import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/cart_qa.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/visitor_cart_batch.dart';
import 'package:project_c/helper/widgets/appearance_scope.dart';
import 'package:project_c/models/catalog/catalog_stock_status.dart';
import 'package:project_c/models/store_product.dart';

/// WhatsApp-style forward (reply arrow mirrored) for selection import.
class WhatsAppForwardIcon extends StatelessWidget {
  const WhatsAppForwardIcon({
    super.key,
    required this.color,
    this.size = 22,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
      child: Icon(Icons.reply_rounded, size: size, color: color),
    );
  }
}

/// Telegram-style check badge on a selected photo tile.
class TelegramPhotoSelectBadge extends StatelessWidget {
  const TelegramPhotoSelectBadge({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? const Color(0xFF4FAE4E) : Colors.black26,
        border: Border.all(color: Colors.white, width: 1.6),
      ),
      child:
          selected
              ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
              : null,
    );
  }
}

/// Selection dock: Add to cart · Import (optional) · Heart.
///
/// When [onAsk] is set, the dock is Ask about N + cart + heart. Import stays
/// on the header forward control.
///
/// Cart CTA label / style follows [CartSelectionBreakdown]:
/// - addable > 0 → "Add N to cart"
/// - all in cart → "Go to cart"
/// - all out of stock → "Out of stock" (disabled; heart stays active)
class VisitorPhotoActionDock extends StatelessWidget {
  const VisitorPhotoActionDock({
    super.key,
    this.onAddToCart,
    this.onGoToCart,
    this.onImport,
    this.onWishlist,
    this.wishlistBusy = false,
    this.cartBusy = false,
    this.showImport = true,
    this.importCount = 0,
    this.importInstantCount = 0,
    this.importPendingCount = 0,
    this.cartBreakdown = const CartSelectionBreakdown(
      addable: 0,
      alreadyInCart: 0,
      outOfStock: 0,
      selected: 0,
    ),
    this.cartFull = false,
    this.onAsk,
  });

  final VoidCallback? onAddToCart;
  final VoidCallback? onGoToCart;
  final VoidCallback? onImport;
  final VoidCallback? onWishlist;

  /// When set, the dock adds Ask about N. Import stays on the header forward.
  final VoidCallback? onAsk;

  final bool wishlistBusy;
  final bool cartBusy;
  final bool showImport;
  final int importCount;
  final int importInstantCount;
  final int importPendingCount;
  final CartSelectionBreakdown cartBreakdown;
  final bool cartFull;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.maybeOf(context);
    final chrome = _visitorGlassChrome();
    final count = importCount < 0 ? 0 : importCount;
    final pending = importPendingCount < 0 ? 0 : importPendingCount;
    final instant = importInstantCount < 0 ? 0 : importInstantCount;
    final importLabel = count <= 0 ? 'Import' : 'Import $count';
    final showApprovalStrip = showImport && pending > 0;

    final cartState = _cartCtaState();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showApprovalStrip) ...[
          _ImportApprovalStrip(instant: instant, pending: pending),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            if (onAsk != null) ...[
              Expanded(
                child: _AskAboutButton(
                  count: count,
                  onTap: count == 0 ? null : onAsk,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              flex: showImport && onAsk == null ? 3 : 4,
              child: _CartActionButton(
                label: cartState.label,
                mode: cartState.mode,
                busy: cartBusy,
                onTap: cartState.onTap,
              ),
            ),
            if (showImport && onAsk == null) ...[
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _VisitorActionButton(
                  label: importLabel,
                  icon: Icons.download_rounded,
                  fill: chrome.fill,
                  border: chrome.border,
                  foreground: chrome.foreground,
                  onTap:
                      wishlistBusy || cartBusy || onImport == null
                          ? null
                          : () => onImport?.call(),
                ),
              ),
            ],
            const SizedBox(width: 8),
            _HeartActionButton(
              busy: wishlistBusy,
              onTap:
                  wishlistBusy || cartBusy || onWishlist == null
                      ? null
                      : () => onWishlist?.call(),
              fill: chrome.fill,
              border: chrome.border,
              foreground: chrome.foreground,
            ),
          ],
        ),
      ],
    );
  }

  ({String label, _CartCtaMode mode, VoidCallback? onTap}) _cartCtaState() {
    CartQa.noteDockMode(
      selected: cartBreakdown.selected,
      addable: cartBreakdown.addable,
      alreadyInCart: cartBreakdown.alreadyInCart,
      outOfStock: cartBreakdown.outOfStock,
      allInCart: cartBreakdown.allInCart,
      allOutOfStock: cartBreakdown.allOutOfStock,
    );
    if (cartFull && cartBreakdown.addable > 0) {
      return (
        label: 'Cart is full',
        mode: _CartCtaMode.disabled,
        onTap: null,
      );
    }
    if (cartBreakdown.allOutOfStock) {
      return (
        label: 'Out of stock',
        mode: _CartCtaMode.disabled,
        onTap: null,
      );
    }
    if (cartBreakdown.allInCart) {
      return (
        label: 'Go to cart',
        mode: _CartCtaMode.goToCart,
        onTap: cartBusy ? null : onGoToCart,
      );
    }
    final n = cartBreakdown.addable;
    final label = n <= 0
        ? 'Add to cart'
        : (n == 1 ? 'Add 1 to cart' : 'Add $n to cart');
    return (
      label: label,
      mode: _CartCtaMode.add,
      onTap: (cartBusy || n <= 0 || onAddToCart == null) ? null : onAddToCart,
    );
  }
}

enum _CartCtaMode { add, goToCart, disabled }

/// Compact orange notice above Import when locked photos need owner approval.
class _ImportApprovalStrip extends StatelessWidget {
  const _ImportApprovalStrip({
    required this.instant,
    required this.pending,
  });

  final int instant;
  final int pending;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.maybeOf(context);
    final night = AppColors.isNight;
    final detail =
        instant > 0
            ? '$instant instant · $pending need approval'
            : '$pending need approval';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: night ? 0.55 : 0.35),
          width: 0.8,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Icon(Icons.lock_rounded, size: 16, color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: night ? AppColors.textPrimary : AppColors.warning,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom Add to cart / Import / Heart while visitor photo selection is active.
class VisitorPhotoSelectionOverlay extends StatelessWidget {
  const VisitorPhotoSelectionOverlay({
    super.key,
    this.onAddToCart,
    this.onGoToCart,
    this.onImport,
    this.onWishlist,
    this.wishlistBusy = false,
    this.cartBusy = false,
    this.showImport = true,
    this.importCount = 0,
    this.importInstantCount = 0,
    this.importPendingCount = 0,
    this.cartBreakdown = const CartSelectionBreakdown(
      addable: 0,
      alreadyInCart: 0,
      outOfStock: 0,
      selected: 0,
    ),
    this.cartFull = false,
    this.onAsk,
  });

  final VoidCallback? onAddToCart;
  final VoidCallback? onGoToCart;
  final VoidCallback? onImport;
  final VoidCallback? onWishlist;
  final VoidCallback? onAsk;
  final bool wishlistBusy;
  final bool cartBusy;
  final bool showImport;
  final int importCount;
  final int importInstantCount;
  final int importPendingCount;
  final CartSelectionBreakdown cartBreakdown;
  final bool cartFull;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      left: AppPadding.horizontal,
      right: AppPadding.horizontal,
      bottom: safeBottom + 16,
      child: VisitorPhotoActionDock(
        onAddToCart: onAddToCart,
        onGoToCart: onGoToCart,
        onImport: onImport,
        onWishlist: onWishlist,
        wishlistBusy: wishlistBusy,
        cartBusy: cartBusy,
        showImport: showImport,
        importCount: importCount,
        importInstantCount: importInstantCount,
        importPendingCount: importPendingCount,
        cartBreakdown: cartBreakdown,
        cartFull: cartFull,
        onAsk: onAsk,
      ),
    );
  }
}

/// In-memory instant vs pending counts for selected photo keys (API §3.1).
({int instant, int pending}) visitorImportSelectionSplit({
  required Set<String> photoKeys,
  required List<StoreProduct> products,
}) {
  final byId = <String, StoreProduct>{
    for (final p in products) p.id: p,
  };
  var instant = 0;
  var pending = 0;
  for (final key in photoKeys) {
    final bar = key.lastIndexOf('|');
    if (bar <= 0) continue;
    final imageIndex = int.tryParse(key.substring(bar + 1)) ?? 0;
    final product = byId[key.substring(0, bar)];
    if (product == null) continue;
    // Group collage: lock is per cell (photoAssetIds), not card rollup.
    if (product.isLockedAt(imageIndex)) {
      pending++;
    } else {
      instant++;
    }
  }
  return (instant: instant, pending: pending);
}

/// Lock / stock / import / in-cart flags. Shown on source photos only while selecting.
class VisitorImportStatusMarks extends StatelessWidget {
  const VisitorImportStatusMarks({
    super.key,
    required this.locked,
    this.stock,
    this.alreadyImported = false,
    this.selectionBlocked = false,
    this.inCart = false,
  });

  final bool locked;
  final CatalogStockStatus? stock;
  final bool alreadyImported;
  final bool selectionBlocked;
  final bool inCart;

  @override
  Widget build(BuildContext context) {
    final out = stock == CatalogStockStatus.outOfStock;
    final toOrder = stock == CatalogStockStatus.mto;
    if (!locked &&
        !out &&
        !toOrder &&
        !alreadyImported &&
        !selectionBlocked &&
        !inCart) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (alreadyImported) _pill('In Your Store', AppColors.primary),
        if (selectionBlocked) ...[
          if (alreadyImported) const SizedBox(height: 4),
          _pill('Exclusive', Colors.black87),
        ],
        if (locked) ...[
          if (alreadyImported || selectionBlocked) const SizedBox(height: 4),
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.2),
            ),
            child: const Icon(
              Icons.lock_rounded,
              size: 12,
              color: Colors.white,
            ),
          ),
        ],
        if (inCart) ...[
          if (alreadyImported || selectionBlocked || locked)
            const SizedBox(height: 4),
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.2),
            ),
            child: const Icon(
              Icons.shopping_cart_rounded,
              size: 11,
              color: Colors.white,
            ),
          ),
        ],
        if (out || toOrder) ...[
          const SizedBox(height: 4),
          _pill(
            out ? 'Out of stock' : 'To order',
            out ? AppColors.error : Colors.black54,
          ),
        ],
      ],
    );
  }

  Widget _pill(String label, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

({Color fill, Color border, Color foreground}) _visitorGlassChrome() {
  final night = AppColors.isNight;
  return (
    fill:
        night
            ? AppColors.appBar.withValues(alpha: 0.42)
            : AppColors.surface.withValues(alpha: 0.55),
    border:
        night
            ? AppColors.border.withValues(alpha: 0.45)
            : AppColors.border.withValues(alpha: 0.7),
    foreground: night ? AppColors.textOnPrimary : AppColors.textPrimary,
  );
}

class _AskAboutButton extends StatelessWidget {
  const _AskAboutButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = count <= 0 ? 'Ask about' : 'Ask about $count';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 18,
                color: onTap == null ? AppColors.grey400 : AppColors.grey900,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.label(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: onTap == null ? AppColors.grey400 : AppColors.grey900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartActionButton extends StatelessWidget {
  const _CartActionButton({
    required this.label,
    required this.mode,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final _CartCtaMode mode;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.maybeOf(context);
    final night = AppColors.isNight;
    final Color fill;
    final Color border;
    final Color foreground;
    switch (mode) {
      // Solid primary CTA — night textOnPrimary == textPrimary, so never use
      // that pair as fill+label (label vanishes).
      case _CartCtaMode.add:
        fill = night ? AppColors.primary : AppColors.accent;
        border = fill;
        foreground = AppColors.textOnPrimary;
      case _CartCtaMode.goToCart:
        fill = night ? AppColors.primary : AppColors.textPrimary;
        border =
            night
                ? AppColors.border.withValues(alpha: 0.7)
                : AppColors.textPrimary;
        foreground = AppColors.textOnPrimary;
      case _CartCtaMode.disabled:
        fill = AppColors.surfaceSecondary;
        border = AppColors.border.withValues(alpha: 0.5);
        foreground = AppColors.textSecondary;
    }

    final enabled = onTap != null;
    return Opacity(
      opacity: enabled || busy || mode == _CartCtaMode.disabled ? 1 : 0.55,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: 0.8),
            ),
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (busy)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: foreground,
                        ),
                      )
                    else
                      Icon(
                        mode == _CartCtaMode.goToCart
                            ? Icons.shopping_cart_outlined
                            : Icons.shopping_cart_rounded,
                        size: 20,
                        color: foreground,
                      ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body(
                          fontWeight: FontWeight.w700,
                          color: foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeartActionButton extends StatelessWidget {
  const _HeartActionButton({
    required this.fill,
    required this.border,
    required this.foreground,
    required this.onTap,
    this.busy = false,
  });

  final Color fill;
  final Color border;
  final Color foreground;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap != null || busy ? 1 : 0.55,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border, width: 0.8),
                ),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Center(
                    child:
                        busy
                            ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: foreground,
                              ),
                            )
                            : Icon(
                              Icons.favorite_border_rounded,
                              size: 22,
                              color: foreground,
                            ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VisitorActionButton extends StatelessWidget {
  const _VisitorActionButton({
    required this.label,
    required this.icon,
    required this.fill,
    required this.border,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color fill;
  final Color border;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border, width: 0.8),
                ),
                child: SizedBox(
                  height: 52,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 20, color: foreground),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body(
                              fontWeight: FontWeight.w700,
                              color: foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
