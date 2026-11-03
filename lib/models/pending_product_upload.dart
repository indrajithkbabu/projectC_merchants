import 'package:equatable/equatable.dart';
import 'package:project_c/models/bulk_upload.dart';
import 'package:project_c/models/catalog/catalog_product_models.dart';

/// Per-photo state for an in-flight create upload (Telegram-style tile).
enum PendingPhotoStatus {
  /// Queued — not yet compressing.
  waiting,

  /// On-device compress / ThumbHash in progress.
  preparing,

  /// Compressed; S3 PUT in flight (or about to start).
  uploading,

  /// S3 PUT succeeded — still show loader until commit + reveal.
  uploaded,

  /// Prepare or PUT failed — show X; dropped from final collage.
  failed,
}

/// One collage cell while [PendingProductUpload] is in flight.
class PendingPhotoSlot extends Equatable {
  const PendingPhotoSlot({
    required this.localPath,
    this.status = PendingPhotoStatus.waiting,
    this.displayPath = '',
    this.thumbhash = '',
    this.publicUrl = '',
    this.thumbnailUrl = '',
    this.detailUrl = '',
  });

  /// Gallery / compose path (stable identity for progress updates).
  final String localPath;

  final PendingPhotoStatus status;

  /// What the tile paints: compressed temp file, then seeded CDN URL.
  /// Empty → fall back to [localPath].
  final String displayPath;

  final String thumbhash;
  final String publicUrl;
  final String thumbnailUrl;
  final String detailUrl;

  /// Path used by [ProductMediaImage] (prefer seeded CDN / compressed).
  String get paintPath {
    final display = displayPath.trim();
    if (display.isNotEmpty) return display;
    return localPath.trim();
  }

  /// URL tier for a collage cell role (matches published card).
  String urlForCollageRole({required bool large}) {
    if (large) {
      final master = publicUrl.trim();
      if (master.isNotEmpty) return master;
      final detail = detailUrl.trim();
      if (detail.isNotEmpty) return detail;
    } else {
      final thumb = thumbnailUrl.trim();
      if (thumb.isNotEmpty) return thumb;
      final detail = detailUrl.trim();
      if (detail.isNotEmpty) return detail;
      final master = publicUrl.trim();
      if (master.isNotEmpty) return master;
    }
    return paintPath;
  }

  PendingPhotoSlot copyWith({
    PendingPhotoStatus? status,
    String? displayPath,
    String? thumbhash,
    String? publicUrl,
    String? thumbnailUrl,
    String? detailUrl,
  }) {
    return PendingPhotoSlot(
      localPath: localPath,
      status: status ?? this.status,
      displayPath: displayPath ?? this.displayPath,
      thumbhash: thumbhash ?? this.thumbhash,
      publicUrl: publicUrl ?? this.publicUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      detailUrl: detailUrl ?? this.detailUrl,
    );
  }

  @override
  List<Object?> get props => [
    localPath,
    status,
    displayPath,
    thumbhash,
    publicUrl,
    thumbnailUrl,
    detailUrl,
  ];
}

/// Placeholder shown on store profile while a create upload runs in background.
class PendingProductUpload extends Equatable {
  const PendingProductUpload({
    required this.id,
    required this.storeId,
    required this.title,
    required this.photoCount,
    this.listingId,
    this.photos = const [],
    this.isCommitting = false,
    this.isRevealing = false,
    this.hasFailed = false,
    this.failureMessage = '',
  });

  final String id;
  final String storeId;
  final String title;
  final int photoCount;

  /// Set once create returns — hide this listing from the grid until finish.
  final String? listingId;

  /// Collage order matching the eventual [StoreProduct.imagePaths] commit order.
  final List<PendingPhotoSlot> photos;

  /// All S3 PUTs done (or failed); waiting on products/batch / collection create.
  final bool isCommitting;

  /// Commit succeeded — UI staggers per-photo ticks, then swaps to the product.
  final bool isRevealing;

  /// Upload/commit failed — show close icons; tap retries the same request.
  final bool hasFailed;

  /// Last failure message (snack / accessibility).
  final String failureMessage;

  PendingProductUpload copyWith({
    String? title,
    int? photoCount,
    String? listingId,
    List<PendingPhotoSlot>? photos,
    bool? isCommitting,
    bool? isRevealing,
    bool? hasFailed,
    String? failureMessage,
  }) {
    return PendingProductUpload(
      id: id,
      storeId: storeId,
      title: title ?? this.title,
      photoCount: photoCount ?? this.photoCount,
      listingId: listingId ?? this.listingId,
      photos: photos ?? this.photos,
      isCommitting: isCommitting ?? this.isCommitting,
      isRevealing: isRevealing ?? this.isRevealing,
      hasFailed: hasFailed ?? this.hasFailed,
      failureMessage: failureMessage ?? this.failureMessage,
    );
  }

  @override
  List<Object?> get props => [
    id,
    storeId,
    title,
    photoCount,
    listingId,
    photos,
    isCommitting,
    isRevealing,
    hasFailed,
    failureMessage,
  ];
}

/// One photo’s compose fields for title-only / batch (aligned with imagePaths).
class TitleOnlyPhotoRow {
  const TitleOnlyPhotoRow({
    required this.spec,
    this.tags = const [],
    this.stockStatus = CatalogStockStatus.inStock,
    this.mtoDays,
    this.isLocked = false,
  });

  final ProductSpec spec;
  final List<String> tags;
  final CatalogStockStatus stockStatus;
  final int? mtoDays;
  final bool isLocked;
}

/// Snapshot for background title-only create.
class TitleOnlyUploadRequest {
  const TitleOnlyUploadRequest({
    required this.storeId,
    required this.title,
    required this.imagePaths,
    this.tags = const [],
    this.description = '',
    this.composeSpec = const ProductSpec(),
    this.photoRows = const [],
    this.stockStatus = CatalogStockStatus.inStock,
    this.mtoDays,
    this.isLocked = false,
  });

  final String storeId;
  final String title;
  final List<String> imagePaths;
  final List<String> tags;
  final String description;

  /// Compose rail defaults (metal/purity/…) — may be incomplete (`!isValid`).
  final ProductSpec composeSpec;

  /// When non-empty and aligned with [imagePaths], per-photo batch rows.
  final List<TitleOnlyPhotoRow> photoRows;
  final CatalogStockStatus stockStatus;
  final int? mtoDays;
  final bool isLocked;
}

/// Snapshot for background create with weight/purity/size (+ optional precise).
class SpecsUploadRequest {
  const SpecsUploadRequest({
    required this.storeId,
    required this.title,
    required this.items,
    required this.groupSpec,
    this.tags = const [],
    this.description = '',
    this.knownSubGroups = const [],
    this.photoRows = const [],
    this.stockStatus = CatalogStockStatus.inStock,
    this.mtoDays,
    this.isLocked = false,
  });

  final String storeId;
  final String title;
  final List<BulkUploadItem> items;
  final ProductSpec groupSpec;
  final List<String> tags;
  final String description;
  final List<BulkKnownSubGroup> knownSubGroups;

  /// When non-empty and aligned with [items], per-photo stock / mto / lock
  /// (compose This-photo). Falls back to [stockStatus] / [mtoDays] / [isLocked].
  final List<TitleOnlyPhotoRow> photoRows;
  final CatalogStockStatus stockStatus;
  final int? mtoDays;
  final bool isLocked;
}
