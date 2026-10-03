import 'package:flutter/material.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';

/// Skeleton list matching [_ImportRequestTile] layout (icon + title/subtitle + chip).
class ImportRequestsListShimmer extends StatefulWidget {
  const ImportRequestsListShimmer({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  State<ImportRequestsListShimmer> createState() =>
      _ImportRequestsListShimmerState();
}

class _ImportRequestsListShimmerState extends State<ImportRequestsListShimmer>
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
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppPadding.screen(top: 8, bottom: 24),
          itemCount: widget.itemCount,
          separatorBuilder:
              (_, __) => const Divider(height: 1, color: AppColors.border),
          itemBuilder: (context, index) {
            return _ImportRequestTileShimmer(t: _controller.value);
          },
        );
      },
    );
  }
}

class _ImportRequestTileShimmer extends StatelessWidget {
  const _ImportRequestTileShimmer({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final highlight = 0.35 + (0.35 * (1 - (2 * (t - 0.5).abs())));
    final base = AppColors.surfaceSecondary;
    final shine = Color.lerp(base, Colors.white, highlight)!;
    final gradient = LinearGradient(
      begin: Alignment(-1.2 + 2.4 * t, -0.4),
      end: Alignment(-0.2 + 2.4 * t, 0.6),
      colors: [base, shine, base],
      stops: const [0.25, 0.5, 0.75],
    );

    Widget bar({
      required double width,
      required double height,
      BorderRadius? radius,
    }) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: radius ?? BorderRadius.circular(6),
          gradient: gradient,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: gradient,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(width: double.infinity, height: 14),
                    const SizedBox(height: 8),
                    bar(width: 160, height: 11),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              bar(
                width: 64,
                height: 22,
                radius: BorderRadius.circular(8),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: bar(
                  width: double.infinity,
                  height: 40,
                  radius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: bar(
                  width: double.infinity,
                  height: 40,
                  radius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
