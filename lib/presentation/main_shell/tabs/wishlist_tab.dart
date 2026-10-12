import 'package:flutter/material.dart';
import 'package:project_c/helper/widgets/floating_bottom_nav_bar.dart';
import 'package:project_c/presentation/privacy/wishlist_route.dart';

/// Shell Wishlist tab — same live wishlist UI as privacy [WishlistRoute].
///
/// Kept alive in the shell [IndexedStack]. [refreshSignal] triggers a quiet
/// refetch when the tab is selected so new likes appear without a restart.
class WishlistTab extends StatelessWidget {
  const WishlistTab({super.key, this.refreshSignal = 0});

  final int refreshSignal;

  @override
  Widget build(BuildContext context) {
    final bottom = FloatingBottomNavBar.reservedHeight(context);
    return WishlistRoute(
      embeddedInShell: true,
      bottomInset: bottom,
      refreshSignal: refreshSignal,
    );
  }
}
