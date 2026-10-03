import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/presentation/search/search_models.dart';
import 'package:project_c/presentation/search/search_widgets/search_shimmers.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/product_image_collage.dart';

class SearchResultCard extends StatelessWidget {
  const SearchResultCard({
    super.key,
    required this.product,
    required this.onTap,
    this.showStoreLine = true,
  });

  final SearchProductResult product;
  final VoidCallback onTap;
  final bool showStoreLine;

  @override
  Widget build(BuildContext context) {
    final paths = ProductImagePaths.displayable(product.imagePaths);
    final hasImages = paths.isNotEmpty;
    final chips = <String>[
      if (product.weightChip.isNotEmpty) product.weightChip,
      if (product.purityChip.isNotEmpty) product.purityChip,
      if (product.wastageChip.isNotEmpty) product.wastageChip,
      if (product.sizeLabel.isNotEmpty) product.sizeLabel,
    ];

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _toneGradient(product.toneIndex),
                      ),
                    ),
                  ),
                  if (hasImages)
                    ProductImageCollage(imagePaths: paths)
                  else
                    const Center(
                      child: Icon(
                        Icons.diamond_outlined,
                        size: 34,
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  if (product.categoryLabel.isNotEmpty)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product.categoryLabel,
                          style: AppTextStyles.caption(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textOnPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (showStoreLine) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: product.storeMarkColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    product.storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (product.city.isNotEmpty)
              Text(
                product.city,
                style: AppTextStyles.caption(fontSize: 11),
              ),
          ],
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [for (final label in chips) _SpecChip(label)],
            ),
          ],
        ],
      ),
    );
  }

  static List<Color> _toneGradient(int toneIndex) {
    const tones = <List<Color>>[
      [Color(0xFF6B8CAD), Color(0xFF3D5A80)],
      [Color(0xFFC9A227), Color(0xFF8B6914)],
      [Color(0xFF7A9E7E), Color(0xFF3D5C40)],
      [Color(0xFFB07D62), Color(0xFF6B4423)],
      [Color(0xFF8E7CC3), Color(0xFF5B4B8A)],
      [Color(0xFF5DADE2), Color(0xFF2874A6)],
    ];
    return tones[toneIndex.abs() % tones.length];
  }
}

class _SpecChip extends StatelessWidget {
  const _SpecChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class SearchResultsGrid extends StatelessWidget {
  const SearchResultsGrid({
    super.key,
    required this.products,
    required this.onProductTap,
    this.showStoreLine = true,
    this.padding = EdgeInsets.zero,
    this.onLoadMore,
    this.isLoadingMore = false,
    this.controller,
  });

  final List<SearchProductResult> products;
  final ValueChanged<SearchProductResult> onProductTap;
  final bool showStoreLine;
  final EdgeInsets padding;
  final VoidCallback? onLoadMore;
  final bool isLoadingMore;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Text(
          'No products match',
          style: AppTextStyles.bodySecondary(),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (onLoadMore == null || isLoadingMore) return false;
        if (notification.metrics.pixels <
            notification.metrics.maxScrollExtent - 240) {
          return false;
        }
        onLoadMore!();
        return false;
      },
      child: GridView.builder(
        controller: controller,
        padding: padding,
        itemCount: products.length + (isLoadingMore ? 1 : 0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 14,
          childAspectRatio: 0.58,
        ),
        itemBuilder: (context, index) {
          if (index >= products.length) {
            return SearchResultCardShimmer(showStoreLine: showStoreLine);
          }
          final product = products[index];
          return SearchResultCard(
            product: product,
            showStoreLine: showStoreLine,
            onTap: () => onProductTap(product),
          );
        },
      ),
    );
  }
}
