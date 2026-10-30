import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:project_c/helper/catalog_media_debug.dart';
import 'package:project_c/helper/jewel_upload_qa.dart';

/// Step-by-step plain-English upload walkthrough (Direct-to-S3).
///
/// **Logcat / console filter:** `CatalogUploadStory` **or** `JewelUploadQA`
///
/// Uses [print] (not [debugPrint]) so lines are not throttled/dropped the way
/// Flutter's debugPrint can be under heavy CatalogApi logging.
///
/// Separate from [CatalogMediaDebug] (`CatalogMediaDBG`). Remove after demos.
class CatalogUploadStory {
  CatalogUploadStory._();

  /// Search/filter string for Logcat / Run console.
  static const filter = 'CatalogUploadStory';

  static bool get _enabled => kDebugMode;

  static int _step = 0;

  static void reset() => _step = 0;

  /// Always prefix with [filter]; also mirrors to [JewelUploadQa.filter].
  static void _line(String message) {
    if (!_enabled) return;
    final line = '[$filter] $message';
    developer.log(line, name: filter);
    // ignore: avoid_print — intentional: survive debugPrint throttling
    print(line);
    JewelUploadQa.log(message);
  }

  static void step(String title, {String? detail}) {
    if (!_enabled) return;
    _step += 1;
    _line('==== Step $_step - $title ====');
    if (detail != null && detail.trim().isNotEmpty) {
      _line(detail.trim());
    }
  }

  static void note(String message) {
    if (!_enabled) return;
    _line('  -> $message');
  }

  static void why(String message) {
    if (!_enabled) return;
    _line('  Why: $message');
  }

  static void frontend(String message) {
    if (!_enabled) return;
    _line('  Frontend: $message');
  }

  /// True for upload/commit APIs (not list/detail/views).
  static bool isUploadApiPath(String path, {String method = ''}) {
    final p = path.toLowerCase();
    final m = method.toUpperCase();
    if (m != 'POST' && m != 'PATCH') return false;
    if (p.contains('/uploads/presign') || p.contains('/uploads/sign')) {
      return true;
    }
    if (p.contains('/products/batch')) return true;
    // Append photos: .../collections/:id/photos
    if (p.contains('/collections/') && p.endsWith('/photos')) return true;
    // Create: .../collections (no trailing listing id segment after collections)
    // Matches `/stores/:id/collections` but not `/stores/:id/collections/:listingId`.
    final collectionsIdx = p.indexOf('/collections');
    if (collectionsIdx >= 0 && !p.contains('/photos')) {
      final after = p.substring(collectionsIdx + '/collections'.length);
      final trimmed = after.startsWith('/') ? after.substring(1) : after;
      // Empty or only query → create endpoint.
      if (trimmed.isEmpty || trimmed.startsWith('?')) return true;
    }
    return false;
  }

  static void beginPublish({
    required String title,
    required int photoCount,
    required String storeId,
    required String mode,
  }) {
    reset();
    _line(
      'STORY START (filter Logcat: JewelUploadQA or CatalogUploadStory)',
    );
    step(
      'Publish started',
      detail:
          'User published "$title" ($photoCount photos) on store $storeId '
          'via $mode.',
    );
    why(
      'Binaries never go through Node — phone compresses, uploads to S3, '
      'then commits small JSON.',
    );
    frontend(
      'ProductUploadCoordinator runs in the background so the user can '
      'return to the store while upload finishes.',
    );
  }

  static void beginCompress({
    required int count,
    required int maxEdge,
    required int webpQuality,
    required int concurrent,
  }) {
    step(
      'On-device prepare (compress + ThumbHash)',
      detail:
          'Compressing $count photo(s) to WebP (max edge $maxEdge px, '
          'quality $webpQuality). Up to $concurrent S3 uploads at a time later.',
    );
    why(
      'Smaller files upload faster; ThumbHash is a tiny blur fingerprint for '
      'instant placeholders when viewing.',
    );
    frontend(
      'CatalogDirectUploadService: EXIF-aware single-pass WebP (max edge 1080 '
      '@ 85%), ThumbHash from a native ~100px preview of the compressed master '
      '(compute fallback), bounded prepare concurrency (default 3). '
      'No full 2K/4K Dart decode.',
    );
  }

  static void preparedPhoto({
    required int index,
    required int total,
    required String name,
    required int width,
    required int height,
    required int bytes,
    required String? thumbhash,
  }) {
    note(
      'Prepared $index/$total "$name" → ${width}x$height, $bytes bytes, '
      '${CatalogMediaDebug.thumbhashFlag(thumbhash)}',
    );
  }

  static void beginPresign({required int fileCount}) {
    step(
      'Ask API for R2 upload tickets (sign)',
      detail:
          'App will call POST …/uploads/sign (fallback store sign/presign) '
          'for $fileCount WebP file(s).',
    );
    why(
      'Server returns imageId + short-lived presignedUrl + url/thumbnailUrl/'
      'detailUrl so the phone can PUT directly to Cloudflare R2.',
    );
    frontend(
      'No photo bytes are sent to the API here — only filenames + '
      'contentType image/webp|jpeg|png.',
    );
  }

  static void beginS3Puts({required int count, required String sessionId}) {
    step(
      'Upload files straight to Cloudflare R2',
      detail:
          'Putting $count compressed WebP file(s) via presignedUrl '
          '(session=$sessionId). Concurrent workers; silent retries on failure.',
    );
    why(
      'R2 stores the master object. Product create later only sends JSON '
      '(image_id + metadata) — binaries never pass through Node.',
    );
    frontend(
      'Each PUT uses the exact compressed bytes + Content-Type from sign. '
      'Auth header is not used on R2 — the signature is in the URL.',
    );
  }

  static void s3PutOk({
    required int index,
    required String name,
    required String key,
  }) {
    note('S3 PUT OK #$index "$name" → key=$key');
  }

  static void s3PutFail({required int index, required String name}) {
    note('S3 PUT FAILED #$index "$name"');
  }

  static void beginCommit({
    required int photoCount,
    required int thumbhashYes,
    required String title,
  }) {
    step(
      'Commit listing to catalog (JSON)',
      detail:
          'POST …/products/batch (or legacy …/collections) title="$title", '
          '$photoCount photo(s), thumbhashYES=$thumbhashYes. '
          'Idempotency-Key on batch/create.',
    );
    why(
      'Batch creates products + collection; legacy create binds staging keys '
      'to a collection listing.',
    );
    frontend(
      'Request body is JSON only (image_id / keys, thumbhash, specs, '
      'stock/lock) — not multipart file upload.',
    );
  }

  static void commitOk({required String listingId, required int photoCount}) {
    step(
      'Commit succeeded',
      detail:
          'Listing $listingId created with $photoCount photo(s). CDN URLs + '
          'thumbhashes are now available for InstantCatalogPhoto.',
    );
    frontend(
      'Store profile refreshes cache. Grids bind thumbnailUrl (~15KB), '
      'product detail binds detailUrl (~1080), pinch-zoom binds master url. '
      'ThumbHash paints instantly until the CDN frame arrives.',
    );
    step(
      'Render rule (post-commit)',
      detail:
          'grid→thumbnailUrl | detail→detailUrl | zoom→url | placeholder→thumbhash. '
          'Filter CatalogMediaDBG for [RENDER] URL role=… source=…',
    );
  }

  static void batchDone({
    required int success,
    required int failed,
    required bool cancelled,
  }) {
    note(
      'Prepare/upload batch finished: success=$success failed=$failed '
      'cancelled=$cancelled',
    );
  }

  static void done() {
    step(
      'Upload story complete',
      detail:
          'Filter JewelUploadQA (or CatalogUploadStory). CatalogMediaDBG '
          'for technical gap checks.',
    );
  }

  /// Plain-English API request line for upload endpoints.
  static void apiRequest({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) {
    if (!_enabled || !isUploadApiPath(path, method: method)) return;
    final m = method.toUpperCase();
    final p = path.toLowerCase();
    if (p.contains('/uploads/sign') || p.contains('/uploads/presign')) {
      step(
        'API — REQUEST sign/presign',
        detail: '$m $path',
      );
      note('Request body: ${_presignBodyStory(body)}');
      CatalogMediaDebug.step(
        '1 SIGN request',
        detail: '$m $path ${_presignBodyStory(body)}',
      );
      return;
    }
    if (p.contains('/products/batch')) {
      step(
        'API — REQUEST products/batch',
        detail: '$m $path',
      );
      note('Request body: ${_batchBodyStory(body)}');
      CatalogMediaDebug.step(
        '3 BATCH request',
        detail: '$m $path ${_batchBodyStory(body)}',
      );
      return;
    }
    if (p.contains('/collections') && m == 'POST') {
      // Avoid narrating GET list/detail (handled by isUploadApiPath).
      step(
        'API — REQUEST create/append collection',
        detail: '$m $path',
      );
      note('Request body: ${_commitBodyStory(body)}');
      return;
    }
    if (p.contains('/photos') && m == 'POST') {
      step(
        'API — REQUEST append photos',
        detail: '$m $path',
      );
      note('Request body: ${_commitBodyStory(body)}');
    }
  }

  /// Plain-English API response for upload endpoints.
  static void apiResponse({
    required String method,
    required String path,
    required int statusCode,
    Object? decoded,
  }) {
    if (!_enabled || !isUploadApiPath(path, method: method)) return;
    final p = path.toLowerCase();
    if (p.contains('/uploads/sign') || p.contains('/uploads/presign')) {
      step(
        'API — RESPONSE sign/presign',
        detail: 'HTTP $statusCode $path',
      );
      note(_presignResponseStory(decoded));
      frontend(
        'App stores imageId + presignedUrl + url/thumbnailUrl/detailUrl, '
        'then PUTs WebP bytes to R2.',
      );
      CatalogMediaDebug.step(
        '1 SIGN response',
        detail: 'HTTP $statusCode ${_presignResponseStory(decoded)}',
      );
      return;
    }
    if (p.contains('/products/batch')) {
      step(
        'API — RESPONSE products/batch',
        detail: 'HTTP $statusCode $path',
      );
      note(_batchResponseStory(decoded));
      frontend(
        'App maps products → StoreProduct (master + thumbnail + detail + '
        'thumbhash) and updates the store product cache.',
      );
      CatalogMediaDebug.step(
        '3 BATCH response',
        detail: 'HTTP $statusCode ${_batchResponseStory(decoded)}',
      );
      return;
    }
    if (p.contains('/collections') && method.toUpperCase() == 'POST') {
      step(
        'API — RESPONSE create collection',
        detail: 'HTTP $statusCode $path',
      );
      note(_commitResponseStory(decoded));
      frontend(
        'App maps response → StoreProduct (urls + thumbhashes) and updates '
        'the store product cache.',
      );
      return;
    }
    if (p.contains('/photos') && method.toUpperCase() == 'POST') {
      step(
        'API — RESPONSE append photos',
        detail: 'HTTP $statusCode $path',
      );
      note(_commitResponseStory(decoded));
    }
  }

  static String _presignBodyStory(Map<String, dynamic>? body) {
    if (body == null) return '(none)';
    final files = body['files'];
    if (files is! List) return jsonEncode(body.keys.take(6).toList());
    final types = <String>{};
    for (final f in files) {
      if (f is Map && f['contentType'] != null) {
        types.add('${f['contentType']}');
      }
    }
    return '${files.length} file descriptor(s), contentTypes=$types '
        '(no image bytes in this call).';
  }

  static String _presignResponseStory(Object? decoded) {
    if (decoded is! Map) return 'body=${decoded.runtimeType}';
    final map = Map<String, dynamic>.from(decoded);
    final session = map['sessionId'] ?? '(missing)';
    final uploads = map['uploads'];
    final n = uploads is List ? uploads.length : (map['count'] ?? '?');
    var withImageId = 0;
    var withThumb = 0;
    var withDetail = 0;
    if (uploads is List) {
      for (final u in uploads) {
        if (u is! Map) continue;
        final id =
            (u['imageId'] as String?)?.trim() ??
            (u['image_id'] as String?)?.trim() ??
            '';
        if (id.isNotEmpty) withImageId++;
        if ((u['thumbnailUrl'] as String?)?.trim().isNotEmpty == true) {
          withThumb++;
        }
        if ((u['detailUrl'] as String?)?.trim().isNotEmpty == true) {
          withDetail++;
        }
      }
    }
    return 'sessionId=$session, $n upload slot(s). '
        'imageIdYES=$withImageId thumbnailUrlYES=$withThumb '
        'detailUrlYES=$withDetail. Each slot has key, url, '
        'thumbnailUrl, detailUrl, and R2 presignedUrl (expires ~900s).';
  }

  static String _batchBodyStory(Map<String, dynamic>? body) {
    if (body == null) return '(none)';
    final products = body['products'];
    if (products is! List) {
      return 'keys=${body.keys.take(8).join(",")}';
    }
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
    return 'products=${products.length}, image_idYES=$withImageId, '
        'thumbhashYES=$withHash, '
        'collectionName=${body['collectionName'] ?? "(none)"}, '
        'idempotencyKey=${body['idempotencyKey'] ?? body['batchId'] ?? "(none)"}. '
        'JSON only — no binary.';
  }

  static String _batchResponseStory(Object? decoded) {
    if (decoded is! Map) return 'body=${decoded.runtimeType}';
    final map = Map<String, dynamic>.from(decoded);
    final products = map['products'];
    final n = products is List ? products.length : (map['count'] ?? 0);
    var withThumb = 0;
    var withDetail = 0;
    var withHash = 0;
    if (products is List) {
      for (final p in products) {
        if (p is! Map) continue;
        final primary = p['primaryImage'];
        if (primary is! Map) continue;
        if ((primary['thumbnailUrl'] as String?)?.trim().isNotEmpty == true) {
          withThumb++;
        }
        if ((primary['detailUrl'] as String?)?.trim().isNotEmpty == true) {
          withDetail++;
        }
        final h =
            (primary['thumbhash'] as String? ?? primary['thumbHash'] as String?)
                ?.trim() ??
            '';
        if (h.isNotEmpty) withHash++;
      }
    }
    return 'batchId=${map['batchId'] ?? "(none)"}, products=$n, '
        'primaryThumbnailYES=$withThumb primaryDetailYES=$withDetail '
        'primaryThumbhashYES=$withHash.';
  }

  static String _commitBodyStory(Map<String, dynamic>? body) {
    if (body == null) return '(none)';
    final photos = body['photos'];
    final title = body['title'] ?? body['name'] ?? '';
    if (photos is! List) {
      return 'title=$title keys=${body.keys.take(8).join(",")}';
    }
    var withHash = 0;
    for (final p in photos) {
      if (p is Map && ((p['thumbhash'] as String?)?.trim().isNotEmpty ?? false)) {
        withHash++;
      }
    }
    return 'title="$title", photos=${photos.length}, '
        'each with staging key + thumbhash ($withHash/$photos have hash), '
        'width/height/bytes/originalName. '
        'clientRequestId=${body['clientRequestId'] ?? "(none)"}.';
  }

  static String _commitResponseStory(Object? decoded) {
    if (decoded is! Map) return 'body=${decoded.runtimeType}';
    final map = Map<String, dynamic>.from(decoded);
    final id = map['id'] ?? '(missing)';
    final name = map['name'] ?? map['title'] ?? '';
    final photos = map['photos'];
    var withHash = 0;
    var n = 0;
    if (photos is List) {
      n = photos.length;
      for (final p in photos) {
        if (p is Map) {
          final h =
              (p['thumbhash'] as String? ?? p['thumbHash'] as String?)
                  ?.trim() ??
              '';
          if (h.isNotEmpty) withHash++;
        }
      }
    }
    final failed =
        map['failedPhotos'] is List
            ? (map['failedPhotos'] as List).length
            : 0;
    return 'listing id=$id name="$name", photos=$n thumbhashYES=$withHash, '
        'failedPhotos=$failed. Photo urls are CDN (CloudFront).';
  }
}
