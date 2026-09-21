import 'package:equatable/equatable.dart';
import 'package:project_c/models/catalog/collection_models.dart';

/// Physical / metallurgy specs (CATALOG_IMAGES.md §2). All-or-nothing on the API.
class CollectionSpecifications extends Equatable {
  const CollectionSpecifications({
    required this.weight,
    required this.otherDeduction,
    required this.purity,
    required this.wastage,
    required this.size,
    required this.metalType,
    required this.category,
  });

  final Map<String, dynamic> weight;
  final Map<String, dynamic> otherDeduction;
  final Map<String, dynamic> purity;
  final double wastage;
  final Map<String, dynamic> size;
  final List<String> metalType;
  final String category;

  Map<String, dynamic> toJson() => {
    'weight': weight,
    'otherDeduction': otherDeduction,
    'purity': purity,
    'wastage': wastage,
    'size': size,
    'metalType': metalType,
    'category': category,
  };

  factory CollectionSpecifications.fromJson(Map<String, dynamic> json) {
    return CollectionSpecifications(
      weight: Map<String, dynamic>.from(
        json['weight'] as Map? ?? const <String, dynamic>{},
      ),
      otherDeduction: Map<String, dynamic>.from(
        json['otherDeduction'] as Map? ?? const <String, dynamic>{},
      ),
      purity: Map<String, dynamic>.from(
        json['purity'] as Map? ?? const <String, dynamic>{},
      ),
      wastage: (json['wastage'] as num?)?.toDouble() ?? 0,
      size: Map<String, dynamic>.from(
        json['size'] as Map? ?? const <String, dynamic>{},
      ),
      metalType:
          (json['metalType'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          const [],
      category: json['category'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [
    weight,
    otherDeduction,
    purity,
    wastage,
    size,
    metalType,
    category,
  ];
}

class CollectionSubGroup extends Equatable {
  const CollectionSubGroup({
    required this.id,
    required this.name,
    required this.photoCount,
    this.tag = '',
    this.description = '',
    this.specifications,
    this.usePrecisionTag = false,
    this.precisionTag = '',
    this.photos = const [],
  });

  final String id;
  final String name;
  final String tag;
  final String description;
  final int photoCount;
  final CollectionSpecifications? specifications;
  final bool usePrecisionTag;
  final String precisionTag;
  final List<CatalogPhoto> photos;

  factory CollectionSubGroup.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photos'];
    final rawSpecs = json['specifications'];
    return CollectionSubGroup(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
      description: json['description'] as String? ?? '',
      photoCount: (json['photoCount'] as num?)?.toInt() ?? 0,
      specifications:
          rawSpecs is Map<String, dynamic>
              ? CollectionSpecifications.fromJson(rawSpecs)
              : null,
      usePrecisionTag: json['usePrecisionTag'] == true,
      precisionTag: json['precisionTag'] as String? ?? '',
      photos:
          rawPhotos is List
              ? rawPhotos
                  .whereType<Map<String, dynamic>>()
                  .map(CatalogPhoto.fromJson)
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
    photoCount,
    specifications,
    usePrecisionTag,
    precisionTag,
    photos,
  ];
}
