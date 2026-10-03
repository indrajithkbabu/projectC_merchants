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
    this.storeImages = const [],
    this.coverImageUrl = '',
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
  final List<CatalogPhoto> storeImages;
  final String coverImageUrl;
  final int pendingImportRequestCount;
  final String? deletingProductId;

  /// Background create uploads — shimmer placeholders until the API finishes.
  final List<PendingProductUpload> pendingUploads;

  /// Per-listing import status when viewing another store (Added / Pending).
  final Map<String, ListingImportAvailability> listingAvailability;

  int get productCount => products.length + pendingUploads.length;

  /// Prefer enriched photo lists when available (gallery / collection browse).
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
  /// the viewer already has a store to import into.
  bool get showActionsRow => isOwnStore || viewerHasOwnStore;

  /// Import is allowed only once the viewer has their own store.
  bool get canImport => viewerHasOwnStore;

  String get storeLink =>
      overrideStoreLink ??
      '${storeName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}.jewelflow.app';

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
    List<CatalogPhoto>? storeImages,
    String? coverImageUrl,
    int? pendingImportRequestCount,
    String? deletingProductId,
    List<PendingProductUpload>? pendingUploads,
    Map<String, ListingImportAvailability>? listingAvailability,
    bool clearDeletingProductId = false,
    bool clearInfoMessage = false,
    bool clearError = false,
    bool clearProductsDetailed = false,
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
      storeImages: storeImages ?? this.storeImages,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
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
    storeImages,
    coverImageUrl,
    pendingImportRequestCount,
    deletingProductId,
    pendingUploads,
    listingAvailability,
  ];
}
