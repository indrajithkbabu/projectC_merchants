import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:project_c/models/store_product.dart';

/// Ephemeral channel UI chrome — visitor photo selection + busy flags.
///
/// Catalog/follow stay on [StoreProfileBloc]; local product paint for
/// wishlist bumps lives here so channel does not `setState` the full route.
class StoreChannelChromeCubit extends Cubit<StoreChannelChromeState> {
  StoreChannelChromeCubit({required List<StoreProduct> products})
    : super(StoreChannelChromeState(products: List<StoreProduct>.from(products)));

  void exitSelection() {
    if (!state.visitorPhotoSelecting && state.selectedPhotoKeys.isEmpty) {
      return;
    }
    emit(
      state.copyWith(
        visitorPhotoSelecting: false,
        selectedPhotoKeys: const {},
      ),
    );
  }

  void enterVisitorPhotoSelection(String photoKey) {
    emit(
      state.copyWith(
        visitorPhotoSelecting: true,
        selectedPhotoKeys: {photoKey},
      ),
    );
  }

  void toggleVisitorPhoto(String photoKey) {
    final next = Set<String>.from(state.selectedPhotoKeys);
    if (next.contains(photoKey)) {
      next.remove(photoKey);
      if (next.isEmpty) {
        emit(
          state.copyWith(
            visitorPhotoSelecting: false,
            selectedPhotoKeys: const {},
          ),
        );
        return;
      }
    } else {
      next.add(photoKey);
    }
    emit(state.copyWith(selectedPhotoKeys: next));
  }

  void clearSelection({bool clearBusy = true}) {
    emit(
      state.copyWith(
        visitorPhotoSelecting: false,
        selectedPhotoKeys: const {},
        wishlistBusy: clearBusy ? false : state.wishlistBusy,
        cartBusy: clearBusy ? false : state.cartBusy,
      ),
    );
  }

  void setWishlistBusy(bool busy) {
    if (state.wishlistBusy == busy) return;
    emit(state.copyWith(wishlistBusy: busy));
  }

  void setCartBusy(bool busy) {
    if (state.cartBusy == busy) return;
    emit(state.copyWith(cartBusy: busy));
  }

  void replaceProducts(List<StoreProduct> products) {
    emit(state.copyWith(products: List<StoreProduct>.from(products)));
  }

  void setLogoPage(int page) {
    if (state.logoPage == page) return;
    emit(state.copyWith(logoPage: page));
  }

  void bumpPaintEpoch() {
    emit(state.copyWith(paintEpoch: state.paintEpoch + 1));
  }

  void bumpTabEpoch() {
    emit(state.copyWith(tabEpoch: state.tabEpoch + 1));
  }
}

class StoreChannelChromeState extends Equatable {
  const StoreChannelChromeState({
    this.products = const [],
    this.selectedPhotoKeys = const {},
    this.visitorPhotoSelecting = false,
    this.wishlistBusy = false,
    this.cartBusy = false,
    this.logoPage = 0,
    this.paintEpoch = 0,
    this.tabEpoch = 0,
  });

  final List<StoreProduct> products;
  final Set<String> selectedPhotoKeys;
  final bool visitorPhotoSelecting;
  final bool wishlistBusy;
  final bool cartBusy;
  final int logoPage;
  final int paintEpoch;
  final int tabEpoch;

  StoreChannelChromeState copyWith({
    List<StoreProduct>? products,
    Set<String>? selectedPhotoKeys,
    bool? visitorPhotoSelecting,
    bool? wishlistBusy,
    bool? cartBusy,
    int? logoPage,
    int? paintEpoch,
    int? tabEpoch,
  }) {
    return StoreChannelChromeState(
      products: products ?? this.products,
      selectedPhotoKeys: selectedPhotoKeys ?? this.selectedPhotoKeys,
      visitorPhotoSelecting:
          visitorPhotoSelecting ?? this.visitorPhotoSelecting,
      wishlistBusy: wishlistBusy ?? this.wishlistBusy,
      cartBusy: cartBusy ?? this.cartBusy,
      logoPage: logoPage ?? this.logoPage,
      paintEpoch: paintEpoch ?? this.paintEpoch,
      tabEpoch: tabEpoch ?? this.tabEpoch,
    );
  }

  @override
  List<Object?> get props => [
    products,
    selectedPhotoKeys,
    visitorPhotoSelecting,
    wishlistBusy,
    cartBusy,
    logoPage,
    paintEpoch,
    tabEpoch,
  ];
}
