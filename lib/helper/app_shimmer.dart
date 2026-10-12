import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';

/// Shared Day / Night shimmer tokens for skeleton loaders.
///
/// Night stays on the Graphite ramp (no pure white). Day keeps a soft lift
/// toward near-white on light grey bases.
abstract final class AppShimmer {
  /// Resting skeleton fill.
  static Color get base =>
      AppColors.isNight ? AppColors.grey800 : AppColors.surfaceSecondary;

  /// Peak of the sweep highlight.
  static Color get highlight =>
      AppColors.isNight ? AppColors.grey700 : const Color(0xFFF7F7F8);

  /// Pulse amount for [t] in `0..1` (triangle wave around mid).
  static double pulse(double t) {
    final raw = 0.35 + (0.35 * (1 - (2 * (t - 0.5).abs())));
    // Night: quieter sweep so blocks don't flash on dark surfaces.
    return AppColors.isNight ? raw * 0.55 : raw;
  }

  static Color shine(double t) => Color.lerp(base, highlight, pulse(t))!;

  static LinearGradient gradient(double t) {
    final b = base;
    final s = shine(t);
    return LinearGradient(
      begin: Alignment(-1.2 + 2.4 * t, -0.4),
      end: Alignment(-0.2 + 2.4 * t, 0.6),
      colors: [b, s, b],
      stops: const [0.25, 0.5, 0.75],
    );
  }

  static BoxDecoration box(double t, {double radius = 8}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: gradient(t),
    );
  }
}
