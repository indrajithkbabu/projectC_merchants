import 'package:flutter/material.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';

/// Skeleton list matching [StoreListingTile] row layout (avatar + title lines).
class StoreListingShimmer extends StatefulWidget {
  const StoreListingShimmer({
    super.key,
    this.itemCount = 8,
    this.padding,
  });

  final int itemCount;
  final EdgeInsetsGeometry? padding;

  @override
  State<StoreListingShimmer> createState() => _StoreListingShimmerState();
}

class _StoreListingShimmerState extends State<StoreListingShimmer>
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
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: widget.padding ?? AppPadding.screen(top: 8, bottom: 24),
          itemCount: widget.itemCount,
          separatorBuilder:
              (_, __) => const Divider(
                height: 1,
                indent: 68,
                color: AppColors.border,
              ),
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  _ShimmerBlock(t: t, height: 48, width: 48, radius: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ShimmerBlock(
                          t: t,
                          height: 14,
                          width: index.isEven ? 140 : 110,
                        ),
                        const SizedBox(height: 8),
                        _ShimmerBlock(
                          t: t,
                          height: 10,
                          width: index.isEven ? 96 : 120,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({
    required this.t,
    required this.height,
    this.width,
    this.radius = 8,
  });

  final double t;
  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final highlight = 0.35 + (0.35 * (1 - (2 * (t - 0.5).abs())));
    final base = AppColors.surfaceSecondary;
    final shine = Color.lerp(base, Colors.white, highlight)!;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment(-1.2 + 2.4 * t, -0.4),
          end: Alignment(-0.2 + 2.4 * t, 0.6),
          colors: [base, shine, base],
          stops: const [0.25, 0.5, 0.75],
        ),
      ),
    );
  }
}
