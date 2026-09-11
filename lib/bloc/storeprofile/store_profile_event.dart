part of 'store_profile_bloc.dart';

sealed class StoreProfileEvent extends Equatable {
  const StoreProfileEvent();

  @override
  List<Object?> get props => [];
}

class StoreProfileLoadCollections extends StoreProfileEvent {
  const StoreProfileLoadCollections();
}

class StoreProfileLoadMembers extends StoreProfileEvent {
  const StoreProfileLoadMembers();
}

class StoreProfileLoadImportRequestCount extends StoreProfileEvent {
  const StoreProfileLoadImportRequestCount();
}

class StoreProfileAddProductsPressed extends StoreProfileEvent {
  const StoreProfileAddProductsPressed();
}

class StoreProfileProductPublished extends StoreProfileEvent {
  const StoreProfileProductPublished(this.product);

  final StoreProduct product;

  @override
  List<Object?> get props => [product];
}

class StoreProfileProductUpdated extends StoreProfileEvent {
  const StoreProfileProductUpdated(
    this.product, {
    this.replacedListingId,
  });

  final StoreProduct product;
  final String? replacedListingId;

  @override
  List<Object?> get props => [product, replacedListingId];
}

class StoreProfileProductDeleted extends StoreProfileEvent {
  const StoreProfileProductDeleted(this.productId);

  final String productId;

  @override
  List<Object?> get props => [productId];
}

class StoreProfileProductsReplaced extends StoreProfileEvent {
  const StoreProfileProductsReplaced(this.products);

  final List<StoreProduct> products;

  @override
  List<Object?> get props => [products];
}

class StoreProfileProductsImported extends StoreProfileEvent {
  const StoreProfileProductsImported(this.products);

  final List<StoreProduct> products;

  @override
  List<Object?> get props => [products];
}

class StoreProfileImportPressed extends StoreProfileEvent {
  const StoreProfileImportPressed();
}

class StoreProfileSharePressed extends StoreProfileEvent {
  const StoreProfileSharePressed();
}

class StoreProfileMorePressed extends StoreProfileEvent {
  const StoreProfileMorePressed();
}

class StoreProfileQuickAddPressed extends StoreProfileEvent {
  const StoreProfileQuickAddPressed();
}

class StoreProfileClearMessage extends StoreProfileEvent {
  const StoreProfileClearMessage();
}
