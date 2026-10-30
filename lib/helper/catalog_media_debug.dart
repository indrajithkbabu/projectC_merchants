import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/catalog_responsive_image.dart';

/// Temporary debug tracer for Direct-to-S3 upload + InstantCatalogPhoto.
///
/// **Logcat / console filter:** `CatalogMediaDBG`
///
/// Progressive-quality QA: filter `CatalogMediaDBG` + `QUALITY`.
/// Remove call sites after gap audit (keep this file only if still useful).
class CatalogMediaDebug {
  CatalogMediaDebug._();

  /// Search/filter string — use in Android Studio Logcat or `flutter logs`.
  static const filter = 'CatalogMediaDBG';

  /// Dedup paint logs so grids do not flood the console every rebuild.
  static final Set<String> _paintLogged = <String>{};

  /// Dedup progressive-quality checklist logs (pinch / rebuild safe).
  static final Set<String> _qualityLogged = <String>{};

  static bool get _enabled => kDebugMode;

  static void clearPaintLogDedup() => _paintLogged.clear();

  static void clearQualityLogDedup() => _qualityLogged.clear();

  static void upload(String message) => _log('UPLOAD', message);

  static void render(String message) => _log('RENDER', message);

  static void api(String message) => _log('API', message);

  static void gap(String message) => _log('GAP', message);

  static void warm(String message) => _log('WARM', message);

  /// Progressive CDN quality checklist (Media cols / Single·Group·Gallery / tap).
  static void quality(String message) => _log('QUALITY', message);

  static void _log(String phase, String message) {
    if (!_enabled) return;
    AppLog.d(filter, '[$phase] $message');
  }

  /// True when [path] is catalog media (sign / batch / collections / photos).
  static bool isMediaApiPath(String path) {
    final p = path.toLowerCase();
    return p.contains('/uploads/presign') ||
        p.contains('/uploads/sign') ||
        p.contains('/products/batch') ||
        p.contains('/products') ||
        p.contains('/collections') ||
        p.contains('/photos') ||
        p.contains('/views');
  }

  /// Numbered pipeline step for Logcat filter `CatalogMediaDBG`.
  static void step(String title, {String? detail}) {
    if (!_enabled) return;
    _log('STEP', title);
    if (detail != null && detail.trim().isNotEmpty) {
      _log('STEP', '  $detail');
    }
  }

  static String shortUrl(String? url) {
    final value = (url ?? '').trim();
    if (value.isEmpty) return '(empty)';
    final uri = Uri.tryParse(value);
    if (uri == null) return value.length > 48 ? '${value.substring(0, 48)}…' : value;
    final host = uri.host;
    final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final shortName =
        name.length > 36 ? '${name.substring(0, 36)}…' : name;
    return '$host/…/$shortName';
  }

  /// Classify painted CDN URL for QA (thumbnail / detail / master).
  ///
  /// Current BE: thumb `width=240`, detail `width=720`. Older 320/1080 still
  /// recognized so mixed payloads keep clear PASS labels.
  static String cdnTier(String? url) {
    final value = (url ?? '').trim();
    if (value.isEmpty) return 'empty';
    if (value.contains('width=240') || value.contains('width=320')) {
      return value.contains('width=240')
          ? 'thumbnailUrl(240)'
          : 'thumbnailUrl(320)';
    }
    if (value.contains('width=720') || value.contains('width=1080')) {
      return value.contains('width=720')
          ? 'detailUrl(720)'
          : 'detailUrl(1080)';
    }
    if (value.contains('/cdn-cgi/image/')) return 'cdn-cgi(other)';
    return 'master(url)';
  }

  static void _qualityOnce(String key, String message) {
    if (!_enabled) return;
    if (!_qualityLogged.add(key)) return;
    quality(message);
  }

  static int? _lastMediaQualityCols;
  static CatalogImageRole? _lastMediaQualityRole;

  static String _qualityVerdict({
    required CatalogImageRole role,
    required CatalogImageRole expectRole,
    required String expectCdn,
    required String tier,
  }) {
    if (role != expectRole) return 'FAIL_ROLE';
    if (expectCdn == 'thumbnailUrl' && tier.startsWith('thumbnailUrl')) {
      return 'PASS';
    }
    if (expectCdn == 'detailUrl' && tier.startsWith('detailUrl')) {
      return 'PASS';
    }
    if (expectCdn == 'master' && tier.startsWith('master')) return 'PASS';
    if (tier == 'master(url)') return 'WARN_FALLBACK_MASTER';
    return 'FAIL_CDN';
  }

  /// Channel Media paint: 6–9 → thumbnailUrl, 2–5 → detailUrl.
  /// Logs once per columns/role change (safe during pinch).
  static void qualityMediaPaint({
    required int columns,
    required CatalogImageRole role,
    required String sampleUrl,
  }) {
    if (!_enabled) return;
    final cols = columns.clamp(2, 9);
    if (_lastMediaQualityCols == cols && _lastMediaQualityRole == role) {
      return;
    }
    _lastMediaQualityCols = cols;
    _lastMediaQualityRole = role;
    final expectRole =
        cols >= 6 ? CatalogImageRole.grid : CatalogImageRole.detail;
    final expectCdn = cols >= 6 ? 'thumbnailUrl' : 'detailUrl';
    final tier = cdnTier(sampleUrl);
    final verdict = _qualityVerdict(
      role: role,
      expectRole: expectRole,
      expectCdn: expectCdn,
      tier: tier,
    );
    quality(
      'CHECK Media cols=$cols role=${role.name} expect=$expectCdn '
      'cdn=$tier url=${shortUrl(sampleUrl)} $verdict',
    );
  }

  /// Group/Single collage: expect matches painted [role]
  /// (hero → master, medium → detailUrl, small → thumbnailUrl).
  static void qualityViewPaint({
    required String view,
    required CatalogImageRole role,
    required String sampleUrl,
  }) {
    if (!_enabled) return;
    final expectCdn = switch (role) {
      CatalogImageRole.grid => 'thumbnailUrl',
      CatalogImageRole.detail => 'detailUrl',
      CatalogImageRole.zoom => 'master',
    };
    final tier = cdnTier(sampleUrl);
    final verdict = _qualityVerdict(
      role: role,
      expectRole: role,
      expectCdn: expectCdn,
      tier: tier,
    );
    _qualityOnce(
      'view|$view|${role.name}|$tier',
      'CHECK View $view role=${role.name} expect=$expectCdn '
      'cdn=$tier url=${shortUrl(sampleUrl)} $verdict',
    );
  }

  /// Tap → product details must open master `url`.
  static void qualityTapOpen({
    required String from,
    required CatalogImageRole role,
    required String url,
    String? paintedUrl,
  }) {
    if (!_enabled) return;
    final tier = cdnTier(url);
    final verdict = _qualityVerdict(
      role: role,
      expectRole: CatalogImageRole.zoom,
      expectCdn: 'master',
      tier: tier,
    );
    final flyer =
        paintedUrl == null || paintedUrl.trim().isEmpty
            ? ''
            : ' flyer=${shortUrl(paintedUrl)}(${cdnTier(paintedUrl)})';
    quality(
      'CHECK TAP from=$from role=${role.name} expect=master '
      'cdn=$tier url=${shortUrl(url)}$flyer $verdict',
    );
  }

  static String thumbhashFlag(String? hash) {
    final value = (hash ?? '').trim();
    if (value.isEmpty) return 'thumbhash=NULL';
    final preview =
        value.length <= 12 ? value : '${value.substring(0, 12)}…';
    return 'thumbhash=YES($preview len=${value.length})';
  }

  /// Summarize collection/list JSON for media gap checks (no full bodies).
  static String summarizeMediaJson(Object? decoded) {
    if (decoded is! Map) return 'bodyType=${decoded.runtimeType}';
    final map = Map<String, dynamic>.from(decoded);
    final photos = _asPhotoList(map['photos']);
    final cover = map['cover'];
    final items = _asPhotoList(map['items']) ?? _asPhotoList(map['data']);
    final buf = StringBuffer();
    if (map['id'] != null) buf.write('id=${map['id']} ');
    if (map['name'] != null || map['title'] != null) {
      buf.write('name=${map['name'] ?? map['title']} ');
    }
    if (map['photoCount'] != null) buf.write('photoCount=${map['photoCount']} ');
    if (map['sessionId'] != null) buf.write('sessionId=${map['sessionId']} ');
    if (map['uploads'] is List) {
      buf.write('presignSlots=${(map['uploads'] as List).length} ');
    }
    if (cover is Map) {
      buf.write(
        'cover{${thumbhashFlag(cover['thumbhash'] as String? ?? cover['thumbHash'] as String?)} '
        'url=${shortUrl(cover['url'] as String?)} '
        'thumb=${_variantFlag(cover['thumbnailUrl'])} '
        'detail=${_variantFlag(cover['detailUrl'])}} ',
      );
    }
    final products = map['products'];
    if (products is List && products.isNotEmpty) {
      buf.write(_productsSummary(products));
    }
    // Detail / create: top-level photos[].
    if (photos != null) {
      buf.write(_photoListSummary(photos, label: 'photos'));
    } else if (items != null) {
      // List endpoint: items[] are collections with cover/mainGroupCover.
      buf.write(_listItemsSummary(items));
    }
    if (map['failedPhotos'] is List) {
      buf.write('failedPhotos=${(map['failedPhotos'] as List).length} ');
    }
    if (map['recorded'] != null) {
      buf.write('recorded=${map['recorded']} skipped=${map['skipped']} ');
    }
    final text = buf.toString().trim();
    return text.isEmpty ? 'keys=${map.keys.take(12).join(",")}' : text;
  }

  static String _variantFlag(Object? value) {
    final s = (value as String?)?.trim() ?? '';
    return s.isEmpty ? 'NULL' : shortUrl(s);
  }

  static String _photoListSummary(List<dynamic> list, {required String label}) {
    var withHash = 0;
    var withoutHash = 0;
    var withThumb = 0;
    var withDetail = 0;
    for (final p in list) {
      if (p is! Map) continue;
      final h =
          (p['thumbhash'] as String? ?? p['thumbHash'] as String?)?.trim() ??
          '';
      if (h.isEmpty) {
        withoutHash++;
      } else {
        withHash++;
      }
      if ((p['thumbnailUrl'] as String?)?.trim().isNotEmpty == true) {
        withThumb++;
      }
      if ((p['detailUrl'] as String?)?.trim().isNotEmpty == true) {
        withDetail++;
      }
    }
    final buf = StringBuffer(
      '$label=${list.length} thumbhashYES=$withHash thumbhashNULL=$withoutHash '
      'thumbnailUrlYES=$withThumb detailUrlYES=$withDetail ',
    );
    if (withoutHash > 0) buf.write('GAP_THUMBHASH_NULL ');
    if (withThumb < list.length) buf.write('GAP_THUMBNAIL_URL ');
    if (withDetail < list.length) buf.write('GAP_DETAIL_URL ');
    if (list.isNotEmpty && list.first is Map) {
      final first = list.first as Map;
      buf.write(
        'first{${thumbhashFlag(first['thumbhash'] as String? ?? first['thumbHash'] as String?)} '
        'url=${shortUrl(first['url'] as String?)} '
        'thumb=${_variantFlag(first['thumbnailUrl'])} '
        'detail=${_variantFlag(first['detailUrl'])}} ',
      );
    }
    return buf.toString();
  }

  static String _productsSummary(List<dynamic> products) {
    var withThumb = 0;
    var withDetail = 0;
    var withHash = 0;
    for (final p in products) {
      if (p is! Map) continue;
      final primary = p['primaryImage'];
      final map =
          primary is Map
              ? Map<String, dynamic>.from(primary)
              : const <String, dynamic>{};
      if ((map['thumbnailUrl'] as String?)?.trim().isNotEmpty == true) {
        withThumb++;
      }
      if ((map['detailUrl'] as String?)?.trim().isNotEmpty == true) {
        withDetail++;
      }
      final h =
          (map['thumbhash'] as String? ?? map['thumbHash'] as String?)
              ?.trim() ??
          '';
      if (h.isNotEmpty) withHash++;
    }
    final buf = StringBuffer(
      'products=${products.length} primaryThumbYES=$withThumb '
      'primaryDetailYES=$withDetail primaryHashYES=$withHash ',
    );
    if (withThumb < products.length) buf.write('GAP_THUMBNAIL_URL ');
    if (withDetail < products.length) buf.write('GAP_DETAIL_URL ');
    if (products.isNotEmpty && products.first is Map) {
      final first = products.first as Map;
      final primary = first['primaryImage'];
      if (primary is Map) {
        buf.write(
          'firstPrimary{url=${shortUrl(primary['url'] as String?)} '
          'thumb=${_variantFlag(primary['thumbnailUrl'])} '
          'detail=${_variantFlag(primary['detailUrl'])} '
          '${thumbhashFlag(primary['thumbhash'] as String? ?? primary['thumbHash'] as String?)}} ',
        );
      }
    }
    return buf.toString();
  }

  /// List API rows use cover.thumbhash — not top-level photo fields.
  static String _listItemsSummary(List<dynamic> items) {
    var withHash = 0;
    var withoutHash = 0;
    Map? firstCover;
    for (final item in items) {
      if (item is! Map) continue;
      final cover = item['cover'] ?? item['mainGroupCover'];
      if (cover is! Map) {
        withoutHash++;
        continue;
      }
      firstCover ??= cover;
      final h =
          (cover['thumbhash'] as String? ?? cover['thumbHash'] as String?)
              ?.trim() ??
          '';
      if (h.isEmpty) {
        withoutHash++;
      } else {
        withHash++;
      }
    }
    final buf = StringBuffer(
      'listItems=${items.length} coverThumbhashYES=$withHash '
      'coverThumbhashNULL=$withoutHash ',
    );
    if (withoutHash > 0) buf.write('GAP_THUMBHASH_NULL ');
    if (firstCover != null) {
      buf.write(
        'firstCover{${thumbhashFlag(firstCover['thumbhash'] as String? ?? firstCover['thumbHash'] as String?)} '
        'url=${shortUrl(firstCover['url'] as String?)}} ',
      );
    }
    return buf.toString();
  }

  static List<dynamic>? _asPhotoList(Object? value) {
    if (value is List) return value;
    return null;
  }

  /// Log InstantCatalogPhoto paint once per url@cacheWidth outcome.
  static void paintOnce({
    required String url,
    required int cacheWidth,
    required String outcome,
    String? thumbhash,
    bool alreadyDecoded = false,
  }) {
    if (!_enabled) return;
    final key = '$url@$cacheWidth@$outcome';
    if (_paintLogged.contains(key)) return;
    _paintLogged.add(key);
    // Cap set growth for long sessions.
    if (_paintLogged.length > 400) {
      _paintLogged.clear();
      _paintLogged.add(key);
    }
    final hash = thumbhashFlag(thumbhash);
    if (outcome == 'placeholder' &&
        (thumbhash == null || thumbhash.trim().isEmpty)) {
      gap(
        'paint $outcome ${shortUrl(url)} cacheW=$cacheWidth $hash '
        'decoded=$alreadyDecoded',
      );
      return;
    }
    render(
      'paint $outcome ${shortUrl(url)} cacheW=$cacheWidth $hash '
      'decoded=$alreadyDecoded',
    );
  }

  static String requestBodyHint(Map<String, dynamic>? body) {
    if (body == null) return '(none)';
    try {
      final photos = body['photos'];
      if (photos is List) {
        var withHash = 0;
        var withoutHash = 0;
        for (final p in photos) {
          if (p is! Map) continue;
          final h = (p['thumbhash'] as String?)?.trim() ?? '';
          if (h.isEmpty) {
            withoutHash++;
          } else {
            withHash++;
          }
        }
        return 'photos=${photos.length} thumbhashYES=$withHash '
            'thumbhashNULL=$withoutHash'
            '${withoutHash > 0 ? ' GAP_THUMBHASH_NULL' : ''}';
      }
      if (body['files'] is List) {
        return 'presignFiles=${(body['files'] as List).length}';
      }
      final products = body['products'];
      if (products is List) {
        var withImageId = 0;
        var withHash = 0;
        for (final p in products) {
          if (p is! Map) continue;
          final id =
              (p['image_id'] as String?)?.trim() ??
              (p['imageId'] as String?)?.trim() ??
              '';
          if (id.isNotEmpty) withImageId++;
          if ((p['thumbhash'] as String?)?.trim().isNotEmpty == true) {
            withHash++;
          }
        }
        return 'batchProducts=${products.length} image_idYES=$withImageId '
            'thumbhashYES=$withHash'
            '${withImageId < products.length ? ' GAP_IMAGE_ID' : ''}'
            '${withHash < products.length ? ' GAP_THUMBHASH_NULL' : ''}';
      }
      return jsonEncode(body.keys.take(8).toList());
    } catch (_) {
      return '(unreadable)';
    }
  }
}
