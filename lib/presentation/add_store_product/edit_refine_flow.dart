import 'package:flutter/material.dart';
import 'package:project_c/bloc/bulk_upload/bulk_upload_bloc.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/bulk_upload.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/add_store_product/compose_product_draft.dart';

/// Filter logcat / Flutter console with: `EditRefine`
const kEditRefineLogTag = 'EditRefine';

/// Opens compose directly for edit refine (no preview flash), applies drafts,
/// saves via [BulkUploadComposeRefineSubmitted], and returns the pop payload
/// (`updated: true` + product map) or `null` if cancelled / failed.
///
/// [bloc] must already be hydrated with [BulkUploadBloc.fromCollectionDetail]
/// (`isEditMode: true`). Caller owns closing the bloc.
Future<Map<String, Object?>?> openComposeRefineEdit({
  required BuildContext context,
  required BulkUploadBloc bloc,
  required List<BulkUploadItem> items,
  CatalogStockStatusFallback? stockFallback,
}) async {
  if (items.isEmpty) {
    AppLog.d(kEditRefineLogTag, 'open SKIP empty_items');
    return null;
  }

  final state = bloc.state;
  final full = state.items;
  final fallbackStock = stockFallback?.stockStatus ?? ComposeStockStatus.inStock;
  final fallbackMto = stockFallback?.mtoDays ?? 7;
  final fallbackLocked = stockFallback?.isLocked ?? false;

  final drafts = <ComposePhotoDraft>[
    for (final item in items)
      ComposePhotoDraft(
        spec:
            item.spec.metalType.isNotEmpty || item.spec.isValid
                ? item.spec
                : ComposePhotoDraft.defaults().spec,
        tags: List<String>.from(state.tags),
        stockStatus: fallbackStock,
        mtoDays: fallbackMto,
        isLocked: fallbackLocked,
      ),
  ];

  AppLog.d(
    kEditRefineLogTag,
    'open_compose_direct '
    'count=${items.length} '
    'ids=${items.map((e) => e.id).join(',')} '
    'listing=${state.listingId ?? '-'} '
    'tags=${state.tags.length} '
    'title="${state.groupTitle.trim()}"',
  );

  final composeResult = await Navigator.of(context).pushNamed(
    Routes.addProductComposeRoute,
    arguments: <String, Object?>{
      'imagePaths': [for (final i in items) i.imagePath],
      'itemIds': [for (final i in items) i.id],
      'initialDrafts': drafts,
      'storeId': state.storeId,
      'initialIndex': 0,
      'returnResult': true,
      // Edit-refine: no add/delete (matches preview refine).
      'allowAddDelete': false,
    },
  );

  if (!context.mounted) return null;
  if (composeResult is! Map) {
    AppLog.d(kEditRefineLogTag, 'compose cancelled / no result');
    return null;
  }

  final map = Map<String, Object?>.from(composeResult);
  if (map['returnResult'] != true) {
    AppLog.d(kEditRefineLogTag, 'compose result ignored returnResult!=true');
    return null;
  }

  final resultDrafts =
      (map['photoDrafts'] is List)
          ? (map['photoDrafts'] as List)
              .whereType<ComposePhotoDraft>()
              .toList(growable: false)
          : const <ComposePhotoDraft>[];
  final paths =
      (map['imagePaths'] is List)
          ? (map['imagePaths'] as List)
              .whereType<String>()
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false)
          : [for (final i in items) i.imagePath];
  final applyToAll = map['applyToAll'] != false;
  final itemIds = [for (final i in items) i.id];

  final composedTitle =
      (map['initialTitle'] as String?)?.trim().isNotEmpty == true
          ? (map['initialTitle'] as String).trim()
          : (resultDrafts.isNotEmpty
              ? composeTitleFromDraft(resultDrafts.first)
              : '');
  final composedDescription =
      (map['description'] as String?)?.trim() ?? '';

  AppLog.d(
    kEditRefineLogTag,
    'compose_returned drafts=${resultDrafts.length} '
    'paths=${paths.length} applyToAll=$applyToAll '
    'matchedFull=${full.length} title="$composedTitle"',
  );

  if (resultDrafts.isEmpty) {
    AppLog.d(kEditRefineLogTag, 'SKIP empty_drafts');
    return null;
  }

  // Wait for save completion (or error) after submitting refine.
  final pending = bloc.stream.firstWhere(
    (s) =>
        s.shouldPopWithResult ||
        (s.errorMessage != null &&
            s.errorMessage!.trim().isNotEmpty &&
            !s.isPublishing),
  );

  bloc.add(
    BulkUploadComposeRefineSubmitted(
      itemIds: itemIds,
      drafts: resultDrafts,
      imagePaths: paths,
      applyToAll: applyToAll,
      title: composedTitle,
      description: composedDescription,
    ),
  );

  final after = await pending;
  if (!context.mounted) return null;

  if (after.shouldPopWithResult && after.publishedProduct != null) {
    final product = after.publishedProduct!;
    AppLog.d(
      kEditRefineLogTag,
      'save_ok productId=${product.id} '
      'title="${product.title}" '
      'rev=${after.publishedRevision} '
      'apiTag=${after.publishedApiTag ?? '-'} '
      '→ store_profile / details refresh',
    );
    bloc.add(const BulkUploadClearShouldPopWithResult());
    return <String, Object?>{
      'updated': true,
      ...product.toMap(),
      if (after.publishedRevision != null) 'revision': after.publishedRevision,
      if (after.publishedApiTag != null) 'apiTag': after.publishedApiTag,
    };
  }

  final err = after.errorMessage?.trim();
  AppLog.d(kEditRefineLogTag, 'save_failed err=${err ?? 'unknown'}');
  if (err != null && err.isNotEmpty && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    bloc.add(const BulkUploadClearMessage());
  }
  return null;
}

/// Optional stock/lock defaults when compose opens from details/browse
/// (detail-level values; per-photo rows are not always available).
class CatalogStockStatusFallback {
  const CatalogStockStatusFallback({
    this.stockStatus = ComposeStockStatus.inStock,
    this.mtoDays,
    this.isLocked = false,
  });

  final ComposeStockStatus stockStatus;
  final int? mtoDays;
  final bool isLocked;
}
