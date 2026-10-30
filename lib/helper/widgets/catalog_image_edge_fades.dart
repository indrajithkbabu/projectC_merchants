import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/widgets/appearance_scope.dart';

/// Soft top/bottom washes so scrolling catalog images fade into the status
/// bar and home-indicator edges (cool / slightly blue tint).
///
/// Place in a [Stack] above the image scroll view and **below** floating
/// chrome (Telegram header, docks) so controls stay crisp.
class CatalogImageEdgeFades extends StatelessWidget {
  const CatalogImageEdgeFades({
    super.key,
    this.topHeight,
    this.bottomHeight,
  });

  /// Defaults to status-bar height + a soft falloff.
  final double? topHeight;

  /// Defaults to home-indicator inset + a soft falloff.
  final double? bottomHeight;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.maybeOf(context);
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;
    final topH = topHeight ?? (topPad + 36);
    final bottomH = bottomHeight ?? (bottomPad + 40);

    // Cool wash: scaffold mixed with Telegram appBar blue (night: scaffold).
    final tip =
        AppColors.isNight
            ? AppColors.scaffold.withValues(alpha: 0.88)
            : Color.lerp(
              AppColors.scaffold,
              AppColors.appBar,
              0.28,
            )!.withValues(alpha: 0.78);
    final mid = tip.withValues(alpha: 0);

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (topH > 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topH,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [tip, mid],
                  ),
                ),
              ),
            ),
          if (bottomH > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: bottomH,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [tip, mid],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
