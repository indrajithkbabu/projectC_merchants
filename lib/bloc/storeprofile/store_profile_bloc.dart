import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:project_c/bloc/team/team_bloc.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/catalog_ui_mapper.dart';
import 'package:project_c/helper/device_contact_names.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/models/catalog/import_models.dart';
import 'package:project_c/models/catalog/store_member_models.dart';
import 'package:project_c/models/pending_product_upload.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/services/product_upload_coordinator.dart';
import 'package:project_c/services/store_products_prefetcher.dart';
import 'package:project_c/storage/store_meta_cache.dart';
import 'package:project_c/storage/store_products_cache.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';
import 'package:project_c/webservice/import/import_repository.dart';
import 'package:project_c/webservice/store/store_repository.dart';
import 'package:project_c/webservice/store/store_request.dart';

part 'store_profile_event.dart';
part 'store_profile_state.dart';

class StoreProfileBloc extends Bloc<StoreProfileEvent, StoreProfileState> {
  StoreProfileBloc({
    required String storeName,
    required List<TeamMember> members,
    List<StoreProduct>? products,
    bool isOwnStore = true,
    String? storeId,
    String? storeLink,
    String? coverImageUrl,
    int avatarColor = 0xFF2AABEE,
    CollectionRepository? collectionRepository,
    StoreRepository? storeRepository,
    ImportRepository? importRepository,
    CatalogSession? session,
    ProductUploadCoordinator? uploadCoordinator,
  }) : _collectionRepository =
           collectionRepository ??
           ServiceLocator.get<CollectionRepository>(),
       _storeRepository =
           storeRepository ?? ServiceLocator.get<StoreRepository>(),
       _importRepository =
           importRepository ?? ServiceLocator.get<ImportRepository>(),
       _session = session ?? ServiceLocator.get<CatalogSession>(),
       _uploadCoordinator =
           uploadCoordinator ?? ServiceLocator.get<ProductUploadCoordinator>(),
       super(
         () {
           final id = storeId ?? (isOwnStore ? 'my_store' : 'other_store');
           final cachedProducts =
               StoreProductsCache.instance.readMemory(id) ??
               products ??
               const <StoreProduct>[];
           final cachedMeta = StoreMetaCache.instance.readMemory(id);
           final argCover = coverImageUrl?.trim() ?? '';
           final cachedCover = cachedMeta?.coverImageUrl.trim() ?? '';
           final cover =
               argCover.isNotEmpty
                   ? argCover
                   : (cachedCover.isNotEmpty ? cachedCover : '');
           final argName =
               storeName.trim().isEmpty ? 'Your Store' : storeName.trim();
           final cachedName = cachedMeta?.storeName.trim() ?? '';
           final cachedLink = cachedMeta?.storeLink.trim() ?? '';
           final coord =
               uploadCoordinator ??
               ServiceLocator.get<ProductUploadCoordinator>();
           final activeUploads = coord.pendingForStore(id);
           final hidden = coord.inFlightListingIdsForStore(id);
           final visibleCached = List<StoreProduct>.from(
             hidden.isEmpty
                 ? cachedProducts
                 : [
                   for (final p in cachedProducts)
                     if (!hidden.contains(p.id)) p,
                 ],
           )..sort((a, b) => b.id.compareTo(a.id));
           return StoreProfileState(
             storeName: cachedName.isNotEmpty ? cachedName : argName,
             members: members,
             products: visibleCached,
             productsDetailed: visibleCached,
             isOwnStore: isOwnStore,
             viewerHasOwnStore: _hasOwnStoreId(
               session ?? ServiceLocator.get<CatalogSession>(),
             ),
             storeId: id,
             avatarColor: avatarColor,
             overrideStoreLink:
                 cachedLink.isNotEmpty ? cachedLink : storeLink,
             coverImageUrl: cover,
             storeImages: cachedMeta?.storeImages ?? const [],
             currentUserId:
                 (session ?? ServiceLocator.get<CatalogSession>()).profile?.id,
             isLoadingProducts: visibleCached.isEmpty && activeUploads.isEmpty,
             isLoadingMembers: isOwnStore,
             isLoadingStoreMeta: cachedMeta == null,
             // Survive leave/return while create upload is still in flight.
             pendingUploads: activeUploads,
           );
         }(),
       ) {
    on<StoreProfileAddProductsPressed>(_onAddProductsPressed);
    on<StoreProfileProductPublished>(_onProductPublished);
    on<StoreProfileProductUpdated>(_onProductUpdated);
    on<StoreProfileProductDeleted>(_onProductDeleted);
    on<StoreProfileProductsDeleted>(_onProductsDeleted);
    on<StoreProfileProductsReplaced>(_onProductsReplaced);
    on<StoreProfileProductsImported>(_onProductsImported);
    on<StoreProfileImportPressed>(_onImportPressed);
    on<StoreProfileSharePressed>(_onSharePressed);
    on<StoreProfileMorePressed>(_onMorePressed);
    on<StoreProfileQuickAddPressed>(_onQuickAddPressed);
    on<StoreProfileClearMessage>(_onClearMessage);
    on<StoreProfileLoadCollections>(_onLoadCollections);
    on<StoreProfileQuietRefreshCollections>(_onQuietRefreshCollections);
    on<StoreProfileLoadMembers>(_onLoadMembers);
    on<StoreProfileLoadImportRequestCount>(_onLoadImportRequestCount);
    on<StoreProfileLoadStoreMeta>(_onLoadStoreMeta);
    on<StoreProfileAppendImagesRequested>(_onAppendImagesRequested);
    on<StoreProfileDeleteImageRequested>(_onDeleteImageRequested);
    on<StoreProfileProbeImportAvailability>(_onProbeImportAvailability);
    on<StoreProfilePendingUploadStarted>(_onPendingUploadStarted);
    on<StoreProfilePendingUploadSucceeded>(_onPendingUploadSucceeded);
    on<StoreProfilePendingUploadFailed>(_onPendingUploadFailed);
    on<StoreProfileHideInFlightListing>(_onHideInFlightListing);
    _uploadSub = _uploadCoordinator.events.listen(_onUploadCoordinatorEvent);
    add(const StoreProfileLoadStoreMeta());
    add(const StoreProfileLoadCollections());
    if (isOwnStore) {
      add(const StoreProfileLoadMembers());
      add(const StoreProfileLoadImportRequestCount());
    }
  }

  final CollectionRepository _collectionRepository;
  final StoreRepository _storeRepository;
  final ImportRepository _importRepository;
  final CatalogSession _session;
  final ProductUploadCoordinator _uploadCoordinator;
  StreamSubscription<ProductUploadEvent>? _uploadSub;
  final Set<String> _finishedUploadIds = <String>{};
  static const _tag = 'StoreProfileBloc';

  void _onUploadCoordinatorEvent(ProductUploadEvent event) {
    if (event.storeId != state.storeId) return;
    switch (event) {
      case ProductUploadStarted(:final pendingId, :final storeId, :final title, :final photoCount):
        add(
          StoreProfilePendingUploadStarted(
            PendingProductUpload(
              id: pendingId,
              storeId: storeId,
              title: title,
              photoCount: photoCount,
            ),
          ),
        );
      case ProductUploadListingBound(:final pendingId, :final listingId):
        add(
          StoreProfileHideInFlightListing(
            pendingId: pendingId,
            listingId: listingId,
          ),
        );
      case ProductUploadSucceeded(
        :final pendingId,
        :final product,
        :final partialMessage,
      ):
        add(
          StoreProfilePendingUploadSucceeded(
            pendingId: pendingId,
            product: product,
            partialMessage: partialMessage,
          ),
        );
      case ProductUploadFailed(:final pendingId, :final message):
        add(
          StoreProfilePendingUploadFailed(
            pendingId: pendingId,
            message: message,
          ),
        );
    }
  }
  static bool _hasOwnStoreId(CatalogSession session) {
    final id = session.ownStoreId;
    return id != null && id.isNotEmpty;
  }

  static const _avatarPalette = <int>[
    0xFF2AABEE,
    0xFFE74C3C,
    0xFF3498DB,
    0xFF2ECC71,
    0xFFE67E22,
    0xFF9B59B6,
    0xFF1ABC9C,
    0xFFE91E63,
  ];

  Future<void> _onLoadCollections(
    StoreProfileLoadCollections event,
    Emitter<StoreProfileState> emit,
  ) async {
    final storeId = state.storeId;
    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      emit(state.copyWith(isLoadingProducts: false));
      return;
    }

    // Disk/memory first — UI always paints from cache.
    final disk = await StoreProductsCache.instance.read(storeId);
    if (emit.isDone) return;
    if (disk != null && disk.isNotEmpty) {
      await _emitProductsFromCache(
        emit,
        storeId,
        isLoadingProducts: false,
      );
      if (!state.isOwnStore && state.canImport) {
        add(const StoreProfileProbeImportAvailability());
      }
      add(const StoreProfileQuietRefreshCollections());
      return;
    }

    // Prefer warm data started on store tap / listing prefetch.
    final warm = await StoreProductsPrefetcher.instance.ensure(storeId);
    if (emit.isDone) return;

    if (warm.isNotEmpty) {
      await _emitProductsFromCache(
        emit,
        storeId,
        fallback: warm,
        isLoadingProducts: false,
      );
      if (!state.isOwnStore && state.canImport) {
        add(const StoreProfileProbeImportAvailability());
      }
      add(const StoreProfileQuietRefreshCollections());
      return;
    }

    // True cold path (no prefetch, empty cache) — shimmer once.
    emit(state.copyWith(isLoadingProducts: true, clearError: true));
    try {
      final products = await _fetchEnrichedProducts(storeId);
      if (emit.isDone) return;
      await _commitProducts(emit, storeId, products, isLoadingProducts: false);
      AppLog.d(_tag, 'Loaded ${products.length} collections (cold load)');
      if (!state.isOwnStore && state.canImport) {
        add(const StoreProfileProbeImportAvailability());
      }
    } catch (e) {
      AppLog.e(_tag, 'Collections load failed', e);
      emit(
        state.copyWith(
          isLoadingProducts: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _onQuietRefreshCollections(
    StoreProfileQuietRefreshCollections event,
    Emitter<StoreProfileState> emit,
  ) async {
    final storeId = state.storeId;
    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      return;
    }
    try {
      final products = await _fetchEnrichedProducts(storeId);
      if (emit.isDone) return;
      final previous = state.products;
      final visible = _withoutInFlightUploads(products);
      await StoreProductsCache.instance.write(storeId, visible);
      final cached =
          StoreProductsCache.instance.readMemory(storeId) ?? visible;
      if (_sameGridVisual(previous, cached)) return;
      emit(
        state.copyWith(
          products: cached,
          productsDetailed: cached,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Quiet collections refresh failed', e);
    }
  }

  Future<List<StoreProduct>> _fetchEnrichedProducts(String storeId) async {
    final page = await _collectionRepository.listCollections(
      storeId: storeId,
      limit: 50,
    );
    // Skip mid-upload listings so partial photo grids never enter cache/UI.
    final hidden = _uploadCoordinator.inFlightListingIdsForStore(storeId);
    final summaries = [
      for (final summary in page.items)
        if (!hidden.contains(summary.id)) summary,
    ];
    final products = await Future.wait([
      for (final summary in summaries)
        _productFromSummary(storeId: storeId, summary: summary),
    ]);
    // listCollections is oldest-first; grid must show newest upload first.
    final ordered = _newestFirst(products);
    await _precacheGridTiles(ordered);
    return ordered;
  }

  /// Newest listing first (Mongo-style ids are time-sortable).
  List<StoreProduct> _newestFirst(List<StoreProduct> products) {
    if (products.length <= 1) return products;
    return List<StoreProduct>.from(products)
      ..sort((a, b) => b.id.compareTo(a.id));
  }

  /// Drop collections still receiving append batches (pending shimmer covers them).
  List<StoreProduct> _withoutInFlightUploads(List<StoreProduct> products) {
    final hidden = _uploadCoordinator.inFlightListingIdsForStore(state.storeId);
    if (hidden.isEmpty) return products;
    return [
      for (final product in products)
        if (!hidden.contains(product.id)) product,
    ];
  }

  /// Precache every tile the profile collage will show so paint is stable.
  Future<void> _precacheGridTiles(List<StoreProduct> products) {
    return CatalogImageCache.precacheUrls([
      for (final product in products) ...product.imagePaths,
    ]);
  }

  bool _sameGridVisual(List<StoreProduct> a, List<StoreProduct> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].title != b[i].title) return false;
      final ap = a[i].imagePaths;
      final bp = b[i].imagePaths;
      if (ap.length != bp.length) return false;
      for (var j = 0; j < ap.length; j++) {
        if (ap[j] != bp[j]) return false;
      }
    }
    return true;
  }

  Future<StoreProduct> _productFromSummary({
    required String storeId,
    required CollectionSummary summary,
  }) async {
    final cover = CatalogUiMapper.summaryToProduct(summary);
    if (summary.photoCount <= 1) return cover;
    try {
      final detail = await _collectionRepository.fetchCollection(
        storeId: storeId,
        listingId: summary.id,
      );
      final detailed = CatalogUiMapper.detailToProduct(detail);
      // Keep list-cover URL first so primary tile stays cache-stable.
      final coverUrl = cover.primaryImagePath?.trim() ?? '';
      if (coverUrl.isEmpty) return detailed;
      final rest =
          detailed.imagePaths.where((p) => p.trim() != coverUrl).toList();
      return detailed.copyWith(imagePaths: [coverUrl, ...rest]);
    } catch (e) {
      AppLog.e(_tag, 'Collection detail enrich failed id=${summary.id}', e);
      return cover;
    }
  }

  /// Write API products → cache, then emit only what cache holds.
  Future<void> _commitProducts(
    Emitter<StoreProfileState> emit,
    String storeId,
    List<StoreProduct> products, {
    bool isLoadingProducts = false,
    String? infoMessage,
    bool clearDeletingProductId = false,
    bool clearError = false,
    List<PendingProductUpload>? pendingUploads,
  }) async {
    await StoreProductsCache.instance.write(storeId, products);
    await _emitProductsFromCache(
      emit,
      storeId,
      fallback: products,
      isLoadingProducts: isLoadingProducts,
      infoMessage: infoMessage,
      clearDeletingProductId: clearDeletingProductId,
      clearError: clearError,
      pendingUploads: pendingUploads,
    );
  }

  Future<void> _emitProductsFromCache(
    Emitter<StoreProfileState> emit,
    String storeId, {
    List<StoreProduct>? fallback,
    bool isLoadingProducts = false,
    String? infoMessage,
    bool clearDeletingProductId = false,
    bool clearError = false,
    List<PendingProductUpload>? pendingUploads,
  }) async {
    final cached =
        StoreProductsCache.instance.readMemory(storeId) ??
        fallback ??
        const <StoreProduct>[];
    final visible = List<StoreProduct>.from(_withoutInFlightUploads(cached))
      ..sort((a, b) => b.id.compareTo(a.id));
    if (emit.isDone) return;
    emit(
      state.copyWith(
        products: visible,
        productsDetailed: visible,
        isLoadingProducts: isLoadingProducts,
        infoMessage: infoMessage,
        clearDeletingProductId: clearDeletingProductId,
        clearError: clearError,
        pendingUploads: pendingUploads,
      ),
    );
  }

  /// Write store meta → cache, then emit only what cache holds.
  Future<void> _commitStoreMeta(
    Emitter<StoreProfileState> emit,
    String storeId,
    StoreMetaSnapshot snapshot, {
    bool isLoadingStoreMeta = false,
    bool isUpdatingStoreImages = false,
    String? infoMessage,
  }) async {
    await StoreMetaCache.instance.write(storeId, snapshot);
    final cover = snapshot.coverImageUrl.trim();
    if (cover.isNotEmpty) {
      await CatalogImageCache.precacheUrls([cover]);
    }
    await _emitStoreMetaFromCache(
      emit,
      storeId,
      fallback: snapshot,
      isLoadingStoreMeta: isLoadingStoreMeta,
      isUpdatingStoreImages: isUpdatingStoreImages,
      infoMessage: infoMessage,
    );
  }

  Future<void> _emitStoreMetaFromCache(
    Emitter<StoreProfileState> emit,
    String storeId, {
    StoreMetaSnapshot? fallback,
    bool isLoadingStoreMeta = false,
    bool isUpdatingStoreImages = false,
    String? infoMessage,
  }) async {
    final cached = StoreMetaCache.instance.readMemory(storeId) ?? fallback;
    if (cached == null || emit.isDone) return;
    final name = cached.storeName.trim();
    final link = cached.storeLink.trim();
    final cover = cached.coverImageUrl.trim();
    emit(
      state.copyWith(
        isLoadingStoreMeta: isLoadingStoreMeta,
        isUpdatingStoreImages: isUpdatingStoreImages,
        storeName: name.isNotEmpty ? name : state.storeName,
        overrideStoreLink: link.isNotEmpty ? link : state.overrideStoreLink,
        storeImages: cached.storeImages,
        coverImageUrl: cover.isNotEmpty ? cover : state.coverImageUrl,
        infoMessage: infoMessage,
      ),
    );
  }

  Future<void> _onLoadMembers(
    StoreProfileLoadMembers event,
    Emitter<StoreProfileState> emit,
  ) async {
    if (!state.isOwnStore) {
      emit(state.copyWith(isLoadingMembers: false));
      return;
    }
    final storeId = state.storeId;
    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      emit(state.copyWith(isLoadingMembers: false));
      return;
    }

    emit(
      state.copyWith(
        isLoadingMembers: true,
        currentUserId: _session.profile?.id ?? state.currentUserId,
        clearError: true,
      ),
    );
    try {
      final all = <StoreMember>[];
      String? cursor;
      do {
        final page = await _storeRepository.fetchMembers(
          storeId: storeId,
          limit: 50,
          cursor: cursor,
        );
        all.addAll(page.items);
        cursor = page.nextCursor;
      } while (cursor != null && cursor.isNotEmpty);

      final mapped = [
        for (var i = 0; i < all.length; i++) _mapMember(all[i], i),
      ];
      AppLog.d(_tag, 'Loaded ${mapped.length} store members');
      emit(
        state.copyWith(
          members: mapped,
          isLoadingMembers: false,
          currentUserId: _session.profile?.id ?? state.currentUserId,
        ),
      );

      // Quietly fill missing names from device contacts (no loader).
      final enrichedApi = await DeviceContactNames.enrichMembers(all);
      if (emit.isDone) return;
      final enrichedMapped = [
        for (var i = 0; i < enrichedApi.length; i++)
          _mapMember(enrichedApi[i], i),
      ];
      emit(
        state.copyWith(
          members: enrichedMapped,
          currentUserId: _session.profile?.id ?? state.currentUserId,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Members load failed', e);
      emit(
        state.copyWith(
          isLoadingMembers: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _onLoadImportRequestCount(
    StoreProfileLoadImportRequestCount event,
    Emitter<StoreProfileState> emit,
  ) async {
    if (!state.isOwnStore) return;
    final storeId = state.storeId;
    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      return;
    }
    try {
      var pending = 0;
      String? cursor;
      do {
        final page = await _importRepository.listStoreRequests(
          storeId: storeId,
          direction: 'incoming',
          limit: 50,
          cursor: cursor,
        );
        pending += page.items.where((r) => r.isPending).length;
        cursor = page.nextCursor;
      } while (cursor != null && cursor.isNotEmpty);
      if (emit.isDone) return;
      AppLog.d(_tag, 'Pending incoming import requests=$pending');
      emit(state.copyWith(pendingImportRequestCount: pending));
    } catch (e) {
      // Badge is secondary; do not interrupt the profile with a snackbar.
      AppLog.e(_tag, 'Import request count failed', e);
    }
  }

  Future<void> _onProbeImportAvailability(
    StoreProfileProbeImportAvailability event,
    Emitter<StoreProfileState> emit,
  ) async {
    if (state.isOwnStore || !state.canImport) return;
    final products = state.products;
    if (products.isEmpty) return;

    try {
      final availability = <String, ListingImportAvailability>{};
      final results = await Future.wait([
        for (final product in products)
          _importRepository
              .fetchTargets(listingId: product.id, limit: 50)
              .then((page) => (product.id, page.items)),
      ]);
      for (final (listingId, targets) in results) {
        availability[listingId] = listingAvailabilityFor(targets);
      }
      if (emit.isDone) return;
      AppLog.d(
        _tag,
        'Import availability probed for ${availability.length} listings',
      );
      emit(state.copyWith(listingAvailability: availability));
    } catch (e) {
      // Badges are secondary — never block profile.
      AppLog.e(_tag, 'Import availability probe failed', e);
    }
  }

  Future<void> _onLoadStoreMeta(
    StoreProfileLoadStoreMeta event,
    Emitter<StoreProfileState> emit,
  ) async {
    final storeId = state.storeId;
    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      emit(state.copyWith(isLoadingStoreMeta: false));
      return;
    }

    // Paint from disk/memory cache first; network only refreshes cache.
    final cached = await StoreMetaCache.instance.read(storeId);
    if (emit.isDone) return;
    if (cached != null) {
      final cover = cached.coverImageUrl.trim();
      if (cover.isNotEmpty) {
        unawaited(CatalogImageCache.precacheUrls([cover]));
      }
      await _emitStoreMetaFromCache(
        emit,
        storeId,
        fallback: cached,
        isLoadingStoreMeta: false,
      );
    } else if (state.coverImageUrl.trim().isNotEmpty) {
      unawaited(CatalogImageCache.precacheUrls([state.coverImageUrl]));
      emit(state.copyWith(isLoadingStoreMeta: true, clearError: true));
    } else {
      emit(state.copyWith(isLoadingStoreMeta: true, clearError: true));
    }

    try {
      final store = await _storeRepository.fetchStore(storeId);
      if (emit.isDone) return;
      AppLog.d(
        _tag,
        'Store meta loaded images=${store.images.length} '
        'cover=${store.coverImageUrl.isNotEmpty}',
      );
      await _commitStoreMeta(
        emit,
        storeId,
        StoreMetaSnapshot.fromCatalogStore(store),
        isLoadingStoreMeta: false,
      );
    } catch (e) {
      AppLog.e(_tag, 'Load store meta failed', e);
      emit(state.copyWith(isLoadingStoreMeta: false));
    }
  }

  Future<void> _onAppendImagesRequested(
    StoreProfileAppendImagesRequested event,
    Emitter<StoreProfileState> emit,
  ) async {
    if (!state.isOwnStore || state.isUpdatingStoreImages) return;
    final storeId = state.storeId;
    if (storeId.isEmpty || storeId == 'my_store') return;
    final remaining = StoreRequest.maxStoreImages - state.storeImages.length;
    if (remaining <= 0) {
      emit(
        state.copyWith(
          errorMessage: 'A store can have at most ${StoreRequest.maxStoreImages} showcase images.',
        ),
      );
      return;
    }
    final paths = event.imagePaths.take(remaining).toList();
    if (paths.isEmpty) return;
    emit(state.copyWith(isUpdatingStoreImages: true, clearError: true));
    try {
      final store = await _storeRepository.appendStoreImages(
        storeId: storeId,
        imageFiles: paths.map(File.new).toList(),
      );
      await _commitStoreMeta(
        emit,
        storeId,
        StoreMetaSnapshot.fromCatalogStore(store),
        isUpdatingStoreImages: false,
        infoMessage:
            event.imagePaths.length > remaining
                ? 'Only $remaining more photo(s) could be added.'
                : 'Store photos updated.',
      );
    } catch (e) {
      AppLog.e(_tag, 'Append store images failed', e);
      emit(
        state.copyWith(
          isUpdatingStoreImages: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _onDeleteImageRequested(
    StoreProfileDeleteImageRequested event,
    Emitter<StoreProfileState> emit,
  ) async {
    if (!state.isOwnStore || state.isUpdatingStoreImages) return;
    final storeId = state.storeId;
    final imageId = event.imageId.trim();
    if (storeId.isEmpty || storeId == 'my_store' || imageId.isEmpty) return;
    emit(state.copyWith(isUpdatingStoreImages: true, clearError: true));
    try {
      final store = await _storeRepository.deleteStoreImage(
        storeId: storeId,
        imageId: imageId,
      );
      await _commitStoreMeta(
        emit,
        storeId,
        StoreMetaSnapshot.fromCatalogStore(store),
        isUpdatingStoreImages: false,
        infoMessage: 'Store photo removed.',
      );
    } catch (e) {
      AppLog.e(_tag, 'Delete store image failed', e);
      emit(
        state.copyWith(
          isUpdatingStoreImages: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  TeamMember _mapMember(StoreMember member, int index) {
    return TeamMember(
      id: member.userId,
      name: member.displayName,
      handle: member.phone,
      phone: member.phone,
      avatarColor: _avatarPalette[index % _avatarPalette.length],
    );
  }

  void _onAddProductsPressed(
    StoreProfileAddProductsPressed event,
    Emitter<StoreProfileState> emit,
  ) {}

  Future<void> _onProductPublished(
    StoreProfileProductPublished event,
    Emitter<StoreProfileState> emit,
  ) async {
    final published = event.product.copyWith(
      canEdit: event.product.canEdit || state.isOwnStore,
      canDelete: event.product.canDelete || state.isOwnStore,
    );
    final next = [published, ...state.products];
    final storeId = state.storeId;
    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      emit(
        state.copyWith(
          products: next,
          productsDetailed: next,
          infoMessage: 'Product published to store.',
        ),
      );
      return;
    }
    await _commitProducts(
      emit,
      storeId,
      next,
      infoMessage: 'Product published to store.',
    );
    add(const StoreProfileQuietRefreshCollections());
  }

  Future<void> _onProductUpdated(
    StoreProfileProductUpdated event,
    Emitter<StoreProfileState> emit,
  ) async {
    final replacedId = event.replacedListingId?.trim();
    final updated = event.product.copyWith(
      canEdit: event.product.canEdit || state.isOwnStore,
      canDelete: event.product.canDelete || state.isOwnStore,
    );
    final next = <StoreProduct>[];
    var replaced = false;
    for (final product in state.products) {
      if (product.id == event.product.id ||
          (replacedId != null &&
              replacedId.isNotEmpty &&
              product.id == replacedId)) {
        if (!replaced) {
          next.add(updated);
          replaced = true;
        }
        continue;
      }
      next.add(product);
    }
    if (!replaced) next.insert(0, updated);
    final storeId = state.storeId;
    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      emit(
        state.copyWith(
          products: next,
          productsDetailed: next,
          infoMessage: 'Product updated.',
        ),
      );
      return;
    }
    await _commitProducts(
      emit,
      storeId,
      next,
      infoMessage: 'Product updated.',
    );
    add(const StoreProfileQuietRefreshCollections());
  }

  Future<void> _onProductDeleted(
    StoreProfileProductDeleted event,
    Emitter<StoreProfileState> emit,
  ) async {
    final productId = event.productId.trim();
    if (productId.isEmpty || state.deletingProductId != null) return;

    List<StoreProduct> without(List<StoreProduct> source) =>
        source.where((p) => p.id != productId).toList();

    final storeId = state.storeId;
    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      final next = without(state.products);
      emit(
        state.copyWith(
          products: next,
          productsDetailed: next,
          infoMessage: 'Product deleted.',
        ),
      );
      return;
    }

    emit(state.copyWith(deletingProductId: productId, clearError: true));
    try {
      await _collectionRepository.deleteCollection(
        storeId: storeId,
        listingId: productId,
      );
      AppLog.d(_tag, 'Deleted collection $productId');
      await _commitProducts(
        emit,
        storeId,
        without(state.products),
        infoMessage: 'Product deleted.',
        clearDeletingProductId: true,
      );
      add(const StoreProfileQuietRefreshCollections());
    } catch (e) {
      AppLog.e(_tag, 'Delete collection failed', e);
      final alreadyGone =
          e is CatalogApiException &&
          (e.statusCode == 404 || e.code == 'COLLECTION_NOT_FOUND');
      if (alreadyGone) {
        await _commitProducts(
          emit,
          storeId,
          without(state.products),
          infoMessage: 'Product deleted.',
          clearDeletingProductId: true,
        );
        add(const StoreProfileQuietRefreshCollections());
        return;
      }
      emit(
        state.copyWith(
          clearDeletingProductId: true,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _onProductsDeleted(
    StoreProfileProductsDeleted event,
    Emitter<StoreProfileState> emit,
  ) async {
    final ids =
        event.productIds
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();
    if (ids.isEmpty || state.deletingProductId != null) return;

    final storeId = state.storeId;
    var current = List<StoreProduct>.from(state.products);
    List<StoreProduct> without(List<StoreProduct> source, String id) =>
        source.where((p) => p.id != id).toList();

    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      for (final productId in ids) {
        current = without(current, productId);
      }
      emit(
        state.copyWith(
          products: current,
          productsDetailed: current,
          infoMessage:
              ids.length == 1
                  ? 'Product deleted.'
                  : '${ids.length} products deleted.',
        ),
      );
      return;
    }

    var failed = 0;
    for (final productId in ids) {
      emit(state.copyWith(deletingProductId: productId, clearError: true));
      try {
        await _collectionRepository.deleteCollection(
          storeId: storeId,
          listingId: productId,
        );
        current = without(current, productId);
        await _commitProducts(
          emit,
          storeId,
          current,
          clearDeletingProductId: true,
        );
      } catch (e) {
        AppLog.e(_tag, 'Batch delete failed for $productId', e);
        final alreadyGone =
            e is CatalogApiException &&
            (e.statusCode == 404 || e.code == 'COLLECTION_NOT_FOUND');
        if (alreadyGone) {
          current = without(current, productId);
          await _commitProducts(
            emit,
            storeId,
            current,
            clearDeletingProductId: true,
          );
        } else {
          failed++;
          emit(state.copyWith(clearDeletingProductId: true));
        }
      }
    }

    final deleted = ids.length - failed;
    if (deleted > 0) {
      emit(
        state.copyWith(
          infoMessage:
              deleted == 1
                  ? 'Product deleted.'
                  : '$deleted products deleted.',
        ),
      );
      add(const StoreProfileQuietRefreshCollections());
    }
    if (failed > 0) {
      emit(
        state.copyWith(
          errorMessage:
              failed == ids.length
                  ? 'Could not delete products.'
                  : 'Deleted $deleted; $failed failed.',
        ),
      );
    }
  }

  Future<void> _onProductsReplaced(
    StoreProfileProductsReplaced event,
    Emitter<StoreProfileState> emit,
  ) async {
    final storeId = state.storeId;
    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      emit(
        state.copyWith(
          products: event.products,
          productsDetailed: event.products,
        ),
      );
      return;
    }
    await _commitProducts(emit, storeId, event.products);
    add(const StoreProfileQuietRefreshCollections());
  }

  Future<void> _onProductsImported(
    StoreProfileProductsImported event,
    Emitter<StoreProfileState> emit,
  ) async {
    final next = [...event.products, ...state.products];
    final storeId = state.storeId;
    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      emit(
        state.copyWith(
          products: next,
          productsDetailed: next,
          infoMessage: 'Imported products are live in your store.',
        ),
      );
      return;
    }
    await _commitProducts(
      emit,
      storeId,
      next,
      infoMessage: 'Imported products are live in your store.',
    );
    add(const StoreProfileQuietRefreshCollections());
  }

  void _onImportPressed(
    StoreProfileImportPressed event,
    Emitter<StoreProfileState> emit,
  ) {}

  void _onSharePressed(
    StoreProfileSharePressed event,
    Emitter<StoreProfileState> emit,
  ) {
    emit(state.copyWith(infoMessage: 'Store link ready to share.'));
  }

  void _onMorePressed(
    StoreProfileMorePressed event,
    Emitter<StoreProfileState> emit,
  ) {
    emit(state.copyWith(infoMessage: 'More actions coming soon.'));
  }

  void _onQuickAddPressed(
    StoreProfileQuickAddPressed event,
    Emitter<StoreProfileState> emit,
  ) {}

  void _onClearMessage(
    StoreProfileClearMessage event,
    Emitter<StoreProfileState> emit,
  ) {
    emit(state.copyWith(clearInfoMessage: true, clearError: true));
  }

  void _onPendingUploadStarted(
    StoreProfilePendingUploadStarted event,
    Emitter<StoreProfileState> emit,
  ) {
    final pending = event.pending;
    if (pending.storeId != state.storeId) return;
    // Upload may finish before this event is handled — ignore stale starts.
    if (_finishedUploadIds.contains(pending.id)) return;
    final exists = state.pendingUploads.any((p) => p.id == pending.id);
    if (exists) return;
    emit(
      state.copyWith(
        pendingUploads: [pending, ...state.pendingUploads],
        clearError: true,
      ),
    );
  }

  void _onHideInFlightListing(
    StoreProfileHideInFlightListing event,
    Emitter<StoreProfileState> emit,
  ) {
    if (_finishedUploadIds.contains(event.pendingId)) return;
    final listingId = event.listingId.trim();
    if (listingId.isEmpty) return;

    final nextPending = [
      for (final p in state.pendingUploads)
        if (p.id == event.pendingId)
          p.copyWith(listingId: listingId)
        else
          p,
    ];
    final nextProducts =
        state.products.where((p) => p.id != listingId).toList();
    emit(
      state.copyWith(
        pendingUploads: nextPending,
        products: nextProducts,
        productsDetailed: nextProducts,
      ),
    );
  }

  Future<void> _onPendingUploadSucceeded(
    StoreProfilePendingUploadSucceeded event,
    Emitter<StoreProfileState> emit,
  ) async {
    _finishedUploadIds.add(event.pendingId);
    final nextPending =
        state.pendingUploads.where((p) => p.id != event.pendingId).toList();
    final published = event.product.copyWith(
      canEdit: event.product.canEdit || state.isOwnStore,
      canDelete: event.product.canDelete || state.isOwnStore,
    );
    final withoutDup =
        state.products.where((p) => p.id != published.id).toList();
    final next = [published, ...withoutDup];
    final info =
        (event.partialMessage != null && event.partialMessage!.trim().isNotEmpty)
            ? event.partialMessage!.trim()
            : 'Product published to store.';

    final storeId = state.storeId;
    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      emit(
        state.copyWith(
          pendingUploads: nextPending,
          products: next,
          productsDetailed: next,
          infoMessage: info,
        ),
      );
      return;
    }
    await _commitProducts(
      emit,
      storeId,
      next,
      infoMessage: info,
      pendingUploads: nextPending,
    );
    add(const StoreProfileQuietRefreshCollections());
  }

  void _onPendingUploadFailed(
    StoreProfilePendingUploadFailed event,
    Emitter<StoreProfileState> emit,
  ) {
    _finishedUploadIds.add(event.pendingId);
    emit(
      state.copyWith(
        pendingUploads:
            state.pendingUploads
                .where((p) => p.id != event.pendingId)
                .toList(),
        errorMessage: event.message,
      ),
    );
  }

  @override
  Future<void> close() {
    unawaited(_uploadSub?.cancel() ?? Future<void>.value());
    return super.close();
  }
}
