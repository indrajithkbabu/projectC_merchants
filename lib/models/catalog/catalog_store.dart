import 'package:equatable/equatable.dart';
import 'package:project_c/models/catalog/collection_models.dart';

enum StoreRelationship { owner, member, other }

StoreRelationship? storeRelationshipFromString(String? value) {
  switch (value) {
    case 'owner':
      return StoreRelationship.owner;
    case 'member':
      return StoreRelationship.member;
    case 'other':
      return StoreRelationship.other;
    default:
      return null;
  }
}

class CatalogStore extends Equatable {
  const CatalogStore({
    required this.id,
    required this.name,
    required this.slug,
    this.relationship,
    this.legalName,
    this.images = const [],
    this.imageUrls = const [],
    this.coverImage,
  });

  final String id;
  final String name;
  final String slug;
  final StoreRelationship? relationship;
  final String? legalName;
  final List<CatalogPhoto> images;
  final List<String> imageUrls;
  final CatalogPhoto? coverImage;

  bool get isOwn => relationship == StoreRelationship.owner;

  String get storeLink => '$slug.jewelflow.app';

  String get coverImageUrl {
    final cover = coverImage?.url.trim() ?? '';
    if (cover.isNotEmpty) return cover;
    if (imageUrls.isNotEmpty) {
      final first = imageUrls.first.trim();
      if (first.isNotEmpty) return first;
    }
    if (images.isNotEmpty) {
      final first = images.first.url.trim();
      if (first.isNotEmpty) return first;
    }
    return '';
  }

  factory CatalogStore.fromJson(Map<String, dynamic> json) {
    final root =
        json['store'] is Map<String, dynamic>
            ? json['store'] as Map<String, dynamic>
            : json;

    final relationship =
        storeRelationshipFromString(root['relationship'] as String?) ??
        storeRelationshipFromString(root['role'] as String?);

    final rawImages = root['images'];
    final images =
        rawImages is List
            ? rawImages
                .whereType<Map<String, dynamic>>()
                .map(CatalogPhoto.fromJson)
                .toList()
            : const <CatalogPhoto>[];

    final rawUrls = root['imageUrls'];
    final imageUrls =
        rawUrls is List
            ? rawUrls.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList()
            : images
                .map((e) => e.url.trim())
                .where((e) => e.isNotEmpty)
                .toList();

    final rawCover = root['coverImage'];
    CatalogPhoto? coverImage;
    if (rawCover is Map<String, dynamic>) {
      coverImage = CatalogPhoto.fromJson(rawCover);
    } else if (images.isNotEmpty) {
      coverImage = images.first;
    }

    return CatalogStore(
      id: root['id'] as String? ?? '',
      name: root['name'] as String? ?? '',
      slug: root['slug'] as String? ?? '',
      relationship: relationship,
      legalName: root['legalName'] as String?,
      images: images,
      imageUrls: imageUrls,
      coverImage: coverImage,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    if (relationship != null) 'relationship': relationship!.name,
    if (legalName != null) 'legalName': legalName,
    'images':
        images
            .map(
              (p) => {
                'id': p.id,
                'url': p.url,
                'width': p.width,
                'height': p.height,
              },
            )
            .toList(),
    'imageUrls': imageUrls,
    if (coverImage != null)
      'coverImage': {
        'id': coverImage!.id,
        'url': coverImage!.url,
        'width': coverImage!.width,
        'height': coverImage!.height,
      },
  };

  /// Apply images / cover fields from append, delete, or replace responses.
  CatalogStore applyingImagesFrom(Map<String, dynamic> json) {
    final root =
        json['store'] is Map<String, dynamic>
            ? json['store'] as Map<String, dynamic>
            : json;
    final merged = CatalogStore.fromJson({
      'id': id,
      'name': name,
      'slug': slug,
      if (relationship != null) 'relationship': relationship!.name,
      if (legalName != null) 'legalName': legalName,
      'images': root['images'],
      'imageUrls': root['imageUrls'],
      'coverImage': root['coverImage'],
    });
    return copyWith(
      images: merged.images,
      imageUrls: merged.imageUrls,
      coverImage: merged.coverImage,
      clearCoverImage: merged.coverImage == null && merged.images.isEmpty,
    );
  }

  CatalogStore copyWith({
    String? id,
    String? name,
    String? slug,
    StoreRelationship? relationship,
    String? legalName,
    List<CatalogPhoto>? images,
    List<String>? imageUrls,
    CatalogPhoto? coverImage,
    bool clearCoverImage = false,
  }) {
    return CatalogStore(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      relationship: relationship ?? this.relationship,
      legalName: legalName ?? this.legalName,
      images: images ?? this.images,
      imageUrls: imageUrls ?? this.imageUrls,
      coverImage: clearCoverImage ? null : (coverImage ?? this.coverImage),
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    slug,
    relationship,
    legalName,
    images,
    imageUrls,
    coverImage,
  ];
}
