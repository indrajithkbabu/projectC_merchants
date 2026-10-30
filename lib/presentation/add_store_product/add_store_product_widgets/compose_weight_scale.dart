import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:project_c/helper/text_styles.dart';

/// Horizontal weight dial for Quick Upload compose (main gross / stone).
///
/// Tick **centers** align with the needle: padding = viewport/2 − stepPx/2.
/// Scroll offset ↔ value uses the same formula as tap-to-select.
class ComposeWeightScale extends StatefulWidget {
  const ComposeWeightScale({
    super.key,
    required this.value,
    required this.onChanged,
    this.onSettle,
    this.minValue = 0.5,
    this.step = 0.5,
    this.pxPerGram = 24,
    this.height = 56,
    this.hint = 'Scroll to choose weight',
    this.rangeMin,
    this.rangeMax,
    this.inactiveValue,
    this.onInactiveTap,
    this.labelEvery,
    this.haptic = true,
  });

  final double value;
  final ValueChanged<double> onChanged;

  /// Fired after fling/drag settles on a snapped value (commit to draft).
  final ValueChanged<double>? onSettle;

  final double minValue;
  final double step;

  /// Horizontal pixels per gram (main 24 → 12px per 0.5g step).
  final double pxPerGram;
  final double height;
  final String hint;

  final double? rangeMin;
  final double? rangeMax;

  /// Other range end — ring; tap switches editing end via [onInactiveTap].
  final double? inactiveValue;
  final VoidCallback? onInactiveTap;

  /// Stone: label every 1g. Null → main labels at 0.5, 5, then every 10g.
  final double? labelEvery;

  final bool haptic;

  double get stepPx => step * pxPerGram;

  @override
  State<ComposeWeightScale> createState() => _ComposeWeightScaleState();
}

class _ComposeWeightScaleState extends State<ComposeWeightScale> {
  late final ScrollController _controller;
  bool _userScrolling = false;
  bool _syncing = false;
  double _lastEmitted = double.nan;
  double _liveValue = 0.5;
  int _extentSteps = 1200;
  double _viewportWidth = 0;

  /// Soft edge fade only — no hard rectangle around the dial.
  static const _fadeAlpha = 0.28;

  @override
  void initState() {
    super.initState();
    _liveValue = widget.value;
    _lastEmitted = widget.value;
    _controller = ScrollController();
    _controller.addListener(_onControllerTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToValue(widget.value);
    });
  }

  @override
  void didUpdateWidget(covariant ComposeWeightScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_userScrolling || _syncing) return;
    if ((oldWidget.value - widget.value).abs() > widget.step / 4) {
      _liveValue = widget.value;
      _jumpToValue(widget.value, animate: true);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerTick);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerTick() {
    if (!_controller.hasClients || _syncing) return;
    final v = _valueForOffset(_controller.offset);
    if ((v - _liveValue).abs() < widget.step / 2) return;
    _liveValue = v;
    // Emit whenever the user is driving the scroll (drag or ballistic).
    if (_userScrolling) _emit(v);
  }

  double _snap(double v) {
    final steps = ((v - widget.minValue) / widget.step).round();
    final snapped = widget.minValue + steps * widget.step;
    return math.max(widget.minValue, double.parse(snapped.toStringAsFixed(3)));
  }

  /// Offset such that the **center** of the tick for [value] sits under the needle.
  double _offsetForValue(double value) {
    final snapped = _snap(value);
    final index = ((snapped - widget.minValue) / widget.step).round();
    return index * widget.stepPx;
  }

  /// Value whose tick center is under the needle at [offset].
  /// Same formula for scroll updates and tap-to-select.
  double _valueForOffset(double offset) {
    final index = (offset / widget.stepPx).round();
    return _snap(widget.minValue + index * widget.step);
  }

  void _ensureExtentFor(double value) {
    final need = ((value - widget.minValue) / widget.step).ceil() + 120;
    if (need > _extentSteps && mounted) {
      setState(() => _extentSteps = need);
    }
  }

  void _jumpToValue(double value, {bool animate = false}) {
    if (!_controller.hasClients) return;
    _ensureExtentFor(value);
    final maxExt = _controller.position.maxScrollExtent;
    final target = _offsetForValue(value).clamp(0.0, maxExt);
    _syncing = true;
    if (animate) {
      _controller
          .animateTo(
            target,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            _syncing = false;
          });
    } else {
      _controller.jumpTo(target);
      _syncing = false;
    }
  }

  void _emit(double value, {bool settle = false}) {
    final v = _snap(value);
    if (!settle &&
        !_lastEmitted.isNaN &&
        (v - _lastEmitted).abs() < widget.step / 2) {
      return;
    }
    if (widget.haptic &&
        !_lastEmitted.isNaN &&
        (v - _lastEmitted).abs() >= widget.step / 2) {
      HapticFeedback.selectionClick();
    }
    _lastEmitted = v;
    _liveValue = v;
    widget.onChanged(v);
    if (settle) widget.onSettle?.call(v);
  }

  Future<void> _snapSettle() async {
    if (!_controller.hasClients) return;
    // Re-read offset after the scroll activity ends (same path as live scroll).
    final v = _valueForOffset(_controller.offset);
    _ensureExtentFor(v + 30);
    final target = _offsetForValue(v).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    _syncing = true;
    await _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
    _syncing = false;
    _emit(v, settle: true);
  }

  void _onTapUp(TapUpDetails details) {
    if (!_controller.hasClients || _viewportWidth <= 0) return;

    // Tap near inactive range ring → switch end.
    if (widget.inactiveValue != null && widget.onInactiveTap != null) {
      final cx = _viewportWidth / 2;
      final ringX =
          (widget.inactiveValue! - widget.minValue) * widget.pxPerGram -
          _controller.offset +
          cx;
      if ((details.localPosition.dx - ringX).abs() < 36) {
        widget.onInactiveTap!();
        return;
      }
    }

    // Same mapping as scroll: content under the tap = offset + dx from needle.
    final dx = details.localPosition.dx - _viewportWidth / 2;
    final next = _valueForOffset(_controller.offset + dx);
    _userScrolling = false;
    _emit(next, settle: true);
    _jumpToValue(next, animate: true);
  }

  bool _onScrollNotification(ScrollNotification n) {
    if (n.depth != 0) return false;
    // Any user-driven start (finger, trackpad, stylus) — do not require
    // dragDetails; otherwise ballistic/trackpad scrolls never emit values.
    if (n is ScrollStartNotification) {
      _userScrolling = true;
    } else if (n is UserScrollNotification &&
        n.direction != ScrollDirection.idle) {
      _userScrolling = true;
    }
    if (n is ScrollEndNotification && _userScrolling) {
      _userScrolling = false;
      _snapSettle();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final stepPx = widget.stepPx;
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _viewportWidth = constraints.maxWidth;
          // Center of tick 0 under needle when offset == 0.
          final sidePad = _viewportWidth / 2 - stepPx / 2;
          return ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: _onScrollNotification,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // onTapUp only fires for a tap (not a drag) — does not
                    // steal the scroll gesture the way onTapDown did.
                    onTapUp: _onTapUp,
                    child: ListView.builder(
                      controller: _controller,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      itemExtent: stepPx,
                      cacheExtent: stepPx * 64,
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: true,
                      padding: EdgeInsets.symmetric(horizontal: sidePad),
                      itemCount: _extentSteps,
                      itemBuilder: (context, index) {
                        final value = widget.minValue + index * widget.step;
                        return _TickCell(
                          value: value,
                          labelEvery: widget.labelEvery,
                          step: widget.step,
                        );
                      },
                    ),
                  ),
                ),
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _ScaleChromePainter(
                          pxPerGram: widget.pxPerGram,
                          minValue: widget.minValue,
                          scrollOffset:
                              _controller.hasClients
                                  ? _controller.offset
                                  : 0,
                          rangeMin: widget.rangeMin,
                          rangeMax: widget.rangeMax,
                          inactiveValue: widget.inactiveValue,
                          height: widget.height,
                          fadeAlpha: _fadeAlpha,
                          drawRangeBand:
                              widget.rangeMin != null &&
                              widget.rangeMax != null,
                          softBand: true,
                        ),
                      );
                    },
                  ),
                ),
                if (widget.hint.trim().isNotEmpty)
                  Positioned(
                    top: 2,
                    left: 0,
                    right: 0,
                    child: Text(
                      widget.hint,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TickCell extends StatelessWidget {
  const _TickCell({
    required this.value,
    required this.step,
    this.labelEvery,
  });

  final double value;
  final double step;
  final double? labelEvery;

  bool get _isLarge {
    final x = (value * 100).round();
    if (step <= 0.15) return x % 100 == 0;
    return x % 500 == 0;
  }

  bool get _isMedium {
    final x = (value * 100).round();
    if (step <= 0.15) return x % 50 == 0;
    return x % 100 == 0;
  }

  bool get _showLabel {
    if (labelEvery != null) {
      final every = labelEvery!;
      final q = value / every;
      return (q - q.roundToDouble()).abs() < 0.001;
    }
    final x = (value * 100).round();
    if (x == 50) return true; // 0.5g
    if (x == 500) return true; // 5g
    return x >= 1000 && x % 1000 == 0; // 10, 20, 30…
  }

  String get _labelText {
    if (value == value.roundToDouble()) return '${value.toInt()}g';
    return '${value.toStringAsFixed(1)}g';
  }

  @override
  Widget build(BuildContext context) {
    final size =
        _isLarge
            ? 5.0
            : _isMedium
            ? 3.5
            : 2.2;
    final opacity =
        _isLarge
            ? 0.95
            : _isMedium
            ? 0.7
            : 0.4;
    return SizedBox(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 14),
          Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: opacity),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 14,
            child:
                _showLabel
                    ? Text(
                      _labelText,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    )
                    : null,
          ),
        ],
      ),
    );
  }
}

class _ScaleChromePainter extends CustomPainter {
  _ScaleChromePainter({
    required this.pxPerGram,
    required this.minValue,
    required this.scrollOffset,
    required this.height,
    required this.fadeAlpha,
    required this.drawRangeBand,
    this.softBand = false,
    this.rangeMin,
    this.rangeMax,
    this.inactiveValue,
  });

  final double pxPerGram;
  final double minValue;
  final double scrollOffset;
  final double height;
  final double fadeAlpha;
  final bool drawRangeBand;
  final bool softBand;
  final double? rangeMin;
  final double? rangeMax;
  final double? inactiveValue;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    if (drawRangeBand && rangeMin != null && rangeMax != null) {
      final a = (rangeMin! - minValue) * pxPerGram - scrollOffset + cx;
      final b = (rangeMax! - minValue) * pxPerGram - scrollOffset + cx;
      final left = math.min(a, b);
      final right = math.max(a, b);
      if (softBand) {
        final band =
            Paint()
              ..shader = LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0),
                ],
              ).createShader(Rect.fromLTRB(left, 18, right, height - 8));
        canvas.drawRect(Rect.fromLTRB(left, 20, right, height - 10), band);
      } else {
        final band = Paint()..color = Colors.white.withValues(alpha: 0.08);
        canvas.drawRRect(
          RRect.fromLTRBR(
            left,
            20,
            right,
            height - 10,
            const Radius.circular(6),
          ),
          band,
        );
      }
    }

    if (inactiveValue != null) {
      final x = (inactiveValue! - minValue) * pxPerGram - scrollOffset + cx;
      final paint =
          Paint()
            ..color = Colors.white.withValues(alpha: 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6;
      canvas.drawCircle(Offset(x, height / 2 + 4), 6, paint);
    }

    final needle =
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, 14), Offset(cx, height - 4), needle);

    final fade =
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.black.withValues(alpha: fadeAlpha),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: fadeAlpha),
            ],
            stops: const [0, 0.1, 0.9, 1],
          ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, fade);
  }

  @override
  bool shouldRepaint(covariant _ScaleChromePainter oldDelegate) {
    return oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.rangeMin != rangeMin ||
        oldDelegate.rangeMax != rangeMax ||
        oldDelegate.inactiveValue != inactiveValue ||
        oldDelegate.fadeAlpha != fadeAlpha ||
        oldDelegate.softBand != softBand;
  }
}
