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

class ImportRequestsAcceptPressed extends ImportRequestsEvent {
  const ImportRequestsAcceptPressed(this.requestId);

  final String requestId;

  @override
  List<Object?> get props => [requestId];
}

class ImportRequestsRejectPressed extends ImportRequestsEvent {
  const ImportRequestsRejectPressed(this.requestId);

  final String requestId;

  @override
  List<Object?> get props => [requestId];
}

class ImportRequestsClearMessage extends ImportRequestsEvent {
  const ImportRequestsClearMessage();
}
