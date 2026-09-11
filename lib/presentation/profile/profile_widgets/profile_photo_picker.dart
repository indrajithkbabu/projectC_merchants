import 'dart:io';

import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';

class ProfilePhotoPicker extends StatelessWidget {
  const ProfilePhotoPicker({
    super.key,
    required this.firstName,
    required this.imagePath,
    required this.isLoading,
    required this.onTap,
  });

  final String firstName;
  final String? imagePath;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.isNotEmpty;
    final trimmed = firstName.trim();
    final initial =
        trimmed.isEmpty ? 'A' : trimmed.substring(0, 1).toUpperCase();

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: isLoading ? null : onTap,
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceSecondary,
                image:
                    hasImage
                        ? DecorationImage(
                          image: FileImage(File(imagePath!)),
                          fit: BoxFit.cover,
                        )
                        : null,
              ),
              child:
                  hasImage
                      ? null
                      : Center(
                        child: Text(
                          initial,
                          style: AppTextStyles.headline(
                            fontSize: 40,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: GestureDetector(
              onTap: isLoading ? null : onTap,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 2),
                ),
                child:
                    isLoading
                        ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textOnPrimary,
                          ),
                        )
                        : const Icon(
                          Icons.camera_alt_rounded,
                          size: 18,
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
