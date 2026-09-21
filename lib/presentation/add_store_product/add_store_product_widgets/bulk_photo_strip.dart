import 'package:flutter/material.dart';
import 'package:project_c/helper/product_image.dart';

/// Horizontal thumbnail strip for bulk upload (local or network paths).
class BulkPhotoStrip extends StatelessWidget {
  const BulkPhotoStrip({
    super.key,
    required this.paths,
    this.height = 72,
    this.onTap,
  });

  final List<String> paths;
  final double height;

  /// Called with the tapped photo index in the displayable path list.
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final displayable = ProductImagePaths.displayable(paths);
    if (displayable.isEmpty) return const SizedBox.shrink();

    // Always allow horizontal scroll — thumbs can overflow the viewport even
    // with fewer than 8 photos (narrow screens / padding). Nested inside a
    // vertical scroll view, a fixed height + primary:false keeps gestures OK.
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        primary: false,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: displayable.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final thumb = ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: height,
              height: height,
              child: ProductMediaImage(path: displayable[index]),
            ),
          );
          if (onTap == null) return thumb;
          return GestureDetector(
            onTap: () => onTap!(index),
            child: thumb,
          );
        },
      ),
    );
  }
}
