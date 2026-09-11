import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project_c/bloc/add_store_product/add_store_product_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/primary_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/presentation/add_store_product/add_store_product_widgets/product_form_widgets.dart';
import 'package:project_c/presentation/add_store_product/add_store_product_widgets/product_image_carousel.dart';

class AddProductFormRoute extends StatefulWidget {
  const AddProductFormRoute({super.key});

  @override
  State<AddProductFormRoute> createState() => _AddProductFormRouteState();
}

class _AddProductFormRouteState extends State<AddProductFormRoute> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagController;

  @override
  void initState() {
    super.initState();
    final state = context.read<AddStoreProductBloc>().state;
    _titleController = TextEditingController(text: state.title);
    _descriptionController = TextEditingController(text: state.description);
    _tagController = TextEditingController(text: state.tagDraft);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _showAddImageOptions() async {
    final source = await showModalBottomSheet<ImageSource>(
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
    if (!mounted || source == null) return;
    context.read<AddStoreProductBloc>().add(
      AddStoreProductAddMoreImagesPressed(source),
    );
  }

  Future<void> _openImagePreview({required bool readOnly}) async {
    final bloc = context.read<AddStoreProductBloc>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) {
        return BlocProvider.value(
          value: bloc,
          child: SafeArea(
            child: Padding(
              padding: AppPadding.screen(top: 12, bottom: 24),
              child: BlocBuilder<AddStoreProductBloc, AddStoreProductState>(
                builder: (context, state) {
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
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ProductImageCarousel(
                        images: state.selectedImages,
                        isPicking: state.isPickingImages,
                        readOnly: readOnly,
                        onDelete:
                            readOnly
                                ? null
                                : (imageId) => context
                                    .read<AddStoreProductBloc>()
                                    .add(AddStoreProductImageRemoved(imageId)),
                        onAddPressed:
                            readOnly
                                ? null
                                : () async {
                                  Navigator.of(sheetContext).pop();
                                  await _showAddImageOptions();
                                },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AddStoreProductBloc, AddStoreProductState>(
          listenWhen:
              (prev, curr) =>
                  curr.errorMessage != null &&
                  curr.errorMessage != prev.errorMessage,
          listener: (context, state) {
            final message = state.errorMessage?.trim();
            if (message == null || message.isEmpty) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
            context.read<AddStoreProductBloc>().add(
              const AddStoreProductClearMessage(),
            );
          },
        ),
        BlocListener<AddStoreProductBloc, AddStoreProductState>(
          listenWhen: (prev, curr) => curr.isPublished && !prev.isPublished,
          listener: (context, state) {
            context.read<AddStoreProductBloc>().add(
              const AddStoreProductClearPublished(),
            );
            final product = state.publishedProduct;
            if (product == null) {
              Navigator.of(context).pop();
              return;
            }
            final productPayload = <String, Object?>{
              ...product.toMap(),
              if (state.publishedRevision != null)
                'revision': state.publishedRevision,
              if (state.publishedApiTag != null)
                'apiTag': state.publishedApiTag,
              if (state.replacedListingId != null)
                'replacedListingId': state.replacedListingId,
            };
            Navigator.of(context).pop(productPayload);
          },
        ),
      ],
      child: ScreenWrapper(
        backgroundColor: AppColors.background,
        statusBarIconBrightness: Brightness.dark,
        child: BlocBuilder<AddStoreProductBloc, AddStoreProductState>(
          builder: (context, state) {
            final images = state.selectedImages;
            final isEdit = state.isEditMode;
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: AppPadding.screen(
                      top: ScreenWrapper.statusBarTop(context),
                      bottom: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AppBackButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                            Expanded(
                              child: Text(
                                isEdit ? 'Edit product' : 'New product',
                                style: AppTextStyles.headline(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ProductPreviewImage(
                              item: state.primaryImage,
                              imageCount: images.length,
                              onTap:
                                  images.isEmpty
                                      ? _showAddImageOptions
                                      : () => _openImagePreview(readOnly: false),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Title',
                                    style: AppTextStyles.label(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                  TextField(
                                    controller: _titleController,
                                    onChanged:
                                        (value) => context
                                            .read<AddStoreProductBloc>()
                                            .add(
                                              AddStoreProductTitleChanged(
                                                value,
                                              ),
                                            ),
                                    style: AppTextStyles.body(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Enter product title',
                                      hintStyle: AppTextStyles.hint(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      enabledBorder: const UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      focusedBorder: const UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: AppColors.primary,
                                          width: 1.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    isEdit && images.length > 1
                                        ? 'Applies to every photo in this product.'
                                        : 'This is what shows under the photo in your store.',
                                    style: AppTextStyles.caption(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Tags',
                          style: AppTextStyles.label(
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in state.tags)
                              ProductTagChip(
                                label: tag,
                                onRemove:
                                    () => context
                                        .read<AddStoreProductBloc>()
                                        .add(AddStoreProductTagRemoved(tag)),
                              ),
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: _tagController,
                                onChanged:
                                    (value) =>
                                        context.read<AddStoreProductBloc>().add(
                                          AddStoreProductTagDraftChanged(value),
                                        ),
                                onSubmitted: (value) {
                                  context.read<AddStoreProductBloc>().add(
                                    AddStoreProductTagAdded(value),
                                  );
                                  _tagController.clear();
                                },
                                style: AppTextStyles.body(fontSize: 14),
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: 'Type a tag...',
                                  hintStyle: AppTextStyles.hint(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Suggested',
                          style: AppTextStyles.caption(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in AddStoreProductBloc.suggestedTags)
                              if (!state.tags.contains(tag))
                                ProductTagChip(
                                  label: tag,
                                  isSuggestion: true,
                                  onAdd:
                                      () => context
                                          .read<AddStoreProductBloc>()
                                          .add(
                                            AddStoreProductSuggestedTagTapped(
                                              tag,
                                            ),
                                          ),
                                ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Description',
                          style: AppTextStyles.label(
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _descriptionController,
                          onChanged:
                              (value) =>
                                  context.read<AddStoreProductBloc>().add(
                                    AddStoreProductDescriptionChanged(value),
                                  ),
                          minLines: 3,
                          maxLines: 5,
                          style: AppTextStyles.body(fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Enter product description',
                            hintStyle: AppTextStyles.hint(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                            filled: true,
                            fillColor: AppColors.surfaceSecondary,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isEdit
                                      ? images.length > 1
                                          ? 'Title, tags, and description apply to all photos together. The catalog does not store a separate title for each photo. Keep at least one photo.'
                                          : 'You can update title, tags, description, and photos. Keep at least one photo.'
                                      : 'Titles and tags make this product searchable across the whole store.',
                                  style: AppTextStyles.caption(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: AppPadding.screen(top: 8, bottom: 24),
                  child: PrimaryButton(
                    label: isEdit ? 'Save changes' : 'Publish to store',
                    enabled: state.canPublish,
                    isLoading: state.isPublishing,
                    onPressed:
                        () => context.read<AddStoreProductBloc>().add(
                          const AddStoreProductPublishPressed(),
                        ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
