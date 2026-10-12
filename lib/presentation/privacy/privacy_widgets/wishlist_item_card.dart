import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/catalog/wishlist_api_models.dart';
import 'package:project_c/models/store_privacy_mode.dart';

/// Active wishlist tile (square grid) or locked private-store stub.
class WishlistItemCard extends StatelessWidget {
  const WishlistItemCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onRemove,
    this.onFollow,
    this.isFollowBusy = false,
    this.isRemoveBusy = false,
  });

  final WishlistItem item;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback? onFollow;
  final bool isFollowBusy;
  final bool isRemoveBusy;

  @override
  Widget build(BuildContext context) {
    if (item.isLocked) {
      return _LockedCard(
        item: item,
        onRemove: onRemove,
        onFollow: onFollow,
        isFollowBusy: isFollowBusy,
        isRemoveBusy: isRemoveBusy,
      );
    }
    return _ActiveGridCard(
      item: item,
      onTap: onTap,
      onRemove: onRemove,
      isRemoveBusy: isRemoveBusy,
    );
  }
}

/// Square tile: image fills cell, heart top-right, details along the bottom.
class _ActiveGridCard extends StatelessWidget {
  const _ActiveGridCard({
    required this.item,
    required this.onTap,
    required this.onRemove,
    required this.isRemoveBusy,
  });

  final WishlistItem item;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final bool isRemoveBusy;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (item.purityLabel.isNotEmpty) item.purityLabel,
      if (item.weightLabel.isNotEmpty) item.weightLabel,
    ].join(' · ');
    final storeName = item.store.name.trim();
    final subtitle = [
      if (meta.isNotEmpty) meta,
      if (storeName.isNotEmpty) storeName,
    ].join(' · ');

    return Material(
      color: AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ProductMediaImage(
              path: item.photo.url,
              thumbhash: item.photo.thumbhash,
              fit: BoxFit.cover,
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Material(
                color: Colors.black.withValues(alpha: 0.35),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: isRemoveBusy ? null : onRemove,
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: Center(
                      child:
                          isRemoveBusy
                              ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.textOnPrimary,
                                ),
                              )
                              : Icon(
                                Icons.favorite_rounded,
                                color: AppColors.error,
                                size: 18,
                              ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.72),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 28, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption(
                            fontSize: 11,
                            color: AppColors.textOnPrimary.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedCard extends StatelessWidget {
  const _LockedCard({
    required this.item,
    required this.onRemove,
    required this.onFollow,
    required this.isFollowBusy,
    required this.isRemoveBusy,
  });

  final WishlistItem item;
  final VoidCallback onRemove;
  final VoidCallback? onFollow;
  final bool isFollowBusy;
  final bool isRemoveBusy;

  @override
  Widget build(BuildContext context) {
    final store = item.store;
    final showFollow =
        onFollow != null &&
        !store.followStatus.isFollowing &&
        store.id.trim().isNotEmpty;
    final followLabel =
        store.followStatus.isPending ? 'Requested' : 'Follow';
    final followIsOutline = store.followStatus.isPending;

    return Material(
      color: AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: AppColors.border.withValues(alpha: 0.45),
            child: Center(
              child: Icon(
                Icons.lock_outline_rounded,
                color: AppColors.textSecondary,
                size: 36,
              ),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: Colors.black.withValues(alpha: 0.28),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: isRemoveBusy ? null : onRemove,
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: Center(
                    child:
                        isRemoveBusy
                            ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textOnPrimary,
                              ),
                            )
                            : Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.textOnPrimary,
                              size: 18,
                            ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.72),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 28, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Private Store Item',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      store.name.trim().isEmpty
                          ? 'Private store'
                          : store.name.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption(
                        fontSize: 11,
                        color: AppColors.textOnPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                    if (showFollow) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        height: 28,
                        child: Material(
                          color:
                              followIsOutline
                                  ? AppColors.surface.withValues(alpha: 0.9)
                                  : AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: isFollowBusy ? null : onFollow,
                            borderRadius: BorderRadius.circular(8),
                            child: Center(
                              child:
                                  isFollowBusy
                                      ? SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color:
                                              followIsOutline
                                                  ? AppColors.textSecondary
                                                  : AppColors.textOnPrimary,
                                        ),
                                      )
                                      : Text(
                                        followLabel,
                                        style: AppTextStyles.caption(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color:
                                              followIsOutline
                                                  ? AppColors.textPrimary
                                                  : AppColors.textOnPrimary,
                                        ),
                                      ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
