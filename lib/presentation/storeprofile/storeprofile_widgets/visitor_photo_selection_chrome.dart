import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
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

/// Two separate Import + Wishlist buttons (not a single segmented dock).
/// Clear selection via header close / edge-swipe — no Cancel CTA.
/// Store accounts see Import (with the selection count). Accounts without
/// a store see Wishlist alone.
///
/// When any selected photo is locked, an orange approval strip sits above
/// the buttons; the Import CTA stays short (`Import N`) so it never overflows.
class VisitorPhotoActionDock extends StatelessWidget {
  const VisitorPhotoActionDock({
    super.key,
    this.onImport,
    this.onWishlist,
    this.wishlistBusy = false,
    this.showImport = true,
    this.importCount = 0,
    this.importInstantCount = 0,
    this.importPendingCount = 0,
  });

  /// Opens the prefilled review screen. Hidden when [showImport] is false.
  final VoidCallback? onImport;

  /// Batch collection like for selected listings.
  final VoidCallback? onWishlist;

  final bool wishlistBusy;
  final bool showImport;
  final int importCount;

  /// Unlocked selected photos (instant publish) — drives approval strip.
  final int importInstantCount;

  /// Locked selected photos (need approval) — drives approval strip.
  final int importPendingCount;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.maybeOf(context);
    final chrome = _visitorGlassChrome();
    final count = importCount < 0 ? 0 : importCount;
    final pending = importPendingCount < 0 ? 0 : importPendingCount;
    final instant = importInstantCount < 0 ? 0 : importInstantCount;
    final importLabel = count <= 0 ? 'Import' : 'Import $count';
    final showApprovalStrip = showImport && pending > 0;
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
            if (showImport) ...[
              Expanded(
                child: _VisitorActionButton(
                  label: importLabel,
                  icon: Icons.download_rounded,
                  fill: chrome.fill,
                  border: chrome.border,
                  foreground: chrome.foreground,
                  onTap:
                      wishlistBusy || onImport == null
                          ? null
                          : () => onImport?.call(),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: _VisitorActionButton(
                label: 'Wishlist',
                icon: Icons.favorite_border_rounded,
                fill: chrome.fill,
                border: chrome.border,
                foreground: chrome.foreground,
                // Keep label; show a compact spinner on the heart while the
                // collection-like batch runs (no "Saving…" text).
                busy: wishlistBusy,
                onTap:
                    wishlistBusy || onWishlist == null
                        ? null
                        : () => onWishlist?.call(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

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

/// Bottom Import / Wishlist buttons while visitor photo selection is active.
class VisitorPhotoSelectionOverlay extends StatelessWidget {
  const VisitorPhotoSelectionOverlay({
    super.key,
    this.onImport,
    this.onWishlist,
    this.wishlistBusy = false,
    this.showImport = true,
    this.importCount = 0,
    this.importInstantCount = 0,
    this.importPendingCount = 0,
  });

  final VoidCallback? onImport;
  final VoidCallback? onWishlist;
  final bool wishlistBusy;
  final bool showImport;
  final int importCount;
  final int importInstantCount;
  final int importPendingCount;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      left: AppPadding.horizontal,
      right: AppPadding.horizontal,
      bottom: safeBottom + 16,
      child: VisitorPhotoActionDock(
        onImport: onImport,
        onWishlist: onWishlist,
        wishlistBusy: wishlistBusy,
        showImport: showImport,
        importCount: importCount,
        importInstantCount: importInstantCount,
        importPendingCount: importPendingCount,
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

/// Lock / stock / import flags. Shown on source photos only while selecting.
class VisitorImportStatusMarks extends StatelessWidget {
  const VisitorImportStatusMarks({
    super.key,
    required this.locked,
    this.stock,
    this.alreadyImported = false,
    this.selectionBlocked = false,
  });

  final bool locked;
  final CatalogStockStatus? stock;
  final bool alreadyImported;
  final bool selectionBlocked;

  @override
  Widget build(BuildContext context) {
    final out = stock == CatalogStockStatus.outOfStock;
    final toOrder = stock == CatalogStockStatus.mto;
    if (!locked &&
        !out &&
        !toOrder &&
        !alreadyImported &&
        !selectionBlocked) {
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
        if (out || toOrder) ...[
          const SizedBox(height: 4),
          _pill(out ? 'Out of stock' : 'To order', out ? AppColors.error : Colors.black54),
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

class _VisitorActionButton extends StatelessWidget {
  const _VisitorActionButton({
    required this.label,
    required this.icon,
    required this.fill,
    required this.border,
    required this.foreground,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final Color fill;
  final Color border;
  final Color foreground;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled || busy ? 1 : 0.55,
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
                          Icon(icon, size: 20, color: foreground),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body(
                            fontWeight: FontWeight.w700,
                            color: foreground,
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
