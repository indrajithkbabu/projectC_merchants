import 'package:flutter/material.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/cart_qa.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/visitor_cart_batch.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/appearance_scope.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/catalog/cart_models.dart';
import 'package:project_c/models/store_channel.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/main_shell/shell_nav.dart';
import 'package:project_c/services/cart_store.dart';
import 'package:project_c/webservice/cart/cart_repository.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';

/// Cart screen — items grouped by store via `GET /me/cart`.
///
/// [embeddedInShell]: Wishlist hub Cart pill — no [ScreenWrapper] / back /
/// heart; parent owns title + pills. [bottomInset] reserves floating nav.
class CartRoute extends StatefulWidget {
  const CartRoute({
    super.key,
    this.embeddedInShell = false,
    this.bottomInset = 0,
    this.refreshSignal = 0,
  });

  final bool embeddedInShell;
  final double bottomInset;
  final int refreshSignal;

  @override
  State<CartRoute> createState() => _CartRouteState();
}

class _CartRouteState extends State<CartRoute> {
  late final CartRepository _cart;
  late final CartStore _store;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _cart = ServiceLocator.get<CartRepository>();
    _store = _cart.store;
    // ignore: discarded_futures
    _load(quiet: widget.embeddedInShell);
  }

  @override
  void didUpdateWidget(covariant CartRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshSignal != oldWidget.refreshSignal &&
        widget.refreshSignal > 0) {
      // ignore: discarded_futures
      _load(quiet: true);
    }
  }

  Future<void> _load({bool quiet = false}) async {
    CartQa.caseStart('TC-06', 'Open cart GET /me/cart (grouped + fine)');
    if (!quiet || _cart.count == 0) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    } else {
      setState(() => _loadError = null);
    }
    try {
      await _cart.refreshCart();
      if (!mounted) return;
      setState(() => _loading = false);
      CartQa.caseEnd(
        'TC-06',
        pass: true,
        detail:
            'items=${_cart.count} stores=${_cart.storeCount} '
            'fine="${_cart.summary.displayLabel}"',
      );
      CartQa.info(
        'TC-12',
        detail: 'footer non-tappable “continue buying soon” (no checkout)',
      );
    } catch (e) {
      if (!mounted) return;
      final msg = CatalogErrorMapper.toUserMessage(e).trim();
      setState(() {
        _loading = false;
        _loadError =
            msg.isEmpty ? 'Could not load cart. Pull to retry.' : msg;
      });
      CartQa.caseEnd('TC-06', pass: false, detail: msg.isEmpty ? '$e' : msg);
    }
  }

  /// Leave cart (and any store/channel stack above the shell), then open
  /// shell Wishlist hub (Wishlist pill). A single [Navigator.maybePop] left
  /// store profile on top.
  void _openShellWishlist(BuildContext context) {
    final nav = Navigator.of(context);
    nav.popUntil(
      (route) =>
          route.settings.name == Routes.storeListingRoute || route.isFirst,
    );
    ShellNav.request(ShellNavTab.wishlist);
  }

  @override
  Widget build(BuildContext context) {
    AppearanceScope.maybeOf(context);
    final embedded = widget.embeddedInShell;
    final top = ScreenWrapper.statusBarTop(context);
    final body = ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final groups = _cart.groupedByStore();
        final count = _cart.count;
        final stores = _cart.storeCount > 0 ? _cart.storeCount : groups.length;
        final subtitle = _subtitle(count, stores);
        final summary = _cart.summary;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!embedded)
              Padding(
                padding: AppPadding.screen(top: top + 8, bottom: 8),
                child: Row(
                  children: [
                    AppBackButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cart',
                            style: AppTextStyles.title(fontSize: 22),
                          ),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              style: AppTextStyles.caption(
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Wishlist',
                      onPressed: () => _openShellWishlist(context),
                      icon: Icon(
                        Icons.favorite_border_rounded,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _body(
                groups,
                count,
                // Footer already clears the floating nav when items exist.
                bottomInset:
                    embedded && count == 0 ? widget.bottomInset : 0,
              ),
            ),
            if (count > 0)
              _CartFooter(
                displayTotalFine: summary.displayLabel,
                bottomInset: embedded ? widget.bottomInset : null,
              ),
          ],
        );
      },
    );

    if (embedded) {
      return ColoredBox(color: AppColors.background, child: body);
    }
    return ScreenWrapper(
      backgroundColor: AppColors.background,
      child: body,
    );
  }

  Widget _body(
    List<CartStoreGroup> groups,
    int count, {
    double bottomInset = 0,
  }) {
    final listBottom = bottomInset > 0 ? bottomInset + 8 : 24.0;
    if (_loading && count == 0) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_loadError != null && count == 0) {
      return Center(
        child: Padding(
          padding: AppPadding.screen(bottom: listBottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary(),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (count == 0) {
      return Center(
        child: Padding(
          padding: AppPadding.screen(bottom: listBottom),
          child: Text(
            'Your cart is empty',
            style: AppTextStyles.bodySecondary(),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView.builder(
        padding: AppPadding.screen(bottom: listBottom),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          return _StoreGroupCard(
            group: groups[index],
            onRemove: _removeWithUndo,
            onWishlist: _moveToWishlist,
            onOpenStore: _openStore,
            onOutOfStockTap: _openStore,
          );
        },
      ),
    );
  }

  String _subtitle(int items, int stores) {
    if (items <= 0) return '';
    final itemLabel = items == 1 ? '1 item' : '$items items';
    final storeLabel = stores == 1 ? '1 store' : '$stores stores';
    return '$itemLabel · $storeLabel';
  }

  Future<void> _removeWithUndo(CartItem item) async {
    try {
      await _cart.removeProduct(item.productId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 2500),
          content: const Text('Removed from cart'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              try {
                await _cart.restoreProductId(item.productId);
              } catch (_) {}
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = CatalogErrorMapper.toUserMessage(e).trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg.isEmpty ? 'Could not remove from cart.' : msg,
          ),
        ),
      );
    }
  }

  Future<void> _moveToWishlist(CartItem item) async {
    try {
      await _cart.moveToWishlist(item.productId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 2500),
          content: const Text('Moved to wishlist'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              try {
                await _cart.undoMoveToWishlist(item.productId);
              } catch (_) {}
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = CatalogErrorMapper.toUserMessage(e).trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg.isEmpty ? 'Could not move to wishlist.' : msg,
          ),
        ),
      );
    }
  }

  void _openStore(CartItem item) {
    final storeId = item.storeId.trim();
    if (storeId.isEmpty) return;
    Navigator.of(context).pushNamed(
      Routes.storeProfileRoute,
      arguments: {
        'store': StoreChannel(
          id: storeId,
          name: item.storeName,
          handle: '',
          avatarColor: 0xFF5A5A5A,
          products: const [],
          coverImageUrl: item.storeAvatarUrl,
          isOwn: false,
        ),
        'isOwnStore': false,
      },
    );
  }
}

class _StoreGroupCard extends StatelessWidget {
  const _StoreGroupCard({
    required this.group,
    required this.onRemove,
    required this.onWishlist,
    required this.onOpenStore,
    required this.onOutOfStockTap,
  });

  final CartStoreGroup group;
  final void Function(CartItem) onRemove;
  final void Function(CartItem) onWishlist;
  final void Function(CartItem) onOpenStore;
  final void Function(CartItem) onOutOfStockTap;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.maybeOf(context);
    final count = group.items.length;
    final countLabel = count == 1 ? '1 item' : '$count items';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap:
                group.items.isEmpty
                    ? null
                    : () => onOpenStore(group.items.first),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  _StoreAvatar(
                    name: group.storeName,
                    imageUrl: group.storeAvatarUrl,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      group.storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    countLabel,
                    style: AppTextStyles.caption(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          for (final item in group.items)
            _CartItemRow(
              item: item,
              onRemove: () => onRemove(item),
              onWishlist: () => onWishlist(item),
              onOutOfStockTap: () => onOutOfStockTap(item),
            ),
        ],
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  const _CartItemRow({
    required this.item,
    required this.onRemove,
    required this.onWishlist,
    required this.onOutOfStockTap,
  });

  final CartItem item;
  final VoidCallback onRemove;
  final VoidCallback onWishlist;
  final VoidCallback onOutOfStockTap;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.maybeOf(context);
    final out = item.isOutOfStock;
    final titleColor =
        out ? AppColors.textSecondary : AppColors.textPrimary;
    final weightColor =
        out ? AppColors.textSecondary : AppColors.textPrimary;
    final fine = item.fineWeightGrams;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 72,
              height: 72,
              child: ColorFiltered(
                colorFilter:
                    out
                        ? const ColorFilter.matrix(<double>[
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0, 0, 0, 1, 0,
                        ])
                        : const ColorFilter.mode(
                          Colors.transparent,
                          BlendMode.dst,
                        ),
                child: ProductMediaImage(
                  path: item.imageUrl,
                  thumbhash:
                      item.thumbhash.isEmpty ? null : item.thumbhash,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                if (item.detailLine.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.detailLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    _OutlineIconButton(
                      icon: Icons.delete_outline_rounded,
                      onTap: onRemove,
                    ),
                    const SizedBox(width: 8),
                    _OutlineLabelButton(
                      icon: Icons.favorite_border_rounded,
                      label: 'Wishlist',
                      onTap: onWishlist,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (out)
                InkWell(
                  onTap: onOutOfStockTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Out of stock',
                          style: AppTextStyles.caption(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                )
              else if (fine != null && fine > 0) ...[
                Text(
                  '${fine.toStringAsFixed(2)} g',
                  style: AppTextStyles.body(
                    fontWeight: FontWeight.w700,
                    color: weightColor,
                  ),
                ),
                Text(
                  'FINE',
                  style: AppTextStyles.caption(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CartFooter extends StatelessWidget {
  const _CartFooter({
    required this.displayTotalFine,
    this.bottomInset,
  });

  /// BE `summary.displayTotalFine` (e.g. `17.58 g Au · 99.90 g Ag`).
  final String displayTotalFine;

  /// When set (shell hub), use floating-nav reserve instead of raw safe bottom.
  final double? bottomInset;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.maybeOf(context);
    final safeBottom =
        bottomInset ?? MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.6)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppPadding.horizontal,
          12,
          AppPadding.horizontal,
          safeBottom + 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Match item-row fine column: value flush to the trailing edge.
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'TOTAL FINE',
                  style: AppTextStyles.caption(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayTotalFine.isEmpty ? '0.00 g' : displayTotalFine,
                    textAlign: TextAlign.right,
                    style: AppTextStyles.body(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            CustomPaint(
              painter: _DashedRRectPainter(
                color: AppColors.border,
                radius: 12,
              ),
              child: SizedBox(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'You can continue buying soon',
                      style: AppTextStyles.body(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreAvatar extends StatelessWidget {
  const _StoreAvatar({required this.name, required this.imageUrl});

  final String name;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    return ClipOval(
      child: SizedBox(
        width: 36,
        height: 36,
        child:
            imageUrl.trim().isEmpty
                ? ColoredBox(
                  color: AppColors.surfaceSecondary,
                  child: Center(
                    child: Text(
                      initials,
                      style: AppTextStyles.caption(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                : ProductMediaImage(path: imageUrl),
      ),
    );
  }

  String _initials(String raw) {
    final parts =
        raw.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'S';
    if (parts.length == 1) {
      final s = parts.first;
      return s.substring(0, s.length >= 2 ? 2 : 1).toUpperCase();
    }
    return ('${parts[0][0]}${parts[1][0]}').toUpperCase();
  }
}

class _OutlineIconButton extends StatelessWidget {
  const _OutlineIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 18, color: AppColors.textPrimary),
      ),
    );
  }
}

class _OutlineLabelButton extends StatelessWidget {
  const _OutlineLabelButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.textPrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.caption(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Snack helper used by selection / photo flows.
void showCartAddSnack(
  BuildContext context,
  CartAddResult result, {
  int? storeCountAfter,
}) {
  final msg = cartAddSnackMessage(
    result,
    storeCountAfter: storeCountAfter,
  );
  if (msg.isEmpty) return;
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      action: SnackBarAction(
        label: 'View',
        onPressed: () {
          Navigator.of(context).pushNamed(Routes.cartRoute);
        },
      ),
    ),
  );
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 5.0;
      const gap = 4.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
