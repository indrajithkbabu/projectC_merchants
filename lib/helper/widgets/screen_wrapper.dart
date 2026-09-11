import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_c/helper/colors.dart';

/// Wraps every screen so content draws under the status bar.
///
/// Use [SafeArea] with `top: false` so header colors cover the status bar
/// instead of leaving a mismatched system strip. Pad your header with
/// [statusBarTop] (or [statusBarPadding]) so content clears the icons.
///
/// Example:
/// ```dart
/// return ScreenWrapper(
///   backgroundColor: AppColors.scaffold,
///   child: Column(
///     children: [
///       Container(
///         width: double.infinity,
///         padding: EdgeInsets.fromLTRB(16, ScreenWrapper.statusBarTop(context) + 16, 16, 16),
///         color: AppColors.primary,
///         child: const Text('Title'),
///       ),
///       const Expanded(child: ...),
///     ],
///   ),
/// );
/// ```
class ScreenWrapper extends StatelessWidget {
  const ScreenWrapper({
    super.key,
    required this.child,
    this.backgroundColor,
    this.statusBarIconBrightness = Brightness.dark,
    this.resizeToAvoidBottomInset = true,
    this.extendBodyBehindBottom = false,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  final Widget child;
  final Color? backgroundColor;

  /// Dark icons for light headers; light icons for blue/dark headers.
  final Brightness statusBarIconBrightness;

  final bool resizeToAvoidBottomInset;

  /// When true, also draws under the bottom system inset (rare).
  final bool extendBodyBehindBottom;

  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  /// Status bar height for the current view.
  static double statusBarTop(BuildContext context) =>
      MediaQuery.paddingOf(context).top;

  /// Convenience padding that clears the status bar.
  static EdgeInsets statusBarPadding(
    BuildContext context, {
    double left = 0,
    double right = 0,
    double bottom = 0,
    double extraTop = 0,
  }) {
    return EdgeInsets.fromLTRB(
      left,
      statusBarTop(context) + extraTop,
      right,
      bottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: statusBarIconBrightness,
      // iOS uses statusBarBrightness inverted vs Android icon brightness.
      statusBarBrightness:
          statusBarIconBrightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
      systemNavigationBarColor: backgroundColor ?? AppColors.scaffold,
      systemNavigationBarIconBrightness: Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: backgroundColor ?? AppColors.scaffold,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomNavigationBar,
        body: SafeArea(
          top: false,
          bottom: !extendBodyBehindBottom,
          child: child,
        ),
      ),
    );
  }
}
