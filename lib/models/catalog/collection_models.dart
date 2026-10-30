import 'package:equatable/equatable.dart';
import 'package:project_c/models/bulk_upload.dart';
import 'package:project_c/models/catalog/catalog_stock_status.dart';
import 'package:project_c/models/catalog/collection_specifications.dart';
import 'package:project_c/models/catalog/quick_import_api_models.dart';

/// Parses collection/list API timestamps (`createdAt` ISO string or epoch ms/s).
DateTime? parseCatalogDateTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is int) {
    // Seconds vs milliseconds heuristic.
    if (raw > 0 && raw < 100000000000) {
      return DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true)
          .toLocal();
    }
    return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true).toLocal();
  }
  if (raw is num) return parseCatalogDateTime(raw.toInt());
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  final asInt = int.tryParse(text);
  if (asInt != null) return parseCatalogDateTime(asInt);
  return DateTime.tryParse(text)?.toLocal();
}

/// Creation time encoded in a MongoDB ObjectId (first 4 bytes = Unix seconds).
/// Used when list/detail omit `createdAt` (current catalog collections API).
DateTime? dateFromMongoObjectId(String? id) {
  final value = id?.trim() ?? '';
  if (value.length < 8) return null;
  final seconds = int.tryParse(value.substring(0, 8), radix: 16);
  if (seconds == null || seconds <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(
    seconds * 1000,
    isUtc: true,
  ).toLocal();
}

/// Prefer API `createdAt`, then optional cover/photo time, then ObjectId.
DateTime? resolveCollectionCreatedAt({
  DateTime? createdAt,
  DateTime? fallbackCreatedAt,
  String? id,
}) {
  return createdAt ?? fallbackCreatedAt ?? dateFromMongoObjectId(id);
}

/// Telegram-style day bucket for store profile Single / Gallery (and Group
/// sectioning when used): Today · Yesterday · October 5 · October 5, 2025.
String formatCatalogDayBucket(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(local.year, local.month, local.day);
  final diff = today.difference(target).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final month = months[target.month - 1];
  if (target.year == today.year) return '$month ${target.day}';
  return '$month ${target.day}, ${target.year}';
}

class CatalogPhoto extends Equatable {
  const CatalogPhoto({
    required this.width,
    required this.height,
    required this.url,
    this.thumbnailUrl = '',
    this.detailUrl = '',
    this.id,
    this.quality,
    this.thumbhash,
    this.liked,
    this.likeCount,
    this.viewCount,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final int width;
  final int height;

  /// Master / original CDN URL (pinch-zoom).
  final String url;

  /// Cloudflare ~320×320 grid variant when provided by BE.
  final String thumbnailUrl;

  /// Cloudflare ~1080px detail variant when provided by BE.
  final String detailUrl;
  final String? quality;
  final String? thumbhash;

  /// Present when collection detail includes viewer like state.
  final bool? liked;
  final int? likeCount;

  /// Denormalized photo view count from collection detail / analytics.
  final int? viewCount;

  /// Upload time when the API includes it (IST `+05:30` or UTC ISO).
  final DateTime? createdAt;

  /// Last edit time — present for store members only; omitted for public.
  final DateTime? updatedAt;

  factory CatalogPhoto.fromJson(Map<String, dynamic> json) {
    return CatalogPhoto(
      id: json['id'] as String?,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      url: json['url'] as String? ?? '',
      thumbnailUrl: (json['thumbnailUrl'] as String?)?.trim() ?? '',
      detailUrl: (json['detailUrl'] as String?)?.trim() ?? '',
      quality: json['quality'] as String?,
      thumbhash: json['thumbhash'] as String? ?? json['thumbHash'] as String?,
      liked: json['liked'] as bool?,
      likeCount: (json['likeCount'] as num?)?.toInt(),
      viewCount: (json['viewCount'] as num?)?.toInt(),
      createdAt: parseCatalogDateTime(
        json['createdAt'] ?? json['created_at'] ?? json['uploadedAt'],
      ),
      updatedAt: parseCatalogDateTime(
        json['updatedAt'] ?? json['updated_at'],
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'width': width,
    'height': height,
    'url': url,
    if (thumbnailUrl.trim().isNotEmpty) 'thumbnailUrl': thumbnailUrl,
    if (detailUrl.trim().isNotEmpty) 'detailUrl': detailUrl,
    'quality': quality,
    'thumbhash': thumbhash,
    if (liked != null) 'liked': liked,
    if (likeCount != null) 'likeCount': likeCount,
    if (viewCount != null) 'viewCount': viewCount,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };

  @override
  List<Object?> get props => [
    id,
    width,
    height,
    url,
    thumbnailUrl,
    detailUrl,
    quality,
    thumbhash,
    liked,
    likeCount,
    viewCount,
    createdAt,
    updatedAt,
  ];
}

/// Builds a [CatalogPhoto] from an embedded product DTO on collection detail.
CatalogPhoto _photoFromEmbeddedProduct(Map<String, dynamic> json) {
  final primary = json['primaryImage'];
  final primaryMap =
      primary is Map<String, dynamic>
          ? primary
          : primary is Map
          ? Map<String, dynamic>.from(primary)
          : const <String, dynamic>{};
  final images = json['images'];
  Map<String, dynamic> imageMap = primaryMap;
  if (imageMap.isEmpty && images is List && images.isNotEmpty) {
    final first = images.first;
    if (first is Map) imageMap = Map<String, dynamic>.from(first);
  }
  final url =
      (imageMap['url'] as String?)?.trim() ??
      (json['url'] as String?)?.trim() ??
      '';
  final thumbnailUrl =
      (imageMap['thumbnailUrl'] as String?)?.trim() ??
      (json['thumbnailUrl'] as String?)?.trim() ??
      '';
  final detailUrl =
      (imageMap['detailUrl'] as String?)?.trim() ??
      (json['detailUrl'] as String?)?.trim() ??
      '';
  // Prefer product id so open/details can call GET /products/:id.
  final productId =
      (json['_id'] as String?)?.trim() ?? (json['id'] as String?)?.trim() ?? '';
  final imageId =
      (imageMap['imageId'] as String?)?.trim() ??
      (imageMap['id'] as String?)?.trim() ??
      '';
  return CatalogPhoto(
    id: productId.isNotEmpty ? productId : imageId,
    width: (imageMap['width'] as num?)?.toInt() ?? 0,
    height: (imageMap['height'] as num?)?.toInt() ?? 0,
    url: url.isNotEmpty ? url : thumbnailUrl,
    thumbnailUrl: thumbnailUrl,
    detailUrl: detailUrl,
    quality: imageMap['quality'] as String?,
    thumbhash:
        (imageMap['thumbhash'] as String?) ??
        (imageMap['thumbHash'] as String?),
    liked: json['liked'] as bool?,
    likeCount: (json['likeCount'] as num?)?.toInt(),
    viewCount: (json['viewCount'] as num?)?.toInt(),
    createdAt: parseCatalogDateTime(
      json['createdAt'] ?? json['created_at'],
    ),
  );
}

class CollectionPermissions extends Equatable {
  const CollectionPermissions({required this.edit, required this.delete});

  final bool edit;
  final bool delete;

  factory CollectionPermissions.fromJson(Map<String, dynamic> json) {
    return CollectionPermissions(
      edit: json['edit'] as bool? ?? false,
      delete: json['delete'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [edit, delete];
}

class FailedPhoto extends Equatable {
  const FailedPhoto({
    required this.fileName,
    required this.code,
    required this.message,
  });

  final String fileName;
  final String code;
  final String message;

  factory FailedPhoto.fromJson(Map<String, dynamic> json) {
    return FailedPhoto(
      fileName: json['fileName'] as String? ?? '',
      code: json['code'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [fileName, code, message];
}

class CollectionSummary extends Equatable {
  const CollectionSummary({
    required this.id,
    required this.name,
    required this.revision,
    required this.photoCount,
    required this.cover,
    this.tag = '',
    this.description = '',
    this.kind,
    this.permissions,
    this.mainGroupPhotoCount,
    this.subGroupCount,
    this.precisionTag = '',
    this.usePrecisionTag = false,
    this.specifications,
    this.mainGroupCover,
    this.viewCount,
    this.likeCount,
    this.isLocked = false,
    this.stockStatus,
    this.mtoDays,
    this.importFlags = const ProductImportFlags(),
    this.liveProductCount,
    this.pendingProductCount,
    this.declinedProductCount,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String tag;
  final String description;
  final int revision;
  final int photoCount;
  final CatalogPhoto cover;
  final String? kind;
  final CollectionPermissions? permissions;
  final int? mainGroupPhotoCount;
  final int? subGroupCount;
  final String precisionTag;
  final bool usePrecisionTag;
  final CollectionSpecifications? specifications;
  final CatalogPhoto? mainGroupCover;

  /// Collection-level view count when the list/detail API includes it.
  final int? viewCount;

  /// Aggregate like / wishlist count when the list API includes it.
  final int? likeCount;

  /// Optional jewel-flow lock/stock when list APIs surface product fields.
  final bool isLocked;
  final CatalogStockStatus? stockStatus;
  final int? mtoDays;

  /// Viewer-relative import enrichment when list APIs include it.
  final ProductImportFlags importFlags;

  /// Owner/visitor breakdown from collection-counter sync (optional).
  final int? liveProductCount;
  final int? pendingProductCount;
  final int? declinedProductCount;

  /// Upload / create / import time (`createdAt`, IST or UTC ISO).
  final DateTime? createdAt;

  /// Last edit — members only; omitted for public viewers.
  final DateTime? updatedAt;

  factory CollectionSummary.fromJson(Map<String, dynamic> json) {
    final perms = json['permissions'];
    final rawSpecs = json['specifications'];
    final rawMainCover = json['mainGroupCover'];
    // New storefront shape uses `coverImage` + `productCount`.
    final rawCover =
        json['coverImage'] ?? json['cover'] ?? const <String, dynamic>{};
    final coverMap =
        rawCover is Map<String, dynamic>
            ? rawCover
            : rawCover is Map
            ? Map<String, dynamic>.from(rawCover)
            : const <String, dynamic>{};
    final productCount =
        (json['productCount'] as num?)?.toInt() ??
        (json['photoCount'] as num?)?.toInt() ??
        0;
    return CollectionSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
      description: json['description'] as String? ?? '',
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      photoCount: productCount,
      cover: CatalogPhoto.fromJson(coverMap),
      kind: json['kind'] as String?,
      permissions:
          perms is Map<String, dynamic>
              ? CollectionPermissions.fromJson(perms)
              : null,
      mainGroupPhotoCount:
          (json['singlePhotoCount'] as num?)?.toInt() ??
          (json['mainGroupPhotoCount'] as num?)?.toInt(),
      subGroupCount:
          (json['subCollectionCount'] as num?)?.toInt() ??
          (json['subGroupCount'] as num?)?.toInt(),
      precisionTag: json['precisionTag'] as String? ?? '',
      usePrecisionTag: json['usePrecisionTag'] == true,
      specifications:
          rawSpecs is Map<String, dynamic>
              ? CollectionSpecifications.fromJson(rawSpecs)
              : null,
      mainGroupCover:
          rawMainCover is Map<String, dynamic>
              ? CatalogPhoto.fromJson(rawMainCover)
              : null,
      viewCount: (json['viewCount'] as num?)?.toInt(),
      likeCount: (json['likeCount'] as num?)?.toInt(),
      isLocked: json['is_locked'] == true || json['isLocked'] == true,
      stockStatus: CatalogStockStatus.tryParse(
        json['stock_status'] ?? json['stockStatus'],
      ),
      mtoDays: (json['mto_days'] as num?)?.toInt() ??
          (json['mtoDays'] as num?)?.toInt(),
      importFlags: ProductImportFlags.fromJson(json),
      liveProductCount: (json['liveProductCount'] as num?)?.toInt(),
      pendingProductCount: (json['pendingProductCount'] as num?)?.toInt(),
      declinedProductCount: (json['declinedProductCount'] as num?)?.toInt(),
      createdAt: parseCatalogDateTime(
        json['createdAt'] ?? json['created_at'] ?? json['uploadedAt'],
      ),
      updatedAt: parseCatalogDateTime(
        json['updatedAt'] ?? json['updated_at'],
      ),
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    tag,
    description,
    revision,
    photoCount,
    cover,
    kind,
    permissions,
    mainGroupPhotoCount,
    subGroupCount,
    precisionTag,
    usePrecisionTag,
    specifications,
    mainGroupCover,
    viewCount,
    likeCount,
    isLocked,
    stockStatus,
    mtoDays,
    importFlags,
    liveProductCount,
    pendingProductCount,
    declinedProductCount,
    createdAt,
    updatedAt,
  ];
}

class CollectionDetail extends Equatable {
  const CollectionDetail({
    required this.id,
    required this.name,
    required this.revision,
    required this.photoCount,
    required this.photos,
    this.tag = '',
    this.description = '',
    this.kind,
    this.permissions,
    this.specifications,
    this.usePrecisionTag = false,
    this.precisionTag = '',
    this.mainGroupPhotoCount,
    this.subGroupCount,
    this.mainGroupPhotos = const [],
    this.subGroups = const [],
    this.productSpecsById = const {},
    this.defaultsSpec,
    this.viewCount,
    this.likeCount,
    this.isLocked = false,
    this.stockStatus,
    this.mtoDays,
    this.liveProductCount,
    this.pendingProductCount,
    this.declinedProductCount,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String tag;
  final String description;
  final int revision;
  final int photoCount;
  final List<CatalogPhoto> photos;
  final String? kind;
  final CollectionPermissions? permissions;
  final CollectionSpecifications? specifications;
  final bool usePrecisionTag;
  final String precisionTag;
  final int? mainGroupPhotoCount;
  final int? subGroupCount;
  final List<CatalogPhoto> mainGroupPhotos;
  final List<CollectionSubGroup> subGroups;

  /// Specs keyed by product / photo id when detail embeds `products`/`items`.
  final Map<String, ProductSpec> productSpecsById;

  /// Collection-level `defaults` (metal / purity / wastage) when present.
  final ProductSpec? defaultsSpec;

  /// Whole-collection view count from detail API.
  final int? viewCount;

  /// Aggregate like / wishlist count when the detail API includes it.
  final int? likeCount;

  final bool isLocked;
  final CatalogStockStatus? stockStatus;
  final int? mtoDays;

  /// Owner/visitor breakdown from collection-counter sync (optional).
  final int? liveProductCount;
  final int? pendingProductCount;
  final int? declinedProductCount;

  /// Upload / create / import time when the detail API includes `createdAt`.
  final DateTime? createdAt;

  /// Last edit — members only; omitted for public viewers.
  final DateTime? updatedAt;

  factory CollectionDetail.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photos'];
    final rawMainPhotos = json['mainGroupPhotos'];
    final rawSubGroups = json['subGroups'];
    final rawProducts = json['products'] ?? json['items'];
    final perms = json['permissions'];
    final rawSpecs = json['specifications'];
    var photos =
        rawPhotos is List
            ? rawPhotos
                .whereType<Map>()
                .map(
                  (e) => CatalogPhoto.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
            : <CatalogPhoto>[];
    // Jewel storefront: collection detail may embed products (with flat specs).
    final productSpecsById = <String, ProductSpec>{};
    // Collection-level is_locked / stock_status can lag behind products[] after
    // per-product PATCH — derive listing chrome from embedded products too.
    var productsLocked = false;
    CatalogStockStatus? productsStock;
    int? productsMtoDays;
    if (rawProducts is List) {
      for (final entry in rawProducts) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);
        final id =
            (map['_id'] as String?)?.trim() ??
            (map['id'] as String?)?.trim() ??
            '';
        if (id.isEmpty) continue;
        final spec = ProductSpec.fromCatalogProductMap(map);
        productSpecsById[id] = spec;
        // Also key by primary imageId — some surfaces use image ids as photo ids.
        final primary = map['primaryImage'];
        final primaryMap =
            primary is Map
                ? Map<String, dynamic>.from(primary)
                : const <String, dynamic>{};
        final imageId =
            (primaryMap['imageId'] as String?)?.trim() ??
            (primaryMap['id'] as String?)?.trim() ??
            '';
        if (imageId.isNotEmpty) productSpecsById[imageId] = spec;
        if (map['is_locked'] == true || map['isLocked'] == true) {
          productsLocked = true;
        }
        final stock = CatalogStockStatus.tryParse(
          map['stock_status'] ?? map['stockStatus'],
        );
        if (stock != null && productsStock == null) {
          productsStock = stock;
        }
        final mto =
            (map['mto_days'] as num?)?.toInt() ??
            (map['mtoDays'] as num?)?.toInt();
        if (mto != null && productsMtoDays == null) {
          productsMtoDays = mto;
        }
      }
      if (photos.isEmpty) {
        photos = [
          for (final entry in rawProducts)
            if (entry is Map)
              _photoFromEmbeddedProduct(Map<String, dynamic>.from(entry)),
        ].where((p) => p.url.trim().isNotEmpty).toList();
      }
    }
    final rawDefaults = json['defaults'];
    final defaultsSpec =
        rawDefaults is Map
            ? ProductSpec.fromCatalogProductMap(
              Map<String, dynamic>.from(rawDefaults),
            )
            : null;
    final productCount =
        (json['productCount'] as num?)?.toInt() ??
        (json['photoCount'] as num?)?.toInt() ??
        photos.length;
    final collectionLocked =
        json['is_locked'] == true || json['isLocked'] == true;
    final collectionStock = CatalogStockStatus.tryParse(
      json['stock_status'] ?? json['stockStatus'],
    );
    final collectionMto =
        (json['mto_days'] as num?)?.toInt() ??
        (json['mtoDays'] as num?)?.toInt();
    return CollectionDetail(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
      description: json['description'] as String? ?? '',
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      photoCount: productCount,
      photos: photos,
      kind: json['kind'] as String?,
      permissions:
          perms is Map<String, dynamic>
              ? CollectionPermissions.fromJson(perms)
              : null,
      specifications:
          rawSpecs is Map<String, dynamic>
              ? CollectionSpecifications.fromJson(rawSpecs)
              : null,
      usePrecisionTag: json['usePrecisionTag'] == true,
      precisionTag: json['precisionTag'] as String? ?? '',
      mainGroupPhotoCount:
          (json['singlePhotoCount'] as num?)?.toInt() ??
          (json['mainGroupPhotoCount'] as num?)?.toInt(),
      subGroupCount:
          (json['subCollectionCount'] as num?)?.toInt() ??
          (json['subGroupCount'] as num?)?.toInt(),
      mainGroupPhotos:
          rawMainPhotos is List
              ? rawMainPhotos
                  .whereType<Map>()
                  .map(
                    (e) => CatalogPhoto.fromJson(Map<String, dynamic>.from(e)),
                  )
                  .toList()
              : const [],
      subGroups:
          rawSubGroups is List
              ? rawSubGroups
                  .whereType<Map>()
                  .map(
                    (e) =>
                        CollectionSubGroup.fromJson(Map<String, dynamic>.from(e)),
                  )
                  .toList()
              : const [],
      productSpecsById: productSpecsById,
      defaultsSpec: defaultsSpec,
      viewCount: (json['viewCount'] as num?)?.toInt(),
      likeCount: (json['likeCount'] as num?)?.toInt(),
      isLocked: collectionLocked || productsLocked,
      // Prefer product-level stock when present (PATCH updates products first).
      stockStatus: productsStock ?? collectionStock,
      mtoDays: productsMtoDays ?? collectionMto,
      liveProductCount: (json['liveProductCount'] as num?)?.toInt(),
      pendingProductCount: (json['pendingProductCount'] as num?)?.toInt(),
      declinedProductCount: (json['declinedProductCount'] as num?)?.toInt(),
      createdAt: parseCatalogDateTime(
        json['createdAt'] ?? json['created_at'] ?? json['uploadedAt'],
      ),
      updatedAt: parseCatalogDateTime(
        json['updatedAt'] ?? json['updated_at'],
      ),
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    tag,
    description,
    revision,
    photoCount,
    photos,
    kind,
    permissions,
    specifications,
    usePrecisionTag,
    precisionTag,
    mainGroupPhotoCount,
    subGroupCount,
    mainGroupPhotos,
    subGroups,
    productSpecsById,
    defaultsSpec,
    viewCount,
    likeCount,
    isLocked,
    stockStatus,
    mtoDays,
    liveProductCount,
    pendingProductCount,
    declinedProductCount,
    createdAt,
    updatedAt,
  ];
}

/// Create (201) response — may include partial [failedPhotos].
class CollectionCreateResult extends Equatable {
  const CollectionCreateResult({
    required this.id,
    required this.name,
    required this.tag,
    required this.description,
    required this.revision,
    required this.photoCount,
    this.failedPhotos = const [],
    this.photos = const [],
    this.newCollectionId,
  });

  final String id;
  final String name;
  final String tag;
  final String description;
  final int revision;
  final int photoCount;
  final List<FailedPhoto> failedPhotos;
  final List<CatalogPhoto> photos;
  final String? newCollectionId;

  bool get hasPartialFailures => failedPhotos.isNotEmpty;

  factory CollectionCreateResult.fromJson(Map<String, dynamic> json) {
    final rawFailed = json['failedPhotos'];
    final rawPhotos = json['photos'];
    return CollectionCreateResult(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
      description: json['description'] as String? ?? '',
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      photoCount: (json['photoCount'] as num?)?.toInt() ?? 0,
      failedPhotos:
          rawFailed is List
              ? rawFailed
                  .whereType<Map<String, dynamic>>()
                  .map(FailedPhoto.fromJson)
                  .toList()
              : const [],
      photos:
          rawPhotos is List
              ? rawPhotos
                  .whereType<Map<String, dynamic>>()
                  .map(CatalogPhoto.fromJson)
                  .toList()
              : const [],
      newCollectionId: json['newCollectionId'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    tag,
    description,
    revision,
    photoCount,
    failedPhotos,
    photos,
    newCollectionId,
  ];
}

/// PATCH metadata response (no photos / failedPhotos).
class CollectionMutation extends Equatable {
  const CollectionMutation({
    required this.id,
    required this.name,
    required this.tag,
    required this.description,
    required this.revision,
    this.precisionTag,
    this.usePrecisionTag,
    this.specifications,
  });

  final String id;
  final String name;
  final String tag;
  final String description;
  final int revision;
  final String? precisionTag;
  final bool? usePrecisionTag;
  final CollectionSpecifications? specifications;

  factory CollectionMutation.fromJson(Map<String, dynamic> json) {
    final rawSpecs = json['specifications'];
    return CollectionMutation(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
      description: json['description'] as String? ?? '',
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      precisionTag: json['precisionTag'] as String?,
      usePrecisionTag:
          json.containsKey('usePrecisionTag')
              ? json['usePrecisionTag'] == true
              : null,
      specifications:
          rawSpecs is Map<String, dynamic>
              ? CollectionSpecifications.fromJson(rawSpecs)
              : null,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    tag,
    description,
    revision,
    precisionTag,
    usePrecisionTag,
    specifications,
  ];
}
