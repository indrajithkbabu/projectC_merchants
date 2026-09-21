import 'dart:io';

import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/webservice/store/store_request.dart';

/// Horizontal strip for picking up to [StoreRequest.maxStoreImages] showcase photos.
class StoreImagesPickerStrip extends StatelessWidget {
  const StoreImagesPickerStrip({
    super.key,
    required this.imagePaths,
    required this.onAdd,
    required this.onRemoveAt,
    this.maxImages = StoreRequest.maxStoreImages,
  });

  final List<String> imagePaths;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemoveAt;
  final int maxImages;

  static const _tile = 88.0;

  @override
  Widget build(BuildContext context) {
    final canAdd = imagePaths.length < maxImages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Store photos (optional)',
          style: AppTextStyles.body(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Add up to $maxImages showcase photos of your storefront.',
          style: AppTextStyles.caption(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: _tile,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            primary: false,
            itemCount: imagePaths.length + (canAdd ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (canAdd && index == imagePaths.length) {
                return _AddTile(size: _tile, onTap: onAdd);
              }
              return _ImageTile(
                size: _tile,
                path: imagePaths[index],
                onRemove: () => onRemoveAt(index),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: size,
          height: size,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_photo_alternate_outlined,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                'Add',
                style: AppTextStyles.caption(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.size,
    required this.path,
    required this.onRemove,
  });

  final double size;
  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    // Delete control sits inside the tile (same inset for 1 or 5 photos)
    // so ListView clipping never shifts/hides it.
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(path), fit: BoxFit.cover),
            Positioned(
              top: 6,
              right: 6,
              child: Material(
                color: Colors.black.withValues(alpha: 0.45),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onRemove,
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 26,
                    height: 26,
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
