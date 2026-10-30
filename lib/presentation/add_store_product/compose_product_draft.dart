import 'package:equatable/equatable.dart';
import 'package:project_c/models/bulk_upload.dart';
import 'package:project_c/models/catalog/catalog_stock_status.dart';

/// Stock UI on compose (frontend-first; batch API later).
enum ComposeStockStatus { inStock, outOfStock, mto }

extension ComposeStockStatusX on ComposeStockStatus {
  CatalogStockStatus get catalog => switch (this) {
    ComposeStockStatus.inStock => CatalogStockStatus.inStock,
    ComposeStockStatus.outOfStock => CatalogStockStatus.outOfStock,
    ComposeStockStatus.mto => CatalogStockStatus.mto,
  };
}

ComposeStockStatus composeStockStatusFromName(String? raw) {
  // Accept API (`in`/`out`/`mto`), enum names, and legacy labels.
  final parsed = CatalogStockStatus.tryParse(raw);
  if (parsed != null) {
    return switch (parsed) {
      CatalogStockStatus.inStock => ComposeStockStatus.inStock,
      CatalogStockStatus.outOfStock => ComposeStockStatus.outOfStock,
      CatalogStockStatus.mto => ComposeStockStatus.mto,
    };
  }
  switch ((raw ?? '').trim()) {
    case 'outOfStock':
      return ComposeStockStatus.outOfStock;
    case 'mto':
      return ComposeStockStatus.mto;
    case 'inStock':
    default:
      return ComposeStockStatus.inStock;
  }
}

/// Which rail flyout is open (one at a time).
enum ComposeRailFlyout {
  none,
  metal,
  purity,
  wastage,
  category,
  size,
  stock,
}

/// Per-photo draft on the post-gallery compose screen.
class ComposePhotoDraft extends Equatable {
  const ComposePhotoDraft({
    this.spec = const ProductSpec(),
    this.tags = const [],
    this.stockStatus = ComposeStockStatus.inStock,
    this.mtoDays = 7,
    this.isLocked = false,
  });

  final ProductSpec spec;
  final List<String> tags;
  final ComposeStockStatus stockStatus;
  final int mtoDays;
  final bool isLocked;

  ComposePhotoDraft copyWith({
    ProductSpec? spec,
    List<String>? tags,
    ComposeStockStatus? stockStatus,
    int? mtoDays,
    bool? isLocked,
  }) {
    return ComposePhotoDraft(
      spec: spec ?? this.spec,
      tags: tags ?? this.tags,
      stockStatus: stockStatus ?? this.stockStatus,
      mtoDays: mtoDays ?? this.mtoDays,
      isLocked: isLocked ?? this.isLocked,
    );
  }

  /// Defaults: gold / first purity / wastage 4% / free size / in stock / unlocked.
  factory ComposePhotoDraft.defaults() {
    return ComposePhotoDraft(
      spec: ProductSpec(
        metalType: const ['gold'],
        purity: ProductSpec.defaultPurityForMetal('gold'),
        purityMode: FieldMode.fixed,
        wastageMode: FieldMode.fixed,
        wastagePercent: 4,
        sizeMode: SizeMode.free,
        category: '',
      ),
    );
  }

  @override
  List<Object?> get props => [spec, tags, stockStatus, mtoDays, isLocked];
}

/// Feature-flagged auto-advance Metal → Purity → Wastage → Category.
const bool kComposeAutoAdvance = true;

/// Parse caption tokens into draft updates (design caption table).
ComposePhotoDraft applyCaptionToken(ComposePhotoDraft draft, String raw) {
  var token = raw.trim();
  if (token.isEmpty) return draft;
  if (token.startsWith('#')) token = token.substring(1).trim();
  if (token.isEmpty) return draft;
  final lower = token.toLowerCase();

  // Weight fixed: 8.44g / 8.44gm
  final fixedWeight = RegExp(
    r'^(\d+(?:\.\d+)?)\s*g(?:m)?$',
    caseSensitive: false,
  ).firstMatch(token);
  if (fixedWeight != null) {
    final v = double.tryParse(fixedWeight.group(1)!);
    if (v != null && v > 0) {
      return draft.copyWith(
        spec: draft.spec.copyWith(
          weightMode: WeightMode.fixed,
          grossMin: v,
          grossMax: v,
        ),
      );
    }
  }

  // Weight range: 8.4-11.3g
  final rangeWeight = RegExp(
    r'^(\d+(?:\.\d+)?)\s*[-–]\s*(\d+(?:\.\d+)?)\s*g(?:m)?$',
    caseSensitive: false,
  ).firstMatch(token);
  if (rangeWeight != null) {
    final a = double.tryParse(rangeWeight.group(1)!);
    final b = double.tryParse(rangeWeight.group(2)!);
    if (a != null && b != null && a > 0 && b > 0) {
      final min = a <= b ? a : b;
      final max = a <= b ? b : a;
      return draft.copyWith(
        spec: draft.spec.copyWith(
          weightMode: WeightMode.range,
          grossMin: min,
          grossMax: max,
        ),
      );
    }
  }

  // Wastage: 12%
  final wastage = RegExp(
    r'^(\d+(?:\.\d+)?)\s*%$',
  ).firstMatch(token);
  if (wastage != null) {
    final v = double.tryParse(wastage.group(1)!);
    if (v != null && v >= 0 && v <= 100) {
      return draft.copyWith(
        spec: draft.spec.copyWith(
          wastageMode: FieldMode.fixed,
          wastagePercent: v,
        ),
      );
    }
  }

  // Metal
  for (final metal in ProductSpec.composeMetalOptions) {
    if (lower == metal || lower == metal.replaceAll(' ', '')) {
      return draft.copyWith(
        spec: draft.spec.copyWith(
          metalType: [metal],
          purity: ProductSpec.defaultPurityForMetal(metal),
          purityMode: FieldMode.fixed,
        ),
        tags: _ensureTag(draft.tags, metal),
      );
    }
  }

  // Category
  for (final cat in ProductSpec.composeCategoryOptions) {
    if (lower == cat) {
      return draft.copyWith(
        spec: draft.spec.copyWith(category: cat),
        tags: _ensureTag(draft.tags, cat, insertFirst: true),
      );
    }
  }

  // Free product name (spaces allowed; stored lower for dedupe).
  return draft.copyWith(tags: _ensureTag(draft.tags, lower));
}

List<String> _ensureTag(
  List<String> tags,
  String tag, {
  bool insertFirst = false,
}) {
  final t = tag.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (t.isEmpty) return tags;
  final next = [
    for (final x in tags) x.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '),
  ];
  next.removeWhere((e) => e == t);
  if (insertFirst) {
    return [t, ...next];
  }
  return [...next, t];
}

/// Add one or more product names (comma-split). Drops case-insensitive dupes.
ComposePhotoDraft addProductNames(ComposePhotoDraft draft, String raw) {
  var next = draft;
  for (final part in raw.split(',')) {
    final piece = part.trim();
    if (piece.isEmpty) continue;
    next = applyCaptionToken(next, piece);
  }
  return next;
}

String composeTitleFromDraft(ComposePhotoDraft draft) {
  final cat = draft.spec.category.trim();
  if (cat.isNotEmpty) return ProductSpec.metalLabel(cat);
  if (draft.tags.isNotEmpty) return draft.tags.first;
  final metal =
      draft.spec.metalType.isNotEmpty ? draft.spec.metalType.first : 'gold';
  return ProductSpec.metalLabel(metal);
}
