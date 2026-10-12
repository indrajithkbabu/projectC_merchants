import 'package:equatable/equatable.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/models/store_privacy_mode.dart';

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
    this.phone = '',
    this.city = '',
    this.privacy,
    this.followerCount = 0,
    this.followingCount = 0,
    this.productCount,
    this.pendingRequestsCount,
    this.canViewContent,
    this.followStatusRaw,
    this.notifyUploads,
    this.autoApprovedFollowers,
    this.images = const [],
    this.imageUrls = const [],
    this.coverImage,
  });

  final String id;
  final String name;
  final String slug;
  final StoreRelationship? relationship;
  final String? legalName;

  /// Owner / store contact phone from `/home` (E.164 when provided).
  final String phone;

  /// City shown on private-store identity preview (when provided).
  final String city;

  /// Store-wide privacy from GET store / PATCH privacy. Null when older APIs
  /// omit it (treat as public until hydrated).
  final StorePrivacyMode? privacy;

  final int followerCount;
  final int followingCount;

  /// Server product/collection count (shown even when content is gated).
  final int? productCount;

  /// Owner-only pending follow request count from GET store / privacy PATCH.
  final int? pendingRequestsCount;

  /// Server-computed visibility; when null, use [resolvedCanViewContent].
  final bool? canViewContent;

  /// API followStatus: none | pending | following | self | member.
  final String? followStatusRaw;

  /// Upload push preference while following (GET store / follow payloads).
  final bool? notifyUploads;

  /// From privacy PATCH when switching to public (bulk-approved count).
  final int? autoApprovedFollowers;

  final List<CatalogPhoto> images;
  final List<String> imageUrls;
  final CatalogPhoto? coverImage;

  bool get isOwn => relationship == StoreRelationship.owner;

  String get storeLink => '$slug.jewelflow.app';

  /// Effective visibility for product content (read-time access check).
  bool get resolvedCanViewContent {
    if (canViewContent != null) return canViewContent!;
    if (relationship == StoreRelationship.owner ||
        relationship == StoreRelationship.member) {
      return true;
    }
    final status = followStatusRaw?.trim().toLowerCase() ?? '';
    if (status == 'following' || status == 'self' || status == 'member') {
      return true;
    }
    // Pending / none never unlock private stores. Unknown privacy + pending
    // must stay locked (follow POST payloads omit privacy).
    if (status == 'pending') return false;
    if (privacy == StorePrivacyMode.private) return false;
    if (privacy == null || privacy == StorePrivacyMode.public) return true;
    return false;
  }

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

  /// Deduped showcase URLs for listing avatar + preview.
  List<String> get showcaseImageUrls {
    final seen = <String>{};
    final out = <String>[];
    void add(String raw) {
      final url = raw.trim();
      if (url.isEmpty || !seen.add(url)) return;
      out.add(url);
    }

    add(coverImage?.url ?? '');
    for (final url in imageUrls) {
      add(url);
    }
    for (final photo in images) {
      add(photo.url);
    }
    return out;
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
                .whereType<Map>()
                .map(
                  (e) => CatalogPhoto.fromJson(Map<String, dynamic>.from(e)),
                )
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

    final coverImage = _parseCoverPhoto(root, images);

    final privacyRaw = root['privacy'] ?? json['privacy'];
    final StorePrivacyMode? privacy =
        privacyRaw is String && privacyRaw.trim().isNotEmpty
            ? StorePrivacyModeX.fromApi(privacyRaw)
            : null;

    final followRaw =
        (root['followStatus'] ?? json['followStatus'] ?? json['status'])
            as String?;

    // Follow POST uses status=active|pending — map active → following for
    // CatalogStore payloads that reuse the same field name.
    String? normalizedFollow = followRaw;
    if (normalizedFollow != null &&
        normalizedFollow.trim().toLowerCase() == 'active') {
      normalizedFollow = 'following';
    }

    final stats = root['stats'] ?? json['stats'];
    int? productCount =
        (root['productCount'] as num?)?.toInt() ??
        (root['collectionCount'] as num?)?.toInt() ??
        (root['productsCount'] as num?)?.toInt() ??
        (root['totalProducts'] as num?)?.toInt() ??
        (root['listingsCount'] as num?)?.toInt() ??
        (json['productCount'] as num?)?.toInt() ??
        (json['collectionCount'] as num?)?.toInt() ??
        (json['productsCount'] as num?)?.toInt() ??
        (json['totalProducts'] as num?)?.toInt();
    if (productCount == null && stats is Map) {
      final s = Map<String, dynamic>.from(stats);
      productCount =
          (s['productCount'] as num?)?.toInt() ??
          (s['products'] as num?)?.toInt() ??
          (s['collectionCount'] as num?)?.toInt() ??
          (s['collections'] as num?)?.toInt();
    }

    return CatalogStore(
      id: root['id'] as String? ?? '',
      name: root['name'] as String? ?? '',
      slug: root['slug'] as String? ?? '',
      relationship: relationship,
      legalName: root['legalName'] as String?,
      phone: _firstString(root, const [
        'phone',
        'phoneNumber',
        'phonenumber',
      ]),
      city: _firstString(root, const ['city', 'cityName']),
      privacy: privacy,
      followerCount:
          (root['followerCount'] as num?)?.toInt() ??
          (json['followerCount'] as num?)?.toInt() ??
          0,
      followingCount:
          (root['followingCount'] as num?)?.toInt() ??
          (json['followingCount'] as num?)?.toInt() ??
          0,
      productCount: productCount,
      pendingRequestsCount:
          (root['pendingRequestsCount'] as num?)?.toInt() ??
          (json['pendingRequestsCount'] as num?)?.toInt(),
      canViewContent:
          root['canViewContent'] as bool? ?? json['canViewContent'] as bool?,
      followStatusRaw: normalizedFollow,
      notifyUploads:
          root['notifyUploads'] as bool? ??
          json['notifyUploads'] as bool? ??
          root['notify_uploads'] as bool? ??
          json['notify_uploads'] as bool?,
      autoApprovedFollowers:
          (root['autoApprovedFollowers'] as num?)?.toInt() ??
          (json['autoApprovedFollowers'] as num?)?.toInt(),
      images: images,
      imageUrls: imageUrls,
      coverImage: coverImage,
    );
  }

  static String _firstString(Map<String, dynamic> root, List<String> keys) {
    for (final key in keys) {
      final value = root[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  static CatalogPhoto? _parseCoverPhoto(
    Map<String, dynamic> root,
    List<CatalogPhoto> images,
  ) {
    CatalogPhoto? fromValue(Object? raw) {
      if (raw is Map) {
        return CatalogPhoto.fromJson(Map<String, dynamic>.from(raw));
      }
      if (raw is String && raw.trim().isNotEmpty) {
        return CatalogPhoto(url: raw.trim(), width: 0, height: 0);
      }
      return null;
    }

    final fromCover = fromValue(root['coverImage']);
    if (fromCover != null && fromCover.url.trim().isNotEmpty) return fromCover;

    final fromStoreImage =
        fromValue(root['storeImage']) ?? fromValue(root['storeimage']);
    if (fromStoreImage != null && fromStoreImage.url.trim().isNotEmpty) {
      return fromStoreImage;
    }

    if (images.isNotEmpty) return images.first;
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    if (relationship != null) 'relationship': relationship!.name,
    if (legalName != null) 'legalName': legalName,
    if (phone.isNotEmpty) 'phone': phone,
    if (city.isNotEmpty) 'city': city,
    if (privacy != null) 'privacy': privacy!.apiValue,
    'followerCount': followerCount,
    'followingCount': followingCount,
    if (productCount != null) 'productCount': productCount,
    if (pendingRequestsCount != null)
      'pendingRequestsCount': pendingRequestsCount,
    if (canViewContent != null) 'canViewContent': canViewContent,
    if (followStatusRaw != null) 'followStatus': followStatusRaw,
    if (notifyUploads != null) 'notifyUploads': notifyUploads,
    if (autoApprovedFollowers != null)
      'autoApprovedFollowers': autoApprovedFollowers,
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
      if (phone.isNotEmpty) 'phone': phone,
      if (city.isNotEmpty) 'city': city,
      if (privacy != null) 'privacy': privacy!.apiValue,
      'followerCount': followerCount,
      'followingCount': followingCount,
      if (productCount != null) 'productCount': productCount,
      if (pendingRequestsCount != null)
        'pendingRequestsCount': pendingRequestsCount,
      if (canViewContent != null) 'canViewContent': canViewContent,
      if (followStatusRaw != null) 'followStatus': followStatusRaw,
      if (autoApprovedFollowers != null)
        'autoApprovedFollowers': autoApprovedFollowers,
      'images': root['images'],
      'imageUrls': root['imageUrls'],
      'coverImage': root['coverImage'],
      'storeImage': root['storeImage'],
      'storeimage': root['storeimage'],
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
    String? phone,
    String? city,
    StorePrivacyMode? privacy,
    int? followerCount,
    int? followingCount,
    int? productCount,
    int? pendingRequestsCount,
    bool? canViewContent,
    String? followStatusRaw,
    bool? notifyUploads,
    int? autoApprovedFollowers,
    List<CatalogPhoto>? images,
    List<String>? imageUrls,
    CatalogPhoto? coverImage,
    bool clearCoverImage = false,
    bool clearPendingRequestsCount = false,
    bool clearCanViewContent = false,
    bool clearFollowStatusRaw = false,
    bool clearNotifyUploads = false,
    bool clearAutoApprovedFollowers = false,
    bool clearPrivacy = false,
  }) {
    return CatalogStore(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      relationship: relationship ?? this.relationship,
      legalName: legalName ?? this.legalName,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      privacy: clearPrivacy ? null : (privacy ?? this.privacy),
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      productCount: productCount ?? this.productCount,
      pendingRequestsCount:
          clearPendingRequestsCount
              ? null
              : (pendingRequestsCount ?? this.pendingRequestsCount),
      canViewContent:
          clearCanViewContent ? null : (canViewContent ?? this.canViewContent),
      followStatusRaw:
          clearFollowStatusRaw
              ? null
              : (followStatusRaw ?? this.followStatusRaw),
      notifyUploads:
          clearNotifyUploads ? null : (notifyUploads ?? this.notifyUploads),
      autoApprovedFollowers:
          clearAutoApprovedFollowers
              ? null
              : (autoApprovedFollowers ?? this.autoApprovedFollowers),
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
    phone,
    city,
    privacy,
    followerCount,
    followingCount,
    productCount,
    pendingRequestsCount,
    canViewContent,
    followStatusRaw,
    notifyUploads,
    autoApprovedFollowers,
    images,
    imageUrls,
    coverImage,
  ];
}
