import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_product_grid.dart';

/// Skeleton grid shown only on cold (uncached) store profile loads.
class StoreProductGridShimmer extends StatefulWidget {
  const StoreProductGridShimmer({super.key, this.itemCount = 6});

  final int itemCount;

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
        return SliverGrid(
          gridDelegate: StoreProductGrid.groupDelegate,
          delegate: SliverChildBuilderDelegate(
            (context, index) => ProductUploadShimmerCard(t: _controller.value),
            childCount: widget.itemCount,
          ),
        );
      },
    );
  }
}

/// Single shimmer card matching group/single product card proportions.
class ProductUploadShimmerCard extends StatelessWidget {
  const ProductUploadShimmerCard({super.key, required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final highlight = 0.35 + (0.35 * (1 - (2 * (t - 0.5).abs())));
    final base = AppColors.surfaceSecondary;
    final shine = Color.lerp(base, Colors.white, highlight)!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-1.2 + 2.4 * t, -0.4),
            end: Alignment(-0.2 + 2.4 * t, 0.6),
            colors: [base, shine, base],
            stops: const [0.25, 0.5, 0.75],
          ),
        ),
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
    final highlight = 0.35 + (0.35 * (1 - (2 * (t - 0.5).abs())));
    final base = AppColors.surfaceSecondary;
    final shine = Color.lerp(base, Colors.white, highlight)!;
    return ColoredBox(
      color: base,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-1.2 + 2.4 * t, -0.4),
            end: Alignment(-0.2 + 2.4 * t, 0.6),
            colors: [base, shine, base],
            stops: const [0.25, 0.5, 0.75],
          ),
        ),
      ),
    );
  }
}
