import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:project_c/helper/catalog_media_debug.dart';
import 'package:project_c/models/product_view_mode.dart';

/// Screen role for Cloudflare R2 / Image Resizing variants.
///
/// Guide: grid → `thumbnailUrl`, detail → `detailUrl`, zoom → master `url`.
enum CatalogImageRole {
  /// Feed / search / collage / gallery tiles (BE thumb, ~360×360).
  grid,

  /// Product detail / bottom sheet (BE detail, ~1080px).
  detail,

  /// Pinch-to-zoom / full-screen master.
  zoom,
}

/// Parsed CDN variants for one catalog image.
class CatalogImageUrls {
  const CatalogImageUrls({
    this.url = '',
    this.thumbnailUrl = '',
    this.detailUrl = '',
    this.thumbhash = '',
    this.imageId = '',
  });

  final String url;
  final String thumbnailUrl;
  final String detailUrl;
  final String thumbhash;
  final String imageId;

  bool get hasMaster => url.trim().isNotEmpty;

  factory CatalogImageUrls.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const CatalogImageUrls();
    return CatalogImageUrls(
      url:
          (json['url'] as String?)?.trim() ??
          (json['publicUrl'] as String?)?.trim() ??
          '',
      thumbnailUrl: (json['thumbnailUrl'] as String?)?.trim() ?? '',
      detailUrl: (json['detailUrl'] as String?)?.trim() ?? '',
      thumbhash:
          (json['thumbhash'] as String?)?.trim() ??
          (json['thumbHash'] as String?)?.trim() ??
          '',
      imageId:
          (json['imageId'] as String?)?.trim() ??
          (json['image_id'] as String?)?.trim() ??
          (json['id'] as String?)?.trim() ??
          '',
    );
  }
}

/// Durable quality ladder: once the user has painted a higher CDN tier for an
/// image, lower-tier binds reuse that unlocked URL (no downgrade).
///
/// ```
/// thumbnailUrl → detailUrl → master url
/// ```
///
/// Persisted under the app **cache** directory so unlocks survive kill /
/// restart / logout. Removed only when the OS clears app cache or app data
/// (device Settings). Prefetch warm alone does not unlock.
class CatalogImageQualityLadder {
  CatalogImageQualityLadder._();

  static const _fileName = 'catalog_image_quality_ladder.json';
  static const _maxUrlsPerTier = 5000;

  /// Detail URLs unlocked (painted / opened) — durable across sessions.
  static final Set<String> _unlockedDetail = <String>{};

  /// Master URLs unlocked (painted / opened) — durable across sessions.
  static final Set<String> _unlockedMaster = <String>{};

  static bool _loaded = false;
  static Future<void>? _loadFuture;
  static Timer? _persistTimer;
  static bool _dirty = false;

  /// Load persisted unlocks before first store paint (call from [defaultMain]).
  static Future<void> ensureLoaded() {
    if (_loaded) return Future<void>.value();
    return _loadFuture ??= _loadFromDisk();
  }

  static bool isDetailUnlocked(String detailUrl) {
    final value = detailUrl.trim();
    return value.isNotEmpty && _unlockedDetail.contains(value);
  }

  static bool isMasterUnlocked(String masterUrl) {
    final value = masterUrl.trim();
    return value.isNotEmpty && _unlockedMaster.contains(value);
  }

  /// Highest unlocked tier for this image family, or null if none.
  static CatalogImageRole? unlockedTier({
    required String masterUrl,
    String detailUrl = '',
  }) {
    if (isMasterUnlocked(masterUrl)) return CatalogImageRole.zoom;
    if (isDetailUnlocked(detailUrl)) return CatalogImageRole.detail;
    return null;
  }

  /// Unlock detail tier for [detailUrl] (user opened / painted detail).
  static void unlockDetail(String detailUrl, {String? reason}) {
    final value = detailUrl.trim();
    if (value.isEmpty) return;
    if (!(value.startsWith('http://') || value.startsWith('https://'))) {
      return;
    }
    if (_unlockedDetail.add(value)) {
      _trim(_unlockedDetail);
      CatalogMediaDebug.render(
        'LADDER unlock=detail via=${reason ?? "explicit"} '
        '→ ${CatalogMediaDebug.shortUrl(value)}',
      );
      _schedulePersist();
    }
  }

  /// Unlock master tier for [masterUrl] (user opened / painted zoom).
  static void unlockMaster(String masterUrl, {String? reason}) {
    final value = masterUrl.trim();
    if (value.isEmpty) return;
    if (!(value.startsWith('http://') || value.startsWith('https://'))) {
      return;
    }
    if (_unlockedMaster.add(value)) {
      _trim(_unlockedMaster);
      CatalogMediaDebug.render(
        'LADDER unlock=zoom via=${reason ?? "explicit"} '
        '→ ${CatalogMediaDebug.shortUrl(value)}',
      );
      _schedulePersist();
    }
  }

  /// Mark [url] unlocked after a successful network paint.
  ///
  /// Thumbnail paints are ignored. Detail CDN (`width=1080`) unlocks detail;
  /// master (no resize transform) unlocks zoom.
  static void markPainted(String url) {
    final value = url.trim();
    if (value.isEmpty) return;
    if (!(value.startsWith('http://') || value.startsWith('https://'))) {
      return;
    }
    final tier = CatalogResponsiveImage.inferredTier(value);
    if (tier == CatalogImageRole.detail) {
      unlockDetail(value, reason: 'paint');
    } else if (tier == CatalogImageRole.zoom) {
      unlockMaster(value, reason: 'paint');
    }
  }

  /// True when [url] is an unlocked detail/master paint (ladder-upgraded tile).
  ///
  /// Used by [ProductMediaImage] to raise decode width / filter quality only
  /// for those tiles — cold thumbs stay cheap.
  static bool isUpgradePaint(String url) {
    final value = url.trim();
    if (value.isEmpty) return false;
    final tier = CatalogResponsiveImage.inferredTier(value);
    if (tier == CatalogImageRole.zoom) return isMasterUnlocked(value);
    if (tier == CatalogImageRole.detail) return isDetailUnlocked(value);
    return false;
  }

  static void _trim(Set<String> set) {
    if (set.length <= _maxUrlsPerTier) return;
    final list = set.toList(growable: false);
    set
      ..clear()
      ..addAll(list.sublist(list.length - _maxUrlsPerTier));
  }

  static void _schedulePersist() {
    _dirty = true;
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 400), () {
      // ignore: unawaited_futures
      _persistToDisk();
    });
  }

  static Future<File> _file() async {
    final dir = await getApplicationCacheDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<void> _loadFromDisk() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final raw = await file.readAsString();
        if (raw.trim().isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            final detail = decoded['detail'];
            final master = decoded['master'];
            if (detail is List) {
              for (final e in detail) {
                final s = e?.toString().trim() ?? '';
                if (s.startsWith('http')) _unlockedDetail.add(s);
              }
            }
            if (master is List) {
              for (final e in master) {
                final s = e?.toString().trim() ?? '';
                if (s.startsWith('http')) _unlockedMaster.add(s);
              }
            }
            _trim(_unlockedDetail);
            _trim(_unlockedMaster);
          }
        }
      }
      CatalogMediaDebug.render(
        'LADDER loaded detail=${_unlockedDetail.length} '
        'master=${_unlockedMaster.length}',
      );
    } catch (e) {
      CatalogMediaDebug.gap('LADDER load failed: $e');
    } finally {
      _loaded = true;
    }
  }

  static Future<void> _persistToDisk() async {
    if (!_dirty) return;
    _dirty = false;
    try {
      // Ensure load finished so we never overwrite disk with a partial set.
      await ensureLoaded();
      final file = await _file();
      final payload = jsonEncode({
        'detail': _unlockedDetail.toList(growable: false),
        'master': _unlockedMaster.toList(growable: false),
      });
      await file.writeAsString(payload, flush: true);
      CatalogMediaDebug.render(
        'LADDER persisted detail=${_unlockedDetail.length} '
        'master=${_unlockedMaster.length}',
      );
    } catch (e) {
      _dirty = true;
      CatalogMediaDebug.gap('LADDER persist failed: $e');
    }
  }
}

/// Resolve the correct CDN URL for a screen from BE fields only.
///
/// Missing `thumbnailUrl` / `detailUrl` → master (and a [CatalogMediaDebug.gap]
/// when logging) so incomplete BE payloads are visible as BE gaps, not masked
/// by FE CDN synthesis.
///
/// After the user paints detail/zoom, [CatalogImageQualityLadder] may upgrade a
/// lower [role] bind to the unlocked tier (thumb→detail→master, never down).
class CatalogResponsiveImage {
  CatalogResponsiveImage._();

  // --- FE CDN synth (DISABLED) — restore with resolve() call sites below ---
  // Kept so we can re-enable without rewriting transforms. Matches BE guide:
  // thumb ~360 @ q60 format=webp, detail ~1080 @ q75, fit=scale-down.
  //
  // static const mediaPathPrefix = '/v1/catalog/media/';
  // static const gridTransform =
  //     'width=360,height=360,fit=cover,quality=60,format=webp';
  // static const detailTransform =
  //     'width=1080,fit=scale-down,quality=75,format=webp';

  /// Classify a painted CDN URL into a ladder tier (null = unknown / ignore).
  ///
  /// BE contract: thumb `width=360`, detail `width=1080`. Other `cdn-cgi`
  /// transforms are ignored (no ladder unlock).
  static CatalogImageRole? inferredTier(String url) {
    final value = url.trim();
    if (value.isEmpty) return null;
    if (value.contains('width=360')) {
      return CatalogImageRole.grid;
    }
    if (value.contains('width=1080')) {
      return CatalogImageRole.detail;
    }
    // Unknown cdn-cgi transform — do not unlock.
    if (value.contains('/cdn-cgi/image/')) return null;
    return CatalogImageRole.zoom;
  }

  /// Pick URL for [role]. Uses BE `thumbnailUrl` / `detailUrl` / `url` only,
  /// then applies the session quality ladder when a higher tier is unlocked.
  static String resolve({
    required String masterUrl,
    String thumbnailUrl = '',
    String detailUrl = '',
    required CatalogImageRole role,
    bool log = false,
    String? context,
  }) {
    final master = masterUrl.trim();
    final thumb = thumbnailUrl.trim();
    final detail = detailUrl.trim();

    String chosen;
    String source;

    switch (role) {
      case CatalogImageRole.grid:
        if (thumb.isNotEmpty) {
          chosen = thumb;
          source = 'be.thumbnailUrl';
        } else {
          // FE synth disabled — do not build cdn-cgi here. Missing thumb is a
          // BE gap; paint master so QA/logs surface it.
          // final synth = synthesize(masterUrl: master, role: role);
          // if (synth != null && synth.isNotEmpty) {
          //   chosen = synth;
          //   source = 'fe.synth.thumbnail';
          // } else {
          chosen = master;
          source = 'fallback.master';
          // }
        }
      case CatalogImageRole.detail:
        if (detail.isNotEmpty) {
          chosen = detail;
          source = 'be.detailUrl';
        } else {
          // FE synth disabled — same as grid.
          // final synth = synthesize(masterUrl: master, role: role);
          // if (synth != null && synth.isNotEmpty) {
          //   chosen = synth;
          //   source = 'fe.synth.detail';
          // } else {
          chosen = master;
          source = 'fallback.master';
          // }
        }
      case CatalogImageRole.zoom:
        chosen =
            master.isNotEmpty
                ? master
                : (detail.isNotEmpty ? detail : thumb);
        source =
            master.isNotEmpty
                ? 'be.url'
                : (detail.isNotEmpty
                    ? 'fallback.detail'
                    : 'fallback.thumbnail');
    }

    // Monotonic ladder: never paint a lower tier once a higher one was seen.
    // zoom role already prefers master — only upgrade grid / detail binds.
    if (role != CatalogImageRole.zoom) {
      if (CatalogImageQualityLadder.isMasterUnlocked(master) &&
          master.isNotEmpty) {
        chosen = master;
        source = 'ladder.master';
      } else if (role == CatalogImageRole.grid &&
          CatalogImageQualityLadder.isDetailUnlocked(detail) &&
          detail.isNotEmpty) {
        chosen = detail;
        source = 'ladder.detail';
      }
    }

    if (log) {
      CatalogMediaDebug.render(
        'URL role=${role.name} source=$source '
        'ctx=${context ?? "-"} → ${CatalogMediaDebug.shortUrl(chosen)} '
        'master=${CatalogMediaDebug.shortUrl(master)} '
        'thumb=${thumb.isEmpty ? "NULL" : CatalogMediaDebug.shortUrl(thumb)} '
        'detail=${detail.isEmpty ? "NULL" : CatalogMediaDebug.shortUrl(detail)}',
      );
      final tier = CatalogMediaDebug.cdnTier(chosen);
      final expectOk = switch (role) {
        CatalogImageRole.grid => tier == 'thumbnailUrl(360)' ||
            source.startsWith('ladder'),
        CatalogImageRole.detail => tier == 'detailUrl(1080)' ||
            source.startsWith('ladder'),
        CatalogImageRole.zoom => tier.startsWith('master'),
      };
      CatalogMediaDebug.r2Qa(
        'L1',
        status: expectOk ? 'PASS' : 'INFO',
        detail:
            'role=${role.name} source=$source cdn=$tier '
            'url=${CatalogMediaDebug.shortUrl(chosen)}',
        once: true,
        onceKey: 'L1:${role.name}:$source:$tier',
      );
      if (source.startsWith('fallback') && role != CatalogImageRole.zoom) {
        CatalogMediaDebug.gap(
          'responsive ${role.name} missing BE variant — $source '
          'ctx=${context ?? "-"}',
        );
      }
      // if (source.startsWith('fe.synth')) {
      //   CatalogMediaDebug.gap(
      //     'responsive ${role.name} BE omitted variant — FE synthesized '
      //     'cdn-cgi ctx=${context ?? "-"}',
      //   );
      // }
    }

    return chosen;
  }

  // --- FE CDN synth helper (DISABLED) — uncomment + wire in resolve() ---
  //
  // /// Build `cdn-cgi/image/…` from master when BE omitted thumb/detail.
  // /// Supports `/v1/catalog/media/…` and CDN-root `catalog/products/…`.
  // static String? synthesize({
  //   required String masterUrl,
  //   required CatalogImageRole role,
  // }) {
  //   if (role == CatalogImageRole.zoom) return null;
  //   final raw = masterUrl.trim();
  //   if (raw.isEmpty) return null;
  //   final uri = Uri.tryParse(raw);
  //   if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
  //     return null;
  //   }
  //   final host = uri.host.toLowerCase();
  //   if (host.contains('r2.dev') || host.contains('r2.cloudflarestorage.com')) {
  //     return null;
  //   }
  //   if (uri.path.contains('/cdn-cgi/image/')) return raw;
  //
  //   final transform =
  //       role == CatalogImageRole.grid ? gridTransform : detailTransform;
  //   final port =
  //       uri.hasPort && uri.port != 80 && uri.port != 443 ? ':${uri.port}' : '';
  //   final origin = '${uri.scheme}://${uri.host}$port';
  //   final path = uri.path;
  //
  //   final mediaIdx = path.indexOf(mediaPathPrefix);
  //   if (mediaIdx >= 0) {
  //     final afterMedia = path.substring(mediaIdx + mediaPathPrefix.length);
  //     if (afterMedia.startsWith('cdn-cgi/image/')) return raw;
  //     if (!afterMedia.startsWith('catalog/')) return null;
  //     final prefix = path.substring(0, mediaIdx + mediaPathPrefix.length);
  //     return '$origin$prefix'
  //         'cdn-cgi/image/$transform/$afterMedia';
  //   }
  //
  //   var objectPath = path.startsWith('/') ? path.substring(1) : path;
  //   if (!objectPath.startsWith('catalog/')) return null;
  //   return '$origin/cdn-cgi/image/$transform/$objectPath';
  // }

  static String fromVariants({
    required CatalogImageUrls variants,
    required CatalogImageRole role,
    bool log = false,
    String? context,
  }) {
    return resolve(
      masterUrl: variants.url,
      thumbnailUrl: variants.thumbnailUrl,
      detailUrl: variants.detailUrl,
      role: role,
      log: log,
      context: context,
    );
  }

  /// Channel Media pinch: dense (zoom out) → thumbnail; large cells (zoom in)
  /// → detailUrl. Master `url` is reserved for tap / product-details.
  ///
  /// Columns are clamped to 2…9 (same range as [StoreChannelRoute] Media).
  static CatalogImageRole roleForMediaColumns(int columns) {
    final cols = columns.clamp(2, 9);
    if (cols >= 6) return CatalogImageRole.grid;
    return CatalogImageRole.detail;
  }

  /// Store profile / channel Group+Gallery default (no per-card count).
  /// Prefer [roleForCollageCell] for Group/Single product cards.
  static CatalogImageRole roleForViewMode(ProductViewMode mode) {
    return switch (mode) {
      ProductViewMode.single => CatalogImageRole.detail,
      ProductViewMode.group || ProductViewMode.gallery => CatalogImageRole.grid,
    };
  }

  /// Group / Single collage: coarse role when every cell shares one URL tier.
  /// Prefer [roleForCollageCell] (hero / medium / small → zoom / detail / grid).
  ///
  /// - **1** → [CatalogImageRole.zoom]
  /// - **2** → [CatalogImageRole.detail]
  /// - **3+** → [CatalogImageRole.grid] (use [roleForCollageCell] for mixed)
  static CatalogImageRole roleForCollageImageCount(int imageCount) {
    final n = imageCount < 0 ? 0 : imageCount;
    if (n <= 0) return CatalogImageRole.grid;
    if (n == 1) return CatalogImageRole.zoom;
    if (n == 2) return CatalogImageRole.detail;
    return CatalogImageRole.grid;
  }

  /// Row plan for 5–9 Telegram collages — mirrors `ProductImageCollage`.
  static List<int> _collageRowPlan(int count) {
    return switch (count) {
      5 => const [2, 3],
      6 => const [3, 3],
      7 => const [2, 2, 3],
      8 => const [2, 3, 3],
      9 => const [3, 3, 3],
      _ => const [3, 3, 3],
    };
  }

  /// True when [roleForCollageCell] would return [CatalogImageRole.zoom].
  static bool collageCellIsLarge({
    required int imageCount,
    required int imageIndex,
  }) {
    return roleForCollageCell(
          imageCount: imageCount,
          imageIndex: imageIndex,
        ) ==
        CatalogImageRole.zoom;
  }

  /// Per-cell Group/Single collage quality (all three CDN tiers).
  ///
  /// Classic Telegram layouts (active). Settings N×N path is disabled —
  /// see `kEnableCollageImageArrangement` in collage_grid_arrangement.dart.
  /// - **1** full card → [CatalogImageRole.zoom] (master)
  /// - **2** equal halves → [CatalogImageRole.detail] (`detailUrl`)
  /// - **3–4** left hero → zoom; stacked right → [CatalogImageRole.grid]
  /// - **5–9** 2-col rows → detail; 3-col rows → grid
  /// - **10+** 3×3 pages → grid
  ///
  /// Tap / product-details still opens master via zoom separately.
  static CatalogImageRole roleForCollageCell({
    required int imageCount,
    required int imageIndex,
  }) {
    final n = imageCount < 0 ? 0 : imageCount;
    if (n <= 0 || imageIndex < 0 || imageIndex >= n) {
      return CatalogImageRole.grid;
    }
    if (n == 1) return CatalogImageRole.zoom;
    if (n == 2) return CatalogImageRole.detail;
    if (n == 3 || n == 4) {
      return imageIndex == 0
          ? CatalogImageRole.zoom
          : CatalogImageRole.grid;
    }
    if (n > 9) return CatalogImageRole.grid;
    final plan = _collageRowPlan(n);
    var i = 0;
    for (final rowSize in plan) {
      for (var c = 0; c < rowSize; c++) {
        if (i == imageIndex) {
          return rowSize <= 2
              ? CatalogImageRole.detail
              : CatalogImageRole.grid;
        }
        i++;
      }
    }
    return CatalogImageRole.grid;
  }
}
