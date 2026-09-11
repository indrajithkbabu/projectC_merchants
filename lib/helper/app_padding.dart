import 'package:flutter/material.dart';

/// Shared spacing tokens used across the app.
abstract final class AppPadding {
  static const double horizontal = 15;

  static const EdgeInsets screenHorizontal = EdgeInsets.symmetric(
    horizontal: horizontal,
  );

  static EdgeInsets screen({double top = 0, double bottom = 0}) =>
      EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
}
