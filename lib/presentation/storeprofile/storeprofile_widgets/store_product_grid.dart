import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/catalog/import_models.dart';
import 'package:project_c/models/product_view_mode.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/product_image_collage.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_product_grid_shimmer.dart';

class StoreProductGrid extends StatelessWidget {
  const StoreProductGrid({
    super.key,
    required this.products,
    required this.onProductTap,
    this.onProductLongPress,
    this.viewMode = ProductViewMode.group,
    this.selectionMode = false,
    this.selectedIds = const {},
    this.deletingProductIds = const {},
    this.listingAvailability = const {},
    this.focusProductId,
    this.focusKey,
  });

  final List<StoreProduct> products;

  /// Second arg is the tapped collage photo index (0 when the card has no
  /// images or the tap was outside a collage cell).
  final void Function(StoreProduct product, int imageIndex) onProductTap;
  final ValueChanged<StoreProduct>? onProductLongPress;
  final ProductViewMode viewMode;
  final bool selectionMode;
  final Set<String> selectedIds;
  final Set<String> deletingProductIds;
  final Map<String, ListingImportAvailability> listingAvailability;

  /// Listing id to draw a primary border around (e.g. search → store chevron).
  final String? focusProductId;

  /// Optional key attached to the focused card for scroll-into-view.
  final GlobalKey? focusKey;

  static const groupDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    childAspectRatio: 0.86,
  );

  static const singleDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 1,
    crossAxisSpacing: 10,
    mainAxisSpacing: 12,
    // width/height — lower = taller portrait card (full-width rectangle).
    childAspectRatio: 0.8,
  );

  SliverGridDelegate get _delegate =>
      viewMode == ProductViewMode.single ? singleDelegate : groupDelegate;

  Widget _card(StoreProduct product) {
    final selected = selectedIds.contains(product.id);
    final focused =
        focusProductId != null &&
        focusProductId!.isNotEmpty &&
        product.id == focusProductId;
    return GestureDetector(
      // Fallback when there are no collage cells (empty product) or the tap
      // lands on chrome overlays; collage cells report their own index.
      onTap: () => onProductTap(product, 0),
      onLongPress:
          onProductLongPress == null
              ? null
              : () => onProductLongPress!(product),
      child: KeyedSubtree(
        key: focused ? focusKey : null,
        child: _ProductCard(
          key: ValueKey(product.id),
          product: product,
          selectionMode: selectionMode,
          isSelected: selected,
          isFocused: focused,
          isDeleting: deletingProductIds.contains(product.id),
          availability: listingAvailability[product.id],
          large: viewMode == ProductViewMode.single,
          onImageTap:
              selectionMode
                  ? null
                  : (imageIndex) => onProductTap(product, imageIndex),
        ),
      ),
    );
  }

  Widget buildSliver({bool isLoading = false}) {
    if (products.isEmpty) {
      if (isLoading) {
        return const StoreProductGridShimmer();
      }
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            'No products yet',
            style: AppTextStyles.bodySecondary(),
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: _delegate,
      delegate: SliverChildBuilderDelegate(
        (context, index) => _card(products[index]),
        childCount: products.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Text(
          'No products yet',
          style: AppTextStyles.bodySecondary(),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: false,
      physics: const BouncingScrollPhysics(),
      itemCount: products.length,
      gridDelegate: _delegate,
      itemBuilder: (context, index) => _card(products[index]),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    super.key,
    required this.product,
    this.selectionMode = false,
    this.isSelected = false,
    this.isFocused = false,
    this.isDeleting = false,
    this.availability,
    this.large = false,
    this.onImageTap,
  });

  final StoreProduct product;
  final bool selectionMode;
  final bool isSelected;
  final bool isFocused;
  final bool isDeleting;
  final ListingImportAvailability? availability;
  final bool large;
  final ValueChanged<int>? onImageTap;

  String? get _statusLabel => switch (availability) {
    ListingImportAvailability.alreadyAdded => 'Added',
    ListingImportAvailability.pending => 'Pending',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final gradient = _toneGradient(product.toneIndex);
    final allPaths = product.imagePaths;
    final displayCells = <({int index, String path})>[
      for (var i = 0; i < allPaths.length; i++)
        if (ProductImagePaths.isDisplayable(allPaths[i]))
          (index: i, path: allPaths[i]),
    ];
    final existingPaths =
        displayCells.map((c) => c.path).toList(growable: false);
    final hasImages = existingPaths.isNotEmpty;
    final status = _statusLabel;
    final showPrimaryBorder =
        (selectionMode && isSelected) || (!selectionMode && isFocused);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border:
            showPrimaryBorder
                ? Border.all(color: AppColors.primary, width: 2.5)
                : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(showPrimaryBorder ? 12 : 14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
              ),
            ),
            if (hasImages)
              ProductImageCollage(
                imagePaths: existingPaths,
                imageThumbhashes: product.imageThumbhashes,
                onImageTap:
                    onImageTap == null
                        ? null
                        : (displayIndex) {
                          if (displayIndex < 0 ||
                              displayIndex >= displayCells.length) {
                            onImageTap!(0);
                            return;
                          }
                          onImageTap!(displayCells[displayIndex].index);
                        },
              )
            else
              Center(
                child: Icon(
                  Icons.diamond_outlined,
                  size: large ? 48 : 34,
                  color: AppColors.textOnPrimary,
                ),
              ),
            // Let collage cells win hit-testing when per-image taps are wired.
            IgnorePointer(
              ignoring: onImageTap != null,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.4),
                    ],
                    stops: const [0.45, 1],
                  ),
                ),
              ),
            ),
            IgnorePointer(
              ignoring: onImageTap != null,
              child: Padding(
                padding: EdgeInsets.all(large ? 14 : 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (selectionMode)
                      Align(
                        alignment: Alignment.topRight,
                        child: _SelectionCheck(
                          isSelected: isSelected,
                          isDeleting: isDeleting,
                        ),
                      )
                    else if (status != null)
                      Align(
                        alignment: Alignment.topRight,
                        child: _ImportStatusChip(label: status),
                      ),
                    const Spacer(),
                    Text(
                      product.title,
                      maxLines: large ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(
                        fontSize: large ? 20 : 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                    // Tags / meta under title intentionally hidden.
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

class _SelectionCheck extends StatelessWidget {
  const _SelectionCheck({
    required this.isSelected,
    required this.isDeleting,
  });

  final bool isSelected;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    if (isDeleting) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.textOnPrimary,
        ),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppColors.primary : Colors.black.withValues(alpha: 0.35),
        border: Border.all(color: AppColors.textOnPrimary, width: 1.5),
      ),
      child:
          isSelected
              ? const Icon(
                Icons.check_rounded,
                size: 16,
                color: AppColors.textOnPrimary,
              )
              : null,
    );
  }
}

class _ImportStatusChip extends StatelessWidget {
  const _ImportStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}

List<Color> _toneGradient(int tone) {
  return switch (tone % 4) {
    0 => [
      AppColors.surfaceSecondary,
      AppColors.primary.withValues(alpha: 0.45),
    ],
    1 => [
      AppColors.surfaceSecondary,
      AppColors.primaryDark.withValues(alpha: 0.42),
    ],
    2 => [AppColors.surfaceSecondary, AppColors.accent.withValues(alpha: 0.35)],
    _ => [
      AppColors.surfaceSecondary,
      AppColors.success.withValues(alpha: 0.38),
    ],
  };
}
