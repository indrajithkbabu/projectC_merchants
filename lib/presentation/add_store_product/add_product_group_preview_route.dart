import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/bulk_upload/bulk_upload_bloc.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/data/merchant_store_session.dart';
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
import 'package:project_c/presentation/add_store_product/add_store_product_widgets/bulk_item_tile.dart';
import 'package:project_c/services/product_upload_coordinator.dart';
import 'package:project_c/session/catalog_session.dart';

class AddProductGroupPreviewRoute extends StatefulWidget {
  const AddProductGroupPreviewRoute({super.key, this.autoOpenEdit = false});

  /// When true (e.g. browse Select → Edit), open the single/multi details form
  /// once for the pre-selected items after the first frame.
  final bool autoOpenEdit;

  @override
  State<AddProductGroupPreviewRoute> createState() =>
      _AddProductGroupPreviewRouteState();
}

class _AddProductGroupPreviewRouteState
    extends State<AddProductGroupPreviewRoute> {
  static const _logTag = 'BulkQA.Preview';
  static const _minColumns = 4;

  bool _didAutoOpenEdit = false;
  int _crossAxisCount = 5;
  double _pinchStartColumns = 5;

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoOpenEdit());
    }
  }

  void _tryAutoOpenEdit() {
    if (!mounted || _didAutoOpenEdit) return;
    final state = context.read<BulkUploadBloc>().state;
    if (state.selectedCount == 0) return;
    _didAutoOpenEdit = true;
    _openEdit(context, state);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _pinchStartColumns = _crossAxisCount.toDouble();
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2) return;
    final width = MediaQuery.sizeOf(context).width;
    final maxColumns = (width / 20).floor();
    final upper = maxColumns < _minColumns ? _minColumns : maxColumns;
    final next = (_pinchStartColumns / details.scale).round().clamp(
      _minColumns,
      upper,
    );
    if (next != _crossAxisCount) {
      setState(() => _crossAxisCount = next);
    }
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
              (prev, curr) => curr.itemsBecameEmpty && !prev.itemsBecameEmpty,
          listener: (context, state) {
            context.read<BulkUploadBloc>().add(
              const BulkUploadClearItemsEmpty(),
            );
            Navigator.of(context).maybePop();
          },
        ),
        BlocListener<BulkUploadBloc, BulkUploadState>(
          listenWhen:
              (prev, curr) => curr.shouldCloseFlow && !prev.shouldCloseFlow,
          listener: (context, state) {
            context.read<BulkUploadBloc>().add(const BulkUploadClearCloseFlow());
            _popPublishedResult(context, state);
          },
        ),
        BlocListener<BulkUploadBloc, BulkUploadState>(
          listenWhen:
              (prev, curr) =>
                  curr.shouldPopWithResult && !prev.shouldPopWithResult,
          listener: (context, state) {
            context.read<BulkUploadBloc>().add(
              const BulkUploadClearShouldPopWithResult(),
            );
            final product = state.publishedProduct;
            if (product == null) {
              Navigator.of(context).maybePop();
              return;
            }
            Navigator.of(context).pop(<String, Object?>{
              'updated': true,
              ...product.toMap(),
              if (state.publishedRevision != null)
                'revision': state.publishedRevision,
              if (state.publishedApiTag != null)
                'apiTag': state.publishedApiTag,
            });
          },
        ),
      ],
      child: ScreenWrapper(
        backgroundColor: AppColors.background,
        statusBarIconBrightness: Brightness.dark,
        child: BlocBuilder<BulkUploadBloc, BulkUploadState>(
          builder: (context, state) {
            if (state.isPublished && !state.isEditMode) {
              // Create uploads leave immediately for background shimmer;
              // Published screen is no longer shown for add flow.
              return _PublishedView(
                title: state.groupTitle.trim(),
                count: state.items.length,
                onDone: () => _popPublishedResult(context, state),
                onRestart:
                    () => context.read<BulkUploadBloc>().add(
                      const BulkUploadRestartRequested(),
                    ),
              );
            }
            return Column(
              children: [
                Padding(
                  padding: AppPadding.screen(
                    top: ScreenWrapper.statusBarTop(context),
                    bottom: 8,
                  ),
                  child: Row(
                    children: [
                      const AppBackButton(),
                      Expanded(
                        child: Text(
                          state.groupTitle.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.headline(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: AppPadding.screenHorizontal,
                  child: Row(
                    children: [
                      Text(
                        '${state.items.length} items',
                        style: AppTextStyles.bodySecondary(fontSize: 14),
                      ),
                      const Spacer(),
                      if (state.isSelectMode) ...[
                        _ToolbarAction(
                          label: 'Edit',
                          enabled: state.selectedCount > 0,
                          onTap: () => _openEdit(context, state),
                        ),
                        _ToolbarAction(
                          label: 'Delete',
                          enabled: state.selectedCount > 0,
                          onTap: () => _confirmDelete(context),
                        ),
                        _ToolbarAction(
                          label: 'Done',
                          enabled: true,
                          onTap:
                              () => context.read<BulkUploadBloc>().add(
                                const BulkUploadSelectModeToggled(false),
                              ),
                        ),
                      ] else
                        _ToolbarAction(
                          label: 'Select',
                          enabled: true,
                          onTap:
                              () => context.read<BulkUploadBloc>().add(
                                const BulkUploadSelectModeToggled(true),
                              ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: RawGestureDetector(
                    gestures: {
                      ScaleGestureRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                            ScaleGestureRecognizer
                          >(
                            () => ScaleGestureRecognizer(),
                            (instance) {
                              instance
                                ..onStart = _onScaleStart
                                ..onUpdate = _onScaleUpdate;
                            },
                          ),
                    },
                    child: GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: state.items.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _crossAxisCount,
                        crossAxisSpacing: 1.5,
                        mainAxisSpacing: 1.5,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (context, index) {
                        final item = state.items[index];
                        return BulkItemTile(
                          item: item,
                          selected: state.selectedItemIds.contains(item.id),
                          selectMode: state.isSelectMode,
                          onTap: () {
                            final bloc = context.read<BulkUploadBloc>();
                            if (state.isSelectMode) {
                              bloc.add(
                                BulkUploadItemSelectionToggled(item.id),
                              );
                              return;
                            }
                            Navigator.of(context).pushNamed(
                              Routes.addProductGroupDetailsRoute,
                              arguments: <String, Object?>{
                                'bloc': bloc,
                                'scope': BulkSpecScope.single,
                                'itemId': item.id,
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: AppPadding.screen(top: 8, bottom: 24),
                  child: PrimaryButton(
                    label:
                        state.isEditMode
                            ? 'Save changes'
                            : 'Done · publish ${state.items.length} items',
                    enabled:
                        state.items.isNotEmpty &&
                        (state.isEditMode ? !state.isPublishing : true),
                    isLoading: state.isEditMode && state.isPublishing,
                    progress:
                        state.isEditMode && state.isPublishing
                            ? state.publishProgress
                            : null,
                    onPressed: () => _onPublishPressed(context, state),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _onPublishPressed(BuildContext context, BulkUploadState state) {
    AppLog.d(
      _logTag,
      'CTA pressed edit=${state.isEditMode} '
      'items=${state.items.length} '
      'publishing=${state.isPublishing}',
    );
    if (state.isEditMode) {
      context.read<BulkUploadBloc>().add(const BulkUploadPublishPressed());
      return;
    }

    final storeId =
        (state.storeId?.trim().isNotEmpty == true)
            ? state.storeId!.trim()
            : (ServiceLocator.get<CatalogSession>().ownStoreId?.trim() ?? '');
    if (storeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a store before publishing products.'),
        ),
      );
      return;
    }
    if (!state.groupSpec.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Group details are incomplete. Go back and fill weight, purity, wastage, size, metal, and category.',
          ),
        ),
      );
      return;
    }

    ServiceLocator.get<ProductUploadCoordinator>().startWithSpecs(
      SpecsUploadRequest(
        storeId: storeId,
        title: state.groupTitle.trim(),
        items: List<BulkUploadItem>.from(state.items),
        groupSpec: state.groupSpec,
        tags: state.tags,
        description: state.description,
        knownSubGroups: List<BulkKnownSubGroup>.from(state.knownSubGroups),
      ),
    );
    // Leave immediately — store profile shows uploading shimmer.
    Navigator.of(context).popUntil((route) {
      final name = route.settings.name;
      return name == Routes.storeProfileRoute || route.isFirst;
    });
  }

  void _popPublishedResult(BuildContext context, BulkUploadState state) {
    final product = state.publishedProduct;
    if (product != null) {
      MerchantStoreSession.instance.addProduct(product);
    }

    // Pop group + preview (and any details above) straight back to store profile.
    // Store profile refreshes collections when the pushNamed future completes.
    Navigator.of(context).popUntil((route) {
      final name = route.settings.name;
      return name == Routes.storeProfileRoute || route.isFirst;
    });
  }

  void _openEdit(BuildContext context, BulkUploadState state) {
    if (state.selectedCount == 0) return;
    final bloc = context.read<BulkUploadBloc>();
    AppLog.d(
      _logTag,
      'OpenEdit count=${state.selectedCount} '
      'ids=${state.selectedItemIds.join(',')} '
      'scope=${state.selectedCount == 1 ? 'single' : 'multi'}',
    );
    if (state.selectedCount == 1) {
      Navigator.of(context).pushNamed(
        Routes.addProductGroupDetailsRoute,
        arguments: <String, Object?>{
          'bloc': bloc,
          'scope': BulkSpecScope.single,
          'itemId': state.selectedItemIds.first,
        },
      );
      return;
    }
    Navigator.of(context).pushNamed(
      Routes.addProductGroupDetailsRoute,
      arguments: <String, Object?>{
        'bloc': bloc,
        'scope': BulkSpecScope.multi,
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    AppLog.d(_logTag, 'Delete dialog open');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Delete items?', style: AppTextStyles.headline()),
          content: Text(
            'Selected items will be removed from this upload.',
            style: AppTextStyles.bodySecondary(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Delete',
                style: AppTextStyles.label(
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (!context.mounted || confirmed != true) {
      AppLog.d(_logTag, 'Delete cancelled');
      return;
    }
    AppLog.d(_logTag, 'Delete confirmed');
    context.read<BulkUploadBloc>().add(const BulkUploadDeleteSelected());
  }
}

class _ToolbarAction extends StatelessWidget {
  const _ToolbarAction({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Text(
          label,
          style: AppTextStyles.label(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: enabled ? AppColors.accent : AppColors.textHint,
          ),
        ),
      ),
    );
  }
}

class _PublishedView extends StatelessWidget {
  const _PublishedView({
    required this.title,
    required this.count,
    required this.onDone,
    required this.onRestart,
  });

  final String title;
  final int count;
  final VoidCallback onDone;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppPadding.screen(
        top: ScreenWrapper.statusBarTop(context),
        bottom: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBackButton(onPressed: onDone),
          const Spacer(),
          Text('Published', style: AppTextStyles.title()),
          const SizedBox(height: 10),
          Text(
            '$count items from "$title" are live in your store.',
            style: AppTextStyles.bodySecondary(),
          ),
          const Spacer(),
          PrimaryButton(label: 'Done', onPressed: onDone),
          // const SizedBox(height: 12),
          // Center(
          //   child: TextButton(
          //     onPressed: onRestart,
          //     child: Text(
          //       'Start another upload',
          //       style: AppTextStyles.button(color: AppColors.accent),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}
