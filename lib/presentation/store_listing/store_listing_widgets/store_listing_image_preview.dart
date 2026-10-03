import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';

/// Centered store-image preview over a light iOS-style blur.
///
/// Dismiss by tapping outside the image (no close button).
Future<void> showStoreListingImagePreview(
  BuildContext context, {
  required List<String> imageUrls,
  int initialIndex = 0,
}) {
  final urls =
      imageUrls.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (urls.isEmpty) return Future<void>.value();

  final start = initialIndex.clamp(0, urls.length - 1);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _StoreListingImagePreview(
        imageUrls: urls,
        initialIndex: start,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

class _StoreListingImagePreview extends StatefulWidget {
  const _StoreListingImagePreview({
    required this.imageUrls,
    required this.initialIndex,
  });

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<_StoreListingImagePreview> createState() =>
      _StoreListingImagePreviewState();
}

class _StoreListingImagePreviewState extends State<_StoreListingImagePreview> {
  late final PageController _pageController;
  late int _page;

  bool get _canScroll => widget.imageUrls.length > 1;

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex;
    _pageController = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final side = (size.shortestSide * 0.82).clamp(240.0, 420.0);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // iOS-like ultra-thin material: mild blur + light dim (not heavy fog).
          GestureDetector(
            onTap: _close,
            behavior: HitTestBehavior.opaque,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.22),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Absorb taps on the image so only outside dismisses.
                GestureDetector(
                  onTap: () {},
                  child: SizedBox(
                    width: side,
                    height: side,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const ColoredBox(color: AppColors.surfaceSecondary),
                          PageView.builder(
                            controller: _pageController,
                            physics:
                                _canScroll
                                    ? const BouncingScrollPhysics()
                                    : const NeverScrollableScrollPhysics(),
                            itemCount: widget.imageUrls.length,
                            onPageChanged: (index) {
                              setState(() => _page = index);
                            },
                            itemBuilder: (context, index) {
                              return ProductMediaImage(
                                path: widget.imageUrls[index],
                                fit: BoxFit.cover,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_canScroll) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < widget.imageUrls.length; i++)
                        Container(
                          width: i == _page ? 8 : 6,
                          height: i == _page ? 8 : 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                i == _page
                                    ? AppColors.textPrimary.withValues(
                                      alpha: 0.85,
                                    )
                                    : AppColors.textPrimary.withValues(
                                      alpha: 0.35,
                                    ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_page + 1} / ${widget.imageUrls.length}',
                    style: AppTextStyles.caption(
                      color: AppColors.textPrimary.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
