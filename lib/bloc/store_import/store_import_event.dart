part of 'store_import_bloc.dart';

sealed class StoreImportEvent extends Equatable {
  const StoreImportEvent();

  @override
  List<Object?> get props => [];
}

class StoreImportStarted extends StoreImportEvent {
  const StoreImportStarted();
}

class StoreImportProductToggled extends StoreImportEvent {
  const StoreImportProductToggled(this.productId);

  final String productId;

  @override
  List<Object?> get props => [productId];
}

class StoreImportSelectAllPressed extends StoreImportEvent {
  const StoreImportSelectAllPressed();
}

class StoreImportDestinationSelected extends StoreImportEvent {
  const StoreImportDestinationSelected(this.destinationStoreId);

  final String destinationStoreId;

  @override
  List<Object?> get props => [destinationStoreId];
}

class StoreImportRequestPressed extends StoreImportEvent {
  const StoreImportRequestPressed();
}

class StoreImportClearRequestSent extends StoreImportEvent {
  const StoreImportClearRequestSent();
}

class StoreImportSimulateApprovedPressed extends StoreImportEvent {
  const StoreImportSimulateApprovedPressed();
}

class StoreImportClearApproved extends StoreImportEvent {
  const StoreImportClearApproved();
}

class StoreImportClearMessage extends StoreImportEvent {
  const StoreImportClearMessage();
}
