import 'dart:io';

import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';

class ProfilePhotoPicker extends StatelessWidget {
  const ProfilePhotoPicker({
    super.key,
    required this.firstName,
    required this.isLoading,
    required this.onTap,
    this.imagePath,
    this.imageUrl,
  });

  final String firstName;
  final String? imagePath;
  final String? imageUrl;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final localPath = imagePath?.trim() ?? '';
    final networkUrl = imageUrl?.trim() ?? '';
    final hasLocal = localPath.isNotEmpty;
    final hasNetwork = !hasLocal && networkUrl.isNotEmpty;
    final trimmed = firstName.trim();
    final initial =
        trimmed.isEmpty ? 'A' : trimmed.substring(0, 1).toUpperCase();
    final initials = Text(
      initial,
      style: AppTextStyles.headline(
        fontSize: 40,
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
    );

    const size = 104.0;
    final Widget photo;
    if (hasLocal) {
      photo = ClipOval(
        child: Image.file(
          File(localPath),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _fallbackShell(initials),
        ),
      );
    } else if (hasNetwork) {
      photo = CatalogNetworkAvatar(
        url: networkUrl,
        size: size,
        backgroundColor: AppColors.surfaceSecondary,
        fallback: initials,
      );
    } else {
      photo = _fallbackShell(initials);
    }

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: isLoading ? null : onTap,
            child: photo,
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
                        ? Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textOnPrimary,
                          ),
                        )
                        : Icon(
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

  Widget _fallbackShell(Widget child) {
    return Container(
      width: 104,
      height: 104,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceSecondary,
      ),
      child: child,
    );
  }
}
