import 'package:flutter/material.dart';
import 'package:project_c/helper/app_shimmer.dart';
import 'package:project_c/models/product_view_mode.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_product_grid.dart';

/// Skeleton grid shown only on cold (uncached) store profile loads.
///
/// Matches the active [viewMode] layout (group / single / gallery).
class StoreProductGridShimmer extends StatefulWidget {
  const StoreProductGridShimmer({
    super.key,
    this.itemCount = 6,
    this.viewMode = ProductViewMode.group,
    this.galleryColumns = 4,
  });

  final int itemCount;
  final ProductViewMode viewMode;

  /// Used when [viewMode] is [ProductViewMode.gallery] (2…9).
  final int galleryColumns;

  @override
  State<StoreProductGridShimmer> createState() =>
      _StoreProductGridShimmerState();
}

class _StoreProductGridShimmerState extends State<StoreProductGridShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return switch (widget.viewMode) {
          ProductViewMode.gallery => _gallerySliver(t),
          ProductViewMode.single => SliverGrid(
            gridDelegate: StoreProductGrid.singleDelegate,
            delegate: SliverChildBuilderDelegate(
              (context, index) => ProductUploadShimmerCard(t: t),
              childCount: widget.itemCount.clamp(1, 4),
            ),
          ),
          ProductViewMode.group => SliverGrid(
            gridDelegate: StoreProductGrid.groupDelegate,
            delegate: SliverChildBuilderDelegate(
              (context, index) => ProductUploadShimmerCard(t: t),
              childCount: widget.itemCount,
            ),
          ),
        };
      },
    );
  }

  Widget _gallerySliver(double t) {
    final crossAxisCount = widget.galleryColumns.clamp(2, 9);
    final spacing = crossAxisCount >= 6 ? 1.0 : 2.0;
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => ProductUploadShimmerTile(t: t),
        childCount: widget.itemCount < 8 ? 12 : widget.itemCount,
      ),
    );
  }
}

/// Single shimmer card matching group/single product card proportions.
class ProductUploadShimmerCard extends StatelessWidget {
  const ProductUploadShimmerCard({super.key, required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: AppShimmer.gradient(t)),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Animated shimmer tile for gallery mosaic pending cells.
class ProductUploadShimmerTile extends StatelessWidget {
  const ProductUploadShimmerTile({super.key, required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppShimmer.base,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: AppShimmer.gradient(t)),
      ),
    );
  }
}
