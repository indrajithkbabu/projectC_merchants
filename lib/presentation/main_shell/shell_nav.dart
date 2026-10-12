import 'package:flutter/foundation.dart';

/// Cross-route requests to switch the main-shell bottom tab (e.g. product-details
/// “View” after liking → Wishlist) without remounting the shell.
enum ShellNavTab { stores, contacts, settings, profile, wishlist, myStore }

class ShellNav {
  ShellNav._();

  static final ValueNotifier<ShellNavTab?> pending = ValueNotifier<ShellNavTab?>(
    null,
  );

  static void request(ShellNavTab tab) {
    pending.value = tab;
  }

  static ShellNavTab? takePending() {
    final tab = pending.value;
    pending.value = null;
    return tab;
  }
}
