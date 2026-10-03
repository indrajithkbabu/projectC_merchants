import 'dart:io';

import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';

/// Telegram-style identity row: circular photo affordance + store name field.
class StoreSetupIdentityCard extends StatelessWidget {
  const StoreSetupIdentityCard({
    super.key,
    required this.controller,
    required this.onNameChanged,
    required this.imagePaths,
    required this.onPickImages,
    required this.onPreviewImages,
    this.isPickingImages = false,
    this.focusNode,
  });

  final TextEditingController controller;
  final ValueChanged<String> onNameChanged;
  final List<String> imagePaths;
  final VoidCallback onPickImages;
  final VoidCallback onPreviewImages;
  final bool isPickingImages;
  final FocusNode? focusNode;

  String? get _coverPath {
    if (imagePaths.isEmpty) return null;
    final path = imagePaths.first.trim();
    return path.isEmpty ? null : path;
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _coverPath != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _PhotoButton(
              coverPath: _coverPath,
              isLoading: isPickingImages,
              photoCount: imagePaths.length,
              onTap:
                  isPickingImages
                      ? null
                      : (hasPhoto ? onPreviewImages : onPickImages),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                onChanged: onNameChanged,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.words,
                style: AppTextStyles.body(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
                decoration: InputDecoration(
                  hintText: 'Store name',
                  hintStyle: AppTextStyles.hint(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.only(bottom: 10, top: 8),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
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

class _PhotoButton extends StatelessWidget {
  const _PhotoButton({
    required this.coverPath,
    required this.isLoading,
    required this.photoCount,
    required this.onTap,
  });

  final String? coverPath;
  final bool isLoading;
  final int photoCount;
  final VoidCallback? onTap;

  static const double _size = 64;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = coverPath != null;
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: _size,
                height: _size,
                child:
                    isLoading
                        ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.textOnPrimary,
                            ),
                          ),
                        )
                        : hasPhoto
                        ? Image.file(
                          File(coverPath!),
                          fit: BoxFit.cover,
                          width: _size,
                          height: _size,
                        )
                        : const Center(
                          child: Icon(
                            Icons.add_a_photo_rounded,
                            size: 28,
                            color: AppColors.textOnPrimary,
                          ),
                        ),
              ),
            ),
          ),
          if (hasPhoto && photoCount > 1)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20),
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.surface, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$photoCount',
                  style: AppTextStyles.caption(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnPrimary,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
