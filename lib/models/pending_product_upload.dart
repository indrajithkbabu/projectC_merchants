import 'package:equatable/equatable.dart';
import 'package:project_c/models/bulk_upload.dart';

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

  /// Set once `POST /collections` returns — hide this listing from the grid
  /// until the full upload finishes (avoids partial photo grids mid-append).
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

/// Snapshot for background title-only create.
class TitleOnlyUploadRequest {
  const TitleOnlyUploadRequest({
    required this.storeId,
    required this.title,
    required this.imagePaths,
    this.tags = const [],
    this.description = '',
  });

  final String storeId;
  final String title;
  final List<String> imagePaths;
  final List<String> tags;
  final String description;
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
  });

  final String storeId;
  final String title;
  final List<BulkUploadItem> items;
  final ProductSpec groupSpec;
  final List<String> tags;
  final String description;
  final List<BulkKnownSubGroup> knownSubGroups;
}
