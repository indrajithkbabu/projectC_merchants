import 'dart:async';

import 'package:camera/camera.dart';
import 'package:drag_select_grid_view/drag_select_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';

/// Result from the gallery sheet (paths or “open full camera after dismiss”).
class _GallerySheetResult {
  const _GallerySheetResult.paths(this.paths) : openCamera = false;

  const _GallerySheetResult.openCamera()
    : paths = const [],
      openCamera = true;

  final List<String> paths;
  final bool openCamera;
}

/// In-app multi-image gallery bottomsheet.
///
/// Same UI (albums dropdown, numbered badges, Done) and post-pick flow.
/// Selection via tap + hold-and-slide ([DragSelectGridView]).
/// When [includeCamera] is true (Telegram-style), a live camera preview
/// spans 2×3 cells; tap opens full-screen camera (same post-pick flow).
class ProductGalleryPicker {
  ProductGalleryPicker._();

  static const int maxAssets = 50;

  /// Opens the gallery sheet and returns selected image file paths.
  ///
  /// Waits for any prior modal (e.g. Camera/Gallery source sheet) to finish
  /// dismissing — required on Samsung One UI where a second sheet opened in
  /// the same frame often never appears.
  ///
  /// [includeCamera]: live preview cell (2 cols × 3 rows). Tap closes the
  /// sheet then opens an in-app full-screen camera (same `camera` package) →
  /// path → caller navigation. Avoids `image_picker` CameraX handoff crashes
  /// on Xiaomi/MIUI after releasing the sheet preview.
  static Future<List<String>> pickImagePaths(
    BuildContext context, {
    bool includeCamera = false,
  }) async {
    await _awaitPriorModalSettled(context);
    if (!context.mounted) return const [];

    final permission = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.image,
          mediaLocation: false,
        ),
      ),
    );
    if (!context.mounted) return const [];

    // Always resolve permission before presenting the sheet.
    if (!permission.hasAccess) {
      await _showPermissionDenied(context);
      return const [];
    }

    // Warm camera enumeration early so the OS can prompt before the sheet
    // when includeCamera is used (preview needs the camera device).
    if (includeCamera) {
      try {
        await availableCameras();
      } catch (_) {}
      if (!context.mounted) return const [];
    }

    // Let the system permission dialog fully dismiss before presenting UI.
    await _awaitPriorModalSettled(context);
    if (!context.mounted) return const [];

    final result = await showModalBottomSheet<_GallerySheetResult>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      // Sheet owns its height + bottom inset; SafeArea here shrinks MediaQuery
      // and can clip the sheet off-screen on some Samsung devices.
      useSafeArea: false,
      builder: (_) => _ProductGallerySheet(includeCamera: includeCamera),
    );
    if (result == null) return const [];
    if (!result.openCamera) return result.paths;

    // Sheet already released the preview camera; open in-app capture next.
    if (!context.mounted) return const [];
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!context.mounted) return const [];
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) return const [];

    final path = await Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _FullScreenCameraPage(),
      ),
    );
    final trimmed = path?.trim() ?? '';
    return trimmed.isEmpty ? const [] : <String>[trimmed];
  }

  /// Give Flutter / OEM window managers time to finish popping a prior sheet.
  static Future<void> _awaitPriorModalSettled(BuildContext context) async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!context.mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }

  static Future<void> _showPermissionDenied(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text(
          'Photo access is required to pick from Gallery. '
          'Allow access in Settings.',
        ),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: () {
            PhotoManager.openSetting();
          },
        ),
      ),
    );
  }
}

class _ProductGallerySheet extends StatefulWidget {
  const _ProductGallerySheet({this.includeCamera = false});

  final bool includeCamera;

  @override
  State<_ProductGallerySheet> createState() => _ProductGallerySheetState();
}

class _ProductGallerySheetState extends State<_ProductGallerySheet> {
  static const int _gridCount = 4;
  static const int _cameraSpanCols = 2;
  static const int _sideCount = _gridCount - _cameraSpanCols;
  static const int _cameraSpanRows = 3;
  static const double _gap = 2;
  static const int _pageSize = 80;
  static const ThumbnailSize _thumbSize = ThumbnailSize.square(160);
  /// Photos shown beside the tall camera cell (2×3).
  static const int _besideCameraCount = _sideCount * _cameraSpanRows;

  final List<AssetPathEntity> _albums = [];
  final List<AssetEntity> _assets = [];
  final List<AssetEntity> _selected = [];
  final Map<String, AssetEntity?> _albumCovers = {};
  final Map<String, int> _albumCounts = {};
  final ScrollController _scrollController = ScrollController();
  /// All photos (no camera) or photos after the side block when camera is shown.
  final DragSelectGridViewController _gridController =
      DragSelectGridViewController();
  /// Photos beside the camera (Telegram layout only).
  final DragSelectGridViewController _sideGridController =
      DragSelectGridViewController();
  final Set<String> _selectedIds = {};

  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _cameraStarting = false;

  AssetPathEntity? _album;
  int _totalCount = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  bool _albumMenuOpen = false;
  bool _ignoreGridListener = false;
  bool _openingCamera = false;

  static final FilterOptionGroup _filter = FilterOptionGroup(
    imageOption: const FilterOption(
      sizeConstraint: SizeConstraint(ignoreSize: true),
    ),
    orders: const [
      OrderOption(type: OrderOptionType.createDate, asc: false),
      OrderOption(type: OrderOptionType.updateDate, asc: false),
    ],
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _gridController.addListener(_onMainGridSelectionChanged);
    _sideGridController.addListener(_onSideGridSelectionChanged);
    _bootstrap();
    if (widget.includeCamera) {
      unawaited(_initLiveCamera());
    }
  }

  @override
  void dispose() {
    _gridController.removeListener(_onMainGridSelectionChanged);
    _sideGridController.removeListener(_onSideGridSelectionChanged);
    _gridController.dispose();
    _sideGridController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    final cam = _detachLiveCamera();
    if (cam != null) unawaited(cam.dispose());
    super.dispose();
  }

  Future<void> _initLiveCamera() async {
    if (_cameraController != null || _cameraStarting) return;
    if (mounted) setState(() => _cameraStarting = true);
    try {
      // Start immediately (no artificial delay). Host already warmed
      // availableCameras() before the sheet, so this is mostly open+bind.
      final cameras = await availableCameras();
      if (!mounted || cameras.isEmpty) {
        if (mounted) setState(() => _cameraStarting = false);
        return;
      }
      final lens = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        lens,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _cameraReady = true;
        _cameraStarting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraReady = false;
        _cameraStarting = false;
        _cameraController = null;
      });
    }
  }

  /// Detach controller without awaiting dispose (caller may await).
  CameraController? _detachLiveCamera() {
    final cam = _cameraController;
    _cameraController = null;
    _cameraReady = false;
    _cameraStarting = false;
    return cam;
  }

  Future<void> _disposeLiveCamera() async {
    final cam = _detachLiveCamera();
    if (mounted) setState(() {});
    await cam?.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 800) {
      _loadMore();
    }
  }

  Future<void> _bootstrap() async {
    try {
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        filterOption: _filter,
      );
      if (paths.isEmpty) {
        if (!mounted) return;
        final limited = await PhotoManager.requestPermissionExtend();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error =
              limited == PermissionState.limited
                  ? 'No photos available. Allow access to more photos in '
                      'Settings, then try again.'
                  : 'No photos found on this device.';
        });
        return;
      }
      final sorted = [...paths]..sort((a, b) {
        if (a.isAll != b.isAll) return a.isAll ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      final recents =
          sorted.where((p) => p.isAll).firstOrNull ?? sorted.first;
      _albums
        ..clear()
        ..addAll(sorted);
      await _openAlbum(recents);
      _prefetchAlbumMeta(sorted);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to open gallery right now.';
      });
    }
  }

  Future<void> _prefetchAlbumMeta(List<AssetPathEntity> albums) async {
    final limited = albums.take(24);
    for (final album in limited) {
      try {
        final count = await album.assetCountAsync;
        final coverBatch = await album.getAssetListRange(start: 0, end: 1);
        if (!mounted) return;
        setState(() {
          _albumCounts[album.id] = count;
          _albumCovers[album.id] =
              coverBatch.isEmpty ? null : coverBatch.first;
        });
      } catch (_) {}
    }
  }

  Future<void> _openAlbum(AssetPathEntity album) async {
    setState(() {
      _albumMenuOpen = false;
      _loading = true;
      _error = null;
      _album = album;
      _assets.clear();
    });
    try {
      final total = await album.assetCountAsync;
      final page = await album.getAssetListPaged(page: 0, size: _pageSize);
      if (!mounted) return;
      setState(() {
        _totalCount = total;
        _assets.addAll(page);
        _loading = false;
      });
      _syncGridFromSelected();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load this album.';
      });
    }
  }

  Future<void> _loadMore() async {
    final album = _album;
    if (album == null || _loadingMore || _assets.length >= _totalCount) return;
    setState(() => _loadingMore = true);
    try {
      final page = _assets.length ~/ _pageSize;
      final next = await album.getAssetListPaged(page: page, size: _pageSize);
      if (!mounted) return;
      setState(() {
        _assets.addAll(next);
        _loadingMore = false;
      });
      // Newly loaded rows may already be selected from another album visit.
      _syncGridFromSelected();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _closeAlbumMenu() {
    if (!_albumMenuOpen) return;
    setState(() => _albumMenuOpen = false);
  }

  void _toggleAlbumMenu() {
    if (_albums.length <= 1) return;
    HapticFeedback.selectionClick();
    setState(() => _albumMenuOpen = !_albumMenuOpen);
  }

  List<AssetEntity> get _sideAssets {
    if (!widget.includeCamera) return const [];
    final end =
        _assets.length < _besideCameraCount
            ? _assets.length
            : _besideCameraCount;
    return _assets.sublist(0, end);
  }

  List<AssetEntity> get _mainAssets {
    if (!widget.includeCamera) return _assets;
    if (_assets.length <= _besideCameraCount) return const [];
    return _assets.sublist(_besideCameraCount);
  }

  void _syncGridFromSelected() {
    _ignoreGridListener = true;
    if (widget.includeCamera) {
      final side = _sideAssets;
      final sideIndexes = <int>{};
      for (var i = 0; i < side.length; i++) {
        if (_selectedIds.contains(side[i].id)) sideIndexes.add(i);
      }
      final sideNext = Selection(sideIndexes);
      if (_sideGridController.value != sideNext) {
        _sideGridController.value = sideNext;
      }

      final main = _mainAssets;
      final mainIndexes = <int>{};
      for (var i = 0; i < main.length; i++) {
        if (_selectedIds.contains(main[i].id)) mainIndexes.add(i);
      }
      final mainNext = Selection(mainIndexes);
      if (_gridController.value != mainNext) {
        _gridController.value = mainNext;
      }
    } else {
      final indexes = <int>{};
      for (var i = 0; i < _assets.length; i++) {
        if (_selectedIds.contains(_assets[i].id)) indexes.add(i);
      }
      final next = Selection(indexes);
      if (_gridController.value != next) {
        _gridController.value = next;
      }
    }
    _ignoreGridListener = false;
  }

  void _onSideGridSelectionChanged() {
    if (_ignoreGridListener || !widget.includeCamera) return;
    _applyVisibleSelection(
      visible: _sideAssets,
      selectedIndexes: _sideGridController.value.selectedIndexes,
    );
  }

  void _onMainGridSelectionChanged() {
    if (_ignoreGridListener) return;
    final visible = widget.includeCamera ? _mainAssets : _assets;
    _applyVisibleSelection(
      visible: visible,
      selectedIndexes: _gridController.value.selectedIndexes,
    );
  }

  void _applyVisibleSelection({
    required List<AssetEntity> visible,
    required Set<int> selectedIndexes,
  }) {
    final visibleIds = {for (final a in visible) a.id};
    final selectedVisibleIds = <String>{};
    for (final i in selectedIndexes) {
      if (i >= 0 && i < visible.length) {
        selectedVisibleIds.add(visible[i].id);
      }
    }

    setState(() {
      _selected.removeWhere(
        (a) => visibleIds.contains(a.id) && !selectedVisibleIds.contains(a.id),
      );
      _selectedIds.removeWhere(
        (id) => visibleIds.contains(id) && !selectedVisibleIds.contains(id),
      );

      final sorted = selectedIndexes.toList()..sort();
      var added = 0;
      var capped = false;
      for (final i in sorted) {
        if (i < 0 || i >= visible.length) continue;
        final asset = visible[i];
        if (_selectedIds.contains(asset.id)) continue;
        if (_selected.length >= ProductGalleryPicker.maxAssets) {
          capped = true;
          break;
        }
        _selectedIds.add(asset.id);
        _selected.add(asset);
        added++;
      }
      if (added > 0) HapticFeedback.selectionClick();

      if (capped) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _syncGridFromSelected();
        });
      }
    });
  }

  Future<void> _openCameraFromCell() async {
    if (_openingCamera) return;
    _openingCamera = true;
    HapticFeedback.selectionClick();
    try {
      // Release preview fully *before* popping — disposing during the route
      // transition races CameraX on Xiaomi and can kill the process (no nav).
      _releaseGridLocalHistory();
      final cam = _detachLiveCamera();
      if (mounted) setState(() {});
      await WidgetsBinding.instance.endOfFrame;
      if (cam != null) {
        try {
          if (cam.value.isInitialized) await cam.pausePreview();
        } catch (_) {}
        await cam.dispose();
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      Navigator.of(context).pop(const _GallerySheetResult.openCamera());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open camera right now.')),
      );
    } finally {
      _openingCamera = false;
    }
  }

  int? _selectionNumber(AssetEntity asset) {
    final i = _selected.indexWhere((e) => e.id == asset.id);
    return i < 0 ? null : i + 1;
  }

  /// Clears grid selection so [DragSelectGridView]'s LocalHistoryEntry is
  /// removed — otherwise the next [Navigator.pop] only clears selection and
  /// never closes the sheet.
  void _releaseGridLocalHistory() {
    _ignoreGridListener = true;
    if (_gridController.value.selectedIndexes.isNotEmpty) {
      _gridController.clear();
    }
    if (_sideGridController.value.selectedIndexes.isNotEmpty) {
      _sideGridController.clear();
    }
    _ignoreGridListener = false;
  }

  Future<void> _confirm() async {
    _closeAlbumMenu();
    if (_selected.isEmpty) return;

    // Snapshot before releasing grid history (which empties controller indexes).
    final selected = List<AssetEntity>.from(
      _selected.take(ProductGalleryPicker.maxAssets),
    );
    _releaseGridLocalHistory();

    final paths = <String>[];
    for (final asset in selected) {
      final file = await asset.file;
      final path = file?.path.trim() ?? '';
      if (path.isNotEmpty) paths.add(path);
    }
    if (!mounted) return;
    if (paths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to read the selected photos.')),
      );
      return;
    }
    Navigator.of(context).pop(_GallerySheetResult.paths(paths));
  }

  void _closeSheet() {
    _closeAlbumMenu();
    _releaseGridLocalHistory();
    unawaited(_disposeLiveCamera());
    Navigator.of(context).maybePop();
  }

  String get _albumTitle {
    final album = _album;
    if (album == null) return 'Gallery';
    return album.isAll ? 'Recents' : album.name;
  }

  Widget _buildAlbumDropdown() {
    final width = MediaQuery.sizeOf(context).width;
    final menuWidth = (width - 48).clamp(240.0, 320.0);
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: menuWidth, maxHeight: 320),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.navBarShadow,
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 6),
              shrinkWrap: true,
              itemCount: _albums.length,
              separatorBuilder:
                  (_, __) => Divider(
                    height: 1,
                    color: AppColors.border.withValues(alpha: 0.7),
                  ),
              itemBuilder: (context, index) {
                final album = _albums[index];
                return _AlbumDropdownTile(
                  album: album,
                  selected: album.id == _album?.id,
                  cover: _albumCovers[album.id],
                  count: _albumCounts[album.id],
                  onTap: () async {
                    _closeAlbumMenu();
                    if (album.id == _album?.id) return;
                    await _openAlbum(album);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Cap by view padding so nav / cutout never clips the sheet to 0 height.
    final maxHeight = media.size.height - media.viewPadding.top;
    final height = (maxHeight * 0.92).clamp(320.0, maxHeight);
    final selectedCount = _selected.length;
    final bottomInset = media.padding.bottom;

    // SizedBox height alone is enough for isScrollControlled sheets (anchored
    // from the bottom). Extra top Padding(fullH - height) overflowed the
    // modal constraint on several Samsung One UI builds → blank / no sheet.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
              Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: AppPadding.screen(top: 10, bottom: 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _closeSheet,
                          icon: const Icon(Icons.close_rounded),
                          color: AppColors.textPrimary,
                          tooltip: 'Close',
                        ),
                        Expanded(
                          child: Center(
                            child: Material(
                              color: AppColors.surfaceSecondary,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                onTap:
                                    _albums.length > 1
                                        ? _toggleAlbumMenu
                                        : null,
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _albumTitle,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.body(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (_albums.length > 1) ...[
                                        const SizedBox(width: 2),
                                        AnimatedRotation(
                                          turns: _albumMenuOpen ? 0.5 : 0,
                                          duration: const Duration(
                                            milliseconds: 160,
                                          ),
                                          child: Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            size: 20,
                                            color:
                                                _albumMenuOpen
                                                    ? AppColors.primary
                                                    : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: selectedCount == 0 ? null : _confirm,
                          child: Text(
                            selectedCount == 0
                                ? 'Done'
                                : 'Done ($selectedCount)',
                            style: AppTextStyles.button(
                              fontSize: 16,
                              color:
                                  selectedCount == 0
                                      ? AppColors.textHint
                                      : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: AppPadding.screen(bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.includeCamera
                            ? 'Camera · tap to select · hold & slide for nearby'
                            : 'Tap to select · hold & slide for nearby photos',
                        style: AppTextStyles.caption(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: _buildBody()),
                  if (_loadingMore)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  SizedBox(height: bottomInset > 0 ? bottomInset : 8),
                ],
              ),
              if (_albumMenuOpen) ...[
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closeAlbumMenu,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  top: 66,
                  left: 24,
                  right: 24,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _buildAlbumDropdown(),
                  ),
                ),
              ],
            ],
          ),
        ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: AppPadding.screenHorizontal,
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary(),
          ),
        ),
      );
    }
    if (_assets.isEmpty && !widget.includeCamera) {
      return Center(
        child: Text('No photos found', style: AppTextStyles.bodySecondary()),
      );
    }

    if (widget.includeCamera) {
      return _buildTelegramBody();
    }

    return DragSelectGridView(
      scrollController: _scrollController,
      gridController: _gridController,
      triggerSelectionOnTap: true,
      impliesAppBarDismissal: false,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      cacheExtent: 1200,
      padding: AppPadding.screenHorizontal,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _gridCount,
        crossAxisSpacing: _gap,
        mainAxisSpacing: _gap,
      ),
      itemCount: _assets.length,
      itemBuilder: (context, index, selected) {
        final asset = _assets[index];
        final number = selected ? _selectionNumber(asset) : null;
        return _GalleryTile(
          asset: asset,
          thumbSize: _thumbSize,
          selected: selected || _selectedIds.contains(asset.id),
          number: number,
        );
      },
    );
  }

  /// Camera spans 2 cols × 3 rows; 2×3 photos beside it; more photos below.
  Widget _buildTelegramBody() {
    final side = _sideAssets;
    final main = _mainAssets;

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentW =
            constraints.maxWidth - (AppPadding.horizontal * 2);
        final cell = (contentW - (_gap * (_gridCount - 1))) / _gridCount;
        final cameraH = cell * _cameraSpanRows + _gap * (_cameraSpanRows - 1);
        final cameraW =
            cell * _cameraSpanCols + _gap * (_cameraSpanCols - 1);

        return CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          cacheExtent: 1200,
          slivers: [
            SliverPadding(
              padding: AppPadding.screenHorizontal,
              sliver: SliverToBoxAdapter(
                child: SizedBox(
                  height: cameraH,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: cameraW,
                        // Keep CameraPreview out from under Material/InkWell —
                        // those layers often leave a black texture on Android.
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap:
                              _openingCamera ? null : _openCameraFromCell,
                          child: _LiveCameraTile(
                            controller:
                                _cameraReady ? _cameraController : null,
                            starting: _cameraStarting && !_cameraReady,
                          ),
                        ),
                      ),
                      if (side.isNotEmpty) ...[
                        const SizedBox(width: _gap),
                        Expanded(
                          child: DragSelectGridView(
                            gridController: _sideGridController,
                            triggerSelectionOnTap: true,
                            impliesAppBarDismissal: false,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: _sideCount,
                                  crossAxisSpacing: _gap,
                                  mainAxisSpacing: _gap,
                                ),
                            itemCount: side.length,
                            itemBuilder: (context, index, selected) {
                              final asset = side[index];
                              final number =
                                  selected ? _selectionNumber(asset) : null;
                              return _GalleryTile(
                                asset: asset,
                                thumbSize: _thumbSize,
                                selected:
                                    selected ||
                                    _selectedIds.contains(asset.id),
                                number: number,
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (main.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SizedBox(height: _gap)),
              SliverPadding(
                padding: AppPadding.screenHorizontal,
                sliver: SliverToBoxAdapter(
                  child: DragSelectGridView(
                    gridController: _gridController,
                    triggerSelectionOnTap: true,
                    impliesAppBarDismissal: false,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _gridCount,
                          crossAxisSpacing: _gap,
                          mainAxisSpacing: _gap,
                        ),
                    itemCount: main.length,
                    itemBuilder: (context, index, selected) {
                      final asset = main[index];
                      final number =
                          selected ? _selectionNumber(asset) : null;
                      return _GalleryTile(
                        asset: asset,
                        thumbSize: _thumbSize,
                        selected:
                            selected || _selectedIds.contains(asset.id),
                        number: number,
                      );
                    },
                  ),
                ),
              ),
            ] else if (_assets.isEmpty) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(
                child: Center(
                  child: Text(
                    'No photos found',
                    style: AppTextStyles.bodySecondary(),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _AlbumDropdownTile extends StatelessWidget {
  const _AlbumDropdownTile({
    required this.album,
    required this.selected,
    required this.cover,
    required this.count,
    required this.onTap,
  });

  final AssetPathEntity album;
  final bool selected;
  final AssetEntity? cover;
  final int? count;
  final VoidCallback onTap;

  String get _name => album.isAll ? 'Recents' : album.name;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 44,
                child:
                    cover == null
                        ? ColoredBox(
                          color: AppColors.surfaceSecondary,
                          child: Icon(
                            album.isAll
                                ? Icons.photo_library_rounded
                                : Icons.folder_rounded,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                        )
                        : Image(
                          image: AssetEntityImageProvider(
                            cover!,
                            isOriginal: false,
                            thumbnailSize: const ThumbnailSize.square(120),
                          ),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.low,
                        ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(
                      fontSize: 15,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w600,
                      color:
                          selected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$count',
                      style: AppTextStyles.caption(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

/// Live rear-camera preview filling the 2×3 cell; tap opens full camera.
class _LiveCameraTile extends StatelessWidget {
  const _LiveCameraTile({
    required this.controller,
    this.starting = false,
  });

  final CameraController? controller;
  final bool starting;

  @override
  Widget build(BuildContext context) {
    final cam = controller;
    final ready = cam != null && cam.value.isInitialized;

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (ready)
            _CameraPreviewCover(controller: cam)
          else
            const ColoredBox(color: Colors.black),
          // Soft vignette so the shutter affordance stays readable on bright scenes.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x33000000),
                  Color(0x00000000),
                  Color(0x66000000),
                ],
                stops: [0, 0.45, 1],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (starting && !ready)
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white70,
                    ),
                  )
                else
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.35),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.85),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.photo_camera_rounded,
                      size: 28,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  'Camera',
                  style: AppTextStyles.caption(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraPreviewCover extends StatelessWidget {
  const _CameraPreviewCover({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    final aspect = controller.value.aspectRatio;
    if (aspect <= 0) {
      return CameraPreview(controller);
    }
    // Cover-crop into the 2×3 cell (sensor orientation handled by CameraPreview).
    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          var width = constraints.maxWidth;
          var height = width / aspect;
          if (height < constraints.maxHeight) {
            height = constraints.maxHeight;
            width = height * aspect;
          }
          return ClipRect(
            child: OverflowBox(
              alignment: Alignment.center,
              maxWidth: width,
              maxHeight: height,
              child: SizedBox(
                width: width,
                height: height,
                child: CameraPreview(controller),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.asset,
    required this.thumbSize,
    required this.selected,
    required this.number,
  });

  final AssetEntity asset;
  final ThumbnailSize thumbSize;
  final bool selected;
  final int? number;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceSecondary,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: AssetEntityImageProvider(
              asset,
              isOriginal: false,
              thumbnailSize: thumbSize,
            ),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
            errorBuilder:
                (_, __, ___) => Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textHint,
                    size: 22,
                  ),
                ),
          ),
          if (selected)
            ColoredBox(color: AppColors.primary.withValues(alpha: 0.38)),
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : Colors.black38,
                border: Border.all(
                  color: AppColors.textOnPrimary,
                  width: 1.5,
                ),
              ),
              child:
                  selected && number != null
                      ? Text(
                        '$number',
                        style: AppTextStyles.caption(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textOnPrimary,
                        ),
                      )
                      : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen capture after the gallery sheet Camera cell is tapped.
/// Uses the same `camera` package as the sheet preview (no image_picker /
/// CameraX handoff) so the path always returns to add-product navigation.
class _FullScreenCameraPage extends StatefulWidget {
  const _FullScreenCameraPage();

  @override
  State<_FullScreenCameraPage> createState() => _FullScreenCameraPageState();
}

class _FullScreenCameraPageState extends State<_FullScreenCameraPage> {
  CameraController? _controller;
  bool _ready = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    final cam = _controller;
    _controller = null;
    if (cam != null) unawaited(cam.dispose());
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() => _error = 'No camera available on this device.');
        return;
      }
      final lens = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        lens,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _ready = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to open camera right now.');
    }
  }

  Future<void> _capture() async {
    final cam = _controller;
    if (_busy || cam == null || !cam.value.isInitialized) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      final shot = await cam.takePicture();
      final path = shot.path.trim();
      if (!mounted) return;
      if (path.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      Navigator.of(context).pop(path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to take photo right now.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cam = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_ready && cam != null)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: cam.value.previewSize?.height ?? 1,
                height: cam.value.previewSize?.width ?? 1,
                child: CameraPreview(cam),
              ),
            )
          else
            Center(
              child:
                  _error != null
                      ? Padding(
                        padding: AppPadding.screenHorizontal,
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body(
                            color: Colors.white70,
                          ),
                        ),
                      )
                      : const CircularProgressIndicator(color: Colors.white70),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded),
                color: Colors.white,
                tooltip: 'Close',
              ),
            ),
          ),
          if (_ready)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: GestureDetector(
                    onTap: _busy ? null : _capture,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      child:
                          _busy
                              ? const Padding(
                                padding: EdgeInsets.all(22),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                              : Center(
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
