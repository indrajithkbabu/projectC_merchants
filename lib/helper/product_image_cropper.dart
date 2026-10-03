import 'package:flutter/material.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/widgets/product_image_editor_page.dart';

/// Shared product-photo editor (WhatsApp-style crop / text / draw).
///
/// Cancel / back on any step keeps that photo's original path so picking
/// is never blocked by the editor UI.
abstract final class ProductImageCropper {
  /// Open the editor for one image. Returns the edited file path, or `null`
  /// if cancelled / the source could not be resolved.
  static Future<String?> cropOne(
    String path, {
    required BuildContext context,
    String title = 'Edit photo',
  }) async {
    final source = path.trim();
    if (source.isEmpty) return null;
    if (!context.mounted) return null;

    final local = await ProductImagePaths.resolveLocalFile(source);
    if (local == null || !context.mounted) return null;

    final result = await Navigator.of(context).push<String>(
      PageRouteBuilder<String>(
        opaque: true,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) {
          return ProductImageEditorPage(
            filePath: local.path,
            title: title,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
    return result;
  }

  /// Sequential edit for a multi-photo (grouped) pick.
  ///
  /// Each cancel keeps that photo's original path; returns paths in the same
  /// order as [paths]. Empty input returns an empty list.
  static Future<List<String>> cropGroup(
    List<String> paths, {
    required BuildContext context,
  }) async {
    if (paths.isEmpty) return const [];
    if (!context.mounted) return List<String>.from(paths);

    if (paths.length == 1) {
      final edited = await cropOne(
        paths.first,
        context: context,
        title: 'Edit photo',
      );
      return [edited ?? paths.first];
    }

    final out = <String>[];
    for (var i = 0; i < paths.length; i++) {
      if (!context.mounted) {
        out.addAll(paths.skip(i));
        break;
      }
      final original = paths[i];
      final edited = await cropOne(
        original,
        context: context,
        title: 'Edit ${i + 1} of ${paths.length}',
      );
      out.add(edited ?? original);
    }
    return out;
  }
}
