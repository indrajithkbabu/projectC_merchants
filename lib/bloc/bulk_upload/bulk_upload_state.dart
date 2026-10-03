part of 'bulk_upload_bloc.dart';

class BulkUploadState extends Equatable {
  const BulkUploadState({
    this.storeId,
    this.images = const [],
    this.items = const [],
    this.groupTitle = '',
    this.description = '',
    this.tags = const [],
    this.tagDraft = '',
    this.groupSpec = const ProductSpec(),
    this.knownSubGroups = const [],
    this.isSelectMode = false,
    this.selectedItemIds = const [],
    this.shouldOpenGroupDetails = false,
    this.shouldOpenPreview = false,
    this.isPublishing = false,
    this.publishProgress = 0,
    this.isPublished = false,
    this.publishedProduct,
    this.publishedRevision,
    this.publishedApiTag,
    this.shouldCloseFlow = false,
    this.itemsBecameEmpty = false,
    this.isEditMode = false,
    this.listingId,
    this.revision = 1,
    this.shouldPopWithResult = false,
    this.errorMessage,
  });

  final String? storeId;
  final List<GalleryImageItem> images;
  final List<BulkUploadItem> items;
  final String groupTitle;
  /// Optional collection description (API ≤1000).
  final String description;
  /// Optional UI tag chips; joined into a single API `tag` (≤40).
  final List<String> tags;
  final String tagDraft;
  final ProductSpec groupSpec;
  final List<BulkKnownSubGroup> knownSubGroups;
  final bool isSelectMode;
  final List<String> selectedItemIds;
  final bool shouldOpenGroupDetails;
  final bool shouldOpenPreview;
  final bool isPublishing;
  /// 0–1 progress while [isPublishing] (photo upload / save steps).
  final double publishProgress;
  final bool isPublished;
  final StoreProduct? publishedProduct;
  final int? publishedRevision;
  final String? publishedApiTag;
  final bool shouldCloseFlow;
  final bool itemsBecameEmpty;
  final bool isEditMode;
  final String? listingId;
  final int revision;
  final bool shouldPopWithResult;
  final String? errorMessage;

  bool get canContinue =>
      groupTitle.trim().isNotEmpty && images.isNotEmpty && items.isNotEmpty;

  int get selectedCount => selectedItemIds.length;

  String displayNameOf(BulkUploadItem item) {
    final custom = item.customTitle.trim();
    if (custom.isNotEmpty) return custom;
    final index = items.indexWhere((entry) => entry.id == item.id);
    final title = groupTitle.trim();
    final prefix = title.isEmpty ? 'Item' : title;
    return '$prefix ${index + 1}';
  }

  /// Sub-groups the selection can move into (excludes the selection's own source).
  List<BulkKnownSubGroup> ungroupTargetsForSelection() {
    final selected =
        items.where((item) => selectedItemIds.contains(item.id)).toList();
    if (selected.isEmpty) return const [];
    final sourceKeys =
        selected.map((item) => item.subGroupId?.trim() ?? '').toSet();
    if (sourceKeys.length != 1) return const [];
    final source = sourceKeys.first;

    final byId = <String, BulkKnownSubGroup>{
      for (final sub in knownSubGroups)
        if (sub.id.trim().isNotEmpty && sub.id.trim() != source)
          sub.id.trim(): sub,
    };

    // In edit/refine mode we only allow real server sub-groups as targets.
    if (isEditMode) {
      return byId.values.toList(growable: false);
    }

    // Create-mode / local clusters among Precise items not in the selection.
    final selectedIds = selectedItemIds.toSet();
    final clusters = <String, List<BulkUploadItem>>{};
    for (final item in items) {
      if (selectedIds.contains(item.id)) continue;
      if (item.tag != BulkItemTag.precise &&
          item.tag != BulkItemTag.standalone) {
        continue;
      }
      final key =
          (item.subGroupId?.trim().isNotEmpty == true)
              ? item.subGroupId!.trim()
              : 'spec:${item.spec.hashCode}';
      if (key == source) continue;
      clusters.putIfAbsent(key, () => []).add(item);
    }
    for (final entry in clusters.entries) {
      if (byId.containsKey(entry.key)) continue;
      final sample = entry.value.first;
      final label =
          sample.spec.category.trim().isNotEmpty
              ? 'Precise · ${sample.spec.category.trim()}'
              : 'Precise group';
      byId[entry.key] = BulkKnownSubGroup(
        id: entry.key,
        name: '$label (${entry.value.length})',
        sampleSpec: sample.spec,
      );
    }
    return byId.values.toList(growable: false);
  }

  ProductSpec specForScope({
    required BulkSpecScope scope,
    String? itemId,
  }) {
    switch (scope) {
      case BulkSpecScope.group:
        return groupSpec;
      case BulkSpecScope.single:
        for (final item in items) {
          if (item.id == itemId) return item.spec;
        }
        return groupSpec;
      case BulkSpecScope.multi:
        final selected =
            items.where((item) => selectedItemIds.contains(item.id)).toList();
        if (selected.isEmpty) return groupSpec;
        final first = selected.first.spec;
        final allMatch = selected.every((item) => item.spec == first);
        return allMatch ? first : groupSpec;
    }
  }

  BulkUploadState copyWith({
    String? storeId,
    List<GalleryImageItem>? images,
    List<BulkUploadItem>? items,
    String? groupTitle,
    String? description,
    List<String>? tags,
    String? tagDraft,
    ProductSpec? groupSpec,
    List<BulkKnownSubGroup>? knownSubGroups,
    bool? isSelectMode,
    List<String>? selectedItemIds,
    bool? shouldOpenGroupDetails,
    bool clearShouldOpenGroupDetails = false,
    bool? shouldOpenPreview,
    bool clearShouldOpenPreview = false,
    bool? isPublishing,
    double? publishProgress,
    bool? isPublished,
    bool clearPublished = false,
    StoreProduct? publishedProduct,
    int? publishedRevision,
    String? publishedApiTag,
    bool? shouldCloseFlow,
    bool clearShouldCloseFlow = false,
    bool? itemsBecameEmpty,
    bool clearItemsBecameEmpty = false,
    bool? isEditMode,
    String? listingId,
    int? revision,
    bool? shouldPopWithResult,
    bool clearShouldPopWithResult = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BulkUploadState(
      storeId: storeId ?? this.storeId,
      images: images ?? this.images,
      items: items ?? this.items,
      groupTitle: groupTitle ?? this.groupTitle,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      tagDraft: tagDraft ?? this.tagDraft,
      groupSpec: groupSpec ?? this.groupSpec,
      knownSubGroups: knownSubGroups ?? this.knownSubGroups,
      isSelectMode: isSelectMode ?? this.isSelectMode,
      selectedItemIds: selectedItemIds ?? this.selectedItemIds,
      shouldOpenGroupDetails:
          clearShouldOpenGroupDetails
              ? false
              : (shouldOpenGroupDetails ?? this.shouldOpenGroupDetails),
      shouldOpenPreview:
          clearShouldOpenPreview
              ? false
              : (shouldOpenPreview ?? this.shouldOpenPreview),
      isPublishing: isPublishing ?? this.isPublishing,
      publishProgress: publishProgress ?? this.publishProgress,
      isPublished: clearPublished ? false : (isPublished ?? this.isPublished),
      publishedProduct:
          clearPublished
              ? null
              : (publishedProduct ?? this.publishedProduct),
      publishedRevision:
          clearPublished
              ? null
              : (publishedRevision ?? this.publishedRevision),
      publishedApiTag:
          clearPublished ? null : (publishedApiTag ?? this.publishedApiTag),
      shouldCloseFlow:
          clearShouldCloseFlow
              ? false
              : (shouldCloseFlow ?? this.shouldCloseFlow),
      itemsBecameEmpty:
          clearItemsBecameEmpty
              ? false
              : (itemsBecameEmpty ?? this.itemsBecameEmpty),
      isEditMode: isEditMode ?? this.isEditMode,
      listingId: listingId ?? this.listingId,
      revision: revision ?? this.revision,
      shouldPopWithResult:
          clearShouldPopWithResult
              ? false
              : (shouldPopWithResult ?? this.shouldPopWithResult),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    storeId,
    images,
    items,
    groupTitle,
    description,
    tags,
    tagDraft,
    groupSpec,
    knownSubGroups,
    isSelectMode,
    selectedItemIds,
    shouldOpenGroupDetails,
    shouldOpenPreview,
    isPublishing,
    publishProgress,
    isPublished,
    publishedProduct,
    publishedRevision,
    publishedApiTag,
    shouldCloseFlow,
    itemsBecameEmpty,
    isEditMode,
    listingId,
    revision,
    shouldPopWithResult,
    errorMessage,
  ];
}
