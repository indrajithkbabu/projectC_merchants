import 'package:equatable/equatable.dart';

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
  });

  final String id;
  final String name;
  final String slug;
  final StoreRelationship? relationship;

  bool get isOwn => relationship == StoreRelationship.owner;

  String get storeLink => '$slug.jewelflow.app';

  factory CatalogStore.fromJson(Map<String, dynamic> json) {
    return CatalogStore(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      relationship: storeRelationshipFromString(
        json['relationship'] as String?,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    if (relationship != null) 'relationship': relationship!.name,
  };

  @override
  List<Object?> get props => [id, name, slug, relationship];
}
