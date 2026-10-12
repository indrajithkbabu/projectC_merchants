import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/store_channel.dart';
import 'package:project_c/presentation/store_listing/store_listing_widgets/store_listing_image_preview.dart';

class StoreListingTile extends StatelessWidget {
  const StoreListingTile({
    super.key,
    required this.store,
    required this.onTap,
  });

  final StoreChannel store;
  final VoidCallback onTap;

  void _openImagePreview(BuildContext context) {
    final urls = store.imageUrls;
    if (urls.isEmpty) return;
    showStoreListingImagePreview(context, imageUrls: urls);
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = store.listingSubtitle;
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: _StoreAvatar(
        store: store,
        onImageTap:
            store.imageUrls.isEmpty
                ? null
                : () => _openImagePreview(context),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              store.name,
              style: AppTextStyles.body(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (store.isOwn) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'You',
                style: AppTextStyles.caption(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle:
          subtitle.isEmpty
              ? null
              : Text(subtitle, style: AppTextStyles.caption()),
    );
  }
}

class _StoreAvatar extends StatelessWidget {
  const _StoreAvatar({required this.store, this.onImageTap});

  final StoreChannel store;
  final VoidCallback? onImageTap;

  static const double _diameter = 52;

  @override
  Widget build(BuildContext context) {
    final cover = store.coverImageUrl.trim();
    final hasImage = cover.isNotEmpty;
    final initials = Text(
      store.initials,
      style: AppTextStyles.label(
        fontWeight: FontWeight.w700,
        color: AppColors.textOnPrimary,
      ),
    );

    final avatar =
        hasImage
            ? CatalogNetworkAvatar(
              url: cover,
              size: _diameter,
              backgroundColor: Color(store.avatarColor),
              fallback: initials,
            )
            : Container(
              width: _diameter,
              height: _diameter,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(store.avatarColor),
              ),
              child: initials,
            );

    if (onImageTap == null) return avatar;

    return GestureDetector(
      onTap: onImageTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          if (store.imageUrls.length > 1)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.background, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${store.imageUrls.length}',
                  style: AppTextStyles.caption(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnPrimary,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
