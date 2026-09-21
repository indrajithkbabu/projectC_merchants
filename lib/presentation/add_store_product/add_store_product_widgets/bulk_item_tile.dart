import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/models/bulk_upload.dart';

class BulkItemTile extends StatelessWidget {
  const BulkItemTile({
    super.key,
    required this.item,
    required this.selected,
    required this.selectMode,
    required this.onTap,
  });

  final BulkUploadItem item;
  final bool selected;
  final bool selectMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPrecise = item.tag == BulkItemTag.precise;

    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ProductMediaImage(path: item.imagePath),
            if (isPrecise)
              Positioned(
                top: selectMode ? null : 8,
                bottom: selectMode ? 8 : null,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                ),
              ),
            if (selectMode)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        selected ? AppColors.primary : AppColors.background,
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: 1.4,
                    ),
                  ),
                  child:
                      selected
                          ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: AppColors.textOnPrimary,
                          )
                          : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
