part of 'store_setup_bloc.dart';

enum StoreLinkAvailabilityStatus { idle, checking, available, unavailable }

class StoreSetupState extends Equatable {
  const StoreSetupState({
    this.storeName = '',
    this.storeHandle = '',
    this.availabilityStatus = StoreLinkAvailabilityStatus.idle,
    this.isSubmitting = false,
    this.isCompleted = false,
    this.skippedStore = false,
    this.createdStoreId,
    this.errorMessage,
  });

  final String storeName;
  final String storeHandle;
  final StoreLinkAvailabilityStatus availabilityStatus;
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
    isSubmitting,
    isCompleted,
    skippedStore,
    createdStoreId,
    errorMessage,
  ];
}
