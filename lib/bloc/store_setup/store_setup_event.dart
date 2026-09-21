part of 'store_setup_bloc.dart';

sealed class StoreSetupEvent extends Equatable {
  const StoreSetupEvent();

  @override
  List<Object?> get props => [];
}

class StoreNameChanged extends StoreSetupEvent {
  const StoreNameChanged(this.value);

  final String value;

  @override
  List<Object?> get props => [value];
}

class StoreAvailabilityCheckRequested extends StoreSetupEvent {
  const StoreAvailabilityCheckRequested(this.handle);

  final String handle;

  @override
  List<Object?> get props => [handle];
}

class StoreImagesPickRequested extends StoreSetupEvent {
  const StoreImagesPickRequested();
}

class StoreImageRemoved extends StoreSetupEvent {
  const StoreImageRemoved(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}

class StoreCreatePressed extends StoreSetupEvent {
  const StoreCreatePressed();
}

class StoreSkipPressed extends StoreSetupEvent {
  const StoreSkipPressed();
}

class StoreClearMessage extends StoreSetupEvent {
  const StoreClearMessage();
}

class StoreClearCompleted extends StoreSetupEvent {
  const StoreClearCompleted();
}
