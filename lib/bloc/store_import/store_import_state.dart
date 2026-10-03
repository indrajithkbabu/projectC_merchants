part of 'store_import_bloc.dart';

class StoreImportState extends Equatable {
  const StoreImportState({
    required this.sourceStore,
    this.selectedIds = const {},
    this.targets = const [],
    this.listingTargets = const {},
    this.listingAvailability = const {},
    this.selectedDestinationId,
    this.isLoadingTargets = false,
    this.isSubmitting = false,
    this.requestSent = false,
    this.isApproved = false,
    this.importedCount = 0,
    this.lastRequestId,
    this.errorMessage,
  });

  final StoreChannel sourceStore;
  final Set<String> selectedIds;
  final List<ImportTarget> targets;
  /// Per-listing import-targets response (cached after probe).
  final Map<String, List<ImportTarget>> listingTargets;
  final Map<String, ListingImportAvailability> listingAvailability;
  final String? selectedDestinationId;
  final bool isLoadingTargets;
  final bool isSubmitting;
  final bool requestSent;
  final bool isApproved;
  final int importedCount;
  final String? lastRequestId;
  final String? errorMessage;

  bool isImportable(String listingId) =>
      listingAvailability[listingId] == ListingImportAvailability.available;

  bool isBlocked(String listingId) {
    final status = listingAvailability[listingId];
    return status == ListingImportAvailability.alreadyAdded ||
        status == ListingImportAvailability.pending;
  }

  Set<String> get importableIds =>
      sourceStore.products
          .map((p) => p.id)
          .where(isImportable)
          .toSet();

  /// Selected listings that can still be requested.
  Set<String> get requestableSelectedIds =>
      selectedIds.where(isImportable).toSet();

  List<StoreProduct> get selectedProducts =>
      sourceStore.products
          .where((p) => requestableSelectedIds.contains(p.id))
          .toList();

  int get selectedCount => requestableSelectedIds.length;

  List<ImportTarget> get requestableTargets =>
      targets.where((t) => t.canRequest).toList();

  bool get needsDestinationPicker => requestableTargets.length > 1;

  bool get hasDestination =>
      selectedDestinationId != null && selectedDestinationId!.isNotEmpty;

  bool get canRequestImport =>
      selectedCount > 0 &&
      !isSubmitting &&
      !isLoadingTargets &&
      hasDestination;

  StoreImportState copyWith({
    StoreChannel? sourceStore,
    Set<String>? selectedIds,
    List<ImportTarget>? targets,
    Map<String, List<ImportTarget>>? listingTargets,
    Map<String, ListingImportAvailability>? listingAvailability,
    String? selectedDestinationId,
    bool clearDestination = false,
    bool? isLoadingTargets,
    bool? isSubmitting,
    bool? requestSent,
    bool clearRequestSent = false,
    bool? isApproved,
    bool clearApproved = false,
    int? importedCount,
    String? lastRequestId,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StoreImportState(
      sourceStore: sourceStore ?? this.sourceStore,
      selectedIds: selectedIds ?? this.selectedIds,
      targets: targets ?? this.targets,
      listingTargets: listingTargets ?? this.listingTargets,
      listingAvailability: listingAvailability ?? this.listingAvailability,
      selectedDestinationId:
          clearDestination
              ? null
              : (selectedDestinationId ?? this.selectedDestinationId),
      isLoadingTargets: isLoadingTargets ?? this.isLoadingTargets,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      requestSent:
          clearRequestSent ? false : (requestSent ?? this.requestSent),
      isApproved: clearApproved ? false : (isApproved ?? this.isApproved),
      importedCount: importedCount ?? this.importedCount,
      lastRequestId: lastRequestId ?? this.lastRequestId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    sourceStore,
    selectedIds,
    targets,
    listingTargets,
    listingAvailability,
    selectedDestinationId,
    isLoadingTargets,
    isSubmitting,
    requestSent,
    isApproved,
    importedCount,
    lastRequestId,
    errorMessage,
  ];
}
