import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project_c/bloc/add_store_product/add_store_product_bloc.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/presentation/add_store_product/add_store_product_widgets/product_image_carousel.dart';
import 'package:project_c/webservice/store/store_request.dart';

/// Store showcase photo sheet — same carousel pattern as bulk/group preview.
Future<void> showStoreImagesManagerSheet(BuildContext context) async {
  final bloc = context.read<StoreProfileBloc>();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    builder: (sheetContext) {
      return BlocProvider.value(
        value: bloc,
        child: const _StoreImagesManagerSheetBody(),
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

class _StoreImagesManagerSheetBody extends StatefulWidget {
  const _StoreImagesManagerSheetBody();

  @override
  State<_StoreImagesManagerSheetBody> createState() =>
      _StoreImagesManagerSheetBodyState();
}

class _StoreImagesManagerSheetBodyState
    extends State<_StoreImagesManagerSheetBody> {
  final _imagePicker = ImagePicker();
  bool _picking = false;

  List<GalleryImageItem> _toGalleryItems(StoreProfileState state) {
    return [
      for (final image in state.storeImages)
        if (image.url.trim().isNotEmpty)
          GalleryImageItem(
            id: (image.id?.trim().isNotEmpty ?? false)
                ? image.id!.trim()
                : 'url_${image.url.hashCode}',
            filePath: image.url.trim(),
            assetId: image.id?.trim(),
            isPlaceholder: false,
          ),
    ];
  }

  Future<void> _addMore(BuildContext sheetContext) async {
    if (_picking) return;
    final bloc = context.read<StoreProfileBloc>();
    final state = bloc.state;
    if (!state.isOwnStore) return;

    final remaining = StoreRequest.maxStoreImages - state.storeImages.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'A store can have at most ${StoreRequest.maxStoreImages} showcase images.',
          ),
        ),
      );
      return;
    }

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
      bloc.add(
        StoreProfileAppendImagesRequested(paths.take(remaining).toList()),
      );
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
        child: BlocBuilder<StoreProfileBloc, StoreProfileState>(
          builder: (context, state) {
            final images = _toGalleryItems(state);
            final canEdit = state.isOwnStore;
            final canAdd =
                canEdit && images.length < StoreRequest.maxStoreImages;
            final canDelete = canEdit && images.isNotEmpty;
            final isBusy = state.isUpdatingStoreImages || _picking;

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
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Up to ${StoreRequest.maxStoreImages} showcase images.',
                    style: AppTextStyles.caption(),
                  ),
                ),
                const SizedBox(height: 8),
                ProductImageCarousel(
                  key: ValueKey(
                    '${images.map((e) => e.id).join(',')}_${state.isUpdatingStoreImages}',
                  ),
                  images: images,
                  isPicking: isBusy,
                  emptyLabel: 'Add store photos',
                  readOnly: !canEdit,
                  onDelete:
                      canDelete
                          ? (imageId) {
                            final id = imageId.trim();
                            if (id.isEmpty || id.startsWith('url_')) return;
                            context.read<StoreProfileBloc>().add(
                              StoreProfileDeleteImageRequested(id),
                            );
                          }
                          : null,
                  onAddPressed:
                      canAdd && !isBusy ? () => _addMore(context) : null,
                ),
                if (canEdit && images.length >= StoreRequest.maxStoreImages) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Limit reached · remove a photo to add another.',
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
