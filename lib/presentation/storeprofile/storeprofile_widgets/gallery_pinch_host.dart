import 'package:flutter/material.dart';

/// Telegram-style pinch host for Gallery mosaics (same 2…9 ladder as channel Media).
///
/// Uses pointer tracking (not [ScaleGestureRecognizer]) so nested scroll views
/// do not steal the gesture. [builder] receives continuous columns while
/// pinching; they snap to an int on release.
class GalleryPinchHost extends StatefulWidget {
  const GalleryPinchHost({
    super.key,
    required this.builder,
    this.initialColumns = 4,
    this.minColumns = 2,
    this.maxColumns = 9,
    this.onColumnsChanged,
  });

  final Widget Function(
    BuildContext context,
    double columns,
    bool pinching,
  )
  builder;

  final double initialColumns;
  final double minColumns;
  final double maxColumns;

  /// Fired when the integer column count changes (pinch update / snap end).
  final ValueChanged<int>? onColumnsChanged;

  @override
  State<GalleryPinchHost> createState() => _GalleryPinchHostState();
}

class _GalleryPinchHostState extends State<GalleryPinchHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _snap;
  final Map<int, Offset> _pointers = <int, Offset>{};
  double? _startDistance;
  late double _columns;
  double _pinchBaseColumns = 4;
  bool _pinching = false;
  int _lastReportedCols = 0;

  @override
  void initState() {
    super.initState();
    _columns = widget.initialColumns.clamp(
      widget.minColumns,
      widget.maxColumns,
    );
    _lastReportedCols = _columns.round();
    _snap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _snap.dispose();
    super.dispose();
  }

  void _reportColumns(int cols) {
    if (cols == _lastReportedCols) return;
    _lastReportedCols = cols;
    widget.onColumnsChanged?.call(cols);
  }

  double? _fingerDistance() {
    if (_pointers.length < 2) return null;
    final pts = _pointers.values.toList(growable: false);
    return (pts[0] - pts[1]).distance;
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 2 && !_pinching) {
      _startDistance = _fingerDistance();
      if (_startDistance != null && _startDistance! >= 12) {
        _snap.stop();
        setState(() {
          _pinching = true;
          _pinchBaseColumns = _columns;
        });
      }
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    if (!_pinching || _pointers.length < 2) return;
    final start = _startDistance;
    final now = _fingerDistance();
    if (start == null || now == null || start < 12) return;
    final scale = now / start;
    if (!scale.isFinite || scale <= 0) return;
    final next = (_pinchBaseColumns / scale).clamp(
      widget.minColumns,
      widget.maxColumns,
    );
    if ((next - _columns).abs() < 0.008) return;
    setState(() => _columns = next);
    _reportColumns(next.round());
  }

  void _onPointerEnd(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (!_pinching || _pointers.length >= 2) return;
    _startDistance = null;
    final from = _columns;
    final to =
        from
            .round()
            .clamp(widget.minColumns.toInt(), widget.maxColumns.toInt())
            .toDouble();
    setState(() => _pinching = false);
    _reportColumns(to.toInt());
    if ((from - to).abs() < 0.02) {
      if (from != to) setState(() => _columns = to);
      return;
    }
    final anim = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(parent: _snap, curve: Curves.easeOutCubic),
    );
    void tick() {
      if (!mounted) return;
      setState(() => _columns = anim.value);
    }

    anim.addListener(tick);
    _snap.forward(from: 0).whenComplete(() {
      anim.removeListener(tick);
      if (!mounted) return;
      setState(() => _columns = to);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: widget.builder(context, _columns, _pinching),
    );
  }
}
