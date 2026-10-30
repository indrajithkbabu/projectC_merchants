import 'package:project_c/helper/catalog_media_debug.dart';
import 'package:project_c/models/product_view_mode.dart';

/// Screen role for Cloudflare R2 / Image Resizing variants.
///
/// Guide: grid → `thumbnailUrl`, detail → `detailUrl`, zoom → master `url`.
enum CatalogImageRole {
  /// Feed / search / collage / gallery tiles (BE thumb, ~240×240).
  grid,

  /// Product detail / bottom sheet (BE detail, ~720px).
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

/// Resolve the correct CDN URL for a screen from BE fields only.
///
/// Missing `thumbnailUrl` / `detailUrl` → master (and a [CatalogMediaDebug.gap]
/// when logging) so incomplete BE payloads are visible as BE gaps, not masked
/// by FE CDN synthesis.
class CatalogResponsiveImage {
  CatalogResponsiveImage._();

  // --- FE CDN synth (DISABLED) — restore with resolve() call sites below ---
  // Kept so we can re-enable without rewriting transforms. Matches current BE:
  // thumb ~240 @ q40, detail ~720 @ q70, fit=scale-down.
  //
  // static const mediaPathPrefix = '/v1/catalog/media/';
  // static const gridTransform =
  //     'width=240,height=240,fit=cover,quality=40,format=auto';
  // static const detailTransform =
  //     'width=720,fit=scale-down,quality=70,format=auto';

  /// Pick URL for [role]. Uses BE `thumbnailUrl` / `detailUrl` / `url` only.
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

    if (log) {
      CatalogMediaDebug.render(
        'URL role=${role.name} source=$source '
        'ctx=${context ?? "-"} → ${CatalogMediaDebug.shortUrl(chosen)} '
        'master=${CatalogMediaDebug.shortUrl(master)} '
        'thumb=${thumb.isEmpty ? "NULL" : CatalogMediaDebug.shortUrl(thumb)} '
        'detail=${detail.isEmpty ? "NULL" : CatalogMediaDebug.shortUrl(detail)}',
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

  /// Row plan for 5–9 collages — mirrors [ProductImageCollage] `_rowPlan`.
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
  /// Layouts must stay in sync with `ProductImageCollage`:
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
          // 2-col rows are medium tiles; 3-col rows are small.
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
