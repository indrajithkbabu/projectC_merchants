import 'package:project_c/models/catalog/collection_models.dart';

/// Typed failure from the Catalog API or transport layer.
class CatalogApiException implements Exception {
  CatalogApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.details = const [],
    this.failedPhotos = const [],
    this.retryAfterSeconds,
  });

  final int statusCode;
  final String code;
  final String message;
  final List<dynamic> details;
  final List<FailedPhoto> failedPhotos;
  final int? retryAfterSeconds;

  bool get isUnauthorized => statusCode == 401;
  bool get isRateLimited => statusCode == 429;
  bool get isUnavailable => statusCode == 503;

  @override
  String toString() =>
      'CatalogApiException($statusCode, $code, $message)';
}
