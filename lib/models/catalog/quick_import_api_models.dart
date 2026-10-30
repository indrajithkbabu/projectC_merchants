import 'package:equatable/equatable.dart';
import 'package:project_c/models/bulk_upload.dart';
import 'package:project_c/presentation/add_store_product/compose_product_draft.dart';

/// Feed / product enrichment from quick-import-api.md.
class ProductImportFlags extends Equatable {
  const ProductImportFlags({
    this.canImport,
    this.importRestrictionReason,
    this.isAlreadyImported = false,
    this.isSourceDeleted = false,
    this.importStatus,
  });

  final bool? canImport;
  final String? importRestrictionReason;
  final bool isAlreadyImported;
  final bool isSourceDeleted;
  final String? importStatus;

  bool get isLockedTierMax =>
      importRestrictionReason?.trim().toUpperCase() == 'LOCKED_TIER_MAX';

  /// Disable selection when exclusivity cap blocks re-import (API §2.1).
  bool get selectionBlocked => isLockedTierMax;

  /// Destination copy waiting on source-owner approval (`importStatus: pending`).
  bool get isImportPending =>
      (importStatus ?? '').trim().toLowerCase() == 'pending';

  /// Destination copy rejected by source (`importStatus: declined`) — owner only.
  bool get isImportDeclined =>
      (importStatus ?? '').trim().toLowerCase() == 'declined';

  factory ProductImportFlags.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const ProductImportFlags();
    return ProductImportFlags(
      canImport: json.containsKey('canImport') ? json['canImport'] == true : null,
      importRestrictionReason:
          (json['importRestrictionReason'] as String?)?.trim(),
      isAlreadyImported: json['isAlreadyImported'] == true,
      isSourceDeleted:
          json['isSourceDeleted'] == true || json['sourceDeleted'] == true,
      importStatus: (json['importStatus'] as String?)?.trim(),
    );
  }

  @override
  List<Object?> get props => [
    canImport,
    importRestrictionReason,
    isAlreadyImported,
    isSourceDeleted,
    importStatus,
  ];
}

enum QuickImportItemStatus { live, pending, alreadyImported, notFound, unknown }

QuickImportItemStatus quickImportItemStatusFrom(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'live':
      return QuickImportItemStatus.live;
    case 'pending':
      return QuickImportItemStatus.pending;
    case 'already_imported':
    case 'alreadyimported':
      return QuickImportItemStatus.alreadyImported;
    case 'not_found':
    case 'notfound':
      return QuickImportItemStatus.notFound;
    default:
      return QuickImportItemStatus.unknown;
  }
}

class QuickImportBatchItemResult extends Equatable {
  const QuickImportBatchItemResult({
    required this.sourceProductId,
    required this.status,
    this.createdProductId = '',
  });

  final String sourceProductId;
  final QuickImportItemStatus status;
  final String createdProductId;

  factory QuickImportBatchItemResult.fromJson(Map<String, dynamic> json) {
    return QuickImportBatchItemResult(
      sourceProductId:
          (json['sourceProductId'] as String?)?.trim() ??
          (json['source_product_id'] as String?)?.trim() ??
          '',
      createdProductId:
          (json['createdProductId'] as String?)?.trim() ??
          (json['created_product_id'] as String?)?.trim() ??
          '',
      status: quickImportItemStatusFrom(json['status'] as String?),
    );
  }

  @override
  List<Object?> get props => [sourceProductId, status, createdProductId];
}

class QuickImportBatchResult extends Equatable {
  const QuickImportBatchResult({
    required this.success,
    required this.results,
    this.importRequestId = '',
    this.total = 0,
    this.instantCount = 0,
    this.pendingCount = 0,
    this.alreadyImportedCount = 0,
  });

  final bool success;
  final String importRequestId;
  final int total;
  final int instantCount;
  final int pendingCount;
  final int alreadyImportedCount;
  final List<QuickImportBatchItemResult> results;

  factory QuickImportBatchResult.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const QuickImportBatchResult(success: false, results: []);
    }
    final summary =
        json['summary'] is Map
            ? Map<String, dynamic>.from(json['summary'] as Map)
            : const <String, dynamic>{};
    final rawResults = json['results'];
    final results = <QuickImportBatchItemResult>[];
    if (rawResults is List) {
      for (final row in rawResults) {
        if (row is Map) {
          results.add(
            QuickImportBatchItemResult.fromJson(
              Map<String, dynamic>.from(row),
            ),
          );
        }
      }
    }
    return QuickImportBatchResult(
      success: json['success'] != false,
      importRequestId: (json['importRequestId'] as String?)?.trim() ?? '',
      total: (summary['total'] as num?)?.toInt() ?? results.length,
      instantCount: (summary['instantCount'] as num?)?.toInt() ??
          results.where((r) => r.status == QuickImportItemStatus.live).length,
      pendingCount: (summary['pendingCount'] as num?)?.toInt() ??
          results
              .where((r) => r.status == QuickImportItemStatus.pending)
              .length,
      alreadyImportedCount:
          (summary['alreadyImportedCount'] as num?)?.toInt() ??
          results
              .where((r) => r.status == QuickImportItemStatus.alreadyImported)
              .length,
      results: results,
    );
  }

  @override
  List<Object?> get props => [
    success,
    importRequestId,
    total,
    instantCount,
    pendingCount,
    alreadyImportedCount,
    results,
  ];
}

/// Sparse overrides for `POST …/imports` items.
Map<String, dynamic> overridesFromComposeDraft(
  ComposePhotoDraft draft, {
  required bool sourceLocked,
}) {
  final spec = draft.spec;
  final out = <String, dynamic>{};
  final metal =
      spec.metalType.isEmpty ? '' : spec.metalType.first.trim();
  if (metal.isNotEmpty) out['metal'] = metal;
  final purity = (spec.purity ?? '').trim();
  if (purity.isNotEmpty) out['purity'] = purity;
  if (spec.grossMin != null) out['gross_min'] = spec.grossMin;
  if (spec.grossMax != null) out['gross_max'] = spec.grossMax;
  if (spec.deductStone && (spec.reduction ?? 0) > 0) {
    out['stone_weight'] = spec.reduction;
  }
  if (spec.wastagePercent != null) out['wastage_pct'] = spec.wastagePercent;
  final category = spec.category.trim();
  if (category.isNotEmpty) out['category'] = category;
  if (spec.sizeValue != null) out['size_value'] = spec.sizeValue;
  out['size_unit'] = switch (spec.sizeUnit) {
    SizeUnit.inch => 'in',
    SizeUnit.cm => 'cm',
    SizeUnit.mm => 'mm',
    SizeUnit.custom =>
      spec.customUnit.trim().isEmpty ? 'mm' : spec.customUnit.trim(),
  };
  if (draft.tags.isNotEmpty) {
    out['tags'] = [
      for (final t in draft.tags) t.trim(),
    ].where((t) => t.isNotEmpty).toList();
  }
  // API: stock override allowed on unlocked only.
  if (!sourceLocked) {
    out['stock_status'] = draft.stockStatus.catalog.apiValue;
    if (draft.stockStatus == ComposeStockStatus.mto) {
      out['mto_days'] = draft.mtoDays;
    }
  }
  if (draft.isLocked) out['is_locked'] = true;
  return out;
}

class ImportRequestStoreRef extends Equatable {
  const ImportRequestStoreRef({
    required this.id,
    required this.name,
    this.slug = '',
    this.phone = '',
    this.logo = '',
  });

  final String id;
  final String name;
  final String slug;
  final String phone;
  final String logo;

  factory ImportRequestStoreRef.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ImportRequestStoreRef(id: '', name: '');
    }
    return ImportRequestStoreRef(
      id:
          (json['_id'] as String?)?.trim() ??
          (json['id'] as String?)?.trim() ??
          '',
      name: (json['name'] as String?)?.trim() ?? '',
      slug: (json['slug'] as String?)?.trim() ?? '',
      phone: (json['phone'] as String?)?.trim() ?? '',
      logo:
          (json['logo'] as String?)?.trim() ??
          (json['logoUrl'] as String?)?.trim() ??
          (json['coverImageUrl'] as String?)?.trim() ??
          '',
    );
  }

  @override
  List<Object?> get props => [id, name, slug, phone, logo];
}

class ImportRequestProductRow extends Equatable {
  const ImportRequestProductRow({
    required this.title,
    required this.imageUrl,
    this.sourceProductId = '',
    this.createdProductId = '',
    this.importStatus = '',
    this.targetCollectionName = '',
  });

  final String title;
  final String imageUrl;
  final String sourceProductId;
  final String createdProductId;

  /// Row `status` or `createdProduct.importStatus` (`pending` / `live` / …).
  final String importStatus;
  final String targetCollectionName;

  /// Id for decision API (created or source — BE accepts either).
  String get decisionProductId =>
      createdProductId.trim().isNotEmpty
          ? createdProductId.trim()
          : sourceProductId.trim();

  bool get isItemPending {
    final s = importStatus.trim().toLowerCase();
    return s.isEmpty || s == 'pending';
  }

  bool get isItemApproved {
    final s = importStatus.trim().toLowerCase();
    return s == 'live' || s == 'approved';
  }

  bool get isItemDeclined {
    final s = importStatus.trim().toLowerCase();
    return s == 'declined' || s == 'rejected';
  }

  factory ImportRequestProductRow.fromJson(Map<String, dynamic> json) {
    final source =
        json['sourceProduct'] is Map
            ? Map<String, dynamic>.from(json['sourceProduct'] as Map)
            : const <String, dynamic>{};
    final created =
        json['createdProduct'] is Map
            ? Map<String, dynamic>.from(json['createdProduct'] as Map)
            : const <String, dynamic>{};
    final primary =
        source['primaryImage'] is Map
            ? Map<String, dynamic>.from(source['primaryImage'] as Map)
            : (created['primaryImage'] is Map
                ? Map<String, dynamic>.from(created['primaryImage'] as Map)
                : const <String, dynamic>{});
    String imageFrom(Map<String, dynamic> map) {
      final direct =
          (map['url'] as String?)?.trim() ??
          (map['thumbnailUrl'] as String?)?.trim() ??
          '';
      if (direct.isNotEmpty) return direct;
      final images = map['images'];
      if (images is List && images.isNotEmpty && images.first is Map) {
        final first = Map<String, dynamic>.from(images.first as Map);
        return (first['url'] as String?)?.trim() ??
            (first['thumbnailUrl'] as String?)?.trim() ??
            '';
      }
      return '';
    }

    final rowStatus = (json['status'] as String?)?.trim() ?? '';
    final createdStatus = (created['importStatus'] as String?)?.trim() ?? '';
    final imageUrl =
        (primary['url'] as String?)?.trim() ??
        (primary['thumbnailUrl'] as String?)?.trim() ??
        '';
    return ImportRequestProductRow(
      sourceProductId:
          (source['_id'] as String?)?.trim() ??
          (source['id'] as String?)?.trim() ??
          '',
      createdProductId:
          (created['_id'] as String?)?.trim() ??
          (created['id'] as String?)?.trim() ??
          '',
      title:
          (source['title'] as String?)?.trim() ??
          (created['title'] as String?)?.trim() ??
          'Product',
      imageUrl:
          imageUrl.isNotEmpty
              ? imageUrl
              : (imageFrom(source).isNotEmpty
                  ? imageFrom(source)
                  : imageFrom(created)),
      importStatus: rowStatus.isNotEmpty ? rowStatus : createdStatus,
      targetCollectionName:
          (json['targetCollectionName'] as String?)?.trim() ?? '',
    );
  }

  ImportRequestProductRow copyWith({String? importStatus}) {
    return ImportRequestProductRow(
      title: title,
      imageUrl: imageUrl,
      sourceProductId: sourceProductId,
      createdProductId: createdProductId,
      importStatus: importStatus ?? this.importStatus,
      targetCollectionName: targetCollectionName,
    );
  }

  @override
  List<Object?> get props => [
    title,
    imageUrl,
    sourceProductId,
    createdProductId,
    importStatus,
    targetCollectionName,
  ];
}

/// Batch import request card (Received / Sent) — quick-import-api.md §2.3.
class ImportRequestBatch extends Equatable {
  const ImportRequestBatch({
    required this.id,
    required this.status,
    required this.createdAt,
    this.decidedAt,
    this.requesterStore = const ImportRequestStoreRef(id: '', name: ''),
    this.sourceStore = const ImportRequestStoreRef(id: '', name: ''),
    this.requesterPhone = '',
    this.products = const [],
  });

  final String id;
  final String status;
  final DateTime? createdAt;
  final DateTime? decidedAt;
  final ImportRequestStoreRef requesterStore;
  final ImportRequestStoreRef sourceStore;
  final String requesterPhone;
  final List<ImportRequestProductRow> products;

  bool get isPending =>
      status == 'pending' || status == 'partially_approved';

  bool get isApproved => status == 'approved';
  bool get isDeclined => status == 'declined' || status == 'rejected';
  bool get isCancelled => status == 'cancelled' || status == 'deleted';
  bool get isPartial => status == 'partially_approved';

  /// Requester may cancel only while the whole request is still `pending`
  /// (BE `DELETE|POST …/import-requests/:id[/cancel]`).
  bool get canCancel => status == 'pending';

  /// True when the source owner can still decide at least one product.
  bool get hasActionablePending {
    if (products.isNotEmpty) return products.any((p) => p.isItemPending);
    return isPending;
  }

  String get primaryTitle =>
      products.isEmpty ? 'Import request' : products.first.title;

  String get primaryImageUrl =>
      products.isEmpty ? '' : products.first.imageUrl;

  factory ImportRequestBatch.fromJson(Map<String, dynamic> json) {
    final products = <ImportRequestProductRow>[];
    final raw = json['products'];
    if (raw is List) {
      for (final row in raw) {
        if (row is Map) {
          products.add(
            ImportRequestProductRow.fromJson(Map<String, dynamic>.from(row)),
          );
        }
      }
    }
    final requesterUser =
        json['requesterUser'] is Map
            ? Map<String, dynamic>.from(json['requesterUser'] as Map)
            : const <String, dynamic>{};
    DateTime? parse(Object? raw) {
      if (raw is String && raw.trim().isNotEmpty) {
        return DateTime.tryParse(raw.trim())?.toLocal();
      }
      return null;
    }

    return ImportRequestBatch(
      id:
          (json['id'] as String?)?.trim() ??
          (json['_id'] as String?)?.trim() ??
          '',
      status: (json['status'] as String?)?.trim().toLowerCase() ?? 'pending',
      createdAt: parse(json['createdAt']),
      decidedAt: parse(json['decidedAt']),
      requesterStore: ImportRequestStoreRef.fromJson(
        json['requesterStore'] is Map
            ? Map<String, dynamic>.from(json['requesterStore'] as Map)
            : null,
      ),
      sourceStore: ImportRequestStoreRef.fromJson(
        json['sourceStore'] is Map
            ? Map<String, dynamic>.from(json['sourceStore'] as Map)
            : null,
      ),
      requesterPhone:
          (requesterUser['phone'] as String?)?.trim() ??
          (json['requesterStore'] is Map
              ? ((json['requesterStore'] as Map)['phone'] as String?)?.trim() ??
                  ''
              : ''),
      products: products,
    );
  }

  ImportRequestBatch copyWith({
    String? status,
    DateTime? decidedAt,
    List<ImportRequestProductRow>? products,
  }) {
    return ImportRequestBatch(
      id: id,
      status: status ?? this.status,
      createdAt: createdAt,
      decidedAt: decidedAt ?? this.decidedAt,
      requesterStore: requesterStore,
      sourceStore: sourceStore,
      requesterPhone: requesterPhone,
      products: products ?? this.products,
    );
  }

  @override
  List<Object?> get props => [
    id,
    status,
    createdAt,
    decidedAt,
    requesterStore,
    sourceStore,
    requesterPhone,
    products,
  ];
}
