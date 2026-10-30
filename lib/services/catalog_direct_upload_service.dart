import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fast_thumbhash/fast_thumbhash.dart' as th;
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/catalog_media_debug.dart';
import 'package:project_c/helper/catalog_upload_story.dart';
import 'package:project_c/models/catalog/catalog_upload_models.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';

/// On-device compress + ThumbHash + concurrent direct S3 PUT with silent retries.
///
/// Phase 1 of the catalog two-phase upload: files land in `catalog/staging/...`
/// (uncommitted). Callers commit via
/// [CollectionRepository.createCollectionFromUploads] /
/// [CollectionRepository.appendUploadedPhotos].
///
/// Prepare is crash-safe for 2K/4K (single or bulk): cheap JPEG prefix SOF+EXIF
/// probe → EXIF-aware single-pass long-edge cap ([maxEdgePx], default 1080) →
/// WebP via [FlutterImageCompress.compressWithFile], then ThumbHash from a
/// **native ~100px preview** of that compressed master (never a full-resolution
/// Dart decode of the original or the 608×1080 master). Bounded prepare
/// concurrency defaults to 3.
class CatalogDirectUploadService {
  CatalogDirectUploadService({
    required CollectionRepository collectionRepository,
    http.Client? httpClient,
    this.maxConcurrentUploads = 3,
    this.maxConcurrentPrepares = 3,
    this.maxEdgePx = 1080,
    this.webpQuality = 85,
  }) : _collectionRepository = collectionRepository,
       _http = httpClient ?? http.Client();

  static const _tag = 'CatalogDirectUpload';
  static const _contentType = 'image/webp';

  /// Presigned URLs expire after 900s; renew a bit earlier.
  static const _presignRenewAfterSeconds = 850;

  /// Silent retries with exponential backoff (2s, 4s, 8s).
  static const _retryDelaysSeconds = <int>[2, 4, 8];

  /// Bytes enough for APP1 Exif + SOF on typical camera JPEGs (no full file).
  static const _jpegProbePrefixBytes = 256 * 1024;

  /// Long edge for the native ThumbHash preview (matches prior Dart resize).
  static const _thumbhashLongEdgePx = 100;

  final CollectionRepository _collectionRepository;
  final http.Client _http;
  final int maxConcurrentUploads;
  /// How many photos to prepare in parallel (ordered results). Default 3.
  final int maxConcurrentPrepares;
  final int maxEdgePx;
  final int webpQuality;

  /// Compress, ThumbHash, presign, then upload with concurrency + retries.
  ///
  /// Pass [cancelToken] to stop further PUTs (Scenario 4). Already-finished
  /// uploads stay in S3 staging until lifecycle purge if never committed.
  Future<CatalogDirectUploadBatchResult> prepareAndUpload({
    required String storeId,
    required List<String> localPaths,
    void Function(double progress)? onProgress,
    CatalogUploadCancelToken? cancelToken,
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

    final prepareWorkers = math.min(maxConcurrentPrepares, paths.length).clamp(1, 8);
    CatalogMediaDebug.upload(
      'prepareAndUpload start store=$storeId count=${paths.length} '
      'maxEdge=$maxEdgePx webpQ=$webpQuality '
      'prepareConcurrent=$prepareWorkers putConcurrent=$maxConcurrentUploads',
    );
    CatalogUploadStory.beginCompress(
      count: paths.length,
      maxEdge: maxEdgePx,
      webpQuality: webpQuality,
      concurrent: prepareWorkers,
    );

    final preparedSlots = List<PreparedCatalogPhoto?>.filled(
      paths.length,
      null,
    );
    final prepareFailedNames = <String>[];
    final prepareFailedPaths = <String>[];
    final prepareBatchSw = Stopwatch()..start();
    var prepareNext = 0;
    var prepareCompleted = 0;

    Future<void> prepareWorker() async {
      while (true) {
        if (cancelToken?.isCancelled == true) return;
        final i = prepareNext++;
        if (i >= paths.length) return;
        final path = paths[i];
        final photoSw = Stopwatch()..start();
        CatalogMediaDebug.upload(
          'prepare START ${i + 1}/${paths.length} name=${p.basename(path)}',
        );
        try {
          final photo = await _preparePhoto(
            path,
            index: i + 1,
            total: paths.length,
          );
          preparedSlots[i] = photo;
          CatalogMediaDebug.upload(
            'prepared ${i + 1}/${paths.length} name=${photo.originalName} '
            '${photo.width}x${photo.height} bytes=${photo.bytes.length} '
            '${CatalogMediaDebug.thumbhashFlag(photo.thumbhash)} '
            'totalMs=${photoSw.elapsedMilliseconds}',
          );
          CatalogUploadStory.preparedPhoto(
            index: i + 1,
            total: paths.length,
            name: photo.originalName,
            width: photo.width,
            height: photo.height,
            bytes: photo.bytes.length,
            thumbhash: photo.thumbhash,
          );
          if ((photo.thumbhash ?? '').trim().isEmpty) {
            CatalogMediaDebug.gap(
              'prepare thumbhash NULL name=${photo.originalName}',
            );
            CatalogUploadStory.note(
              'GAP: ThumbHash missing for "${photo.originalName}"',
            );
          }
        } catch (e, st) {
          AppLog.e(_tag, 'prepare failed path=$path', e);
          CatalogMediaDebug.gap(
            'prepare FAILED ${i + 1}/${paths.length} path=$path '
            'ms=${photoSw.elapsedMilliseconds} err=$e',
          );
          CatalogMediaDebug.upload(
            'prepare FAIL stack=${st.toString().split("\n").take(3).join(" | ")}',
          );
          prepareFailedNames.add(p.basename(path));
          prepareFailedPaths.add(path);
        }
        prepareCompleted++;
        onProgress?.call(prepareCompleted / paths.length * 0.25);
        await Future<void>.delayed(Duration.zero);
      }
    }

    await Future.wait([
      for (var w = 0; w < prepareWorkers; w++) prepareWorker(),
    ]);

    if (cancelToken?.isCancelled == true) {
      CatalogMediaDebug.upload(
        'prepare CANCELLED ok=${preparedSlots.whereType<PreparedCatalogPhoto>().length} '
        'fail=${prepareFailedNames.length} '
        'elapsedMs=${prepareBatchSw.elapsedMilliseconds}',
      );
      return CatalogDirectUploadBatchResult(
        successful: const [],
        failedNames: [
          ...prepareFailedNames,
          for (var i = 0; i < paths.length; i++)
            if (preparedSlots[i] == null &&
                !prepareFailedPaths.contains(paths[i]))
              p.basename(paths[i]),
        ],
        failedPaths: [
          ...prepareFailedPaths,
          for (var i = 0; i < paths.length; i++)
            if (preparedSlots[i] == null &&
                !prepareFailedPaths.contains(paths[i]))
              paths[i],
        ],
        cancelled: true,
      );
    }

    final prepared = <PreparedCatalogPhoto>[
      for (final photo in preparedSlots)
        if (photo != null) photo,
    ];

    prepareBatchSw.stop();
    CatalogMediaDebug.upload(
      'prepare DONE ok=${prepared.length} fail=${prepareFailedNames.length} '
      'total=${paths.length} elapsedMs=${prepareBatchSw.elapsedMilliseconds} '
      'maxEdge=$maxEdgePx webpQ=$webpQuality prepareConcurrent=$prepareWorkers',
    );
    if (prepareFailedNames.isNotEmpty) {
      CatalogMediaDebug.gap(
        'prepare failedNames=${prepareFailedNames.join(",")}',
      );
    }

    if (prepared.isEmpty) {
      if (cancelToken?.isCancelled == true) {
        return CatalogDirectUploadBatchResult(
          successful: const [],
          failedNames: prepareFailedNames,
          failedPaths: prepareFailedPaths,
          cancelled: true,
        );
      }
      throw CatalogApiException(
        statusCode: 400,
        code: 'NO_VALID_PHOTOS',
        message: 'None of the photos could be prepared.',
      );
    }

    if (cancelToken?.isCancelled == true) {
      return CatalogDirectUploadBatchResult(
        successful: const [],
        failedNames: [
          ...prepareFailedNames,
          for (final photo in prepared) photo.originalName,
        ],
        failedPaths: [
          ...prepareFailedPaths,
          for (final photo in prepared) photo.localPath,
        ],
        cancelled: true,
      );
    }

    CatalogUploadStory.beginPresign(fileCount: prepared.length);
    final sessionId = await _assignPresignedUrls(
      storeId: storeId,
      photos: prepared,
    );
    CatalogMediaDebug.upload(
      'presign OK session=$sessionId slots=${prepared.length}',
    );
    CatalogUploadStory.beginS3Puts(
      count: prepared.length,
      sessionId: sessionId,
    );
    onProgress?.call(0.3);

    // Preserve input order for commit ↔ local item mapping.
    final results = List<CatalogUploadedPhoto?>.filled(prepared.length, null);
    final uploadFailedNames = List<String>.from(prepareFailedNames);
    final uploadFailedPaths = List<String>.from(prepareFailedPaths);
    var completed = 0;
    final total = prepared.length;

    Future<void> uploadOne(int index, PreparedCatalogPhoto photo) async {
      if (cancelToken?.isCancelled == true) {
        uploadFailedNames.add(photo.originalName);
        uploadFailedPaths.add(photo.localPath);
        completed++;
        onProgress?.call(0.3 + (completed / total) * 0.7);
        return;
      }
      final ok = await _putWithRetries(
        storeId: storeId,
        photo: photo,
        cancelToken: cancelToken,
      );
      if (ok && (photo.s3Key ?? '').isNotEmpty) {
        results[index] = CatalogUploadedPhoto(
          key: photo.s3Key!,
          originalName: photo.originalName,
          bytes: photo.bytes.length,
          width: photo.width,
          height: photo.height,
          thumbhash: photo.thumbhash,
          localPath: photo.localPath,
          imageId: photo.imageId?.trim() ?? '',
          publicUrl: photo.publicUrl?.trim() ?? '',
          thumbnailUrl: photo.thumbnailUrl?.trim() ?? '',
          detailUrl: photo.detailUrl?.trim() ?? '',
        );
        CatalogMediaDebug.upload(
          'S3 PUT OK index=$index name=${photo.originalName} '
          'key=${photo.s3Key} ${CatalogMediaDebug.thumbhashFlag(photo.thumbhash)}',
        );
        CatalogUploadStory.s3PutOk(
          index: index,
          name: photo.originalName,
          key: photo.s3Key!,
        );
      } else {
        CatalogMediaDebug.gap(
          'S3 PUT FAIL index=$index name=${photo.originalName}',
        );
        CatalogUploadStory.s3PutFail(
          index: index,
          name: photo.originalName,
        );
        uploadFailedNames.add(photo.originalName);
        uploadFailedPaths.add(photo.localPath);
      }
      completed++;
      onProgress?.call(0.3 + (completed / total) * 0.7);
    }

    var next = 0;
    Future<void> worker() async {
      while (true) {
        if (cancelToken?.isCancelled == true) return;
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

    final cancelled = cancelToken?.isCancelled == true;
    AppLog.d(
      _tag,
      'batch done success=${successful.length} failed=${uploadFailedNames.length} '
      'session=$sessionId cancelled=$cancelled',
    );
    CatalogMediaDebug.upload(
      'batch done success=${successful.length} failed=${uploadFailedNames.length} '
      'session=$sessionId cancelled=$cancelled',
    );
    CatalogUploadStory.batchDone(
      success: successful.length,
      failed: uploadFailedNames.length,
      cancelled: cancelled,
    );

    return CatalogDirectUploadBatchResult(
      successful: successful,
      failedNames: uploadFailedNames,
      failedPaths: uploadFailedPaths,
      sessionId: sessionId,
      cancelled: cancelled,
    );
  }

  Future<PreparedCatalogPhoto> _preparePhoto(
    String localPath, {
    int index = 0,
    int total = 0,
  }) async {
    final label =
        index > 0 && total > 0 ? '$index/$total' : p.basename(localPath);
    final file = File(localPath);
    if (!file.existsSync()) {
      CatalogMediaDebug.gap('prepare missing file $label path=$localPath');
      throw CatalogApiException(
        statusCode: 400,
        code: 'INVALID_IMAGE',
        message: 'Image file missing.',
      );
    }

    final originalName = _webpFileName(p.basename(localPath));
    final sourceLen = await file.length();
    CatalogMediaDebug.upload(
      'prepare [$label] source name=$originalName '
      'sourceBytes=$sourceLen maxEdge=$maxEdgePx q=$webpQuality',
    );

    // Cheap oriented size: read JPEG prefix only (no full-file isolate copy).
    // Full 5MB compute() probe was 2–3s/photo; prefix SOF+EXIF is ms-scale.
    var targetW = maxEdgePx;
    var targetH = maxEdgePx;
    final probeSw = Stopwatch()..start();
    try {
      final prefix = await _readFilePrefix(
        file,
        maxBytes: _jpegProbePrefixBytes,
      );
      final probed = _jpegOrientedSizeFromPrefix(prefix);
      if (probed != null && probed.width > 0 && probed.height > 0) {
        final fitted = _fitLongEdge(probed.width, probed.height, maxEdgePx);
        targetW = fitted.width;
        targetH = fitted.height;
        CatalogMediaDebug.upload(
          'prepare [$label] oriented ${probed.width}x${probed.height} '
          'exif=${probed.orientation} prefix=${prefix.length} → '
          'target ${targetW}x$targetH ms=${probeSw.elapsedMilliseconds}',
        );
      } else {
        CatalogMediaDebug.upload(
          'prepare [$label] oriented probe unavailable → '
          'target ${targetW}x$targetH ms=${probeSw.elapsedMilliseconds}',
        );
      }
    } catch (e) {
      CatalogMediaDebug.gap(
        'prepare [$label] oriented probe FAILED err=$e → '
        'target ${targetW}x$targetH',
      );
    }

    // Single native pass to final dimensions (autoCorrectionAngle applies EXIF).
    // Prefer compressWithFile so we never load the full original into Dart heap.
    final compressSw = Stopwatch()..start();
    var usedListFallback = false;
    final fromFile = await FlutterImageCompress.compressWithFile(
      localPath,
      minWidth: targetW,
      minHeight: targetH,
      quality: webpQuality,
      format: CompressFormat.webp,
      keepExif: false,
      autoCorrectionAngle: true,
    );

    late final Uint8List compressed;
    if (fromFile != null && fromFile.isNotEmpty) {
      compressed = fromFile;
    } else {
      usedListFallback = true;
      final rawFileBytes = await file.readAsBytes();
      if (rawFileBytes.isEmpty) {
        CatalogMediaDebug.gap('prepare [$label] source file empty');
        throw CatalogApiException(
          statusCode: 400,
          code: 'INVALID_IMAGE',
          message: 'Image file empty.',
        );
      }
      final fromList = await FlutterImageCompress.compressWithList(
        rawFileBytes,
        minWidth: targetW,
        minHeight: targetH,
        quality: webpQuality,
        format: CompressFormat.webp,
        keepExif: false,
        autoCorrectionAngle: true,
      );
      if (fromList.isEmpty) {
        compressSw.stop();
        CatalogMediaDebug.gap(
          'prepare [$label] compress produced empty '
          'listFallback=$usedListFallback ms=${compressSw.elapsedMilliseconds}',
        );
        throw CatalogApiException(
          statusCode: 400,
          code: 'INVALID_IMAGE',
          message: 'Image compress produced empty bytes.',
        );
      }
      compressed = fromList;
    }
    compressSw.stop();

    CatalogMediaDebug.upload(
      'prepare [$label] compress OK listFallback=$usedListFallback '
      'outBytes=${compressed.length} ms=${compressSw.elapsedMilliseconds}',
    );

    var masterBytes = Uint8List.fromList(compressed);
    var width = targetW;
    var height = targetH;

    // Verify final WebP once on this isolate (small buffer — no compute copy).
    try {
      final sized = _catalogProbeImageSize(masterBytes);
      if (sized != null && sized.width > 0 && sized.height > 0) {
        width = sized.width;
        height = sized.height;
      }
    } catch (e) {
      CatalogMediaDebug.gap('prepare [$label] verify size FAILED err=$e');
    }

    if (math.max(width, height) > maxEdgePx && width > 0 && height > 0) {
      final fitted = _fitLongEdge(width, height, maxEdgePx);
      final recapSw = Stopwatch()..start();
      CatalogMediaDebug.upload(
        'prepare [$label] fallback recap ${width}x$height → '
        '${fitted.width}x${fitted.height}',
      );
      final recap = await FlutterImageCompress.compressWithList(
        masterBytes,
        minWidth: fitted.width,
        minHeight: fitted.height,
        quality: webpQuality,
        format: CompressFormat.webp,
        keepExif: false,
        autoCorrectionAngle: false,
      );
      if (recap.isNotEmpty) {
        masterBytes = Uint8List.fromList(recap);
        CatalogMediaDebug.upload(
          'prepare [$label] fallback recap OK outBytes=${masterBytes.length} '
          'ms=${recapSw.elapsedMilliseconds}',
        );
      } else {
        CatalogMediaDebug.gap(
          'prepare [$label] fallback recap empty '
          'ms=${recapSw.elapsedMilliseconds}',
        );
      }
    }

    String? thumbhash;
    try {
      final meta = await _metaFromCompressedMaster(
        masterBytes,
        knownWidth: width,
        knownHeight: height,
        label: label,
      );
      if (meta.width > 0) width = meta.width;
      if (meta.height > 0) height = meta.height;
      thumbhash = meta.thumbhash;
    } catch (e) {
      AppLog.e(_tag, 'thumbhash/decode failed', e);
      CatalogMediaDebug.gap('prepare [$label] meta/thumbhash FAILED err=$e');
    }

    final longEdge = math.max(width, height);
    if (longEdge > maxEdgePx) {
      CatalogMediaDebug.gap(
        'prepare [$label] longEdge=$longEdge > maxEdge=$maxEdgePx '
        '(compress may not have capped)',
      );
    } else {
      CatalogMediaDebug.upload(
        'prepare [$label] longEdge OK longEdge=$longEdge maxEdge=$maxEdgePx',
      );
    }

    return PreparedCatalogPhoto(
      localPath: localPath,
      originalName: originalName,
      bytes: masterBytes,
      width: width,
      height: height,
      thumbhash: thumbhash,
      contentType: _contentType,
    );
  }

  /// ThumbHash from compressed master — never re-decodes the original JPEG.
  ///
  /// Fast path: native shrink of the WebP master to ~100px long-edge JPEG, then
  /// a tiny Dart decode + [th.rgbaToThumbHash] on this isolate (no [compute]
  /// spawn). Fallback: prior full-master [compute] path if native shrink fails.
  Future<_CompressedMasterMeta> _metaFromCompressedMaster(
    Uint8List masterBytes, {
    required int knownWidth,
    required int knownHeight,
    required String label,
  }) async {
    final wall = Stopwatch()..start();
    final inBytes = masterBytes.length;

    // --- Fast path: native preview → tiny Dart decode (UI-safe, ms-scale) ---
    try {
      final previewW =
          knownWidth > 0 ? knownWidth : maxEdgePx;
      final previewH =
          knownHeight > 0 ? knownHeight : maxEdgePx;
      final fitted = _fitLongEdge(
        previewW,
        previewH,
        _thumbhashLongEdgePx,
      );
      final tinySw = Stopwatch()..start();
      final tiny = await FlutterImageCompress.compressWithList(
        masterBytes,
        minWidth: fitted.width,
        minHeight: fitted.height,
        quality: 85,
        format: CompressFormat.jpeg,
        keepExif: false,
        autoCorrectionAngle: false,
      );
      final tinyMs = tinySw.elapsedMilliseconds;

      if (tiny.isNotEmpty) {
        // Yield so the UI can paint between native compress and sync decode.
        await Future<void>.delayed(Duration.zero);
        final workSw = Stopwatch()..start();
        final meta = _catalogThumbhashFromPreviewBytes(
          tiny,
          masterWidth: knownWidth,
          masterHeight: knownHeight,
        );
        final workMs = workSw.elapsedMilliseconds;
        if ((meta.thumbhash ?? '').isNotEmpty) {
          CatalogMediaDebug.upload(
            'prepare [$label] meta ${meta.width}x${meta.height} '
            '${CatalogMediaDebug.thumbhashFlag(meta.thumbhash)} '
            'path=nativePreview wallMs=${wall.elapsedMilliseconds} '
            'inBytes=$inBytes tinyBytes=${tiny.length} tinyMs=$tinyMs '
            'workMs=$workMs decode=${meta.decodeMs} resize=${meta.resizeMs} '
            'rgba=${meta.rgbaMs} hash=${meta.hashMs} b64=${meta.base64Ms}',
          );
          return meta;
        }
        CatalogMediaDebug.gap(
          'prepare [$label] meta nativePreview empty hash '
          'tinyMs=$tinyMs workMs=$workMs → fallback compute',
        );
      } else {
        CatalogMediaDebug.gap(
          'prepare [$label] meta nativePreview empty bytes '
          'tinyMs=$tinyMs → fallback compute',
        );
      }
    } catch (e) {
      CatalogMediaDebug.gap(
        'prepare [$label] meta nativePreview FAILED err=$e → fallback compute',
      );
    }

    // --- Fallback: full-master decode on a background isolate (prior path) ---
    final computeSw = Stopwatch()..start();
    final meta = await compute(_catalogMetaFromCompressedMaster, masterBytes);
    CatalogMediaDebug.upload(
      'prepare [$label] meta ${meta.width}x${meta.height} '
      '${CatalogMediaDebug.thumbhashFlag(meta.thumbhash)} '
      'path=fullCompute wallMs=${wall.elapsedMilliseconds} '
      'computeMs=${computeSw.elapsedMilliseconds} inBytes=$inBytes '
      'decode=${meta.decodeMs} resize=${meta.resizeMs} '
      'rgba=${meta.rgbaMs} hash=${meta.hashMs} b64=${meta.base64Ms}',
    );
    return meta;
  }

  /// Aspect-correct size with long edge ≤ [maxEdge].
  static ({int width, int height}) _fitLongEdge(
    int width,
    int height,
    int maxEdge,
  ) {
    if (width <= 0 || height <= 0 || maxEdge <= 0) {
      return (width: maxEdge, height: maxEdge);
    }
    if (width <= maxEdge && height <= maxEdge) {
      return (width: width, height: height);
    }
    if (width >= height) {
      return (
        width: maxEdge,
        height: math.max(1, (height * maxEdge / width).round()),
      );
    }
    return (
      width: math.max(1, (width * maxEdge / height).round()),
      height: maxEdge,
    );
  }

  /// Read at most [maxBytes] from the start of [file] (probe only).
  static Future<Uint8List> _readFilePrefix(
    File file, {
    required int maxBytes,
  }) async {
    final len = await file.length();
    if (len <= 0) return Uint8List(0);
    final take = math.min(len, maxBytes);
    final raf = await file.open(mode: FileMode.read);
    try {
      return await raf.read(take);
    } finally {
      await raf.close();
    }
  }

  /// Oriented display size from a JPEG/PNG prefix — never loads the full file.
  static _OrientedImageSize? _jpegOrientedSizeFromPrefix(Uint8List data) {
    final fromJpeg = _parseJpegOrientedSize(data);
    if (fromJpeg != null) return fromJpeg;
    // PNG IHDR / partial JPEG: header decode on the same small buffer.
    return _catalogProbeOrientedSize(data);
  }

  /// Manual JPEG SOF + APP1 Exif orientation (tags 5–8 swap W/H).
  static _OrientedImageSize? _parseJpegOrientedSize(Uint8List data) {
    if (data.length < 4 || data[0] != 0xFF || data[1] != 0xD8) return null;

    var i = 2;
    int? width;
    int? height;
    var orientation = 1;

    while (i + 1 < data.length) {
      if (data[i] != 0xFF) {
        i++;
        continue;
      }
      while (i < data.length && data[i] == 0xFF) {
        i++;
      }
      if (i >= data.length) break;

      final marker = data[i++];
      // Standalone markers (no length).
      if (marker == 0xD8) continue; // nested SOI
      if (marker == 0xD9) break; // EOI
      if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) continue;
      if (marker == 0xDA) break; // SOS — image data follows

      if (i + 1 >= data.length) break;
      final segLen = (data[i] << 8) | data[i + 1];
      if (segLen < 2) break;
      final segEnd = i + segLen;
      if (segEnd > data.length) break;
      final payloadStart = i + 2;

      final isSof =
          (marker >= 0xC0 && marker <= 0xC3) ||
          (marker >= 0xC5 && marker <= 0xC7) ||
          (marker >= 0xC9 && marker <= 0xCB) ||
          (marker >= 0xCD && marker <= 0xCF);
      if (isSof && segEnd - payloadStart >= 5) {
        height = (data[payloadStart + 1] << 8) | data[payloadStart + 2];
        width = (data[payloadStart + 3] << 8) | data[payloadStart + 4];
      }

      if (marker == 0xE1) {
        final o = _exifOrientationFromApp1(data, payloadStart, segEnd);
        if (o != null) orientation = o;
      }

      i = segEnd;
      if (width != null && height != null && orientation != 1) {
        // Have both SOF and a non-default orientation — done.
        break;
      }
    }

    final sofW = width;
    final sofH = height;
    if (sofW == null || sofH == null || sofW <= 0 || sofH <= 0) {
      return null;
    }

    var w = sofW;
    var h = sofH;
    if (orientation >= 5 && orientation <= 8) {
      final tmp = w;
      w = h;
      h = tmp;
    }
    return _OrientedImageSize(
      width: w,
      height: h,
      orientation: orientation,
    );
  }

  /// EXIF Orientation (0x0112) from an APP1 payload (`Exif\0\0` + TIFF).
  static int? _exifOrientationFromApp1(
    Uint8List data,
    int start,
    int end,
  ) {
    if (end - start < 14) return null;
    if (data[start] != 0x45 ||
        data[start + 1] != 0x78 ||
        data[start + 2] != 0x69 ||
        data[start + 3] != 0x66 ||
        data[start + 4] != 0 ||
        data[start + 5] != 0) {
      return null;
    }

    final tiff = start + 6;
    final little =
        data[tiff] == 0x49 && data[tiff + 1] == 0x49;
    final big = data[tiff] == 0x4D && data[tiff + 1] == 0x4D;
    if (!little && !big) return null;

    int u16(int off) {
      if (off + 1 >= end) return -1;
      return little
          ? data[off] | (data[off + 1] << 8)
          : (data[off] << 8) | data[off + 1];
    }

    int u32(int off) {
      if (off + 3 >= end) return -1;
      return little
          ? data[off] |
              (data[off + 1] << 8) |
              (data[off + 2] << 16) |
              (data[off + 3] << 24)
          : (data[off] << 24) |
              (data[off + 1] << 16) |
              (data[off + 2] << 8) |
              data[off + 3];
    }

    if (u16(tiff + 2) != 42) return null;
    final ifd0Rel = u32(tiff + 4);
    if (ifd0Rel < 0) return null;
    final ifd0 = tiff + ifd0Rel;
    final count = u16(ifd0);
    if (count <= 0) return null;

    for (var e = 0; e < count; e++) {
      final entry = ifd0 + 2 + e * 12;
      if (entry + 12 > end) break;
      if (u16(entry) != 0x0112) continue;
      final type = u16(entry + 2);
      final valueOff = entry + 8;
      final orientation = type == 4 ? u32(valueOff) : u16(valueOff);
      if (orientation >= 1 && orientation <= 8) return orientation;
      return null;
    }
    return null;
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
      photos[i].imageId = slot.imageId.trim().isEmpty ? null : slot.imageId;
      photos[i].publicUrl = slot.url.trim().isEmpty ? null : slot.url;
      photos[i].thumbnailUrl =
          slot.thumbnailUrl.trim().isEmpty ? null : slot.thumbnailUrl;
      photos[i].detailUrl =
          slot.detailUrl.trim().isEmpty ? null : slot.detailUrl;
      photos[i].presignedUrl = slot.presignedUrl;
      photos[i].putContentType = slot.contentType;
      photos[i].presignedAt = now;
      CatalogMediaDebug.upload(
        'sign slot[$i] imageId=${slot.imageId} key=${slot.key} '
        'master=${CatalogMediaDebug.shortUrl(slot.url)} '
        'thumb=${slot.thumbnailUrl.isEmpty ? "NULL" : CatalogMediaDebug.shortUrl(slot.thumbnailUrl)} '
        'detail=${slot.detailUrl.isEmpty ? "NULL" : CatalogMediaDebug.shortUrl(slot.detailUrl)} '
        'expiresIn=${slot.expiresIn}',
      );
      if (slot.imageId.trim().isEmpty) {
        CatalogMediaDebug.gap('sign slot[$i] missing imageId');
      }
      if (slot.thumbnailUrl.trim().isEmpty || slot.detailUrl.trim().isEmpty) {
        CatalogMediaDebug.gap(
          'sign slot[$i] missing responsive URLs '
          'thumb=${slot.thumbnailUrl.isEmpty} detail=${slot.detailUrl.isEmpty}',
        );
      }
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
    CatalogUploadCancelToken? cancelToken,
  }) async {
    // attempt 0 + up to 3 delayed retries (delays 2/4/8).
    for (var attempt = 0; attempt <= _retryDelaysSeconds.length; attempt++) {
      if (cancelToken?.isCancelled == true) return false;
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
        final bytes = photo.bytes;
        if (bytes.isEmpty) {
          AppLog.e(_tag, 'S3 PUT refuse empty bytes name=${photo.originalName}');
          return false;
        }
        // Exact compressed WebP bytes + explicit Content-Length (avoids
        // chunked/0-byte PUTs that S3 may accept while leaving empty objects).
        final request =
            http.Request('PUT', Uri.parse(url))
              ..headers['Content-Type'] = contentType
              ..headers['Content-Length'] = '${bytes.length}'
              ..bodyBytes = bytes;
        final streamed = await _http
            .send(request)
            .timeout(const Duration(minutes: 5));
        final response = await http.Response.fromStream(streamed);

        if (response.statusCode == 200 || response.statusCode == 204) {
          AppLog.d(
            _tag,
            'S3 PUT OK name=${photo.originalName} bytes=${bytes.length} '
            'key=${photo.s3Key ?? ''}',
          );
          CatalogMediaDebug.step(
            '2 R2 PUT OK',
            detail:
                'name=${photo.originalName} bytes=${bytes.length} '
                'imageId=${photo.imageId ?? ""} key=${photo.s3Key ?? ""} '
                'contentType=$contentType',
          );
          return true;
        }

        AppLog.d(
          _tag,
          'S3 PUT status=${response.statusCode} attempt=${attempt + 1} '
          'name=${photo.originalName} bytes=${bytes.length} '
          'body=${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
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
        if (cancelToken?.isCancelled == true) return false;
        await Future<void>.delayed(
          Duration(seconds: _retryDelaysSeconds[attempt]),
        );
      }
    }
    return false;
  }

  static String _webpFileName(String original) {
    final base =
        original.contains('.')
            ? original.substring(0, original.lastIndexOf('.'))
            : original;
    final safe =
        base
            .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')
            .replaceAll(RegExp(r'_+'), '_');
    final name = safe.isEmpty ? 'photo' : safe;
    return '$name.webp';
  }
}

/// Size + ThumbHash + stage timings (isolate-safe for [compute]).
class _CompressedMasterMeta {
  const _CompressedMasterMeta({
    required this.width,
    required this.height,
    this.thumbhash,
    this.decodeMs = 0,
    this.resizeMs = 0,
    this.rgbaMs = 0,
    this.hashMs = 0,
    this.base64Ms = 0,
  });

  final int width;
  final int height;
  final String? thumbhash;
  final int decodeMs;
  final int resizeMs;
  final int rgbaMs;
  final int hashMs;
  final int base64Ms;
}

/// Header size only (isolate-safe for [compute]).
class _ImageSizeProbe {
  const _ImageSizeProbe({required this.width, required this.height});

  final int width;
  final int height;
}

/// Display size after EXIF orientation is applied.
class _OrientedImageSize {
  const _OrientedImageSize({
    required this.width,
    required this.height,
    required this.orientation,
  });

  final int width;
  final int height;
  final int orientation;
}

/// Header size only — used to verify compressed output (not for ThumbHash).
_ImageSizeProbe? _catalogProbeImageSize(Uint8List bytes) {
  final decoder = img.findDecoderForData(bytes);
  if (decoder == null) return null;
  final info = decoder.startDecode(bytes);
  if (info == null || info.width <= 0 || info.height <= 0) return null;
  return _ImageSizeProbe(width: info.width, height: info.height);
}

/// Fallback oriented probe on a **prefix** buffer (image package, no isolate).
_OrientedImageSize? _catalogProbeOrientedSize(Uint8List bytes) {
  final decoder = img.findDecoderForData(bytes);
  if (decoder == null) return null;
  final info = decoder.startDecode(bytes);
  if (info == null || info.width <= 0 || info.height <= 0) return null;

  var width = info.width;
  var height = info.height;
  var orientation = 1;
  try {
    final exif = img.decodeJpgExif(bytes);
    orientation = exif?.imageIfd.orientation ?? 1;
    // EXIF 5–8 rotate/transpose so displayed axes swap.
    if (orientation >= 5 && orientation <= 8) {
      final tmp = width;
      width = height;
      height = tmp;
    }
  } catch (_) {
    // Non-JPEG or missing EXIF — keep sensor dimensions.
  }
  return _OrientedImageSize(
    width: width,
    height: height,
    orientation: orientation,
  );
}

/// ThumbHash from a **tiny** preview (≤~100px long edge). Same RGBA +
/// [th.rgbaToThumbHash] + Base64 contract as the full-master path.
_CompressedMasterMeta _catalogThumbhashFromPreviewBytes(
  Uint8List previewBytes, {
  required int masterWidth,
  required int masterHeight,
}) {
  final sw = Stopwatch()..start();
  final decoded = img.decodeImage(previewBytes);
  final decodeMs = sw.elapsedMilliseconds;
  if (decoded == null) {
    return _CompressedMasterMeta(
      width: masterWidth,
      height: masterHeight,
      decodeMs: decodeMs,
    );
  }

  final hashed = _catalogThumbhashFromDecoded(
    decoded,
    longEdgePx: CatalogDirectUploadService._thumbhashLongEdgePx,
  );
  return _CompressedMasterMeta(
    width: masterWidth > 0 ? masterWidth : decoded.width,
    height: masterHeight > 0 ? masterHeight : decoded.height,
    thumbhash: hashed.thumbhash,
    decodeMs: decodeMs,
    resizeMs: hashed.resizeMs,
    rgbaMs: hashed.rgbaMs,
    hashMs: hashed.hashMs,
    base64Ms: hashed.base64Ms,
  );
}

/// Decode full compressed master + ThumbHash (compute fallback only).
_CompressedMasterMeta _catalogMetaFromCompressedMaster(Uint8List bytes) {
  final sw = Stopwatch()..start();
  final decoded = img.decodeImage(bytes);
  final decodeMs = sw.elapsedMilliseconds;
  if (decoded == null) {
    return _CompressedMasterMeta(width: 0, height: 0, decodeMs: decodeMs);
  }

  final hashed = _catalogThumbhashFromDecoded(
    decoded,
    longEdgePx: CatalogDirectUploadService._thumbhashLongEdgePx,
  );
  return _CompressedMasterMeta(
    width: decoded.width,
    height: decoded.height,
    thumbhash: hashed.thumbhash,
    decodeMs: decodeMs,
    resizeMs: hashed.resizeMs,
    rgbaMs: hashed.rgbaMs,
    hashMs: hashed.hashMs,
    base64Ms: hashed.base64Ms,
  );
}

/// Shared resize → RGBA → [th.rgbaToThumbHash] → Base64.
({
  String? thumbhash,
  int resizeMs,
  int rgbaMs,
  int hashMs,
  int base64Ms,
})
_catalogThumbhashFromDecoded(
  img.Image decoded, {
  required int longEdgePx,
}) {
  final sw = Stopwatch()..start();
  final maxSide = math.max(decoded.width, decoded.height);
  if (maxSide <= 0) {
    return (
      thumbhash: null,
      resizeMs: 0,
      rgbaMs: 0,
      hashMs: 0,
      base64Ms: 0,
    );
  }

  final scale = math.min(1.0, longEdgePx / maxSide);
  final thumbW = math.max(1, (decoded.width * scale).round());
  final thumbH = math.max(1, (decoded.height * scale).round());
  final small =
      (thumbW == decoded.width && thumbH == decoded.height)
          ? decoded
          : img.copyResize(
            decoded,
            width: thumbW,
            height: thumbH,
            interpolation: img.Interpolation.average,
          );
  final resizeMs = sw.elapsedMilliseconds;

  sw
    ..reset()
    ..start();
  final rgbaImage =
      small.numChannels == 4
          ? small
          : small.convert(numChannels: 4, alpha: 255);
  final rgba = rgbaImage.getBytes(order: img.ChannelOrder.rgba);
  final rgbaMs = sw.elapsedMilliseconds;
  if (rgba.length != rgbaImage.width * rgbaImage.height * 4) {
    return (
      thumbhash: null,
      resizeMs: resizeMs,
      rgbaMs: rgbaMs,
      hashMs: 0,
      base64Ms: 0,
    );
  }

  sw
    ..reset()
    ..start();
  final hashBytes = th.rgbaToThumbHash(
    rgbaImage.width,
    rgbaImage.height,
    rgba,
  );
  final hashMs = sw.elapsedMilliseconds;
  if (hashBytes.length < 5) {
    return (
      thumbhash: null,
      resizeMs: resizeMs,
      rgbaMs: rgbaMs,
      hashMs: hashMs,
      base64Ms: 0,
    );
  }

  sw
    ..reset()
    ..start();
  final thumbhash = base64Encode(hashBytes);
  final base64Ms = sw.elapsedMilliseconds;

  return (
    thumbhash: thumbhash,
    resizeMs: resizeMs,
    rgbaMs: rgbaMs,
    hashMs: hashMs,
    base64Ms: base64Ms,
  );
}
