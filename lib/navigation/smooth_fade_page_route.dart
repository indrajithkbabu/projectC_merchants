import 'package:flutter/material.dart';

/// Soft fade route for Stores → Discover (no horizontal page slide).
class SmoothFadePageRoute<T> extends PageRouteBuilder<T> {
  SmoothFadePageRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          opaque: true,
          maintainState: true,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (context, animation, secondaryAnimation) {
            return builder(context);
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fade = CurvedAnimation(
              parent: animation,
              curve: const Cubic(0.2, 0.0, 0.0, 1.0),
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(opacity: fade, child: child);
          },
        );
}

/// Store profile → channel: expands from the header instead of a sideways push.
///
/// Non-opaque so Discover stays visible underneath while channel fades/rises —
/// feels like the header opening, not a page push. **Pop is instant** (back
/// icon / edge swipe) — no reverse fade/slide/scale.
class StoreChannelRevealRoute<T> extends PageRouteBuilder<T> {
  StoreChannelRevealRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          opaque: false,
          barrierColor: Colors.transparent,
          maintainState: true,
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, animation, secondaryAnimation) {
            return builder(context);
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Instant dismiss — skip fade/slide/scale on reverse.
            if (animation.status == AnimationStatus.reverse ||
                animation.status == AnimationStatus.dismissed) {
              return const SizedBox.shrink();
            }

            // Fade settles early; motion eases longer for a soft settle.
            final fade = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.62, curve: Cubic(0.2, 0.0, 0.0, 1.0)),
            );
            final motion = CurvedAnimation(
              parent: animation,
              curve: const Cubic(0.22, 1.0, 0.36, 1.0),
            );
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.028),
              end: Offset.zero,
            ).animate(motion);
            final scale = Tween<double>(begin: 0.985, end: 1).animate(motion);

            return FadeTransition(
              opacity: fade,
              child: SlideTransition(
                position: slide,
                child: ScaleTransition(
                  scale: scale,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.medium,
                  child: child,
                ),
              ),
            );
          },
        );
}

/// Left-edge drag to pop — restores iOS-style back-swipe on fade routes.
class EdgeBackSwipe extends StatefulWidget {
  const EdgeBackSwipe({
    super.key,
    required this.onBack,
    required this.child,
    this.edgeWidth = 28,
  });

  final Future<void> Function() onBack;
  final Widget child;
  final double edgeWidth;

  @override
  State<EdgeBackSwipe> createState() => _EdgeBackSwipeState();
}

class _EdgeBackSwipeState extends State<EdgeBackSwipe> {
  bool _tracking = false;
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: widget.edgeWidth,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (details) {
              _tracking = true;
              _dx = 0;
            },
            onHorizontalDragUpdate: (details) {
              if (!_tracking) return;
              _dx += details.delta.dx;
            },
            onHorizontalDragEnd: (details) {
              if (!_tracking) return;
              final fling = details.primaryVelocity ?? 0;
              final shouldPop = _dx > 72 || fling > 700;
              _tracking = false;
              _dx = 0;
              if (shouldPop) {
                widget.onBack();
              }
            },
            onHorizontalDragCancel: () {
              _tracking = false;
              _dx = 0;
            },
          ),
        ),
      ],
    );
  }
}
