import 'dart:io';

import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';

/// Shared helpers for product/collection media (local path or remote URL).
class ProductImagePaths {
  ProductImagePaths._();

  static bool isNetwork(String path) {
    final value = path.trim();
    return value.startsWith('http://') || value.startsWith('https://');
  }

  static bool isDisplayable(String path) {
    final value = path.trim();
    if (value.isEmpty) return false;
    if (isNetwork(value)) return true;
    return File(value).existsSync();
  }

  static List<String> displayable(List<String> paths) {
    return paths.where(isDisplayable).toList(growable: false);
  }

  static ImageProvider? provider(String path) {
    final value = path.trim();
    if (value.isEmpty) return null;
    if (isNetwork(value)) return NetworkImage(value);
    final file = File(value);
    if (!file.existsSync()) return null;
    return FileImage(file);
  }
}

/// Renders a local file or remote URL with a consistent broken-image fallback.
class ProductMediaImage extends StatelessWidget {
  const ProductMediaImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.error,
  });

  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? error;

  @override
  Widget build(BuildContext context) {
    final value = path.trim();
    if (value.isEmpty) return error ?? _broken();

    if (ProductImagePaths.isNetwork(value)) {
      return Image.network(
        value,
        fit: fit,
        width: width ?? double.infinity,
        height: height ?? double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => error ?? _broken(),
      );
    }

    final file = File(value);
    if (!file.existsSync()) return error ?? _broken();

    return Image.file(
      file,
      fit: fit,
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => error ?? _broken(),
    );
  }

  static Widget _broken() {
    return const ColoredBox(
      color: AppColors.surfaceSecondary,
      child: Icon(
        Icons.broken_image_outlined,
        color: AppColors.textSecondary,
      ),
    );
  }
}
