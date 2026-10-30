import 'package:equatable/equatable.dart';
import 'package:project_c/helper/catalog_responsive_image.dart';
import 'package:project_c/models/catalog/catalog_stock_status.dart';
import 'package:project_c/models/catalog/quick_import_api_models.dart';

class StoreProduct extends Equatable {
  StoreProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.tags,
    required this.imagePaths,
    this.photoAssetIds = const [],
    this.imageThumbhashes = const [],
    this.imageThumbnailUrls = const [],
    this.imageDetailUrls = const [],
    this.imageQualities = const [],
    this.imageIsLocked = const [],
    this.imageStockStatuses = const [],
    this.imageImportStatuses = const [],
    this.canEdit = false,
    this.canDelete = false,
    this.toneIndex = 0,
    this.viewCount,
    this.likeCount,
    this.wishlistCount,
    this.isLocked = false,
    this.stockStatus,
    this.mtoDays,
    this.precisionTag = '',
    this.collectionId = '',
    this.importFlags = const ProductImportFlags(),
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  final String description;
  final List<String> tags;

  /// Master / original CDN URLs (pinch-zoom identity).
  final List<String> imagePaths;

  /// Parallel to [imagePaths] when the API returns member photo ids.
  /// Group collage cards store **CatalogProduct ids** (not img_* keys).
  final List<String> photoAssetIds;

  /// Parallel to [imagePaths] — per-cell lock on Group collage cards.
  /// Empty → fall back to [isLocked].
  final List<bool> imageIsLocked;

  /// Parallel to [imagePaths] — per-cell stock API values (`in`/`out`/`mto`).
  /// Empty entry or missing → fall back to [stockStatus].
  final List<String> imageStockStatuses;

  /// Parallel to [imagePaths] — per-cell `importStatus` on Group collage cards
  /// (`pending` / `live` / …). Empty → fall back to [importFlags.importStatus].
  final List<String> imageImportStatuses;

  /// Parallel to [imagePaths] — base64 ThumbHash placeholders when present.
  final List<String> imageThumbhashes;

  /// Parallel to [imagePaths] — Cloudflare grid variants (`thumbnailUrl`).
  final List<String> imageThumbnailUrls;

  /// Parallel to [imagePaths] — Cloudflare detail variants (`detailUrl`).
  final List<String> imageDetailUrls;

  /// Parallel to [imagePaths] — API `quality`: `standard` | `high` | `low`.
  final List<String> imageQualities;
  final bool canEdit;
  final bool canDelete;
  final int toneIndex;

  /// Collection-level view count when provided by list/detail APIs.
  final int? viewCount;

  /// Aggregate public like count (cover or sum of product likes).
  final int? likeCount;

  /// Viewer-private wishlist badge: how many pieces on this card the current
  /// user has bookmarked. Not a public social count (API has no wishlistCount).
  final int? wishlistCount;

  /// Product lock (`is_locked`) — visitors without access never see locked rows.
  final bool isLocked;

  /// Stock state when the products/feed API provides it.
  final CatalogStockStatus? stockStatus;

  /// Make-to-order lead time in days when [stockStatus] is mto.
  final int? mtoDays;

  /// Server-computed precision tag line when present.
  final String precisionTag;

  /// Parent collection id when this grid card is a product (not a collection).
  final String collectionId;

  /// Viewer-relative import enrichment from feed (quick-import-api.md).
  final ProductImportFlags importFlags;

  final DateTime createdAt;

  bool get isAlreadyImported => importFlags.isAlreadyImported;
  bool get isSourceDeleted => importFlags.isSourceDeleted;
  bool get importSelectionBlocked => importFlags.selectionBlocked;

  /// Card-level destination import waiting for approval.
  bool get isImportPending => importFlags.isImportPending;

  /// Card-level destination import declined by source (owner shelf only).
  bool get isImportDeclined => importFlags.isImportDeclined;

  String get meta {
    if (tags.isEmpty) return 'product';
    return tags.take(2).join(' · ');
  }

  bool get hasLocalImage => imagePaths.isNotEmpty;

  String? get primaryImagePath => imagePaths.isEmpty ? null : imagePaths.first;

  String? thumbhashAt(int index) {
    if (index < 0 || index >= imageThumbhashes.length) return null;
    final value = imageThumbhashes[index].trim();
    return value.isEmpty ? null : value;
  }

  String _parallelAt(List<String> list, int index) {
    if (index < 0 || index >= list.length) return '';
    return list[index].trim();
  }

  /// CDN URL for [role] at [index] (grid / detail / zoom) with safe fallbacks.
  String urlForRole(
    int index,
    CatalogImageRole role, {
    bool log = false,
  }) {
    if (index < 0 || index >= imagePaths.length) return '';
    return CatalogResponsiveImage.resolve(
      masterUrl: imagePaths[index],
      thumbnailUrl: _parallelAt(imageThumbnailUrls, index),
      detailUrl: _parallelAt(imageDetailUrls, index),
      role: role,
      log: log,
      context: 'product=$id#$index',
    );
  }

  /// Display URLs for every image at [role] (same length as [imagePaths]).
  List<String> urlsForRole(CatalogImageRole role, {bool log = false}) {
    return [
      for (var i = 0; i < imagePaths.length; i++)
        urlForRole(i, role, log: log && i == 0),
    ];
  }

  /// API photo quality at [index], or null when unknown.
  String? qualityAt(int index) {
    if (index < 0 || index >= imageQualities.length) return null;
    final value = imageQualities[index].trim().toLowerCase();
    return value.isEmpty ? null : value;
  }

  /// Deep pinch zoom is disabled for merchant WhatsApp-style low thumbs.
  bool allowsDeepZoomAt(int index) => qualityAt(index) != 'low';

  /// Product id to use for Quick Import / like for collage cell [index].
  /// Prefers [photoAssetIds]; falls back to [id] (single / card).
  String sourceProductIdAt(int index) {
    if (index >= 0 && index < photoAssetIds.length) {
      final cell = photoAssetIds[index].trim();
      if (cell.isNotEmpty) return cell;
    }
    return id.trim();
  }

  /// Per-cell lock when [imageIsLocked] is populated (Group collage).
  bool isLockedAt(int index) {
    if (index >= 0 && index < imageIsLocked.length) {
      return imageIsLocked[index];
    }
    return isLocked;
  }

  /// Per-cell stock when [imageStockStatuses] is populated (Group collage).
  CatalogStockStatus? stockStatusAt(int index) {
    if (index >= 0 && index < imageStockStatuses.length) {
      final raw = imageStockStatuses[index].trim();
      if (raw.isNotEmpty) return CatalogStockStatus.tryParse(raw);
    }
    return stockStatus;
  }

  /// Per-cell import pending when [imageImportStatuses] is populated.
  bool isImportPendingAt(int index) {
    if (index >= 0 && index < imageImportStatuses.length) {
      final raw = imageImportStatuses[index].trim().toLowerCase();
      if (raw.isNotEmpty) return raw == 'pending';
    }
    return isImportPending;
  }

  /// Per-cell import declined when [imageImportStatuses] is populated.
  bool isImportDeclinedAt(int index) {
    if (index >= 0 && index < imageImportStatuses.length) {
      final raw = imageImportStatuses[index].trim().toLowerCase();
      if (raw.isNotEmpty) return raw == 'declined';
    }
    return isImportDeclined;
  }

  DateTime get addedDate =>
      DateTime(createdAt.year, createdAt.month, createdAt.day);

  StoreProduct copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? tags,
    List<String>? imagePaths,
    List<String>? photoAssetIds,
    List<String>? imageThumbhashes,
    List<String>? imageThumbnailUrls,
    List<String>? imageDetailUrls,
    List<String>? imageQualities,
    List<bool>? imageIsLocked,
    List<String>? imageStockStatuses,
    List<String>? imageImportStatuses,
    bool? canEdit,
    bool? canDelete,
    int? toneIndex,
    int? viewCount,
    bool clearViewCount = false,
    int? likeCount,
    bool clearLikeCount = false,
    int? wishlistCount,
    bool clearWishlistCount = false,
    bool? isLocked,
    CatalogStockStatus? stockStatus,
    bool clearStockStatus = false,
    int? mtoDays,
    bool clearMtoDays = false,
    String? precisionTag,
    String? collectionId,
    ProductImportFlags? importFlags,
    DateTime? createdAt,
  }) {
    return StoreProduct(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      imagePaths: imagePaths ?? this.imagePaths,
      photoAssetIds: photoAssetIds ?? this.photoAssetIds,
      imageThumbhashes: imageThumbhashes ?? this.imageThumbhashes,
      imageThumbnailUrls: imageThumbnailUrls ?? this.imageThumbnailUrls,
      imageDetailUrls: imageDetailUrls ?? this.imageDetailUrls,
      imageQualities: imageQualities ?? this.imageQualities,
      imageIsLocked: imageIsLocked ?? this.imageIsLocked,
      imageStockStatuses: imageStockStatuses ?? this.imageStockStatuses,
      imageImportStatuses: imageImportStatuses ?? this.imageImportStatuses,
      canEdit: canEdit ?? this.canEdit,
      canDelete: canDelete ?? this.canDelete,
      toneIndex: toneIndex ?? this.toneIndex,
      viewCount: clearViewCount ? null : (viewCount ?? this.viewCount),
      likeCount: clearLikeCount ? null : (likeCount ?? this.likeCount),
      wishlistCount:
          clearWishlistCount
              ? null
              : (wishlistCount ?? this.wishlistCount),
      isLocked: isLocked ?? this.isLocked,
      stockStatus:
          clearStockStatus ? null : (stockStatus ?? this.stockStatus),
      mtoDays: clearMtoDays ? null : (mtoDays ?? this.mtoDays),
      precisionTag: precisionTag ?? this.precisionTag,
      collectionId: collectionId ?? this.collectionId,
      importFlags: importFlags ?? this.importFlags,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'tags': tags,
      'imagePaths': imagePaths,
      'photoAssetIds': photoAssetIds,
      'imageThumbhashes': imageThumbhashes,
      'imageThumbnailUrls': imageThumbnailUrls,
      'imageDetailUrls': imageDetailUrls,
      'imageQualities': imageQualities,
      'imageIsLocked': imageIsLocked,
      'imageStockStatuses': imageStockStatuses,
      'imageImportStatuses': imageImportStatuses,
      'canEdit': canEdit,
      'canDelete': canDelete,
      'toneIndex': toneIndex,
      if (viewCount != null) 'viewCount': viewCount,
      if (likeCount != null) 'likeCount': likeCount,
      if (wishlistCount != null) 'wishlistCount': wishlistCount,
      'isLocked': isLocked,
      if (stockStatus != null) 'stockStatus': stockStatus!.name,
      if (mtoDays != null) 'mtoDays': mtoDays,
      if (precisionTag.isNotEmpty) 'precisionTag': precisionTag,
      if (collectionId.isNotEmpty) 'collectionId': collectionId,
      if (importFlags.canImport != null) 'canImport': importFlags.canImport,
      if (importFlags.importRestrictionReason != null)
        'importRestrictionReason': importFlags.importRestrictionReason,
      'isAlreadyImported': importFlags.isAlreadyImported,
      'isSourceDeleted': importFlags.isSourceDeleted,
      if (importFlags.importStatus != null)
        'importStatus': importFlags.importStatus,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory StoreProduct.fromMap(Map<String, Object?> map) {
    final rawTags = map['tags'];
    final rawPaths = map['imagePaths'];
    final rawAssetIds = map['photoAssetIds'];
    final rawThumbhashes = map['imageThumbhashes'];
    final rawThumbs = map['imageThumbnailUrls'];
    final rawDetails = map['imageDetailUrls'];
    final rawQualities = map['imageQualities'];
    final rawImageLocked = map['imageIsLocked'];
    final rawImageStock = map['imageStockStatuses'];
    final rawImageImport = map['imageImportStatuses'];
    final rawCreatedAt = map['createdAt'];
    final rawViewCount = map['viewCount'];
    final rawLikeCount = map['likeCount'];
    final rawWishlistCount = map['wishlistCount'];
    final rawStock = map['stockStatus'];
    return StoreProduct(
      id:
          (map['id'] as String?) ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      tags:
          rawTags is List
              ? rawTags.map((e) => e.toString()).toList()
              : const [],
      imagePaths:
          rawPaths is List
              ? rawPaths.map((e) => e.toString()).toList()
              : const [],
      photoAssetIds:
          rawAssetIds is List
              ? rawAssetIds.map((e) => e.toString().trim()).toList()
              : const [],
      imageThumbhashes:
          rawThumbhashes is List
              ? rawThumbhashes.map((e) => e.toString()).toList()
              : const [],
      imageThumbnailUrls:
          rawThumbs is List
              ? rawThumbs.map((e) => e.toString()).toList()
              : const [],
      imageDetailUrls:
          rawDetails is List
              ? rawDetails.map((e) => e.toString()).toList()
              : const [],
      imageQualities:
          rawQualities is List
              ? rawQualities.map((e) => e.toString()).toList()
              : const [],
      imageIsLocked:
          rawImageLocked is List
              ? rawImageLocked.map((e) => e == true).toList()
              : const [],
      imageStockStatuses:
          rawImageStock is List
              ? rawImageStock.map((e) => e.toString().trim()).toList()
              : const [],
      imageImportStatuses:
          rawImageImport is List
              ? rawImageImport.map((e) => e.toString().trim()).toList()
              : const [],
      canEdit: map['canEdit'] == true,
      canDelete: map['canDelete'] == true,
      toneIndex: (map['toneIndex'] as int?) ?? 0,
      viewCount:
          rawViewCount is num
              ? rawViewCount.toInt()
              : (rawViewCount is int ? rawViewCount : null),
      likeCount:
          rawLikeCount is num
              ? rawLikeCount.toInt()
              : (rawLikeCount is int ? rawLikeCount : null),
      wishlistCount:
          rawWishlistCount is num
              ? rawWishlistCount.toInt()
              : (rawWishlistCount is int ? rawWishlistCount : null),
      isLocked: map['isLocked'] == true,
      stockStatus: CatalogStockStatus.tryParse(rawStock) ??
          (rawStock is String
              ? switch (rawStock) {
                'inStock' => CatalogStockStatus.inStock,
                'outOfStock' => CatalogStockStatus.outOfStock,
                'mto' => CatalogStockStatus.mto,
                _ => null,
              }
              : null),
      mtoDays: (map['mtoDays'] as num?)?.toInt(),
      precisionTag: (map['precisionTag'] as String?) ?? '',
      collectionId: (map['collectionId'] as String?) ?? '',
      importFlags: ProductImportFlags.fromJson(
        Map<String, dynamic>.from(map),
      ),
      createdAt: () {
        if (rawCreatedAt is int) {
          if (rawCreatedAt > 0 && rawCreatedAt < 100000000000) {
            return DateTime.fromMillisecondsSinceEpoch(
              rawCreatedAt * 1000,
              isUtc: true,
            ).toLocal();
          }
          return DateTime.fromMillisecondsSinceEpoch(
            rawCreatedAt,
            isUtc: true,
          ).toLocal();
        }
        if (rawCreatedAt is String) {
          return DateTime.tryParse(rawCreatedAt)?.toLocal() ?? DateTime.now();
        }
        return DateTime.now();
      }(),
    );
  }

  static List<StoreProduct> demoCatalog() {
    final now = DateTime.now();
    return [
      StoreProduct(
        id: 'demo_1',
        title: 'Solitaire ring',
        description:
            '18k white gold band with a brilliant-cut centre stone. Certified conflict-free.',
        tags: ['ring', 'diamond'],
        imagePaths: [],
        toneIndex: 0,
        createdAt: now,
      ),
      StoreProduct(
        id: 'demo_2',
        title: 'Rose gold bangle',
        description:
            'Hand-finished rose gold bangle with a soft brushed finish.',
        tags: ['bangle', 'rose gold'],
        imagePaths: [],
        toneIndex: 1,
        createdAt: now,
      ),
      StoreProduct(
        id: 'demo_3',
        title: 'Pearl drop earrings',
        description: 'Freshwater pearl drops set on a slim gold hook.',
        tags: ['earrings', 'pearl'],
        imagePaths: [],
        toneIndex: 2,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      StoreProduct(
        id: 'demo_4',
        title: 'Emerald pendant',
        description: 'Deep emerald pendant on a fine gold chain.',
        tags: ['pendant', 'emerald'],
        imagePaths: [],
        toneIndex: 3,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ];
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    tags,
    imagePaths,
    photoAssetIds,
    imageThumbhashes,
    imageThumbnailUrls,
    imageDetailUrls,
    imageQualities,
    imageIsLocked,
    imageStockStatuses,
    imageImportStatuses,
    canEdit,
    canDelete,
    toneIndex,
    viewCount,
    likeCount,
    wishlistCount,
    isLocked,
    stockStatus,
    mtoDays,
    precisionTag,
    collectionId,
    importFlags,
    createdAt,
  ];
}
