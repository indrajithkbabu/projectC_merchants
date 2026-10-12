import 'package:flutter/material.dart';
import 'package:project_c/helper/app_shimmer.dart';
import 'package:project_c/helper/colors.dart';

/// Skeleton rows matching [ActivityNotificationTile] (avatar + text lines).
class ActivityFeedShimmer extends StatefulWidget {
  const ActivityFeedShimmer({
    super.key,
    this.itemCount = 6,
    this.includeSectionLabel = true,
  });

  final int itemCount;
  final bool includeSectionLabel;

  @override
  State<ActivityFeedShimmer> createState() => _ActivityFeedShimmerState();
}

class _ActivityFeedShimmerState extends State<ActivityFeedShimmer>
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.includeSectionLabel) ...[
              const SizedBox(height: 20),
              _ShimmerBlock(t: t, height: 14, width: 56, radius: 4),
              const SizedBox(height: 8),
            ],
            for (var i = 0; i < widget.itemCount; i++) ...[
              _ActivityRowShimmer(t: t, wide: i.isEven),
              if (i < widget.itemCount - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.border.withValues(alpha: 0.7),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// Single placeholder row (used for pagination footer too).
class ActivityRowShimmer extends StatefulWidget {
  const ActivityRowShimmer({super.key});

  @override
  State<ActivityRowShimmer> createState() => _ActivityRowShimmerState();
}

class _ActivityRowShimmerState extends State<ActivityRowShimmer>
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
        return _ActivityRowShimmer(t: _controller.value, wide: true);
      },
    );
  }
}

class _ActivityRowShimmer extends StatelessWidget {
  const _ActivityRowShimmer({required this.t, required this.wide});

  final double t;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ShimmerBlock(t: t, height: 48, width: 48, radius: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _ShimmerBlock(
                  t: t,
                  height: 13,
                  width: wide ? double.infinity : 180,
                  radius: 4,
                ),
                const SizedBox(height: 8),
                _ShimmerBlock(
                  t: t,
                  height: 11,
                  width: wide ? 88 : 64,
                  radius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
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
    return Container(
      width: width,
      height: height,
      decoration: AppShimmer.box(t, radius: radius),
    );
  }
}
