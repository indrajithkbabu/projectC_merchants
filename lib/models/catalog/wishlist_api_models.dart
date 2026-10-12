import 'package:equatable/equatable.dart';
import 'package:project_c/models/store_privacy_mode.dart';

/// Result of PUT/DELETE `.../photos/:photoId/like`.
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
    this.thumbhash,
    this.width = 0,
    this.height = 0,
  });

  final String url;
  final String? thumbhash;
  final int width;
  final int height;

  factory WishlistPhoto.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WishlistPhoto();
    return WishlistPhoto(
      url: json['url'] as String? ?? '',
      thumbhash: json['thumbhash'] as String? ?? json['thumbHash'] as String?,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [url, thumbhash, width, height];
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

/// One row from `GET /wishlist` (active card or locked stub).
class WishlistItem extends Equatable {
  const WishlistItem({
    required this.id,
    required this.status,
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

  WishlistItem copyWith({
    WishlistItemStatus? status,
    WishlistStore? store,
  }) {
    return WishlistItem(
      id: id,
      status: status ?? this.status,
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
    final rawPhoto = json['photo'];
    final rawStore = json['store'];
    final rawSpecs = json['specifications'];
    DateTime? likedAt;
    final likedRaw = json['likedAt'];
    if (likedRaw is String && likedRaw.isNotEmpty) {
      likedAt = DateTime.tryParse(likedRaw);
    }
    return WishlistItem(
      id: json['id'] as String? ?? '',
      status: wishlistItemStatusFromString(json['status'] as String?),
      assetId: json['assetId'] as String? ?? '',
      listingId: json['listingId'] as String? ?? '',
      photo:
          rawPhoto is Map
              ? WishlistPhoto.fromJson(Map<String, dynamic>.from(rawPhoto))
              : const WishlistPhoto(),
      title: json['title'] as String? ?? '',
      collectionName: json['collectionName'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
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
