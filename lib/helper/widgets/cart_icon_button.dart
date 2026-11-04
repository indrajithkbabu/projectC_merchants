import 'package:flutter/material.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/appearance_scope.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/services/cart_store.dart';

/// Cart trolley with live badge count. Opens [Routes.cartRoute] on tap.
class CartIconButton extends StatelessWidget {
  const CartIconButton({
    super.key,
    this.color,
    this.size = 22,
    this.tooltip = 'Cart',
    this.onPressed,
  });

  final Color? color;
  final double size;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.maybeOf(context);
    final cart = ServiceLocator.get<CartStore>();
    final iconColor = color ?? AppColors.textPrimary;

    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) {
        final count = cart.count;
        return IconButton(
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onPressed:
              onPressed ??
              () => Navigator.of(context).pushNamed(Routes.cartRoute),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.shopping_cart_outlined, size: size, color: iconColor),
              if (count > 0)
                Positioned(
                  right: -6,
                  top: -4,
                  child: CartCountBadge(count: count),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Cart count chip — primary fill + on-primary label (readable Day + Night).
///
/// Night `textOnPrimary` == `textPrimary` (light gray); never use that pair as
/// fill+label or the digit disappears.
class CartCountBadge extends StatelessWidget {
  const CartCountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.maybeOf(context);
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.background, width: 1.2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTextStyles.caption(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: AppColors.textOnPrimary,
          height: 1.1,
        ),
      ),
    );
  }
}
