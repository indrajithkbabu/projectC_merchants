import 'dart:io';

import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/catalog_page.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/models/catalog/collection_specifications.dart';
import 'package:project_c/webservice/collection/collection_request.dart';

abstract class CollectionRepository {
  Future<CatalogPage<CollectionSummary>> listCollections({
    required String storeId,
    int limit = 20,
    String? cursor,
  });

  Future<CollectionDetail> fetchCollection({
    required String storeId,
    required String listingId,
  });

  Future<CollectionCreateResult> createCollection({
    required String storeId,
    required String name,
    required List<File> photoFiles,
    String tag = '',
    String description = '',
    Map<String, dynamic>? specifications,
    bool usePrecisionTag = false,
  });

  Future<CollectionMutation> updateCollection({
    required String storeId,
    required String listingId,
    required int revision,
    String? name,
    String? tag,
    String? description,
    Map<String, dynamic>? specifications,
    bool? usePrecisionTag,
  });

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
  });

  Future<CollectionCreateResult> deletePhotos({
    required String storeId,
    required String listingId,
    required List<String> photoIds,
    int? revision,
  });

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
  });

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
  });

  Future<CollectionCreateResult> movePhotos({
    required String storeId,
    required String listingId,
    required Map<String, dynamic> source,
    required Map<String, dynamic> destination,
    required List<String> photoIds,
    int? revision,
  });

  Future<void> deleteCollection({
    required String storeId,
    required String listingId,
  });
}

class CollectionRepositoryImpl implements CollectionRepository {
  CollectionRepositoryImpl({required CollectionRequest request})
    : _request = request;

  static const _tag = 'CollectionRepository';

  final CollectionRequest _request;

  @override
  Future<CatalogPage<CollectionSummary>> listCollections({
    required String storeId,
    int limit = 20,
    String? cursor,
  }) {
    AppLog.d(_tag, 'listCollections store=$storeId');
    return _request.listCollections(
      storeId: storeId,
      limit: limit,
      cursor: cursor,
    );
  }

  @override
  Future<CollectionDetail> fetchCollection({
    required String storeId,
    required String listingId,
  }) {
    return _request.fetchCollection(storeId: storeId, listingId: listingId);
  }

  @override
  Future<CollectionCreateResult> createCollection({
    required String storeId,
    required String name,
    required List<File> photoFiles,
    String tag = '',
    String description = '',
    Map<String, dynamic>? specifications,
    bool usePrecisionTag = false,
  }) {
    AppLog.d(
      _tag,
      'createCollection photos=${photoFiles.length} '
      'specs=${specifications != null}',
    );
    return _request.createCollection(
      storeId: storeId,
      name: name,
      photoFiles: photoFiles,
      tag: tag,
      description: description,
      specifications: specifications,
      usePrecisionTag: usePrecisionTag,
    );
  }

  @override
  Future<CollectionMutation> updateCollection({
    required String storeId,
    required String listingId,
    required int revision,
    String? name,
    String? tag,
    String? description,
    Map<String, dynamic>? specifications,
    bool? usePrecisionTag,
  }) {
    return _request.updateCollection(
      storeId: storeId,
      listingId: listingId,
      revision: revision,
      name: name,
      tag: tag,
      description: description,
      specifications: specifications,
      usePrecisionTag: usePrecisionTag,
    );
  }

  @override
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
  }) {
    AppLog.d(
      _tag,
      'updateCollectionWithPhotos listing=$listingId photos=${photoFiles.length}',
    );
    return _request.updateCollectionWithPhotos(
      storeId: storeId,
      listingId: listingId,
      revision: revision,
      photoFiles: photoFiles,
      name: name,
      tag: tag,
      description: description,
      specifications: specifications,
      usePrecisionTag: usePrecisionTag,
    );
  }

  @override
  Future<CollectionCreateResult> deletePhotos({
    required String storeId,
    required String listingId,
    required List<String> photoIds,
    int? revision,
  }) {
    AppLog.d(
      _tag,
      'deletePhotos listing=$listingId count=${photoIds.length}',
    );
    return _request.deletePhotos(
      storeId: storeId,
      listingId: listingId,
      photoIds: photoIds,
      revision: revision,
    );
  }

  @override
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
  }) {
    AppLog.d(
      _tag,
      'createSubGroup listing=$listingId photos=${photoIds.length}',
    );
    return _request.createSubGroup(
      storeId: storeId,
      listingId: listingId,
      name: name,
      photoIds: photoIds,
      revision: revision,
      tag: tag,
      description: description,
      specifications: specifications,
      usePrecisionTag: usePrecisionTag,
    );
  }

  @override
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
  }) {
    AppLog.d(
      _tag,
      'updateSubGroup listing=$listingId sub=$subGroupId',
    );
    return _request.updateSubGroup(
      storeId: storeId,
      listingId: listingId,
      subGroupId: subGroupId,
      revision: revision,
      name: name,
      tag: tag,
      description: description,
      specifications: specifications,
      usePrecisionTag: usePrecisionTag,
    );
  }

  @override
  Future<CollectionCreateResult> movePhotos({
    required String storeId,
    required String listingId,
    required Map<String, dynamic> source,
    required Map<String, dynamic> destination,
    required List<String> photoIds,
    int? revision,
  }) {
    AppLog.d(
      _tag,
      'movePhotos listing=$listingId count=${photoIds.length}',
    );
    return _request.movePhotos(
      storeId: storeId,
      listingId: listingId,
      source: source,
      destination: destination,
      photoIds: photoIds,
      revision: revision,
    );
  }

  @override
  Future<void> deleteCollection({
    required String storeId,
    required String listingId,
  }) {
    return _request.deleteCollection(storeId: storeId, listingId: listingId);
  }
}
