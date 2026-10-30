import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:project_c/helper/product_image.dart';

/// Armed by product-details before [Navigator.pop] so swipe-dismiss close
/// continues from the dragged photo frame (no snap to a full-size flyer).
class TelegramPhotoCloseAnchor {
  TelegramPhotoCloseAnchor._();

  static double dismissDy = 0;
  static double dismissScale = 1;

  static void arm({required double dy, required double scale}) {
    dismissDy = dy;
    dismissScale = scale.clamp(0.5, 1.0);
  }

  static void clear() {
    dismissDy = 0;
    dismissScale = 1;
  }
}

/// Telegram-style photo open/close (MediaViewer).
///
/// Photo-aspect [flight] rect (cover over cell → contain on screen) + [clip]
/// from the tapped cell. Close is the reverse; swipe-dismiss arms
/// [TelegramPhotoCloseAnchor] so reverse starts from the dragged frame.
class TelegramPhotoPageRoute<T> extends PageRouteBuilder<T> {
  TelegramPhotoPageRoute({
    required this.sourceRect,
    required this.imagePath,
    this.thumbhash,
    this.imageWidth,
    this.imageHeight,
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          opaque: false,
          barrierDismissible: false,
          barrierColor: Colors.transparent,
          maintainState: true,
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (context, animation, secondaryAnimation) {
            return builder(context);
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _TelegramPhotoTransition(
              animation: animation,
              sourceRect: sourceRect,
              imagePath: imagePath,
              thumbhash: thumbhash,
              imageWidth: imageWidth,
              imageHeight: imageHeight,
              child: child,
            );
          },
        );

  final Rect sourceRect;
  final String imagePath;
  final String? thumbhash;
  final double? imageWidth;
  final double? imageHeight;

  @override
  bool get popGestureEnabled => false;
}

class _TelegramPhotoTransition extends StatefulWidget {
  const _TelegramPhotoTransition({
    required this.animation,
    required this.sourceRect,
    required this.imagePath,
    required this.thumbhash,
    required this.imageWidth,
    required this.imageHeight,
    required this.child,
  });

  final Animation<double> animation;
  final Rect sourceRect;
  final String imagePath;
  final String? thumbhash;
  final double? imageWidth;
  final double? imageHeight;
  final Widget child;

  @override
  State<_TelegramPhotoTransition> createState() =>
      _TelegramPhotoTransitionState();
}

class _TelegramPhotoTransitionState extends State<_TelegramPhotoTransition> {
  /// Details chrome only after flyer has settled (avoids size handoff flicker).
  static const double _childFadeStart = 0.92;

  late final CurvedAnimation _curved;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  /// Real photo aspect — never fall back to cell aspect for [dest] (that
  /// caused open: oversized square → settle to real photo size).
  double? _aspect;

  /// Close endpoint captured once when reverse starts (includes swipe offset).
  Rect? _closeEnd;
  bool _closeArmed = false;

  @override
  void initState() {
    super.initState();
    _curved = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    final w = widget.imageWidth;
    final h = widget.imageHeight;
    if (w != null && h != null && w > 0 && h > 0) {
      _aspect = w / h;
    } else {
      _resolveAspect();
    }
  }

  ImageProvider? _providerFor(String path) {
    final value = path.trim();
    if (value.isEmpty) return null;
    if (ProductImagePaths.isNetwork(value)) {
      return CachedNetworkImageProvider(
        value,
        cacheManager: CatalogImageCache.instance,
      );
    }
    final file = File(value);
    if (!file.existsSync()) return null;
    return FileImage(file);
  }

  void _resolveAspect() {
    final provider = _providerFor(widget.imagePath);
    if (provider == null) return;
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, syncCall) {
        final iw = info.image.width;
        final ih = info.image.height;
        // Detach before reading aspect so dispose never double-removes
        // (MultiImageStreamCompleter disposes once the last listener leaves).
        _detachImageStreamListener();
        if (iw <= 0 || ih <= 0) return;
        final next = iw / ih;
        if (_aspect != null) return;
        _aspect = next;
        // Sync cache hit: apply before first paint. Late async: only if
        // flight hasn't moved (avoids mid-open size jump).
        if (!mounted) return;
        if (syncCall || widget.animation.value < 0.02) {
          setState(() {});
        }
      },
      onError: (_, __) {
        _detachImageStreamListener();
      },
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  /// Removes the aspect listener at most once. Safe if already detached.
  void _detachImageStreamListener() {
    final stream = _stream;
    final listener = _listener;
    _stream = null;
    _listener = null;
    if (stream == null || listener == null) return;
    try {
      stream.removeListener(listener);
    } on StateError catch (_) {
      // Stream already disposed after an earlier removeListener.
    }
  }

  @override
  void dispose() {
    _detachImageStreamListener();
    _curved.dispose();
    TelegramPhotoCloseAnchor.clear();
    super.dispose();
  }

  static Rect _containDest(Size screen, double aspect) {
    if (aspect <= 0 || !aspect.isFinite) return Offset.zero & screen;
    final screenAspect = screen.width / math.max(screen.height, 1.0);
    if (aspect > screenAspect) {
      final h = screen.width / aspect;
      return Rect.fromLTWH(0, (screen.height - h) / 2, screen.width, h);
    }
    final w = screen.height * aspect;
    return Rect.fromLTWH((screen.width - w) / 2, 0, w, screen.height);
  }

  static Rect _coverFromCell(Rect cell, double aspect) {
    if (aspect <= 0 || !aspect.isFinite) return cell;
    final cellAspect = cell.width / math.max(cell.height, 1.0);
    if (aspect > cellAspect) {
      final h = cell.height;
      final w = h * aspect;
      return Rect.fromCenter(center: cell.center, width: w, height: h);
    }
    final w = cell.width;
    final h = w / aspect;
    return Rect.fromCenter(center: cell.center, width: w, height: h);
  }

  Rect _viewerEnd(Size screen, double aspect) {
    final dest = _containDest(screen, aspect);
    final dy = TelegramPhotoCloseAnchor.dismissDy;
    final scale = TelegramPhotoCloseAnchor.dismissScale;
    if (dy.abs() < 0.5 && (scale - 1).abs() < 0.001) return dest;
    return Rect.fromCenter(
      center: dest.center + Offset(0, dy),
      width: dest.width * scale,
      height: dest.height * scale,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final source = widget.sourceRect;

    return AnimatedBuilder(
      animation: Listenable.merge([_curved, widget.animation]),
      builder: (context, _) {
        final t = _curved.value.clamp(0.0, 1.0);
        final closing = widget.animation.status == AnimationStatus.reverse;

        // Until real aspect is known, stay on the cell (avoid wrong-aspect
        // oversized dest → settle flicker). Details still fade in at the end.
        final aspect = _aspect;
        final hasAspect = aspect != null && aspect > 0 && aspect.isFinite;

        final Rect flight;
        final Rect clip;
        if (!hasAspect) {
          flight = source;
          clip = source;
        } else {
          final from = _coverFromCell(source, aspect);
          final dest = _containDest(size, aspect);
          if (closing) {
            if (!_closeArmed) {
              _closeEnd = _viewerEnd(size, aspect);
              _closeArmed = true;
              TelegramPhotoCloseAnchor.clear();
            }
            final end = _closeEnd ?? dest;
            flight = Rect.lerp(from, end, t)!;
            clip = Rect.lerp(source, end, t)!;
          } else {
            flight = Rect.lerp(from, dest, t)!;
            clip = Rect.lerp(source, dest, t)!;
          }
        }

        final childOpacity =
            closing
                ? 0.0
                : t <= _childFadeStart
                ? 0.0
                : ((t - _childFadeStart) / (1.0 - _childFadeStart))
                    .clamp(0.0, 1.0);
        // Hide flyer once details own the frame — no double-image size flash.
        final showFlyer =
            closing || (childOpacity < 0.995 && (hasAspect || t < 0.5));

        final scrim =
            !hasAspect
                ? 0.0
                : closing
                ? (t * t * 0.90)
                : (t * 0.90);
        final radius = lerpDouble(5.0, 0.0, hasAspect ? t : 0.0)!;

        final imageLeft = flight.left - clip.left;
        final imageTop = flight.top - clip.top;

        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: scrim.clamp(0.0, 1.0)),
              ),
            ),
            IgnorePointer(
              ignoring: childOpacity < 0.999,
              child: Opacity(opacity: childOpacity, child: widget.child),
            ),
            if (showFlyer)
              Positioned(
                left: clip.left,
                top: clip.top,
                width: clip.width.clamp(1.0, size.width * 1.25),
                height: clip.height.clamp(1.0, size.height * 1.25),
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          left: imageLeft,
                          top: imageTop,
                          width: flight.width.clamp(1.0, size.width * 1.5),
                          height: flight.height.clamp(1.0, size.height * 1.5),
                          child: ProductMediaImage(
                            path: widget.imagePath,
                            fit: BoxFit.cover,
                            thumbhash: widget.thumbhash,
                            decodeCacheWidth:
                                CatalogImageCache.fullCacheWidth(),
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Parse a [Rect] stored in named-route args as a map of doubles.
Rect? rectFromArgs(Object? raw) {
  if (raw is Rect) return raw;
  if (raw is! Map) return null;
  final left = raw['left'];
  final top = raw['top'];
  final width = raw['width'];
  final height = raw['height'];
  if (left is! num || top is! num || width is! num || height is! num) {
    return null;
  }
  if (width <= 0 || height <= 0) return null;
  return Rect.fromLTWH(
    left.toDouble(),
    top.toDouble(),
    width.toDouble(),
    height.toDouble(),
  );
}

Map<String, double> rectToArgs(Rect rect) => {
  'left': rect.left,
  'top': rect.top,
  'width': rect.width,
  'height': rect.height,
};
