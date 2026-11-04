import 'package:flutter/foundation.dart';

/// Cross-route requests to switch the main-shell bottom tab (e.g. product-details
/// “View” after liking → Wishlist) without remounting the shell.
///
/// [cart] opens the own-store Wishlist shell tab on the **Cart** pill
/// (same bottom index as [wishlist]).
enum ShellNavTab {
  stores,
  contacts,
  settings,
  profile,
  wishlist,
  cart,
  myStore,
}

/// Pane inside the Wishlist shell hub (Wishlist | Cart pills).
enum ShellWishlistHubPane { wishlist, cart }

class ShellNav {
  ShellNav._();

  static final ValueNotifier<ShellNavTab?> pending = ValueNotifier<ShellNavTab?>(
    null,
  );

  /// Which pill is selected on the Wishlist hub. Survives tab switches.
  static final ValueNotifier<ShellWishlistHubPane> wishlistHubPane =
      ValueNotifier<ShellWishlistHubPane>(ShellWishlistHubPane.wishlist);

  static void request(ShellNavTab tab) {
    if (tab == ShellNavTab.wishlist) {
      _setHubPane(ShellWishlistHubPane.wishlist);
    } else if (tab == ShellNavTab.cart) {
      _setHubPane(ShellWishlistHubPane.cart);
    }
    // ValueNotifier skips notify if value is unchanged — clear first so a
    // repeated request still reaches the shell listener.
    if (pending.value == tab) {
      pending.value = null;
    }
    pending.value = tab;
  }

  static void _setHubPane(ShellWishlistHubPane pane) {
    wishlistHubPane.value = pane;
  }

  static ShellNavTab? takePending() {
    final tab = pending.value;
    pending.value = null;
    return tab;
  }
}
