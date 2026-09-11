import 'package:flutter/material.dart';
import 'package:project_c/bloc/add_store_product/add_store_product_bloc.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';

class ProductImageCarousel extends StatefulWidget {
  const ProductImageCarousel({
    super.key,
    required this.images,
    required this.isPicking,
    this.onDelete,
    this.onAddPressed,
    this.readOnly = false,
  });

  final List<GalleryImageItem> images;
  final bool isPicking;
  final ValueChanged<String>? onDelete;
  final VoidCallback? onAddPressed;
  final bool readOnly;

  @override
  State<ProductImageCarousel> createState() => _ProductImageCarouselState();
}

class _ProductImageCarouselState extends State<ProductImageCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant ProductImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.images.isEmpty) {
      _currentPage = 0;
      return;
    }
    if (_currentPage >= widget.images.length) {
      _currentPage = widget.images.length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_pageController.hasClients) return;
        _pageController.jumpToPage(_currentPage);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return _EmptyImageSlot(
        isPicking: widget.isPicking,
        onAddPressed: widget.readOnly ? null : widget.onAddPressed,
      );
    }

    final showActions =
        !widget.readOnly &&
        (widget.onDelete != null || widget.onAddPressed != null);

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: widget.images.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    final item = widget.images[index];
                    return _ImagePage(item: item);
                  },
                ),
                if (showActions)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Row(
                      children: [
                        if (widget.onDelete != null)
                          _CircleActionButton(
                            icon: Icons.delete_outline_rounded,
                            onTap: () {
                              final id = widget.images[_currentPage].id;
                              widget.onDelete!(id);
                            },
                          ),
                        if (widget.onDelete != null &&
                            widget.onAddPressed != null)
                          const SizedBox(width: 8),
                        if (widget.onAddPressed != null)
                          _CircleActionButton(
                            icon: Icons.add_photo_alternate_outlined,
                            onTap:
                                widget.isPicking ? null : widget.onAddPressed,
                          ),
                      ],
                    ),
                  ),
                if (widget.images.length > 1)
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
                        '${_currentPage + 1}/${widget.images.length}',
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
        if (widget.images.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.images.length, (index) {
              final isActive = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : AppColors.border,
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

class _ImagePage extends StatelessWidget {
  const _ImagePage({required this.item});

  final GalleryImageItem item;

  @override
  Widget build(BuildContext context) {
    if (!item.isPlaceholder && item.filePath != null) {
      return ProductMediaImage(path: item.filePath!);
    }
    return const _FallbackThumb();
  }
}

class _FallbackThumb extends StatelessWidget {
  const _FallbackThumb();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceSecondary,
            AppColors.primary.withValues(alpha: 0.4),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.diamond_outlined,
          size: 42,
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}

class _EmptyImageSlot extends StatelessWidget {
  const _EmptyImageSlot({required this.isPicking, required this.onAddPressed});

  final bool isPicking;
  final VoidCallback? onAddPressed;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: isPicking ? null : onAddPressed,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child:
                isPicking
                    ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                    : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 34,
                          color: AppColors.accent,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add product photos',
                          style: AppTextStyles.label(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 18, color: AppColors.textOnPrimary),
        ),
      ),
    );
  }
}
