import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/product_image_collage.dart';

class StoreProductGrid extends StatelessWidget {
  const StoreProductGrid({
    super.key,
    required this.products,
    required this.onProductTap,
    this.onProductDelete,
    this.deletingProductId,
  });

  final List<StoreProduct> products;
  final ValueChanged<StoreProduct> onProductTap;
  final ValueChanged<StoreProduct>? onProductDelete;
  final String? deletingProductId;

  static const sliverDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    childAspectRatio: 0.86,
  );

  Widget _card(StoreProduct product) {
    return GestureDetector(
      onTap: () => onProductTap(product),
      child: _ProductCard(
        product: product,
        showDelete: onProductDelete != null,
        isDeleting: deletingProductId == product.id,
        onDelete:
            onProductDelete == null ? null : () => onProductDelete!(product),
      ),
    );
  }

  Widget buildSliver() {
    if (products.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text('No products yet', style: AppTextStyles.bodySecondary()),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: sliverDelegate,
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
        child: Text('No products yet', style: AppTextStyles.bodySecondary()),
      );
    }

    return GridView.builder(
      shrinkWrap: false,
      physics: const BouncingScrollPhysics(),
      itemCount: products.length,
      gridDelegate: sliverDelegate,
      itemBuilder: (context, index) => _card(products[index]),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    this.showDelete = false,
    this.isDeleting = false,
    this.onDelete,
  });

  final StoreProduct product;
  final bool showDelete;
  final bool isDeleting;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final gradient = _toneGradient(product.toneIndex);
    final existingPaths = ProductImagePaths.displayable(product.imagePaths);
    final hasImages = existingPaths.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
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
            ProductImageCollage(imagePaths: existingPaths)
          else
            const Center(
              child: Icon(
                Icons.diamond_outlined,
                size: 34,
                color: AppColors.textOnPrimary,
              ),
            ),
          DecoratedBox(
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
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showDelete)
                  Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: isDeleting ? null : onDelete,
                      child: _ProductCloseButton(
                        isDeleting: isDeleting,
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  product.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  product.meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(
                    fontSize: 13,
                    color: AppColors.textOnPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCloseButton extends StatelessWidget {
  const _ProductCloseButton({required this.isDeleting});

  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child:
              isDeleting
                  ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textOnPrimary,
                    ),
                  )
                  : const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textOnPrimary,
                  ),
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
