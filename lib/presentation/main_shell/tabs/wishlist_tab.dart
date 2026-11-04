import 'package:flutter/material.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/appearance_scope.dart';
import 'package:project_c/helper/widgets/floating_bottom_nav_bar.dart';
import 'package:project_c/helper/widgets/shell_tab_title_bar.dart';
import 'package:project_c/presentation/cart/cart_route.dart';
import 'package:project_c/presentation/main_shell/shell_nav.dart';
import 'package:project_c/presentation/privacy/wishlist_route.dart';
import 'package:project_c/services/cart_store.dart';

/// Shell Wishlist hub — pill switcher for [WishlistRoute] + embedded [CartRoute].
///
/// Kept alive in the shell [IndexedStack]. [refreshSignal] quiet-refetches
/// wishlist (and cart when that pill is selected) when the bottom tab is
/// re-selected.
class WishlistTab extends StatefulWidget {
  const WishlistTab({super.key, this.refreshSignal = 0});

  final int refreshSignal;

  @override
  State<WishlistTab> createState() => _WishlistTabState();
}

class _WishlistTabState extends State<WishlistTab> {
  late ShellWishlistHubPane _pane;
  int _cartRefreshSignal = 0;

  @override
  void initState() {
    super.initState();
    _pane = ShellNav.wishlistHubPane.value;
    ShellNav.wishlistHubPane.addListener(_onHubPane);
  }

  @override
  void dispose() {
    ShellNav.wishlistHubPane.removeListener(_onHubPane);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant WishlistTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshSignal != oldWidget.refreshSignal &&
        widget.refreshSignal > 0 &&
        _pane == ShellWishlistHubPane.cart) {
      setState(() => _cartRefreshSignal++);
    }
  }

  void _onHubPane() {
    final next = ShellNav.wishlistHubPane.value;
    if (!mounted || next == _pane) return;
    setState(() {
      _pane = next;
      if (next == ShellWishlistHubPane.cart) {
        _cartRefreshSignal++;
      }
    });
  }

  void _selectPane(ShellWishlistHubPane pane) {
    if (pane == _pane) {
      if (pane == ShellWishlistHubPane.cart) {
        setState(() => _cartRefreshSignal++);
      }
      return;
    }
    // [_onHubPane] applies state; bump cart refresh when opening Cart.
    if (pane == ShellWishlistHubPane.cart) {
      _cartRefreshSignal++;
    }
    ShellNav.wishlistHubPane.value = pane;
  }

  @override
  Widget build(BuildContext context) {
    AppearanceScope.maybeOf(context);
    final bottom = FloatingBottomNavBar.reservedHeight(context);
    final onCart = _pane == ShellWishlistHubPane.cart;
    final cart = ServiceLocator.get<CartStore>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: ShellTabTitleBar.padding(context),
          child: ListenableBuilder(
            listenable: cart,
            builder: (context, _) {
              final title = onCart ? 'Cart' : 'Wishlist';
              final cartCount = cart.count;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ShellTabTitleBar(
                    title: title,
                    titleBadge:
                        onCart && cartCount > 0
                            ? _HubCountPill(count: cartCount)
                            : null,
                  ),
                  const SizedBox(height: 10),
                  _WishlistCartPills(
                    pane: _pane,
                    cartCount: cartCount,
                    onChanged: _selectPane,
                  ),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: onCart ? 1 : 0,
            sizing: StackFit.expand,
            children: [
              WishlistRoute(
                embeddedInShell: true,
                hideShellTitle: true,
                bottomInset: bottom,
                refreshSignal: widget.refreshSignal,
              ),
              CartRoute(
                embeddedInShell: true,
                bottomInset: bottom,
                refreshSignal: _cartRefreshSignal,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HubCountPill extends StatelessWidget {
  const _HubCountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.maybeOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: AppTextStyles.label(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _WishlistCartPills extends StatelessWidget {
  const _WishlistCartPills({
    required this.pane,
    required this.cartCount,
    required this.onChanged,
  });

  final ShellWishlistHubPane pane;
  final int cartCount;
  final ValueChanged<ShellWishlistHubPane> onChanged;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.maybeOf(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _HubPill(
              label: 'Wishlist',
              selected: pane == ShellWishlistHubPane.wishlist,
              onTap: () => onChanged(ShellWishlistHubPane.wishlist),
            ),
          ),
          Expanded(
            child: _HubPill(
              label: 'Cart',
              count: cartCount,
              selected: pane == ShellWishlistHubPane.cart,
              onTap: () => onChanged(ShellWishlistHubPane.cart),
            ),
          ),
        ],
      ),
    );
  }
}

class _HubPill extends StatelessWidget {
  const _HubPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count = 0,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelColor =
        selected ? AppColors.textPrimary : AppColors.textSecondary;
    return Material(
      color: selected ? AppColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: labelColor,
                  ),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        selected
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: AppTextStyles.caption(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color:
                          selected
                              ? AppColors.textOnPrimary
                              : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
