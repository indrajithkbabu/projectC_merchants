part of 'import_requests_bloc.dart';

sealed class ImportRequestsEvent extends Equatable {
  const ImportRequestsEvent();

  @override
  List<Object?> get props => [];
}

class ImportRequestsStarted extends ImportRequestsEvent {
  const ImportRequestsStarted();
}

class ImportRequestsRefreshed extends ImportRequestsEvent {
  const ImportRequestsRefreshed();
}

/// Approve one product in a received request (item-level / `partial`).
class ImportRequestsAcceptPressed extends ImportRequestsEvent {
  const ImportRequestsAcceptPressed({
    required this.requestId,
    required this.productId,
  });

  final String requestId;
  final String productId;

  @override
  List<Object?> get props => [requestId, productId];
}

/// Decline one product in a received request (item-level / `partial`).
class ImportRequestsRejectPressed extends ImportRequestsEvent {
  const ImportRequestsRejectPressed({
    required this.requestId,
    required this.productId,
  });

  final String requestId;
  final String productId;

  @override
  List<Object?> get props => [requestId, productId];
}

/// Cancel a pending Sent request (requester).
class ImportRequestsCancelPressed extends ImportRequestsEvent {
  const ImportRequestsCancelPressed({required this.requestId});

  final String requestId;

  @override
  List<Object?> get props => [requestId];
}

class ImportRequestsClearMessage extends ImportRequestsEvent {
  const ImportRequestsClearMessage();
}
