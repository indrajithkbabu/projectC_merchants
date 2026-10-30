import 'package:equatable/equatable.dart';
import 'package:project_c/models/bulk_upload.dart';
import 'package:project_c/models/catalog/catalog_product_models.dart';

/// Placeholder shown on store profile while a create upload runs in background.
class PendingProductUpload extends Equatable {
  const PendingProductUpload({
    required this.id,
    required this.storeId,
    required this.title,
    required this.photoCount,
    this.listingId,
  });

  final String id;
  final String storeId;
  final String title;
  final int photoCount;

  /// Set once create returns — hide this listing from the grid until finish.
  final String? listingId;

  PendingProductUpload copyWith({
    String? title,
    int? photoCount,
    String? listingId,
  }) {
    return PendingProductUpload(
      id: id,
      storeId: storeId,
      title: title ?? this.title,
      photoCount: photoCount ?? this.photoCount,
      listingId: listingId ?? this.listingId,
    );
  }

  @override
  List<Object?> get props => [id, storeId, title, photoCount, listingId];
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
