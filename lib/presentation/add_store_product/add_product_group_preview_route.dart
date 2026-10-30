import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/bulk_upload/bulk_upload_bloc.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/data/merchant_store_session.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/jewel_upload_qa.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/primary_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/bulk_upload.dart';
import 'package:project_c/models/catalog/catalog_product_models.dart';
import 'package:project_c/models/pending_product_upload.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/add_store_product/add_store_product_widgets/bulk_item_tile.dart';
import 'package:project_c/presentation/add_store_product/compose_product_draft.dart';
import 'package:project_c/presentation/add_store_product/leave_create_product_flow.dart';
import 'package:project_c/services/product_upload_coordinator.dart';
import 'package:project_c/session/catalog_session.dart';

class AddProductGroupPreviewRoute extends StatefulWidget {
  const AddProductGroupPreviewRoute({
    super.key,
    this.autoOpenEdit = false,
    this.stockStatus = 'in',
    this.mtoDays,
    this.isLocked = false,
    this.photoRows = const [],
  });

  /// When true (e.g. browse Select → Edit), open compose for the pre-selected
  /// items after the first frame.
  final bool autoOpenEdit;

  /// Compose stock/lock (UI); persisted on local product until upload docs land.
  final String stockStatus;
  final int? mtoDays;
  final bool isLocked;

  /// Per-photo stock/mto/lock from compose (aligned with bulk items at open).
  final List<TitleOnlyPhotoRow> photoRows;

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

  /// Mutable copy so preview refine (compose return) can update stock/lock.
  late List<TitleOnlyPhotoRow> _photoRows;

  @override
  void initState() {
    super.initState();
    _photoRows = List<TitleOnlyPhotoRow>.from(widget.photoRows);
    if (widget.autoOpenEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoOpenEdit());
    }
  }

  CatalogStockStatus get _fallbackStock =>
      CatalogStockStatus.tryParse(widget.stockStatus) ??
      CatalogStockStatus.inStock;

  TitleOnlyPhotoRow _rowForDraft(ComposePhotoDraft d) {
    return TitleOnlyPhotoRow(
      spec: d.spec,
      tags: d.tags,
      stockStatus: d.stockStatus.catalog,
      mtoDays: d.mtoDays,
      isLocked: d.isLocked,
    );
  }

  ComposeStockStatus _composeStockForIndex(int itemIndex) {
    if (itemIndex >= 0 && itemIndex < _photoRows.length) {
      return composeStockStatusFromName(_photoRows[itemIndex].stockStatus.apiValue);
    }
    return composeStockStatusFromName(widget.stockStatus);
  }

  int? _mtoForIndex(int itemIndex) {
    if (itemIndex >= 0 && itemIndex < _photoRows.length) {
      return _photoRows[itemIndex].mtoDays ?? widget.mtoDays;
    }
    return widget.mtoDays;
  }

  bool _lockedForIndex(int itemIndex) {
    if (itemIndex >= 0 && itemIndex < _photoRows.length) {
      return _photoRows[itemIndex].isLocked;
    }
    return widget.isLocked;
  }

  /// Align stored rows to current [items] order (handles deletes / replaces).
  List<TitleOnlyPhotoRow> _photoRowsAlignedTo(List<BulkUploadItem> items) {
    if (_photoRows.isEmpty) return const [];
    if (_photoRows.length == items.length) {
      return List<TitleOnlyPhotoRow>.from(_photoRows);
    }
    // Index-based pad/truncate when item count changed without a full remap.
    return [
      for (var i = 0; i < items.length; i++)
        if (i < _photoRows.length)
          _photoRows[i]
        else
          TitleOnlyPhotoRow(
            spec: items[i].spec,
            stockStatus: _fallbackStock,
            mtoDays: widget.mtoDays,
            isLocked: widget.isLocked,
          ),
    ];
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
                            unawaited(
                              _openComposeEdit(
                                context,
                                state,
                                items: [item],
                              ),
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

    final stock = _fallbackStock;
    final items = List<BulkUploadItem>.from(state.items);
    final photoRows = _photoRowsAlignedTo(items);
    JewelUploadQa.step(
      'UI publish → startWithSpecs',
      detail:
          'store=$storeId photos=${items.length} '
          'photoRows=${photoRows.length} '
          'stock=${stock.apiValue} locked=${widget.isLocked} '
          '${[
            for (var i = 0; i < photoRows.length; i++)
              '[$i]=${photoRows[i].stockStatus.apiValue}/'
              'L=${photoRows[i].isLocked}',
          ].join(' ')}',
    );
    ServiceLocator.get<ProductUploadCoordinator>().startWithSpecs(
      SpecsUploadRequest(
        storeId: storeId,
        title: state.groupTitle.trim(),
        items: items,
        groupSpec: state.groupSpec,
        tags: state.tags,
        description: state.description,
        knownSubGroups: List<BulkKnownSubGroup>.from(state.knownSubGroups),
        photoRows: photoRows,
        stockStatus: stock,
        mtoDays: widget.mtoDays,
        isLocked: widget.isLocked,
      ),
    );
    // Pop preview only — group calls [leaveCreateProductFlow] so compose-overlay
    // cleanup cannot pop the store profile that leave just revealed.
    Navigator.of(context).pop(kCreateProductBackgroundUpload);
  }

  void _popPublishedResult(BuildContext context, BulkUploadState state) {
    final product = state.publishedProduct;
    if (product != null) {
      MerchantStoreSession.instance.addProduct(product);
      Navigator.of(context).pop(<String, Object?>{
        ...product.toMap(),
        if (state.publishedRevision != null)
          'revision': state.publishedRevision,
        if (state.publishedApiTag != null) 'apiTag': state.publishedApiTag,
      });
      return;
    }
    Navigator.of(context).pop('close_flow');
  }

  void _openEdit(BuildContext context, BulkUploadState state) {
    if (state.selectedCount == 0) return;
    final ids = state.selectedItemIds.toSet();
    final items = [
      for (final item in state.items)
        if (ids.contains(item.id)) item,
    ];
    if (items.isEmpty) return;
    AppLog.d(
      _logTag,
      'OpenEdit → compose count=${items.length} '
      'ids=${items.map((e) => e.id).join(',')}',
    );
    unawaited(_openComposeEdit(context, state, items: items));
  }

  Future<void> _openComposeEdit(
    BuildContext context,
    BulkUploadState state, {
    required List<BulkUploadItem> items,
  }) async {
    if (items.isEmpty) return;
    final full = state.items;
    final drafts = [
      for (final item in items)
        () {
          final idx = full.indexWhere((e) => e.id == item.id);
          return ComposePhotoDraft(
            // Prefer hydrated item specs; fall back to compose defaults so the
            // rail is never blank when refining title-only / incomplete items.
            spec:
                item.spec.metalType.isNotEmpty || item.spec.isValid
                    ? item.spec
                    : ComposePhotoDraft.defaults().spec,
            tags: state.tags,
            stockStatus: _composeStockForIndex(idx),
            mtoDays: _mtoForIndex(idx) ?? 7,
            isLocked: _lockedForIndex(idx),
          );
        }(),
    ];
    final result = await Navigator.of(context).pushNamed(
      Routes.addProductComposeRoute,
      arguments: <String, Object?>{
        'imagePaths': [for (final i in items) i.imagePath],
        'itemIds': [for (final i in items) i.id],
        'initialDrafts': drafts,
        'storeId': state.storeId,
        'initialIndex': 0,
        'returnResult': true,
        // Edit-refine: no add/delete here (preview / metadata edit own that).
        'allowAddDelete': !state.isEditMode,
      },
    );
    if (!context.mounted || result is! Map) return;
    final map = Map<String, Object?>.from(result);
    if (map['returnResult'] != true) return;
    _applyComposeResult(context, state, items: items, result: map);
  }

  void _applyComposeResult(
    BuildContext context,
    BulkUploadState state, {
    required List<BulkUploadItem> items,
    required Map<String, Object?> result,
  }) {
    final bloc = context.read<BulkUploadBloc>();
    final drafts =
        (result['photoDrafts'] is List)
            ? (result['photoDrafts'] as List)
                .whereType<ComposePhotoDraft>()
                .toList()
            : const <ComposePhotoDraft>[];
    final paths =
        (result['imagePaths'] is List)
            ? (result['imagePaths'] as List)
                .whereType<String>()
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : const <String>[];
    final applyToAll = result['applyToAll'] != false;
    final full = bloc.state.items;

    // Keep per-photo stock/lock in sync even when only lock/stock changed.
    if (drafts.isNotEmpty) {
      setState(() {
        var next = _photoRowsAlignedTo(full);
        if (next.isEmpty) {
          next = [
            for (final item in full)
              TitleOnlyPhotoRow(
                spec: item.spec,
                stockStatus: _fallbackStock,
                mtoDays: widget.mtoDays,
                isLocked: widget.isLocked,
              ),
          ];
        }
        if (applyToAll && drafts.isNotEmpty) {
          final row = _rowForDraft(drafts.first);
          for (final item in items) {
            final idx = full.indexWhere((e) => e.id == item.id);
            if (idx >= 0 && idx < next.length) next[idx] = row;
          }
        } else {
          for (var i = 0; i < items.length && i < drafts.length; i++) {
            final idx = full.indexWhere((e) => e.id == items[i].id);
            if (idx >= 0 && idx < next.length) {
              next[idx] = _rowForDraft(drafts[i]);
            }
          }
        }
        _photoRows = next;
      });
    }

    var applied = 0;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (i < paths.length && paths[i] != item.imagePath.trim()) {
        bloc.add(
          BulkUploadItemImageReplaced(itemId: item.id, imagePath: paths[i]),
        );
      }
      if (i >= drafts.length) continue;
      final spec = drafts[i].spec;
      if (!spec.isValid) continue;
      if (applyToAll && items.length > 1) {
        // Apply once below.
        continue;
      }
      bloc.add(BulkUploadApplyItemSpec(itemId: item.id, spec: spec));
      applied++;
    }
    if (applyToAll && items.length > 1 && drafts.isNotEmpty) {
      final spec = drafts.first.spec;
      if (spec.isValid) {
        bloc.add(
          BulkUploadSelectionSet([for (final i in items) i.id]),
        );
        bloc.add(BulkUploadApplyMultiSpec(spec));
        applied = items.length;
      }
    }
    if (applied == 0 && drafts.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fill complete specs (metal, purity, wastage, weight, size) to apply.',
          ),
        ),
      );
    }
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
