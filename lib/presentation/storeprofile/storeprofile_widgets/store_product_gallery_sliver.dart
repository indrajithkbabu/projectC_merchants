import 'package:flutter/material.dart';
import 'package:project_c/bloc/store_gallery/store_gallery_bloc.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_product_grid_shimmer.dart';

/// Light-theme gallery mosaic embedded in store profile (view-mode: gallery).
class StoreProductGallerySliver extends StatelessWidget {
  const StoreProductGallerySliver({
    super.key,
    required this.products,
    required this.onImageTap,
    this.onProductLongPress,
    this.selectionMode = false,
    this.selectedIds = const {},
    this.isLoading = false,
    this.crossAxisCount = 4,
    this.focusProductId,
    this.focusKey,
  });

  final List<StoreProduct> products;
  final void Function(StoreProduct product, int imageIndex) onImageTap;
  final ValueChanged<StoreProduct>? onProductLongPress;
  final bool selectionMode;
  final Set<String> selectedIds;
  final bool isLoading;
  final int crossAxisCount;
  final String? focusProductId;
  final GlobalKey? focusKey;

  @override
  Widget build(BuildContext context) {
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

    final focusId = focusProductId?.trim() ?? '';
    final sections = StoreGalleryState.buildSections(products);
    final slivers = <Widget>[];

    for (var dayIndex = 0; dayIndex < sections.length; dayIndex++) {
      final day = sections[dayIndex];
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Text(
              day.isSingleProduct
                  ? '${day.label}  |  ${day.products.first.product.title}'
                  : day.label,
              style: AppTextStyles.headline(fontSize: 16),
            ),
          ),
        ),
      );

      for (var i = 0; i < day.products.length; i++) {
        final section = day.products[i];
        final product = section.product;
        final selected = selectedIds.contains(product.id);
        final focused = focusId.isNotEmpty && product.id == focusId;

        if (!day.isSingleProduct) {
          slivers.add(
            SliverToBoxAdapter(
              child: Padding(
                key: focused ? focusKey : null,
                padding: EdgeInsets.only(top: i == 0 ? 0 : 14, bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.title,
                        style: AppTextStyles.body(
                          fontWeight: FontWeight.w600,
                          color:
                              focused
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (selectionMode) _MiniCheck(isSelected: selected),
                  ],
                ),
              ),
            ),
          );
        } else if (selectionMode) {
          slivers.add(
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _MiniCheck(isSelected: selected),
                ),
              ),
            ),
          );
        }

        slivers.add(
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: day.isSingleProduct && focused ? focusKey : null,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border:
                      focused
                          ? Border.all(color: AppColors.primary, width: 2.5)
                          : null,
                  borderRadius: focused ? BorderRadius.circular(4) : null,
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  itemCount: section.tileCount,
                  itemBuilder: (context, index) {
                    final path =
                        section.imagePaths.isEmpty
                            ? null
                            : section.imagePaths[index];
                    return GestureDetector(
                      onTap: () => onImageTap(product, index),
                      onLongPress:
                          onProductLongPress == null
                              ? null
                              : () => onProductLongPress!(product),
                      child: ColoredBox(
                        color: AppColors.surfaceSecondary,
                        child: _tileImage(path, product.toneIndex),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      }

      if (dayIndex < sections.length - 1) {
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 8)));
      }
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));
    return SliverMainAxisGroup(slivers: slivers);
  }

  Widget _tileImage(String? path, int tone) {
    if (path == null ||
        path.isEmpty ||
        !ProductImagePaths.isDisplayable(path)) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surfaceSecondary,
              AppColors.primary.withValues(alpha: 0.35),
            ],
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.diamond_outlined,
            size: 16,
            color: AppColors.textOnPrimary,
          ),
        ),
      );
    }
    return ProductMediaImage(path: path);
  }
}

class _MiniCheck extends StatelessWidget {
  const _MiniCheck({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppColors.primary : AppColors.surfaceSecondary,
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: 1.5,
        ),
      ),
      child:
          isSelected
              ? const Icon(
                Icons.check_rounded,
                size: 14,
                color: AppColors.textOnPrimary,
              )
              : null,
    );
  }
}
