import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';

/// Provides [AppAppearance] to the tree and notifies dependents on Day/Night switch.
class AppearanceScope extends InheritedWidget {
  const AppearanceScope({
    super.key,
    required this.appearance,
    required super.child,
  });

  final AppAppearance appearance;

  /// Registers a dependency so this widget rebuilds when appearance changes.
  static AppAppearance of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppearanceScope>();
    assert(
      scope != null,
      'AppearanceScope.of() called without an AppearanceScope ancestor',
    );
    return scope?.appearance ?? AppAppearance.day;
  }

  static AppAppearance? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppearanceScope>()
        ?.appearance;
  }

  @override
  bool updateShouldNotify(AppearanceScope oldWidget) =>
      appearance != oldWidget.appearance;
}

/// Marks the entire child [Element] subtree dirty when [appearance] changes.
///
/// Needed because [AppColors] is read via static getters: Flutter skips rebuilding
/// children when the parent reuses the same [Widget] instance (`updateChild`
/// early-return). Walking and `markNeedsBuild` keeps [State] (scroll, tabs,
/// navigation) while forcing every screen to paint the new palette immediately.
class AppearanceRebuildGate extends StatefulWidget {
  const AppearanceRebuildGate({
    super.key,
    required this.appearance,
    required this.child,
  });

  final AppAppearance appearance;
  final Widget child;

  @override
  State<AppearanceRebuildGate> createState() => _AppearanceRebuildGateState();
}

class _AppearanceRebuildGateState extends State<AppearanceRebuildGate> {
  @override
  void didUpdateWidget(covariant AppearanceRebuildGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appearance == widget.appearance) return;
    // Sync AppColors again in case this gate updated without a full app rebuild.
    AppColors.bind(widget.appearance);
    _markSubtreeNeedsBuild();
  }

  void _markSubtreeNeedsBuild() {
    final element = context as Element;
    void mark(Element child) {
      child.markNeedsBuild();
      child.visitChildren(mark);
    }

    element.visitChildren(mark);
  }

  @override
  Widget build(BuildContext context) {
    // Keep static palette aligned with the active scope.
    AppColors.bind(widget.appearance);
    return widget.child;
  }
}
