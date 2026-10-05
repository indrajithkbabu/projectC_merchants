import 'package:drag_select_grid_view/drag_select_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';

/// In-app multi-image gallery bottomsheet.
///
/// Same UI (albums dropdown, numbered badges, Done) and post-pick flow.
/// Selection via tap + hold-and-slide ([DragSelectGridView]).
class ProductGalleryPicker {
  ProductGalleryPicker._();

  static const int maxAssets = 50;

  /// Opens the gallery sheet and returns selected image file paths.
  static Future<List<String>> pickImagePaths(BuildContext context) async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) return const [];
    if (!context.mounted) return const [];

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      useSafeArea: true,
      builder: (_) => const _ProductGallerySheet(),
    );
    return result ?? const [];
  }
}

class _ProductGallerySheet extends StatefulWidget {
  const _ProductGallerySheet();

  @override
  State<_ProductGallerySheet> createState() => _ProductGallerySheetState();
}

class _ProductGallerySheetState extends State<_ProductGallerySheet> {
  static const int _gridCount = 4;
  static const double _gap = 2;
  static const int _pageSize = 80;
  static const ThumbnailSize _thumbSize = ThumbnailSize.square(160);

  final List<AssetPathEntity> _albums = [];
  final List<AssetEntity> _assets = [];
  final List<AssetEntity> _selected = [];
  final Map<String, AssetEntity?> _albumCovers = {};
  final Map<String, int> _albumCounts = {};
  final ScrollController _scrollController = ScrollController();
  final DragSelectGridViewController _gridController =
      DragSelectGridViewController();
  final Set<String> _selectedIds = {};

  AssetPathEntity? _album;
  int _totalCount = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  bool _albumMenuOpen = false;
  bool _ignoreGridListener = false;

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
    _gridController.addListener(_onGridSelectionChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _gridController.removeListener(_onGridSelectionChanged);
    _gridController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
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
        setState(() {
          _loading = false;
          _error = 'No photos found on this device.';
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

  void _syncGridFromSelected() {
    final indexes = <int>{};
    for (var i = 0; i < _assets.length; i++) {
      if (_selectedIds.contains(_assets[i].id)) indexes.add(i);
    }
    final next = Selection(indexes);
    if (_gridController.value == next) return;
    _ignoreGridListener = true;
    _gridController.value = next;
    _ignoreGridListener = false;
  }

  void _onGridSelectionChanged() {
    if (_ignoreGridListener) return;

    final indexes = Set<int>.from(_gridController.value.selectedIndexes);
    final visibleIds = {for (final a in _assets) a.id};

    setState(() {
      // Drop only assets that are currently visible but no longer selected.
      _selected.removeWhere(
        (a) => visibleIds.contains(a.id) && !_indexSelected(a.id, indexes),
      );
      _selectedIds.removeWhere(
        (id) => visibleIds.contains(id) && !_indexSelected(id, indexes),
      );

      final sorted = indexes.toList()..sort();
      var added = 0;
      var capped = false;
      for (final i in sorted) {
        if (i < 0 || i >= _assets.length) continue;
        final asset = _assets[i];
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
        // Write back clamped indexes so the grid matches maxAssets.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _syncGridFromSelected();
        });
      }
    });
  }

  bool _indexSelected(String assetId, Set<int> indexes) {
    for (final i in indexes) {
      if (i >= 0 && i < _assets.length && _assets[i].id == assetId) {
        return true;
      }
    }
    return false;
  }

  int? _selectionNumber(AssetEntity asset) {
    final i = _selected.indexWhere((e) => e.id == asset.id);
    return i < 0 ? null : i + 1;
  }

  /// Clears grid selection so [DragSelectGridView]'s LocalHistoryEntry is
  /// removed — otherwise the next [Navigator.pop] only clears selection and
  /// never closes the sheet.
  void _releaseGridLocalHistory() {
    if (_gridController.value.selectedIndexes.isEmpty) return;
    _ignoreGridListener = true;
    _gridController.clear();
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
    Navigator.of(context).pop(paths);
  }

  void _closeSheet() {
    _closeAlbumMenu();
    _releaseGridLocalHistory();
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
    final height = MediaQuery.sizeOf(context).height * 0.92;
    final selectedCount = _selected.length;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.sizeOf(context).height - height),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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
                        'Tap to select · hold & slide for nearby photos',
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
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
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
    if (_assets.isEmpty) {
      return Center(
        child: Text('No photos found', style: AppTextStyles.bodySecondary()),
      );
    }

    return DragSelectGridView(
      scrollController: _scrollController,
      gridController: _gridController,
      // Tap toggles immediately; long-press then slide for range select.
      triggerSelectionOnTap: true,
      // Avoid treating selection as a route dismissal step for the app bar.
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
        // Prefer ordered selection badge from our list when present.
        final number =
            selected ? _selectionNumber(asset) : null;
        return _GalleryTile(
          asset: asset,
          thumbSize: _thumbSize,
          selected: selected || _selectedIds.contains(asset.id),
          number: number,
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
              const Icon(
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
                (_, __, ___) => const Center(
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
