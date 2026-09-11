import 'dart:io';

import 'package:flutter/material.dart';
import 'package:project_c/bloc/add_store_product/add_store_product_bloc.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';

class GalleryImageTile extends StatelessWidget {
  const GalleryImageTile({
    super.key,
    required this.item,
    required this.isSelected,
    required this.selectionOrder,
    required this.onTap,
  });

  final GalleryImageItem item;
  final bool isSelected;
  final int selectionOrder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Thumbnail(item: item),
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : AppColors.background,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 1.4,
                ),
              ),
              child:
                  isSelected
                      ? Text(
                        '$selectionOrder',
                        style: AppTextStyles.caption(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textOnPrimary,
                        ),
                      )
                      : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.item});

  final GalleryImageItem item;

  @override
  Widget build(BuildContext context) {
    if (!item.isPlaceholder && item.filePath != null) {
      return Image.file(
        File(item.filePath!),
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) => _PlaceholderThumb(tone: item.placeholderTone),
      );
    }
    return _PlaceholderThumb(tone: item.placeholderTone);
  }
}

class _PlaceholderThumb extends StatelessWidget {
  const _PlaceholderThumb({required this.tone});

  final int tone;

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      0 => [
        AppColors.surfaceSecondary,
        AppColors.primary.withValues(alpha: 0.35),
      ],
      1 => [
        AppColors.surfaceSecondary,
        AppColors.primaryDark.withValues(alpha: 0.32),
      ],
      2 => [
        AppColors.surfaceSecondary,
        AppColors.accent.withValues(alpha: 0.28),
      ],
      _ => [
        AppColors.surfaceSecondary,
        AppColors.success.withValues(alpha: 0.28),
      ],
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.diamond_outlined,
          size: 28,
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}
