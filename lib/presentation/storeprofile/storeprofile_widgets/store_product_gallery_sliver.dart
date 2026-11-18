import 'package:flutter/material.dart';
import 'package:project_c/bloc/store_gallery/store_gallery_bloc.dart';
import 'package:project_c/helper/catalog_media_debug.dart';
import 'package:project_c/helper/catalog_responsive_image.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/product_view_mode.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_product_grid_shimmer.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/visitor_photo_selection_chrome.dart';

/// Light-theme gallery mosaic (store profile Gallery + channel Gallery tab).
///
/// Pinch columns (2…9) via [GalleryPinchHost] / parent. Paint role follows
/// [CatalogResponsiveImage.roleForMediaColumns] but **locks while pinching**
/// so mid-pinch does not flip thumbnail↔detail (Img High #4). Uses real
/// [SliverGrid]s (no nested `shrinkWrap` GridViews — UI-1).
class StoreProductGallerySliver extends StatefulWidget {
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
    this.productsResolved = true,
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

  /// False while disk/warm hydrate runs after process restart.
  final bool productsResolved;

  /// Continuous 2…9; painted as [columns.round] (Media-style).
  final double columns;
  final bool pinching;
  final String? focusProductId;
  final GlobalKey? focusKey;

  @override
  State<StoreProductGallerySliver> createState() =>
      _StoreProductGallerySliverState();
}

class _StoreProductGallerySliverState extends State<StoreProductGallerySliver> {
  /// Role at pinch start — held until release so URL tier does not thrash.
  CatalogImageRole? _lockedPaintRole;

  @override
  void didUpdateWidget(covariant StoreProductGallerySliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pinching && !oldWidget.pinching) {
      _lockedPaintRole = CatalogResponsiveImage.roleForMediaColumns(
        oldWidget.columns.round().clamp(2, 9),
      );
    } else if (!widget.pinching) {
      _lockedPaintRole = null;
    }
  }

  CatalogImageRole get _paintRole {
    final locked = _lockedPaintRole;
    if (widget.pinching && locked != null) return locked;
    return CatalogResponsiveImage.roleForMediaColumns(
      widget.columns.round().clamp(2, 9),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) {
      // Loading or disk hydrate — shimmer, never a blank hole.
      if (widget.isLoading || !widget.productsResolved) {
        return StoreProductGridShimmer(
          viewMode: ProductViewMode.gallery,
          galleryColumns: widget.columns.round().clamp(2, 9),
        );
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

    final crossAxisCount = widget.columns.round().clamp(2, 9);
    final paintRole = _paintRole;
    // Role picks URL tier; decode follows cell width (Img High #3).
    final decodeWidth = CatalogImageCache.cacheWidthForMediaColumns(
      crossAxisCount,
      screenWidth: MediaQuery.sizeOf(context).width,
    );
    final spacing = crossAxisCount >= 6 ? 1.0 : 2.0;

    final focusId = widget.focusProductId?.trim() ?? '';
    final sections = StoreGalleryState.buildSections(widget.products);
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
        final selected = widget.selectedIds.contains(product.id);
        final focused = focusId.isNotEmpty && product.id == focusId;

        if (!day.isSingleProduct) {
          slivers.add(
            SliverToBoxAdapter(
              child: Padding(
                key: focused ? widget.focusKey : null,
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
                    if (widget.selectionMode) _MiniCheck(isSelected: selected),
                  ],
                ),
              ),
            ),
          );
        } else if (widget.selectionMode) {
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

        final grid = SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
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
                      widget.selectedPhotoKeys.contains(photoKey);
                  return GestureDetector(
                    onTap:
                        widget.pinching
                            ? null
                            : () {
                              Rect? sourceRect;
                              final box = tileContext.findRenderObject();
                              if (box is RenderBox && box.hasSize) {
                                sourceRect =
                                    box.localToGlobal(Offset.zero) & box.size;
                              }
                              widget.onImageTap(
                                product,
                                index,
                                sourceRect: sourceRect,
                              );
                            },
                    onLongPress:
                        widget.pinching
                            ? null
                            : widget.onImageLongPress != null
                            ? () => widget.onImageLongPress!(product, index)
                            : widget.onProductLongPress == null
                            ? null
                            : () => widget.onProductLongPress!(product),
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
                          if (widget.photoSelectionMode)
                            Positioned(
                              top: 5,
                              right: 5,
                              child: TelegramPhotoSelectBadge(
                                selected: photoSelected,
                              ),
                            ),
                          if (widget.photoSelectionMode)
                            Positioned(
                              top:
                                  product.isImportDeclinedAt(index) ||
                                          product.isImportPendingAt(index)
                                      ? 28
                                      : 5,
                              left: 5,
                              right: 28,
                              child: VisitorImportStatusMarks(
                                locked: product.isLockedAt(index),
                                stock: product.stockStatusAt(index),
                                alreadyImported: product.isAlreadyImported,
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
            childCount: section.tileCount,
            addAutomaticKeepAlives: false,
          ),
        );

        slivers.add(
          SliverPadding(
            key: day.isSingleProduct && focused ? widget.focusKey : null,
            padding: EdgeInsets.zero,
            sliver:
                focused
                    ? DecoratedSliver(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.primary,
                          width: 2.5,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      sliver: grid,
                    )
                    : grid,
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
