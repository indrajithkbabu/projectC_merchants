part of 'product_details_bloc.dart';

class ProductDetailsState extends Equatable {
  const ProductDetailsState({
    required this.product,
    required this.storeName,
    required this.storeLink,
    this.storeId,
    this.isOwnStore = false,
    this.initialImageIndex = 0,
    this.isLoadingPhotos = false,
    this.revision = 1,
    this.apiTag = '',
    this.canEdit = false,
    this.canDelete = false,
    this.shouldOpenEdit = false,
    this.isDeleting = false,
    this.isDeleted = false,
    this.infoMessage,
  });

  final StoreProduct product;
  final String storeName;
  final String storeLink;
  final String? storeId;
  final bool isOwnStore;
  final int initialImageIndex;
  final bool isLoadingPhotos;
  final int revision;
  final String apiTag;
  final bool canEdit;
  final bool canDelete;
  final bool shouldOpenEdit;
  final bool isDeleting;
  final bool isDeleted;
  final String? infoMessage;

  ProductDetailsState copyWith({
    StoreProduct? product,
    String? storeName,
    String? storeLink,
    String? storeId,
    bool? isOwnStore,
    int? initialImageIndex,
    bool? isLoadingPhotos,
    int? revision,
    String? apiTag,
    bool? canEdit,
    bool? canDelete,
    bool? shouldOpenEdit,
    bool clearShouldOpenEdit = false,
    bool? isDeleting,
    bool? isDeleted,
    bool clearDeleted = false,
    String? infoMessage,
    bool clearInfoMessage = false,
  }) {
    return ProductDetailsState(
      product: product ?? this.product,
      storeName: storeName ?? this.storeName,
      storeLink: storeLink ?? this.storeLink,
      storeId: storeId ?? this.storeId,
      isOwnStore: isOwnStore ?? this.isOwnStore,
      initialImageIndex: initialImageIndex ?? this.initialImageIndex,
      isLoadingPhotos: isLoadingPhotos ?? this.isLoadingPhotos,
      revision: revision ?? this.revision,
      apiTag: apiTag ?? this.apiTag,
      canEdit: canEdit ?? this.canEdit,
      canDelete: canDelete ?? this.canDelete,
      shouldOpenEdit:
          clearShouldOpenEdit
              ? false
              : (shouldOpenEdit ?? this.shouldOpenEdit),
      isDeleting: isDeleting ?? this.isDeleting,
      isDeleted: clearDeleted ? false : (isDeleted ?? this.isDeleted),
      infoMessage: clearInfoMessage ? null : (infoMessage ?? this.infoMessage),
    );
  }

  @override
  List<Object?> get props => [
    product,
    storeName,
    storeLink,
    storeId,
    isOwnStore,
    initialImageIndex,
    isLoadingPhotos,
    revision,
    apiTag,
    canEdit,
    canDelete,
    shouldOpenEdit,
    isDeleting,
    isDeleted,
    infoMessage,
  ];
}
