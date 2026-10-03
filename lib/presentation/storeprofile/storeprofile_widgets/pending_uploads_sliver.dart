import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/pending_product_upload.dart';
import 'package:project_c/models/product_view_mode.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_product_grid.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_product_grid_shimmer.dart';

/// Shimmer placeholders for in-flight create uploads (existing products stay).
class PendingUploadsSliver extends StatefulWidget {
  const PendingUploadsSliver({
    super.key,
    required this.pending,
    required this.viewMode,
    this.galleryCrossAxisCount = 4,
  });

  final List<PendingProductUpload> pending;
  final ProductViewMode viewMode;
  final int galleryCrossAxisCount;

  @override
  State<PendingUploadsSliver> createState() => _PendingUploadsSliverState();
}

class _PendingUploadsSliverState extends State<PendingUploadsSliver>
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
    if (widget.pending.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return switch (widget.viewMode) {
          ProductViewMode.gallery => _gallerySliver(t),
          ProductViewMode.single ||
          ProductViewMode.group => _gridSliver(t),
        };
      },
    );
  }

  Widget _gridSliver(double t) {
    final delegate =
        widget.viewMode == ProductViewMode.single
            ? StoreProductGrid.singleDelegate
            : StoreProductGrid.groupDelegate;
    return SliverGrid(
      gridDelegate: delegate,
      delegate: SliverChildBuilderDelegate(
        (context, index) => ProductUploadShimmerCard(t: t),
        childCount: widget.pending.length,
      ),
    );
  }

  Widget _gallerySliver(double t) {
    final slivers = <Widget>[];
    for (final pending in widget.pending) {
      final count = pending.photoCount < 1 ? 1 : pending.photoCount;
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Text(
              pending.title.trim().isEmpty ? 'Uploading…' : pending.title,
              style: AppTextStyles.headline(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
      slivers.add(
        SliverToBoxAdapter(
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.galleryCrossAxisCount,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: count,
            itemBuilder: (context, index) => ProductUploadShimmerTile(t: t),
          ),
        ),
      );
    }
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 8)));
    return SliverMainAxisGroup(slivers: slivers);
  }
}
