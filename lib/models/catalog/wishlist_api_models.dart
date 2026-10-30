import 'package:equatable/equatable.dart';
import 'package:project_c/models/store_privacy_mode.dart';

/// Result of PUT/DELETE `/products/:productId/like` (public appreciation).
class ProductLikeResult extends Equatable {
  const ProductLikeResult({
    required this.liked,
    this.productId = '',
    this.likeCount,
    this.likeId,
    this.alreadyLiked = false,
  });

  final bool liked;
  final String productId;
  final int? likeCount;
  final String? likeId;
  final bool alreadyLiked;

  factory ProductLikeResult.fromJson(Map<String, dynamic> json) {
    return ProductLikeResult(
      liked: json['liked'] as bool? ?? false,
      productId:
          (json['productId'] as String?)?.trim() ??
          (json['_id'] as String?)?.trim() ??
          '',
      likeCount: (json['likeCount'] as num?)?.toInt(),
      likeId: (json['likeId'] as String?)?.trim(),
      alreadyLiked: json['alreadyLiked'] == true,
    );
  }

  @override
  List<Object?> get props => [
    liked,
    productId,
    likeCount,
    likeId,
    alreadyLiked,
  ];
}

/// Result of POST/DELETE wishlist product/collection (private bookmark).
class WishlistToggleResult extends Equatable {
  const WishlistToggleResult({
    required this.wishlisted,
    this.productId = '',
    this.collectionId = '',
    this.wishlistId,
    this.alreadyWishlisted = false,
  });

  final bool wishlisted;
  final String productId;
  final String collectionId;
  final String? wishlistId;
  final bool alreadyWishlisted;

  factory WishlistToggleResult.fromJson(Map<String, dynamic> json) {
    return WishlistToggleResult(
      wishlisted:
          json['wishlisted'] as bool? ?? json['liked'] as bool? ?? false,
      productId: (json['productId'] as String?)?.trim() ?? '',
      collectionId: (json['collectionId'] as String?)?.trim() ?? '',
      wishlistId: (json['wishlistId'] as String?)?.trim(),
      alreadyWishlisted: json['alreadyWishlisted'] == true,
    );
  }

  @override
  List<Object?> get props => [
    wishlisted,
    productId,
    collectionId,
    wishlistId,
    alreadyWishlisted,
  ];
}

/// One row from `POST /wishlist/batch` `items[]`.
class WishlistBatchItemResult extends Equatable {
  const WishlistBatchItemResult({
    required this.productId,
    required this.wishlisted,
    this.alreadyWishlisted = false,
    this.wishlistId,
  });

  final String productId;
  final bool wishlisted;
  final bool alreadyWishlisted;
  final String? wishlistId;

  factory WishlistBatchItemResult.fromJson(Map<String, dynamic> json) {
    return WishlistBatchItemResult(
      productId: (json['productId'] as String?)?.trim() ?? '',
      wishlisted:
          json['wishlisted'] as bool? ?? json['liked'] as bool? ?? false,
      alreadyWishlisted: json['alreadyWishlisted'] == true,
      wishlistId: (json['wishlistId'] as String?)?.trim(),
    );
  }

  @override
  List<Object?> get props => [
    productId,
    wishlisted,
    alreadyWishlisted,
    wishlistId,
  ];
}

/// Result of `POST /wishlist/batch` (multi-select add).
class WishlistBatchAddResult extends Equatable {
  const WishlistBatchAddResult({
    this.success = true,
    this.totalRequested = 0,
    this.addedCount = 0,
    this.alreadyWishlistedCount = 0,
    this.failedCount = 0,
    this.items = const [],
  });

  final bool success;
  final int totalRequested;
  final int addedCount;
  final int alreadyWishlistedCount;
  final int failedCount;
  final List<WishlistBatchItemResult> items;

  /// Product ids that are wishlisted after the call (added or already).
  Set<String> get okProductIds => {
    for (final i in items)
      if (i.wishlisted && i.productId.isNotEmpty) i.productId,
  };

  factory WishlistBatchAddResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return WishlistBatchAddResult(
      success: json['success'] as bool? ?? true,
      totalRequested: (json['totalRequested'] as num?)?.toInt() ?? 0,
      addedCount: (json['addedCount'] as num?)?.toInt() ?? 0,
      alreadyWishlistedCount:
          (json['alreadyWishlistedCount'] as num?)?.toInt() ?? 0,
      failedCount: (json['failedCount'] as num?)?.toInt() ?? 0,
      items:
          rawItems is List
              ? [
                for (final e in rawItems)
                  if (e is Map)
                    WishlistBatchItemResult.fromJson(
                      Map<String, dynamic>.from(e),
                    ),
              ]
              : const [],
    );
  }

  @override
  List<Object?> get props => [
    success,
    totalRequested,
    addedCount,
    alreadyWishlistedCount,
    failedCount,
    items,
  ];
}

/// Result of `DELETE /wishlist/batch` (multi-select remove).
class WishlistBatchRemoveResult extends Equatable {
  const WishlistBatchRemoveResult({
    this.success = true,
    this.removedCount = 0,
    this.productIds = const [],
  });

  final bool success;
  final int removedCount;
  final List<String> productIds;

  factory WishlistBatchRemoveResult.fromJson(Map<String, dynamic> json) {
    final raw = json['productIds'];
    return WishlistBatchRemoveResult(
      success: json['success'] as bool? ?? true,
      removedCount: (json['removedCount'] as num?)?.toInt() ?? 0,
      productIds:
          raw is List
              ? [
                for (final e in raw)
                  if ('$e'.trim().isNotEmpty) '$e'.trim(),
              ]
              : const [],
    );
  }

  @override
  List<Object?> get props => [success, removedCount, productIds];
}

/// Result of PUT/DELETE legacy `.../photos/:photoId/like`.
class PhotoLikeResult extends Equatable {
  const PhotoLikeResult({
    required this.liked,
    this.assetId = '',
    this.listingId = '',
    this.wishlistId,
  });

  final bool liked;
  final String assetId;
  final String listingId;
  final String? wishlistId;

  factory PhotoLikeResult.fromJson(Map<String, dynamic> json) {
    return PhotoLikeResult(
      liked: json['liked'] as bool? ?? false,
      assetId: (json['assetId'] as String?)?.trim() ?? '',
      listingId: (json['listingId'] as String?)?.trim() ?? '',
      wishlistId: (json['wishlistId'] as String?)?.trim(),
    );
  }

  @override
  List<Object?> get props => [liked, assetId, listingId, wishlistId];
}

/// Result of PUT/DELETE `/collections/:collectionId/like`.
class CollectionLikeResult extends Equatable {
  const CollectionLikeResult({
    required this.liked,
    this.listingId = '',
    this.subGroupId,
    this.totalPhotos = 0,
    this.likedCount = 0,
    this.alreadyLikedCount = 0,
    this.unlikedCount = 0,
    this.likeCount,
    this.likeId,
    this.alreadyLiked = false,
  });

  final bool liked;
  final String listingId;
  final String? subGroupId;
  final int totalPhotos;
  final int likedCount;
  final int alreadyLikedCount;
  final int unlikedCount;
  final int? likeCount;
  final String? likeId;
  final bool alreadyLiked;

  factory CollectionLikeResult.fromJson(Map<String, dynamic> json) {
    final rawSub = json['subGroupId'];
    final collectionId =
        (json['collectionId'] as String?)?.trim() ??
        (json['listingId'] as String?)?.trim() ??
        '';
    final publicCount = (json['likeCount'] as num?)?.toInt();
    return CollectionLikeResult(
      liked: json['liked'] as bool? ?? false,
      listingId: collectionId,
      subGroupId:
          rawSub == null ? null : rawSub.toString().trim().isEmpty
              ? null
              : rawSub.toString().trim(),
      totalPhotos: (json['totalPhotos'] as num?)?.toInt() ?? 0,
      likedCount: (json['likedCount'] as num?)?.toInt() ?? publicCount ?? 0,
      alreadyLikedCount: (json['alreadyLikedCount'] as num?)?.toInt() ?? 0,
      unlikedCount: (json['unlikedCount'] as num?)?.toInt() ?? 0,
      likeCount: publicCount,
      likeId: (json['likeId'] as String?)?.trim(),
      alreadyLiked: json['alreadyLiked'] == true,
    );
  }

  @override
  List<Object?> get props => [
    liked,
    listingId,
    subGroupId,
    totalPhotos,
    likedCount,
    alreadyLikedCount,
    unlikedCount,
    likeCount,
    likeId,
    alreadyLiked,
  ];
}

enum WishlistItemStatus { active, locked }

WishlistItemStatus wishlistItemStatusFromString(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'locked':
      return WishlistItemStatus.locked;
    case 'active':
    default:
      return WishlistItemStatus.active;
  }
}

class WishlistPhoto extends Equatable {
  const WishlistPhoto({
    this.url = '',
    this.thumbnailUrl = '',
    this.detailUrl = '',
    this.thumbhash,
    this.width = 0,
    this.height = 0,
  });

  final String url;
  final String thumbnailUrl;
  final String detailUrl;
  final String? thumbhash;
  final int width;
  final int height;

  factory WishlistPhoto.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WishlistPhoto();
    return WishlistPhoto(
      url: json['url'] as String? ?? '',
      thumbnailUrl: (json['thumbnailUrl'] as String?)?.trim() ?? '',
      detailUrl: (json['detailUrl'] as String?)?.trim() ?? '',
      thumbhash: json['thumbhash'] as String? ?? json['thumbHash'] as String?,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props =>
      [url, thumbnailUrl, detailUrl, thumbhash, width, height];
}

class WishlistStore extends Equatable {
  const WishlistStore({
    required this.id,
    this.name = '',
    this.slug = '',
    this.city = '',
    this.privacy,
    this.followStatus = StoreFollowStatus.none,
  });

  final String id;
  final String name;
  final String slug;
  final String city;
  final StorePrivacyMode? privacy;
  final StoreFollowStatus followStatus;

  bool get isPrivate => privacy?.isPrivate == true;

  factory WishlistStore.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const WishlistStore(id: '');
    }
    final privacyRaw = json['privacy'];
    return WishlistStore(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      city: json['city'] as String? ?? '',
      privacy:
          privacyRaw is String && privacyRaw.trim().isNotEmpty
              ? StorePrivacyModeX.fromApi(privacyRaw)
              : null,
      followStatus: storeFollowStatusFromString(
        (json['followStatus'] as String?) ?? (json['status'] as String?),
      ),
    );
  }

  WishlistStore copyWith({StoreFollowStatus? followStatus}) {
    return WishlistStore(
      id: id,
      name: name,
      slug: slug,
      city: city,
      privacy: privacy,
      followStatus: followStatus ?? this.followStatus,
    );
  }

  @override
  List<Object?> get props => [id, name, slug, city, privacy, followStatus];
}

enum WishlistItemType { product, collection }

WishlistItemType wishlistItemTypeFromString(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'collection':
      return WishlistItemType.collection;
    case 'product':
    default:
      return WishlistItemType.product;
  }
}

/// One row from `GET /wishlist` (active card or locked stub).
class WishlistItem extends Equatable {
  const WishlistItem({
    required this.id,
    required this.status,
    this.itemType = WishlistItemType.product,
    this.assetId = '',
    this.listingId = '',
    this.photo = const WishlistPhoto(),
    this.title = '',
    this.collectionName = '',
    this.tag = '',
    this.description = '',
    this.specifications = const {},
    this.store = const WishlistStore(id: ''),
    this.likedAt,
  });

  final String id;
  final WishlistItemStatus status;
  final WishlistItemType itemType;
  final String assetId;
  final String listingId;
  final WishlistPhoto photo;
  final String title;
  final String collectionName;
  final String tag;
  final String description;
  final Map<String, dynamic> specifications;
  final WishlistStore store;
  final DateTime? likedAt;

  bool get isLocked => status == WishlistItemStatus.locked;
  bool get isActive => status == WishlistItemStatus.active;
  bool get isProduct => itemType == WishlistItemType.product;
  bool get isCollection => itemType == WishlistItemType.collection;

  String get displayTitle {
    if (isLocked) return 'Private Store Item';
    final t = title.trim();
    if (t.isNotEmpty) return t;
    final c = collectionName.trim();
    return c.isNotEmpty ? c : 'Item';
  }

  String get weightLabel {
    final weight = specifications['weight'];
    if (weight is Map) {
      final v = weight['value'];
      if (v is num) {
        final n = v.toDouble();
        if (n == n.roundToDouble()) return '${n.toInt()} g';
        return '${n.toStringAsFixed(1)} g';
      }
    }
    return '';
  }

  String get purityLabel {
    final purity = specifications['purity'];
    if (purity is Map) {
      final v = purity['value'];
      if (v != null) {
        final s = v.toString().trim();
        if (s.isEmpty) return '';
        return s.endsWith('%') ? s : '$s%';
      }
    }
    if (purity != null) {
      final s = purity.toString().trim();
      if (s.isEmpty) return '';
      return s.endsWith('%') ? s : '$s%';
    }
    return '';
  }

  /// Raw purity key from specs (e.g. `92`) for filter matching.
  String get purityFilterValue {
    final purity = specifications['purity'];
    if (purity is Map) {
      return (purity['value']?.toString() ?? '').trim();
    }
    return (purity?.toString() ?? '').trim();
  }

  /// Lowercased metal keys from `specifications.metalType`.
  List<String> get metalFilterValues {
    final raw = specifications['metalType'];
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e.toString().trim().isNotEmpty) e.toString().trim().toLowerCase(),
    ];
  }

  double? get weightSortValue {
    final weight = specifications['weight'];
    if (weight is! Map) return null;
    final v = weight['value'];
    if (v is num) return v.toDouble();
    final min = weight['min'];
    if (min is num) return min.toDouble();
    return null;
  }

  WishlistItem copyWith({
    WishlistItemStatus? status,
    WishlistStore? store,
  }) {
    return WishlistItem(
      id: id,
      status: status ?? this.status,
      itemType: itemType,
      assetId: assetId,
      listingId: listingId,
      photo: photo,
      title: title,
      collectionName: collectionName,
      tag: tag,
      description: description,
      specifications: specifications,
      store: store ?? this.store,
      likedAt: likedAt,
    );
  }

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    // Jewel shape: { type/itemType, product|collection, store, createdAt }
    final itemType = wishlistItemTypeFromString(
      (json['type'] as String?) ?? (json['itemType'] as String?),
    );
    final rawProduct = json['product'];
    final rawCollection = json['collection'];
    final productMap =
        rawProduct is Map
            ? Map<String, dynamic>.from(rawProduct)
            : const <String, dynamic>{};
    final collectionMap =
        rawCollection is Map
            ? Map<String, dynamic>.from(rawCollection)
            : const <String, dynamic>{};

    final cover = collectionMap['coverImage'];
    final coverMap =
        cover is Map ? Map<String, dynamic>.from(cover) : const <String, dynamic>{};
    final rawPhoto =
        json['photo'] ??
        productMap['primaryImage'] ??
        (coverMap.isNotEmpty ? coverMap : null);
    final rawStore = json['store'];
    final rawSpecs = json['specifications'] ?? productMap['specifications'];
    DateTime? likedAt;
    final likedRaw = json['likedAt'] ?? json['createdAt'];
    if (likedRaw is String && likedRaw.isNotEmpty) {
      likedAt = DateTime.tryParse(likedRaw);
    }

    final productId =
        (productMap['id'] as String?)?.trim() ??
        (productMap['_id'] as String?)?.trim() ??
        '';
    final collectionId =
        (collectionMap['id'] as String?)?.trim() ??
        (collectionMap['_id'] as String?)?.trim() ??
        (json['collectionId'] as String?)?.trim() ??
        (json['listingId'] as String?)?.trim() ??
        '';
    final resolvedId =
        itemType == WishlistItemType.collection
            ? (collectionId.isNotEmpty
                ? collectionId
                : (json['listingId'] as String? ?? ''))
            : (productId.isNotEmpty
                ? productId
                : (json['listingId'] as String? ?? ''));
    final title =
        (productMap['title'] as String?)?.trim() ??
        (collectionMap['name'] as String?)?.trim() ??
        (json['title'] as String?)?.trim() ??
        '';
    final precision =
        (productMap['precisionTag'] as String?)?.trim() ?? '';
    final collectionName =
        (collectionMap['name'] as String?)?.trim() ??
        (json['collectionName'] as String?)?.trim() ??
        '';

    return WishlistItem(
      id:
          (json['id'] as String?)?.trim() ??
          (json['_id'] as String?)?.trim() ??
          '',
      status: wishlistItemStatusFromString(json['status'] as String?),
      itemType: itemType,
      assetId:
          (json['assetId'] as String?)?.trim() ??
          (json['photoId'] as String?)?.trim() ??
          (productMap['primaryImageId'] as String?)?.trim() ??
          '',
      listingId: resolvedId,
      photo:
          rawPhoto is Map
              ? WishlistPhoto.fromJson(Map<String, dynamic>.from(rawPhoto))
              : const WishlistPhoto(),
      title: title,
      collectionName: collectionName,
      tag:
          (json['tag'] as String?)?.trim() ??
          (productMap['category'] as String?)?.trim() ??
          precision,
      description: json['description'] as String? ?? '',
      specifications:
          rawSpecs is Map
              ? Map<String, dynamic>.from(rawSpecs)
              : const <String, dynamic>{},
      store:
          rawStore is Map
              ? WishlistStore.fromJson(Map<String, dynamic>.from(rawStore))
              : const WishlistStore(id: ''),
      likedAt: likedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        status,
        itemType,
        assetId,
        listingId,
        photo,
        title,
        collectionName,
        tag,
        description,
        specifications,
        store,
        likedAt,
      ];
}

class WishlistPage extends Equatable {
  const WishlistPage({
    this.items = const [],
    this.nextCursor,
  });

  final List<WishlistItem> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  factory WishlistPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    return WishlistPage(
      items:
          raw is List
              ? raw
                  .whereType<Map>()
                  .map(
                    (e) => WishlistItem.fromJson(Map<String, dynamic>.from(e)),
                  )
                  .toList()
              : const [],
      nextCursor: json['nextCursor'] as String?,
    );
  }

  @override
  List<Object?> get props => [items, nextCursor];
}

/// Result of `DELETE /wishlist/:wishlistId`.
class WishlistRemoveResult extends Equatable {
  const WishlistRemoveResult({
    required this.success,
    this.id = '',
    this.assetId = '',
    this.listingId = '',
  });

  final bool success;
  final String id;
  final String assetId;
  final String listingId;

  factory WishlistRemoveResult.fromJson(Map<String, dynamic> json) {
    return WishlistRemoveResult(
      success: json['success'] as bool? ?? true,
      id: json['id'] as String? ?? '',
      assetId: json['assetId'] as String? ?? '',
      listingId: json['listingId'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [success, id, assetId, listingId];
}
