import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

/// Ephemeral Discover UI chrome — selection, busy flags, scroll reveal.
///
/// Kept separate from [StoreProfileBloc] (catalog / meta) so long-lived shell
/// catalog state is not polluted by multi-select, and chrome updates do not
/// re-run catalog `buildWhen` paths unnecessarily.
class StoreProfileChromeCubit extends Cubit<StoreProfileChromeState> {
  StoreProfileChromeCubit() : super(const StoreProfileChromeState());

  void exitSelection() {
    if (!state.selectionMode &&
        state.selectedIds.isEmpty &&
        state.selectedPhotoKeys.isEmpty) {
      return;
    }
    emit(
      state.copyWith(
        selectionMode: false,
        visitorPhotoSelecting: false,
        selectedIds: const {},
        selectedPhotoKeys: const {},
      ),
    );
  }

  void enterAlbumSelection(String productId) {
    emit(
      state.copyWith(
        selectionMode: true,
        visitorPhotoSelecting: false,
        selectedIds: {productId},
        selectedPhotoKeys: const {},
      ),
    );
  }

  void enterVisitorPhotoSelection(String photoKey) {
    emit(
      state.copyWith(
        selectionMode: true,
        visitorPhotoSelecting: true,
        selectedIds: const {},
        selectedPhotoKeys: {photoKey},
      ),
    );
  }

  void toggleAlbumSelected(String productId) {
    final next = Set<String>.from(state.selectedIds);
    if (next.contains(productId)) {
      next.remove(productId);
      if (next.isEmpty) {
        emit(
          state.copyWith(
            selectionMode: false,
            visitorPhotoSelecting: false,
            selectedIds: const {},
            selectedPhotoKeys: const {},
          ),
        );
        return;
      }
    } else {
      next.add(productId);
    }
    emit(state.copyWith(selectedIds: next));
  }

  void toggleVisitorPhoto(String photoKey) {
    final next = Set<String>.from(state.selectedPhotoKeys);
    if (next.contains(photoKey)) {
      next.remove(photoKey);
      if (next.isEmpty) {
        emit(
          state.copyWith(
            selectionMode: false,
            visitorPhotoSelecting: false,
            selectedIds: const {},
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

  void clearSelection() {
    emit(
      state.copyWith(
        selectionMode: false,
        visitorPhotoSelecting: false,
        selectedIds: const {},
        selectedPhotoKeys: const {},
        wishlistBusy: false,
        cartBusy: false,
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

  void setAwaitingReveal(bool awaiting) {
    if (state.awaitingReveal == awaiting) return;
    emit(state.copyWith(awaitingReveal: awaiting));
  }

  /// Force a chrome rebuild (e.g. rebind collage URLs after details pop).
  void bumpPaintEpoch() {
    emit(state.copyWith(paintEpoch: state.paintEpoch + 1));
  }
}

class StoreProfileChromeState extends Equatable {
  const StoreProfileChromeState({
    this.selectionMode = false,
    this.visitorPhotoSelecting = false,
    this.selectedIds = const {},
    this.selectedPhotoKeys = const {},
    this.wishlistBusy = false,
    this.cartBusy = false,
    this.awaitingReveal = false,
    this.paintEpoch = 0,
  });

  final bool selectionMode;
  final bool visitorPhotoSelecting;
  final Set<String> selectedIds;
  final Set<String> selectedPhotoKeys;
  final bool wishlistBusy;
  final bool cartBusy;
  final bool awaitingReveal;
  final int paintEpoch;

  StoreProfileChromeState copyWith({
    bool? selectionMode,
    bool? visitorPhotoSelecting,
    Set<String>? selectedIds,
    Set<String>? selectedPhotoKeys,
    bool? wishlistBusy,
    bool? cartBusy,
    bool? awaitingReveal,
    int? paintEpoch,
  }) {
    return StoreProfileChromeState(
      selectionMode: selectionMode ?? this.selectionMode,
      visitorPhotoSelecting:
          visitorPhotoSelecting ?? this.visitorPhotoSelecting,
      selectedIds: selectedIds ?? this.selectedIds,
      selectedPhotoKeys: selectedPhotoKeys ?? this.selectedPhotoKeys,
      wishlistBusy: wishlistBusy ?? this.wishlistBusy,
      cartBusy: cartBusy ?? this.cartBusy,
      awaitingReveal: awaitingReveal ?? this.awaitingReveal,
      paintEpoch: paintEpoch ?? this.paintEpoch,
    );
  }

  @override
  List<Object?> get props => [
    selectionMode,
    visitorPhotoSelecting,
    selectedIds,
    selectedPhotoKeys,
    wishlistBusy,
    cartBusy,
    awaitingReveal,
    paintEpoch,
  ];
}
