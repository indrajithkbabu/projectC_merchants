part of 'store_profile_bloc.dart';

class StoreProfileState extends Equatable {
  const StoreProfileState({
    required this.storeName,
    required this.members,
    this.products = const [],
    this.productsDetailed = const [],
    this.isOwnStore = true,
    this.viewerHasOwnStore = true,
    this.storeId = 'my_store',
    this.avatarColor = 0xFF2AABEE,
    this.overrideStoreLink,
    this.currentUserId,
    this.infoMessage,
    this.errorMessage,
    this.isLoadingProducts = false,
    this.isLoadingMembers = false,
    this.isLoadingStoreMeta = false,
    this.isUpdatingStoreImages = false,
    this.isFollowBusy = false,
    this.storeImages = const [],
    this.coverImageUrl = '',
    this.city = '',
    this.privacy = StorePrivacyMode.public,
    this.followerCount = 0,
    this.followingCount = 0,
    this.apiProductCount,
    this.pendingFollowRequestCount = 0,
    this.followRequestPreviewNames = const [],
    this.canViewContent = true,
    this.followStatus = StoreFollowStatus.none,
    this.notifyUploads = true,
    this.pendingImportRequestCount = 0,
    this.deletingProductId,
    this.pendingUploads = const [],
    this.listingAvailability = const {},
  });

  final String storeName;
  final List<TeamMember> members;

  /// Cover-only list for the profile grid (stable; no collage morph).
  final List<StoreProduct> products;

  /// Full photo lists after background enrich (gallery / browse). Empty until
  /// enrich finishes; UI falls back to [products] via [productsForMedia].
  final List<StoreProduct> productsDetailed;
  final bool isOwnStore;

  /// True when the signed-in user already has a destination store.
  /// Import CTAs stay hidden until this is true.
  final bool viewerHasOwnStore;
  final String storeId;
  final int avatarColor;
  final String? overrideStoreLink;
  final String? currentUserId;
  final String? infoMessage;
  final String? errorMessage;
  final bool isLoadingProducts;
  final bool isLoadingMembers;
  final bool isLoadingStoreMeta;
  final bool isUpdatingStoreImages;
  final bool isFollowBusy;
  final List<CatalogPhoto> storeImages;
  final String coverImageUrl;
  final String city;
  final StorePrivacyMode privacy;
  final int followerCount;
  final int followingCount;

  /// Product count from GET store (used when content is gated).
  final int? apiProductCount;

  /// Owner-only pending follow requests (from GET store).
  final int pendingFollowRequestCount;

  /// First requester names for the follow-requests banner subtitle.
  final List<String> followRequestPreviewNames;
  final bool canViewContent;
  final StoreFollowStatus followStatus;

  /// Local UX for upload notifications while following (bell).
  final bool notifyUploads;
  final int pendingImportRequestCount;
  final String? deletingProductId;

  /// Background create uploads — shimmer placeholders until the API finishes.
  final List<PendingProductUpload> pendingUploads;

  /// Per-listing import status when viewing another store (Added / Pending).
  final Map<String, ListingImportAvailability> listingAvailability;

  /// Prefer server count when present (gated profiles still show totals).
  int get productCount {
    if (apiProductCount != null) return apiProductCount!;
    return products.length + pendingUploads.length;
  }

  bool get showFollowRequestsBanner =>
      isOwnStore &&
      privacy.isPrivate &&
      pendingFollowRequestCount > 0;

  /// Prefer enriched photo lists when available (gallery / browse).
  List<StoreProduct> get productsForMedia =>
      productsDetailed.isNotEmpty ? productsDetailed : products;

  /// Non-owner teammates (owner is always in GET /members).
  List<TeamMember> get teammates {
    final me = currentUserId;
    if (me == null || me.isEmpty) {
      // Without a user id, treat a single membership as owner-only.
      if (members.length <= 1) return const [];
      return members.skip(1).toList();
    }
    return members.where((m) => m.id != me).toList();
  }

  int get teammateCount => teammates.length;

  /// Own store can always add members from the expanded profile header.
  bool get showAddMembersCta => isOwnStore;

  bool get showImportRequestsBadge => isOwnStore;

  /// Own store always shows Add/Import; other stores only show Import when
  /// the viewer already has a store to import into and can see products.
  bool get showActionsRow =>
      isOwnStore || (viewerHasOwnStore && canViewContent);

  /// Import is allowed only once the viewer has their own store.
  bool get canImport => viewerHasOwnStore && canViewContent;

  bool get isPrivateStore => privacy.isPrivate;

  /// Visitor cannot see product photos / details.
  bool get isContentLocked => !isOwnStore && !canViewContent;

  /// Show Follow / Requested / Following chrome on other stores.
  bool get showVisitorFollowChrome =>
      !isOwnStore &&
      followStatus != StoreFollowStatus.self &&
      followStatus != StoreFollowStatus.member;

  String get storeLink =>
      overrideStoreLink ??
      '${storeName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}.jewelflow.app';

  String get visitorSubtitle {
    final cityPart = city.trim();
    if (cityPart.isEmpty) return 'Jewellery store';
    return 'Jewellery store · $cityPart';
  }

  StoreProfileState copyWith({
    String? storeName,
    List<TeamMember>? members,
    List<StoreProduct>? products,
    List<StoreProduct>? productsDetailed,
    bool? isOwnStore,
    bool? viewerHasOwnStore,
    String? storeId,
    int? avatarColor,
    String? overrideStoreLink,
    String? currentUserId,
    String? infoMessage,
    String? errorMessage,
    bool? isLoadingProducts,
    bool? isLoadingMembers,
    bool? isLoadingStoreMeta,
    bool? isUpdatingStoreImages,
    bool? isFollowBusy,
    List<CatalogPhoto>? storeImages,
    String? coverImageUrl,
    String? city,
    StorePrivacyMode? privacy,
    int? followerCount,
    int? followingCount,
    int? apiProductCount,
    int? pendingFollowRequestCount,
    List<String>? followRequestPreviewNames,
    bool? canViewContent,
    StoreFollowStatus? followStatus,
    bool? notifyUploads,
    int? pendingImportRequestCount,
    String? deletingProductId,
    List<PendingProductUpload>? pendingUploads,
    Map<String, ListingImportAvailability>? listingAvailability,
    bool clearDeletingProductId = false,
    bool clearInfoMessage = false,
    bool clearError = false,
    bool clearProductsDetailed = false,
    bool clearApiProductCount = false,
  }) {
    return StoreProfileState(
      storeName: storeName ?? this.storeName,
      members: members ?? this.members,
      products: products ?? this.products,
      productsDetailed:
          clearProductsDetailed
              ? const []
              : (productsDetailed ?? this.productsDetailed),
      isOwnStore: isOwnStore ?? this.isOwnStore,
      viewerHasOwnStore: viewerHasOwnStore ?? this.viewerHasOwnStore,
      storeId: storeId ?? this.storeId,
      avatarColor: avatarColor ?? this.avatarColor,
      overrideStoreLink: overrideStoreLink ?? this.overrideStoreLink,
      currentUserId: currentUserId ?? this.currentUserId,
      infoMessage: clearInfoMessage ? null : (infoMessage ?? this.infoMessage),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLoadingProducts: isLoadingProducts ?? this.isLoadingProducts,
      isLoadingMembers: isLoadingMembers ?? this.isLoadingMembers,
      isLoadingStoreMeta: isLoadingStoreMeta ?? this.isLoadingStoreMeta,
      isUpdatingStoreImages:
          isUpdatingStoreImages ?? this.isUpdatingStoreImages,
      isFollowBusy: isFollowBusy ?? this.isFollowBusy,
      storeImages: storeImages ?? this.storeImages,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      city: city ?? this.city,
      privacy: privacy ?? this.privacy,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      apiProductCount:
          clearApiProductCount
              ? null
              : (apiProductCount ?? this.apiProductCount),
      pendingFollowRequestCount:
          pendingFollowRequestCount ?? this.pendingFollowRequestCount,
      followRequestPreviewNames:
          followRequestPreviewNames ?? this.followRequestPreviewNames,
      canViewContent: canViewContent ?? this.canViewContent,
      followStatus: followStatus ?? this.followStatus,
      notifyUploads: notifyUploads ?? this.notifyUploads,
      pendingImportRequestCount:
          pendingImportRequestCount ?? this.pendingImportRequestCount,
      deletingProductId:
          clearDeletingProductId
              ? null
              : (deletingProductId ?? this.deletingProductId),
      pendingUploads: pendingUploads ?? this.pendingUploads,
      listingAvailability: listingAvailability ?? this.listingAvailability,
    );
  }

  @override
  List<Object?> get props => [
    storeName,
    members,
    products,
    productsDetailed,
    isOwnStore,
    viewerHasOwnStore,
    storeId,
    avatarColor,
    overrideStoreLink,
    currentUserId,
    infoMessage,
    errorMessage,
    isLoadingProducts,
    isLoadingMembers,
    isLoadingStoreMeta,
    isUpdatingStoreImages,
    isFollowBusy,
    storeImages,
    coverImageUrl,
    city,
    privacy,
    followerCount,
    followingCount,
    apiProductCount,
    pendingFollowRequestCount,
    followRequestPreviewNames,
    canViewContent,
    followStatus,
    notifyUploads,
    pendingImportRequestCount,
    deletingProductId,
    pendingUploads,
    listingAvailability,
  ];
}
