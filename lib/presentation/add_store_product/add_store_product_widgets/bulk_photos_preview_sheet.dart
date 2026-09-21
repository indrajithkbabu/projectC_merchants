import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project_c/bloc/add_store_product/add_store_product_bloc.dart';
import 'package:project_c/bloc/bulk_upload/bulk_upload_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/presentation/add_store_product/add_store_product_widgets/product_image_carousel.dart';

/// Photo preview sheet (same pattern as [add_product_form_route]): carousel with
/// optional delete / add. Create flow allows edits; edit/refine is read-only.
Future<void> showBulkPhotosPreviewSheet({
  required BuildContext context,
  int initialIndex = 0,
  bool readOnly = false,
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
          onlyItemIds: onlyItemIds,
        ),
      );
    },
  );
}

Future<ImageSource?> _pickImageSource(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: Text('Camera', style: AppTextStyles.body()),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: Text('Gallery', style: AppTextStyles.body()),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _BulkPhotosPreviewSheetBody extends StatefulWidget {
  const _BulkPhotosPreviewSheetBody({
    required this.initialIndex,
    required this.readOnly,
    this.onlyItemIds,
  });

  final int initialIndex;
  final bool readOnly;
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
          if (!image.isPlaceholder && (image.filePath?.trim().isNotEmpty ?? false))
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

  Future<void> _addMore(BuildContext sheetContext) async {
    if (_picking || widget.readOnly) return;
    final bloc = context.read<BulkUploadBloc>();
    final source = await _pickImageSource(sheetContext);
    if (!mounted || source == null) return;

    setState(() => _picking = true);
    try {
      final paths = <String>[];
      if (source == ImageSource.camera) {
        final photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1920,
          maxHeight: 1920,
        );
        if (photo != null) paths.add(photo.path);
      } else {
        final photos = await _imagePicker.pickMultiImage(
          imageQuality: 85,
          maxWidth: 1920,
          maxHeight: 1920,
        );
        for (final photo in photos) {
          paths.add(photo.path);
        }
      }
      if (!mounted || paths.isEmpty) return;
      // Close sheet first (same as form route), then append so the strip updates.
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
                    '${images.map((e) => e.id).join(',')}_$initial',
                  ),
                  images: images,
                  isPicking: _picking,
                  readOnly: widget.readOnly,
                  initialIndex: initial,
                  onDelete:
                      canDelete
                          ? (imageId) => context.read<BulkUploadBloc>().add(
                            BulkUploadItemRemoved(imageId),
                          )
                          : null,
                  onAddPressed:
                      widget.readOnly
                          ? null
                          : () => _addMore(context),
                ),
                if (!widget.readOnly && state.items.length <= 1) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Keep at least one photo in this upload.',
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
