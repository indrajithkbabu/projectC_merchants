import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fast_thumbhash/fast_thumbhash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:project_c/helper/catalog_media_debug.dart';
import 'package:project_c/helper/catalog_responsive_image.dart';
import 'package:project_c/helper/colors.dart';

/// File-based image cache (JSON index) — avoids sqflite / MissingPluginException
/// when the default [DefaultCacheManager] DB channel is not registered yet.
///
/// Scale model (1000s of photos):
/// - **Disk**: warm aggressively (LRU file cache) — never re-download
/// - **Decode / ImageCache**: only the visible window + small lookahead —
///   never decode an entire catalog into RAM
/// - **Paint**: stable [ResizeImage] width so pinch-zoom remounts hit the same
///   memory key; disk-warm URLs skip placeholder flash
class CatalogImageCache {
  CatalogImageCache._();

  static final CacheManager instance = CacheManager(
    Config(
      'catalogImages',
      stalePeriod: const Duration(days: 21),
      // Large catalogs (1000s of tiles) — disk LRU, not memory.
      maxNrOfCacheObjects: 10000,
      repo: JsonCacheInfoRepository(databaseName: 'catalogImages'),
    ),
  );

  /// Default max bitmaps to decode per warm call (viewport-sized).
  static const int defaultMaxDecode = 48;

  /// URLs known to have a local file (after warm / successful paint).
  static final Set<String> _diskReady = <String>{};

  /// Local file path for disk-warm URLs (FileImage — sync paint on reopen).
  static final Map<String, String> _filePaths = <String, String>{};

  /// Decode keys (`url@cacheWidth`) already resolved into [ImageCache] this session.
  static final Set<String> _decodedKeys = <String>{};

  /// In-flight disk fetches (dedupe concurrent warms).
  static final Map<String, Future<void>> _diskInFlight = {};

  /// In-flight decode warms (dedupe).
  static final Map<String, Future<void>> _decodeInFlight = {};

  /// True when [url] was downloaded/cached on disk this session.
  static bool isDiskWarm(String url) => _diskReady.contains(url.trim());

  /// True when [url] was decoded at [cacheWidth] (warm or successful paint).
  static bool isDecoded(String url, int cacheWidth) =>
      _decodedKeys.contains('${url.trim()}@$cacheWidth');

  /// Local path when [url] is on disk (null if not probed/warmed yet).
  static String? diskPath(String url) => _filePaths[url.trim()];

  /// Mark [url] as disk-ready (e.g. after a successful first paint).
  static void markDiskWarm(String url, {String? filePath}) {
    final value = url.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      _diskReady.add(value);
      final path = filePath?.trim() ?? '';
      if (path.isNotEmpty) _filePaths[value] = path;
    }
  }

  /// Mark [url] as decoded at [cacheWidth] so remounts skip placeholder flash.
  static void markDecoded(String url, int cacheWidth) {
    final value = url.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      _decodedKeys.add('$value@$cacheWidth');
    }
  }

  /// How many Media-grid tiles to decode-warm for ~[screens] of a [columns]
  /// grid. Capped so [ImageCache] is not thrashed on dense 9-col layouts.
  static int mediaGridWarmCount({
    required int columns,
    double screens = 1.75,
  }) {
    final cols = columns.clamp(2, 9);
    final view = _primaryView;
    if (view == null) return (cols * 12 * screens).round().clamp(36, 96);
    final dpr = view.devicePixelRatio;
    final screenW = view.physicalSize.width / dpr;
    final screenH = view.physicalSize.height / dpr;
    final cell = (screenW / cols).clamp(1.0, screenW);
    final rows = (screenH / cell).ceil() + 3;
    return (cols * rows * screens).round().clamp(36, 96);
  }

  /// Drops disk + memory image cache (logout / delete account).
  static Future<void> clearAll() async {
    _diskReady.clear();
    _filePaths.clear();
    _decodedKeys.clear();
    _diskInFlight.clear();
    _decodeInFlight.clear();
    try {
      await instance.emptyCache();
    } catch (_) {}
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  /// Half-screen decode width — shared by all grids / channel / collage / zoom.
  static int gridCacheWidth() {
    final view = _primaryView;
    if (view == null) return 800;
    final dpr = view.devicePixelRatio;
    final screenW = view.physicalSize.width / dpr;
    return ((screenW / 2) * dpr).round().clamp(1, 4096);
  }

  /// ~¾-screen decode for Media zoom-in / Single view (`detailUrl` tier).
  static int detailCacheWidth() {
    final view = _primaryView;
    if (view == null) return 1080;
    final dpr = view.devicePixelRatio;
    final screenW = view.physicalSize.width / dpr;
    return ((screenW * 0.75) * dpr).round().clamp(1, 4096);
  }

  /// Full-screen decode width for heroes / product details.
  static int fullCacheWidth() {
    final view = _primaryView;
    if (view == null) return 1200;
    final dpr = view.devicePixelRatio;
    final screenW = view.physicalSize.width / dpr;
    return (screenW * dpr).round().clamp(1, 4096);
  }

  /// Decode width matching [CatalogImageRole] so warm + paint share one key.
  static int cacheWidthForRole(CatalogImageRole role) {
    return switch (role) {
      CatalogImageRole.grid => gridCacheWidth(),
      CatalogImageRole.detail => detailCacheWidth(),
      CatalogImageRole.zoom => fullCacheWidth(),
    };
  }

  /// Stable decode width for store/profile circular avatars (shared memory key).
  static int avatarCacheWidth() {
    final view = _primaryView;
    final dpr = view?.devicePixelRatio ?? 2.0;
    // Covers listing (~52), header (~36), profile picker (~104).
    return (112 * dpr).round().clamp(64, 512);
  }

  static ui.FlutterView? get _primaryView {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return null;
    return views.first;
  }

  static List<String> _normalize(Iterable<String> urls) {
    return urls
        .map((u) => u.trim())
        .where((u) => u.startsWith('http://') || u.startsWith('https://'))
        .toSet()
        .toList(growable: false);
  }

  /// Shared [ImageProvider] used by widgets + decode warm (same cache key).
  ///
  /// Prefers [FileImage] when the file is already on disk so cold reopen can
  /// paint without waiting on [CachedNetworkImageProvider] async resolve.
  static ImageProvider providerFor(
    String url, {
    required int cacheWidth,
  }) {
    final value = url.trim();
    final path = _filePaths[value];
    final ImageProvider provider;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      provider = FileImage(File(path));
    } else {
      provider = CachedNetworkImageProvider(
        value,
        cacheManager: instance,
      );
    }
    return ResizeImage.resizeIfNeeded(cacheWidth, null, provider);
  }

  /// Avatar-sized provider (listing / profile / nav) — one memory key.
  static ImageProvider avatarProvider(String url) {
    return providerFor(url, cacheWidth: avatarCacheWidth());
  }

  /// Re-attach disk hits after process restart (files still on disk).
  static Future<void> probeDisk(Iterable<String> urls) async {
    final pending = [
      for (final url in _normalize(urls))
        if (!_filePaths.containsKey(url)) url,
    ];
    if (pending.isEmpty) return;
    await Future.wait([
      for (final url in pending) _probeOne(url),
    ]);
  }

  static Future<void> _probeOne(String url) async {
    try {
      final info = await instance.getFileFromCache(url);
      if (info == null) return;
      if (!await info.file.exists()) return;
      _diskReady.add(url);
      _filePaths[url] = info.file.path;
    } catch (_) {}
  }

  /// Probe disk + decode avatars into [ImageCache] (store covers / profile).
  ///
  /// Call before first listing/profile paint on reopen so avatars don't flash.
  static Future<void> warmAvatars(
    Iterable<String> urls, {
    int concurrency = 6,
  }) async {
    final pending = _normalize(urls);
    if (pending.isEmpty) return;
    await probeDisk(pending);
    await _diskWarmAll(pending, concurrency: concurrency);
    await _decodeWarmAll(
      pending,
      cacheWidth: avatarCacheWidth(),
      concurrency: concurrency,
    );
  }

  /// Warm files onto disk. Safe for 1000s of URLs (no decode).
  ///
  /// Set [decode] + [maxDecode] only for a small visible window — decoding an
  /// entire catalog thrashs [ImageCache] and causes zoom flash.
  static Future<void> precacheUrls(
    Iterable<String> urls, {
    int concurrency = 8,
    bool decode = false,
    int maxDecode = defaultMaxDecode,
    int? cacheWidth,
  }) async {
    final pending = _normalize(urls);
    if (pending.isEmpty) return;

    await _diskWarmAll(pending, concurrency: concurrency);

    if (!decode || maxDecode <= 0) return;
    final width = cacheWidth ?? gridCacheWidth();
    final toDecode = pending.take(maxDecode).toList(growable: false);
    await _decodeWarmAll(toDecode, cacheWidth: width, concurrency: concurrency);
  }

  /// Raise [ImageCache] budget for catalog grids (dense Media / collage).
  static void ensureCatalogMemoryBudget() {
    final cache = PaintingBinding.instance.imageCache;
    // ~150MB / 220 live entries — enough for a dense Media viewport without
    // immediately evicting tiles that were just warmed for pinch zoom-out.
    if (cache.maximumSizeBytes < 150 << 20) {
      cache.maximumSizeBytes = 150 << 20;
    }
    if (cache.maximumSize < 220) {
      cache.maximumSize = 220;
    }
  }

  /// Viewport warm for long grids: disk for [diskPad] around the window,
  /// decode only `[firstIndex … lastIndex]` (clamped). Scales to 1000s.
  static Future<void> warmWindow({
    required List<String> urls,
    required int firstIndex,
    required int lastIndex,
    int diskPad = 48,
    int? cacheWidth,
    int concurrency = 8,
  }) async {
    ensureCatalogMemoryBudget();
    final normalized = [
      for (final u in urls)
        if (u.trim().startsWith('http')) u.trim(),
    ];
    if (normalized.isEmpty) return;

    final n = normalized.length;
    final start = firstIndex.clamp(0, n - 1);
    final end = lastIndex.clamp(0, n - 1);
    if (end < start) return;

    final diskStart = math.max(0, start - diskPad);
    final diskEnd = math.min(n, end + 1 + diskPad);
    final diskSlice = normalized.sublist(diskStart, diskEnd);
    final decodeSlice = normalized.sublist(start, end + 1);

    final width = cacheWidth ?? gridCacheWidth();
    CatalogMediaDebug.warm(
      'warmWindow urls=${normalized.length} decode=$start..$end '
      '(${decodeSlice.length}) diskPad=${diskSlice.length} cacheW=$width '
      'concurrency=$concurrency',
    );
    await _diskWarmAll(diskSlice, concurrency: concurrency);
    await _decodeWarmAll(
      decodeSlice,
      cacheWidth: width,
      concurrency: concurrency,
    );
    CatalogMediaDebug.warm(
      'warmWindow done decode=${decodeSlice.length} cacheW=$width',
    );
  }

  /// Warm a vertical square grid from scroll metrics + viewport width.
  static Future<void> warmGridWindow({
    required List<String> urls,
    required ScrollMetrics metrics,
    required int crossAxisCount,
    required double viewportWidth,
    double spacing = 2,
    int rowPad = 3,
    int? cacheWidth,
  }) async {
    if (urls.isEmpty || crossAxisCount <= 0) return;
    final cols = crossAxisCount;
    final cell =
        (viewportWidth - spacing * (cols - 1)).clamp(1.0, viewportWidth) / cols;
    final stride = cell + spacing;
    final firstRow =
        math.max(0, ((metrics.pixels - spacing) / stride).floor() - rowPad);
    final visibleRows =
        (metrics.viewportDimension / stride).ceil() + rowPad * 2;
    final first = firstRow * cols;
    final last = math.min(urls.length - 1, first + visibleRows * cols - 1);
    await warmWindow(
      urls: urls,
      firstIndex: first,
      lastIndex: last,
      cacheWidth: cacheWidth,
    );
  }

  /// Warm around scroll progress for non-uniform layouts (headers, sections).
  ///
  /// Maps [ScrollMetrics.pixels] → URL index; decodes only [windowSize] tiles.
  static Future<void> warmAroundScroll({
    required List<String> urls,
    required ScrollMetrics metrics,
    int windowSize = defaultMaxDecode,
    int? cacheWidth,
  }) async {
    if (urls.isEmpty) return;
    final n = urls.length;
    if (metrics.maxScrollExtent <= 0) {
      await warmWindow(
        urls: urls,
        firstIndex: 0,
        lastIndex: math.min(n - 1, windowSize - 1),
        cacheWidth: cacheWidth,
      );
      return;
    }
    final t = (metrics.pixels / metrics.maxScrollExtent).clamp(0.0, 1.0);
    final center = (t * (n - 1)).round();
    final half = math.max(1, windowSize ~/ 2);
    await warmWindow(
      urls: urls,
      firstIndex: center - half,
      lastIndex: center + half,
      cacheWidth: cacheWidth,
    );
  }

  static Future<void> _diskWarmAll(
    List<String> urls, {
    required int concurrency,
  }) async {
    final need = [
      for (final url in urls)
        if (!_diskReady.contains(url)) url,
    ];
    if (need.isEmpty) return;

    for (var i = 0; i < need.length; i += concurrency) {
      final end = math.min(i + concurrency, need.length);
      await Future.wait([
        for (final url in need.sublist(i, end)) _diskWarmOne(url),
      ]);
    }
  }

  static Future<void> _diskWarmOne(String url) {
    final existing = _diskInFlight[url];
    if (existing != null) return existing;
    final future = instance
        .getSingleFile(url)
        .then<void>((file) {
          _diskReady.add(url);
          _filePaths[url] = file.path;
        })
        .catchError((_) {})
        .whenComplete(() {
          _diskInFlight.remove(url);
        });
    _diskInFlight[url] = future;
    return future;
  }

  static Future<void> _decodeWarmAll(
    List<String> urls, {
    required int cacheWidth,
    required int concurrency,
  }) async {
    if (urls.isEmpty) return;
    for (var i = 0; i < urls.length; i += concurrency) {
      final end = math.min(i + concurrency, urls.length);
      await Future.wait([
        for (final url in urls.sublist(i, end))
          _decodeIntoMemory(url, cacheWidth),
      ]);
    }
  }

  /// Decode [url] into Flutter's [ImageCache] at [cacheWidth] (no context).
  static Future<void> _decodeIntoMemory(String url, int cacheWidth) {
    final key = '$url@$cacheWidth';
    final existing = _decodeInFlight[key];
    if (existing != null) return existing;

    final future = () async {
      try {
        // Prefer file on disk first so decode never hits the network.
        if (!_diskReady.contains(url)) {
          await _diskWarmOne(url);
        }
        final dpr = _primaryView?.devicePixelRatio ?? 2.0;
        final provider = providerFor(url, cacheWidth: cacheWidth);
        final stream = provider.resolve(
          ImageConfiguration(devicePixelRatio: dpr),
        );
        final done = Completer<void>();
        late ImageStreamListener listener;
        var decoded = false;
        listener = ImageStreamListener(
          (ImageInfo info, bool synchronousCall) {
            decoded = true;
            markDecoded(url, cacheWidth);
            stream.removeListener(listener);
            if (!done.isCompleted) done.complete();
          },
          onError: (Object error, StackTrace? stackTrace) {
            stream.removeListener(listener);
            if (!done.isCompleted) done.complete();
          },
        );
        stream.addListener(listener);
        await done.future.timeout(
          const Duration(seconds: 20),
          onTimeout: () {},
        );
        if (decoded) markDiskWarm(url);
      } catch (_) {}
    }();

    _decodeInFlight[key] = future;
    return future.whenComplete(() {
      _decodeInFlight.remove(key);
    });
  }
}

/// Shared helpers for product/collection media (local path or remote URL).
class ProductImagePaths {
  ProductImagePaths._();

  static bool isNetwork(String path) {
    final value = path.trim();
    return value.startsWith('http://') || value.startsWith('https://');
  }

  static bool isDisplayable(String path) {
    final value = path.trim();
    if (value.isEmpty) return false;
    if (isNetwork(value)) return true;
    return File(value).existsSync();
  }

  static List<String> displayable(List<String> paths) {
    return paths.where(isDisplayable).toList(growable: false);
  }

  /// Local [File] for sharing: existing path, or disk-cached network URL.
  static Future<File?> resolveLocalFile(String path) async {
    final value = path.trim();
    if (value.isEmpty) return null;
    if (isNetwork(value)) {
      try {
        return await CatalogImageCache.instance.getSingleFile(value);
      } catch (_) {
        return null;
      }
    }
    final file = File(value);
    if (!file.existsSync()) return null;
    return file;
  }

  static ImageProvider? provider(String path) {
    final value = path.trim();
    if (value.isEmpty) return null;
    if (isNetwork(value)) {
      return CachedNetworkImageProvider(
        value,
        cacheManager: CatalogImageCache.instance,
      );
    }
    final file = File(value);
    if (!file.existsSync()) return null;
    return FileImage(file);
  }

  /// Parse a base64 ThumbHash, or null on failure.
  static ThumbHash? parseThumbhash(String? thumbhashBase64) {
    final raw = thumbhashBase64?.trim() ?? '';
    if (raw.isEmpty) return null;
    try {
      final decoded = base64Decode(base64.normalize(raw));
      if (decoded.length < 5) return null;
      return ThumbHash.fromBytes(Uint8List.fromList(decoded));
    } catch (_) {
      return null;
    }
  }

  /// Average color from a ThumbHash — safe solid fill when blur decode fails.
  static Color? thumbhashAverageColor(String? thumbhashBase64) {
    try {
      return parseThumbhash(thumbhashBase64)?.toAverageColor();
    } catch (_) {
      return null;
    }
  }
}

/// InstantCatalogPhoto-style blur: RGBA → [RawImage] (no PNG [MemoryImage],
/// which threw "Could not decompress image" for some hashes).
class ThumbhashBlurPlaceholder extends StatefulWidget {
  const ThumbhashBlurPlaceholder({
    super.key,
    required this.thumbhash,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.fallbackColor,
  });

  final String thumbhash;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Color? fallbackColor;

  @override
  State<ThumbhashBlurPlaceholder> createState() =>
      _ThumbhashBlurPlaceholderState();
}

class _ThumbhashBlurPlaceholderState extends State<ThumbhashBlurPlaceholder> {
  ui.Image? _image;
  Color? _fallback;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant ThumbhashBlurPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thumbhash != widget.thumbhash) {
      _image?.dispose();
      _image = null;
      _fallback = null;
      _decode();
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    final hash = ProductImagePaths.parseThumbhash(widget.thumbhash);
    final average =
        widget.fallbackColor ??
        ProductImagePaths.thumbhashAverageColor(widget.thumbhash) ??
        AppColors.surfaceSecondary;
    if (hash == null) {
      if (!mounted) return;
      setState(() => _fallback = average);
      return;
    }
    try {
      final rgba = hash.toRGBA();
      if (rgba.width <= 0 ||
          rgba.height <= 0 ||
          rgba.rgba.length != rgba.width * rgba.height * 4) {
        if (!mounted) return;
        setState(() => _fallback = average);
        return;
      }
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        rgba.rgba,
        rgba.width,
        rgba.height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      final image = await completer.future;
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _image?.dispose();
        _image = image;
        _fallback = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _fallback = average);
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image != null) {
      return RawImage(
        image: image,
        fit: widget.fit,
        width: widget.width ?? double.infinity,
        height: widget.height ?? double.infinity,
      );
    }
    return ColoredBox(
      color: _fallback ?? widget.fallbackColor ?? AppColors.surfaceSecondary,
    );
  }
}

/// Renders a local file or remote URL with disk+memory cache for network URLs.
///
/// Cold miss → thumbhash / solid. Disk or [ImageCache] hit → immediate paint
/// (no fade), including after pinch-zoom rebuilds with the same decode width.
class ProductMediaImage extends StatelessWidget {
  const ProductMediaImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.thumbhash,
    this.thumbhashOnly = false,
    this.decodeCacheWidth,
    this.filterQuality = FilterQuality.low,
    this.error,
  });

  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;
  final String? thumbhash;

  /// Ignored (kept for call-site compatibility). Frontend guide InstantCatalogPhoto
  /// always loads the CDN URL; ThumbHash is placeholder only.
  final bool thumbhashOnly;

  /// When set (e.g. [CatalogImageCache.fullCacheWidth] on product-details zoom),
  /// skip layout-derived width so warm + paint + pinch rebuilds share one key.
  final int? decodeCacheWidth;

  /// Use [FilterQuality.medium] for pinch-zoom heroes; grids stay [low].
  final FilterQuality filterQuality;
  final Widget? error;

  /// Logical px for [ResizeImage] — must match [CatalogImageCache.gridCacheWidth]
  /// / [CatalogImageCache.fullCacheWidth] so warm + paint share one memory key.
  static double _decodeLogicalWidth(
    BuildContext context,
    BoxConstraints constraints,
    double? explicitWidth,
  ) {
    final screenW = MediaQuery.sizeOf(context).width;
    if (explicitWidth != null && explicitWidth.isFinite && explicitWidth > 0) {
      return explicitWidth;
    }
    final layoutW = constraints.maxWidth;
    if (layoutW.isFinite && layoutW >= screenW * 0.75) {
      return screenW;
    }
    // Grids / channel / collage: half-screen — stable across 2…9 column pinch.
    return screenW / 2;
  }

  Widget _placeholder() {
    final hash = thumbhash?.trim() ?? '';
    final average = ProductImagePaths.thumbhashAverageColor(thumbhash);
    if (hash.isNotEmpty) {
      return ThumbhashBlurPlaceholder(
        thumbhash: hash,
        fit: fit,
        width: width ?? double.infinity,
        height: height ?? double.infinity,
        fallbackColor: average ?? AppColors.surfaceSecondary,
      );
    }
    return ColoredBox(color: average ?? AppColors.surfaceSecondary);
  }

  @override
  Widget build(BuildContext context) {
    final value = path.trim();
    if (value.isEmpty) return error ?? _broken();

    if (ProductImagePaths.isNetwork(value)) {
      // InstantCatalogPhoto: always fetch CDN URL; ThumbHash is placeholder only.
      final fixedWidth = decodeCacheWidth;
      if (fixedWidth != null && fixedWidth > 0) {
        return _networkImage(value, cacheWidth: fixedWidth);
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final dpr = MediaQuery.devicePixelRatioOf(context);
          final logical = _decodeLogicalWidth(context, constraints, width);
          final cacheWidth = (logical * dpr).round().clamp(1, 4096);
          return _networkImage(value, cacheWidth: cacheWidth);
        },
      );
    }

    final file = File(value);
    if (!file.existsSync()) return error ?? _broken();

    return Image.file(
      file,
      fit: fit,
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => error ?? _broken(),
    );
  }

  Widget _networkImage(String value, {required int cacheWidth}) {
    final provider = CatalogImageCache.providerFor(
      value,
      cacheWidth: cacheWidth,
    );
    final alreadyDecoded = CatalogImageCache.isDecoded(value, cacheWidth);
    final hash = thumbhash;
    return Image(
      key: ValueKey('$value@$cacheWidth'),
      image: provider,
      fit: fit,
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      gaplessPlayback: true,
      filterQuality: filterQuality,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          CatalogImageCache.markDecoded(value, cacheWidth);
          if (frame != null) CatalogImageCache.markDiskWarm(value);
          CatalogMediaDebug.paintOnce(
            url: value,
            cacheWidth: cacheWidth,
            outcome: wasSynchronouslyLoaded ? 'syncFrame' : 'asyncFrame',
            thumbhash: hash,
            alreadyDecoded: alreadyDecoded,
          );
          return child;
        }
        // Prior decode at this width — avoid thumbhash flash on grid remount
        // (channel Media pinch / NestedScrollView rebuilds).
        if (alreadyDecoded) {
          CatalogMediaDebug.paintOnce(
            url: value,
            cacheWidth: cacheWidth,
            outcome: 'reuseDecoded',
            thumbhash: hash,
            alreadyDecoded: true,
          );
          return child;
        }
        // InstantCatalogPhoto: keep blur until the CDN frame arrives.
        CatalogMediaDebug.paintOnce(
          url: value,
          cacheWidth: cacheWidth,
          outcome: 'placeholder',
          thumbhash: hash,
          alreadyDecoded: false,
        );
        return _placeholder();
      },
      errorBuilder: (_, __, ___) {
        CatalogMediaDebug.gap(
          'paint ERROR ${CatalogMediaDebug.shortUrl(value)} '
          'cacheW=$cacheWidth ${CatalogMediaDebug.thumbhashFlag(hash)}',
        );
        return error ?? _broken();
      },
    );
  }

  static Widget _broken() {
    return ColoredBox(
      color: AppColors.surfaceSecondary,
      child: Icon(
        Icons.broken_image_outlined,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// Circular network avatar with disk/memory cache — no cold-open flicker.
///
/// Uses the same [CatalogImageCache.avatarProvider] as [warmAvatars] so
/// kill+reopen paints synchronously when the file is already on disk.
class CatalogNetworkAvatar extends StatelessWidget {
  const CatalogNetworkAvatar({
    super.key,
    required this.url,
    required this.size,
    this.backgroundColor,
    this.fallback,
    this.border,
  });

  final String url;
  final double size;
  final Color? backgroundColor;
  final Widget? fallback;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final value = url.trim();
    final bg = backgroundColor ?? AppColors.surfaceSecondary;
    if (value.isEmpty || !ProductImagePaths.isNetwork(value)) {
      return _shell(bg, fallback);
    }

    final provider = CatalogImageCache.avatarProvider(value);
    final diskWarm = CatalogImageCache.isDiskWarm(value);
    final cacheWidth = CatalogImageCache.avatarCacheWidth();

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: border,
        ),
        child: ClipOval(
          child: Image(
            key: ValueKey('avatar:$value@$cacheWidth'),
            image: provider,
            fit: BoxFit.cover,
            width: size,
            height: size,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) {
                if (frame != null) {
                  CatalogImageCache.markDiskWarm(
                    value,
                    filePath: CatalogImageCache.diskPath(value),
                  );
                }
                return child;
              }
              // Disk hit: keep decoding without flashing initials/color swap.
              if (diskWarm) return child;
              return fallback ?? const SizedBox.shrink();
            },
            errorBuilder: (_, __, ___) => fallback ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _shell(Color bg, Widget? child) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: child,
    );
  }
}
