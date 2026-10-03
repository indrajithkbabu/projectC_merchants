import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
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
    final paths = widget.product.imagePaths;
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
                    if (paths.isEmpty) {
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
      child: const Center(
        child: Icon(
          Icons.diamond_outlined,
          size: 48,
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}

class ProductDetailsCategoryPill extends StatelessWidget {
  const ProductDetailsCategoryPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final text = label.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textOnPrimary,
        ),
      ),
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
        decoration: const BoxDecoration(
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
              child: const Icon(
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
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal thumbnail strip for product details ("Preview all").
class ProductDetailsThumbStrip extends StatelessWidget {
  const ProductDetailsThumbStrip({
    super.key,
    required this.paths,
    required this.activeIndex,
    required this.controller,
    required this.onTapIndex,
  });

  final List<String?> paths;
  final int activeIndex;
  final ScrollController controller;
  final ValueChanged<int> onTapIndex;

  @override
  Widget build(BuildContext context) {
    if (paths.length <= 1) return const SizedBox.shrink();
    return SizedBox(
      height: 72,
      child: Center(
        child: ListView.separated(
          controller: controller,
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          itemCount: paths.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final isActive = index == activeIndex;
            final path = paths[index];
            return GestureDetector(
              onTap: () => onTapIndex(index),
              child: Container(
                width: 64,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        isActive
                            ? AppColors.primary
                            : Colors.white.withValues(alpha: 0.28),
                    width: isActive ? 2 : 1,
                  ),
                ),
                child:
                    path == null ||
                            path.isEmpty ||
                            !ProductImagePaths.isDisplayable(path)
                        ? ColoredBox(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          child: const Center(
                            child: Icon(
                              Icons.diamond_outlined,
                              size: 22,
                              color: AppColors.textOnPrimary,
                            ),
                          ),
                        )
                        : ProductMediaImage(path: path, fit: BoxFit.cover),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Full-bleed photo with pinch-zoom / pan that cooperates with a parent
/// [PageView]: page swipe when at 1×, pan only while zoomed.
class ProductDetailsZoomablePhoto extends StatefulWidget {
  const ProductDetailsZoomablePhoto({
    super.key,
    required this.path,
    required this.onTap,
    required this.onZoomChanged,
    this.isActive = true,
  });

  final String path;
  final VoidCallback onTap;
  final ValueChanged<bool> onZoomChanged;

  /// When this page is no longer the active [PageView] page, zoom resets.
  final bool isActive;

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

  void _onTransformChanged() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > _zoomEpsilon;
    if (zoomed == _zoomed) return;
    _zoomed = zoomed;
    widget.onZoomChanged(zoomed);
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return InteractiveViewer(
      transformationController: _transform,
      minScale: 1,
      maxScale: 4,
      // Let PageView own horizontal swipes at 1×; pan only while zoomed.
      panEnabled: _zoomed,
      scaleEnabled: true,
      clipBehavior: Clip.hardEdge,
      boundaryMargin: _zoomed ? const EdgeInsets.all(64) : EdgeInsets.zero,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTap: _onDoubleTap,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Center(
            child: ProductMediaImage(
              path: widget.path,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
