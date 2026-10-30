import 'package:equatable/equatable.dart';
import 'package:project_c/models/catalog/catalog_stock_status.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/models/catalog/quick_import_api_models.dart';

export 'package:project_c/models/catalog/catalog_stock_status.dart';

/// First-class product shape from jewel products API.
enum CatalogProductKind { single, subCollection }

CatalogProductKind? catalogProductKindFromString(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'single':
      return CatalogProductKind.single;
    case 'sub_collection':
    case 'subcollection':
      return CatalogProductKind.subCollection;
    default:
      return null;
  }
}

/// One product DTO from batch create / store products / product detail.
class CatalogProduct extends Equatable {
  const CatalogProduct({
    required this.id,
    required this.storeId,
    this.collectionId = '',
    this.kind,
    this.title = '',
    this.metal = '',
    this.purity = '',
    this.grossMin,
    this.grossMax,
    this.stoneWeight,
    this.netMin,
    this.netMax,
    this.wastagePct,
    this.sizeMode = '',
    this.sizeValue,
    this.sizeUnit,
    this.category = '',
    this.stockStatus,
    this.mtoDays,
    this.isLocked = false,
    this.hasPrecisionTag = false,
    this.precisionTag = '',
    this.primaryImageUrl = '',
    this.primaryImageThumbnailUrl = '',
    this.primaryImageDetailUrl = '',
    this.primaryImageId = '',
    this.primaryImageThumbhash = '',
    this.imageUrls = const [],
    this.imageThumbnailUrls = const [],
    this.imageDetailUrls = const [],
    this.imageIds = const [],
    this.imageThumbhashes = const [],
    this.tags = const [],
    this.likeCount,
    this.viewCount,
    this.liked,
    this.wishlisted,
    this.isNew = false,
    this.createdAt,
    this.importFlags = const ProductImportFlags(),
  });

  final String id;
  final String storeId;
  final String collectionId;
  final CatalogProductKind? kind;
  final String title;
  final String metal;
  final String purity;
  final double? grossMin;
  final double? grossMax;
  final double? stoneWeight;
  final double? netMin;
  final double? netMax;
  final double? wastagePct;
  final String sizeMode;
  final double? sizeValue;
  final String? sizeUnit;
  final String category;
  final CatalogStockStatus? stockStatus;
  final int? mtoDays;
  final bool isLocked;
  final bool hasPrecisionTag;
  final String precisionTag;
  final String primaryImageUrl;
  final String primaryImageThumbnailUrl;
  final String primaryImageDetailUrl;
  final String primaryImageId;
  final String primaryImageThumbhash;
  final List<String> imageUrls;
  final List<String> imageThumbnailUrls;
  final List<String> imageDetailUrls;
  final List<String> imageIds;
  final List<String> imageThumbhashes;
  final List<String> tags;
  final int? likeCount;
  final int? viewCount;

  /// Viewer like state from product detail / feed when present.
  final bool? liked;

  /// Viewer private wishlist state when present on product GET.
  final bool? wishlisted;
  final bool isNew;
  final DateTime? createdAt;
  final ProductImportFlags importFlags;

  /// Flat jewel fields for [ProductSpec.fromCatalogProductMap].
  Map<String, dynamic> toFlatSpecMap() => <String, dynamic>{
    'metal': metal,
    'purity': purity,
    'gross_min': grossMin,
    'gross_max': grossMax,
    'stone_weight': stoneWeight,
    'wastage_pct': wastagePct,
    'size_mode': sizeMode,
    'size_value': sizeValue,
    'size_unit': sizeUnit,
    'category': category,
  };

  factory CatalogProduct.fromJson(Map<String, dynamic> json) {
    final primary = json['primaryImage'];
    final primaryMap =
        primary is Map<String, dynamic>
            ? primary
            : primary is Map
            ? Map<String, dynamic>.from(primary)
            : const <String, dynamic>{};
    final rawImages = json['images'] ?? json['photos'] ?? json['gallery'];
    final imageUrls = <String>[];
    final imageThumbnailUrls = <String>[];
    final imageDetailUrls = <String>[];
    final imageIds = <String>[];
    final imageThumbhashes = <String>[];
    if (rawImages is List) {
      for (final entry in rawImages) {
        if (entry is Map) {
          final map = Map<String, dynamic>.from(entry);
          final url =
              (map['url'] as String?)?.trim() ??
              (map['publicUrl'] as String?)?.trim() ??
              '';
          final thumb = (map['thumbnailUrl'] as String?)?.trim() ?? '';
          final detail = (map['detailUrl'] as String?)?.trim() ?? '';
          final id =
              (map['imageId'] as String?)?.trim() ??
              (map['id'] as String?)?.trim() ??
              '';
          final hash =
              (map['thumbhash'] as String?)?.trim() ??
              (map['thumbHash'] as String?)?.trim() ??
              '';
          if (url.isNotEmpty || thumb.isNotEmpty || detail.isNotEmpty) {
            imageUrls.add(url.isNotEmpty ? url : (detail.isNotEmpty ? detail : thumb));
            imageThumbnailUrls.add(thumb);
            imageDetailUrls.add(detail);
            imageIds.add(id);
            imageThumbhashes.add(hash);
          }
        } else if (entry is String && entry.trim().isNotEmpty) {
          imageUrls.add(entry.trim());
          imageThumbnailUrls.add('');
          imageDetailUrls.add('');
          imageIds.add('');
          imageThumbhashes.add('');
        }
      }
    }
    final primaryUrl =
        (primaryMap['url'] as String?)?.trim() ??
        (imageUrls.isNotEmpty ? imageUrls.first : '');
    final primaryThumb =
        (primaryMap['thumbnailUrl'] as String?)?.trim() ??
        (json['thumbnailUrl'] as String?)?.trim() ??
        (imageThumbnailUrls.isNotEmpty ? imageThumbnailUrls.first : '');
    final primaryDetail =
        (primaryMap['detailUrl'] as String?)?.trim() ??
        (json['detailUrl'] as String?)?.trim() ??
        (imageDetailUrls.isNotEmpty ? imageDetailUrls.first : '');
    final primaryId =
        (primaryMap['imageId'] as String?)?.trim() ??
        (imageIds.isNotEmpty ? imageIds.first : '');
    final primaryHash =
        (primaryMap['thumbhash'] as String?)?.trim() ??
        (primaryMap['thumbHash'] as String?)?.trim() ??
        (imageThumbhashes.isNotEmpty ? imageThumbhashes.first : '');
    if (primaryUrl.isNotEmpty &&
        (imageUrls.isEmpty || imageUrls.first != primaryUrl)) {
      imageUrls.insert(0, primaryUrl);
      imageThumbnailUrls.insert(0, primaryThumb);
      imageDetailUrls.insert(0, primaryDetail);
      imageIds.insert(0, primaryId);
      imageThumbhashes.insert(0, primaryHash);
    }
    if (primaryId.isNotEmpty &&
        imageIds.isNotEmpty &&
        imageIds.first != primaryId) {
      imageIds[0] = primaryId;
    }
    if (primaryHash.isNotEmpty &&
        imageThumbhashes.isNotEmpty &&
        imageThumbhashes.first.isEmpty) {
      imageThumbhashes[0] = primaryHash;
    }
    if (primaryThumb.isNotEmpty &&
        imageThumbnailUrls.isNotEmpty &&
        imageThumbnailUrls.first.isEmpty) {
      imageThumbnailUrls[0] = primaryThumb;
    }
    if (primaryDetail.isNotEmpty &&
        imageDetailUrls.isNotEmpty &&
        imageDetailUrls.first.isEmpty) {
      imageDetailUrls[0] = primaryDetail;
    }

    final rawTags = json['tags'];
    final parsedKind = catalogProductKindFromString(json['kind'] as String?);
    final inferredKind =
        parsedKind ??
        (imageUrls.length >= 2
            ? CatalogProductKind.subCollection
            : (imageUrls.length == 1 ? CatalogProductKind.single : null));

    return CatalogProduct(
      id:
          (json['_id'] as String?)?.trim() ??
          (json['id'] as String?)?.trim() ??
          '',
      storeId: (json['storeId'] as String?)?.trim() ?? '',
      collectionId: (json['collectionId'] as String?)?.trim() ?? '',
      kind: inferredKind,
      title: (json['title'] as String?)?.trim() ?? '',
      metal: (json['metal'] as String?)?.trim() ?? '',
      purity: (json['purity'] as String?)?.trim() ?? '',
      grossMin: (json['gross_min'] as num?)?.toDouble(),
      grossMax: (json['gross_max'] as num?)?.toDouble(),
      stoneWeight: (json['stone_weight'] as num?)?.toDouble(),
      netMin: (json['net_min'] as num?)?.toDouble(),
      netMax: (json['net_max'] as num?)?.toDouble(),
      wastagePct: (json['wastage_pct'] as num?)?.toDouble(),
      sizeMode: (json['size_mode'] as String?)?.trim() ?? '',
      sizeValue: (json['size_value'] as num?)?.toDouble(),
      sizeUnit: (json['size_unit'] as String?)?.trim(),
      category: (json['category'] as String?)?.trim() ?? '',
      stockStatus: CatalogStockStatus.tryParse(
        json['stock_status'] ?? json['stockStatus'],
      ),
      mtoDays: (json['mto_days'] as num?)?.toInt() ??
          (json['mtoDays'] as num?)?.toInt(),
      isLocked: json['is_locked'] == true || json['isLocked'] == true,
      hasPrecisionTag: json['hasPrecisionTag'] == true,
      precisionTag: (json['precisionTag'] as String?)?.trim() ?? '',
      primaryImageUrl: primaryUrl,
      primaryImageThumbnailUrl: primaryThumb,
      primaryImageDetailUrl: primaryDetail,
      primaryImageId: primaryId,
      primaryImageThumbhash: primaryHash,
      imageUrls: imageUrls,
      imageThumbnailUrls: imageThumbnailUrls,
      imageDetailUrls: imageDetailUrls,
      imageIds: imageIds,
      imageThumbhashes: imageThumbhashes,
      tags:
          rawTags is List
              ? rawTags.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
              : const [],
      likeCount: (json['likeCount'] as num?)?.toInt(),
      viewCount: (json['viewCount'] as num?)?.toInt(),
      liked: json['liked'] as bool?,
      wishlisted:
          json['wishlisted'] as bool? ?? json['isWishlisted'] as bool?,
      isNew: json['isNew'] == true,
      createdAt: parseCatalogDateTime(
        json['createdAt'] ?? json['created_at'],
      ),
      importFlags: ProductImportFlags.fromJson(json),
    );
  }

  @override
  List<Object?> get props => [
    id,
    storeId,
    collectionId,
    kind,
    title,
    metal,
    purity,
    stockStatus,
    mtoDays,
    isLocked,
    precisionTag,
    primaryImageUrl,
    primaryImageThumbnailUrl,
    primaryImageDetailUrl,
    imageUrls,
    imageThumbnailUrls,
    imageDetailUrls,
    tags,
    likeCount,
    viewCount,
    liked,
    wishlisted,
    isNew,
    createdAt,
    importFlags,
  ];
}

class CatalogProductBatchCollection extends Equatable {
  const CatalogProductBatchCollection({
    required this.id,
    required this.name,
    this.productCount = 0,
  });

  final String id;
  final String name;
  final int productCount;

  factory CatalogProductBatchCollection.fromJson(Map<String, dynamic> json) {
    return CatalogProductBatchCollection(
      id: (json['id'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      productCount: (json['productCount'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, name, productCount];
}

/// `POST /stores/:storeId/products/batch` response.
class CatalogProductBatchResult extends Equatable {
  const CatalogProductBatchResult({
    required this.products,
    this.success = true,
    this.count = 0,
    this.batchId = '',
    this.collection,
  });

  final bool success;
  final int count;
  final String batchId;
  final CatalogProductBatchCollection? collection;
  final List<CatalogProduct> products;

  factory CatalogProductBatchResult.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['products'];
    final rawCollection = json['collection'];
    return CatalogProductBatchResult(
      success: json['success'] != false,
      count: (json['count'] as num?)?.toInt() ?? 0,
      batchId: (json['batchId'] as String?)?.trim() ?? '',
      collection:
          rawCollection is Map<String, dynamic>
              ? CatalogProductBatchCollection.fromJson(rawCollection)
              : rawCollection is Map
              ? CatalogProductBatchCollection.fromJson(
                Map<String, dynamic>.from(rawCollection),
              )
              : null,
      products:
          rawProducts is List
              ? rawProducts
                  .whereType<Map>()
                  .map(
                    (e) => CatalogProduct.fromJson(Map<String, dynamic>.from(e)),
                  )
                  .toList()
              : const [],
    );
  }

  @override
  List<Object?> get props => [success, count, batchId, collection, products];
}
