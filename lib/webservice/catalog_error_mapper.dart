import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';

/// Maps API / transport errors to short user-facing copy.
///
/// Rules:
/// - Branch on [CatalogApiException.code] (and status), never show raw API
///   `message`, stack traces, JSON, or code strings like `SLUG_TAKEN`.
/// - Unknown codes fall back to a safe status-based line (never backend text).
class CatalogErrorMapper {
  CatalogErrorMapper._();

  /// Last-resort copy when no status/code mapping applies.
  static const String _fallback =
      'Something went wrong. Please try again.';

  static String toUserMessage(Object error) {
    if (error is CatalogApiException) {
      // Prefer the first per-file failure code when the whole request failed.
      if (error.code == 'NO_VALID_PHOTOS' && error.failedPhotos.isNotEmpty) {
        final fileCode = error.failedPhotos.first.code.trim();
        final fromFile = _fromCode(fileCode);
        if (fromFile != null) return fromFile;
      }

      final mapped = _fromCode(error.code);
      if (mapped != null) {
        if (error.code == 'RATE_LIMITED' &&
            error.retryAfterSeconds != null &&
            error.retryAfterSeconds! > 0) {
          final sec = error.retryAfterSeconds!;
          if (sec <= 60) {
            return 'Too many attempts. Please wait a minute and try again.';
          }
          final minutes = (sec / 60).ceil();
          return minutes == 1
              ? 'Too many attempts. Please wait about a minute and try again.'
              : 'Too many attempts. Please wait about $minutes minutes and try again.';
        }
        return mapped;
      }

      return _fromStatus(error.statusCode) ?? _fallback;
    }

    final text = error.toString().toLowerCase();
    if (text.contains('socket') ||
        text.contains('network') ||
        text.contains('failed host lookup') ||
        text.contains('connection')) {
      return 'No internet connection. Check your network and try again.';
    }
    if (text.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    return _fallback;
  }

  /// Summarize partial create failures for snackbars (never uses server text).
  static String failedPhotosSummary(List<FailedPhoto> failedPhotos) {
    if (failedPhotos.isEmpty) {
      return 'Some photos could not be uploaded.';
    }
    final count = failedPhotos.length;
    final firstMapped = _fromCode(failedPhotos.first.code.trim());
    if (count == 1 && firstMapped != null) return firstMapped;
    if (count == 1) return '1 photo could not be uploaded.';
    if (firstMapped != null) {
      return '$count photos could not be uploaded. $firstMapped';
    }
    return '$count photos could not be uploaded.';
  }

  static String? _fromCode(String code) {
    if (code.isEmpty) return null;

    // Client-synthesized codes like HTTP_502 / HTTP_413.
    if (code.startsWith('HTTP_')) {
      final status = int.tryParse(code.substring(5));
      if (status != null) return _fromStatus(status);
    }

    switch (code) {
      // ── Auth / OTP ──────────────────────────────────────────────
      case 'INVALID_PHONE':
        return 'Enter a valid phone number with country code.';
      case 'UNSUPPORTED_PHONE_COUNTRY':
        return 'Only Indian mobile numbers are supported right now.';
      case 'INVALID_OTP':
        return 'That code is incorrect or expired. Try again.';
      case 'OTP_RESEND_TOO_SOON':
        return 'Please wait before requesting another code.';
      case 'OTP_NOT_CONFIGURED':
      case 'OTP_DELIVERY_FAILED':
        return 'SMS verification is temporarily unavailable.';

      // ── Session / authz ─────────────────────────────────────────
      case 'AUTH_REQUIRED':
      case 'INVALID_ACCESS_TOKEN':
        return 'Please sign in again.';
      case 'SESSION_REVOKED':
      case 'INVALID_REFRESH_TOKEN':
        return 'Your session expired. Please sign in again.';
      case 'PROFILE_REQUIRED':
        return 'Please finish setting up your profile.';
      case 'OWNER_REQUIRED':
        return 'Only the store owner can do this.';
      case 'MEMBERSHIP_REQUIRED':
      case 'STORE_MEMBERSHIP_REQUIRED':
        return 'You need to be a store member to continue.';
      case 'COLLECTION_EDITOR_REQUIRED':
        return 'You do not have permission to edit this collection.';
      case 'UPLOAD_OWNER_REQUIRED':
        return 'You do not have permission for this upload.';
      case 'OWNER_CANNOT_LEAVE':
        return 'Store owners cannot leave their store.';
      case 'IMPORTED_COLLECTION_READ_ONLY':
        return 'Imported collections cannot be edited.';

      // ── Shared / validation ─────────────────────────────────────
      case 'VALIDATION_ERROR':
        return 'Please check your details and try again.';
      case 'INVALID_ID':
        return 'This item is invalid or no longer available.';
      case 'INVALID_CURSOR':
        return 'List is out of date. Pull to refresh.';
      case 'INVALID_PAGE_LIMIT':
        return 'Please refresh and try again.';
      case 'INVALID_SLUG':
        return 'Store link must be 3–50 letters, numbers, or hyphens.';
      case 'RATE_LIMITED':
        return 'Too many attempts. Please wait a minute and try again.';
      case 'CONFLICT':
        return 'Something changed. Refresh and try again.';
      case 'NOT_FOUND':
        return 'This item is no longer available.';
      case 'UNEXPECTED_RESPONSE':
        return 'We could not read the server response. Please try again.';

      // ── Infra / availability ────────────────────────────────────
      case 'CATALOG_UNAVAILABLE':
      case 'DATABASE_UNAVAILABLE':
        return 'Service is temporarily unavailable. Try again soon.';
      case 'REQUEST_TIMEOUT':
      case 'TIMEOUT':
        return 'Request timed out. Please try again.';
      case 'NETWORK_ERROR':
        return 'No internet connection. Check your network and try again.';
      case 'MEDIA_UNAVAILABLE':
        return 'Media is temporarily unavailable. Try again soon.';
      case 'STORAGE_NOT_CONFIGURED':
      case 'INVALID_STORAGE_KEY':
        return 'Media storage is temporarily unavailable.';
      case 'INTERNAL_ERROR':
        return 'Server error. Please try again later.';

      // ── Store ───────────────────────────────────────────────────
      case 'SLUG_TAKEN':
        return 'That store link is already taken. Try another.';
      case 'STORE_ALREADY_OWNED':
        return 'You already have a store.';
      case 'STORE_NOT_FOUND':
        return 'This store is no longer available.';
      case 'TOO_MANY_STORE_IMAGES':
        return 'A store can have at most 5 showcase images.';
      case 'AT_LEAST_ONE_IMAGE_REQUIRED':
        return 'Add at least one store image.';
      case 'STORE_IMAGE_NOT_FOUND':
        return 'That store image is no longer available.';

      // ── Collections / photos (multipart + legacy asset flows) ───
      case 'COLLECTION_NOT_FOUND':
        return 'This collection is no longer available.';
      case 'PHOTOS_REQUIRED':
        return 'Add at least one photo.';
      case 'AT_LEAST_ONE_PHOTO_REQUIRED':
        return 'Keep at least one photo on this product.';
      case 'PHOTO_NOT_FOUND':
        return 'One or more photos are no longer available.';
      case 'TOO_MANY_PHOTOS':
        return 'You can upload at most 50 photos.';
      case 'INVALID_MULTIPART':
        return 'Upload format is invalid. Try again with fewer or smaller photos.';
      case 'NO_VALID_PHOTOS':
        return 'None of the photos could be uploaded. Try different images.';
      case 'PHOTOS_NOT_READY':
        return 'Wait until all photos finish processing, then try again.';
      case 'DUPLICATE_PHOTO':
        return 'Remove duplicate photos and try again.';
      case 'COLLECTION_QUOTA_EXCEEDED':
        return 'This store has reached its collection limit.';
      case 'STORAGE_QUOTA_EXCEEDED':
        return 'This store is out of media storage space.';
      case 'REVISION_CONFLICT':
        return 'This was updated elsewhere. Refresh and try again.';
      case 'INCOMPLETE_SPECIFICATIONS':
        return 'Fill all product details: weight, deduction, purity, wastage, size, metal, and category.';
      case 'DEDUCTION_EXCEEDS_WEIGHT':
        return 'Stone or other deduction must be less than the gross weight.';
      case 'INVALID_PURITY':
        return 'Choose a valid purity (75, 82, 86, 92, 999) or Varied.';
      case 'INVALID_WASTAGE':
        return 'Wastage must be between 0 and 100 percent.';
      case 'CROSS_SELECTION_NOT_ALLOWED':
        return 'Selected photos must come from the same group. Try again.';
      case 'PHOTO_ALREADY_IN_SUBGROUP':
        return 'One or more photos are already in another group.';
      case 'SUBGROUP_NOT_FOUND':
        return 'This product group is no longer available.';
      case 'UPLOAD_BUSY':
        return 'Uploads are busy. Please try again in a moment.';
      case 'PAYLOAD_TOO_LARGE':
      case 'REQUEST_ENTITY_TOO_LARGE':
        return 'These photos are too large to upload. Try smaller images or fewer photos.';

      // ── Image / processing (top-level or failedPhotos[].code) ───
      case 'HEIC_NOT_SUPPORTED':
        return 'HEIC photos are not supported. Use JPEG, PNG, or WebP.';
      case 'INVALID_IMAGE':
        return 'This file is not a valid image.';
      case 'UNSUPPORTED_IMAGE':
        return 'This image format is not supported.';
      case 'ANIMATED_IMAGE_NOT_ALLOWED':
        return 'Animated images are not supported.';
      case 'IMAGE_TOO_LARGE':
        return 'Image is too large. Use a photo under 500 MB.';
      case 'IMAGE_RESOLUTION_TOO_LOW':
        return 'Image is too small. Use a clearer photo.';
      case 'PROCESSED_IMAGE_TOO_LARGE':
        return 'Processed photo is too large. Try another image.';
      case 'IMAGE_PROCESSING_FAILED':
      case 'PROCESSING_RETRYABLE_FAILURE':
      case 'WORKER_RETRIES_EXHAUSTED':
        return 'We could not process this photo. Try another.';
      case 'STORAGE_UPLOAD_FAILED':
      case 'S3_UPLOAD_FAILED':
        return 'Photo upload failed. Please try again.';
      case 'UPLOAD_SIGNING_FAILED':
        return 'Unable to prepare this photo. Please try again.';

      // ── Legacy upload-ticket codes (safe if server still returns) ─
      case 'UPLOAD_NOT_FOUND':
        return 'Upload not found. Please select the photo again.';
      case 'UPLOAD_EXPIRED':
      case 'UPLOAD_NOT_AVAILABLE':
        return 'Upload expired. Please select the photo again.';
      case 'UPLOAD_IN_PROGRESS':
        return 'Photo is still processing. Please wait.';
      case 'UPLOAD_CLAIM_LOST':
      case 'UPLOAD_RETRY_REQUIRED':
        return 'Photo processing was interrupted. Try again.';
      case 'UPLOAD_CHECKSUM_MISMATCH':
        return 'Photo upload failed. Please try again.';

      // ── Import ──────────────────────────────────────────────────
      case 'IMPORT_NOT_FOUND':
        return 'Import request not found.';
      case 'COLLECTION_ALREADY_ADDED':
        return 'This collection is already in your store.';
      case 'IMPORT_ALREADY_PENDING':
        return 'An import request is already pending.';
      case 'IMPORT_COOLDOWN':
        return 'Please wait 24 hours before requesting again.';
      case 'IMPORT_NOT_PENDING':
        return 'This request was already decided.';
      case 'DESTINATION_STORE_REQUIRED':
        return 'Choose which store to import into.';

      default:
        return null;
    }
  }

  static String? _fromStatus(int statusCode) {
    if (statusCode == 0) {
      return 'No internet connection. Check your network and try again.';
    }
    switch (statusCode) {
      case 400:
        return 'Please check your details and try again.';
      case 401:
        return 'Please sign in again.';
      case 403:
        return 'You do not have permission for this action.';
      case 404:
        return 'This item is no longer available.';
      case 408:
        return 'Request timed out. Please try again.';
      case 409:
        return 'Something changed. Refresh and try again.';
      case 413:
        return 'These photos are too large to upload. Try smaller images or fewer photos.';
      case 415:
        return 'This file type is not supported.';
      case 422:
        return 'Please check your details and try again.';
      case 429:
        return 'Too many attempts. Please wait a minute and try again.';
      case 502:
      case 503:
      case 504:
        return 'Service is temporarily unavailable. Try again soon.';
    }
    if (statusCode >= 500) {
      return 'Server error. Please try again later.';
    }
    if (statusCode >= 400) {
      return 'Unable to complete this request. Please try again.';
    }
    return null;
  }
}
