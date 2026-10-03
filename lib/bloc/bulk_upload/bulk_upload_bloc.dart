import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:project_c/bloc/add_store_product/add_store_product_bloc.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/catalog_ui_mapper.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/models/bulk_upload.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/services/catalog_direct_upload_service.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';

part 'bulk_upload_event.dart';
part 'bulk_upload_state.dart';

class BulkUploadBloc extends Bloc<BulkUploadEvent, BulkUploadState> {
  BulkUploadBloc({
    required List<GalleryImageItem> images,
    String? storeId,
    CollectionRepository? collectionRepository,
    CatalogDirectUploadService? directUploadService,
    CatalogSession? session,
  }) : _storeId = storeId,
       _collectionRepository =
           collectionRepository ??
           ServiceLocator.get<CollectionRepository>(),
       _directUpload =
           directUploadService ??
           ServiceLocator.get<CatalogDirectUploadService>(),
       _session = session ?? ServiceLocator.get<CatalogSession>(),
       super(
         BulkUploadState(
           storeId: storeId,
           images: _usableImages(images),
           items: [
             for (final image in _usableImages(images))
               BulkUploadItem(
                 id: image.id,
                 imagePath: image.filePath!,
               ),
           ],
         ),
       ) {
    _registerHandlers();
  }

  /// Hydrate refine/edit preview from an existing collection detail.
  BulkUploadBloc.fromCollectionDetail({
    required CollectionDetail detail,
    required String storeId,
    CollectionRepository? collectionRepository,
    CatalogDirectUploadService? directUploadService,
    CatalogSession? session,
  }) : _storeId = storeId,
       _collectionRepository =
           collectionRepository ??
           ServiceLocator.get<CollectionRepository>(),
       _directUpload =
           directUploadService ??
           ServiceLocator.get<CatalogDirectUploadService>(),
       _session = session ?? ServiceLocator.get<CatalogSession>(),
       super(_stateFromDetail(detail: detail, storeId: storeId)) {
    _registerHandlers();
  }

  final String? _storeId;
  final CollectionRepository _collectionRepository;
  final CatalogDirectUploadService _directUpload;
  final CatalogSession _session;
  static const _tag = 'BulkQA.Bloc';
  static const _ungroupTag = 'BulkQA.Ungroup';
  static const _publishTag = 'BulkQA.Publish';
  static const _editTag = 'BulkQA.Edit';
  static const _maxPhotoBytes = 500 * 1024 * 1024;

  static String _destinationLabel(BulkUngroupDestination destination) {
    return switch (destination) {
      BulkUngroupDestination.main => 'main',
      BulkUngroupDestination.existingSubgroup => 'existing_subgroup',
      BulkUngroupDestination.newSubgroup => 'new_subgroup',
      BulkUngroupDestination.newCollection => 'new_collection',
    };
  }

  static String _itemBrief(BulkUploadItem item) {
    final sub = item.subGroupId?.trim();
    return '${item.id}|${item.tag.name}'
        '|sub=${(sub == null || sub.isEmpty) ? '-' : sub}'
        '|specValid=${item.spec.isValid}'
        '|cat=${item.spec.category.trim().isEmpty ? '-' : item.spec.category.trim()}';
  }

  void _logSnapshot(String tag, String phase) {
    final counts = <String, int>{};
    for (final item in state.items) {
      final key = item.tag.name;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    AppLog.d(
      tag,
      '$phase edit=${state.isEditMode} listing=${state.listingId ?? '-'} '
      'rev=${state.revision} title="${state.groupTitle.trim()}" '
      'items=${state.items.length} selected=${state.selectedCount} '
      'selectMode=${state.isSelectMode} publishing=${state.isPublishing} '
      'tags=${counts.entries.map((e) => '${e.key}:${e.value}').join(',')} '
      'knownSubs=${state.knownSubGroups.map((s) => '${s.id}:${s.name}').join('|')}',
    );
    for (var i = 0; i < state.items.length; i++) {
      AppLog.d(tag, '  [$i] ${_itemBrief(state.items[i])}');
    }
  }

  void _logItemTagSummary(String phase) {
    _logSnapshot(_ungroupTag, phase);
  }

  String? get _effectiveStoreId =>
      state.storeId ?? _storeId ?? _session.ownStoreId;

  void _registerHandlers() {
    on<BulkUploadTitleChanged>(_onTitleChanged);
    on<BulkUploadDescriptionChanged>(_onDescriptionChanged);
    on<BulkUploadTagDraftChanged>(_onTagDraftChanged);
    on<BulkUploadTagAdded>(_onTagAdded);
    on<BulkUploadTagRemoved>(_onTagRemoved);
    on<BulkUploadSuggestedTagTapped>(_onSuggestedTagTapped);
    on<BulkUploadTitleOnlyPressed>(_onTitleOnlyPressed);
    on<BulkUploadAddDetailsPressed>(_onAddDetailsPressed);
    on<BulkUploadClearOpenGroupDetails>(_onClearOpenGroupDetails);
    on<BulkUploadApplyGroupSpec>(_onApplyGroupSpec);
    on<BulkUploadClearOpenPreview>(_onClearOpenPreview);
    on<BulkUploadSelectModeToggled>(_onSelectModeToggled);
    on<BulkUploadSelectionSet>(_onSelectionSet);
    on<BulkUploadItemSelectionToggled>(_onItemSelectionToggled);
    on<BulkUploadApplyItemSpec>(_onApplyItemSpec);
    on<BulkUploadApplyMultiSpec>(_onApplyMultiSpec);
    on<BulkUploadItemTitleChanged>(_onItemTitleChanged);
    on<BulkUploadItemImageReplaced>(_onItemImageReplaced);
    on<BulkUploadItemRemoved>(_onItemRemoved);
    on<BulkUploadImagesAdded>(_onImagesAdded);
    on<BulkUploadUngroupSelected>(_onUngroupSelected);
    on<BulkUploadDeleteSelected>(_onDeleteSelected);
    on<BulkUploadClearItemsEmpty>(_onClearItemsEmpty);
    on<BulkUploadPublishPressed>(_onPublishPressed);
    on<BulkUploadClearPublished>(_onClearPublished);
    on<BulkUploadRestartRequested>(_onRestartRequested);
    on<BulkUploadClearCloseFlow>(_onClearCloseFlow);
    on<BulkUploadClearMessage>(_onClearMessage);
    on<BulkUploadClearShouldPopWithResult>(_onClearShouldPopWithResult);
  }

  static BulkUploadState _stateFromDetail({
    required CollectionDetail detail,
    required String storeId,
  }) {
    final groupSpec = ProductSpec.fromApiJson(
      detail.specifications?.toJson(),
    );
    final items = <BulkUploadItem>[];
    final images = <GalleryImageItem>[];

    final mainPhotos =
        detail.mainGroupPhotos.isNotEmpty
            ? detail.mainGroupPhotos
            : (detail.subGroups.isEmpty
                ? detail.photos.where((p) => p.url.trim().isNotEmpty).toList()
                : const <CatalogPhoto>[]);

    for (final photo in mainPhotos) {
      final url = photo.url.trim();
      if (url.isEmpty) continue;
      final id = (photo.id?.trim().isNotEmpty == true)
          ? photo.id!.trim()
          : 'main_${url.hashCode}';
      items.add(
        BulkUploadItem(
          id: id,
          imagePath: url,
          tag: BulkItemTag.group,
          spec: groupSpec,
        ),
      );
      images.add(
        GalleryImageItem(
          id: id,
          filePath: url,
          assetId: photo.id?.trim(),
          isPlaceholder: false,
        ),
      );
    }

    for (final sub in detail.subGroups) {
      final subSpec = ProductSpec.fromApiJson(sub.specifications?.toJson());
      final effectiveSpec = subSpec.isValid ? subSpec : groupSpec;
      final isStandalone = sub.name.toLowerCase().contains('standalone');
      for (final photo in sub.photos) {
        final url = photo.url.trim();
        if (url.isEmpty) continue;
        final id = (photo.id?.trim().isNotEmpty == true)
            ? photo.id!.trim()
            : 'sub_${sub.id}_${url.hashCode}';
        items.add(
          BulkUploadItem(
            id: id,
            imagePath: url,
            tag:
                isStandalone
                    ? BulkItemTag.standalone
                    : BulkItemTag.precise,
            spec: effectiveSpec,
            customTitle: sub.name.trim(),
            subGroupId: sub.id.trim().isEmpty ? null : sub.id.trim(),
          ),
        );
        images.add(
          GalleryImageItem(
            id: id,
            filePath: url,
            assetId: photo.id?.trim(),
            isPlaceholder: false,
          ),
        );
      }
    }

    AppLog.d(
      _editTag,
      'hydrate listing=${detail.id} name="${detail.name}" '
      'photos=${detail.photoCount} main=${detail.mainGroupPhotos.length} '
      'subs=${detail.subGroups.length} revision=${detail.revision} '
      'items=${items.length}',
    );
    for (var i = 0; i < items.length; i++) {
      AppLog.d(_editTag, '  hydrate[$i] ${_itemBrief(items[i])}');
    }

    final apiTag = detail.tag.trim();
    return BulkUploadState(
      storeId: storeId,
      images: images,
      items: items,
      groupTitle: detail.name,
      description: detail.description,
      tags:
          apiTag.isEmpty
              ? const <String>[]
              : apiTag
                  .split(',')
                  .map((t) => t.trim().toLowerCase())
                  .where((t) => t.isNotEmpty)
                  .toList(growable: false),
      groupSpec: groupSpec,
      knownSubGroups: [
        for (final sub in detail.subGroups)
          if (sub.id.trim().isNotEmpty)
            BulkKnownSubGroup(
              id: sub.id.trim(),
              name:
                  sub.name.trim().isNotEmpty
                      ? sub.name.trim()
                      : 'Sub-group',
              sampleSpec: ProductSpec.fromApiJson(
                sub.specifications?.toJson(),
              ),
            ),
      ],
      isEditMode: true,
      listingId: detail.id,
      revision: detail.revision,
    );
  }

  static List<GalleryImageItem> _usableImages(List<GalleryImageItem> images) {
    return images
        .where((item) => !item.isPlaceholder && item.filePath != null)
        .toList(growable: false);
  }

  void _onTitleChanged(
    BulkUploadTitleChanged event,
    Emitter<BulkUploadState> emit,
  ) {
    emit(state.copyWith(groupTitle: event.value, clearError: true));
  }

  void _onDescriptionChanged(
    BulkUploadDescriptionChanged event,
    Emitter<BulkUploadState> emit,
  ) {
    emit(state.copyWith(description: event.value, clearError: true));
  }

  void _onTagDraftChanged(
    BulkUploadTagDraftChanged event,
    Emitter<BulkUploadState> emit,
  ) {
    emit(state.copyWith(tagDraft: event.value));
  }

  void _onTagAdded(
    BulkUploadTagAdded event,
    Emitter<BulkUploadState> emit,
  ) {
    final tag = event.tag.trim().toLowerCase();
    if (tag.isEmpty || state.tags.contains(tag)) {
      emit(state.copyWith(tagDraft: ''));
      return;
    }
    emit(
      state.copyWith(
        tags: [...state.tags, tag],
        tagDraft: '',
        clearError: true,
      ),
    );
  }

  void _onTagRemoved(
    BulkUploadTagRemoved event,
    Emitter<BulkUploadState> emit,
  ) {
    emit(
      state.copyWith(
        tags: state.tags.where((t) => t != event.tag).toList(),
        clearError: true,
      ),
    );
  }

  void _onSuggestedTagTapped(
    BulkUploadSuggestedTagTapped event,
    Emitter<BulkUploadState> emit,
  ) {
    add(BulkUploadTagAdded(event.tag));
  }

  Future<void> _onTitleOnlyPressed(
    BulkUploadTitleOnlyPressed event,
    Emitter<BulkUploadState> emit,
  ) async {
    if (!state.canContinue || state.isPublishing || state.isPublished) return;
    final storeId = _effectiveStoreId;
    if (storeId == null || storeId.isEmpty) {
      emit(
        state.copyWith(
          errorMessage: 'Create a store before publishing products.',
        ),
      );
      return;
    }
    await _publishTitleOnly(emit, storeId: storeId);
  }

  void _onAddDetailsPressed(
    BulkUploadAddDetailsPressed event,
    Emitter<BulkUploadState> emit,
  ) {
    if (!state.canContinue) return;
    emit(state.copyWith(shouldOpenGroupDetails: true, clearError: true));
  }

  void _onClearOpenGroupDetails(
    BulkUploadClearOpenGroupDetails event,
    Emitter<BulkUploadState> emit,
  ) {
    emit(state.copyWith(clearShouldOpenGroupDetails: true));
  }

  void _onApplyGroupSpec(
    BulkUploadApplyGroupSpec event,
    Emitter<BulkUploadState> emit,
  ) {
    if (!event.spec.isValid) {
      AppLog.d(_tag, 'ApplyGroupSpec REJECT invalid_spec');
      return;
    }
    AppLog.d(
      _tag,
      'ApplyGroupSpec → all group cat=${event.spec.category} '
      'items=${state.items.length}',
    );
    emit(
      state.copyWith(
        groupSpec: event.spec,
        items: [
          for (final item in state.items)
            item.copyWith(spec: event.spec, tag: BulkItemTag.group),
        ],
        isSelectMode: false,
        selectedItemIds: const [],
        shouldOpenPreview: true,
        isPublished: false,
        clearError: true,
      ),
    );
    _logSnapshot(_tag, 'after_apply_group_spec');
  }

  void _onClearOpenPreview(
    BulkUploadClearOpenPreview event,
    Emitter<BulkUploadState> emit,
  ) {
    emit(state.copyWith(clearShouldOpenPreview: true));
  }

  void _onSelectModeToggled(
    BulkUploadSelectModeToggled event,
    Emitter<BulkUploadState> emit,
  ) {
    AppLog.d(
      _tag,
      'SelectMode enabled=${event.enabled} was=${state.isSelectMode} '
      'selected=${state.selectedCount}',
    );
    emit(
      state.copyWith(
        isSelectMode: event.enabled,
        selectedItemIds: event.enabled ? state.selectedItemIds : const [],
        clearError: true,
      ),
    );
  }

  void _onSelectionSet(
    BulkUploadSelectionSet event,
    Emitter<BulkUploadState> emit,
  ) {
    final known = state.items.map((item) => item.id).toSet();
    final ids = [
      for (final id in event.itemIds)
        if (known.contains(id)) id,
    ];
    AppLog.d(
      _tag,
      'SelectionSet count=${ids.length} selectMode=${event.selectMode} '
      'ids=${ids.join(',')}',
    );
    emit(
      state.copyWith(
        isSelectMode: event.selectMode && ids.isNotEmpty,
        selectedItemIds: ids,
        clearError: true,
      ),
    );
  }

  void _onItemSelectionToggled(
    BulkUploadItemSelectionToggled event,
    Emitter<BulkUploadState> emit,
  ) {
    final selected = List<String>.from(state.selectedItemIds);
    final adding = !selected.contains(event.itemId);
    if (selected.contains(event.itemId)) {
      selected.remove(event.itemId);
    } else {
      selected.add(event.itemId);
    }
    AppLog.d(
      _tag,
      'ItemSelection ${adding ? 'add' : 'remove'} id=${event.itemId} '
      'now=${selected.length}',
    );
    emit(state.copyWith(selectedItemIds: selected, clearError: true));
  }

  void _onApplyItemSpec(
    BulkUploadApplyItemSpec event,
    Emitter<BulkUploadState> emit,
  ) {
    if (!event.spec.isValid) {
      AppLog.d(_tag, 'ApplyItemSpec REJECT invalid_spec item=${event.itemId}');
      return;
    }
    AppLog.d(
      _tag,
      'ApplyItemSpec item=${event.itemId} → precise '
      'cat=${event.spec.category} valid=${event.spec.isValid}',
    );
    emit(
      state.copyWith(
        items: [
          for (final item in state.items)
            item.id == event.itemId
                ? item.copyWith(spec: event.spec, tag: BulkItemTag.precise)
                : item,
        ],
        clearError: true,
      ),
    );
    _logSnapshot(_tag, 'after_apply_item_spec');
  }

  void _onApplyMultiSpec(
    BulkUploadApplyMultiSpec event,
    Emitter<BulkUploadState> emit,
  ) {
    if (!event.spec.isValid || state.selectedItemIds.isEmpty) {
      AppLog.d(
        _tag,
        'ApplyMultiSpec REJECT valid=${event.spec.isValid} '
        'selected=${state.selectedCount}',
      );
      return;
    }
    final ids = state.selectedItemIds.toSet();
    AppLog.d(
      _tag,
      'ApplyMultiSpec count=${ids.length} → precise '
      'ids=${ids.join(',')} cat=${event.spec.category}',
    );
    emit(
      state.copyWith(
        items: [
          for (final item in state.items)
            ids.contains(item.id)
                ? item.copyWith(spec: event.spec, tag: BulkItemTag.precise)
                : item,
        ],
        isSelectMode: false,
        selectedItemIds: const [],
        clearError: true,
      ),
    );
    _logSnapshot(_tag, 'after_apply_multi_spec');
  }

  void _onItemTitleChanged(
    BulkUploadItemTitleChanged event,
    Emitter<BulkUploadState> emit,
  ) {
    emit(
      state.copyWith(
        items: [
          for (final item in state.items)
            item.id == event.itemId
                ? item.copyWith(customTitle: event.title)
                : item,
        ],
        clearError: true,
      ),
    );
  }

  void _onItemImageReplaced(
    BulkUploadItemImageReplaced event,
    Emitter<BulkUploadState> emit,
  ) {
    final path = event.imagePath.trim();
    if (path.isEmpty) return;
    emit(
      state.copyWith(
        items: [
          for (final item in state.items)
            item.id == event.itemId ? item.copyWith(imagePath: path) : item,
        ],
        images: [
          for (final image in state.images)
            image.id == event.itemId
                ? GalleryImageItem(
                  id: image.id,
                  filePath: path,
                  // Local crop/replace — clear catalog asset id.
                  assetId: null,
                  isPlaceholder: false,
                )
                : image,
        ],
        clearError: true,
      ),
    );
  }

  void _onItemRemoved(
    BulkUploadItemRemoved event,
    Emitter<BulkUploadState> emit,
  ) {
    if (state.items.length <= 1) {
      emit(
        state.copyWith(
          errorMessage: 'Keep at least one photo in this upload.',
        ),
      );
      return;
    }
    final nextItems =
        state.items.where((item) => item.id != event.itemId).toList();
    final nextImages =
        state.images.where((image) => image.id != event.itemId).toList();
    final nextSelected =
        state.selectedItemIds.where((id) => id != event.itemId).toList();
    emit(
      state.copyWith(
        items: nextItems,
        images: nextImages,
        selectedItemIds: nextSelected,
        isSelectMode: nextItems.isNotEmpty && state.isSelectMode,
        itemsBecameEmpty: nextItems.isEmpty,
        errorMessage:
            nextItems.isEmpty
                ? 'All items were removed from this upload.'
                : null,
        clearError: nextItems.isNotEmpty,
      ),
    );
  }

  static const _maxPhotosPerCollection = 50;

  void _onImagesAdded(
    BulkUploadImagesAdded event,
    Emitter<BulkUploadState> emit,
  ) {
    final paths = [
      for (final path in event.filePaths)
        if (path.trim().isNotEmpty) path.trim(),
    ];
    if (paths.isEmpty) return;

    final remaining = _maxPhotosPerCollection - state.items.length;
    if (remaining <= 0) {
      emit(
        state.copyWith(
          errorMessage:
              'You can upload at most $_maxPhotosPerCollection photos.',
        ),
      );
      return;
    }

    final toAdd = paths.take(remaining).toList();
    final nextItems = List<BulkUploadItem>.from(state.items);
    final nextImages = List<GalleryImageItem>.from(state.images);
    final baseSpec =
        state.groupSpec.isValid ? state.groupSpec : const ProductSpec();

    for (var i = 0; i < toAdd.length; i++) {
      final path = toAdd[i];
      final id =
          'added_${DateTime.now().millisecondsSinceEpoch}_${path.hashCode}_$i';
      nextItems.add(
        BulkUploadItem(
          id: id,
          imagePath: path,
          tag: BulkItemTag.group,
          spec: baseSpec,
        ),
      );
      nextImages.add(
        GalleryImageItem(id: id, filePath: path, isPlaceholder: false),
      );
    }

    emit(
      state.copyWith(
        items: nextItems,
        images: nextImages,
        errorMessage:
            paths.length > remaining
                ? 'Only $remaining more photo(s) could be added (max $_maxPhotosPerCollection).'
                : null,
        clearError: paths.length <= remaining,
      ),
    );
  }

  Future<void> _onUngroupSelected(
    BulkUploadUngroupSelected event,
    Emitter<BulkUploadState> emit,
  ) async {
    if (state.selectedItemIds.isEmpty) return;
    final ids = state.selectedItemIds.toSet();
    final selected =
        state.items.where((item) => ids.contains(item.id)).toList();
    if (selected.isEmpty) return;

    final sourceKeys =
        selected.map((item) => item.subGroupId?.trim() ?? '').toSet();
    if (sourceKeys.length != 1) {
      AppLog.d(
        _ungroupTag,
        'REJECT mixed_source selected=${selected.length} sources=$sourceKeys',
      );
      emit(
        state.copyWith(
          errorMessage:
              'Select items from the same group only. Mixing main and sub-group photos is not allowed.',
        ),
      );
      return;
    }
    final sourceSubGroupId = sourceKeys.first;
    AppLog.d(
      _ungroupTag,
      'START dest=${_destinationLabel(event.destination)} '
      'edit=${state.isEditMode} listing=${state.listingId ?? '-'} '
      'sourceSub=${sourceSubGroupId.isEmpty ? 'main' : sourceSubGroupId} '
      'selected=${selected.length} photoIds=${selected.map((i) => i.id).join(',')} '
      'targetSub=${event.targetSubGroupId ?? '-'} newName="${event.newName.trim()}"',
    );
    for (final item in selected) {
      AppLog.d(_ungroupTag, '  selected ${_itemBrief(item)}');
    }
    _logSnapshot(_ungroupTag, 'before_ungroup');

    if (event.destination == BulkUngroupDestination.main &&
        sourceSubGroupId.isEmpty) {
      AppLog.d(_ungroupTag, 'NOOP already_in_main');
      emit(
        state.copyWith(
          isSelectMode: false,
          selectedItemIds: const [],
          clearError: true,
        ),
      );
      return;
    }

    if (event.destination == BulkUngroupDestination.existingSubgroup) {
      final target = event.targetSubGroupId?.trim() ?? '';
      if (target.isEmpty) {
        emit(
          state.copyWith(errorMessage: 'Choose a sub-group to move into.'),
        );
        return;
      }
    }

    if (event.destination == BulkUngroupDestination.newSubgroup ||
        event.destination == BulkUngroupDestination.newCollection) {
      if (event.newName.trim().isEmpty) {
        emit(
          state.copyWith(
            errorMessage:
                event.destination == BulkUngroupDestination.newCollection
                    ? 'Enter a name for the new collection.'
                    : 'Enter a name for the new sub-group.',
          ),
        );
        return;
      }
    }

    if (event.destination == BulkUngroupDestination.newSubgroup ||
        event.destination == BulkUngroupDestination.newCollection) {
      final sample = selected.first.spec;
      if (!sample.isValid) {
        AppLog.d(_ungroupTag, 'REJECT invalid_spec_for_new_dest');
        emit(
          state.copyWith(
            errorMessage:
                'Selected items need complete details before creating a new sub-group or collection.',
          ),
        );
        return;
      }
    }

    if (event.destination == BulkUngroupDestination.newCollection &&
        !state.isEditMode) {
      AppLog.d(_ungroupTag, 'REJECT new_collection_before_publish');
      emit(
        state.copyWith(
          errorMessage:
              'Splitting into a new collection is available after this group is published. Use Save / Done first, then refine.',
        ),
      );
      return;
    }

    if (!state.isEditMode) {
      AppLog.d(
        _ungroupTag,
        'REJECT create_mode_ungroup — use collection browse after publish',
      );
      emit(
        state.copyWith(
          errorMessage:
              'Ungroup is available after publish from the collection browse screen.',
        ),
      );
      return;
    }

    final canCallMoveApi =
        state.isEditMode &&
        (state.listingId?.trim().isNotEmpty ?? false) &&
        (state.storeId?.trim().isNotEmpty ?? false) &&
        // Server move needs real photo + subgroup ids (not local create keys).
        !sourceSubGroupId.startsWith('spec:') &&
        !sourceSubGroupId.startsWith('local_') &&
        selected.every((item) => item.id.trim().isNotEmpty);

    if (canCallMoveApi &&
        (sourceSubGroupId.isNotEmpty ||
            event.destination != BulkUngroupDestination.main)) {
      // existing_subgroup with local-only target keys cannot hit the API.
      if (event.destination == BulkUngroupDestination.existingSubgroup) {
        final target = event.targetSubGroupId!.trim();
        final isServerTarget = state.knownSubGroups.any(
          (sub) => sub.id.trim() == target,
        );
        if (!isServerTarget) {
          AppLog.d(
            _ungroupTag,
            'REJECT invalid_server_target target=$target',
          );
          emit(
            state.copyWith(
              errorMessage:
                  'Select a valid sub-group and try again. Refresh this screen if targets look outdated.',
            ),
          );
          return;
        }
      }
      AppLog.d(_ungroupTag, 'PATH server_movePhotos canCallMoveApi=true');
      await _moveSelectedOnServer(
        emit,
        event: event,
        selected: selected,
        sourceSubGroupId: sourceSubGroupId,
      );
      return;
    }

    if (state.isEditMode) {
      AppLog.d(
        _ungroupTag,
        'REJECT edit_local_fallback canCallMoveApi=false '
        'sourceSub=$sourceSubGroupId',
      );
      emit(
        state.copyWith(
          errorMessage:
              'Unable to move right now. Please reopen refine and try again.',
        ),
      );
      return;
    }

    AppLog.d(_ungroupTag, 'PATH local_apply create_mode');
    _applyLocalUngroup(emit, event: event, selectedIds: ids);
  }

  void _applyLocalUngroup(
    Emitter<BulkUploadState> emit, {
    required BulkUploadUngroupSelected event,
    required Set<String> selectedIds,
  }) {
    final groupTitle = state.groupTitle.trim();
    switch (event.destination) {
      case BulkUngroupDestination.main:
        emit(
          state.copyWith(
            items: [
              for (final item in state.items)
                selectedIds.contains(item.id)
                    ? item.copyWith(
                      tag: BulkItemTag.group,
                      spec: state.groupSpec,
                      clearSubGroupId: true,
                    )
                    : item,
            ],
            isSelectMode: false,
            selectedItemIds: const [],
            clearError: true,
          ),
        );
        AppLog.d(
          _ungroupTag,
          'OK local_main moved=${selectedIds.length} → group tag',
        );
        _logItemTagSummary('after_local_main');
        return;
      case BulkUngroupDestination.existingSubgroup:
        final targetId = event.targetSubGroupId!.trim();
        BulkKnownSubGroup? known;
        for (final sub in state.knownSubGroups) {
          if (sub.id.trim() == targetId) {
            known = sub;
            break;
          }
        }
        ProductSpec targetSpec = known?.sampleSpec ?? const ProductSpec();
        if (!targetSpec.isValid) {
          for (final item in state.items) {
            if ((item.subGroupId?.trim() ?? '') == targetId ||
                'spec:${item.spec.hashCode}' == targetId) {
              targetSpec = item.spec;
              break;
            }
          }
        }
        if (!targetSpec.isValid) {
          targetSpec = state.groupSpec;
        }
        final resolvedSubId =
            targetId.startsWith('spec:')
                ? 'local_${DateTime.now().microsecondsSinceEpoch}'
                : targetId;
        // If joining a local spec-cluster, also stamp sibling items with the same id.
        emit(
          state.copyWith(
            items: [
              for (final item in state.items)
                if (selectedIds.contains(item.id))
                  item.copyWith(
                    tag: BulkItemTag.precise,
                    spec: targetSpec,
                    subGroupId: resolvedSubId,
                  )
                else if (targetId.startsWith('spec:') &&
                    item.tag == BulkItemTag.precise &&
                    'spec:${item.spec.hashCode}' == targetId &&
                    (item.subGroupId == null ||
                        item.subGroupId!.trim().isEmpty))
                  item.copyWith(subGroupId: resolvedSubId)
                else
                  item,
            ],
            knownSubGroups: [
              ...state.knownSubGroups.where((sub) => sub.id != targetId),
              if (!state.knownSubGroups.any((sub) => sub.id == resolvedSubId))
                BulkKnownSubGroup(
                  id: resolvedSubId,
                  name:
                      event.newName.trim().isNotEmpty
                          ? event.newName.trim()
                          : (known?.name ?? 'Precise group'),
                  sampleSpec: targetSpec,
                ),
            ],
            isSelectMode: false,
            selectedItemIds: const [],
            clearError: true,
          ),
        );
        AppLog.d(
          _ungroupTag,
          'OK local_existing target=$targetId resolved=$resolvedSubId '
          'moved=${selectedIds.length}',
        );
        _logItemTagSummary('after_local_existing');
        return;
      case BulkUngroupDestination.newSubgroup:
        final newId = 'local_${DateTime.now().microsecondsSinceEpoch}';
        final name =
            event.newName.trim().isNotEmpty
                ? event.newName.trim()
                : '$groupTitle precise';
        final sampleSpec =
            selectedIds.isEmpty
                ? state.groupSpec
                : state.items
                    .firstWhere(
                      (item) => selectedIds.contains(item.id),
                      orElse: () => state.items.first,
                    )
                    .spec;
        emit(
          state.copyWith(
            items: [
              for (final item in state.items)
                selectedIds.contains(item.id)
                    ? item.copyWith(
                      tag: BulkItemTag.precise,
                      subGroupId: newId,
                    )
                    : item,
            ],
            knownSubGroups: [
              ...state.knownSubGroups,
              BulkKnownSubGroup(
                id: newId,
                name: name,
                sampleSpec: sampleSpec.isValid ? sampleSpec : state.groupSpec,
              ),
            ],
            isSelectMode: false,
            selectedItemIds: const [],
            clearError: true,
          ),
        );
        AppLog.d(
          _ungroupTag,
          'OK local_new_subgroup id=$newId name=$name moved=${selectedIds.length}',
        );
        _logItemTagSummary('after_local_new_subgroup');
        return;
      case BulkUngroupDestination.newCollection:
        // Create-mode split is blocked earlier; keep as safety no-op message.
        AppLog.d(_ungroupTag, 'REJECT local_new_collection safety');
        emit(
          state.copyWith(
            errorMessage:
                'Splitting into a new collection is available after publish.',
          ),
        );
        return;
    }
  }

  Future<void> _moveSelectedOnServer(
    Emitter<BulkUploadState> emit, {
    required BulkUploadUngroupSelected event,
    required List<BulkUploadItem> selected,
    required String sourceSubGroupId,
  }) async {
    final storeId = state.storeId!.trim();
    final listingId = state.listingId!.trim();
    final photoIds =
        selected.map((item) => item.id.trim()).where((id) => id.isNotEmpty).toList();
    if (photoIds.isEmpty) return;

    final source =
        sourceSubGroupId.isEmpty
            ? <String, dynamic>{'type': 'main'}
            : <String, dynamic>{
              'type': 'subgroup',
              'subGroupId': sourceSubGroupId,
            };

    Map<String, dynamic> destination;
    switch (event.destination) {
      case BulkUngroupDestination.main:
        destination = <String, dynamic>{'type': 'main'};
      case BulkUngroupDestination.existingSubgroup:
        destination = <String, dynamic>{
          'type': 'existing_subgroup',
          'targetSubGroupId': event.targetSubGroupId!.trim(),
        };
      case BulkUngroupDestination.newSubgroup:
        final sample = selected.first.spec;
        if (!sample.isValid) {
          emit(
            state.copyWith(
              isPublishing: false,
              errorMessage:
                  'Complete item details before creating a new sub-group.',
            ),
          );
          return;
        }
        destination = <String, dynamic>{
          'type': 'new_subgroup',
          'subGroupDetails': {
            'name': event.newName.trim(),
            'tag': sample.category.trim().isNotEmpty
                ? sample.category.trim()
                : state.groupSpec.category,
            'usePrecisionTag': sample.isValid,
            if (sample.isValid) 'specifications': sample.toApiJson(),
          },
        };
      case BulkUngroupDestination.newCollection:
        final sample = selected.first.spec;
        if (!sample.isValid) {
          emit(
            state.copyWith(
              isPublishing: false,
              errorMessage:
                  'Complete item details before splitting into a new collection.',
            ),
          );
          return;
        }
        final remaining = state.items.length - selected.length;
        if (remaining < 1) {
          emit(
            state.copyWith(
              errorMessage:
                  'Keep at least one photo in this collection. Delete the collection instead if you want to remove everything.',
            ),
          );
          return;
        }
        destination = <String, dynamic>{
          'type': 'new_collection',
          'collectionDetails': {
            'name': event.newName.trim(),
            'tag': sample.category.trim().isNotEmpty
                ? sample.category.trim()
                : state.groupSpec.category,
            'usePrecisionTag': sample.isValid,
            if (sample.isValid) 'specifications': sample.toApiJson(),
          },
        };
    }

    AppLog.d(
      _ungroupTag,
      'API movePhotos source=$source dest=$destination '
      'photoIds=$photoIds revision=${state.revision}',
    );

    emit(
      state.copyWith(
        isPublishing: true,
        clearError: true,
      ),
    );

    try {
      final moved = await _collectionRepository.movePhotos(
        storeId: storeId,
        listingId: listingId,
        source: source,
        destination: destination,
        photoIds: photoIds,
        revision: state.revision,
      );
      final detail = await _collectionRepository.fetchCollection(
        storeId: storeId,
        listingId: listingId,
      );
      final refreshed = _stateFromDetail(detail: detail, storeId: storeId);
      final newCollectionId = moved.newCollectionId?.trim();
      AppLog.d(
        _ungroupTag,
        'OK server_move photos=${detail.photoCount} subs=${detail.subGroups.length} '
        'revision=${detail.revision} '
        'newCollectionId=${newCollectionId ?? '-'}',
      );
      emit(
        refreshed.copyWith(
          isPublishing: false,
          isSelectMode: false,
          selectedItemIds: const [],
          clearError: true,
          errorMessage:
              (newCollectionId != null && newCollectionId.isNotEmpty)
                  ? 'Moved to a new collection.'
                  : null,
        ),
      );
      _logItemTagSummary('after_server_move');
    } catch (e) {
      AppLog.e(_ungroupTag, 'FAIL server_move', e);
      emit(
        state.copyWith(
          isPublishing: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  /// Cluster key for Precise/Standalone publish: prefer explicit sub-group id.
  static String _precisionClusterKey(BulkUploadItem item) {
    final subId = item.subGroupId?.trim() ?? '';
    if (subId.isNotEmpty) return 'sg:$subId';
    return 'spec:${item.spec.hashCode}';
  }

  void _onDeleteSelected(
    BulkUploadDeleteSelected event,
    Emitter<BulkUploadState> emit,
  ) {
    if (state.selectedItemIds.isEmpty) return;
    final ids = state.selectedItemIds.toSet();
    AppLog.d(_tag, 'DeleteSelected count=${ids.length} ids=${ids.join(',')}');
    final nextItems =
        state.items.where((item) => !ids.contains(item.id)).toList();
    final nextImages =
        state.images.where((image) => !ids.contains(image.id)).toList();
    emit(
      state.copyWith(
        items: nextItems,
        images: nextImages,
        isSelectMode: nextItems.isNotEmpty && state.isSelectMode,
        selectedItemIds: const [],
        itemsBecameEmpty: nextItems.isEmpty,
        errorMessage:
            nextItems.isEmpty
                ? 'All items were removed from this upload.'
                : null,
        clearError: nextItems.isNotEmpty,
      ),
    );
    _logSnapshot(_tag, 'after_delete_selected');
  }

  void _onClearItemsEmpty(
    BulkUploadClearItemsEmpty event,
    Emitter<BulkUploadState> emit,
  ) {
    emit(state.copyWith(clearItemsBecameEmpty: true));
  }

  Future<void> _onPublishPressed(
    BulkUploadPublishPressed event,
    Emitter<BulkUploadState> emit,
  ) async {
    AppLog.d(
      _publishTag,
      'PublishPressed edit=${state.isEditMode} items=${state.items.length} '
      'publishing=${state.isPublishing} published=${state.isPublished}',
    );
    _logSnapshot(_publishTag, 'before_publish');
    if (state.items.isEmpty || state.isPublished || state.isPublishing) {
      AppLog.d(_publishTag, 'SKIP empty_or_busy');
      return;
    }
    if (state.isEditMode && state.shouldPopWithResult) {
      AppLog.d(_publishTag, 'SKIP already_popping');
      return;
    }

    final storeId = _effectiveStoreId;
    if (storeId == null || storeId.isEmpty) {
      AppLog.d(_publishTag, 'REJECT missing_store');
      emit(
        state.copyWith(
          errorMessage: 'Create a store before publishing products.',
        ),
      );
      return;
    }

    if (!state.isEditMode && !state.groupSpec.isValid) {
      AppLog.d(_publishTag, 'REJECT invalid_group_spec');
      emit(
        state.copyWith(
          errorMessage:
              'Group details are incomplete. Go back and fill weight, purity, wastage, size, metal, and category.',
        ),
      );
      return;
    }

    if (state.isEditMode) {
      AppLog.d(_publishTag, 'PATH save_edit store=$storeId');
      await _saveEdit(emit, storeId: storeId);
      return;
    }

    AppLog.d(_publishTag, 'PATH publish_create store=$storeId');
    await _publishCreate(emit, storeId: storeId);
  }

  Future<void> _saveEdit(
    Emitter<BulkUploadState> emit, {
    required String storeId,
  }) async {
    final listingId = state.listingId?.trim() ?? '';
    if (listingId.isEmpty) {
      emit(state.copyWith(errorMessage: 'Unable to save — missing listing.'));
      return;
    }

    emit(
      state.copyWith(
        isPublishing: true,
        publishProgress: 0,
        isSelectMode: false,
        selectedItemIds: const [],
        clearError: true,
        clearShouldPopWithResult: true,
      ),
    );

    try {
      var revision = state.revision;
      final groupTitle = state.groupTitle.trim();

      // Persist WhatsApp-style photo edits (local paths) before specs/subgroups.
      revision = await _syncReplacedEditPhotos(
        emit,
        storeId: storeId,
        listingId: listingId,
        revision: revision,
      );
      _setPublishProgress(emit, 0.08);

      final updated = await _collectionRepository.updateCollection(
        storeId: storeId,
        listingId: listingId,
        revision: revision,
        name: groupTitle.isNotEmpty ? groupTitle : null,
        specifications:
            state.groupSpec.isValid ? state.groupSpec.toApiJson() : null,
        usePrecisionTag: state.groupSpec.isValid ? true : null,
      );
      revision = updated.revision;

      var detail = await _collectionRepository.fetchCollection(
        storeId: storeId,
        listingId: listingId,
      );
      revision = detail.revision;
      _setPublishProgress(emit, 0.15);

      final mainIds =
          detail.mainGroupPhotos
              .map((p) => p.id?.trim() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();

      // Create subgroups for Precise/Standalone items still sitting in main.
      final createCandidates =
          state.items
              .where(
                (item) =>
                    (item.tag == BulkItemTag.precise ||
                        item.tag == BulkItemTag.standalone) &&
                    mainIds.contains(item.id),
              )
              .toList();

      // PATCH existing Precise/Standalone subgroups when their items were edited.
      final updateCandidates =
          state.items
              .where((item) {
                final subId = item.subGroupId?.trim() ?? '';
                return (item.tag == BulkItemTag.precise ||
                        item.tag == BulkItemTag.standalone) &&
                    subId.isNotEmpty &&
                    !mainIds.contains(item.id);
              })
              .toList();

      AppLog.d(
        _editTag,
        'saveEdit mainIds=${mainIds.length} '
        'createCandidates=${createCandidates.length} '
        'updateCandidates=${updateCandidates.length}',
      );
      for (final item in createCandidates) {
        AppLog.d(_editTag, '  create ${_itemBrief(item)}');
      }
      for (final item in updateCandidates) {
        AppLog.d(_editTag, '  update ${_itemBrief(item)}');
      }

      final createClusters = <String, List<BulkUploadItem>>{};
      for (final item in createCandidates) {
        createClusters
            .putIfAbsent(_precisionClusterKey(item), () => [])
            .add(item);
      }

      final updateClusters = <String, List<BulkUploadItem>>{};
      for (final item in updateCandidates) {
        final subId = item.subGroupId!.trim();
        updateClusters.putIfAbsent(subId, () => []).add(item);
      }

      AppLog.d(_editTag, 'saveEdit createClusters=${createClusters.length}');
      AppLog.d(_editTag, 'saveEdit updateClusters=${updateClusters.length}');

      final editOps = createClusters.length + updateClusters.length;
      var editDone = 0;
      void bumpEditProgress() {
        editDone++;
        if (editOps <= 0) return;
        _setPublishProgress(emit, 0.15 + 0.8 * (editDone / editOps));
      }

      var subIndex = 1;
      for (final entry in createClusters.entries) {
        final photoIds =
            entry.value
                .map((item) => item.id.trim())
                .where((id) => id.isNotEmpty && mainIds.contains(id))
                .toList();
        if (photoIds.isEmpty) continue;
        final clusterSpec = entry.value.first.spec;
        if (!clusterSpec.isValid) {
          AppLog.d(
            _editTag,
            'SKIP create ${entry.key} invalid_spec photos=${photoIds.length}',
          );
          bumpEditProgress();
          continue;
        }

        final label = _clusterDisplayName(
          items: entry.value,
          groupTitle: groupTitle,
          subIndex: subIndex,
          isStandalone: entry.value.every(
            (item) => item.tag == BulkItemTag.standalone,
          ),
        );

        try {
          AppLog.d(
            _editTag,
            'createSubGroup name=$label photos=${photoIds.length} '
            'ids=${photoIds.join(',')}',
          );
          await _collectionRepository.createSubGroup(
            storeId: storeId,
            listingId: listingId,
            name: label,
            tag: clusterSpec.category,
            photoIds: photoIds,
            revision: revision,
            specifications: clusterSpec.toApiJson(),
            usePrecisionTag: true,
          );
          detail = await _collectionRepository.fetchCollection(
            storeId: storeId,
            listingId: listingId,
          );
          revision = detail.revision;
          mainIds
            ..clear()
            ..addAll(
              detail.mainGroupPhotos
                  .map((p) => p.id?.trim() ?? '')
                  .where((id) => id.isNotEmpty),
            );
          AppLog.d(
            _editTag,
            'createSubGroup OK name=$label revision=$revision '
            'mainLeft=${mainIds.length}',
          );
        } catch (e) {
          AppLog.e(_editTag, 'edit createSubGroup failed for $label', e);
        }
        bumpEditProgress();
        subIndex++;
      }

      for (final entry in updateClusters.entries) {
        final subGroupId = entry.key;
        final clusterSpec = entry.value.first.spec;
        if (!clusterSpec.isValid) {
          AppLog.d(
            _editTag,
            'SKIP update $subGroupId invalid_spec '
            'photos=${entry.value.length}',
          );
          bumpEditProgress();
          continue;
        }

        final knownName =
            state.knownSubGroups
                .where((s) => s.id.trim() == subGroupId)
                .map((s) => s.name.trim())
                .firstWhere((n) => n.isNotEmpty, orElse: () => '');
        final customName =
            entry.value
                .map((item) => item.customTitle.trim())
                .firstWhere((t) => t.isNotEmpty, orElse: () => '');
        final label =
            customName.isNotEmpty
                ? customName
                : (knownName.isNotEmpty ? knownName : 'Precise');

        try {
          AppLog.d(
            _editTag,
            'updateSubGroup id=$subGroupId name=$label '
            'photos=${entry.value.length}',
          );
          await _collectionRepository.updateSubGroup(
            storeId: storeId,
            listingId: listingId,
            subGroupId: subGroupId,
            revision: revision,
            name: label,
            tag: clusterSpec.category,
            specifications: clusterSpec.toApiJson(),
            usePrecisionTag: true,
          );
          detail = await _collectionRepository.fetchCollection(
            storeId: storeId,
            listingId: listingId,
          );
          revision = detail.revision;
          AppLog.d(
            _editTag,
            'updateSubGroup OK id=$subGroupId revision=$revision',
          );
        } catch (e) {
          AppLog.e(_editTag, 'edit updateSubGroup failed for $subGroupId', e);
        }
        bumpEditProgress();
      }

      _setPublishProgress(emit, 1);

      detail = await _collectionRepository.fetchCollection(
        storeId: storeId,
        listingId: listingId,
      );
      final product = CatalogUiMapper.detailToProduct(detail);

      AppLog.d(
        _editTag,
        'Saved edit collection $listingId photos=${detail.photoCount} '
        'subs=${detail.subGroups.length}',
      );

      emit(
        state.copyWith(
          isPublishing: false,
          publishProgress: 0,
          revision: detail.revision,
          publishedProduct: product,
          publishedRevision: detail.revision,
          publishedApiTag: detail.tag,
          shouldPopWithResult: true,
          isPublished: false,
        ),
      );
    } catch (e) {
      AppLog.e(_editTag, 'Bulk edit save failed', e);
      emit(
        state.copyWith(
          isPublishing: false,
          publishProgress: 0,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  /// Upload locally edited photos (crop/draw/text) and remove the old remote
  /// photo ids. Remaps [BulkUploadItem.id] to the new catalog photo ids so
  /// later subgroup create/update still matches `mainGroupPhotos`.
  Future<int> _syncReplacedEditPhotos(
    Emitter<BulkUploadState> emit, {
    required String storeId,
    required String listingId,
    required int revision,
  }) async {
    final replaced =
        state.items
            .where(
              (item) =>
                  item.imagePath.trim().isNotEmpty &&
                  !ProductImagePaths.isNetwork(item.imagePath) &&
                  File(item.imagePath).existsSync(),
            )
            .toList(growable: false);
    if (replaced.isEmpty) return revision;

    AppLog.d(
      _editTag,
      'syncReplacedPhotos count=${replaced.length} '
      'ids=${replaced.map((e) => e.id).join(',')}',
    );

    var nextRevision = revision;
    var nextItems = List<BulkUploadItem>.from(state.items);
    var nextImages = List<GalleryImageItem>.from(state.images);

    for (final item in replaced) {
      final oldId = item.id.trim();
      final file = File(item.imagePath);
      if (oldId.isEmpty || !file.existsSync()) continue;

      var detail = await _collectionRepository.fetchCollection(
        storeId: storeId,
        listingId: listingId,
      );
      nextRevision = detail.revision;
      final beforeIds =
          detail.photos
              .map((p) => p.id?.trim() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();

      // Add first so the collection never drops below 1 photo.
      final uploadBatch = await _directUpload.prepareAndUpload(
        storeId: storeId,
        localPaths: [item.imagePath],
      );
      if (uploadBatch.allFailed) {
        throw CatalogApiException(
          statusCode: 400,
          code: 'NO_VALID_PHOTOS',
          message: 'Edited photo could not be uploaded.',
        );
      }
      final added = await _collectionRepository.appendUploadedPhotos(
        storeId: storeId,
        listingId: listingId,
        photos: uploadBatch.successful,
        revision: nextRevision,
      );
      nextRevision = added.revision;

      detail = await _collectionRepository.fetchCollection(
        storeId: storeId,
        listingId: listingId,
      );
      nextRevision = detail.revision;

      String? newId;
      for (final photo in detail.photos.reversed) {
        final id = photo.id?.trim() ?? '';
        if (id.isNotEmpty && !beforeIds.contains(id)) {
          newId = id;
          break;
        }
      }
      if (newId == null || newId.isEmpty) {
        AppLog.d(
          _editTag,
          'WARN syncReplacedPhotos no_new_id for old=$oldId — skip delete',
        );
        continue;
      }

      var newUrl = item.imagePath;
      for (final photo in detail.photos) {
        if ((photo.id?.trim() ?? '') == newId && photo.url.trim().isNotEmpty) {
          newUrl = photo.url.trim();
          break;
        }
      }

      // Keep Precise/Standalone membership when the original lived in a sub-group.
      final subId = item.subGroupId?.trim() ?? '';
      final inExistingSub =
          subId.isNotEmpty && !subId.startsWith('local_');
      if (inExistingSub) {
        try {
          final moved = await _collectionRepository.movePhotos(
            storeId: storeId,
            listingId: listingId,
            photoIds: [newId],
            source: const <String, dynamic>{'type': 'main'},
            destination: <String, dynamic>{
              'type': 'existing_subgroup',
              'targetSubGroupId': subId,
            },
            revision: nextRevision,
          );
          nextRevision = moved.revision;
        } catch (e) {
          AppLog.e(
            _editTag,
            'syncReplacedPhotos move to sub=$subId failed',
            e,
          );
        }
      }

      if (beforeIds.contains(oldId)) {
        final deleted = await _collectionRepository.deletePhotos(
          storeId: storeId,
          listingId: listingId,
          photoIds: [oldId],
          revision: nextRevision,
        );
        nextRevision = deleted.revision;
      }

      nextItems = [
        for (final entry in nextItems)
          entry.id == oldId
              ? entry.copyWith(id: newId, imagePath: newUrl)
              : entry,
      ];
      nextImages = [
        for (final image in nextImages)
          if (image.id == oldId)
            GalleryImageItem(
              id: newId,
              filePath: newUrl,
              assetId: newId,
              isPlaceholder: false,
            )
          else
            image,
      ];

      AppLog.d(_editTag, 'syncReplacedPhotos OK old=$oldId → new=$newId');
    }

    emit(
      state.copyWith(
        items: nextItems,
        images: nextImages,
        revision: nextRevision,
      ),
    );
    return nextRevision;
  }

  /// Name for a new Precise/Standalone cluster: custom title → known sub name →
  /// `{groupTitle} precise|standalone {n}`.
  String _clusterDisplayName({
    required List<BulkUploadItem> items,
    required String groupTitle,
    required int subIndex,
    required bool isStandalone,
  }) {
    final custom =
        items
            .map((item) => item.customTitle.trim())
            .firstWhere((t) => t.isNotEmpty, orElse: () => '');
    if (custom.isNotEmpty) return custom;

    final knownName =
        items
            .map((item) => item.subGroupId?.trim() ?? '')
            .where((id) => id.isNotEmpty)
            .map((id) {
              for (final sub in state.knownSubGroups) {
                if (sub.id == id) return sub.name.trim();
              }
              return '';
            })
            .firstWhere((name) => name.isNotEmpty, orElse: () => '');
    if (knownName.isNotEmpty) return knownName;

    final prefix = groupTitle.trim().isEmpty ? 'Item' : groupTitle.trim();
    return isStandalone
        ? '$prefix standalone $subIndex'
        : '$prefix precise $subIndex';
  }

  Future<void> _publishCreate(
    Emitter<BulkUploadState> emit, {
    required String storeId,
  }) async {
    final photoFiles = <File>[
      for (final item in state.items) File(item.imagePath),
    ];
    try {
      await _assertPhotoSizes(photoFiles);
    } catch (e) {
      emit(
        state.copyWith(errorMessage: CatalogErrorMapper.toUserMessage(e)),
      );
      return;
    }

    emit(
      state.copyWith(
        isPublishing: true,
        publishProgress: 0,
        isSelectMode: false,
        selectedItemIds: const [],
        clearError: true,
      ),
    );

    try {
      final groupTitle = state.groupTitle.trim();
      final apiTag = _apiTag(state.tags);
      final description = state.description.trim();
      final totalPhotos = photoFiles.length;

      final uploadBatch = await _directUpload.prepareAndUpload(
        storeId: storeId,
        localPaths: [for (final item in state.items) item.imagePath],
        onProgress: (p) => _setPublishProgress(emit, p * 0.85),
      );
      if (uploadBatch.allFailed) {
        throw CatalogApiException(
          statusCode: 400,
          code: 'NO_VALID_PHOTOS',
          message: 'None of the photos could be uploaded.',
        );
      }

      final created = await _collectionRepository.createCollectionFromUploads(
        storeId: storeId,
        name: groupTitle,
        photos: uploadBatch.successful,
        tag: apiTag,
        description: description,
        specifications: state.groupSpec.toApiJson(),
        usePrecisionTag: true,
      );
      AppLog.d(
        _publishTag,
        'createCollectionFromUploads id=${created.id} '
        'revision=${created.revision} failed=${created.failedPhotos.length} '
        's3Failed=${uploadBatch.failedNames.length}',
      );
      _setPublishProgress(emit, 0.9);

      final failedPhotos = [
        ...created.failedPhotos,
        for (final name in uploadBatch.failedNames)
          FailedPhoto(
            fileName: name,
            code: 'S3_UPLOAD_FAILED',
            message: 'Upload failed',
          ),
      ];

      var detail = await _collectionRepository.fetchCollection(
        storeId: storeId,
        listingId: created.id,
      );
      var revision = detail.revision;

      final photos = detail.photos;
      if (photos.length < totalPhotos) {
        AppLog.d(
          _tag,
          'Photo count mismatch local=$totalPhotos '
          'remote=${photos.length} failed=${failedPhotos.length}',
        );
      }

      final successfulItems = <BulkUploadItem>[];
      final byPath = {
        for (final item in state.items) item.imagePath.trim(): item,
      };
      for (final uploaded in uploadBatch.successful) {
        final path = uploaded.localPath?.trim() ?? '';
        final item = path.isNotEmpty ? byPath[path] : null;
        if (item != null) successfulItems.add(item);
      }
      final mapItems =
          successfulItems.isNotEmpty ? successfulItems : state.items;

      final localToPhotoId = <String, String>{};
      for (var i = 0; i < mapItems.length && i < photos.length; i++) {
        final photoId = photos[i].id?.trim() ?? '';
        if (photoId.isNotEmpty) {
          localToPhotoId[mapItems[i].id] = photoId;
        }
      }

      final subgroupCandidates =
          mapItems
              .where(
                (item) =>
                    item.tag == BulkItemTag.precise ||
                    item.tag == BulkItemTag.standalone,
              )
              .toList();

      AppLog.d(
        _publishTag,
        'publishCreate mappedPhotos=${localToPhotoId.length} '
        'subgroupCandidates=${subgroupCandidates.length}',
      );
      for (final item in subgroupCandidates) {
        AppLog.d(_publishTag, '  candidate ${_itemBrief(item)}');
      }

      final clusters = <String, List<BulkUploadItem>>{};
      for (final item in subgroupCandidates) {
        clusters.putIfAbsent(_precisionClusterKey(item), () => []).add(item);
      }
      AppLog.d(_publishTag, 'publishCreate clusters=${clusters.length}');

      final clusterCount = clusters.length;
      var clusterDone = 0;
      void bumpClusterProgress() {
        clusterDone++;
        if (clusterCount <= 0) return;
        _setPublishProgress(emit, 0.9 + 0.1 * (clusterDone / clusterCount));
      }

      var subIndex = 1;
      for (final entry in clusters.entries) {
        final photoIds =
            entry.value
                .map((item) => localToPhotoId[item.id])
                .whereType<String>()
                .where((id) => id.isNotEmpty)
                .toList();
        if (photoIds.isEmpty) {
          AppLog.d(_publishTag, 'SKIP cluster ${entry.key} no_photo_ids');
          bumpClusterProgress();
          continue;
        }
        final clusterSpec = entry.value.first.spec;
        if (!clusterSpec.isValid) {
          AppLog.d(
            _publishTag,
            'SKIP cluster ${entry.key} invalid_spec photos=${photoIds.length}',
          );
          bumpClusterProgress();
          continue;
        }

        final isStandaloneCluster = entry.value.every(
          (item) => item.tag == BulkItemTag.standalone,
        );
        final knownName =
            entry.value
                .map((item) => item.subGroupId?.trim() ?? '')
                .where((id) => id.isNotEmpty)
                .map((id) {
                  for (final sub in state.knownSubGroups) {
                    if (sub.id == id) return sub.name.trim();
                  }
                  return '';
                })
                .firstWhere((name) => name.isNotEmpty, orElse: () => '');
        final label =
            knownName.isNotEmpty
                ? knownName
                : (isStandaloneCluster
                    ? '$groupTitle standalone $subIndex'
                    : '$groupTitle precise $subIndex');

        try {
          AppLog.d(
            _publishTag,
            'createSubGroup name=$label photos=${photoIds.length} '
            'ids=${photoIds.join(',')}',
          );
          await _collectionRepository.createSubGroup(
            storeId: storeId,
            listingId: created.id,
            name: label,
            tag: clusterSpec.category,
            photoIds: photoIds,
            revision: revision,
            specifications: clusterSpec.toApiJson(),
            usePrecisionTag: true,
          );
          detail = await _collectionRepository.fetchCollection(
            storeId: storeId,
            listingId: created.id,
          );
          revision = detail.revision;
          AppLog.d(
            _publishTag,
            'createSubGroup OK name=$label revision=$revision',
          );
        } catch (e) {
          AppLog.e(_publishTag, 'createSubGroup failed for $label', e);
        }
        bumpClusterProgress();
        subIndex++;
      }

      _setPublishProgress(emit, 1);

      StoreProduct product;
      try {
        detail = await _collectionRepository.fetchCollection(
          storeId: storeId,
          listingId: created.id,
        );
        product = CatalogUiMapper.detailToProduct(detail);
      } catch (_) {
        product = StoreProduct(
          id: created.id,
          title: created.name.isNotEmpty ? created.name : groupTitle,
          description:
              created.description.isNotEmpty
                  ? created.description
                  : description,
          tags: [
            if (created.tag.isNotEmpty) created.tag,
            ...state.tags.where((t) => t != created.tag),
            state.groupSpec.category,
            ...state.groupSpec.metalType,
          ],
          imagePaths: state.items.map((e) => e.imagePath).toList(),
          canEdit: true,
          canDelete: true,
        );
      }

      final partialMessage =
          failedPhotos.isNotEmpty
              ? CatalogErrorMapper.failedPhotosSummary(failedPhotos)
              : null;

      AppLog.d(
        _publishTag,
        'Published bulk collection ${created.id} '
        'photos=${detail.photoCount} subs=${detail.subGroups.length} '
        'partialFailed=${failedPhotos.length}',
      );

      emit(
        state.copyWith(
          isPublishing: false,
          publishProgress: 0,
          isPublished: true,
          publishedProduct: product,
          publishedRevision: detail.revision,
          publishedApiTag: detail.tag.isNotEmpty ? detail.tag : created.tag,
          errorMessage: partialMessage,
        ),
      );
    } catch (e) {
      AppLog.e(_publishTag, 'Bulk publish failed', e);
      emit(
        state.copyWith(
          isPublishing: false,
          publishProgress: 0,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  void _setPublishProgress(Emitter<BulkUploadState> emit, double value) {
    emit(
      state.copyWith(
        isPublishing: true,
        publishProgress: value.clamp(0.0, 1.0),
      ),
    );
  }

  Future<void> _assertPhotoSizes(List<File> files) async {
    for (final file in files) {
      final length = await file.length();
      if (length <= 0 || length > _maxPhotoBytes) {
        throw CatalogApiException(
          statusCode: 400,
          code: 'IMAGE_TOO_LARGE',
          message: 'Image exceeds size limit',
        );
      }
    }
  }

  Future<void> _publishTitleOnly(
    Emitter<BulkUploadState> emit, {
    required String storeId,
  }) async {
    final photoFiles = <File>[
      for (final item in state.items) File(item.imagePath),
    ];
    try {
      await _assertPhotoSizes(photoFiles);
    } catch (e) {
      emit(
        state.copyWith(errorMessage: CatalogErrorMapper.toUserMessage(e)),
      );
      return;
    }

    emit(
      state.copyWith(
        isPublishing: true,
        publishProgress: 0,
        isSelectMode: false,
        selectedItemIds: const [],
        clearError: true,
      ),
    );

    try {
      final groupTitle = state.groupTitle.trim();
      final apiTag = _apiTag(state.tags);
      final description = state.description.trim();
      final uploadBatch = await _directUpload.prepareAndUpload(
        storeId: storeId,
        localPaths: [for (final item in state.items) item.imagePath],
        onProgress: (p) => _setPublishProgress(emit, p),
      );
      if (uploadBatch.allFailed) {
        throw CatalogApiException(
          statusCode: 400,
          code: 'NO_VALID_PHOTOS',
          message: 'None of the photos could be uploaded.',
        );
      }

      final created = await _collectionRepository.createCollectionFromUploads(
        storeId: storeId,
        name: groupTitle,
        photos: uploadBatch.successful,
        tag: apiTag,
        description: description,
      );
      AppLog.d(
        _publishTag,
        'titleOnly createCollectionFromUploads id=${created.id} '
        'revision=${created.revision} failed=${created.failedPhotos.length}',
      );

      var revision = created.revision;
      final failedPhotos = [
        ...created.failedPhotos,
        for (final name in uploadBatch.failedNames)
          FailedPhoto(
            fileName: name,
            code: 'S3_UPLOAD_FAILED',
            message: 'Upload failed',
          ),
      ];

      StoreProduct product;
      try {
        final detail = await _collectionRepository.fetchCollection(
          storeId: storeId,
          listingId: created.id,
        );
        product = CatalogUiMapper.detailToProduct(detail);
        revision = detail.revision;
      } catch (_) {
        product = StoreProduct(
          id: created.id,
          title: created.name.isNotEmpty ? created.name : groupTitle,
          description:
              created.description.isNotEmpty
                  ? created.description
                  : description,
          tags: [
            if (created.tag.isNotEmpty) created.tag,
            ...state.tags.where((t) => t != created.tag),
          ],
          imagePaths: state.items.map((e) => e.imagePath).toList(),
          canEdit: true,
          canDelete: true,
        );
      }

      final partialMessage =
          failedPhotos.isNotEmpty
              ? CatalogErrorMapper.failedPhotosSummary(failedPhotos)
              : null;

      AppLog.d(
        _publishTag,
        'Published title-only collection ${created.id} '
        'photos=${product.imagePaths.length} failed=${failedPhotos.length}',
      );

      emit(
        state.copyWith(
          isPublishing: false,
          publishProgress: 0,
          isPublished: true,
          publishedProduct: product,
          publishedRevision: revision,
          publishedApiTag: created.tag,
          errorMessage: partialMessage,
        ),
      );
    } catch (e) {
      AppLog.e(_publishTag, 'Title-only publish failed', e);
      emit(
        state.copyWith(
          isPublishing: false,
          publishProgress: 0,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  /// API accepts a single tag string (max 40). Join UI chips when possible.
  String _apiTag(List<String> tags) {
    if (tags.isEmpty) return '';
    final joined =
        tags.map((t) => t.trim()).where((t) => t.isNotEmpty).join(', ');
    if (joined.length <= 40) return joined;
    return joined.substring(0, 40).trim();
  }

  void _onClearPublished(
    BulkUploadClearPublished event,
    Emitter<BulkUploadState> emit,
  ) {
    emit(state.copyWith(clearPublished: true));
  }

  void _onRestartRequested(
    BulkUploadRestartRequested event,
    Emitter<BulkUploadState> emit,
  ) {
    emit(state.copyWith(shouldCloseFlow: true));
  }

  void _onClearCloseFlow(
    BulkUploadClearCloseFlow event,
    Emitter<BulkUploadState> emit,
  ) {
    emit(state.copyWith(clearShouldCloseFlow: true));
  }

  void _onClearMessage(
    BulkUploadClearMessage event,
    Emitter<BulkUploadState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }

  void _onClearShouldPopWithResult(
    BulkUploadClearShouldPopWithResult event,
    Emitter<BulkUploadState> emit,
  ) {
    emit(state.copyWith(clearShouldPopWithResult: true));
  }
}
