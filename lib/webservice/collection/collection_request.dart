import 'dart:io';

import 'package:project_c/models/catalog/catalog_page.dart';
import 'package:project_c/models/catalog/collection_models.dart';
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

  /// Multipart create: `name`, optional `tag`/`description`, repeated `photos`.
  Future<CollectionCreateResult> createCollection({
    required String storeId,
    required String name,
    required List<File> photoFiles,
    String tag = '',
    String description = '',
  }) async {
    final json = await _api.sendMultipart(
      method: HttpMethod.post,
      path: Endpoints.storeCollections(storeId),
      fields: {
        'name': name,
        'tag': tag,
        'description': description,
      },
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
  }) async {
    final body = <String, dynamic>{'revision': revision};
    if (name != null) body['name'] = name;
    if (tag != null) body['tag'] = tag;
    if (description != null) body['description'] = description;
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
  }) async {
    final fields = <String, String>{'revision': '$revision'};
    if (name != null) fields['name'] = name;
    if (tag != null) fields['tag'] = tag;
    if (description != null) fields['description'] = description;

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
