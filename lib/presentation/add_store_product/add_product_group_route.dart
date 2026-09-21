import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/bulk_upload/bulk_upload_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/primary_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/bulk_upload.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/add_store_product/add_store_product_widgets/bulk_photo_strip.dart';
import 'package:project_c/presentation/add_store_product/add_store_product_widgets/bulk_photos_preview_sheet.dart';

class AddProductGroupRoute extends StatefulWidget {
  const AddProductGroupRoute({super.key});

  @override
  State<AddProductGroupRoute> createState() => _AddProductGroupRouteState();
}

class _AddProductGroupRouteState extends State<AddProductGroupRoute> {
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: context.read<BulkUploadBloc>().state.groupTitle,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _openTitleOnlyForm(BulkUploadState state) async {
    final published = await Navigator.of(context).pushNamed(
      Routes.addProductFormRoute,
      arguments: <String, Object?>{
        'selectedItems': state.images,
        'storeId': state.storeId,
        'title': state.groupTitle.trim(),
      },
    );
    if (!mounted) return;
    if (published is Map) {
      Navigator.of(context).pop(published);
    }
  }

  Future<void> _openGroupDetails() async {
    final bloc = context.read<BulkUploadBloc>();
    final result = await Navigator.of(context).pushNamed(
      Routes.addProductGroupDetailsRoute,
      arguments: <String, Object?>{
        'bloc': bloc,
        'scope': BulkSpecScope.group,
      },
    );
    if (!mounted) return;

    if (result == 'open_preview' || bloc.state.shouldOpenPreview) {
      if (bloc.state.shouldOpenPreview) {
        bloc.add(const BulkUploadClearOpenPreview());
      }
      await _openPreview();
      return;
    }

    if (result is Map) {
      Navigator.of(context).pop(result);
      return;
    }
    if (result == 'close_flow') {
      _popToStoreWithPublished(bloc);
    }
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
    // Preview closed after publish (or via popUntil) — still leave add flow.
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
                  curr.shouldOpenTitleOnlyForm && !prev.shouldOpenTitleOnlyForm,
          listener: (context, state) {
            context.read<BulkUploadBloc>().add(
              const BulkUploadClearOpenTitleOnlyForm(),
            );
            _openTitleOnlyForm(state);
          },
        ),
        BlocListener<BulkUploadBloc, BulkUploadState>(
          listenWhen:
              (prev, curr) =>
                  curr.shouldOpenGroupDetails && !prev.shouldOpenGroupDetails,
          listener: (context, state) {
            context.read<BulkUploadBloc>().add(
              const BulkUploadClearOpenGroupDetails(),
            );
            _openGroupDetails();
          },
        ),
      ],
      child: ScreenWrapper(
        backgroundColor: AppColors.background,
        statusBarIconBrightness: Brightness.dark,
        child: BlocBuilder<BulkUploadBloc, BulkUploadState>(
          builder: (context, state) {
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
                        const SizedBox(height: 12),
                        Text(
                          'New upload · ${state.items.length} photos',
                          style: AppTextStyles.headline(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        BulkPhotoStrip(
                          paths: [
                            for (final item in state.items) item.imagePath,
                          ],
                          onTap:
                              (index) => showBulkPhotosPreviewSheet(
                                context: context,
                                initialIndex: index,
                                readOnly: state.isEditMode,
                              ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Group title',
                          style: AppTextStyles.label(
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                        TextField(
                          controller: _titleController,
                          onChanged:
                              (value) => context.read<BulkUploadBloc>().add(
                                BulkUploadTitleChanged(value),
                              ),
                          style: AppTextStyles.body(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. Bridal ring collection',
                            hintStyle: AppTextStyles.hint(
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                            ),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.primary,
                                width: 1.6,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Every photo becomes its own product under this group. You can rename items later.',
                          style: AppTextStyles.caption(),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Choose how much detail to add now. You can always refine individual items afterwards.',
                            style: AppTextStyles.caption(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: AppPadding.screen(top: 8, bottom: 24),
                  child: Column(
                    children: [
                      PrimaryButton(
                        label: 'Upload with title only',
                        enabled: state.canContinue,
                        onPressed:
                            () => context.read<BulkUploadBloc>().add(
                              const BulkUploadTitleOnlyPressed(),
                            ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: state.canContinue ? 1 : 0.45,
                          child: OutlinedButton(
                            onPressed:
                                state.canContinue
                                    ? () => context.read<BulkUploadBloc>().add(
                                      const BulkUploadAddDetailsPressed(),
                                    )
                                    : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              disabledForegroundColor: AppColors.primary,
                              side: const BorderSide(
                                color: AppColors.primary,
                                width: 1.4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Add weight, purity & size',
                              style: AppTextStyles.button(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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

