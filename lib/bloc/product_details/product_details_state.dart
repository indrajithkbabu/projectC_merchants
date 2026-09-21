part of 'product_details_bloc.dart';

class ProductDetailsState extends Equatable {
  const ProductDetailsState({
    required this.product,
    required this.storeName,
    required this.storeLink,
    this.storeId,
    this.isOwnStore = false,
    this.initialImageIndex = 0,
    this.galleryFeed,
    this.galleryFeedIndex = 0,
    this.isLoadingPhotos = false,
    this.revision = 1,
    this.apiTag = '',
    this.specifications,
    this.precisionTag = '',
    this.subGroups = const [],
    this.canEdit = false,
    this.canDelete = false,
    this.shouldOpenEdit = false,
    this.isDeleting = false,
    this.isDeleted = false,
    this.infoMessage,
  });

  final StoreProduct product;
  final String storeName;
  final String storeLink;
  final String? storeId;
  final bool isOwnStore;
  final int initialImageIndex;

  /// When opened from store gallery: swipe across all photos (all groups/dates).
  final List<ProductDetailsFeedItem>? galleryFeed;
  final int galleryFeedIndex;

  final bool isLoadingPhotos;
  final int revision;
  final String apiTag;
  final ProductSpec? specifications;
  final String precisionTag;
  final List<CollectionSubGroup> subGroups;
  final bool canEdit;
  final bool canDelete;
  final bool shouldOpenEdit;
  final bool isDeleting;
  final bool isDeleted;
  final String? infoMessage;

  bool get hasGalleryFeed =>
      galleryFeed != null && galleryFeed!.isNotEmpty;

  /// Display title for the photo at [imageIndex]: collection name for main,
  /// sub-group name for Precise/Standalone — numbered within that group
  /// (same scheme as collection browse captions).
  String titleForPhoto(int imageIndex) {
    final collectionName =
        product.title.trim().isEmpty ? 'Item' : product.title.trim();
    final photoId =
        imageIndex >= 0 && imageIndex < product.photoAssetIds.length
            ? product.photoAssetIds[imageIndex].trim()
            : '';

    if (photoId.isNotEmpty) {
      for (final sub in subGroups) {
        final subPhotos = [
          for (final p in sub.photos)
            if (p.url.trim().isNotEmpty) p,
        ];
        final idx = subPhotos.indexWhere(
          (p) => (p.id?.trim() ?? '') == photoId,
        );
        if (idx < 0) continue;
        final base =
            sub.name.trim().isEmpty ? collectionName : sub.name.trim();
        return '$base ${idx + 1}';
      }
    }

    final inSub = <String>{
      for (final sub in subGroups)
        for (final p in sub.photos)
          if ((p.id?.trim() ?? '').isNotEmpty) p.id!.trim(),
    };
    final mainIds = [
      for (final id in product.photoAssetIds)
        if (id.trim().isNotEmpty && !inSub.contains(id.trim())) id.trim(),
    ];
    if (photoId.isNotEmpty) {
      final mainIdx = mainIds.indexOf(photoId);
      if (mainIdx >= 0) return '$collectionName ${mainIdx + 1}';
    }

    return collectionName;
  }

  /// Specs line for the photo at [imageIndex] (sub-group Precise overrides group).
  /// Null when title-only (no weight/purity/size line to show).
  PhotoSpecDisplay? specDisplayForPhoto(int imageIndex) {
    final photoId =
        imageIndex >= 0 && imageIndex < product.photoAssetIds.length
            ? product.photoAssetIds[imageIndex].trim()
            : '';

    if (photoId.isNotEmpty) {
      for (final sub in subGroups) {
        final inSub = sub.photos.any((p) => (p.id?.trim() ?? '') == photoId);
        if (!inSub) continue;
        final isStandalone = sub.name.toLowerCase().contains('standalone');
        final subSpec = ProductSpec.fromApiJson(sub.specifications?.toJson());
        final fine = subSpec.fineWeightDisplay;
        final tag = sub.precisionTag.trim();
        final fallback = _formatSpec(subSpec);
        final line =
            tag.isNotEmpty
                ? _displayPrecisionTag(tag)
                : (fallback ?? '');
        if (line.isEmpty) {
          if (isStandalone && fine == null) return null;
          if (isStandalone) {
            return PhotoSpecDisplay(line: '', fineWeightLine: fine);
          }
          return PhotoSpecDisplay(
            line: 'Precise details applied',
            fineWeightLine: fine,
          );
        }
        return PhotoSpecDisplay(line: line, fineWeightLine: fine);
      }
    }

    final fine = specifications?.fineWeightDisplay;
    final groupTag = precisionTag.trim();
    if (groupTag.isNotEmpty) {
      return PhotoSpecDisplay(
        line: _displayPrecisionTag(groupTag),
        fineWeightLine: fine,
      );
    }

    final fallback = _formatSpec(specifications);
    if ((fallback == null || fallback.isEmpty) && fine == null) return null;
    return PhotoSpecDisplay(
      line: fallback ?? '',
      fineWeightLine: fine,
    );
  }

  /// API `precisionTag` → details chrome:
  /// `22K (92%) | 55g | 2% W | Free Size` → `92 | Gross 55g | 2% | Free Size`
  /// `22K (92%) | 25g (Net: 20g) | 1% W | Free Size` → `92 | Net 25g | 1% | Free Size`
  /// `22K (92%) | 10-20g | 1% W | Free Size` → `92 | Gross 10-20g | 1% | Free Size`
  static String _displayPrecisionTag(String tag) {
    final parts =
        tag
            .split('|')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
    if (parts.isEmpty) return tag.trim();

    final out = <String>[];
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];

      final karat = RegExp(
        r'^(\d+(?:\.\d+)?)K\s*\(([^)]+)\)\s*$',
        caseSensitive: false,
      ).firstMatch(part);
      if (karat != null) {
        out.add(_purityDisplay(karat.group(2)!));
        continue;
      }

      // Already-stripped purity like `92%` (first segment only).
      if (i == 0 && RegExp(r'^\d+(?:\.\d+)?%\s*$').hasMatch(part)) {
        out.add(_purityDisplay(part));
        continue;
      }

      final withNet = RegExp(
        r'^(\d+(?:\.\d+)?)\s*g\s*\(\s*Net:\s*[^)]+\)\s*$',
        caseSensitive: false,
      ).firstMatch(part);
      if (withNet != null) {
        out.add('Net ${withNet.group(1)}g');
        continue;
      }

      // Fixed `55g` or range `10-20g` / `10–20g`.
      final gross = RegExp(
        r'^(\d+(?:\.\d+)?(?:\s*[-–]\s*\d+(?:\.\d+)?)?)\s*g\s*$',
        caseSensitive: false,
      ).firstMatch(part);
      if (gross != null) {
        final weight = gross
            .group(1)!
            .replaceAll(RegExp(r'\s*[-–]\s*'), '-')
            .trim();
        out.add('Gross ${weight}g');
        continue;
      }

      final wastage = RegExp(
        r'^(\d+(?:\.\d+)?)\s*%\s*W\s*$',
        caseSensitive: false,
      ).firstMatch(part);
      if (wastage != null) {
        out.add('${wastage.group(1)}%');
        continue;
      }

      out.add(part);
    }
    return out.join(' | ');
  }

  static String _purityDisplay(String raw) {
    var value = raw.trim();
    if (value.endsWith('%')) {
      value = value.substring(0, value.length - 1).trim();
    }
    return value;
  }

  static String? _formatSpec(ProductSpec? spec) {
    if (spec == null) return null;
    final parts = <String>[];
    if (spec.purityMode == FieldMode.varied) {
      parts.add('Varied Purity');
    } else if (spec.purity != null && spec.purity!.isNotEmpty) {
      parts.add(_purityDisplay(spec.purity!));
    }
    if (spec.grossMin != null) {
      if (spec.weightMode == WeightMode.range && spec.grossMax != null) {
        parts.add('Gross ${spec.grossMin}-${spec.grossMax}g');
      } else {
        final net = spec.netLabel;
        if (net != '—') {
          parts.add('Net ${spec.grossMin}g');
        } else {
          parts.add('Gross ${spec.grossMin}g');
        }
      }
    }
    if (spec.wastageMode == FieldMode.fixed && spec.wastagePercent != null) {
      parts.add('${spec.wastagePercent}%');
    }
    if (spec.sizeMode == SizeMode.free) {
      parts.add('Free Size');
    } else if (spec.sizeMode == SizeMode.fixed && spec.sizeValue != null) {
      final unit =
          spec.sizeUnit == SizeUnit.custom
              ? spec.customUnit.trim()
              : spec.sizeUnit.name;
      parts.add('${spec.sizeValue} $unit');
    }
    if (parts.isEmpty) return null;
    return parts.join(' | ');
  }

  ProductDetailsState copyWith({
    StoreProduct? product,
    String? storeName,
    String? storeLink,
    String? storeId,
    bool? isOwnStore,
    int? initialImageIndex,
    List<ProductDetailsFeedItem>? galleryFeed,
    int? galleryFeedIndex,
    bool? isLoadingPhotos,
    int? revision,
    String? apiTag,
    ProductSpec? specifications,
    bool clearSpecifications = false,
    String? precisionTag,
    List<CollectionSubGroup>? subGroups,
    bool? canEdit,
    bool? canDelete,
    bool? shouldOpenEdit,
    bool clearShouldOpenEdit = false,
    bool? isDeleting,
    bool? isDeleted,
    bool clearDeleted = false,
    String? infoMessage,
    bool clearInfoMessage = false,
  }) {
    return ProductDetailsState(
      product: product ?? this.product,
      storeName: storeName ?? this.storeName,
      storeLink: storeLink ?? this.storeLink,
      storeId: storeId ?? this.storeId,
      isOwnStore: isOwnStore ?? this.isOwnStore,
      initialImageIndex: initialImageIndex ?? this.initialImageIndex,
      galleryFeed: galleryFeed ?? this.galleryFeed,
      galleryFeedIndex: galleryFeedIndex ?? this.galleryFeedIndex,
      isLoadingPhotos: isLoadingPhotos ?? this.isLoadingPhotos,
      revision: revision ?? this.revision,
      apiTag: apiTag ?? this.apiTag,
      specifications:
          clearSpecifications
              ? null
              : (specifications ?? this.specifications),
      precisionTag: precisionTag ?? this.precisionTag,
      subGroups: subGroups ?? this.subGroups,
      canEdit: canEdit ?? this.canEdit,
      canDelete: canDelete ?? this.canDelete,
      shouldOpenEdit:
          clearShouldOpenEdit
              ? false
              : (shouldOpenEdit ?? this.shouldOpenEdit),
      isDeleting: isDeleting ?? this.isDeleting,
      isDeleted: clearDeleted ? false : (isDeleted ?? this.isDeleted),
      infoMessage: clearInfoMessage ? null : (infoMessage ?? this.infoMessage),
    );
  }

  @override
  List<Object?> get props => [
    product,
    storeName,
    storeLink,
    storeId,
    isOwnStore,
    initialImageIndex,
    galleryFeed,
    galleryFeedIndex,
    isLoadingPhotos,
    revision,
    apiTag,
    specifications,
    precisionTag,
    subGroups,
    canEdit,
    canDelete,
    shouldOpenEdit,
    isDeleting,
    isDeleted,
    infoMessage,
  ];
}

class PhotoSpecDisplay extends Equatable {
  const PhotoSpecDisplay({
    required this.line,
    this.label,
    this.fineWeightLine,
  });

  final String line;
  final String? label;
  /// e.g. `Fine weight : 23.5g` when purity + wastage + net are known.
  final String? fineWeightLine;

  @override
  List<Object?> get props => [line, label, fineWeightLine];
}
