import 'package:equatable/equatable.dart';

/// Per-listing import status relative to the viewer's destination stores.
enum ListingImportAvailability { available, alreadyAdded, pending, unavailable }

ListingImportAvailability listingAvailabilityFor(List<ImportTarget> targets) {
  if (targets.isEmpty) return ListingImportAvailability.unavailable;
  if (targets.any((t) => t.canRequest)) {
    return ListingImportAvailability.available;
  }
  if (targets.any((t) => t.pending)) {
    return ListingImportAvailability.pending;
  }
  if (targets.any((t) => t.alreadyAdded)) {
    return ListingImportAvailability.alreadyAdded;
  }
  return ListingImportAvailability.unavailable;
}

class ImportTarget extends Equatable {
  const ImportTarget({
    required this.id,
    required this.name,
    required this.slug,
    required this.alreadyAdded,
    required this.pending,
  });

  final String id;
  final String name;
  final String slug;
  final bool alreadyAdded;
  final bool pending;

  bool get canRequest => !alreadyAdded && !pending;

  factory ImportTarget.fromJson(Map<String, dynamic> json) {
    return ImportTarget(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      alreadyAdded: json['alreadyAdded'] as bool? ?? false,
      pending: json['pending'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, name, slug, alreadyAdded, pending];
}

class ImportRequest extends Equatable {
  const ImportRequest({
    required this.id,
    required this.sourceListingId,
    required this.sourceStoreId,
    required this.destinationStoreId,
    required this.status,
    required this.expiresAt,
    this.decidedAt,
  });

  final String id;
  final String sourceListingId;
  final String sourceStoreId;
  final String destinationStoreId;
  final String status;
  final String expiresAt;
  final String? decidedAt;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';

  factory ImportRequest.fromJson(Map<String, dynamic> json) {
    return ImportRequest(
      id: json['id'] as String? ?? '',
      sourceListingId: json['sourceListingId'] as String? ?? '',
      sourceStoreId: json['sourceStoreId'] as String? ?? '',
      destinationStoreId: json['destinationStoreId'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      expiresAt: json['expiresAt'] as String? ?? '',
      decidedAt: json['decidedAt'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    sourceListingId,
    sourceStoreId,
    destinationStoreId,
    status,
    expiresAt,
    decidedAt,
  ];
}
