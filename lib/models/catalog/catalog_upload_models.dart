import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Cooperative cancel flag for one [CatalogDirectUploadService] batch.
class CatalogUploadCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

/// One file descriptor sent to `POST .../uploads/presign`.
class CatalogPresignFile extends Equatable {
  const CatalogPresignFile({
    required this.filename,
    this.contentType = 'image/webp',
  });

  final String filename;
  final String contentType;

  Map<String, dynamic> toJson() => {
    'filename': filename,
    'contentType': contentType,
  };

  @override
  List<Object?> get props => [filename, contentType];
}

/// One pre-signed S3 PUT slot from the sign / presign endpoint.
class CatalogPresignedUpload extends Equatable {
  const CatalogPresignedUpload({
    required this.key,
    required this.url,
    required this.presignedUrl,
    required this.contentType,
    this.thumbnailUrl = '',
    this.detailUrl = '',
    this.imageId = '',
    this.expiresIn = 900,
  });

  final String key;

  /// CDN / public master URL (`publicUrl` on new sign; `url` on legacy presign).
  final String url;

  /// Cloudflare ~320×320 grid variant when BE includes it on sign.
  final String thumbnailUrl;

  /// Cloudflare ~1080px detail variant when BE includes it on sign.
  final String detailUrl;
  final String presignedUrl;
  final String contentType;

  /// Pre-allocated image id from `POST /uploads/sign` (required for products/batch).
  final String imageId;
  final int expiresIn;

  factory CatalogPresignedUpload.fromJson(Map<String, dynamic> json) {
    final headers = json['headers'];
    final contentType =
        headers is Map
            ? (headers['Content-Type'] as String? ??
                headers['content-type'] as String? ??
                'image/webp')
            : 'image/webp';
    return CatalogPresignedUpload(
      key: json['key'] as String? ?? '',
      url:
          (json['publicUrl'] as String?)?.trim().isNotEmpty == true
              ? (json['publicUrl'] as String).trim()
              : (json['url'] as String? ?? ''),
      thumbnailUrl: (json['thumbnailUrl'] as String?)?.trim() ?? '',
      detailUrl: (json['detailUrl'] as String?)?.trim() ?? '',
      presignedUrl: json['presignedUrl'] as String? ?? '',
      contentType: contentType,
      imageId:
          (json['imageId'] as String?)?.trim() ??
          (json['image_id'] as String?)?.trim() ??
          '',
      expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 900,
    );
  }

  @override
  List<Object?> get props => [
    key,
    url,
    thumbnailUrl,
    detailUrl,
    presignedUrl,
    contentType,
    imageId,
    expiresIn,
  ];
}

class CatalogPresignResult extends Equatable {
  const CatalogPresignResult({
    required this.count,
    required this.uploads,
    this.sessionId = '',
  });

  final int count;
  final String sessionId;
  final List<CatalogPresignedUpload> uploads;

  factory CatalogPresignResult.fromJson(Map<String, dynamic> json) {
    final raw = json['uploads'];
    return CatalogPresignResult(
      count: (json['count'] as num?)?.toInt() ?? 0,
      sessionId: json['sessionId'] as String? ?? '',
      uploads:
          raw is List
              ? raw
                  .whereType<Map<String, dynamic>>()
                  .map(CatalogPresignedUpload.fromJson)
                  .toList()
              : const [],
    );
  }

  @override
  List<Object?> get props => [count, sessionId, uploads];
}

/// Local photo after on-device compress + ThumbHash, ready for S3 PUT.
class PreparedCatalogPhoto {
  PreparedCatalogPhoto({
    required this.localPath,
    required this.originalName,
    required this.bytes,
    required this.width,
    required this.height,
    this.thumbhash,
    this.contentType = 'image/webp',
  });

  final String localPath;
  final String originalName;

  /// Exact compressed bytes that must be PUT to S3 (never re-read original).
  final Uint8List bytes;
  final int width;
  final int height;
  final String? thumbhash;
  final String contentType;

  String? s3Key;
  String? imageId;
  String? publicUrl;
  String? thumbnailUrl;
  String? detailUrl;
  String? presignedUrl;
  String? putContentType;
  DateTime? presignedAt;
}

/// Successful direct-to-S3 upload payload for Phase 2 JSON commit.
class CatalogUploadedPhoto extends Equatable {
  const CatalogUploadedPhoto({
    required this.key,
    required this.originalName,
    required this.bytes,
    required this.width,
    required this.height,
    this.thumbhash,
    this.localPath,
    this.imageId = '',
    this.publicUrl = '',
    this.thumbnailUrl = '',
    this.detailUrl = '',
  });

  final String key;
  final String originalName;
  final int bytes;
  final int width;
  final int height;
  final String? thumbhash;

  /// Client-only path used to map back to local gallery items (not sent to API).
  final String? localPath;

  /// From `POST /uploads/sign` — used by `POST …/products/batch`.
  final String imageId;
  final String publicUrl;
  final String thumbnailUrl;
  final String detailUrl;

  Map<String, dynamic> toJson() => {
    'key': key,
    if (thumbhash != null && thumbhash!.isNotEmpty) 'thumbhash': thumbhash,
    'width': width,
    'height': height,
    'bytes': bytes,
    'originalName': originalName,
    if (imageId.trim().isNotEmpty) 'imageId': imageId.trim(),
  };

  @override
  List<Object?> get props => [
    key,
    originalName,
    bytes,
    width,
    height,
    thumbhash,
    localPath,
    imageId,
    publicUrl,
    thumbnailUrl,
    detailUrl,
  ];
}

/// Result of preparing + uploading a batch to S3 (before MongoDB commit).
class CatalogDirectUploadBatchResult {
  const CatalogDirectUploadBatchResult({
    required this.successful,
    required this.failedNames,
    this.failedPaths = const [],
    this.sessionId = '',
    this.cancelled = false,
  });

  final List<CatalogUploadedPhoto> successful;
  final List<String> failedNames;

  /// Local paths that failed prepare/upload (for Retry Failed).
  final List<String> failedPaths;
  final String sessionId;
  final bool cancelled;

  bool get hasSuccess => successful.isNotEmpty;
  bool get allFailed => successful.isEmpty;
}
