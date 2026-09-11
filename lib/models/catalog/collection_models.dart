import 'package:equatable/equatable.dart';

class CatalogPhoto extends Equatable {
  const CatalogPhoto({
    required this.width,
    required this.height,
    required this.url,
    this.id,
    this.quality,
  });

  final String? id;
  final int width;
  final int height;
  final String url;
  final String? quality;

  factory CatalogPhoto.fromJson(Map<String, dynamic> json) {
    return CatalogPhoto(
      id: json['id'] as String?,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      url: json['url'] as String? ?? '',
      quality: json['quality'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, width, height, url, quality];
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

  factory CollectionSummary.fromJson(Map<String, dynamic> json) {
    final perms = json['permissions'];
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

  factory CollectionDetail.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photos'];
    final perms = json['permissions'];
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
  });

  final String id;
  final String name;
  final String tag;
  final String description;
  final int revision;
  final int photoCount;
  final List<FailedPhoto> failedPhotos;

  bool get hasPartialFailures => failedPhotos.isNotEmpty;

  factory CollectionCreateResult.fromJson(Map<String, dynamic> json) {
    final rawFailed = json['failedPhotos'];
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
  });

  final String id;
  final String name;
  final String tag;
  final String description;
  final int revision;

  factory CollectionMutation.fromJson(Map<String, dynamic> json) {
    return CollectionMutation(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
      description: json['description'] as String? ?? '',
      revision: (json['revision'] as num?)?.toInt() ?? 1,
    );
  }

  @override
  List<Object?> get props => [id, name, tag, description, revision];
}
