part of 'import_requests_bloc.dart';

class ImportRequestsState extends Equatable {
  const ImportRequestsState({
    required this.storeId,
    required this.storeName,
    this.items = const [],
    this.isLoading = false,
    this.actingRequestId,
    this.infoMessage,
    this.errorMessage,
  });

  final String storeId;
  final String storeName;
  final List<ImportRequestItem> items;
  final bool isLoading;
  final String? actingRequestId;
  final String? infoMessage;
  final String? errorMessage;

  List<ImportRequestItem> get pendingIncoming =>
      items
          .where((i) => i.isIncoming && i.request.isPending)
          .toList(growable: false);

  List<ImportRequestItem> get pendingOutgoing =>
      items
          .where((i) => i.isOutgoing && i.request.isPending)
          .toList(growable: false);

  List<ImportRequestItem> get incomingItems =>
      items.where((i) => i.isIncoming).toList(growable: false);

  List<ImportRequestItem> get outgoingItems =>
      items.where((i) => i.isOutgoing).toList(growable: false);

  ImportRequestsState copyWith({
    String? storeId,
    String? storeName,
    List<ImportRequestItem>? items,
    bool? isLoading,
    String? actingRequestId,
    String? infoMessage,
    String? errorMessage,
    bool clearActing = false,
    bool clearInfo = false,
    bool clearError = false,
  }) {
    return ImportRequestsState(
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      actingRequestId:
          clearActing ? null : (actingRequestId ?? this.actingRequestId),
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    storeId,
    storeName,
    items,
    isLoading,
    actingRequestId,
    infoMessage,
    errorMessage,
  ];
}
