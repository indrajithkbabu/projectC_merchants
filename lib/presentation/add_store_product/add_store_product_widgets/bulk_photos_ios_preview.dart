import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project_c/bloc/add_store_product/add_store_product_bloc.dart';
import 'package:project_c/bloc/bulk_upload/bulk_upload_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_gallery_picker.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/product_image_cropper.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/media_source_sheet.dart';

/// iOS-style centered photo preview (blur backdrop) with the same add / delete /
/// edit actions as [showBulkPhotosPreviewSheet], plus a bottom thumbnail scroller.
Future<void> showBulkPhotosIosPreview({
  required BuildContext context,
  int initialIndex = 0,
  bool readOnly = false,
  bool allowImageEdit = true,
  Set<String>? onlyItemIds,
}) {
  final bloc = context.read<BulkUploadBloc>();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return BlocProvider.value(
        value: bloc,
        child: _BulkPhotosIosPreview(
          initialIndex: initialIndex,
          readOnly: readOnly,
          allowImageEdit: allowImageEdit,
          onlyItemIds: onlyItemIds,
        ),
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

class _BulkPhotosIosPreview extends StatefulWidget {
  const _BulkPhotosIosPreview({
    required this.initialIndex,
    required this.readOnly,
    required this.allowImageEdit,
    this.onlyItemIds,
  });

  final int initialIndex;
  final bool readOnly;
  final bool allowImageEdit;
  final Set<String>? onlyItemIds;

  @override
  State<_BulkPhotosIosPreview> createState() => _BulkPhotosIosPreviewState();
}

class _BulkPhotosIosPreviewState extends State<_BulkPhotosIosPreview> {
  final _imagePicker = ImagePicker();
  late final PageController _pageController;
  late final ScrollController _thumbController;
  late int _page;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex < 0 ? 0 : widget.initialIndex;
    _pageController = PageController(initialPage: _page);
    _thumbController = ScrollController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbController.dispose();
    super.dispose();
  }

  List<GalleryImageItem> _visibleImages(BulkUploadState state) {
    final filter = widget.onlyItemIds;
    if (filter == null || filter.isEmpty) {
      return [
        for (final image in state.images)
          if (!image.isPlaceholder &&
              (image.filePath?.trim().isNotEmpty ?? false))
            image,
      ];
    }
    return [
      for (final image in state.images)
        if (filter.contains(image.id) &&
            !image.isPlaceholder &&
            (image.filePath?.trim().isNotEmpty ?? false))
          image,
    ];
  }

  void _close() => Navigator.of(context).maybePop();

  void _goToPage(int index) {
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _ensureThumbVisible(int index) {
    if (!_thumbController.hasClients) return;
    const thumb = 56.0;
    const gap = 8.0;
    final target = index * (thumb + gap);
    final view = _thumbController.position.viewportDimension;
    final offset = _thumbController.offset;
    if (target < offset) {
      _thumbController.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else if (target + thumb > offset + view) {
      _thumbController.animateTo(
        target + thumb - view,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _cropImage(GalleryImageItem image) async {
    final path = image.filePath?.trim();
    if (path == null || path.isEmpty || _picking || !widget.allowImageEdit) {
      return;
    }

    setState(() => _picking = true);
    try {
      final cropped = await ProductImageCropper.cropOne(path, context: context);
      if (!mounted || cropped == null || cropped == path) return;
      context.read<BulkUploadBloc>().add(
        BulkUploadItemImageReplaced(itemId: image.id, imagePath: cropped),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _addMore(BuildContext hostContext) async {
    if (_picking || widget.readOnly) return;
    final bloc = context.read<BulkUploadBloc>();
    final source = await showMediaSourceSheet(
      hostContext,
      title: 'Add photos',
      subtitle: 'Capture new photos or pick from your gallery',
    );
    if (!mounted || !hostContext.mounted || source == null) return;

    setState(() => _picking = true);
    try {
      final paths = <String>[];
      if (source == MediaPickSource.camera) {
        final photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1920,
          maxHeight: 1920,
        );
        if (photo != null) paths.add(photo.path);
      } else {
        if (!hostContext.mounted) return;
        paths.addAll(await ProductGalleryPicker.pickImagePaths(hostContext));
      }
      if (!mounted || paths.isEmpty) return;
      // Keep preview open so the bottom scroller updates (same events as sheet).
      bloc.add(BulkUploadImagesAdded(paths));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open image picker right now.')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
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
          SafeArea(
            child: BlocBuilder<BulkUploadBloc, BulkUploadState>(
              builder: (context, state) {
                final images = _visibleImages(state);
                if (images.isEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _close();
                  });
                  return const SizedBox.shrink();
                }

                final maxIndex = images.length - 1;
                if (_page > maxIndex) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() => _page = maxIndex);
                    if (_pageController.hasClients) {
                      _pageController.jumpToPage(maxIndex);
                    }
                  });
                }

                final page = _page.clamp(0, maxIndex);
                final canDelete = !widget.readOnly && state.items.length > 1;
                final canCrop = widget.allowImageEdit && images.isNotEmpty;
                final showActions =
                    canCrop || canDelete || !widget.readOnly;

                return Column(
                  children: [
                    const Spacer(),
                    // Same full-width square presentation as bottomsheet carousel.
                    GestureDetector(
                      onTap: () {},
                      child: Padding(
                        padding: AppPadding.screenHorizontal,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                const ColoredBox(
                                  color: AppColors.surfaceSecondary,
                                ),
                                PageView.builder(
                                  controller: _pageController,
                                  itemCount: images.length,
                                  onPageChanged: (index) {
                                    setState(() => _page = index);
                                    _ensureThumbVisible(index);
                                  },
                                  itemBuilder: (context, index) {
                                    // Default fit matches ProductImageCarousel.
                                    return ProductMediaImage(
                                      path: images[index].filePath!,
                                    );
                                  },
                                ),
                                if (showActions)
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: Row(
                                      children: [
                                        if (canCrop) ...[
                                          _CircleAction(
                                            icon: Icons.edit_outlined,
                                            onTap:
                                                _picking
                                                    ? null
                                                    : () => _cropImage(
                                                      images[page],
                                                    ),
                                          ),
                                          if (canDelete || !widget.readOnly)
                                            const SizedBox(width: 8),
                                        ],
                                        if (canDelete) ...[
                                          _CircleAction(
                                            icon:
                                                Icons.delete_outline_rounded,
                                            onTap:
                                                () => context
                                                    .read<BulkUploadBloc>()
                                                    .add(
                                                      BulkUploadItemRemoved(
                                                        images[page].id,
                                                      ),
                                                    ),
                                          ),
                                          if (!widget.readOnly)
                                            const SizedBox(width: 8),
                                        ],
                                        if (!widget.readOnly)
                                          _CircleAction(
                                            icon:
                                                Icons
                                                    .add_photo_alternate_outlined,
                                            onTap:
                                                _picking
                                                    ? null
                                                    : () => _addMore(context),
                                          ),
                                      ],
                                    ),
                                  ),
                                if (images.length > 1)
                                  Positioned(
                                    left: 10,
                                    bottom: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.45,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${page + 1}/${images.length}',
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
                      ),
                    ),
                    if (!widget.readOnly && state.items.length <= 1) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Keep at least one photo in this upload.',
                        style: AppTextStyles.caption(),
                      ),
                    ],
                    const Spacer(),
                    if (images.length > 1) ...[
                      SizedBox(
                        height: 64,
                        child: ListView.separated(
                          controller: _thumbController,
                          scrollDirection: Axis.horizontal,
                          primary: false,
                          padding: AppPadding.screenHorizontal,
                          itemCount: images.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final selected = index == page;
                            return GestureDetector(
                              onTap: () => _goToPage(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        selected
                                            ? AppColors.primary
                                            : AppColors.border,
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: ProductMediaImage(
                                  path: images[index].filePath!,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else
                      const SizedBox(height: 12),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap});

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
