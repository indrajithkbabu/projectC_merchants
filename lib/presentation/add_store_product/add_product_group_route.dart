import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/add_store_product/add_store_product_bloc.dart';
import 'package:project_c/bloc/bulk_upload/bulk_upload_bloc.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/primary_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/bulk_upload.dart';
import 'package:project_c/models/pending_product_upload.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/add_store_product/add_store_product_widgets/bulk_photos_ios_preview.dart';
import 'package:project_c/presentation/add_store_product/add_store_product_widgets/product_form_widgets.dart';
import 'package:project_c/presentation/add_store_product/add_store_product_widgets/product_spec_form.dart';
import 'package:project_c/services/product_upload_coordinator.dart';
import 'package:project_c/session/catalog_session.dart';

class AddProductGroupRoute extends StatefulWidget {
  const AddProductGroupRoute({super.key});

  @override
  State<AddProductGroupRoute> createState() => _AddProductGroupRouteState();
}

class _AddProductGroupRouteState extends State<AddProductGroupRoute> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagController;

  /// Latest draft from [ProductSpecForm]; drives Continue vs title-only publish.
  ProductSpec? _detailsDraft;

  /// Optional description field — collapsed behind a + until expanded.
  bool _showDescription = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<BulkUploadBloc>().state;
    _titleController = TextEditingController(text: state.groupTitle);
    _descriptionController = TextEditingController(text: state.description);
    _tagController = TextEditingController(text: state.tagDraft);
    _showDescription = state.description.trim().isNotEmpty;
    _detailsDraft = state.groupSpec.isValid ? state.groupSpec : null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _commitTag() {
    final value = _tagController.text;
    if (value.trim().isEmpty) return;
    context.read<BulkUploadBloc>().add(BulkUploadTagAdded(value));
    _tagController.clear();
  }

  void _toggleDescription() {
    setState(() {
      _showDescription = !_showDescription;
      if (!_showDescription) {
        _descriptionController.clear();
        context.read<BulkUploadBloc>().add(
          const BulkUploadDescriptionChanged(''),
        );
      }
    });
  }

  Future<void> _openPreview() async {
    final bloc = context.read<BulkUploadBloc>();
    final result = await Navigator.of(context).pushNamed(
      Routes.addProductGroupPreviewRoute,
      arguments: <String, Object?>{'bloc': bloc},
    );
    if (!mounted) return;

    if (result is Map) {
      Navigator.of(context).pop(Map<String, Object?>.from(result));
      return;
    }
    if (bloc.state.isPublished || bloc.state.publishedProduct != null) {
      _popToStoreWithPublished(bloc);
      return;
    }
    if (result == 'close_flow') {
      _popToStoreWithPublished(bloc);
    }
  }

  void _popToStoreWithPublished(BulkUploadBloc bloc) {
    final product = bloc.state.publishedProduct;
    if (product != null) {
      Navigator.of(context).pop(<String, Object?>{
        ...product.toMap(),
        if (bloc.state.publishedRevision != null)
          'revision': bloc.state.publishedRevision,
        if (bloc.state.publishedApiTag != null)
          'apiTag': bloc.state.publishedApiTag,
      });
      return;
    }
    Navigator.of(context).pop();
  }

  void _leaveForBackgroundUpload() {
    Navigator.of(context).pop(<String, Object?>{'uploading': true});
  }

  String? _resolveStoreId(BulkUploadState state) {
    final fromState = state.storeId?.trim() ?? '';
    if (fromState.isNotEmpty) return fromState;
    return ServiceLocator.get<CatalogSession>().ownStoreId?.trim();
  }

  bool get _detailsValid =>
      _detailsDraft != null && _detailsDraft!.isValid;

  void _onPrimaryPressed(BulkUploadState state) {
    if (_detailsValid) {
      final spec = _detailsDraft;
      if (spec == null || !spec.isValid) return;
      // Same as former group-details Apply → opens preview for precise/edit/delete.
      context.read<BulkUploadBloc>().add(BulkUploadApplyGroupSpec(spec));
      return;
    }

    final storeId = _resolveStoreId(state);
    if (storeId == null || storeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a store before publishing products.'),
        ),
      );
      return;
    }

    // Fire-and-forget title-only upload → store profile shows shimmer.
    ServiceLocator.get<ProductUploadCoordinator>().startTitleOnly(
      TitleOnlyUploadRequest(
        storeId: storeId,
        title: state.groupTitle.trim(),
        imagePaths: [for (final item in state.items) item.imagePath],
        tags: state.tags,
        description: state.description,
      ),
    );
    _leaveForBackgroundUpload();
  }

  InputDecoration _underlineDecoration({
    required String hint,
    double size = 18,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.hint(fontSize: size, fontWeight: FontWeight.w400),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.primary, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<BulkUploadBloc, BulkUploadState>(
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
            context.read<BulkUploadBloc>().add(const BulkUploadClearMessage());
          },
        ),
        BlocListener<BulkUploadBloc, BulkUploadState>(
          listenWhen:
              (prev, curr) =>
                  curr.shouldOpenPreview && !prev.shouldOpenPreview,
          listener: (context, state) {
            context.read<BulkUploadBloc>().add(
              const BulkUploadClearOpenPreview(),
            );
            _openPreview();
          },
        ),
      ],
      child: ScreenWrapper(
        backgroundColor: AppColors.background,
        statusBarIconBrightness: Brightness.dark,
        child: BlocBuilder<BulkUploadBloc, BulkUploadState>(
          builder: (context, state) {
            final canSubmit = state.canContinue;

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
                        const AppBackButton(),
                        const SizedBox(height: 14),
                        Builder(
                          builder: (context) {
                            final previewImages = [
                              for (final image in state.images)
                                if (!image.isPlaceholder &&
                                    (image.filePath?.trim().isNotEmpty ??
                                        false))
                                  image,
                            ];
                            final primary =
                                previewImages.isEmpty
                                    ? null
                                    : previewImages.first;
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ProductPreviewImage(
                                  item: primary,
                                  imageCount: previewImages.length,
                                  onTap:
                                      primary == null
                                          ? null
                                          : () => showBulkPhotosIosPreview(
                                            context: context,
                                            initialIndex: 0,
                                            readOnly: state.isEditMode,
                                          ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text.rich(
                                        TextSpan(
                                          text: 'Title',
                                          style: AppTextStyles.label(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.accent,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: ' *',
                                              style: AppTextStyles.label(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextField(
                                        controller: _titleController,
                                        onChanged:
                                            (value) => context
                                                .read<BulkUploadBloc>()
                                                .add(
                                                  BulkUploadTitleChanged(value),
                                                ),
                                        style: AppTextStyles.body(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        decoration: _underlineDecoration(
                                          hint: 'e.g. Bridal ring collection',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Tags',
                          style: AppTextStyles.label(
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            SizedBox(
                              width: 128,
                              child: TextField(
                                controller: _tagController,
                                onChanged:
                                    (value) =>
                                        context.read<BulkUploadBloc>().add(
                                          BulkUploadTagDraftChanged(value),
                                        ),
                                onSubmitted: (_) => _commitTag(),
                                textInputAction: TextInputAction.done,
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
                            IconButton(
                              tooltip: 'Add tag',
                              onPressed: _commitTag,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              icon: const Icon(
                                Icons.add_circle_rounded,
                                color: AppColors.accent,
                                size: 26,
                              ),
                            ),
                          ],
                        ),
                        if (state.tags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final tag in state.tags)
                                ProductTagChip(
                                  label: tag,
                                  onRemove:
                                      () => context.read<BulkUploadBloc>().add(
                                        BulkUploadTagRemoved(tag),
                                      ),
                                ),
                            ],
                          ),
                        ],
                        Builder(
                          builder: (context) {
                            final suggestions =
                                AddStoreProductBloc.suggestedTags
                                    .where((tag) => !state.tags.contains(tag))
                                    .toList(growable: false);
                            if (suggestions.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 14),
                                Text(
                                  'Suggested',
                                  style: AppTextStyles.caption(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 36,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: suggestions.length,
                                    separatorBuilder:
                                        (_, __) => const SizedBox(width: 8),
                                    itemBuilder: (context, index) {
                                      final tag = suggestions[index];
                                      return ProductTagChip(
                                        label: tag,
                                        isSuggestion: true,
                                        onAdd:
                                            () => context
                                                .read<BulkUploadBloc>()
                                                .add(
                                                  BulkUploadSuggestedTagTapped(
                                                    tag,
                                                  ),
                                                ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        ProductSpecForm(
                          initial: state.groupSpec,
                          subtitle: '',
                          onChanged: (spec) {
                            setState(() => _detailsDraft = spec);
                          },
                        ),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: _toggleDescription,
                          child: Row(
                            children: [
                              Icon(
                                _showDescription
                                    ? Icons.remove_circle_outline_rounded
                                    : Icons.add_circle_rounded,
                                color: AppColors.accent,
                                size: 22,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _showDescription
                                    ? 'Hide description'
                                    : 'Add description',
                                style: AppTextStyles.label(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_showDescription) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: _descriptionController,
                            onChanged:
                                (value) => context.read<BulkUploadBloc>().add(
                                  BulkUploadDescriptionChanged(value),
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
                        ],
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    width: double.infinity,
                    color: AppColors.background,
                    padding: AppPadding.screen(top: 10, bottom: 12),
                    child: PrimaryButton(
                      label:
                          _detailsValid
                              ? 'Continue · ${state.items.length} items'
                              : 'Publish to store',
                      enabled: canSubmit,
                      onPressed: () => _onPrimaryPressed(state),
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
