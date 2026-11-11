/// Orientation helpers for classic Telegram Group/Single collages.
///
/// Does **not** reorder photos — only picks a layout variant so landscape
/// frames are not forced into tall left strips.
class TelegramCollageGeometry {
  TelegramCollageGeometry._();

  /// Mild landscape still counts (avoids near-square misclassification).
  static const double landscapeThreshold = 1.05;

  static bool isLandscapeRatio(double? ratio) =>
      ratio != null && ratio.isFinite && ratio >= landscapeThreshold;

  static bool isLandscapeAt(List<double?> ratios, int index) {
    if (index < 0 || index >= ratios.length) return false;
    return isLandscapeRatio(ratios[index]);
  }

  /// True when every known ratio among the first [count] is landscape.
  static bool allKnownLandscape(List<double?> ratios, int count) {
    var known = 0;
    var land = 0;
    final n = count < ratios.length ? count : ratios.length;
    for (var i = 0; i < n; i++) {
      final r = ratios[i];
      if (r == null || !r.isFinite || r <= 0) continue;
      known++;
      if (isLandscapeRatio(r)) land++;
    }
    return known > 0 && land == known;
  }

  /// 2-up: stack when both are landscape (Telegram).
  static bool stackTwoLandscapes(List<double?> ratios) {
    return isLandscapeAt(ratios, 0) && isLandscapeAt(ratios, 1);
  }

  /// 3–9: prefer full-width top landscape instead of tall left / skinny rows.
  ///
  /// Also when every known ratio is landscape (multiple landscapes, even if
  /// index 0 is still unknown) — avoids squeezing all-landscape albums into
  /// LargeLeft / dense row cells. Mixed portrait-first albums stay classic.
  static bool useTopThenRestForCount(List<double?> ratios, int count) {
    if (count < 3 || count > 9) return false;
    if (isLandscapeAt(ratios, 0)) return true;
    if (allKnownLandscape(ratios, count)) return true;
    return false;
  }

  /// 4-up all-landscape → 2×2 (avoids tall left and a squeezed 3-across).
  static bool useGridFourAllLandscape(List<double?> ratios) {
    return allKnownLandscape(ratios, 4);
  }

  /// Remaining strip under a top landscape: stack when both leftover cells
  /// are landscape (same idea as the 2-up stack).
  static bool stackRemainingTwoLandscapes(
    List<double?> ratios,
    int startIndex,
  ) {
    return isLandscapeAt(ratios, startIndex) &&
        isLandscapeAt(ratios, startIndex + 1);
  }
}
