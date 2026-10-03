import 'dart:convert';
import 'dart:io';

import 'package:project_c/models/catalog/catalog_page.dart';
import 'package:project_c/models/catalog/catalog_upload_models.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/models/catalog/collection_specifications.dart';
import 'package:project_c/resources/endpoints.dart';
import 'package:project_c/webservice/catalog_api_client.dart';

class CollectionRequest {
  CollectionRequest({required CatalogApiClient apiClient}) : _api = apiClient;

  final CatalogApiClient _api;

  Future<CatalogPage<CollectionSummary>> listCollections({
    required String storeId,
    int limit = 20,
    String? cursor,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (cursor != null && cursor.isNotEmpty) query['cursor'] = cursor;
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.storeCollections(storeId),
      query: query,
      requiresAuth: false,
      allowAnonymousBearer: true,
    );
    final items =
        (json?['items'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(CollectionSummary.fromJson)
            .toList();
    return CatalogPage(
      items: items,
      nextCursor: json?['nextCursor'] as String?,
    );
  }

  Future<CollectionDetail> fetchCollection({
    required String storeId,
    required String listingId,
  }) async {
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.storeCollection(storeId, listingId),
      requiresAuth: false,
      allowAnonymousBearer: true,
    );
    return CollectionDetail.fromJson(json ?? const {});
  }

  /// Phase 1: pre-signed S3 PUT URLs for direct binary upload.
  Future<CatalogPresignResult> presignUploads({
    required String storeId,
    required List<CatalogPresignFile> files,
  }) async {
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.storeUploadsPresign(storeId),
      body: {
        'files': [for (final f in files) f.toJson()],
      },
      requiresAuth: true,
    );
    return CatalogPresignResult.fromJson(json ?? const {});
  }

  /// Phase 2 JSON commit after direct S3 uploads (no multipart file parts).
  Future<CollectionCreateResult> createCollectionFromUploads({
    required String storeId,
    required String name,
    required List<CatalogUploadedPhoto> photos,
    String tag = '',
    String description = '',
    Map<String, dynamic>? specifications,
    bool usePrecisionTag = false,
    String? clientRequestId,
  }) async {
    final requestId =
        (clientRequestId != null && clientRequestId.trim().isNotEmpty)
            ? clientRequestId.trim()
            : 'req-${DateTime.now().microsecondsSinceEpoch}-${photos.length}';
    final body = <String, dynamic>{
      // Backend JSON commit docs use `title`; multipart / responses use `name`.
      'title': name,
      'name': name,
      'tag': tag,
      'description': description,
      'usePrecisionTag': usePrecisionTag,
      'clientRequestId': requestId,
      'photos': [for (final photo in photos) photo.toJson()],
    };
    if (specifications != null) {
      body['specifications'] = specifications;
    }
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.storeCollections(storeId),
      body: body,
      extraHeaders: {'Idempotency-Key': requestId},
      requiresAuth: true,
      timeout: const Duration(minutes: 2),
    );
    return CollectionCreateResult.fromJson(json ?? const {});
  }

  /// Append pre-signed uploaded photos to an existing collection.
  Future<CollectionCreateResult> appendUploadedPhotos({
    required String storeId,
    required String listingId,
    required List<CatalogUploadedPhoto> photos,
    int? revision,
  }) async {
    final body = <String, dynamic>{
      'photos': [for (final photo in photos) photo.toJson()],
    };
    if (revision != null) body['revision'] = revision;
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.storeCollectionPhotos(storeId, listingId),
      body: body,
      requiresAuth: true,
      timeout: const Duration(minutes: 2),
    );
    return CollectionCreateResult.fromJson(json ?? const {});
  }

  /// Legacy multipart create (kept for fallback / older server paths).
  Future<CollectionCreateResult> createCollection({
    required String storeId,
    required String name,
    required List<File> photoFiles,
    String tag = '',
    String description = '',
    Map<String, dynamic>? specifications,
    bool usePrecisionTag = false,
  }) async {
    final fields = <String, String>{
      'name': name,
      'tag': tag,
      'description': description,
    };
    if (specifications != null) {
      fields['specifications'] = jsonEncode(specifications);
      fields['usePrecisionTag'] = usePrecisionTag ? 'true' : 'false';
    }
    final json = await _api.sendMultipart(
      method: HttpMethod.post,
      path: Endpoints.storeCollections(storeId),
      fields: fields,
      files: _photoParts(photoFiles),
      requiresAuth: true,
      timeout: const Duration(minutes: 5),
    );
    return CollectionCreateResult.fromJson(json ?? const {});
  }

  /// JSON metadata-only update (no new photo files).
  Future<CollectionMutation> updateCollection({
    required String storeId,
    required String listingId,
    required int revision,
    String? name,
    String? tag,
    String? description,
    Map<String, dynamic>? specifications,
    bool? usePrecisionTag,
  }) async {
    final body = <String, dynamic>{'revision': revision};
    if (name != null) body['name'] = name;
    if (tag != null) body['tag'] = tag;
    if (description != null) body['description'] = description;
    if (specifications != null) body['specifications'] = specifications;
    if (usePrecisionTag != null) body['usePrecisionTag'] = usePrecisionTag;
    final json = await _api.sendJson(
      method: HttpMethod.patch,
      path: Endpoints.storeCollection(storeId, listingId),
      body: body,
      requiresAuth: true,
    );
    return CollectionMutation.fromJson(json ?? const {});
  }

  /// Multipart PATCH: append photos and/or update details (CATALOG_IMAGES.md).
  Future<CollectionCreateResult> updateCollectionWithPhotos({
    required String storeId,
    required String listingId,
    required int revision,
    required List<File> photoFiles,
    String? name,
    String? tag,
    String? description,
    Map<String, dynamic>? specifications,
    bool? usePrecisionTag,
  }) async {
    final fields = <String, String>{'revision': '$revision'};
    if (name != null) fields['name'] = name;
    if (tag != null) fields['tag'] = tag;
    if (description != null) fields['description'] = description;
    if (specifications != null) {
      fields['specifications'] = jsonEncode(specifications);
    }
    if (usePrecisionTag != null) {
      fields['usePrecisionTag'] = usePrecisionTag ? 'true' : 'false';
    }

    final json = await _api.sendMultipart(
      method: HttpMethod.patch,
      path: Endpoints.storeCollection(storeId, listingId),
      fields: fields,
      files: _photoParts(photoFiles),
      requiresAuth: true,
      timeout: const Duration(minutes: 5),
    );
    return CollectionCreateResult.fromJson(json ?? const {});
  }

  /// Mobile-friendly photo delete (POST body). Keeps ≥1 photo on the collection.
  Future<CollectionCreateResult> deletePhotos({
    required String storeId,
    required String listingId,
    required List<String> photoIds,
    int? revision,
  }) async {
    final body = <String, dynamic>{'photoIds': photoIds};
    if (revision != null) body['revision'] = revision;
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.storeCollectionPhotosDelete(storeId, listingId),
      body: body,
      requiresAuth: true,
    );
    return CollectionCreateResult.fromJson(json ?? const {});
  }

  Future<CollectionSubGroup> createSubGroup({
    required String storeId,
    required String listingId,
    required String name,
    required List<String> photoIds,
    required int revision,
    String tag = '',
    String description = '',
    Map<String, dynamic>? specifications,
    bool usePrecisionTag = false,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'tag': tag,
      'description': description,
      'photoIds': photoIds,
      'revision': revision,
      'usePrecisionTag': usePrecisionTag,
    };
    if (specifications != null) body['specifications'] = specifications;
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.storeCollectionSubGroups(storeId, listingId),
      body: body,
      requiresAuth: true,
    );
    return CollectionSubGroup.fromJson(json ?? const {});
  }

  /// PATCH sub-group metadata / specs (CATALOG_IMAGES §4.5). No photoIds —
  /// membership changes use [movePhotos]. Caller should re-fetch the collection
  /// for the latest [revision].
  Future<void> updateSubGroup({
    required String storeId,
    required String listingId,
    required String subGroupId,
    required int revision,
    String? name,
    String? tag,
    String? description,
    Map<String, dynamic>? specifications,
    bool? usePrecisionTag,
  }) async {
    final body = <String, dynamic>{'revision': revision};
    if (name != null) body['name'] = name;
    if (tag != null) body['tag'] = tag;
    if (description != null) body['description'] = description;
    if (specifications != null) body['specifications'] = specifications;
    if (usePrecisionTag != null) body['usePrecisionTag'] = usePrecisionTag;
    await _api.sendJson(
      method: HttpMethod.patch,
      path: Endpoints.storeCollectionSubGroup(storeId, listingId, subGroupId),
      body: body,
      requiresAuth: true,
    );
  }

  Future<CollectionCreateResult> movePhotos({
    required String storeId,
    required String listingId,
    required Map<String, dynamic> source,
    required Map<String, dynamic> destination,
    required List<String> photoIds,
    int? revision,
  }) async {
    final body = <String, dynamic>{
      'source': source,
      'destination': destination,
      'photoIds': photoIds,
    };
    if (revision != null) body['revision'] = revision;
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.storeCollectionPhotosMove(storeId, listingId),
      body: body,
      requiresAuth: true,
    );
    return CollectionCreateResult.fromJson(json ?? const {});
  }

  Future<void> deleteCollection({
    required String storeId,
    required String listingId,
  }) async {
    await _api.sendJson(
      method: HttpMethod.delete,
      path: Endpoints.storeCollection(storeId, listingId),
      requiresAuth: true,
    );
  }

  List<CatalogMultipartFile> _photoParts(List<File> photoFiles) {
    final parts = <CatalogMultipartFile>[];
    for (var i = 0; i < photoFiles.length; i++) {
      final file = photoFiles[i];
      final original =
          file.uri.pathSegments.isNotEmpty
              ? file.uri.pathSegments.last
              : 'photo.jpg';
      final ext =
          original.contains('.')
              ? original.substring(original.lastIndexOf('.'))
              : '.jpg';
      parts.add(
        CatalogMultipartFile(
          field: 'photos',
          file: file,
          filename: 'photo_${i + 1}$ext',
        ),
      );
    }
    return parts;
  }
}
