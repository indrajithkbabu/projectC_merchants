import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/import_qa.dart';
import 'package:project_c/models/bulk_upload.dart';
import 'package:project_c/models/catalog/catalog_product_models.dart';
import 'package:project_c/models/catalog/quick_import_api_models.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/add_store_product/compose_product_draft.dart';
import 'package:project_c/presentation/add_store_product/leave_create_product_flow.dart';
import 'package:project_c/presentation/main_shell/shell_nav.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';
import 'package:project_c/webservice/import/import_repository.dart';

/// Quick import: select → review compose → `POST /stores/:id/imports`.
enum QuickImportStatus { pending, approved, declined }

class QuickImportRecord {
  const QuickImportRecord({
    required this.id,
    required this.sourceStoreId,
    required this.sourceStoreName,
    required this.sourceProductId,
    required this.imageUrls,
    required this.drafts,
    required this.sourceLocked,
    required this.status,
    required this.createdAt,
    this.decidedAt,
    this.title = '',
  });

  final String id;
  final String sourceStoreId;
  final String sourceStoreName;
  final String sourceProductId;
  final List<String> imageUrls;
  final List<ComposePhotoDraft> drafts;
  final bool sourceLocked;
  final QuickImportStatus status;
  final DateTime createdAt;
  final DateTime? decidedAt;
  final String title;

  String get displayTitle {
    final named = title.trim();
    if (named.isNotEmpty) return named;
    for (final draft in drafts) {
      for (final tag in draft.tags) {
        final t = tag.trim();
        if (t.isNotEmpty) return t;
      }
    }
    return 'Product';
  }

  QuickImportRecord copyWith({
    List<String>? imageUrls,
    List<ComposePhotoDraft>? drafts,
    bool? sourceLocked,
    QuickImportStatus? status,
    DateTime? createdAt,
    DateTime? decidedAt,
    bool clearDecidedAt = false,
    String? title,
  }) {
    return QuickImportRecord(
      id: id,
      sourceStoreId: sourceStoreId,
      sourceStoreName: sourceStoreName,
      sourceProductId: sourceProductId,
      imageUrls: imageUrls ?? this.imageUrls,
      drafts: drafts ?? this.drafts,
      sourceLocked: sourceLocked ?? this.sourceLocked,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      decidedAt: clearDecidedAt ? null : (decidedAt ?? this.decidedAt),
      title: title ?? this.title,
    );
  }
}

class QuickImportCommitResult {
  const QuickImportCommitResult({
    required this.pendingCount,
    required this.liveCount,
    required this.sourceStoreName,
    this.alreadyImportedCount = 0,
    this.importRequestId = '',
  });

  final int pendingCount;
  final int liveCount;
  final int alreadyImportedCount;
  final String sourceStoreName;
  final String importRequestId;

  int get total => pendingCount + liveCount + alreadyImportedCount;
}

/// In-memory copies of imports made this session. Replaced when the server
/// owns requests. Declined rows keep a 24-hour retry gap on this device.
class QuickImportSession {
  QuickImportSession._();

  static final QuickImportSession instance = QuickImportSession._();

  final ValueNotifier<List<QuickImportRecord>> items =
      ValueNotifier<List<QuickImportRecord>>(const []);

  int get pendingCount =>
      items.value.where((r) => r.status == QuickImportStatus.pending).length;

  QuickImportRecord? recordFor(String sourceProductId) {
    final id = sourceProductId.trim();
    if (id.isEmpty) return null;
    for (final record in items.value) {
      if (record.sourceProductId == id) return record;
    }
    return null;
  }

  /// Null when the product can be requested. Otherwise a short reason.
  String? blockReason(String sourceProductId) {
    final record = recordFor(sourceProductId);
    if (record == null || record.status != QuickImportStatus.declined) {
      return null;
    }
    final decided = record.decidedAt;
    if (decided == null) return null;
    final until = decided.add(const Duration(hours: 24));
    if (DateTime.now().isBefore(until)) {
      return 'You can request this again after 24 hours.';
    }
    return null;
  }

  ComposePhotoDraft? savedDraft(String sourceProductId, int imageIndex) {
    final record = recordFor(sourceProductId);
    if (record == null || record.drafts.isEmpty) return null;
    if (imageIndex >= 0 && imageIndex < record.drafts.length) {
      return record.drafts[imageIndex];
    }
    return record.drafts.first;
  }

  QuickImportCommitResult commit({
    required String sourceStoreId,
    required String sourceStoreName,
    required List<String> productIds,
    required List<String> imagePaths,
    required List<ComposePhotoDraft> drafts,
    required List<bool> sourceLocked,
  }) {
    final n = _min4(
      productIds.length,
      imagePaths.length,
      drafts.length,
      sourceLocked.length,
    );
    final order = <String>[];
    final grouped = <String, _GroupedImport>{};
    for (var i = 0; i < n; i++) {
      final productId = productIds[i].trim();
      final path = imagePaths[i].trim();
      if (productId.isEmpty || path.isEmpty) continue;
      final bucket = grouped.putIfAbsent(productId, () {
        order.add(productId);
        return _GroupedImport(sourceLocked: sourceLocked[i]);
      });
      bucket.paths.add(path);
      bucket.drafts.add(drafts[i]);
      if (sourceLocked[i]) bucket.sourceLocked = true;
    }

    final now = DateTime.now();
    final next = List<QuickImportRecord>.from(items.value);
    var pending = 0;
    var live = 0;
    for (final productId in order) {
      final bucket = grouped[productId]!;
      final status =
          bucket.sourceLocked
              ? QuickImportStatus.pending
              : QuickImportStatus.approved;
      if (status == QuickImportStatus.pending) {
        pending += 1;
      } else {
        live += 1;
      }
      final title = _titleFrom(bucket.drafts);
      final index = next.indexWhere(
        (r) =>
            r.sourceProductId == productId && r.sourceStoreId == sourceStoreId,
      );
      if (index >= 0) {
        final previous = next.removeAt(index);
        next.insert(
          0,
          previous.copyWith(
            imageUrls: List<String>.from(bucket.paths),
            drafts: List<ComposePhotoDraft>.from(bucket.drafts),
            sourceLocked: bucket.sourceLocked,
            status: status,
            createdAt: now,
            clearDecidedAt: true,
            title: title,
          ),
        );
      } else {
        next.insert(
          0,
          QuickImportRecord(
            id: 'qi_${productId}_${now.microsecondsSinceEpoch}',
            sourceStoreId: sourceStoreId,
            sourceStoreName: sourceStoreName,
            sourceProductId: productId,
            imageUrls: List<String>.from(bucket.paths),
            drafts: List<ComposePhotoDraft>.from(bucket.drafts),
            sourceLocked: bucket.sourceLocked,
            status: status,
            createdAt: now,
            title: title,
          ),
        );
      }
    }
    items.value = List<QuickImportRecord>.unmodifiable(next);
    return QuickImportCommitResult(
      pendingCount: pending,
      liveCount: live,
      sourceStoreName: sourceStoreName,
    );
  }

  static int _min4(int a, int b, int c, int d) {
    var n = a;
    if (b < n) n = b;
    if (c < n) n = c;
    if (d < n) n = d;
    return n;
  }

  static String _titleFrom(List<ComposePhotoDraft> drafts) {
    for (final draft in drafts) {
      for (final tag in draft.tags) {
        final t = tag.trim();
        if (t.isNotEmpty) return t;
      }
    }
    return '';
  }
}

class _GroupedImport {
  _GroupedImport({required this.sourceLocked});

  bool sourceLocked;
  final List<String> paths = [];
  final List<ComposePhotoDraft> drafts = [];
}

/// Builds a compose draft from data the client already has.
class QuickImportPrefill {
  QuickImportPrefill._();

  static ComposePhotoDraft fromStoreProduct(StoreProduct product) {
    return ComposePhotoDraft(
      spec: ComposePhotoDraft.defaults().spec,
      tags: _names(product.tags, product.title),
      stockStatus: _stock(product.stockStatus),
      mtoDays: product.mtoDays ?? 7,
      isLocked: product.isLocked,
    );
  }

  static ComposePhotoDraft fromCatalog(
    CatalogProduct product, {
    StoreProduct? fallback,
  }) {
    final spec = ProductSpec.fromCatalogProductMap(product.toFlatSpecMap());
    final names = _names(
      product.tags,
      product.title.isNotEmpty ? product.title : (fallback?.title ?? ''),
    );
    return ComposePhotoDraft(
      spec: spec,
      tags: names.isNotEmpty ? names : (fallback == null ? const [] : _names(fallback.tags, fallback.title)),
      stockStatus: _stock(product.stockStatus ?? fallback?.stockStatus),
      mtoDays: product.mtoDays ?? fallback?.mtoDays ?? 7,
      isLocked: product.isLocked || (fallback?.isLocked ?? false),
    );
  }

  static ComposeStockStatus _stock(CatalogStockStatus? status) {
    return switch (status) {
      CatalogStockStatus.outOfStock => ComposeStockStatus.outOfStock,
      CatalogStockStatus.mto => ComposeStockStatus.mto,
      _ => ComposeStockStatus.inStock,
    };
  }

  static List<String> _names(List<String> tags, String title) {
    final out = <String>[];
    for (final raw in tags) {
      final t = raw.trim();
      if (t.isEmpty) continue;
      final lower = t.toLowerCase();
      if (lower.endsWith(' pieces')) continue;
      if (lower == 'single' ||
          lower == 'group' ||
          lower == 'sub_collection' ||
          lower == 'subcollection') {
        continue;
      }
      out.add(t);
    }
    if (out.isEmpty) {
      final named = title.trim();
      final lower = named.toLowerCase();
      if (named.isNotEmpty && lower != 'item' && lower != 'product') {
        out.add(named);
      }
    }
    return out;
  }
}

class _SelectedImportPhoto {
  const _SelectedImportPhoto({
    required this.sourceProductId,
    required this.product,
    required this.imageIndex,
    required this.imageUrl,
    required this.draft,
    required this.sourceLocked,
  });

  /// Catalog product id for `POST …/imports` (not collection listing id).
  final String sourceProductId;
  final StoreProduct product;
  final int imageIndex;
  final String imageUrl;
  final ComposePhotoDraft draft;
  final bool sourceLocked;
}

/// Long-press selection → prefilled Quick upload review → local session.
class QuickImportFlow {
  QuickImportFlow._();

  static Future<bool> openFromSelection({
    required BuildContext context,
    required Set<String> photoKeys,
    required List<StoreProduct> products,
    required String sourceStoreId,
    required String sourceStoreName,
    required bool canImport,
  }) async {
    if (!canImport || photoKeys.isEmpty) return false;
    ImportQa.step(
      'Selection → compose',
      detail:
          'source=$sourceStoreId name="$sourceStoreName" '
          'keys=${photoKeys.length} products=${products.length}',
    );
    final selected = await _resolve(
      context: context,
      photoKeys: photoKeys,
      products: products,
    );
    if (!context.mounted || selected.isEmpty) return false;
    ImportQa.step(
      'Resolved photos',
      detail: [
        for (var i = 0; i < selected.length; i++)
          '[$i] id=${selected[i].sourceProductId} '
          'card=${selected[i].product.id} '
          'stock=${selected[i].draft.stockStatus.catalog.apiValue} '
          'srcLocked=${selected[i].sourceLocked} '
          'draftL=${selected[i].draft.isLocked}',
      ].join(' '),
    );

    final result = await Navigator.of(context).pushNamed(
      Routes.addProductComposeRoute,
      arguments: <String, Object?>{
        'imagePaths': [for (final photo in selected) photo.imageUrl],
        'storeId': _ownStoreId(),
        'initialIndex': 0,
        'initialDrafts': [for (final photo in selected) photo.draft],
        'importMode': true,
        'allowAddDelete': true,
        'sourceStoreId': sourceStoreId,
        'sourceStoreName': sourceStoreName,
        'sourceProductIds': [
          for (final photo in selected) photo.sourceProductId,
        ],
        'sourceLocked': [for (final photo in selected) photo.sourceLocked],
      },
    );
    if (!context.mounted) return false;
    if (result is! Map || result['quickImport'] != true) return false;

    final productIds = _strings(result['sourceProductIds']);
    final drafts = _drafts(result['photoDrafts']);
    final locked = _bools(result['sourceLocked']);
    final imagePaths = _strings(result['imagePaths']);
    final destId = _ownStoreId();
    if (destId.isEmpty || productIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create your store before importing products.'),
        ),
      );
      return false;
    }

    // One API item per unique source product (last draft wins for overrides).
    final byProduct = <String, ({ComposePhotoDraft draft, bool locked})>{};
    final order = <String>[];
    final n = [
      productIds.length,
      drafts.length,
      locked.length,
    ].reduce((a, b) => a < b ? a : b);
    for (var i = 0; i < n; i++) {
      final id = productIds[i].trim();
      if (id.isEmpty) continue;
      if (!byProduct.containsKey(id)) order.add(id);
      byProduct[id] = (draft: drafts[i], locked: locked[i]);
    }
    if (order.isEmpty) return false;

    final items = <Map<String, dynamic>>[
      for (final id in order)
        {
          'sourceProductId': id,
          'overrides': overridesFromComposeDraft(
            byProduct[id]!.draft,
            sourceLocked: byProduct[id]!.locked,
          ),
        },
    ];

    ImportQa.step(
      'Send → POST /stores/:id/imports',
      detail:
          'dest=$destId source=$sourceStoreId items=${items.length} '
          '${[
            for (final id in order)
              'id=$id srcL=${byProduct[id]!.locked} '
              'stock=${byProduct[id]!.draft.stockStatus.catalog.apiValue} '
              'draftL=${byProduct[id]!.draft.isLocked}',
          ].join(' | ')}',
    );

    // Keep local drafts so re-open review can restore edits if needed.
    QuickImportSession.instance.commit(
      sourceStoreId: sourceStoreId,
      sourceStoreName: sourceStoreName,
      productIds: productIds,
      imagePaths: imagePaths,
      drafts: drafts,
      sourceLocked: locked,
    );

    QuickImportBatchResult batch;
    try {
      batch = await ServiceLocator.get<ImportRepository>().submitBatchImport(
        destinationStoreId: destId,
        sourceStoreId: sourceStoreId,
        items: items,
      );
    } catch (e) {
      ImportQa.step('Send FAILED', detail: '$e');
      if (!context.mounted) return false;
      final msg = CatalogErrorMapper.toUserMessage(e).trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg.isEmpty ? 'Could not import. Please try again.' : msg,
          ),
        ),
      );
      return false;
    }
    if (!context.mounted) return false;

    ImportQa.step(
      'Send result',
      detail:
          'live=${batch.instantCount} pending=${batch.pendingCount} '
          'already=${batch.alreadyImportedCount} '
          'requestId=${batch.importRequestId} '
          '${[
            for (final r in batch.results)
              '${r.sourceProductId}→${r.status.name}',
          ].join(' | ')}',
    );

    final committed = QuickImportCommitResult(
      pendingCount: batch.pendingCount,
      liveCount: batch.instantCount,
      alreadyImportedCount: batch.alreadyImportedCount,
      sourceStoreName: sourceStoreName,
      importRequestId: batch.importRequestId,
    );
    if (committed.total == 0 && batch.results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing was imported.')),
      );
      return false;
    }

    final rootNav = Navigator.of(context, rootNavigator: true);
    leaveCreateProductFlow(context);
    if (batch.instantCount > 0) {
      ShellNav.request(ShellNavTab.myStore);
    }
    _showResult(rootNav, committed);
    return true;
  }

  static Future<List<_SelectedImportPhoto>> _resolve({
    required BuildContext context,
    required Set<String> photoKeys,
    required List<StoreProduct> products,
  }) async {
    final session = QuickImportSession.instance;
    final byId = <String, StoreProduct>{
      for (final product in products) product.id: product,
    };
    final pending =
        <
          ({
            StoreProduct card,
            String sourceProductId,
            int imageIndex,
            String url,
            bool cellLocked,
            CatalogStockStatus? cellStock,
          })
        >[];
    String? blocked;
    final seenBlocked = <String>{};
    for (final key in photoKeys) {
      final bar = key.lastIndexOf('|');
      if (bar <= 0) continue;
      final cardId = key.substring(0, bar);
      final imageIndex = int.tryParse(key.substring(bar + 1)) ?? 0;
      final card = byId[cardId];
      if (card == null) continue;
      final sourceProductId = card.sourceProductIdAt(imageIndex);
      if (sourceProductId.isEmpty) continue;
      if (card.importSelectionBlocked) {
        blocked ??=
            card.importFlags.isLockedTierMax
                ? 'Exclusive piece — cannot be re-imported'
                : 'This product cannot be imported';
        seenBlocked.add(sourceProductId);
        continue;
      }
      final reason = session.blockReason(sourceProductId);
      if (reason != null) {
        blocked ??= reason;
        seenBlocked.add(sourceProductId);
        continue;
      }
      final url = _imageUrl(card, imageIndex);
      if (url.isEmpty) continue;
      pending.add((
        card: card,
        sourceProductId: sourceProductId,
        imageIndex: imageIndex,
        url: url,
        cellLocked: card.isLockedAt(imageIndex),
        cellStock: card.stockStatusAt(imageIndex),
      ));
    }
    if (pending.isEmpty) {
      if (blocked != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(blocked)),
        );
      }
      return const [];
    }
    if (blocked != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(blocked)),
      );
    }

    final repo = ServiceLocator.get<CollectionRepository>();
    final fetched = <String, Future<CatalogProduct?>>{};
    Future<CatalogProduct?> load(String id) {
      return fetched.putIfAbsent(id, () async {
        try {
          return await repo
              .fetchProduct(productId: id)
              .timeout(const Duration(milliseconds: 800));
        } catch (_) {
          return null;
        }
      });
    }

    final photos = <_SelectedImportPhoto>[];
    for (final row in pending) {
      final saved = session.savedDraft(row.sourceProductId, 0);
      if (saved != null) {
        photos.add(
          _SelectedImportPhoto(
            sourceProductId: row.sourceProductId,
            product: row.card,
            imageIndex: row.imageIndex,
            imageUrl: row.url,
            draft: saved,
            sourceLocked: row.cellLocked || saved.isLocked,
          ),
        );
        continue;
      }
      // Fetch the **cell** product (not the collection listing id).
      final catalog = await load(row.sourceProductId);
      final fallback = row.card.copyWith(
        id: row.sourceProductId,
        isLocked: row.cellLocked,
        stockStatus: row.cellStock,
        clearStockStatus: row.cellStock == null,
      );
      var draft =
          catalog == null
              ? QuickImportPrefill.fromStoreProduct(fallback)
              : QuickImportPrefill.fromCatalog(catalog, fallback: fallback);
      final sourceLocked =
          row.cellLocked || (catalog?.isLocked ?? false) || draft.isLocked;
      if (sourceLocked && !draft.isLocked) {
        draft = draft.copyWith(isLocked: true);
      }
      photos.add(
        _SelectedImportPhoto(
          sourceProductId: row.sourceProductId,
          product: row.card,
          imageIndex: row.imageIndex,
          imageUrl: row.url,
          draft: draft,
          sourceLocked: sourceLocked,
        ),
      );
    }
    return photos;
  }

  static String _imageUrl(StoreProduct product, int index) {
    if (index >= 0 &&
        index < product.imagePaths.length &&
        product.imagePaths[index].trim().isNotEmpty) {
      return product.imagePaths[index].trim();
    }
    if (product.imagePaths.isNotEmpty) return product.imagePaths.first.trim();
    return '';
  }

  static String _ownStoreId() {
    final session = ServiceLocator.get<CatalogSession>();
    final own = session.profile?.ownStore?.id.trim() ?? '';
    if (own.isNotEmpty) return own;
    return session.ownStoreId?.trim() ?? '';
  }

  static void _showResult(NavigatorState rootNav, QuickImportCommitResult result) {
    final source = result.sourceStoreName.trim().isEmpty
        ? 'the source store'
        : result.sourceStoreName.trim();
    final parts = <String>[];
    if (result.liveCount > 0) {
      parts.add(
        result.liveCount == 1
            ? 'Imported 1'
            : 'Imported ${result.liveCount}',
      );
    }
    if (result.pendingCount > 0) {
      parts.add(
        '${result.pendingCount} sent to $source for approval',
      );
    }
    if (result.alreadyImportedCount > 0) {
      parts.add(
        result.alreadyImportedCount == 1
            ? '1 already in your store'
            : '${result.alreadyImportedCount} already in your store',
      );
    }
    final text =
        parts.isEmpty ? 'Import finished' : parts.join(' · ');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = rootNav.context;
      if (!ctx.mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(ctx);
      if (messenger == null) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(text),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              final session = ServiceLocator.get<CatalogSession>();
              final own = session.profile?.ownStore;
              final storeId = (own?.id.trim().isNotEmpty == true)
                  ? own!.id.trim()
                  : (session.ownStoreId?.trim() ?? '');
              final storeName = (own?.name.trim().isNotEmpty == true)
                  ? own!.name.trim()
                  : 'Your Store';
              rootNav.pushNamed(
                Routes.storeImportRequestsRoute,
                arguments: <String, Object?>{
                  'storeId': storeId,
                  'storeName': storeName,
                  'initialTab': 1,
                },
              );
            },
          ),
        ),
      );
    });
  }

  static List<String> _strings(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw) item is String ? item.trim() : '',
    ];
  }

  static List<bool> _bools(Object? raw) {
    if (raw is! List) return const [];
    return [for (final item in raw) item == true];
  }

  static List<ComposePhotoDraft> _drafts(Object? raw) {
    if (raw is! List) return const [];
    return raw.whereType<ComposePhotoDraft>().toList(growable: false);
  }
}
