import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/catalog_responsive_image.dart';

/// Temporary debug tracer for Direct-to-S3 upload + InstantCatalogPhoto.
///
/// **Logcat / console filter:** `CatalogMediaDBG`
///
/// Progressive-quality QA: filter `CatalogMediaDBG` + `QUALITY`.
/// FE-only review cases: filter **`FE_QA`** (or `CatalogMediaDBG` + `FE_QA`).
/// R2 responsive low+medium QA: filter **`R2_QA`**.
/// FE no-BE pending wave: filter **`FE_PENDING`** (standalone tag).
/// Remove call sites after gap audit (keep this file only if still useful).
class CatalogMediaDebug {
  CatalogMediaDebug._();

  /// Search/filter string — use in Android Studio Logcat or `flutter logs`.
  static const filter = 'CatalogMediaDBG';

  /// FE-only review checklist phase — Logcat filter: `FE_QA`.
  static const feQaFilter = 'FE_QA';

  /// R2 / CDN responsive low+medium checklist — Logcat filter: `R2_QA`.
  static const r2QaFilter = 'R2_QA';

  /// FE pending (no-BE) implementation wave — Logcat filter: `FE_PENDING`.
  static const fePendingFilter = 'FE_PENDING';

  /// Dedup paint logs so grids do not flood the console every rebuild.
  static final Set<String> _paintLogged = <String>{};

  /// Dedup progressive-quality checklist logs (pinch / rebuild safe).
  static final Set<String> _qualityLogged = <String>{};

  /// Dedup FE_QA once-per-session / once-per-key lines.
  static final Set<String> _feQaLogged = <String>{};

  /// Dedup R2_QA once-per-session / once-per-key lines.
  static final Set<String> _r2QaLogged = <String>{};

  /// Dedup FE_PENDING once-per-session / once-per-key lines.
  static final Set<String> _fePendingLogged = <String>{};

  static bool get _enabled => kDebugMode;

  static void clearPaintLogDedup() => _paintLogged.clear();

  static void clearQualityLogDedup() => _qualityLogged.clear();

  static void clearFeQaLogDedup() => _feQaLogged.clear();

  static void clearR2QaLogDedup() => _r2QaLogged.clear();

  static void clearFePendingLogDedup() => _fePendingLogged.clear();

  static void upload(String message) => _log('UPLOAD', message);

  static void render(String message) => _log('RENDER', message);

  static void api(String message) => _log('API', message);

  static void gap(String message) => _log('GAP', message);

  static void warm(String message) => _log('WARM', message);

  /// Progressive CDN quality checklist (Media cols / Single·Group·Gallery / tap).
  static void quality(String message) => _log('QUALITY', message);

  /// FE-only review case log. Filter Logcat with `FE_QA`.
  ///
  /// [caseId] e.g. `P0.1`, [status] `PASS` / `FAIL` / `INFO`,
  /// [detail] short evidence string.
  static void feQa(
    String caseId, {
    required String status,
    required String detail,
    bool once = false,
    String? onceKey,
  }) {
    if (!_enabled) return;
    if (once) {
      final key = '${caseId.trim()}|${(onceKey ?? detail).trim()}';
      if (_feQaLogged.contains(key)) return;
      _feQaLogged.add(key);
      if (_feQaLogged.length > 200) {
        _feQaLogged.clear();
        _feQaLogged.add(key);
      }
    }
    final id = caseId.trim().isEmpty ? 'P?' : caseId.trim();
    final st = status.trim().isEmpty ? 'INFO' : status.trim().toUpperCase();
    _log(feQaFilter, '$id $st | $detail');
  }

  /// R2 responsive low+medium QA. Filter Logcat with `R2_QA`.
  ///
  /// [caseId] e.g. `L1` (CDN tier), `M1` (presign renew), `M2` (batch shape).
  static void r2Qa(
    String caseId, {
    required String status,
    required String detail,
    bool once = false,
    String? onceKey,
  }) {
    if (!_enabled) return;
    if (once) {
      final key = '${caseId.trim()}|${(onceKey ?? detail).trim()}';
      if (_r2QaLogged.contains(key)) return;
      _r2QaLogged.add(key);
      if (_r2QaLogged.length > 200) {
        _r2QaLogged.clear();
        _r2QaLogged.add(key);
      }
    }
    final id = caseId.trim().isEmpty ? 'R2?' : caseId.trim();
    final st = status.trim().isEmpty ? 'INFO' : status.trim().toUpperCase();
    // Own Logcat tag so filter `R2_QA` matches without CatalogMediaDBG.
    AppLog.d(r2QaFilter, '$id $st | $detail');
  }

  /// FE no-BE pending wave. Filter Logcat with `FE_PENDING`.
  ///
  /// [caseId] e.g. `P3.4`, `P4.1`, `P4.5`, [status] `PASS` / `FAIL` / `INFO`.
  static void fePending(
    String caseId, {
    required String status,
    required String detail,
    bool once = false,
    String? onceKey,
  }) {
    if (!_enabled) return;
    if (once) {
      final key = '${caseId.trim()}|${(onceKey ?? detail).trim()}';
      if (_fePendingLogged.contains(key)) return;
      _fePendingLogged.add(key);
      if (_fePendingLogged.length > 200) {
        _fePendingLogged.clear();
        _fePendingLogged.add(key);
      }
    }
    final id = caseId.trim().isEmpty ? 'P?' : caseId.trim();
    final st = status.trim().isEmpty ? 'INFO' : status.trim().toUpperCase();
    // Own Logcat tag so filter `FE_PENDING` matches without CatalogMediaDBG.
    AppLog.d(fePendingFilter, '$id $st | $detail');
  }

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
  /// BE contract: thumb `width=360`, detail `width=1080`.
  static String cdnTier(String? url) {
    final value = (url ?? '').trim();
    if (value.isEmpty) return 'empty';
    if (value.contains('width=360')) return 'thumbnailUrl(360)';
    if (value.contains('width=1080')) return 'detailUrl(1080)';
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

  static int _cdnTierRank(String tier) {
    if (tier.startsWith('thumbnailUrl')) return 1;
    if (tier.startsWith('detailUrl')) return 2;
    if (tier.startsWith('master')) return 3;
    return 0;
  }

  static int _expectCdnRank(String expectCdn) {
    return switch (expectCdn) {
      'thumbnailUrl' => 1,
      'detailUrl' => 2,
      'master' => 3,
      _ => 0,
    };
  }

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
    // Session ladder may paint a higher unlocked tier than the screen role.
    final actual = _cdnTierRank(tier);
    final expect = _expectCdnRank(expectCdn);
    if (actual > 0 && expect > 0 && actual > expect) {
      return 'PASS_LADDER';
    }
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
    r2Qa(
      'L1',
      status: verdict.startsWith('PASS') ? 'PASS' : 'INFO',
      detail:
          'Media cols=$cols role=${role.name} expect=$expectCdn '
          'cdn=$tier $verdict',
      once: true,
      onceKey: 'L1:media:$cols:${role.name}:$tier',
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
    r2Qa(
      'L1',
      status: verdict.startsWith('PASS') ? 'PASS' : 'INFO',
      detail:
          'View $view role=${role.name} expect=$expectCdn '
          'cdn=$tier $verdict',
      once: true,
      onceKey: 'L1:view:$view:${role.name}:$tier',
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
    // FE_QA / FE_PENDING paint checks (deduped with paintOnce key).
    feQa(
      'P3.4',
      status: cacheWidth > 0 ? 'PASS' : 'FAIL',
      detail: 'cacheW=$cacheWidth outcome=$outcome url=${shortUrl(url)}',
      once: true,
      onceKey: 'cacheW:$cacheWidth',
    );
    fePending(
      'P3.4',
      status: cacheWidth > 0 ? 'PASS' : 'FAIL',
      detail: 'cacheW=$cacheWidth outcome=$outcome url=${shortUrl(url)}',
      once: true,
      onceKey: 'cacheW:$cacheWidth',
    );
    if (outcome == 'reuseDecoded') {
      feQa(
        'P3.7',
        status: 'PASS',
        detail: 'reuseDecoded=true cacheW=$cacheWidth ${thumbhashFlag(thumbhash)}',
        once: true,
        onceKey: 'reuseDecoded',
      );
      fePending(
        'P3.7',
        status: 'PASS',
        detail: 'cdnReuseDecoded cacheW=$cacheWidth ${thumbhashFlag(thumbhash)}',
        once: true,
        onceKey: 'reuseDecoded',
      );
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
