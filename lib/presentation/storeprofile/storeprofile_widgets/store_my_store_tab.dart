import 'package:flutter/material.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/helper/catalog_responsive_image.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/merchant_profile_link.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/presentation/privacy/privacy_widgets/follow_requests_banner.dart';
import 'package:project_c/models/product_view_mode.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_product_grid_shimmer.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_profile_header_card.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_visitor_follow_bar.dart';
import 'package:share_plus/share_plus.dart';

/// One My-store mosaic cell (listing + absolute [imageIndex] in imagePaths).
class MyStorePhotoCell {
  const MyStorePhotoCell({required this.product, required this.imageIndex});

  final StoreProduct product;
  final int imageIndex;
}

/// Flatten every displayable frame across listings (cache-first albums).
///
/// Listings with no displayable frames are omitted (avoids empty ghost tiles
/// after deleting every item in a product). Pending uploads use their own
/// shimmer row, not this mosaic.
List<MyStorePhotoCell> myStorePhotoCells(List<StoreProduct> products) {
  final cells = <MyStorePhotoCell>[];
  for (final product in products) {
    final paths = product.imagePaths;
    for (var i = 0; i < paths.length; i++) {
      if (!ProductImagePaths.isDisplayable(paths[i])) continue;
      cells.add(MyStorePhotoCell(product: product, imageIndex: i));
    }
  }
  return cells;
}

/// Owner "My store" tab — Instagram-style profile (walkthrough screen 03).
class StoreMyStoreTab extends StatelessWidget {
  const StoreMyStoreTab({
    super.key,
    required this.state,
    required this.onBack,
    required this.onFollowersTap,
    required this.onFollowingTap,
    required this.onOpenImportRequests,
    required this.onProductTap,
    required this.onProductLongPress,
    this.onOpenFollowRequests,
    this.onOpenSettings,
    this.onOpenSwitcher,
    this.onOpenStaff,
    this.showSwitcherDot = false,
    this.roleBadge,
    this.canManageStore = true,
    this.showBack = true,
    this.bottomInset = 0,
    this.selectedProductIds = const {},
    this.selectedPhotoKeys = const {},
  });

  final StoreProfileState state;
  final VoidCallback onBack;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;
  /// Opens import-requests inbox (legacy / settings path).
  final VoidCallback onOpenImportRequests;
  final void Function(StoreProduct product, int imageIndex) onProductTap;
  /// Long-press a mosaic cell → `(product, imageIndex)` for item select.
  final void Function(StoreProduct product, int imageIndex)? onProductLongPress;
  final VoidCallback? onOpenFollowRequests;
  /// When set (shell My store tab), shows a hamburger that opens Settings/menu.
  final VoidCallback? onOpenSettings;
  /// Opens the profile switcher (name + chevron).
  final VoidCallback? onOpenSwitcher;
  /// Owner: opens Staff list (UI 4.3 / 5.2).
  final VoidCallback? onOpenStaff;
  final bool showSwitcherDot;
  /// Optional role pill under the store name (e.g. Staff / Owner).
  final String? roleBadge;
  /// When false (staff), hide owner management CTAs.
  final bool canManageStore;
  /// Hide back when hosted as a shell tab (no stack to pop).
  final bool showBack;
  final double bottomInset;
  /// Listing ids selected for multi-delete (legacy whole-product highlight).
  final Set<String> selectedProductIds;
  /// Photo keys `"listingId|imageIndex"` for per-item multi-delete.
  final Set<String> selectedPhotoKeys;

  static String photoKey(String productId, int imageIndex) =>
      '$productId|$imageIndex';

  String get _logoUrl {
    final cover = state.coverImageUrl.trim();
    if (cover.isNotEmpty) return cover;
    for (final photo in state.storeImages) {
      final url = photo.url.trim();
      if (url.isNotEmpty) return url;
    }
    return '';
  }

  Future<void> _shareStore(BuildContext context) async {
    final message = MerchantProfileLink.shareMessage(
      storeName: state.storeName.trim().isEmpty ? 'my store' : state.storeName,
      storeLinkOrSlug: state.storeLink,
    );
    await Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    final showBanner =
        state.showFollowRequestsBanner && onOpenFollowRequests != null;
    // Prefer enriched albums (full imagePaths); fall back to cover list.
    final products = state.productsForMedia;
    final photoCells = myStorePhotoCells(products);
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MyStoreToolbar(
                onBack: onBack,
                showBack: showBack,
                onOpenSettings: onOpenSettings,
                storeName: state.storeName,
                onOpenSwitcher: onOpenSwitcher,
                showSwitcherDot: showSwitcherDot,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _CircleStoreLogo(
                    size: 86,
                    imageUrl: _logoUrl,
                    storeName: state.storeName,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.storeName,
                          style: AppTextStyles.headline(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (roleBadge != null && roleBadge!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSecondary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  roleBadge!,
                                  style: AppTextStyles.caption(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  state.storeLink.trim().isEmpty
                                      ? ''
                                      : '@${state.storeLink.trim().split('/').last}',
                                  style: AppTextStyles.caption(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          StoreVisitorCountsRow(
                            productCount: photoCells.length,
                            followerCount: state.followerCount,
                            followingCount: state.followingCount,
                            onFollowersTap: onFollowersTap,
                            onFollowingTap: onFollowingTap,
                            alignStart: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (canManageStore)
                Row(
                  children: [
                    Expanded(
                      child: _GreyActionButton(
                        label: 'Edit store',
                        onTap: onOpenSettings ?? onOpenImportRequests,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _GreyActionButton(
                        label: 'Staff',
                        onTap: onOpenStaff ?? onOpenImportRequests,
                      ),
                    ),
                  ],
                )
              else
                _GreyActionButton(
                  label: 'Share store',
                  onTap: () => _shareStore(context),
                ),
              if (showBanner) ...[
                const SizedBox(height: 14),
                FollowRequestsBanner(
                  pendingCount: state.pendingFollowRequestCount,
                  previewNames: state.followRequestPreviewNames,
                  onTap: onOpenFollowRequests!,
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
        if (state.showProductGridShimmer)
          const StoreProductGridShimmer(
            viewMode: ProductViewMode.gallery,
            galleryColumns: 3,
            itemCount: 12,
          )
        else if (!state.productsResolved && photoCells.isEmpty)
          const SliverToBoxAdapter(child: SizedBox.shrink())
        else if (state.showProductGridEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'No products yet',
                  style: AppTextStyles.bodySecondary(),
                ),
              ),
            ),
          )
        else if (photoCells.isEmpty)
          const SliverToBoxAdapter(child: SizedBox.shrink())
        else
          SliverPadding(
            padding: EdgeInsets.only(bottom: bottomInset + 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final cell = photoCells[index];
                  final key = photoKey(cell.product.id, cell.imageIndex);
                  final selected =
                      selectedPhotoKeys.contains(key) ||
                      selectedProductIds.contains(cell.product.id);
                  return _MyStoreProductTile(
                    product: cell.product,
                    imageIndex: cell.imageIndex,
                    selected: selected,
                    onTap: () => onProductTap(cell.product, cell.imageIndex),
                    onLongPress:
                        onProductLongPress == null
                            ? null
                            : () => onProductLongPress!(
                              cell.product,
                              cell.imageIndex,
                            ),
                  );
                },
                childCount: photoCells.length,
              ),
            ),
          ),
      ],
    );
  }
}

/// Ensures store image is clipped to a circle (anti-aliased).
class _CircleStoreLogo extends StatelessWidget {
  const _CircleStoreLogo({
    required this.size,
    required this.imageUrl,
    required this.storeName,
  });

  final double size;
  final String imageUrl;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceSecondary,
      ),
      clipBehavior: Clip.antiAlias,
      child: StoreProfileLogo(
        size: size,
        imageUrl: imageUrl.isEmpty ? null : imageUrl,
        storeName: storeName,
      ),
    );
  }
}

class _MyStoreToolbar extends StatelessWidget {
  const _MyStoreToolbar({
    required this.onBack,
    this.showBack = true,
    this.onOpenSettings,
    this.storeName = '',
    this.onOpenSwitcher,
    this.showSwitcherDot = false,
  });

  final VoidCallback onBack;
  final bool showBack;
  final VoidCallback? onOpenSettings;
  final String storeName;
  final VoidCallback? onOpenSwitcher;
  final bool showSwitcherDot;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBack)
          AppBackButton(onPressed: onBack)
        else if (onOpenSwitcher != null)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpenSwitcher,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        storeName.trim().isEmpty ? 'Store' : storeName.trim(),
                        style: AppTextStyles.headline(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
                    if (showSwitcherDot) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        else
          const SizedBox(width: 8),
        if (onOpenSwitcher == null) const Spacer(),
        if (onOpenSettings != null)
          IconButton(
            onPressed: onOpenSettings,
            tooltip: 'Menu',
            icon: Icon(
              Icons.menu_rounded,
              color: AppColors.textPrimary,
              size: 24,
            ),
          ),
      ],
    );
  }
}

class _GreyActionButton extends StatelessWidget {
  const _GreyActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Material(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.label(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

class _MyStoreProductTile extends StatelessWidget {
  const _MyStoreProductTile({
    required this.product,
    required this.imageIndex,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
  });

  final StoreProduct product;
  final int imageIndex;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final safeIndex =
        imageIndex < 0
            ? 0
            : (imageIndex >= product.imagePaths.length ? 0 : imageIndex);
    final master =
        product.imagePaths.isEmpty
            ? ''
            : product.imagePaths[safeIndex].trim();
    final url =
        master.isEmpty
            ? ''
            : product.urlForRole(safeIndex, CatalogImageRole.grid);
    return Material(
      color: AppColors.surfaceSecondary,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            url.isEmpty
                ? Center(
                  child: Icon(
                    Icons.diamond_outlined,
                    color: AppColors.textHint,
                    size: 28,
                  ),
                )
                : ProductMediaImage(
                  path: url,
                  thumbhash: product.thumbhashAt(safeIndex),
                  fit: BoxFit.cover,
                  error: Center(
                    child: Icon(
                      Icons.diamond_outlined,
                      color: AppColors.textHint,
                      size: 28,
                    ),
                  ),
                ),
            if (selected)
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 2.5),
                  color: AppColors.primary.withValues(alpha: 0.18),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
