import 'package:flutter/material.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/presentation/privacy/privacy_widgets/follow_requests_banner.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_profile_header_card.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_visitor_follow_bar.dart';
import 'package:share_plus/share_plus.dart';

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
    this.showBack = true,
    this.bottomInset = 0,
  });

  final StoreProfileState state;
  final VoidCallback onBack;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;
  /// Opens import-requests inbox (replaces former Edit store CTA).
  final VoidCallback onOpenImportRequests;
  final void Function(StoreProduct product) onProductTap;
  final ValueChanged<StoreProduct>? onProductLongPress;
  final VoidCallback? onOpenFollowRequests;
  /// When set (shell My store tab), shows a hamburger that opens Settings.
  final VoidCallback? onOpenSettings;
  /// Hide back when hosted as a shell tab (no stack to pop).
  final bool showBack;
  final double bottomInset;

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
    final link = state.storeLink.trim();
    final name = state.storeName.trim().isEmpty ? 'my store' : state.storeName;
    final message =
        link.isEmpty
            ? 'Check out $name on Jewel Flow.'
            : 'Check out $name on Jewel Flow: $link';
    await Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    final showBanner =
        state.showFollowRequestsBanner && onOpenFollowRequests != null;
    final products = state.products;
    final pendingImports = state.pendingImportRequestCount;

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
                        const SizedBox(height: 8),
                        StoreVisitorCountsRow(
                          productCount: state.productCount,
                          followerCount: state.followerCount,
                          followingCount: state.followingCount,
                          onFollowersTap: onFollowersTap,
                          onFollowingTap: onFollowingTap,
                          alignStart: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _GreyActionButton(
                      label:
                          pendingImports > 0
                              ? 'Import requests ($pendingImports)'
                              : 'Import requests',
                      onTap: onOpenImportRequests,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _GreyActionButton(
                      label: 'Share store',
                      onTap: () => _shareStore(context),
                    ),
                  ),
                ],
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
        if (state.isLoadingProducts && products.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            ),
          )
        else if (products.isEmpty)
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
                  final product = products[index];
                  return _MyStoreProductTile(
                    product: product,
                    onTap: () => onProductTap(product),
                    onLongPress:
                        onProductLongPress == null
                            ? null
                            : () => onProductLongPress!(product),
                  );
                },
                childCount: products.length,
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
  });

  final VoidCallback onBack;
  final bool showBack;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBack)
          AppBackButton(onPressed: onBack)
        else
          const SizedBox(width: 8),
        const Spacer(),
        if (onOpenSettings != null)
          IconButton(
            onPressed: onOpenSettings,
            tooltip: 'Settings',
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
    required this.onTap,
    this.onLongPress,
  });

  final StoreProduct product;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final url = product.primaryImagePath?.trim() ?? '';
    return Material(
      color: AppColors.surfaceSecondary,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child:
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
                  fit: BoxFit.cover,
                  error: Center(
                    child: Icon(
                      Icons.diamond_outlined,
                      color: AppColors.textHint,
                      size: 28,
                    ),
                  ),
                ),
      ),
    );
  }
}
