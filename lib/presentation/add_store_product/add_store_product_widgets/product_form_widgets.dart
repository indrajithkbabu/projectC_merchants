import 'package:flutter/material.dart';
import 'package:project_c/bloc/add_store_product/add_store_product_bloc.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';

class ProductPreviewImage extends StatelessWidget {
  const ProductPreviewImage({
    super.key,
    required this.item,
    this.onTap,
    this.imageCount = 1,
  });

  final GalleryImageItem? item;
  final VoidCallback? onTap;
  final int imageCount;

  @override
  Widget build(BuildContext context) {
    final path = item?.filePath;
    final hasImage =
        item != null &&
        !item!.isPlaceholder &&
        path != null &&
        ProductImagePaths.isDisplayable(path);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 88,
            height: 88,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surfaceSecondary,
                  AppColors.primary.withValues(alpha: 0.4),
                ],
              ),
            ),
            child:
                hasImage
                    ? ProductMediaImage(path: path)
                    : const Icon(
                      Icons.diamond_outlined,
                      size: 32,
                      color: AppColors.textOnPrimary,
                    ),
          ),
          if (imageCount > 1)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$imageCount',
                  style: AppTextStyles.caption(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ProductTagChip extends StatelessWidget {
  const ProductTagChip({
    super.key,
    required this.label,
    this.onRemove,
    this.onAdd,
    this.isSuggestion = false,
  });

  final String label;
  final VoidCallback? onRemove;
  final VoidCallback? onAdd;
  final bool isSuggestion;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSuggestion ? onAdd : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:
              isSuggestion
                  ? AppColors.surfaceSecondary
                  : AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSuggestion) ...[
              const Icon(Icons.add, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 2),
            ],
            Text(
              label,
              style: AppTextStyles.caption(
                fontWeight: FontWeight.w600,
                color:
                    isSuggestion ? AppColors.textSecondary : AppColors.primary,
              ),
            ),
            if (!isSuggestion && onRemove != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
