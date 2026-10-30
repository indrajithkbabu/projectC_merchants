import 'package:flutter/material.dart';
import 'package:project_c/helper/catalog_responsive_image.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/catalog/catalog_product_models.dart';
import 'package:project_c/models/store_product.dart';

class ProductDetailsImageCarousel extends StatefulWidget {
  const ProductDetailsImageCarousel({super.key, required this.product});

  final StoreProduct product;

  @override
  State<ProductDetailsImageCarousel> createState() =>
      _ProductDetailsImageCarouselState();
}

class _ProductDetailsImageCarouselState
    extends State<ProductDetailsImageCarousel> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final masters = widget.product.imagePaths;
    final paths = widget.product.urlsForRole(
      CatalogImageRole.detail,
      log: true,
    );
    final pageCount = paths.isEmpty ? 1 : paths.length;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                PageView.builder(
                  controller: _controller,
                  itemCount: pageCount,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) {
                    if (masters.isEmpty) {
                      return _Placeholder(tone: widget.product.toneIndex);
                    }
                    final path = paths[index];
                    if (!ProductImagePaths.isDisplayable(path)) {
                      return _Placeholder(tone: widget.product.toneIndex);
                    }
                    return ProductMediaImage(
                      path: path,
                      thumbhash: widget.product.thumbhashAt(index),
                    );
                  },
                ),
                if (paths.length > 1)
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_index + 1}/${paths.length}',
                        style: AppTextStyles.caption(
                          color: AppColors.textOnPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (paths.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(paths.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.tone});

  final int tone;

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone % 4) {
      0 => [
        AppColors.surfaceSecondary,
        AppColors.primary.withValues(alpha: 0.45),
      ],
      1 => [
        AppColors.surfaceSecondary,
        AppColors.primaryDark.withValues(alpha: 0.42),
      ],
      2 => [
        AppColors.surfaceSecondary,
        AppColors.accent.withValues(alpha: 0.35),
      ],
      _ => [
        AppColors.surfaceSecondary,
        AppColors.success.withValues(alpha: 0.38),
      ],
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.diamond_outlined,
          size: 48,
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}

/// Lock + stock icons (Preview details chrome).
///
/// Default states are silent: unlocked + in-stock (or null stock) → nothing.
/// Only **lock**, **out of stock**, **to-order**, and **Pending** import
/// chrome are shown — no "Unlocked" / "In stock" chrome.
class ProductDetailsLockStockRow extends StatelessWidget {
  const ProductDetailsLockStockRow({
    super.key,
    required this.isLocked,
    this.stockStatus,
    this.mtoDays,
    this.importPending = false,
    this.importDeclined = false,
  });

  final bool isLocked;
  final CatalogStockStatus? stockStatus;

  /// Kept for call-site compatibility; days are not shown (icon-only chrome).
  final int? mtoDays;

  /// Destination copy awaiting source-owner approval.
  final bool importPending;

  /// Destination copy declined by source partner.
  final bool importDeclined;

  /// Whether any non-default lock/stock/pending chrome should paint.
  static bool shouldShow({
    required bool isLocked,
    CatalogStockStatus? stockStatus,
    bool importPending = false,
    bool importDeclined = false,
  }) {
    if (importPending || importDeclined) return true;
    if (isLocked) return true;
    return stockStatus == CatalogStockStatus.outOfStock ||
        stockStatus == CatalogStockStatus.mto;
  }

  @override
  Widget build(BuildContext context) {
    if (!shouldShow(
      isLocked: isLocked,
      stockStatus: stockStatus,
      importPending: importPending,
      importDeclined: importDeclined,
    )) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (importDeclined)
          const _ImportStatusPill(label: 'Declined', error: true)
        else if (importPending)
          const _ImportStatusPill(label: 'Pending'),
        if (isLocked) const _LockStockIconPill(icon: Icons.lock_rounded),
        if (stockStatus == CatalogStockStatus.outOfStock)
          const _LockStockIconPill(icon: Icons.production_quantity_limits),
        if (stockStatus == CatalogStockStatus.mto)
          const _LockStockIconPill(icon: Icons.schedule_rounded),
      ],
    );
  }
}

class _ImportStatusPill extends StatelessWidget {
  const _ImportStatusPill({required this.label, this.error = false});

  final String label;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color:
            error
                ? AppColors.error.withValues(alpha: 0.92)
                : AppColors.warning.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}

class _LockStockIconPill extends StatelessWidget {
  const _LockStockIconPill({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 14, color: AppColors.textOnPrimary),
    );
  }
}

class ProductDetailsTagChip extends StatelessWidget {
  const ProductDetailsTagChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final display = label.startsWith('#') ? label : '#$label';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Text(
        display,
        style: AppTextStyles.caption(
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class ProductDetailsStoreTile extends StatelessWidget {
  const ProductDetailsStoreTile({
    super.key,
    required this.storeName,
    required this.storeLink,
    this.onTap,
  });

  final String storeName;
  final String storeLink;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border),
            bottom: BorderSide(color: AppColors.border),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.folder_rounded,
                color: AppColors.textOnPrimary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    storeName,
                    style: AppTextStyles.body(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(storeLink, style: AppTextStyles.caption()),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Telegram media-viewer filmstrip ("Preview all").
///
/// Free-flow horizontal scroll (no snap). Fast flings do **not** drive the
/// main pager (that was killing momentum); the pager updates when the user
/// slows to inspect, and once more on scroll-end. Highlight still tracks the
/// nearest centered thumb the whole time.
class ProductDetailsThumbStrip extends StatefulWidget {
  const ProductDetailsThumbStrip({
    super.key,
    required this.paths,
    required this.activeIndex,
    required this.controller,
    required this.onTapIndex,
    this.onScrollIndex,
    this.onScrollEnd,
    this.thumbhashes = const [],
  });

  /// Thumb width + gap (matches route offset math).
  static const double itemStride = 48;
  static const double thumbSize = 44;
  static const double gap = 4;

  /// Below this speed (px/s) the strip is "inspecting" → sync main photo.
  static const double inspectVelocityPxPerSec = 720;

  final List<String?> paths;
  final int activeIndex;
  final ScrollController controller;
  final ValueChanged<int> onTapIndex;

  /// Fired when the user slows on a thumb, and again on scroll-end.
  final ValueChanged<int>? onScrollIndex;
  final VoidCallback? onScrollEnd;
  final List<String> thumbhashes;

  /// Index whose thumb is centered for [offset].
  static int indexForOffset(double offset, int count) {
    if (count <= 1) return 0;
    return (offset / itemStride).round().clamp(0, count - 1);
  }

  @override
  State<ProductDetailsThumbStrip> createState() =>
      _ProductDetailsThumbStripState();
}

class _ProductDetailsThumbStripState extends State<ProductDetailsThumbStrip> {
  /// Finger / fling owned the strip until [ScrollEndNotification].
  bool _userDriven = false;

  /// Highlight follows scroll position (local only — avoids parent rebuilds).
  late final ValueNotifier<int> _visualIndex = ValueNotifier(widget.activeIndex);

  double _lastOffset = 0;
  int _lastMicros = 0;
  int? _lastEmittedIndex;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerTick);
  }

  @override
  void didUpdateWidget(covariant ProductDetailsThumbStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerTick);
      widget.controller.addListener(_onControllerTick);
    }
    if (!_userDriven &&
        oldWidget.activeIndex != widget.activeIndex &&
        widget.activeIndex != _visualIndex.value) {
      _visualIndex.value = widget.activeIndex;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerTick);
    _visualIndex.dispose();
    super.dispose();
  }

  void _onControllerTick() {
    if (!widget.controller.hasClients) return;
    final offset = widget.controller.offset;
    final now = DateTime.now().microsecondsSinceEpoch;
    var speed = 0.0;
    if (_lastMicros > 0) {
      final dt = (now - _lastMicros) / 1e6;
      if (dt > 0 && dt < 0.1) {
        speed = (offset - _lastOffset).abs() / dt;
      }
    }
    _lastOffset = offset;
    _lastMicros = now;

    final next = ProductDetailsThumbStrip.indexForOffset(
      offset,
      widget.paths.length,
    );
    if (next != _visualIndex.value) {
      _visualIndex.value = next;
    }

    if (!_userDriven) return;
    // Fast fling: leave the pager alone so ballistic scroll stays silky.
    if (speed > ProductDetailsThumbStrip.inspectVelocityPxPerSec) return;
    if (next == _lastEmittedIndex) return;
    _lastEmittedIndex = next;
    widget.onScrollIndex?.call(next);
  }

  void _emitSettled() {
    if (!widget.controller.hasClients) return;
    final index = ProductDetailsThumbStrip.indexForOffset(
      widget.controller.offset,
      widget.paths.length,
    );
    _visualIndex.value = index;
    if (index != _lastEmittedIndex) {
      _lastEmittedIndex = index;
      widget.onScrollIndex?.call(index);
    }
    widget.onScrollEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final paths = widget.paths;
    if (paths.length <= 1) return const SizedBox.shrink();
    return SizedBox(
      height: ProductDetailsThumbStrip.thumbSize + 6,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sidePad =
              ((constraints.maxWidth - ProductDetailsThumbStrip.thumbSize) / 2)
                  .clamp(0.0, double.infinity);
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.depth != 0) return false;
              if (notification is ScrollStartNotification &&
                  notification.dragDetails != null) {
                _userDriven = true;
                _lastEmittedIndex = null;
                _lastMicros = 0;
              }
              if (notification is ScrollEndNotification) {
                if (_userDriven) _emitSettled();
                _userDriven = false;
              }
              return false;
            },
            child: ListView.builder(
              controller: widget.controller,
              scrollDirection: Axis.horizontal,
              itemExtent: ProductDetailsThumbStrip.itemStride,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              cacheExtent: ProductDetailsThumbStrip.itemStride * 16,
              padding: EdgeInsets.symmetric(horizontal: sidePad),
              itemCount: paths.length,
              itemBuilder: (context, index) {
                final path = paths[index];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onTapIndex(index),
                  child: SizedBox(
                    width: ProductDetailsThumbStrip.itemStride,
                    child: Center(
                      child: ValueListenableBuilder<int>(
                        valueListenable: _visualIndex,
                        builder: (context, visual, child) {
                          final isActive = index == visual;
                          return Opacity(
                            opacity: isActive ? 1 : 0.72,
                            child: Transform.scale(
                              scale: isActive ? 1.06 : 1.0,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color:
                                        isActive
                                            ? AppColors.textOnPrimary
                                            : Colors.white.withValues(
                                              alpha: 0.28,
                                            ),
                                    width: isActive ? 1.5 : 0.5,
                                  ),
                                ),
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2.5),
                          child: SizedBox(
                            width: ProductDetailsThumbStrip.thumbSize,
                            height: ProductDetailsThumbStrip.thumbSize,
                            child:
                                path == null ||
                                        path.isEmpty ||
                                        !ProductImagePaths.isDisplayable(path)
                                    ? ColoredBox(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.35,
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.diamond_outlined,
                                          size: 16,
                                          color: AppColors.textOnPrimary,
                                        ),
                                      ),
                                    )
                                    : ProductMediaImage(
                                      path: path,
                                      fit: BoxFit.cover,
                                      thumbhash:
                                          index < widget.thumbhashes.length
                                              ? widget.thumbhashes[index]
                                              : null,
                                    ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Full-bleed photo with double-tap + pinch zoom / pan that cooperates with a
/// parent [PageView]: page swipe with one finger at 1×; pinch or double-tap
/// enters zoom; pan only while zoomed; pinch-out / double-tap exits.
class ProductDetailsZoomablePhoto extends StatefulWidget {
  const ProductDetailsZoomablePhoto({
    super.key,
    required this.path,
    required this.onTap,
    required this.onZoomChanged,
    this.onMultiTouchChanged,
    this.isActive = true,
    this.thumbhash,
    this.allowsDeepZoom = true,
  });

  final String path;
  final VoidCallback onTap;
  final ValueChanged<bool> onZoomChanged;

  /// Two fingers down — parent should lock [PageView] so pinch can start at 1×.
  final ValueChanged<bool>? onMultiTouchChanged;

  /// When this page is no longer the active [PageView] page, zoom resets.
  final bool isActive;

  /// Instant blur while the master CDN WebP loads (Med stage).
  final String? thumbhash;

  /// When false (`quality: low`), pinch is limited to light zoom only.
  final bool allowsDeepZoom;

  @override
  State<ProductDetailsZoomablePhoto> createState() =>
      _ProductDetailsZoomablePhotoState();
}

class _ProductDetailsZoomablePhotoState
    extends State<ProductDetailsZoomablePhoto>
    with SingleTickerProviderStateMixin {
  static const _zoomEpsilon = 1.05;

  late final TransformationController _transform;
  late final AnimationController _resetController;
  Animation<Matrix4>? _resetAnimation;
  bool _zoomed = false;
  int _pointerCount = 0;
  bool _multiTouch = false;

  /// Locked at first build so warm + paint + pinch remounts share one ImageCache key.
  late final int _decodeCacheWidth = CatalogImageCache.fullCacheWidth();

  @override
  void initState() {
    super.initState();
    _transform = TransformationController();
    _transform.addListener(_onTransformChanged);
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(() {
      final animation = _resetAnimation;
      if (animation == null) return;
      _transform.value = animation.value;
    });
  }

  @override
  void dispose() {
    if (_zoomed) widget.onZoomChanged(false);
    if (_multiTouch) widget.onMultiTouchChanged?.call(false);
    _resetController.dispose();
    _transform.removeListener(_onTransformChanged);
    _transform.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProductDetailsZoomablePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive && _zoomed) {
      _transform.value = Matrix4.identity();
    }
  }

  void _setMultiTouch(bool value) {
    if (_multiTouch == value) return;
    _multiTouch = value;
    widget.onMultiTouchChanged?.call(value);
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerCount++;
    if (_pointerCount >= 2) _setMultiTouch(true);
  }

  void _onPointerUp(PointerEvent event) {
    if (_pointerCount > 0) _pointerCount--;
    if (_pointerCount < 2) _setMultiTouch(false);
  }

  void _onTransformChanged() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > _zoomEpsilon;
    if (zoomed == _zoomed) return;
    _zoomed = zoomed;
    widget.onZoomChanged(zoomed);
    // Rebuild so panEnabled / boundary follow zoom state — photo key stays stable.
    if (mounted) setState(() {});
  }

  void _animateToIdentity() {
    _resetAnimation = Matrix4Tween(
      begin: _transform.value,
      end: Matrix4.identity(),
    ).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOut),
    );
    _resetController.forward(from: 0);
  }

  void _onDoubleTap() {
    if (!widget.allowsDeepZoom) return;
    if (_zoomed) {
      _animateToIdentity();
      return;
    }
    // Zoom toward center (~2.2×) for a quick inspect gesture.
    final size = MediaQuery.sizeOf(context);
    const scale = 2.2;
    final dx = size.width * (1 - scale) / 2;
    final dy = size.height * (1 - scale) / 2;
    final next = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale);
    _resetAnimation = Matrix4Tween(
      begin: _transform.value,
      end: next,
    ).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOut),
    );
    _resetController.forward(from: 0);
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    // Snap back when the user pinches out to ~1× so PageView can swipe again.
    if (_transform.value.getMaxScaleOnAxis() <= _zoomEpsilon) {
      _transform.value = Matrix4.identity();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxScale = widget.allowsDeepZoom ? 4.0 : 1.15;
    // High stage: pinch the same already-decoded master buffer (stable cache key).
    final photo = RepaintBoundary(
      child: ProductMediaImage(
        path: widget.path,
        fit: BoxFit.contain,
        thumbhash: widget.thumbhash,
        decodeCacheWidth: _decodeCacheWidth,
        // Low during page swipes (inactive neighbors); medium when active.
        filterQuality:
            widget.isActive ? FilterQuality.medium : FilterQuality.low,
      ),
    );
    final framed = SizedBox(
      width: size.width,
      height: size.height,
      child: Center(child: photo),
    );

    // Always mount [InteractiveViewer] so pinch can start at 1×. One-finger
    // pan stays off until zoomed so [PageView] keeps horizontal swipes; parent
    // locks the pager while two fingers are down ([onMultiTouchChanged]).
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: maxScale,
        panEnabled: _zoomed,
        scaleEnabled: true,
        clipBehavior: Clip.hardEdge,
        boundaryMargin:
            _zoomed ? const EdgeInsets.all(64) : EdgeInsets.zero,
        onInteractionEnd: _onInteractionEnd,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onDoubleTap: widget.allowsDeepZoom ? _onDoubleTap : null,
          child: framed,
        ),
      ),
    );
  }
}
