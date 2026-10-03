import 'package:equatable/equatable.dart';

class StoreProduct extends Equatable {
  StoreProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.tags,
    required this.imagePaths,
    this.photoAssetIds = const [],
    this.imageThumbhashes = const [],
    this.canEdit = false,
    this.canDelete = false,
    this.toneIndex = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  final String description;
  final List<String> tags;
  final List<String> imagePaths;

  /// Parallel to [imagePaths] when the API returns member photo ids.
  final List<String> photoAssetIds;

  /// Parallel to [imagePaths] — base64 ThumbHash placeholders when present.
  final List<String> imageThumbhashes;
  final bool canEdit;
  final bool canDelete;
  final int toneIndex;
  final DateTime createdAt;

  String get meta {
    if (tags.isEmpty) return 'product';
    return tags.take(2).join(' · ');
  }

  bool get hasLocalImage => imagePaths.isNotEmpty;

  String? get primaryImagePath => imagePaths.isEmpty ? null : imagePaths.first;

  String? thumbhashAt(int index) {
    if (index < 0 || index >= imageThumbhashes.length) return null;
    final value = imageThumbhashes[index].trim();
    return value.isEmpty ? null : value;
  }

  DateTime get addedDate =>
      DateTime(createdAt.year, createdAt.month, createdAt.day);

  StoreProduct copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? tags,
    List<String>? imagePaths,
    List<String>? photoAssetIds,
    List<String>? imageThumbhashes,
    bool? canEdit,
    bool? canDelete,
    int? toneIndex,
    DateTime? createdAt,
  }) {
    return StoreProduct(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      imagePaths: imagePaths ?? this.imagePaths,
      photoAssetIds: photoAssetIds ?? this.photoAssetIds,
      imageThumbhashes: imageThumbhashes ?? this.imageThumbhashes,
      canEdit: canEdit ?? this.canEdit,
      canDelete: canDelete ?? this.canDelete,
      toneIndex: toneIndex ?? this.toneIndex,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'tags': tags,
      'imagePaths': imagePaths,
      'photoAssetIds': photoAssetIds,
      'imageThumbhashes': imageThumbhashes,
      'canEdit': canEdit,
      'canDelete': canDelete,
      'toneIndex': toneIndex,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory StoreProduct.fromMap(Map<String, Object?> map) {
    final rawTags = map['tags'];
    final rawPaths = map['imagePaths'];
    final rawAssetIds = map['photoAssetIds'];
    final rawThumbhashes = map['imageThumbhashes'];
    final rawCreatedAt = map['createdAt'];
    return StoreProduct(
      id:
          (map['id'] as String?) ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      tags:
          rawTags is List
              ? rawTags.map((e) => e.toString()).toList()
              : const [],
      imagePaths:
          rawPaths is List
              ? rawPaths.map((e) => e.toString()).toList()
              : const [],
      photoAssetIds:
          rawAssetIds is List
              ? rawAssetIds.map((e) => e.toString().trim()).toList()
              : const [],
      imageThumbhashes:
          rawThumbhashes is List
              ? rawThumbhashes.map((e) => e.toString()).toList()
              : const [],
      canEdit: map['canEdit'] == true,
      canDelete: map['canDelete'] == true,
      toneIndex: (map['toneIndex'] as int?) ?? 0,
      createdAt:
          rawCreatedAt is int
              ? DateTime.fromMillisecondsSinceEpoch(rawCreatedAt)
              : DateTime.now(),
    );
  }

  static List<StoreProduct> demoCatalog() {
    final now = DateTime.now();
    return [
      StoreProduct(
        id: 'demo_1',
        title: 'Solitaire ring',
        description:
            '18k white gold band with a brilliant-cut centre stone. Certified conflict-free.',
        tags: ['ring', 'diamond'],
        imagePaths: [],
        toneIndex: 0,
        createdAt: now,
      ),
      StoreProduct(
        id: 'demo_2',
        title: 'Rose gold bangle',
        description:
            'Hand-finished rose gold bangle with a soft brushed finish.',
        tags: ['bangle', 'rose gold'],
        imagePaths: [],
        toneIndex: 1,
        createdAt: now,
      ),
      StoreProduct(
        id: 'demo_3',
        title: 'Pearl drop earrings',
        description: 'Freshwater pearl drops set on a slim gold hook.',
        tags: ['earrings', 'pearl'],
        imagePaths: [],
        toneIndex: 2,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      StoreProduct(
        id: 'demo_4',
        title: 'Emerald pendant',
        description: 'Deep emerald pendant on a fine gold chain.',
        tags: ['pendant', 'emerald'],
        imagePaths: [],
        toneIndex: 3,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ];
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    tags,
    imagePaths,
    photoAssetIds,
    imageThumbhashes,
    canEdit,
    canDelete,
    toneIndex,
    createdAt,
  ];
}
