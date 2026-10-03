import 'package:equatable/equatable.dart';
import 'package:project_c/models/catalog/collection_specifications.dart';

class CatalogPhoto extends Equatable {
  const CatalogPhoto({
    required this.width,
    required this.height,
    required this.url,
    this.id,
    this.quality,
    this.thumbhash,
  });

  final String? id;
  final int width;
  final int height;
  final String url;
  final String? quality;
  final String? thumbhash;

  factory CatalogPhoto.fromJson(Map<String, dynamic> json) {
    return CatalogPhoto(
      id: json['id'] as String?,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      url: json['url'] as String? ?? '',
      quality: json['quality'] as String?,
      thumbhash: json['thumbhash'] as String? ?? json['thumbHash'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'width': width,
    'height': height,
    'url': url,
    'quality': quality,
    'thumbhash': thumbhash,
  };

  @override
  List<Object?> get props => [id, width, height, url, quality, thumbhash];
}

class CollectionPermissions extends Equatable {
  const CollectionPermissions({required this.edit, required this.delete});

  final bool edit;
  final bool delete;

  factory CollectionPermissions.fromJson(Map<String, dynamic> json) {
    return CollectionPermissions(
      edit: json['edit'] as bool? ?? false,
      delete: json['delete'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [edit, delete];
}

class FailedPhoto extends Equatable {
  const FailedPhoto({
    required this.fileName,
    required this.code,
    required this.message,
  });

  final String fileName;
  final String code;
  final String message;

  factory FailedPhoto.fromJson(Map<String, dynamic> json) {
    return FailedPhoto(
      fileName: json['fileName'] as String? ?? '',
      code: json['code'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [fileName, code, message];
}

class CollectionSummary extends Equatable {
  const CollectionSummary({
    required this.id,
    required this.name,
    required this.revision,
    required this.photoCount,
    required this.cover,
    this.tag = '',
    this.description = '',
    this.kind,
    this.permissions,
    this.mainGroupPhotoCount,
    this.subGroupCount,
    this.precisionTag = '',
    this.usePrecisionTag = false,
    this.specifications,
    this.mainGroupCover,
  });

  final String id;
  final String name;
  final String tag;
  final String description;
  final int revision;
  final int photoCount;
  final CatalogPhoto cover;
  final String? kind;
  final CollectionPermissions? permissions;
  final int? mainGroupPhotoCount;
  final int? subGroupCount;
  final String precisionTag;
  final bool usePrecisionTag;
  final CollectionSpecifications? specifications;
  final CatalogPhoto? mainGroupCover;

  factory CollectionSummary.fromJson(Map<String, dynamic> json) {
    final perms = json['permissions'];
    final rawSpecs = json['specifications'];
    final rawMainCover = json['mainGroupCover'];
    return CollectionSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
      description: json['description'] as String? ?? '',
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      photoCount: (json['photoCount'] as num?)?.toInt() ?? 0,
      cover: CatalogPhoto.fromJson(
        json['cover'] as Map<String, dynamic>? ?? const {},
      ),
      kind: json['kind'] as String?,
      permissions:
          perms is Map<String, dynamic>
              ? CollectionPermissions.fromJson(perms)
              : null,
      mainGroupPhotoCount: (json['mainGroupPhotoCount'] as num?)?.toInt(),
      subGroupCount: (json['subGroupCount'] as num?)?.toInt(),
      precisionTag: json['precisionTag'] as String? ?? '',
      usePrecisionTag: json['usePrecisionTag'] == true,
      specifications:
          rawSpecs is Map<String, dynamic>
              ? CollectionSpecifications.fromJson(rawSpecs)
              : null,
      mainGroupCover:
          rawMainCover is Map<String, dynamic>
              ? CatalogPhoto.fromJson(rawMainCover)
              : null,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    tag,
    description,
    revision,
    photoCount,
    cover,
    kind,
    permissions,
    mainGroupPhotoCount,
    subGroupCount,
    precisionTag,
    usePrecisionTag,
    specifications,
    mainGroupCover,
  ];
}

class CollectionDetail extends Equatable {
  const CollectionDetail({
    required this.id,
    required this.name,
    required this.revision,
    required this.photoCount,
    required this.photos,
    this.tag = '',
    this.description = '',
    this.kind,
    this.permissions,
    this.specifications,
    this.usePrecisionTag = false,
    this.precisionTag = '',
    this.mainGroupPhotoCount,
    this.subGroupCount,
    this.mainGroupPhotos = const [],
    this.subGroups = const [],
  });

  final String id;
  final String name;
  final String tag;
  final String description;
  final int revision;
  final int photoCount;
  final List<CatalogPhoto> photos;
  final String? kind;
  final CollectionPermissions? permissions;
  final CollectionSpecifications? specifications;
  final bool usePrecisionTag;
  final String precisionTag;
  final int? mainGroupPhotoCount;
  final int? subGroupCount;
  final List<CatalogPhoto> mainGroupPhotos;
  final List<CollectionSubGroup> subGroups;

  factory CollectionDetail.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photos'];
    final rawMainPhotos = json['mainGroupPhotos'];
    final rawSubGroups = json['subGroups'];
    final perms = json['permissions'];
    final rawSpecs = json['specifications'];
    return CollectionDetail(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
      description: json['description'] as String? ?? '',
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      photoCount: (json['photoCount'] as num?)?.toInt() ?? 0,
      photos:
          rawPhotos is List
              ? rawPhotos
                  .whereType<Map<String, dynamic>>()
                  .map(CatalogPhoto.fromJson)
                  .toList()
              : const [],
      kind: json['kind'] as String?,
      permissions:
          perms is Map<String, dynamic>
              ? CollectionPermissions.fromJson(perms)
              : null,
      specifications:
          rawSpecs is Map<String, dynamic>
              ? CollectionSpecifications.fromJson(rawSpecs)
              : null,
      usePrecisionTag: json['usePrecisionTag'] == true,
      precisionTag: json['precisionTag'] as String? ?? '',
      mainGroupPhotoCount: (json['mainGroupPhotoCount'] as num?)?.toInt(),
      subGroupCount: (json['subGroupCount'] as num?)?.toInt(),
      mainGroupPhotos:
          rawMainPhotos is List
              ? rawMainPhotos
                  .whereType<Map<String, dynamic>>()
                  .map(CatalogPhoto.fromJson)
                  .toList()
              : const [],
      subGroups:
          rawSubGroups is List
              ? rawSubGroups
                  .whereType<Map<String, dynamic>>()
                  .map(CollectionSubGroup.fromJson)
                  .toList()
              : const [],
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    tag,
    description,
    revision,
    photoCount,
    photos,
    kind,
    permissions,
    specifications,
    usePrecisionTag,
    precisionTag,
    mainGroupPhotoCount,
    subGroupCount,
    mainGroupPhotos,
    subGroups,
  ];
}

/// Create (201) response — may include partial [failedPhotos].
class CollectionCreateResult extends Equatable {
  const CollectionCreateResult({
    required this.id,
    required this.name,
    required this.tag,
    required this.description,
    required this.revision,
    required this.photoCount,
    this.failedPhotos = const [],
    this.photos = const [],
    this.newCollectionId,
  });

  final String id;
  final String name;
  final String tag;
  final String description;
  final int revision;
  final int photoCount;
  final List<FailedPhoto> failedPhotos;
  final List<CatalogPhoto> photos;
  final String? newCollectionId;

  bool get hasPartialFailures => failedPhotos.isNotEmpty;

  factory CollectionCreateResult.fromJson(Map<String, dynamic> json) {
    final rawFailed = json['failedPhotos'];
    final rawPhotos = json['photos'];
    return CollectionCreateResult(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
      description: json['description'] as String? ?? '',
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      photoCount: (json['photoCount'] as num?)?.toInt() ?? 0,
      failedPhotos:
          rawFailed is List
              ? rawFailed
                  .whereType<Map<String, dynamic>>()
                  .map(FailedPhoto.fromJson)
                  .toList()
              : const [],
      photos:
          rawPhotos is List
              ? rawPhotos
                  .whereType<Map<String, dynamic>>()
                  .map(CatalogPhoto.fromJson)
                  .toList()
              : const [],
      newCollectionId: json['newCollectionId'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    tag,
    description,
    revision,
    photoCount,
    failedPhotos,
    photos,
    newCollectionId,
  ];
}

/// PATCH metadata response (no photos / failedPhotos).
class CollectionMutation extends Equatable {
  const CollectionMutation({
    required this.id,
    required this.name,
    required this.tag,
    required this.description,
    required this.revision,
    this.precisionTag,
    this.usePrecisionTag,
    this.specifications,
  });

  final String id;
  final String name;
  final String tag;
  final String description;
  final int revision;
  final String? precisionTag;
  final bool? usePrecisionTag;
  final CollectionSpecifications? specifications;

  factory CollectionMutation.fromJson(Map<String, dynamic> json) {
    final rawSpecs = json['specifications'];
    return CollectionMutation(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
      description: json['description'] as String? ?? '',
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      precisionTag: json['precisionTag'] as String?,
      usePrecisionTag:
          json.containsKey('usePrecisionTag')
              ? json['usePrecisionTag'] == true
              : null,
      specifications:
          rawSpecs is Map<String, dynamic>
              ? CollectionSpecifications.fromJson(rawSpecs)
              : null,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    tag,
    description,
    revision,
    precisionTag,
    usePrecisionTag,
    specifications,
  ];
}
