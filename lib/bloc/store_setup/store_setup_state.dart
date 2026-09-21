part of 'store_setup_bloc.dart';

enum StoreLinkAvailabilityStatus { idle, checking, available, unavailable }

class StoreSetupState extends Equatable {
  const StoreSetupState({
    this.storeName = '',
    this.storeHandle = '',
    this.availabilityStatus = StoreLinkAvailabilityStatus.idle,
    this.imagePaths = const [],
    this.isPickingImages = false,
    this.isSubmitting = false,
    this.isCompleted = false,
    this.skippedStore = false,
    this.createdStoreId,
    this.errorMessage,
  });

  final String storeName;
  final String storeHandle;
  final StoreLinkAvailabilityStatus availabilityStatus;
  final List<String> imagePaths;
  final bool isPickingImages;
  final bool isSubmitting;
  final bool isCompleted;
  final bool skippedStore;
  final String? createdStoreId;
  final String? errorMessage;

  bool get isHandleAvailable =>
      availabilityStatus == StoreLinkAvailabilityStatus.available;

  bool get canContinue =>
      storeName.trim().isNotEmpty && isHandleAvailable && !isSubmitting;

  String get fullStoreLink =>
      storeHandle.isEmpty ? '' : '$storeHandle.jewelflow.app';

  StoreSetupState copyWith({
    String? storeName,
    String? storeHandle,
    StoreLinkAvailabilityStatus? availabilityStatus,
    List<String>? imagePaths,
    bool? isPickingImages,
    bool? isSubmitting,
    bool? isCompleted,
    bool? skippedStore,
    String? createdStoreId,
    String? errorMessage,
    bool clearError = false,
    bool clearCompleted = false,
  }) {
    return StoreSetupState(
      storeName: storeName ?? this.storeName,
      storeHandle: storeHandle ?? this.storeHandle,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      imagePaths: imagePaths ?? this.imagePaths,
      isPickingImages: isPickingImages ?? this.isPickingImages,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isCompleted: clearCompleted ? false : (isCompleted ?? this.isCompleted),
      skippedStore: skippedStore ?? this.skippedStore,
      createdStoreId: createdStoreId ?? this.createdStoreId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    storeName,
    storeHandle,
    availabilityStatus,
    imagePaths,
    isPickingImages,
    isSubmitting,
    isCompleted,
    skippedStore,
    createdStoreId,
    errorMessage,
  ];
}
