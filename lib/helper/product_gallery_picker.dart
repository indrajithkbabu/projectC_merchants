import 'dart:async';
import 'dart:io' show File;
import 'dart:ui' show ImageFilter;

import 'package:camera/camera.dart';
import 'package:drag_select_grid_view/drag_select_grid_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Reuses [AssetEntityImageProvider] instances so grid rebuilds (drag-select)
/// hit Flutter's [ImageCache] instead of allocating new providers each frame.
class _GalleryThumbProviders {
  _GalleryThumbProviders._();

  static final Map<String, AssetEntityImageProvider> _byKey = {};

  static AssetEntityImageProvider of(
    AssetEntity asset,
    ThumbnailSize thumbSize,
  ) {
    final key = '${asset.id}_${thumbSize.width}x${thumbSize.height}';
    return _byKey.putIfAbsent(
      key,
      () => AssetEntityImageProvider(
        asset,
        isOriginal: false,
        thumbnailSize: thumbSize,
        thumbnailFormat: ThumbnailFormat.jpeg,
      ),
    );
  }

  static void clear() => _byKey.clear();
}

/// Debug-only timeline for gallery confirm → compose open.
/// Search logcat for `[ComposeNavPerf]`.
void _composeNavPerf(String stage, {int? n, Stopwatch? sw}) {
  if (!kDebugMode) return;
  final ms = sw == null ? '' : ' +${sw.elapsedMilliseconds}ms';
  final count = n == null ? '' : ' n=$n';
  debugPrint('[ComposeNavPerf]$ms $stage$count');
}

/// Paths from [ProductGalleryPicker.pickImages], plus which photo to show
/// first on the next screen (Telegram: body tap opens that image).
class ProductGalleryPickResult {
  const ProductGalleryPickResult({
    required this.paths,
    this.initialIndex = 0,
  });

  final List<String> paths;
  final int initialIndex;

  static const empty = ProductGalleryPickResult(paths: []);
}

/// Result from the gallery sheet (paths or “open full camera after dismiss”).
class _GallerySheetResult {
  const _GallerySheetResult.paths(this.paths, {this.initialIndex = 0})
    : openCamera = false;

  const _GallerySheetResult.openCamera()
    : paths = const [],
      initialIndex = 0,
      openCamera = true;

  final List<String> paths;
  final int initialIndex;
  final bool openCamera;
}

/// In-app multi-image gallery bottomsheet (Telegram attach-media style).
///
/// Same UI (albums dropdown, numbered badges) and post-pick flow.
/// Confirm control is **Done** text by default, or a WhatsApp-style send
/// icon + count when [confirmAsSend] is true (add-products flow).
/// Telegram selection: photo body opens next when idle; count badge toggles
/// select; hold-and-slide multi-selects ([DragSelectGridView]).
/// When [includeCamera] is true, a live camera preview spans 2×3 cells; tap
/// opens full-screen camera (same post-pick flow).
class ProductGalleryPicker {
  ProductGalleryPicker._();

  static const int maxAssets = 50;

  /// Serializes CameraX dispose so a later preview/capture never opens while
  /// a previous controller is still tearing down (Xiaomi Binder races).
  static Future<void> _cameraDisposeQueue = Future<void>.value();

  /// Await any in-flight gallery camera dispose (full-screen camera / re-open).
  static Future<void> awaitPendingCameraDispose() => _cameraDisposeQueue;

  /// Decode width for compose hero — must match compose `Image.file` cacheWidth.
  static int composeHeroDecodeWidth({
    required double logicalWidth,
    required double dpr,
  }) {
    return (logicalWidth * dpr).round().clamp(320, 1080);
  }

  /// Kick off hero decode into [ImageCache] without a BuildContext (overlaps
  /// remaining path IO / route push). Matches compose ResizeImage key.
  static void warmComposeHeroDecode(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return;
    try {
      final views = WidgetsBinding.instance.platformDispatcher.views;
      if (views.isEmpty) return;
      final view = views.first;
      final logicalW = view.physicalSize.width / view.devicePixelRatio;
      final cacheWidth = composeHeroDecodeWidth(
        logicalWidth: logicalW,
        dpr: view.devicePixelRatio,
      );
      final provider = ResizeImage(
        FileImage(File(trimmed)),
        width: cacheWidth,
      );
      final stream = provider.resolve(
        ImageConfiguration(devicePixelRatio: view.devicePixelRatio),
      );
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool _) {
          stream.removeListener(listener);
          // Keep bitmap in [ImageCache]; do not dispose [info] here.
        },
        onError: (Object _, StackTrace? __) {
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
    } catch (_) {}
  }

  static Future<File?> _safeAssetFile(AssetEntity asset) async {
    try {
      return await asset.file;
    } catch (_) {
      return null;
    }
  }

  /// Detach is already done by caller. Dispose runs off the navigation critical
  /// path but still completes before the next camera open.
  static Future<void> _enqueueCameraDispose(CameraController? cam) {
    if (cam == null) return _cameraDisposeQueue;
    _cameraDisposeQueue = _cameraDisposeQueue.then((_) async {
      final sw = Stopwatch()..start();
      _composeNavPerf('camera_dispose_start', sw: sw);
      try {
        if (cam.value.isInitialized) await cam.pausePreview();
      } catch (_) {}
      try {
        await cam.dispose();
      } catch (_) {}
      _composeNavPerf('camera_dispose_end', sw: sw);
    });
    return _cameraDisposeQueue;
  }

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
  ///
  /// [confirmAsSend]: replace Done with a green send icon + selection count.
  static Future<List<String>> pickImagePaths(
    BuildContext context, {
    bool includeCamera = false,
    bool confirmAsSend = false,
  }) async {
    final result = await pickImages(
      context,
      includeCamera: includeCamera,
      confirmAsSend: confirmAsSend,
    );
    return result.paths;
  }

  /// Same as [pickImagePaths], plus [ProductGalleryPickResult.initialIndex]
  /// for the photo that should open first on the next screen.
  ///
  /// Lightweight bottom-sheet [PopupRoute]: dimmed barrier, slide-up, rounded
  /// sheet, drag handle, tap-outside / back to dismiss — same look as
  /// [showModalBottomSheet] with less route overhead. Live camera stays on
  /// while scrolling (Telegram); Texture is a stable child under Transform.
  static Future<ProductGalleryPickResult> pickImages(
    BuildContext context, {
    bool includeCamera = false,
    bool confirmAsSend = false,
  }) async {
    if (!context.mounted) return ProductGalleryPickResult.empty;

    // Start album + first page before the route is pushed so thumbs are often
    // ready as the sheet finishes sliding up (avoids empty→photos flicker).
    final warm = _warmFirstPage();

    final result = await Navigator.of(context, rootNavigator: true)
        .push<_GallerySheetResult>(
      _GallerySheetPopupRoute(
        includeCamera: includeCamera,
        confirmAsSend: confirmAsSend,
        warm: warm,
      ),
    );
    _composeNavPerf(
      'pickImages_return',
      n: result == null ? 0 : result.paths.length,
    );
    if (result == null) return ProductGalleryPickResult.empty;
    if (!result.openCamera) {
      return ProductGalleryPickResult(
        paths: result.paths,
        initialIndex: result.initialIndex,
      );
    }

    // Sheet already released the preview camera; open in-app capture next.
    // Wait for any background dispose from the sheet before opening CameraX.
    await awaitPendingCameraDispose();
    if (!context.mounted) return ProductGalleryPickResult.empty;
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!context.mounted) return ProductGalleryPickResult.empty;
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) return ProductGalleryPickResult.empty;

    final path = await Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _FullScreenCameraPage(),
      ),
    );
    final trimmed = path?.trim() ?? '';
    return trimmed.isEmpty
        ? ProductGalleryPickResult.empty
        : ProductGalleryPickResult(paths: <String>[trimmed]);
  }

  static final FilterOptionGroup _filter = FilterOptionGroup(
    imageOption: const FilterOption(
      sizeConstraint: SizeConstraint(ignoreSize: true),
    ),
    orders: const [
      OrderOption(type: OrderOptionType.createDate, asc: false),
      OrderOption(type: OrderOptionType.updateDate, asc: false),
    ],
  );

  /// Permission + Recents first page — started before the sheet route pushes.
  static Future<_GalleryWarmResult> _warmFirstPage() async {
    try {
      final permission = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.image,
            mediaLocation: false,
          ),
        ),
      );
      if (!permission.hasAccess) {
        return _GalleryWarmResult.error(
          'Photo access is required to pick from Gallery. '
          'Allow access in Settings.',
        );
      }
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        filterOption: _filter,
      );
      if (paths.isEmpty) {
        return _GalleryWarmResult.error(
          permission == PermissionState.limited
              ? 'No photos available. Allow access to more photos in '
                  'Settings, then try again.'
              : 'No photos found on this device.',
        );
      }
      final sorted = [...paths]..sort((a, b) {
        if (a.isAll != b.isAll) return a.isAll ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      final recents =
          sorted.where((p) => p.isAll).firstOrNull ?? sorted.first;
      final total = await recents.assetCountAsync;
      final page = await recents.getAssetListPaged(
        page: 0,
        size: _ProductGallerySheetState._pageSize,
      );
      return _GalleryWarmResult(
        albums: sorted,
        album: recents,
        assets: page,
        totalCount: total,
      );
    } catch (_) {
      return _GalleryWarmResult.error('Unable to open gallery right now.');
    }
  }
}

/// Preloaded album + first thumbnails for a flicker-free sheet open.
class _GalleryWarmResult {
  const _GalleryWarmResult({
    required this.albums,
    required this.album,
    required this.assets,
    required this.totalCount,
  }) : error = null;

  const _GalleryWarmResult.error(this.error)
    : albums = const [],
      album = null,
      assets = const [],
      totalCount = 0;

  final List<AssetPathEntity> albums;
  final AssetPathEntity? album;
  final List<AssetEntity> assets;
  final int totalCount;
  final String? error;
}

/// Bottom-sheet style route: dimmed barrier, slide up from bottom, tap outside
/// / back to dismiss. Same UX as [showModalBottomSheet] with less route overhead
/// so [_ProductGallerySheet] can start bootstrapping during the animation.
class _GallerySheetPopupRoute extends PopupRoute<_GallerySheetResult> {
  _GallerySheetPopupRoute({
    required this.includeCamera,
    required this.confirmAsSend,
    required this.warm,
  });

  final bool includeCamera;
  final bool confirmAsSend;
  final Future<_GalleryWarmResult> warm;

  /// Matches Material modal bottom sheet enter (~250–280ms).
  @override
  Duration get transitionDuration => const Duration(milliseconds: 280);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 220);

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: 0.45);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Close gallery';

  @override
  bool get maintainState => true;

  @override
  bool get opaque => false;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // Material removes debug yellow text underlines (PopupRoute has no
    // Material ancestor unlike showModalBottomSheet).
    return Material(
      type: MaterialType.transparency,
      child: _ProductGallerySheet(
        includeCamera: includeCamera,
        confirmAsSend: confirmAsSend,
        warm: warm,
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return Align(
      alignment: Alignment.bottomCenter,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class _ProductGallerySheet extends StatefulWidget {
  const _ProductGallerySheet({
    this.includeCamera = false,
    this.confirmAsSend = false,
    required this.warm,
  });

  final bool includeCamera;
  final bool confirmAsSend;
  final Future<_GalleryWarmResult> warm;

  @override
  State<_ProductGallerySheet> createState() => _ProductGallerySheetState();
}

class _ProductGallerySheetState extends State<_ProductGallerySheet> {
  static const int _gridCount = 4;
  static const int _cameraSpanCols = 2;
  static const int _sideCount = _gridCount - _cameraSpanCols;
  static const int _cameraSpanRows = 3;
  static const double _gap = 2;
  /// Small pages — load more asset pages only as the user scrolls (Telegram).
  /// Public to library so [ProductGalleryPicker._warmFirstPage] matches.
  static const int _pageSize = 36;
  /// Visible cells + ~1–2 rows — keep modest so scroll decode stays light.
  static const double _cacheExtent = 240;
  /// Photos shown beside the tall camera cell (2×3).
  static const int _besideCameraCount = _sideCount * _cameraSpanRows;

  final List<AssetPathEntity> _albums = [];
  final List<AssetEntity> _assets = [];
  final List<AssetEntity> _selected = [];
  final Map<String, AssetEntity?> _albumCovers = {};
  final Map<String, int> _albumCounts = {};
  final ScrollController _scrollController = ScrollController();
  /// Single grid for all selectable photos (Telegram camera uses spacers + overlay).
  final DragSelectGridViewController _gridController =
      DragSelectGridViewController();
  final Set<String> _selectedIds = {};
  /// id → 1-based order — O(1) badge numbers without scanning [_selected].
  final Map<String, int> _selectionOrder = {};
  /// Header count without rebuilding the whole sheet on every drag tick.
  final ValueNotifier<int> _selectedCount = ValueNotifier<int>(0);
  /// Live camera controller — updates only the overlay, not the grid/header.
  final ValueNotifier<CameraController?> _liveCamera =
      ValueNotifier<CameraController?>(null);

  Timer? _cameraStartTimer;

  int? _prevImageCacheSize;
  int? _prevImageCacheBytes;

  AssetPathEntity? _album;
  int _totalCount = 0;
  /// Sheet paints immediately; true while first album page is pending.
  bool _bootstrapping = true;
  bool _loadingMore = false;
  bool _albumMetaLoaded = false;
  String? _error;
  bool _albumMenuOpen = false;
  bool _ignoreGridListener = false;
  bool _openingCamera = false;

  @override
  void initState() {
    super.initState();
    _boostImageCache();
    _scrollController.addListener(_onScroll);
    _gridController.addListener(_onGridSelectionChanged);
    unawaited(_applyWarm(widget.warm));
    if (widget.includeCamera) {
      // Slight defer so the sheet paints first; icon shows immediately (no loader).
      _cameraStartTimer = Timer(const Duration(milliseconds: 120), () {
        if (mounted) unawaited(_initLiveCamera());
      });
    }
  }

  @override
  void dispose() {
    _cameraStartTimer?.cancel();
    _restoreImageCache();
    _GalleryThumbProviders.clear();
    _gridController.removeListener(_onGridSelectionChanged);
    _gridController.dispose();
    _selectedCount.dispose();
    final cam = _liveCamera.value;
    _liveCamera.value = null;
    _liveCamera.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    if (cam != null) unawaited(ProductGalleryPicker._enqueueCameraDispose(cam));
    super.dispose();
  }

  void _boostImageCache() {
    final cache = PaintingBinding.instance.imageCache;
    _prevImageCacheSize = cache.maximumSize;
    _prevImageCacheBytes = cache.maximumSizeBytes;
    // Modest cache — visible + near thumbs, not the whole library.
    if (cache.maximumSize < 160) cache.maximumSize = 160;
    if (cache.maximumSizeBytes < 48 << 20) {
      cache.maximumSizeBytes = 48 << 20;
    }
  }

  void _restoreImageCache() {
    final cache = PaintingBinding.instance.imageCache;
    final size = _prevImageCacheSize;
    final bytes = _prevImageCacheBytes;
    if (size != null) cache.maximumSize = size;
    if (bytes != null) cache.maximumSizeBytes = bytes;
  }

  /// Cell edge × DPR, capped — decode only what the tile needs.
  ThumbnailSize _thumbSizeForCell(double cellLogical) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // Cap at 120px decode — enough for 4-col cells; cheaper scroll than 160.
    final px = (cellLogical * dpr).round().clamp(64, 120);
    return ThumbnailSize.square(px);
  }

  Future<void> _initLiveCamera() async {
    if (_liveCamera.value != null) return;
    // Prior confirm may still be disposing CameraX in the background.
    await ProductGalleryPicker.awaitPendingCameraDispose();
    if (!mounted || _liveCamera.value != null) return;
    try {
      final cameras = await availableCameras();
      if (!mounted || cameras.isEmpty) return;
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
      // Overlay-only notify — do not setState the grid/header.
      _liveCamera.value = controller;
    } catch (_) {
      if (!mounted) return;
      _liveCamera.value = null;
    }
  }

  /// Detach controller without awaiting dispose (caller may await).
  CameraController? _detachLiveCamera() {
    final cam = _liveCamera.value;
    _liveCamera.value = null;
    return cam;
  }

  Future<void> _disposeLiveCamera() async {
    final cam = _detachLiveCamera();
    await ProductGalleryPicker._enqueueCameraDispose(cam);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    // Camera overlay listens to [_scrollController] via AnimatedBuilder —
    // do not setState / ValueNotifier here (keeps grid + live Texture stable).
    if (_loadingMore) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 600) {
      unawaited(_loadMore());
    }
  }

  void _rebuildSelectionOrder() {
    _selectionOrder
      ..clear()
      ..addEntries([
        for (var i = 0; i < _selected.length; i++)
          MapEntry(_selected[i].id, i + 1),
      ]);
  }

  ScrollPhysics get _gridPhysics {
    // Clamping on Android (Telegram-like); bouncing on iOS.
    // Avoid nested AlwaysScrollable — it adds overscroll work for no benefit.
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
    }
    return const ClampingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  Future<void> _applyWarm(Future<_GalleryWarmResult> warm) async {
    final result = await warm;
    if (!mounted) return;
    if (result.error != null) {
      setState(() {
        _bootstrapping = false;
        _error = result.error;
        _albums.clear();
        _assets.clear();
        _album = null;
        _totalCount = 0;
      });
      return;
    }
    final album = result.album;
    if (album == null) {
      setState(() {
        _bootstrapping = false;
        _error = 'Unable to open gallery right now.';
      });
      return;
    }
    setState(() {
      _error = null;
      _bootstrapping = false;
      _albums
        ..clear()
        ..addAll(result.albums);
      _album = album;
      _totalCount = result.totalCount;
      _assets
        ..clear()
        ..addAll(result.assets);
    });
    _syncGridFromSelected();
  }

  /// Album covers/counts only when the dropdown opens (not on every sheet open).
  Future<void> _ensureAlbumMeta() async {
    if (_albumMetaLoaded || _albums.isEmpty) return;
    _albumMetaLoaded = true;
    final limited = _albums.take(24).toList(growable: false);
    final counts = <String, int>{};
    final covers = <String, AssetEntity?>{};
    for (final album in limited) {
      try {
        counts[album.id] = await album.assetCountAsync;
        final coverBatch = await album.getAssetListRange(start: 0, end: 1);
        covers[album.id] = coverBatch.isEmpty ? null : coverBatch.first;
      } catch (_) {}
      if (!mounted) return;
    }
    if (!mounted) return;
    setState(() {
      _albumCounts.addAll(counts);
      _albumCovers.addAll(covers);
    });
  }

  Future<void> _openAlbum(AssetPathEntity album) async {
    if (mounted) {
      setState(() {
        _albumMenuOpen = false;
        _bootstrapping = _assets.isEmpty;
        _error = null;
        _album = album;
        _assets.clear();
      });
    }
    try {
      final total = await album.assetCountAsync;
      final page = await album.getAssetListPaged(page: 0, size: _pageSize);
      if (!mounted) return;
      setState(() {
        _totalCount = total;
        _assets
          ..clear()
          ..addAll(page);
        _bootstrapping = false;
      });
      _syncGridFromSelected();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bootstrapping = false;
        _error = 'Unable to load this album.';
      });
    }
  }

  Future<void> _loadMore() async {
    final album = _album;
    if (album == null || _loadingMore || _assets.length >= _totalCount) return;
    _loadingMore = true;
    try {
      final page = _assets.length ~/ _pageSize;
      final next = await album.getAssetListPaged(page: page, size: _pageSize);
      if (!mounted) return;
      if (next.isEmpty) {
        _loadingMore = false;
        return;
      }
      setState(() {
        _assets.addAll(next);
        _loadingMore = false;
      });
      // Newly loaded rows may already be selected from another album visit.
      _syncGridFromSelected();
    } catch (_) {
      _loadingMore = false;
    }
  }

  void _closeAlbumMenu() {
    if (!_albumMenuOpen) return;
    setState(() => _albumMenuOpen = false);
  }

  void _toggleAlbumMenu() {
    if (_albums.length <= 1) return;
    HapticFeedback.selectionClick();
    final opening = !_albumMenuOpen;
    setState(() => _albumMenuOpen = opening);
    if (opening) unawaited(_ensureAlbumMeta());
  }

  /// Camera hole + empty slots in the 2×3 beside-camera band are non-photos.
  bool _isTelegramNonPhotoCell(int gridIndex) {
    return _assetIndexForGridIndex(gridIndex) == null;
  }

  /// Maps a flat 4-col grid index → asset index when [includeCamera].
  /// Camera occupies cols 0–1 for the first 3 rows (spacers); photos fill the
  /// rest so one [DragSelectGridView] can slide-select across the whole sheet.
  int? _assetIndexForGridIndex(int gridIndex) {
    if (!widget.includeCamera) {
      if (gridIndex < 0 || gridIndex >= _assets.length) return null;
      return gridIndex;
    }
    final row = gridIndex ~/ _gridCount;
    final col = gridIndex % _gridCount;
    if (row < _cameraSpanRows && col < _cameraSpanCols) return null;
    late final int assetIndex;
    if (row < _cameraSpanRows) {
      assetIndex = row * _sideCount + (col - _cameraSpanCols);
    } else {
      assetIndex = gridIndex - (_cameraSpanCols * _cameraSpanRows);
    }
    if (assetIndex < 0 || assetIndex >= _assets.length) return null;
    return assetIndex;
  }

  int _gridIndexForAsset(int assetIndex) {
    if (!widget.includeCamera) return assetIndex;
    if (assetIndex < _besideCameraCount) {
      final row = assetIndex ~/ _sideCount;
      final col = _cameraSpanCols + (assetIndex % _sideCount);
      return row * _gridCount + col;
    }
    return (_gridCount * _cameraSpanRows) +
        (assetIndex - _besideCameraCount);
  }

  int get _gridItemCount {
    // Placeholder rows while warm loads so the sheet never opens empty.
    const placeholderExtraRows = 6;
    if (!widget.includeCamera) {
      if (_assets.isEmpty && _bootstrapping) {
        return _gridCount * placeholderExtraRows;
      }
      return _assets.length;
    }
    final cameraBlock = _gridCount * _cameraSpanRows;
    if (_assets.isEmpty) {
      return _bootstrapping
          ? cameraBlock + _gridCount * placeholderExtraRows
          : cameraBlock;
    }
    final last = _gridIndexForAsset(_assets.length - 1) + 1;
    return last < cameraBlock ? cameraBlock : last;
  }

  bool _isCameraHole(int gridIndex) {
    if (!widget.includeCamera) return false;
    final row = gridIndex ~/ _gridCount;
    final col = gridIndex % _gridCount;
    return row < _cameraSpanRows && col < _cameraSpanCols;
  }

  Widget _placeholderTile() {
    return ColoredBox(color: AppColors.surfaceSecondary);
  }

  void _syncGridFromSelected() {
    _ignoreGridListener = true;
    final indexes = <int>{};
    for (var i = 0; i < _assets.length; i++) {
      if (_selectedIds.contains(_assets[i].id)) {
        indexes.add(_gridIndexForAsset(i));
      }
    }
    final next = Selection(indexes);
    if (_gridController.value != next) {
      _gridController.value = next;
    }
    _ignoreGridListener = false;
  }

  void _onGridSelectionChanged() {
    if (_ignoreGridListener) return;
    final selectedIndexes = _gridController.value.selectedIndexes;
    final selectedAssetIndexes = <int>{};
    for (final g in selectedIndexes) {
      final assetIndex = _assetIndexForGridIndex(g);
      if (assetIndex != null) selectedAssetIndexes.add(assetIndex);
    }

    // Drop camera-hole / empty indexes from the controller so badges stay clean.
    final cleaned = {
      for (final a in selectedAssetIndexes) _gridIndexForAsset(a),
    };
    final photoOnly = {
      for (final g in selectedIndexes)
        if (!_isTelegramNonPhotoCell(g)) g,
    };
    if (cleaned.length != photoOnly.length || !cleaned.containsAll(photoOnly)) {
      _ignoreGridListener = true;
      _gridController.value = Selection(cleaned);
      _ignoreGridListener = false;
    }

    // Mutate selection without setState — DragSelectGridView already rebuilt
    // tiles; header listens to [_selectedCount].
    final selectedIds = <String>{
      for (final i in selectedAssetIndexes) _assets[i].id,
    };
    _selected.removeWhere((a) => !selectedIds.contains(a.id));
    _selectedIds.removeWhere((id) => !selectedIds.contains(id));

    final sorted = selectedAssetIndexes.toList()..sort();
    var added = 0;
    var capped = false;
    for (final i in sorted) {
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
    _rebuildSelectionOrder();
    if (_selectedCount.value != _selected.length) {
      _selectedCount.value = _selected.length;
    }

    if (capped) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncGridFromSelected();
      });
    }
  }

  Future<void> _openCameraFromCell() async {
    if (_openingCamera) return;
    _openingCamera = true;
    HapticFeedback.selectionClick();
    try {
      // Must fully release preview before full-screen CameraX opens (Xiaomi).
      _releaseGridLocalHistory();
      final cam = _detachLiveCamera();
      if (mounted) setState(() {});
      await WidgetsBinding.instance.endOfFrame;
      // Await full CameraX teardown before opening full-screen capture.
      await ProductGalleryPicker._enqueueCameraDispose(cam);
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

  int? _selectionNumber(AssetEntity asset) => _selectionOrder[asset.id];

  /// Clears grid selection so [DragSelectGridView]'s LocalHistoryEntry is
  /// removed — otherwise the next [Navigator.pop] only clears selection and
  /// never closes the sheet.
  void _releaseGridLocalHistory() {
    _ignoreGridListener = true;
    if (_gridController.value.selectedIndexes.isNotEmpty) {
      _gridController.clear();
    }
    _ignoreGridListener = false;
    _selected.clear();
    _selectedIds.clear();
    _selectionOrder.clear();
    if (_selectedCount.value != 0) _selectedCount.value = 0;
  }

  Future<void> _confirm({int initialIndex = 0}) async {
    if (_selected.isEmpty) return;
    await _confirmWithAssets(
      List<AssetEntity>.from(_selected.take(ProductGalleryPicker.maxAssets)),
      initialIndex: initialIndex,
    );
  }

  /// Telegram: photo body selects when idle / unselected; body of an already
  /// selected photo continues with the full selection (opens on that photo).
  Future<void> _openFromPhotoBody(AssetEntity asset) async {
    final assetIndex = _assets.indexWhere((a) => a.id == asset.id);
    if (assetIndex < 0) return;

    if (_selectedIds.contains(asset.id)) {
      // Already selected → continue (compose) starting on this photo.
      final order = _selectionOrder[asset.id];
      final i = order == null ? 0 : order - 1;
      HapticFeedback.selectionClick();
      await _confirm(initialIndex: i);
      return;
    }

    // Idle or selecting: body tap selects (badge also toggles / deselects).
    _toggleAssetAt(assetIndex);
  }

  /// Checkmark / count circle — toggle without opening compose.
  void _toggleAssetAt(int assetIndex) {
    if (assetIndex < 0 || assetIndex >= _assets.length) return;
    final gridIndex = _gridIndexForAsset(assetIndex);
    final asset = _assets[assetIndex];
    final next = Set<int>.from(_gridController.value.selectedIndexes);
    if (next.contains(gridIndex)) {
      next.remove(gridIndex);
    } else {
      if (_selected.length >= ProductGalleryPicker.maxAssets &&
          !_selectedIds.contains(asset.id)) {
        return;
      }
      next.add(gridIndex);
    }
    HapticFeedback.selectionClick();
    _gridController.value = Selection(next);
  }

  Future<void> _confirmWithAssets(
    List<AssetEntity> assets, {
    int initialIndex = 0,
  }) async {
    final sw = Stopwatch()..start();
    _closeAlbumMenu();
    if (assets.isEmpty) return;

    // Snapshot before releasing grid history (which empties controller indexes).
    final selected = List<AssetEntity>.from(
      assets.take(ProductGalleryPicker.maxAssets),
    );
    final n = selected.length;
    _composeNavPerf('confirm_enter', n: n, sw: sw);
    final targetId =
        initialIndex >= 0 && initialIndex < selected.length
            ? selected[initialIndex].id
            : null;
    _releaseGridLocalHistory();

    // Detach Texture immediately so compose is not blocked on native CameraX
    // Binder close (~100–500ms). Dispose continues on [_cameraDisposeQueue];
    // next camera open awaits that queue (Xiaomi-safe).
    final cam = _detachLiveCamera();
    unawaited(ProductGalleryPicker._enqueueCameraDispose(cam));
    _composeNavPerf('camera_detached_dispose_queued', n: n, sw: sw);

    _composeNavPerf('paths_resolve_start', n: n, sw: sw);
    // Hero path first → warm decode while the rest resolve (compose feels
    // stuck until the first photo paints; overlap IO with decode).
    final heroIndex =
        targetId == null
            ? 0
            : selected.indexWhere((a) => a.id == targetId).clamp(0, n - 1).toInt();
    final files = List<File?>.filled(selected.length, null);
    files[heroIndex] = await ProductGalleryPicker._safeAssetFile(
      selected[heroIndex],
    );
    final heroPath = files[heroIndex]?.path.trim() ?? '';
    if (heroPath.isNotEmpty) {
      ProductGalleryPicker.warmComposeHeroDecode(heroPath);
      _composeNavPerf('paths_hero_warmed', n: n, sw: sw);
    }
    // Remaining paths — one parallel batch (n ≤ 50).
    if (n > 1) {
      await Future.wait([
        for (var i = 0; i < selected.length; i++)
          if (i != heroIndex)
            ProductGalleryPicker._safeAssetFile(selected[i]).then((f) {
              files[i] = f;
            }),
      ]);
    }
    final paths = <String>[];
    var resolvedInitial = 0;
    for (var i = 0; i < selected.length; i++) {
      final path = files[i]?.path.trim() ?? '';
      if (path.isEmpty) continue;
      if (targetId != null && selected[i].id == targetId) {
        resolvedInitial = paths.length;
      }
      paths.add(path);
    }
    // If hero file failed but others succeeded, still warm the shown path.
    if (heroPath.isEmpty && paths.isNotEmpty) {
      final warmIdx = resolvedInitial.clamp(0, paths.length - 1);
      ProductGalleryPicker.warmComposeHeroDecode(paths[warmIdx]);
    }
    _composeNavPerf('paths_resolve_end', n: paths.length, sw: sw);

    if (!mounted) return;
    if (paths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to read the selected photos.')),
      );
      return;
    }
    _composeNavPerf('gallery_pop', n: paths.length, sw: sw);
    Navigator.of(context).pop(
      _GallerySheetResult.paths(paths, initialIndex: resolvedInitial),
    );
  }

  void _closeSheet() {
    _closeAlbumMenu();
    _releaseGridLocalHistory();
    // Fire-and-forget; confirm also queues dispose (does not block pop).
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
    final bottomInset = media.padding.bottom;

    // Material root: rounded sheet surface + DefaultTextStyle (no yellow
    // underlines under PopupRoute).
    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      clipBehavior: Clip.hardEdge,
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
                      ValueListenableBuilder<int>(
                        valueListenable: _selectedCount,
                        builder: (context, selectedCount, _) {
                          if (widget.confirmAsSend) {
                            return _WhatsAppSendConfirmButton(
                              count: selectedCount,
                              onPressed:
                                  selectedCount == 0 ? null : _confirm,
                            );
                          }
                          return TextButton(
                            onPressed:
                                selectedCount == 0 ? null : _confirm,
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
                          );
                        },
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
                          ? 'Camera · tap to select · hold & slide · tap again to send'
                          : 'Tap to select · hold & slide · tap again to send',
                      style: AppTextStyles.caption(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                Expanded(child: _buildBody()),
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
    if (_error != null && _assets.isEmpty && !widget.includeCamera) {
      return Center(
        child: Padding(
          padding: AppPadding.screenHorizontal,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary(),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => PhotoManager.openSetting(),
                child: Text(
                  'Open Settings',
                  style: AppTextStyles.button(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_assets.isEmpty && !widget.includeCamera && !_bootstrapping) {
      return Center(
        child: Text('No photos found', style: AppTextStyles.bodySecondary()),
      );
    }

    if (widget.includeCamera) {
      return _buildTelegramBody();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = AppPadding.horizontal;
        final contentW = constraints.maxWidth - (pad * 2);
        final cell = (contentW - (_gap * (_gridCount - 1))) / _gridCount;
        final thumbSize = _thumbSizeForCell(cell);
        return DragSelectGridView(
          scrollController: _scrollController,
          gridController: _gridController,
          triggerSelectionOnTap: false,
          impliesAppBarDismissal: false,
          addAutomaticKeepAlives: false,
          physics: _gridPhysics,
          cacheExtent: _cacheExtent,
          padding: AppPadding.screenHorizontal,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _gridCount,
            crossAxisSpacing: _gap,
            mainAxisSpacing: _gap,
          ),
          itemCount: _gridItemCount,
          itemBuilder: (context, index, selected) {
            final assetIndex = _assetIndexForGridIndex(index);
            if (assetIndex == null) {
              return _bootstrapping
                  ? _placeholderTile()
                  : const SizedBox.expand();
            }
            final asset = _assets[assetIndex];
            final isSelected = selected || _selectedIds.contains(asset.id);
            final number = isSelected ? _selectionNumber(asset) : null;
            return _GalleryTile(
              key: ValueKey<String>(asset.id),
              asset: asset,
              thumbSize: thumbSize,
              selected: isSelected,
              number: number,
              onOpen: () => _openFromPhotoBody(asset),
              onToggleSelect: () => _toggleAssetAt(assetIndex),
            );
          },
        );
      },
    );
  }

  /// Camera spans 2 cols × 3 rows; photos fill the rest of a single
  /// [DragSelectGridView] so hold-and-slide continues from the side band
  /// into row 4+ in one gesture.
  Widget _buildTelegramBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = AppPadding.horizontal;
        final contentW = constraints.maxWidth - (pad * 2);
        final cell = (contentW - (_gap * (_gridCount - 1))) / _gridCount;
        final cameraH = cell * _cameraSpanRows + _gap * (_cameraSpanRows - 1);
        final cameraW =
            cell * _cameraSpanCols + _gap * (_cameraSpanCols - 1);
        final thumbSize = _thumbSizeForCell(cell);

        // Clip so the camera overlay scrolls away with the grid instead of
        // staying pinned and covering lower photos.
        return ClipRect(
          child: Stack(
            children: [
              DragSelectGridView(
                scrollController: _scrollController,
                gridController: _gridController,
                triggerSelectionOnTap: false,
                impliesAppBarDismissal: false,
                addAutomaticKeepAlives: false,
                physics: _gridPhysics,
                cacheExtent: _cacheExtent,
                padding: AppPadding.screenHorizontal,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _gridCount,
                  crossAxisSpacing: _gap,
                  mainAxisSpacing: _gap,
                ),
                itemCount: _gridItemCount,
                itemBuilder: (context, index, selected) {
                  final assetIndex = _assetIndexForGridIndex(index);
                  if (assetIndex == null) {
                    if (_isCameraHole(index)) {
                      return const SizedBox.expand();
                    }
                    return _bootstrapping
                        ? _placeholderTile()
                        : const SizedBox.expand();
                  }
                  final asset = _assets[assetIndex];
                  final isSelected =
                      selected || _selectedIds.contains(asset.id);
                  final number = isSelected ? _selectionNumber(asset) : null;
                  return _GalleryTile(
                    key: ValueKey<String>(asset.id),
                    asset: asset,
                    thumbSize: thumbSize,
                    selected: isSelected,
                    number: number,
                    onOpen: () => _openFromPhotoBody(asset),
                    onToggleSelect: () => _toggleAssetAt(assetIndex),
                  );
                },
              ),
              // Live camera stays on while scrolling (Telegram). Preview is a
              // stable [AnimatedBuilder] child — only Transform updates.
              _ScrollLinkedCameraOverlay(
                scrollController: _scrollController,
                liveCamera: _liveCamera,
                left: pad,
                width: cameraW,
                height: cameraH,
                onTap: _openingCamera ? null : _openCameraFromCell,
              ),
              if (_assets.isEmpty && !_bootstrapping)
                AnimatedBuilder(
                  animation: _scrollController,
                  builder: (context, _) {
                    final offset =
                        _scrollController.hasClients
                            ? _scrollController.offset
                            : 0.0;
                    return Positioned(
                      left: 0,
                      right: 0,
                      top: cameraH + 24 - offset,
                      child: Padding(
                        padding: AppPadding.screenHorizontal,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _error ?? 'No photos found',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodySecondary(),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => PhotoManager.openSetting(),
                                child: Text(
                                  'Open Settings',
                                  style: AppTextStyles.button(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Translates the live camera with scroll without rebuilding the photo grid.
/// [CameraPreview] stays mounted as [AnimatedBuilder.child] (Telegram: live
/// while scrolling).
class _ScrollLinkedCameraOverlay extends StatelessWidget {
  const _ScrollLinkedCameraOverlay({
    required this.scrollController,
    required this.liveCamera,
    required this.left,
    required this.width,
    required this.height,
    this.onTap,
  });

  final ScrollController scrollController;
  final ValueNotifier<CameraController?> liveCamera;
  final double left;
  final double width;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Stable preview subtree — only swaps when controller instance changes.
    final preview = ValueListenableBuilder<CameraController?>(
      valueListenable: liveCamera,
      builder: (context, controller, _) {
        return RepaintBoundary(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: _LiveCameraTile(controller: controller),
          ),
        );
      },
    );

    return AnimatedBuilder(
      animation: scrollController,
      child: SizedBox(width: width, height: height, child: preview),
      builder: (context, child) {
        final offset =
            scrollController.hasClients ? scrollController.offset : 0.0;
        // Fully off-screen: skip Transform (VisibilityDetector pauses preview).
        if (offset >= height) {
          return const SizedBox.shrink();
        }
        return Positioned(
          left: left,
          top: 0,
          width: width,
          height: height,
          child: ClipRect(
            clipBehavior: Clip.hardEdge,
            child: Transform.translate(
              offset: Offset(0, -offset),
              filterQuality: FilterQuality.none,
              child: child,
            ),
          ),
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
/// Until ready: Telegram-style blurred placeholder (not solid black).
///
/// Pauses CameraX preview when scrolled off-screen or app backgrounded
/// ([pausePreview] / [resumePreview]) — keeps the controller for fast resume.
class _LiveCameraTile extends StatefulWidget {
  const _LiveCameraTile({required this.controller});

  final CameraController? controller;

  @override
  State<_LiveCameraTile> createState() => _LiveCameraTileState();
}

class _LiveCameraTileState extends State<_LiveCameraTile>
    with WidgetsBindingObserver {
  bool _visible = true;
  bool _appResumed = true;
  bool _busy = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant _LiveCameraTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      unawaited(_syncPreview());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    unawaited(_syncPreview());
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final nextVisible = info.visibleFraction >= 0.35;
    if (_visible == nextVisible) return;
    _visible = nextVisible;
    unawaited(_syncPreview());
  }

  Future<void> _syncPreview() async {
    if (_busy || _disposed) return;
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) return;

    final shouldRun = _visible && _appResumed;
    final isPaused = controller.value.isPreviewPaused;
    if (shouldRun == !isPaused) return;

    _busy = true;
    try {
      if (shouldRun) {
        await controller.resumePreview();
      } else {
        await controller.pausePreview();
      }
      if (mounted && !_disposed) setState(() {});
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Gallery camera preview transition failed: $e');
      }
    } finally {
      _busy = false;
      if (!_disposed &&
          mounted &&
          _visible &&
          _appResumed &&
          widget.controller != null &&
          widget.controller!.value.isInitialized &&
          widget.controller!.value.isPreviewPaused) {
        unawaited(_syncPreview());
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cam = widget.controller;
    final ready = cam != null && cam.value.isInitialized;
    final showLive =
        ready && _visible && _appResumed && !cam.value.isPreviewPaused;

    return VisibilityDetector(
      key: const Key('product-gallery-camera-tile'),
      onVisibilityChanged: _onVisibilityChanged,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showLive)
              _CameraPreviewCover(controller: cam)
            else
              const _CameraBlurPlaceholder(),
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
      ),
    );
  }
}

/// Soft frosted / blurred camera stand-in (Telegram) until live preview binds.
/// Blur is clipped to this cell only — same glass language as frosted pills.
class _CameraBlurPlaceholder extends StatelessWidget {
  const _CameraBlurPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Soft grey wash so blur has tone even before blobs paint.
          ColoredBox(color: AppColors.surfaceSecondary),
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: const Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: Color(0xFF3D4450)),
                Positioned(
                  left: -48,
                  top: -36,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF6E7C91),
                    ),
                    child: SizedBox(width: 200, height: 200),
                  ),
                ),
                Positioned(
                  right: -56,
                  bottom: -48,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF505A6A),
                    ),
                    child: SizedBox(width: 220, height: 220),
                  ),
                ),
                Positioned(
                  right: 24,
                  top: 32,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF8A959F),
                    ),
                    child: SizedBox(width: 120, height: 120),
                  ),
                ),
              ],
            ),
          ),
          // Light frost wash on top of the blurred blobs.
          ColoredBox(color: Colors.white.withValues(alpha: 0.08)),
        ],
      ),
    );
  }
}

/// Stable cover-crop of [CameraPreview] — preview element rebuilt only when
/// the controller instance changes (not on every scroll/layout tick).
class _CameraPreviewCover extends StatefulWidget {
  const _CameraPreviewCover({required this.controller});

  final CameraController controller;

  @override
  State<_CameraPreviewCover> createState() => _CameraPreviewCoverState();
}

class _CameraPreviewCoverState extends State<_CameraPreviewCover> {
  late Widget _preview;

  @override
  void initState() {
    super.initState();
    _preview = CameraPreview(widget.controller);
  }

  @override
  void didUpdateWidget(covariant _CameraPreviewCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _preview = CameraPreview(widget.controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.value.isInitialized) {
      return const _CameraBlurPlaceholder();
    }
    final aspect = widget.controller.value.aspectRatio;
    if (aspect <= 0) return _preview;

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
                child: _preview,
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
    super.key,
    required this.asset,
    required this.thumbSize,
    required this.selected,
    required this.number,
    this.onOpen,
    this.onToggleSelect,
  });

  final AssetEntity asset;
  final ThumbnailSize thumbSize;
  final bool selected;
  final int? number;
  final VoidCallback? onOpen;
  final VoidCallback? onToggleSelect;

  @override
  Widget build(BuildContext context) {
    // Isolate drag-select chrome repaints from the decoded thumb.
    return RepaintBoundary(
      child: ColoredBox(
        color: AppColors.surfaceSecondary,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _GalleryThumbImage(
              key: ValueKey<String>('img_${asset.id}'),
              asset: asset,
              thumbSize: thumbSize,
              onOpen: onOpen,
            ),
            if (selected)
              IgnorePointer(
                child: ColoredBox(
                  color: AppColors.primary.withValues(alpha: 0.38),
                ),
              ),
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggleSelect,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? AppColors.primary : Colors.black45,
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Image-only subtree so selection updates do not recreate the provider.
class _GalleryThumbImage extends StatelessWidget {
  const _GalleryThumbImage({
    super.key,
    required this.asset,
    required this.thumbSize,
    this.onOpen,
  });

  final AssetEntity asset;
  final ThumbnailSize thumbSize;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Image(
        image: _GalleryThumbProviders.of(asset, thumbSize),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.none,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return ColoredBox(color: AppColors.surfaceSecondary);
        },
        errorBuilder:
            (_, __, ___) => Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: AppColors.textHint,
                size: 22,
              ),
            ),
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
      await ProductGalleryPicker.awaitPendingCameraDispose();
      if (!mounted) return;
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
            Stack(
              fit: StackFit.expand,
              children: [
                const _CameraBlurPlaceholder(),
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
                          : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.photo_camera_rounded,
                                size: 40,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Camera',
                                style: AppTextStyles.caption(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                ),
              ],
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

/// WhatsApp-style green send circle with selection count badge.
class _WhatsAppSendConfirmButton extends StatelessWidget {
  const _WhatsAppSendConfirmButton({
    required this.count,
    required this.onPressed,
  });

  final int count;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && count > 0;
    final green = AppColors.success;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          customBorder: const CircleBorder(),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: SizedBox(
            width: 48,
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: green,
                  ),
                  child: const Center(
                    child: Padding(
                      // Material send points up-right; nudge like WhatsApp.
                      padding: EdgeInsets.only(left: 2),
                      child: Icon(
                        Icons.send_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (count > 0)
                  Positioned(
                    top: -2,
                    right: 0,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: green, width: 1.2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: AppTextStyles.caption(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: green,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
