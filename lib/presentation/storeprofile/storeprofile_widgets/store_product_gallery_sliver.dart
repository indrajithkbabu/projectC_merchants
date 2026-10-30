import 'package:flutter/material.dart';
import 'package:project_c/bloc/store_gallery/store_gallery_bloc.dart';
import 'package:project_c/helper/catalog_media_debug.dart';
import 'package:project_c/helper/catalog_responsive_image.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_product_grid_shimmer.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/visitor_photo_selection_chrome.dart';

/// Light-theme gallery mosaic (store profile Gallery + channel Gallery tab).
///
/// Pinch columns (2…9) via [GalleryPinchHost] / parent; quality follows the
/// same ladder as channel Media (`roleForMediaColumns`).
class StoreProductGallerySliver extends StatelessWidget {
  const StoreProductGallerySliver({
    super.key,
    required this.products,
    required this.onImageTap,
    this.onProductLongPress,
    this.onImageLongPress,
    this.selectionMode = false,
    this.photoSelectionMode = false,
    this.selectedIds = const {},
    this.selectedPhotoKeys = const {},
    this.isLoading = false,
    this.columns = 4,
    this.pinching = false,
    this.focusProductId,
    this.focusKey,
  });

  final List<StoreProduct> products;
  final void Function(
    StoreProduct product,
    int imageIndex, {
    Rect? sourceRect,
  })
  onImageTap;
  final ValueChanged<StoreProduct>? onProductLongPress;
  final void Function(StoreProduct product, int imageIndex)? onImageLongPress;
  final bool selectionMode;
  final bool photoSelectionMode;
  final Set<String> selectedIds;
  final Set<String> selectedPhotoKeys;
  final bool isLoading;

  /// Continuous 2…9; painted as [columns.round] (Media-style).
  final double columns;
  final bool pinching;
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

    final crossAxisCount = columns.round().clamp(2, 9);
    final paintRole =
        CatalogResponsiveImage.roleForMediaColumns(crossAxisCount);
    final decodeWidth = CatalogImageCache.cacheWidthForRole(paintRole);
    final spacing = crossAxisCount >= 6 ? 1.0 : 2.0;

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
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                  ),
                  itemCount: section.tileCount,
                  itemBuilder: (context, index) {
                    final path =
                        section.imagePaths.isEmpty
                            ? null
                            : product.urlForRole(
                              index,
                              paintRole,
                              log: index == 0 && dayIndex == 0,
                            );
                    if (index == 0 &&
                        dayIndex == 0 &&
                        path != null &&
                        path.isNotEmpty) {
                      CatalogMediaDebug.qualityMediaPaint(
                        columns: crossAxisCount,
                        role: paintRole,
                        sampleUrl: path,
                      );
                    }
                    return Builder(
                      builder: (tileContext) {
                        final photoKey = '${product.id}|$index';
                        final photoSelected =
                            selectedPhotoKeys.contains(photoKey);
                        return GestureDetector(
                          onTap:
                              pinching
                                  ? null
                                  : () {
                                    Rect? sourceRect;
                                    final box = tileContext.findRenderObject();
                                    if (box is RenderBox && box.hasSize) {
                                      sourceRect =
                                          box.localToGlobal(Offset.zero) &
                                          box.size;
                                    }
                                    onImageTap(
                                      product,
                                      index,
                                      sourceRect: sourceRect,
                                    );
                                  },
                          onLongPress:
                              pinching
                                  ? null
                                  : onImageLongPress != null
                                  ? () => onImageLongPress!(product, index)
                                  : onProductLongPress == null
                                  ? null
                                  : () => onProductLongPress!(product),
                          child: ColoredBox(
                            color: AppColors.surfaceSecondary,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _tileImage(
                                  path,
                                  product.toneIndex,
                                  product.thumbhashAt(index),
                                  decodeWidth,
                                ),
                                if (product.isImportDeclinedAt(index) ||
                                    product.isImportPendingAt(index))
                                  Positioned(
                                    top: 5,
                                    left: 5,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            product.isImportDeclinedAt(index)
                                                ? AppColors.error.withValues(
                                                  alpha: 0.92,
                                                )
                                                : AppColors.warning.withValues(
                                                  alpha: 0.92,
                                                ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        product.isImportDeclinedAt(index)
                                            ? 'Declined'
                                            : 'Pending',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.caption(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (photoSelectionMode)
                                  Positioned(
                                    top: 5,
                                    right: 5,
                                    child: TelegramPhotoSelectBadge(
                                      selected: photoSelected,
                                    ),
                                  ),
                                if (photoSelectionMode)
                                  Positioned(
                                    top:
                                        product.isImportDeclinedAt(index) ||
                                                product.isImportPendingAt(
                                                  index,
                                                )
                                            ? 28
                                            : 5,
                                    left: 5,
                                    right: 28,
                                    child: VisitorImportStatusMarks(
                                      locked: product.isLockedAt(index),
                                      stock: product.stockStatusAt(index),
                                      alreadyImported:
                                          product.isAlreadyImported,
                                      selectionBlocked:
                                          product.importSelectionBlocked,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
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

    // No trailing bottom spacer — images sit flush with the viewport edge.
    return SliverMainAxisGroup(slivers: slivers);
  }

  Widget _tileImage(
    String? path,
    int tone,
    String? thumbhash,
    int decodeWidth,
  ) {
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
        child: Center(
          child: Icon(
            Icons.diamond_outlined,
            size: 16,
            color: AppColors.textOnPrimary,
          ),
        ),
      );
    }
    return ProductMediaImage(
      path: path,
      thumbhash: thumbhash,
      decodeCacheWidth: decodeWidth,
    );
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
              ? Icon(
                Icons.check_rounded,
                size: 14,
                color: AppColors.textOnPrimary,
              )
              : null,
    );
  }
}
