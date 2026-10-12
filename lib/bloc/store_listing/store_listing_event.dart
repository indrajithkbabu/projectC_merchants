part of 'store_listing_bloc.dart';

sealed class StoreListingEvent extends Equatable {
  const StoreListingEvent();

  @override
  List<Object?> get props => [];
}

class StoreListingSearchChanged extends StoreListingEvent {
  const StoreListingSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class StoreListingRefreshed extends StoreListingEvent {
  const StoreListingRefreshed();
}

class StoreListingLoadMore extends StoreListingEvent {
  const StoreListingLoadMore();
}

class StoreListingDeleteAccountRequested extends StoreListingEvent {
  const StoreListingDeleteAccountRequested();
}

class StoreListingClearMessage extends StoreListingEvent {
  const StoreListingClearMessage();
}

class StoreListingClearAccountDeleted extends StoreListingEvent {
  const StoreListingClearAccountDeleted();
}

/// Internal: apply contact names resolved after a disk-first paint.
class StoreListingCachedNamesReady extends StoreListingEvent {
  const StoreListingCachedNamesReady(this.stores);

  final List<StoreChannel> stores;

  @override
  List<Object?> get props => [stores];
}
