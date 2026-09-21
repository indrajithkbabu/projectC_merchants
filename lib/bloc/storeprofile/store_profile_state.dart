part of 'store_profile_bloc.dart';

class StoreProfileState extends Equatable {
  const StoreProfileState({
    required this.storeName,
    required this.members,
    this.products = const [],
    this.isOwnStore = true,
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
  });

  final String storeName;
  final List<TeamMember> members;
  final List<StoreProduct> products;
  final bool isOwnStore;
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

  int get productCount => products.length;

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

  String get storeLink =>
      overrideStoreLink ??
      '${storeName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}.jewelflow.app';

  StoreProfileState copyWith({
    String? storeName,
    List<TeamMember>? members,
    List<StoreProduct>? products,
    bool? isOwnStore,
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
    bool clearDeletingProductId = false,
    bool clearInfoMessage = false,
    bool clearError = false,
  }) {
    return StoreProfileState(
      storeName: storeName ?? this.storeName,
      members: members ?? this.members,
      products: products ?? this.products,
      isOwnStore: isOwnStore ?? this.isOwnStore,
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
    );
  }

  @override
  List<Object?> get props => [
    storeName,
    members,
    products,
    isOwnStore,
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
  ];
}
