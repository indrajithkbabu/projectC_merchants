import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/presentation/search/search_widgets/search_chips.dart';

/// Shared pulse controller used by search skeleton loaders.
mixin _SearchShimmerTicker<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  late final AnimationController shimmerController;

  @override
  void initState() {
    super.initState();
    shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    shimmerController.dispose();
    super.dispose();
  }
}

Color _shimmerShine(double t) {
  final highlight = 0.35 + (0.35 * (1 - (2 * (t - 0.5).abs())));
  return Color.lerp(AppColors.surfaceSecondary, Colors.white, highlight)!;
}

BoxDecoration _shimmerBox(double t, {double radius = 8}) {
  final base = AppColors.surfaceSecondary;
  final shine = _shimmerShine(t);
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: LinearGradient(
      begin: Alignment(-1.2 + 2.4 * t, -0.4),
      end: Alignment(-0.2 + 2.4 * t, 0.6),
      colors: [base, shine, base],
      stops: const [0.25, 0.5, 0.75],
    ),
  );
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
      decoration: _shimmerBox(t, radius: radius),
    );
  }
}

/// Discover panel skeleton (Recent rows + trending pills + category tiles).
class SearchDiscoverShimmer extends StatefulWidget {
  const SearchDiscoverShimmer({super.key});

  @override
  State<SearchDiscoverShimmer> createState() => _SearchDiscoverShimmerState();
}

class _SearchDiscoverShimmerState extends State<SearchDiscoverShimmer>
    with SingleTickerProviderStateMixin, _SearchShimmerTicker {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerController,
      builder: (context, _) {
        final t = shimmerController.value;
        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _ShimmerBlock(t: t, height: 12, width: 72),
            const SizedBox(height: 10),
            for (var i = 0; i < 3; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    _ShimmerBlock(t: t, height: 22, width: 22, radius: 6),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ShimmerBlock(t: t, height: 14, width: 140),
                          const SizedBox(height: 6),
                          _ShimmerBlock(t: t, height: 10, width: 80),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _ShimmerBlock(t: t, height: 12, width: 100),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final w in [64.0, 72.0, 80.0, 56.0, 88.0, 70.0])
                  _ShimmerBlock(t: t, height: 32, width: w, radius: 20),
              ],
            ),
            const SizedBox(height: 20),
            _ShimmerBlock(t: t, height: 12, width: 140),
            const SizedBox(height: 10),
            GridView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.5,
              ),
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ShimmerBlock(t: t, height: 14, width: 88, radius: 4),
                      const SizedBox(height: 8),
                      _ShimmerBlock(t: t, height: 10, width: 56, radius: 4),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// Suggestion list skeleton (Matches header + list rows).
class SearchSuggestionShimmer extends StatefulWidget {
  const SearchSuggestionShimmer({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  State<SearchSuggestionShimmer> createState() => _SearchSuggestionShimmerState();
}

class _SearchSuggestionShimmerState extends State<SearchSuggestionShimmer>
    with SingleTickerProviderStateMixin, _SearchShimmerTicker {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerController,
      builder: (context, _) {
        final t = shimmerController.value;
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            const SearchSectionHeader(title: 'Matches'),
            const SizedBox(height: 8),
            for (var i = 0; i < widget.itemCount; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ShimmerBlock(t: t, height: 14, width: 160),
                          const SizedBox(height: 8),
                          _ShimmerBlock(t: t, height: 10, width: 120),
                        ],
                      ),
                    ),
                    _ShimmerBlock(t: t, height: 12, width: 48, radius: 4),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Results grid skeleton matching [SearchResultsGrid] card layout.
class SearchResultsGridShimmer extends StatefulWidget {
  const SearchResultsGridShimmer({
    super.key,
    this.itemCount = 6,
    this.showStoreLine = true,
    this.padding = EdgeInsets.zero,
  });

  final int itemCount;
  final bool showStoreLine;
  final EdgeInsets padding;

  @override
  State<SearchResultsGridShimmer> createState() =>
      _SearchResultsGridShimmerState();
}

class _SearchResultsGridShimmerState extends State<SearchResultsGridShimmer>
    with SingleTickerProviderStateMixin, _SearchShimmerTicker {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerController,
      builder: (context, _) {
        final t = shimmerController.value;
        return GridView.builder(
          padding: widget.padding,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.itemCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 14,
            childAspectRatio: 0.58,
          ),
          itemBuilder: (context, index) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: _shimmerBox(t, radius: 14),
                  ),
                ),
                const SizedBox(height: 8),
                _ShimmerBlock(t: t, height: 12, width: double.infinity),
                if (widget.showStoreLine) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _ShimmerBlock(t: t, height: 8, width: 8, radius: 4),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _ShimmerBlock(t: t, height: 10, width: 80),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: [
                    _ShimmerBlock(t: t, height: 18, width: 44, radius: 6),
                    _ShimmerBlock(t: t, height: 18, width: 36, radius: 6),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Count-line skeleton under the filter bar.
class SearchCountLineShimmer extends StatefulWidget {
  const SearchCountLineShimmer({super.key});

  @override
  State<SearchCountLineShimmer> createState() => _SearchCountLineShimmerState();
}

class _SearchCountLineShimmerState extends State<SearchCountLineShimmer>
    with SingleTickerProviderStateMixin, _SearchShimmerTicker {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerController,
      builder: (context, _) {
        final t = shimmerController.value;
        return _ShimmerBlock(t: t, height: 12, width: 160, radius: 4);
      },
    );
  }
}

/// Single result-card shimmer used for load-more footer.
class SearchResultCardShimmer extends StatefulWidget {
  const SearchResultCardShimmer({super.key, this.showStoreLine = true});

  final bool showStoreLine;

  @override
  State<SearchResultCardShimmer> createState() =>
      _SearchResultCardShimmerState();
}

class _SearchResultCardShimmerState extends State<SearchResultCardShimmer>
    with SingleTickerProviderStateMixin, _SearchShimmerTicker {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerController,
      builder: (context, _) {
        final t = shimmerController.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(decoration: _shimmerBox(t, radius: 14)),
            ),
            const SizedBox(height: 8),
            _ShimmerBlock(t: t, height: 12, width: double.infinity),
            if (widget.showStoreLine) ...[
              const SizedBox(height: 6),
              _ShimmerBlock(t: t, height: 10, width: 90),
            ],
          ],
        );
      },
    );
  }
}

/// “What this store has” chip-row skeleton.
class SearchSummaryChipsShimmer extends StatefulWidget {
  const SearchSummaryChipsShimmer({super.key});

  @override
  State<SearchSummaryChipsShimmer> createState() =>
      _SearchSummaryChipsShimmerState();
}

class _SearchSummaryChipsShimmerState extends State<SearchSummaryChipsShimmer>
    with SingleTickerProviderStateMixin, _SearchShimmerTicker {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerController,
      builder: (context, _) {
        final t = shimmerController.value;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final w in [78.0, 92.0, 70.0, 86.0, 64.0, 100.0])
              _ShimmerBlock(t: t, height: 32, width: w, radius: 20),
          ],
        );
      },
    );
  }
}
