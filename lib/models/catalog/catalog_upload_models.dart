import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// One file descriptor sent to `POST .../uploads/presign`.
class CatalogPresignFile extends Equatable {
  const CatalogPresignFile({
    required this.filename,
    this.contentType = 'image/jpeg',
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

/// One pre-signed S3 PUT slot from the presign endpoint.
class CatalogPresignedUpload extends Equatable {
  const CatalogPresignedUpload({
    required this.key,
    required this.url,
    required this.presignedUrl,
    required this.contentType,
    this.expiresIn = 900,
  });

  final String key;
  final String url;
  final String presignedUrl;
  final String contentType;
  final int expiresIn;

  factory CatalogPresignedUpload.fromJson(Map<String, dynamic> json) {
    final headers = json['headers'];
    final contentType =
        headers is Map
            ? (headers['Content-Type'] as String? ??
                headers['content-type'] as String? ??
                'image/jpeg')
            : 'image/jpeg';
    return CatalogPresignedUpload(
      key: json['key'] as String? ?? '',
      url: json['url'] as String? ?? '',
      presignedUrl: json['presignedUrl'] as String? ?? '',
      contentType: contentType,
      expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 900,
    );
  }

  @override
  List<Object?> get props => [key, url, presignedUrl, contentType, expiresIn];
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
    this.contentType = 'image/jpeg',
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
  });

  final String key;
  final String originalName;
  final int bytes;
  final int width;
  final int height;
  final String? thumbhash;

  /// Client-only path used to map back to local gallery items (not sent to API).
  final String? localPath;

  Map<String, dynamic> toJson() => {
    'key': key,
    if (thumbhash != null && thumbhash!.isNotEmpty) 'thumbhash': thumbhash,
    'width': width,
    'height': height,
    'bytes': bytes,
    'originalName': originalName,
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
  ];
}

/// Result of preparing + uploading a batch to S3 (before MongoDB commit).
class CatalogDirectUploadBatchResult {
  const CatalogDirectUploadBatchResult({
    required this.successful,
    required this.failedNames,
    this.sessionId = '',
  });

  final List<CatalogUploadedPhoto> successful;
  final List<String> failedNames;
  final String sessionId;

  bool get hasSuccess => successful.isNotEmpty;
  bool get allFailed => successful.isEmpty;
}
