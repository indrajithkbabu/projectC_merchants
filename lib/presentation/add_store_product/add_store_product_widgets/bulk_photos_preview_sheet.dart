import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project_c/bloc/add_store_product/add_store_product_bloc.dart';
import 'package:project_c/bloc/bulk_upload/bulk_upload_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_gallery_picker.dart';
import 'package:project_c/helper/product_image_cropper.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/media_source_sheet.dart';
import 'package:project_c/presentation/add_store_product/add_store_product_widgets/product_image_carousel.dart';

/// Photo preview sheet (same pattern as [add_product_form_route]): carousel with
/// optional delete / add / edit (crop, draw, text).
///
/// [readOnly] blocks add/delete (used in edit/refine). Image editing
/// (crop / draw / text) stays available unless [allowImageEdit] is false.
Future<void> showBulkPhotosPreviewSheet({
  required BuildContext context,
  int initialIndex = 0,
  bool readOnly = false,
  bool allowImageEdit = true,
  Set<String>? onlyItemIds,
}) {
  final bloc = context.read<BulkUploadBloc>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    builder: (sheetContext) {
      return BlocProvider.value(
        value: bloc,
        child: _BulkPhotosPreviewSheetBody(
          initialIndex: initialIndex,
          readOnly: readOnly,
          allowImageEdit: allowImageEdit,
          onlyItemIds: onlyItemIds,
        ),
      );
    },
  );
}

class _BulkPhotosPreviewSheetBody extends StatefulWidget {
  const _BulkPhotosPreviewSheetBody({
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
  State<_BulkPhotosPreviewSheetBody> createState() =>
      _BulkPhotosPreviewSheetBodyState();
}

class _BulkPhotosPreviewSheetBodyState
    extends State<_BulkPhotosPreviewSheetBody> {
  final _imagePicker = ImagePicker();
  bool _picking = false;

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

  Future<void> _cropImage(GalleryImageItem image) async {
    final path = image.filePath?.trim();
    if (path == null || path.isEmpty || _picking || !widget.allowImageEdit) {
      return;
    }

    setState(() => _picking = true);
    try {
      final cropped = await ProductImageCropper.cropOne(
        path,
        context: context,
      );
      if (!mounted || cropped == null || cropped == path) return;
      context.read<BulkUploadBloc>().add(
        BulkUploadItemImageReplaced(itemId: image.id, imagePath: cropped),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _cropAll(List<GalleryImageItem> images) async {
    if (_picking || !widget.allowImageEdit || images.isEmpty) return;

    setState(() => _picking = true);
    try {
      final paths = [
        for (final image in images) image.filePath!.trim(),
      ];
      final cropped = await ProductImageCropper.cropGroup(
        paths,
        context: context,
      );
      if (!mounted) return;
      final bloc = context.read<BulkUploadBloc>();
      for (var i = 0; i < images.length; i++) {
        if (cropped[i] != paths[i]) {
          bloc.add(
            BulkUploadItemImageReplaced(
              itemId: images[i].id,
              imagePath: cropped[i],
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _addMore(BuildContext sheetContext) async {
    if (_picking || widget.readOnly) return;
    final bloc = context.read<BulkUploadBloc>();
    final source = await showMediaSourceSheet(
      sheetContext,
      title: 'Add photos',
      subtitle: 'Capture new photos or pick from your gallery',
    );
    if (!mounted || !sheetContext.mounted || source == null) return;

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
        if (!sheetContext.mounted) return;
        // Same drag_select gallery used from store profile Add products.
        paths.addAll(await ProductGalleryPicker.pickImagePaths(sheetContext));
      }
      if (!mounted || paths.isEmpty) return;

      // Close sheet first (same as form route), then append so the strip updates.
      // Crop / draw / text stays optional from the photo strip after append.
      if (sheetContext.mounted) {
        Navigator.of(sheetContext).pop();
      }
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
    return SafeArea(
      child: Padding(
        padding: AppPadding.screen(top: 12, bottom: 24),
        child: BlocBuilder<BulkUploadBloc, BulkUploadState>(
          builder: (context, state) {
            final images = _visibleImages(state);
            final maxIndex = images.isEmpty ? 0 : images.length - 1;
            final initial = widget.initialIndex.clamp(0, maxIndex);
            final canDelete = !widget.readOnly && state.items.length > 1;
            final canCrop = widget.allowImageEdit && images.isNotEmpty;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Photos',
                      style: AppTextStyles.headline(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (canCrop && images.length > 1) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Edit all',
                        onPressed: _picking ? null : () => _cropAll(images),
                        icon: const Icon(Icons.edit_outlined),
                        color: AppColors.accent,
                      ),
                    ],
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ProductImageCarousel(
                  key: ValueKey(
                    '${images.map((e) => '${e.id}:${e.filePath}').join(',')}_$initial',
                  ),
                  images: images,
                  isPicking: _picking,
                  // Carousel "readOnly" only when add/delete AND edit are off.
                  readOnly: widget.readOnly && !widget.allowImageEdit,
                  initialIndex: initial,
                  onCrop:
                      canCrop
                          ? (imageId) {
                            final image = images.firstWhere(
                              (e) => e.id == imageId,
                              orElse: () => images.first,
                            );
                            _cropImage(image);
                          }
                          : null,
                  onDelete:
                      canDelete
                          ? (imageId) => context.read<BulkUploadBloc>().add(
                            BulkUploadItemRemoved(imageId),
                          )
                          : null,
                  onAddPressed:
                      widget.readOnly ? null : () => _addMore(context),
                ),
                if (!widget.readOnly && state.items.length <= 1) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Keep at least one photo in this upload.',
                    style: AppTextStyles.caption(),
                  ),
                ],
                if (widget.readOnly && widget.allowImageEdit) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Tap edit to crop, draw, or add text. Save changes on the preview screen.',
                    style: AppTextStyles.caption(),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
