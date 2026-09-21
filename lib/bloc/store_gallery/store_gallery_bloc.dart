import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:project_c/models/product_details_feed_item.dart';
import 'package:project_c/models/store_product.dart';

part 'store_gallery_event.dart';
part 'store_gallery_state.dart';

class StoreGalleryBloc extends Bloc<StoreGalleryEvent, StoreGalleryState> {
  StoreGalleryBloc({
    required List<StoreProduct> products,
    required String storeName,
    required String storeLink,
    String? storeId,
    bool isOwnStore = false,
  }) : super(
         StoreGalleryState(
           products: products,
           storeName: storeName,
           storeLink: storeLink,
           storeId: storeId,
           isOwnStore: isOwnStore,
           sections: StoreGalleryState.buildSections(products),
         ),
       ) {
    on<StoreGalleryColumnsChanged>(_onColumnsChanged);
    on<StoreGalleryProductUpdated>(_onProductUpdated);
    on<StoreGalleryProductDeleted>(_onProductDeleted);
  }

  void _onColumnsChanged(
    StoreGalleryColumnsChanged event,
    Emitter<StoreGalleryState> emit,
  ) {
    final columns =
        event.columns < StoreGalleryState.minColumns
            ? StoreGalleryState.minColumns
            : event.columns;
    emit(state.copyWith(crossAxisCount: columns));
  }

  void _onProductUpdated(
    StoreGalleryProductUpdated event,
    Emitter<StoreGalleryState> emit,
  ) {
    final replacedId = event.replacedListingId?.trim();
    final next = <StoreProduct>[];
    var replaced = false;
    for (final product in state.products) {
      if (product.id == event.product.id ||
          (replacedId != null &&
              replacedId.isNotEmpty &&
              product.id == replacedId)) {
        if (!replaced) {
          next.add(event.product);
          replaced = true;
        }
        continue;
      }
      next.add(product);
    }
    if (!replaced) {
      next.insert(0, event.product);
    }
    emit(state.copyWith(products: next));
  }

  void _onProductDeleted(
    StoreGalleryProductDeleted event,
    Emitter<StoreGalleryState> emit,
  ) {
    final next =
        state.products.where((p) => p.id != event.productId).toList();
    emit(state.copyWith(products: next));
  }
}
