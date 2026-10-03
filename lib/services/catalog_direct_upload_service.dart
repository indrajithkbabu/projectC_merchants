import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fast_thumbhash/fast_thumbhash.dart' as th;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/catalog_upload_models.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';

/// On-device compress + ThumbHash + concurrent direct S3 PUT with silent retries.
///
/// Phase 1 of the catalog two-phase upload: files land in `catalog/staging/...`
/// (uncommitted). Callers commit via
/// [CollectionRepository.createCollectionFromUploads] /
/// [CollectionRepository.appendUploadedPhotos].
class CatalogDirectUploadService {
  CatalogDirectUploadService({
    required CollectionRepository collectionRepository,
    http.Client? httpClient,
    this.maxConcurrentUploads = 3,
    this.maxEdgePx = 2560,
    this.jpegQuality = 85,
  }) : _collectionRepository = collectionRepository,
       _http = httpClient ?? http.Client();

  static const _tag = 'CatalogDirectUpload';
  static const _contentType = 'image/jpeg';

  /// Presigned URLs expire after 900s; renew a bit earlier.
  static const _presignRenewAfterSeconds = 850;

  /// Silent retries with exponential backoff (2s, 4s, 8s).
  static const _retryDelaysSeconds = <int>[2, 4, 8];

  final CollectionRepository _collectionRepository;
  final http.Client _http;
  final int maxConcurrentUploads;
  final int maxEdgePx;
  final int jpegQuality;

  /// Compress, ThumbHash, presign, then upload with concurrency + retries.
  Future<CatalogDirectUploadBatchResult> prepareAndUpload({
    required String storeId,
    required List<String> localPaths,
    void Function(double progress)? onProgress,
  }) async {
    final paths =
        localPaths
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
    if (paths.isEmpty) {
      throw CatalogApiException(
        statusCode: 400,
        code: 'PHOTOS_REQUIRED',
        message: 'Pick at least one photo.',
      );
    }

    final prepared = <PreparedCatalogPhoto>[];
    final prepareFailed = <String>[];

    for (var i = 0; i < paths.length; i++) {
      final path = paths[i];
      try {
        prepared.add(await _preparePhoto(path));
      } catch (e) {
        AppLog.e(_tag, 'prepare failed path=$path', e);
        prepareFailed.add(p.basename(path));
      }
      onProgress?.call((i + 1) / paths.length * 0.25);
    }

    if (prepared.isEmpty) {
      throw CatalogApiException(
        statusCode: 400,
        code: 'NO_VALID_PHOTOS',
        message: 'None of the photos could be prepared.',
      );
    }

    final sessionId = await _assignPresignedUrls(
      storeId: storeId,
      photos: prepared,
    );
    onProgress?.call(0.3);

    // Preserve input order for commit ↔ local item mapping.
    final results = List<CatalogUploadedPhoto?>.filled(prepared.length, null);
    final uploadFailed = List<String>.from(prepareFailed);
    var completed = 0;
    final total = prepared.length;

    Future<void> uploadOne(int index, PreparedCatalogPhoto photo) async {
      final ok = await _putWithRetries(storeId: storeId, photo: photo);
      if (ok && (photo.s3Key ?? '').isNotEmpty) {
        results[index] = CatalogUploadedPhoto(
          key: photo.s3Key!,
          originalName: photo.originalName,
          bytes: photo.bytes.length,
          width: photo.width,
          height: photo.height,
          thumbhash: photo.thumbhash,
          localPath: photo.localPath,
        );
      } else {
        uploadFailed.add(photo.originalName);
      }
      completed++;
      onProgress?.call(0.3 + (completed / total) * 0.7);
    }

    var next = 0;
    Future<void> worker() async {
      while (true) {
        final index = next++;
        if (index >= prepared.length) return;
        await uploadOne(index, prepared[index]);
      }
    }

    final workers = math.min(maxConcurrentUploads, prepared.length);
    await Future.wait([for (var i = 0; i < workers; i++) worker()]);

    final successful = [
      for (final photo in results)
        if (photo != null) photo,
    ];

    AppLog.d(
      _tag,
      'batch done success=${successful.length} failed=${uploadFailed.length} '
      'session=$sessionId',
    );

    return CatalogDirectUploadBatchResult(
      successful: successful,
      failedNames: uploadFailed,
      sessionId: sessionId,
    );
  }

  Future<PreparedCatalogPhoto> _preparePhoto(String localPath) async {
    final file = File(localPath);
    if (!file.existsSync()) {
      throw CatalogApiException(
        statusCode: 400,
        code: 'INVALID_IMAGE',
        message: 'Image file missing.',
      );
    }

    final originalName = _jpegFileName(p.basename(localPath));
    final rawFileBytes = await file.readAsBytes();
    if (rawFileBytes.isEmpty) {
      throw CatalogApiException(
        statusCode: 400,
        code: 'INVALID_IMAGE',
        message: 'Image file empty.',
      );
    }

    // Decode for true max-edge sizing + ThumbHash (RGBA, not compressed bytes).
    final decoded = img.decodeImage(rawFileBytes);
    var targetW = decoded?.width ?? maxEdgePx;
    var targetH = decoded?.height ?? maxEdgePx;
    if (decoded != null && (targetW > maxEdgePx || targetH > maxEdgePx)) {
      if (targetW >= targetH) {
        targetH = math.max(1, (targetH * maxEdgePx / targetW).round());
        targetW = maxEdgePx;
      } else {
        targetW = math.max(1, (targetW * maxEdgePx / targetH).round());
        targetH = maxEdgePx;
      }
    }

    // JPEG kept for Flutter decode reliability (docs allow WebP or JPEG).
    final compressed =
        await FlutterImageCompress.compressWithList(
          rawFileBytes,
          minWidth: targetW,
          minHeight: targetH,
          quality: jpegQuality,
          format: CompressFormat.jpeg,
          keepExif: false,
        );

    if (compressed.isEmpty) {
      throw CatalogApiException(
        statusCode: 400,
        code: 'INVALID_IMAGE',
        message: 'Image compress produced empty bytes.',
      );
    }

    var width = targetW;
    var height = targetH;
    String? thumbhash;

    try {
      final compressedDecoded = img.decodeImage(compressed);
      if (compressedDecoded != null) {
        width = compressedDecoded.width;
        height = compressedDecoded.height;
      }
      if (decoded != null) {
        thumbhash = _encodeThumbhash(decoded);
      }
    } catch (e) {
      AppLog.e(_tag, 'thumbhash/decode failed', e);
    }

    return PreparedCatalogPhoto(
      localPath: localPath,
      originalName: originalName,
      bytes: Uint8List.fromList(compressed),
      width: width,
      height: height,
      thumbhash: thumbhash,
      contentType: _contentType,
    );
  }

  String? _encodeThumbhash(img.Image source) {
    final maxSide = math.max(source.width, source.height);
    if (maxSide <= 0) return null;
    final scale = math.min(1.0, 100 / maxSide);
    final w = math.max(1, (source.width * scale).round());
    final h = math.max(1, (source.height * scale).round());

    var resized =
        (w == source.width && h == source.height)
            ? source
            : img.copyResize(
              source,
              width: w,
              height: h,
              interpolation: img.Interpolation.average,
            );

    // ThumbHash requires tightly packed RGBA (w * h * 4).
    resized = resized.convert(numChannels: 4, alpha: 255);
    final rgba = resized.getBytes(order: img.ChannelOrder.rgba);
    if (rgba.length != resized.width * resized.height * 4) {
      AppLog.d(
        _tag,
        'thumbhash rgba length mismatch '
        '${rgba.length} vs ${resized.width * resized.height * 4}',
      );
      return null;
    }

    final hashBytes = th.rgbaToThumbHash(
      resized.width,
      resized.height,
      rgba,
    );
    if (hashBytes.length < 5) return null;
    return base64Encode(hashBytes);
  }

  Future<String> _assignPresignedUrls({
    required String storeId,
    required List<PreparedCatalogPhoto> photos,
  }) async {
    if (photos.isEmpty) return '';
    final presign = await _collectionRepository.presignUploads(
      storeId: storeId,
      files: [
        for (final photo in photos)
          CatalogPresignFile(
            filename: photo.originalName,
            contentType: photo.contentType,
          ),
      ],
    );

    if (presign.uploads.length < photos.length) {
      throw CatalogApiException(
        statusCode: 502,
        code: 'UPLOAD_SIGNING_FAILED',
        message: 'Upload URLs incomplete.',
      );
    }

    final now = DateTime.now();
    for (var i = 0; i < photos.length; i++) {
      final slot = presign.uploads[i];
      photos[i].s3Key = slot.key;
      photos[i].presignedUrl = slot.presignedUrl;
      photos[i].putContentType = slot.contentType;
      photos[i].presignedAt = now;
    }
    return presign.sessionId;
  }

  Future<void> _refreshPresignedUrl({
    required String storeId,
    required PreparedCatalogPhoto photo,
  }) async {
    await _assignPresignedUrls(storeId: storeId, photos: [photo]);
  }

  bool _needsPresignRefresh(PreparedCatalogPhoto photo) {
    final url = photo.presignedUrl?.trim() ?? '';
    if (url.isEmpty || photo.presignedAt == null) return true;
    return DateTime.now().difference(photo.presignedAt!).inSeconds >
        _presignRenewAfterSeconds;
  }

  Future<bool> _putWithRetries({
    required String storeId,
    required PreparedCatalogPhoto photo,
  }) async {
    // attempt 0 + up to 3 delayed retries (delays 2/4/8).
    for (var attempt = 0; attempt <= _retryDelaysSeconds.length; attempt++) {
      try {
        if (_needsPresignRefresh(photo)) {
          await _refreshPresignedUrl(storeId: storeId, photo: photo);
        }

        final url = photo.presignedUrl?.trim() ?? '';
        if (url.isEmpty) {
          if (attempt == _retryDelaysSeconds.length) return false;
          await Future<void>.delayed(
            Duration(seconds: _retryDelaysSeconds[attempt]),
          );
          continue;
        }

        final contentType = photo.putContentType ?? photo.contentType;
        // Upload the exact compressed bytes (never re-read the original file).
        final response = await _http
            .put(
              Uri.parse(url),
              headers: {'Content-Type': contentType},
              body: photo.bytes,
            )
            .timeout(const Duration(minutes: 5));

        if (response.statusCode == 200 || response.statusCode == 204) {
          return true;
        }

        AppLog.d(
          _tag,
          'S3 PUT status=${response.statusCode} attempt=${attempt + 1} '
          'name=${photo.originalName}',
        );

        // Expired / forbidden signature — force refresh on next attempt.
        if (response.statusCode == 403) {
          photo.presignedUrl = null;
          photo.presignedAt = null;
        } else if (response.statusCode >= 400 &&
            response.statusCode < 500 &&
            response.statusCode != 429) {
          // Other client errors are not retryable.
          return false;
        }
      } catch (e) {
        AppLog.e(
          _tag,
          'S3 PUT error attempt=${attempt + 1} name=${photo.originalName}',
          e,
        );
        if (attempt == _retryDelaysSeconds.length) return false;
      }

      if (attempt < _retryDelaysSeconds.length) {
        await Future<void>.delayed(
          Duration(seconds: _retryDelaysSeconds[attempt]),
        );
      }
    }
    return false;
  }

  static String _jpegFileName(String original) {
    final base =
        original.contains('.')
            ? original.substring(0, original.lastIndexOf('.'))
            : original;
    final safe =
        base
            .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')
            .replaceAll(RegExp(r'_+'), '_');
    final name = safe.isEmpty ? 'photo' : safe;
    return '$name.jpg';
  }
}
