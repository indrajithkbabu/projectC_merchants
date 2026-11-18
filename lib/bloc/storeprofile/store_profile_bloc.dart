import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:project_c/bloc/team/team_bloc.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/catalog_api_call_log.dart';
import 'package:project_c/helper/catalog_ui_mapper.dart';
import 'package:project_c/helper/device_contact_names.dart';
import 'package:project_c/helper/import_qa.dart';
import 'package:project_c/helper/owner_item_delete.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/store_warm_qa.dart';
import 'package:project_c/models/catalog/catalog_store.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/models/catalog/follow_api_models.dart';
import 'package:project_c/models/catalog/import_models.dart';
import 'package:project_c/models/catalog/store_member_models.dart';
import 'package:project_c/models/pending_product_upload.dart';
import 'package:project_c/models/store_privacy_mode.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/services/product_upload_coordinator.dart';
import 'package:project_c/services/store_products_prefetcher.dart';
import 'package:project_c/storage/store_meta_cache.dart';
import 'package:project_c/storage/store_products_cache.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';
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

    /// Seeded from home/detail so owner/member never flash visitor Follow.
    StoreFollowStatus? initialFollowStatus,

    /// From home [CatalogStore.resolvedCanViewContent] — unlock grid on tap
    /// without waiting for GET store (private stays false on listing).
    bool? initialCanViewContent,

    /// Shell mounts this bloc on Stores home — wait for Profile tab / ensure.
    bool deferInitialCatalogLoads = false,
    CollectionRepository? collectionRepository,
    StoreRepository? storeRepository,
    CatalogSession? session,
    ProductUploadCoordinator? uploadCoordinator,
  }) : _collectionRepository =
           collectionRepository ?? ServiceLocator.get<CollectionRepository>(),
       _storeRepository =
           storeRepository ?? ServiceLocator.get<StoreRepository>(),
       _session = session ?? ServiceLocator.get<CatalogSession>(),
       _uploadCoordinator =
           uploadCoordinator ?? ServiceLocator.get<ProductUploadCoordinator>(),
       _deferInitialCatalogLoads = deferInitialCatalogLoads,
       super(() {
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
         final own = isOwnStore;
         final seededFollow =
             own
                 ? StoreFollowStatus.self
                 : (initialFollowStatus ??
                     cachedMeta?.followStatus ??
                     StoreFollowStatus.none);
         // Unlock when meta/home already says viewable, or follow is
         // following/self/member. Private + pending stays locked until GET.
         final initialCanView =
             own ||
             (cachedMeta?.canViewContent ?? false) ||
             (initialCanViewContent ?? false) ||
             seededFollow.isFollowing;
         // Reuse ctor-injected coordinator — avoid a second ServiceLocator hit.
         final coord =
             uploadCoordinator ??
             ServiceLocator.get<ProductUploadCoordinator>();
         final catalogSession = session ?? ServiceLocator.get<CatalogSession>();
         final activeUploads = coord.pendingForStore(id);
         final hidden = coord.inFlightListingIdsForStore(id);
         // Skip List.from + sort when cache is already newest-first and
         // nothing is hidden (Batch 1 — route construction stays light).
         final visibleCached = _visibleProductsForInitialState(
           cachedProducts,
           hidden,
         );
         final gatedProducts =
             initialCanView ? visibleCached : const <StoreProduct>[];
         // When gated, keep a count from warm/cache products if the GET
         // store payload omits productCount (common for private visitors).
         final seedProductCount =
             cachedMeta?.productCount ??
             (cachedProducts.isNotEmpty ? cachedProducts.length : null);
         return StoreProfileState(
           storeName: cachedName.isNotEmpty ? cachedName : argName,
           members: members,
           products: gatedProducts,
           productsDetailed: gatedProducts,
           isOwnStore: own,
           viewerHasOwnStore: _hasOwnStoreId(catalogSession),
           storeId: id,
           avatarColor: avatarColor,
           overrideStoreLink: cachedLink.isNotEmpty ? cachedLink : storeLink,
           coverImageUrl: cover,
           storeImages: cachedMeta?.storeImages ?? const [],
           city: cachedMeta?.city ?? '',
           privacy: cachedMeta?.privacy ?? StorePrivacyMode.public,
           followerCount: cachedMeta?.followerCount ?? 0,
           followingCount: cachedMeta?.followingCount ?? 0,
           apiProductCount: seedProductCount,
           pendingFollowRequestCount:
               own ? (cachedMeta?.pendingRequestsCount ?? 0) : 0,
           canViewContent: initialCanView,
           followStatus: seededFollow,
           currentUserId: catalogSession.profile?.id,
           // Do not assume cold shimmer on process restart — memory is empty
           // but disk may still have the grid. LoadCollections sets shimmer
           // only after a confirmed disk+warm miss (clear-data / first open).
           isLoadingProducts: false,
           productsResolved:
               gatedProducts.isNotEmpty || activeUploads.isNotEmpty,
           // Members API is owner-only; staff uses isOwnStore shell but must
           // not spin a members loader (avoids OWNER_REQUIRED toast on switch).
           isLoadingMembers:
               own &&
               !deferInitialCatalogLoads &&
               catalogSession.isActingAsOwner,
           isLoadingStoreMeta:
               deferInitialCatalogLoads ? false : cachedMeta == null,
           // Survive leave/return while create upload is still in flight.
           pendingUploads: own ? activeUploads : const [],
         );
       }()) {
    on<StoreProfileAddProductsPressed>(_onAddProductsPressed);
    on<StoreProfileProductPublished>(_onProductPublished);
    on<StoreProfileProductUpdated>(_onProductUpdated);
    on<StoreProfileProductDeleted>(_onProductDeleted);
    on<StoreProfileProductsDeleted>(_onProductsDeleted);
    on<StoreProfileItemsDeleted>(_onItemsDeleted);
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
    on<StoreProfilePendingUploadProgress>(_onPendingUploadProgress);
    on<StoreProfilePendingUploadSucceeded>(_onPendingUploadSucceeded);
    on<StoreProfilePendingRevealFinished>(_onPendingRevealFinished);
    on<StoreProfilePendingUploadFailed>(_onPendingUploadFailed);
    on<StoreProfilePendingUploadRetry>(_onPendingUploadRetry);
    on<StoreProfileHideInFlightListing>(_onHideInFlightListing);
    on<StoreProfileFollowPressed>(_onFollowPressed);
    on<StoreProfileUnfollowPressed>(_onUnfollowPressed);
    on<StoreProfileToggleNotifyUploads>(_onToggleNotifyUploads);
    on<StoreProfileLoadFollowRequestPreviews>(_onLoadFollowRequestPreviews);
    on<StoreProfileExpandAlbumCollage>(_onExpandAlbumCollage);
    on<StoreProfileExpandAlbumBatch>(_onExpandAlbumBatch);
    on<StoreProfileEnsureInitialCatalogLoads>(_onEnsureInitialCatalogLoads);
    // Concurrent so a slow disk/isolate decode does not block Ensure / meta /
    // network events queued on the same bloc (Batch I3 race safety).
    on<StoreProfileHydrateDiskCache>(
      _onHydrateDiskCache,
      transformer: (events, mapper) => events.concurrentAsyncExpand(mapper),
    );
    _uploadSub = _uploadCoordinator.events.listen(_onUploadCoordinatorEvent);
    if (StoreWarmQa.enabled) {
      final id = state.storeId.trim();
      // Avoid shell remount metrics stealing an in-flight Discover open session.
      final correlates =
          StoreWarmQa.openStoreId == null || StoreWarmQa.openStoreId == id;
      if (correlates) {
        final mem = StoreProductsCache.instance.readMemory(id);
        if (mem != null && mem.isNotEmpty) {
          StoreWarmQa.event('PROFILE_MEMORY_CACHE_HIT', {
            'store': id,
            'products': mem.length,
            'beforeFirstFrame': !StoreWarmQa.firstFrameSeen,
          });
          StoreWarmQa.observeShimmer(show: false, reason: 'cachedProducts');
          StoreWarmQa.noteFirstProductsReady(
            count: mem.length,
            source: 'memory',
          );
        } else {
          StoreWarmQa.event('PROFILE_MEMORY_CACHE_MISS', {
            'store': id,
            'productsResolved': state.productsResolved,
          });
          if (state.products.isEmpty && !state.productsResolved) {
            StoreWarmQa.observeShimmer(show: true, reason: 'unresolved');
          }
        }
        StoreWarmQa.event('PROFILE_BLOC_CREATED', {
          'store': id,
          'products': state.products.length,
          'productsResolved': state.productsResolved,
          'isLoadingProducts': state.isLoadingProducts,
          'canView': state.canViewContent,
        });
      }
    }
    if (!_deferInitialCatalogLoads) {
      _startInitialCatalogLoads(storeId: storeId, isOwnStore: isOwnStore);
    }
  }

  /// Owner-only store admin reads (members / follow-request inbox).
  bool get _canLoadOwnerAdminData => _session.isActingAsOwner;

  final CollectionRepository _collectionRepository;
  final StoreRepository _storeRepository;
  final CatalogSession _session;
  final ProductUploadCoordinator _uploadCoordinator;
  final bool _deferInitialCatalogLoads;
  bool _initialCatalogLoadsStarted = false;

  /// Coalesce open-path [StoreProfileLoadCollections] (memory / disk / network
  /// meta can each try to kick collections once canView flips).
  bool _initialCollectionsRequested = false;

  /// Batch I3 — at most one early disk hydrate per bloc instance.
  bool _earlyDiskHydrateStarted = false;

  /// Test hook: delay after eligibility checks, before the async disk read.
  @visibleForTesting
  static Future<void> Function()? debugBeforeDiskHydrateRead;

  StreamSubscription<ProductUploadEvent>? _uploadSub;
  final Set<String> _finishedUploadIds = <String>{};
  final Set<String> _expandingAlbumIds = <String>{};

  /// Albums that already ran one expand attempt this session (doc §4:
  /// same album won't expand twice). Cleared on cold collections load.
  final Set<String> _expandedAlbumIds = <String>{};

  /// Background expand queue — deferred after first grid paint so open does
  /// not race large collections decode / image warm (doc §4).
  final LinkedHashSet<String> _pendingAlbumExpandIds = LinkedHashSet<String>();
  Timer? _albumExpandPumpTimer;
  bool _albumExpandIdleGatePassed = false;

  /// Let open transition + first collage paint settle before expand waves
  /// (was 80ms — fought landing jank / skipped frames).
  static const Duration _albumExpandStartDelay = Duration(milliseconds: 420);

  /// Gap between parallel waves — keep light while user may be scrolling.
  static const Duration _albumExpandBetweenDelay = Duration(milliseconds: 120);

  /// Parallel product-list fetches per wave (lower = less mid-scroll rebuild).
  static const int _albumExpandMaxConcurrent = 2;

  /// Auto-expand only the first N albums after open (≈ viewport + buffer).
  /// Further albums expand on swipe via [StoreProfileExpandAlbumCollage].
  static const int _maxAutoExpandAlbums = 8;

  /// Authoritative warm lease for this profile session (Batch 7A).
  /// Cancelled only from [close] — route dispose must not cancel peers.
  final CatalogWarmOwner _imageWarmOwner = CatalogImageCache.createWarmOwner(
    debugLabel: 'storeProfile',
  );

  /// Shared across bloc instances so open remounts do not double GET store.
  static final Map<String, Future<CatalogStore>> _storeMetaInFlight = {};
  static final Map<String, DateTime> _storeMetaNetworkAt = {};
  static const Duration _storeMetaQuietTtl = Duration(seconds: 45);

  /// Shared members fetch — remount / double Ensure must not 2× GET members.
  static final Map<String, Future<List<TeamMember>>> _storeMembersInFlight = {};
  static final Map<String, List<TeamMember>> _storeMembersMemory = {};
  static final Map<String, DateTime> _storeMembersNetworkAt = {};
  static const Duration _storeMembersQuietTtl = Duration(seconds: 45);

  void _startInitialCatalogLoads({
    required String? storeId,
    required bool isOwnStore,
  }) {
    if (_initialCatalogLoadsStarted) return;
    _initialCatalogLoadsStarted = true;
    // Debug: attribute ApiCallCount to this profile open.
    final scopedId = (storeId ?? state.storeId).trim();
    if (scopedId.isNotEmpty &&
        scopedId != 'my_store' &&
        scopedId != 'other_store') {
      CatalogApiCallLog.beginStoreProfileScope(scopedId);
      // Clear post-close collage-warm suppress (deep link may skip prefetch).
      StoreProductsPrefetcher.instance.noteProfileOpened(scopedId);
    }
    add(const StoreProfileLoadStoreMeta());
    // Own store: load collections immediately. Visitors: as soon as canView
    // is known (meta memory, or following seed) — do not wait on GET store.
    if (isOwnStore) {
      _requestInitialCollections();
      // Staff also mounts with isOwnStore=true for product chrome; members /
      // follow-request admin APIs are owner-only — skip for staff.
      if (_session.isActingAsOwner) {
        add(const StoreProfileLoadMembers());
      }
      // TODO(backend): re-enable when GET …/import-requests is live (404 today).
      // add(const StoreProfileLoadImportRequestCount());
    } else {
      _requestInitialCollections();
    }
  }

  /// One open-path collections load once [canViewContent] is true.
  /// Follow/unlock mutation paths still `add(LoadCollections)` directly.
  void _requestInitialCollections({bool allowAfterUnlock = false}) {
    if (!state.isOwnStore && !state.canViewContent) return;
    if (_initialCollectionsRequested && !allowAfterUnlock) return;
    _initialCollectionsRequested = true;
    add(const StoreProfileLoadCollections());
  }

  void _onEnsureInitialCatalogLoads(
    StoreProfileEnsureInitialCatalogLoads event,
    Emitter<StoreProfileState> emit,
  ) {
    _startInitialCatalogLoads(
      storeId: state.storeId,
      isOwnStore: state.isOwnStore,
    );
  }

  /// Batch I3 — async disk hydrate after first frame (not behind Ensure delay).
  Future<void> _onHydrateDiskCache(
    StoreProfileHydrateDiskCache event,
    Emitter<StoreProfileState> emit,
  ) async {
    if (_earlyDiskHydrateStarted) return;
    _earlyDiskHydrateStarted = true;

    final storeId = state.storeId.trim();
    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      return;
    }
    // Private visitor lock — do not probe disk or mark resolved.
    if (!state.isOwnStore && !state.canViewContent) return;

    // Memory already painted usable products — skip disk I/O.
    if (state.products.isNotEmpty && state.productsResolved) return;
    final mem = StoreProductsCache.instance.readMemory(storeId);
    if (mem != null && mem.isNotEmpty) return;

    final beforeRead = debugBeforeDiskHydrateRead;
    if (beforeRead != null) {
      await beforeRead();
      if (isClosed || emit.isDone) return;
      if (state.storeId.trim() != storeId) return;
    }

    StoreWarmQa.event('PROFILE_EARLY_DISK_START', {
      'store': storeId,
      'beforeFirstFrame': !StoreWarmQa.firstFrameSeen,
    });
    final diskSw = Stopwatch()..start();
    final disk = await StoreProductsCache.instance.read(storeId);
    diskSw.stop();
    if (isClosed || emit.isDone) return;
    if (state.storeId.trim() != storeId) return;

    // Network / Ensure already painted — never overwrite with stale disk.
    if (state.products.isNotEmpty && state.productsResolved) {
      StoreWarmQa.event('PROFILE_EARLY_DISK_SKIP', {
        'store': storeId,
        'reason': 'networkWon',
        'ms': diskSw.elapsedMilliseconds,
      });
      return;
    }

    if (disk == null || disk.isEmpty) {
      // Empty disk = miss — keep unresolved until collections resolve.
      StoreWarmQa.event('PROFILE_EARLY_DISK_MISS', {
        'store': storeId,
        'ms': diskSw.elapsedMilliseconds,
      });
      // Batch I5 — start collections immediately after confirmed miss so cold
      // opens do not wait for the Ensure delay (~280–320 ms). Coalesced with
      // Ensure via [_initialCollectionsRequested].
      StoreWarmQa.event('COLD_COLLECTIONS_KICK', {
        'store': storeId,
        'reason': 'earlyDiskMiss',
      });
      _requestInitialCollections();
      return;
    }

    StoreWarmQa.event('PROFILE_EARLY_DISK_HIT', {
      'store': storeId,
      'products': disk.length,
      'ms': diskSw.elapsedMilliseconds,
      'beforeFirstFrame': !StoreWarmQa.firstFrameSeen,
    });
    await _emitProductsFromCache(
      emit,
      storeId,
      isLoadingProducts: false,
      productsResolved: true,
    );
    if (isClosed || emit.isDone) return;
    StoreWarmQa.observeShimmer(show: false, reason: 'cachedProducts');
    StoreWarmQa.noteFirstProductsReady(count: disk.length, source: 'earlyDisk');
  }

  /// Open-path soft refresh — one network per [quietRefreshTtl], not per remount.
  void _queueQuietCollectionsRefreshIfStale(String storeId) {
    if (StoreProductsPrefetcher.instance.isFresh(storeId)) {
      AppLog.d(_tag, 'Skip quiet collections refresh store=$storeId (fresh)');
      return;
    }
    add(const StoreProfileQuietRefreshCollections(force: false));
  }

  /// Commit succeeded — product held until pending collage finishes tick reveal.
  final Map<String, ({StoreProduct product, String? partialMessage})>
  _pendingReveals = {};
  static const _tag = 'StoreProfileBloc';

  void _onUploadCoordinatorEvent(ProductUploadEvent event) {
    if (event.storeId != state.storeId) return;
    switch (event) {
      case ProductUploadStarted(
        :final pendingId,
        :final storeId,
        :final title,
        :final photoCount,
        :final photos,
      ):
        add(
          StoreProfilePendingUploadStarted(
            PendingProductUpload(
              id: pendingId,
              storeId: storeId,
              title: title,
              photoCount: photoCount,
              photos: photos,
            ),
          ),
        );
      case ProductUploadProgress(
        :final pendingId,
        :final photos,
        :final isCommitting,
      ):
        add(
          StoreProfilePendingUploadProgress(
            pendingId: pendingId,
            photos: photos,
            isCommitting: isCommitting,
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

  /// Seed grid products without always copying + sorting the full list.
  /// Prefetch/cache already keep newest-first by id; reuse that reference.
  static List<StoreProduct> _visibleProductsForInitialState(
    List<StoreProduct> cachedProducts,
    Set<String> hidden,
  ) {
    if (cachedProducts.isEmpty) return const <StoreProduct>[];
    if (hidden.isEmpty) {
      if (_isNewestFirstById(cachedProducts)) return cachedProducts;
      return List<StoreProduct>.from(cachedProducts)
        ..sort((a, b) => b.id.compareTo(a.id));
    }
    return [
      for (final p in cachedProducts)
        if (!hidden.contains(p.id)) p,
    ]..sort((a, b) => b.id.compareTo(a.id));
  }

  static bool _isNewestFirstById(List<StoreProduct> products) {
    for (var i = 1; i < products.length; i++) {
      if (products[i - 1].id.compareTo(products[i].id) < 0) return false;
    }
    return true;
  }

  /// Viewer can import into active store (owner/staff) or an owned store.
  static bool _hasOwnStoreId(CatalogSession session) {
    return session.hasImportDestination;
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
      emit(state.copyWith(isLoadingProducts: false, productsResolved: true));
      return;
    }
    if (!state.isOwnStore && !state.canViewContent) {
      emit(
        state.copyWith(
          products: const [],
          clearProductsDetailed: true,
          isLoadingProducts: false,
          productsResolved: true,
        ),
      );
      return;
    }

    // Batch I3 — early disk already painted usable products; keep grid and
    // only quiet-refresh. Do not clear expand sets or re-read disk.
    if (state.products.isNotEmpty && state.productsResolved) {
      _queueQuietCollectionsRefreshIfStale(storeId);
      return;
    }

    // Fresh cold load may need expand again (album grew / cache rebuilt).
    _expandedAlbumIds.clear();
    _expandingAlbumIds.clear();
    _clearAlbumExpandQueue(resetIdleGate: true);

    // Disk/memory first — restart paints from disk without shimmer.
    // Do not set isLoadingProducts until disk+warm both miss (true cold).
    StoreWarmQa.event('PROFILE_DISK_CACHE_START', {
      'store': storeId,
      'beforeFirstFrame': !StoreWarmQa.firstFrameSeen,
    });
    final diskSw = Stopwatch()..start();
    final disk = await StoreProductsCache.instance.read(storeId);
    diskSw.stop();
    if (emit.isDone) return;
    if (disk != null && disk.isNotEmpty) {
      StoreWarmQa.event('PROFILE_DISK_CACHE_HIT', {
        'store': storeId,
        'products': disk.length,
        'ms': diskSw.elapsedMilliseconds,
        'beforeFirstFrame': !StoreWarmQa.firstFrameSeen,
      });
      StoreWarmQa.event('PROFILE_DISK_CACHE_COMPLETE', {
        'store': storeId,
        'source': 'hit',
        'ms': diskSw.elapsedMilliseconds,
      });
      await _emitProductsFromCache(
        emit,
        storeId,
        isLoadingProducts: false,
        productsResolved: true,
      );
      StoreWarmQa.observeShimmer(show: false, reason: 'cachedProducts');
      StoreWarmQa.noteFirstProductsReady(count: disk.length, source: 'disk');
      // Soft quiet refresh — skipped if prefetcher just enriched (TTL).
      _queueQuietCollectionsRefreshIfStale(storeId);
      return;
    }

    StoreWarmQa.event('PROFILE_DISK_CACHE_MISS', {
      'store': storeId,
      'ms': diskSw.elapsedMilliseconds,
      'beforeFirstFrame': !StoreWarmQa.firstFrameSeen,
    });
    StoreWarmQa.event('PROFILE_DISK_CACHE_COMPLETE', {
      'store': storeId,
      'source': 'miss',
      'ms': diskSw.elapsedMilliseconds,
    });

    // Prefer warm data started on store tap / listing prefetch (shared loader).
    final warm = await StoreProductsPrefetcher.instance.ensure(storeId);
    if (emit.isDone) return;

    if (warm.isNotEmpty) {
      await _emitProductsFromCache(
        emit,
        storeId,
        fallback: warm,
        isLoadingProducts: false,
        productsResolved: true,
      );
      StoreWarmQa.observeShimmer(show: false, reason: 'cachedProducts');
      StoreWarmQa.noteFirstProductsReady(count: warm.length, source: 'ensure');
      _queueQuietCollectionsRefreshIfStale(storeId);
      return;
    }

    // Empty store: [ensure] already GETs collections (and stamps TTL). Do not
    // fall through to force:true refresh — that was the empty-store 2× bug.
    if (StoreProductsPrefetcher.instance.isFresh(storeId)) {
      await _commitProducts(
        emit,
        storeId,
        const [],
        isLoadingProducts: false,
        productsResolved: true,
      );
      StoreWarmQa.observeShimmer(show: false, reason: 'none');
      StoreWarmQa.noteEmptyResolved(source: 'ensureFreshEmpty');
      AppLog.d(_tag, 'Empty collections after ensure — skip second GET');
      return;
    }

    // True cold path (clear data / first open) — restrained section loader (I5).
    StoreWarmQa.observeShimmer(show: true, reason: 'loading');
    StoreWarmQa.event('COLD_LOAD_START', {'store': storeId});
    final coldSw = Stopwatch()..start();
    emit(
      state.copyWith(
        isLoadingProducts: true,
        productsResolved: false,
        clearError: true,
      ),
    );
    try {
      // Same loader as prefetch / quiet refresh (API-2).
      final products = await StoreProductsPrefetcher.instance.refresh(
        storeId,
        force: true,
      );
      if (emit.isDone) return;
      final commitSw = Stopwatch()..start();
      await _commitProducts(
        emit,
        storeId,
        products,
        isLoadingProducts: false,
        productsResolved: true,
      );
      commitSw.stop();
      coldSw.stop();
      StoreWarmQa.event('COLD_LOAD_COMMIT', {
        'store': storeId,
        'products': products.length,
        'commitMs': commitSw.elapsedMilliseconds,
        'totalMs': coldSw.elapsedMilliseconds,
      });
      if (products.isEmpty) {
        StoreWarmQa.observeShimmer(show: false, reason: 'none');
        StoreWarmQa.noteEmptyResolved(source: 'coldRefresh');
      } else {
        StoreWarmQa.observeShimmer(show: false, reason: 'cachedProducts');
        StoreWarmQa.noteFirstProductsReady(
          count: products.length,
          source: 'coldRefresh',
        );
      }
      AppLog.d(_tag, 'Loaded ${products.length} collections (cold load)');
    } catch (e) {
      AppLog.e(_tag, 'Collections load failed', e);
      coldSw.stop();
      StoreWarmQa.event('COLD_LOAD_FAIL', {
        'store': storeId,
        'ms': coldSw.elapsedMilliseconds,
      });
      if (e is CatalogApiException && e.code == 'STORE_PRIVATE') {
        emit(
          state.copyWith(
            canViewContent: false,
            products: const [],
            clearProductsDetailed: true,
            isLoadingProducts: false,
            productsResolved: true,
            clearError: true,
          ),
        );
        StoreWarmQa.observeShimmer(show: false, reason: 'none');
        return;
      }
      emit(
        state.copyWith(
          isLoadingProducts: false,
          productsResolved: true,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
      StoreWarmQa.observeShimmer(show: false, reason: 'none');
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
    if (!state.isOwnStore && !state.canViewContent) return;
    // Forced refresh (upload/delete) — allow expand again for grown albums.
    if (event.force) {
      _expandedAlbumIds.clear();
      // Re-discover from merged grid; keep idle gate (screen already painted).
      _clearAlbumExpandQueue(resetIdleGate: false);
    }
    try {
      // Single enrich path via prefetcher (no duplicate bloc 1+N).
      final products = await StoreProductsPrefetcher.instance.refresh(
        storeId,
        force: event.force,
      );
      if (isClosed || emit.isDone) return;
      if (state.storeId.trim() != storeId) return;
      final previous = state.products;
      // Drop cover-only empties that slipped through enrich (no displayable
      // frames) so item-delete cannot resurrect ghost tiles after refresh.
      final visible = [
        for (final p in _withoutInFlightUploads(products))
          if (p.imagePaths.any(ProductImagePaths.isDisplayable)) p,
      ];
      // Keep already-expanded collage frames (20) — prefetcher only holds
      // productsLimit=9 and must not wipe swipe pages back to preview.
      final merged = _mergePreservingExpandedAlbums(previous, visible);
      // Prefetcher already wrote cache on network; keep memory in sync for
      // TTL-skipped returns that only read cache.
      await StoreProductsCache.instance.write(storeId, merged);
      final cached = StoreProductsCache.instance.readMemory(storeId) ?? merged;
      if (_sameGridVisual(previous, cached) &&
          _sameListingAvailability(state.listingAvailability, cached)) {
        _queueNeededAlbumExpands(cached);
        return;
      }
      emit(
        state.copyWith(
          products: cached,
          productsDetailed: cached,
          listingAvailability: _listingAvailabilityFromProducts(cached),
        ),
      );
      _queueNeededAlbumExpands(cached);
    } catch (e) {
      AppLog.e(_tag, 'Quiet collections refresh failed', e);
    }
  }

  /// Prefer local expanded media when quiet refresh returns BE-2 preview only.
  List<StoreProduct> _mergePreservingExpandedAlbums(
    List<StoreProduct> previous,
    List<StoreProduct> incoming,
  ) {
    if (previous.isEmpty) return incoming;
    final prevById = <String, StoreProduct>{for (final p in previous) p.id: p};
    return [
      for (final next in incoming)
        () {
          final old = prevById[next.id];
          if (old == null) return next;
          final oldN = old.imagePaths.where((p) => p.trim().isNotEmpty).length;
          final newN = next.imagePaths.where((p) => p.trim().isNotEmpty).length;
          if (oldN <= newN) return next;
          final album =
              next.albumItemCount > old.albumItemCount
                  ? next.albumItemCount
                  : old.albumItemCount;
          // Keep expanded paths; refresh badge / lock metadata from network.
          return old.copyWith(
            title: next.title,
            description: next.description,
            likeCount: next.likeCount,
            viewCount: next.viewCount,
            wishlistCount: next.wishlistCount,
            isLocked: next.isLocked,
            stockStatus: next.stockStatus,
            mtoDays: next.mtoDays,
            importFlags: next.importFlags,
            albumItemCount: album,
            tags: next.tags,
            precisionTag: next.precisionTag,
            createdAt: next.createdAt ?? old.createdAt,
          );
        }(),
    ];
  }

  /// Background-fill albums larger than BE-2 preview so swipe / browse /
  /// channel are ready without a loading wait (fast-APK parallel fan-out).
  ///
  /// One attempt per album (§4). Waves of [_albumExpandMaxConcurrent] run
  /// after a short idle gate. Swipe still dispatches a single
  /// [StoreProfileExpandAlbumCollage] immediately.
  void _queueNeededAlbumExpands(List<StoreProduct> products) {
    var enqueued = false;
    var autoCount = 0;
    for (final p in products) {
      // Batch 6: do not auto-expand the whole catalog — prioritise visible.
      if (autoCount >= _maxAutoExpandAlbums) break;
      if (!p.needsAlbumExpand) continue;
      final id = p.id.trim();
      if (id.isEmpty) continue;
      if (_expandingAlbumIds.contains(id) || _expandedAlbumIds.contains(id)) {
        continue;
      }
      if (_pendingAlbumExpandIds.add(id)) {
        enqueued = true;
        autoCount++;
      }
    }
    if (enqueued) {
      _scheduleAlbumExpandPump();
    }
  }

  void _clearAlbumExpandQueue({required bool resetIdleGate}) {
    _albumExpandPumpTimer?.cancel();
    _albumExpandPumpTimer = null;
    _pendingAlbumExpandIds.clear();
    if (resetIdleGate) {
      _albumExpandIdleGatePassed = false;
    }
  }

  /// Start / continue the deferred expand pump. [afterExpand] short-circuits
  /// the open idle gate and replaces any longer pending timer.
  void _scheduleAlbumExpandPump({bool afterExpand = false}) {
    if (isClosed) return;
    if (_pendingAlbumExpandIds.isEmpty) return;

    if (afterExpand) {
      _albumExpandIdleGatePassed = true;
      _albumExpandPumpTimer?.cancel();
      _albumExpandPumpTimer = null;
    } else {
      if (_albumExpandPumpTimer?.isActive ?? false) return;
      if (_expandingAlbumIds.isNotEmpty) return;
    }

    final delay =
        _albumExpandIdleGatePassed
            ? _albumExpandBetweenDelay
            : _albumExpandStartDelay;
    _albumExpandPumpTimer = Timer(delay, () {
      _albumExpandPumpTimer = null;
      _albumExpandIdleGatePassed = true;
      _pumpNextAlbumExpand();
    });
  }

  void _pumpNextAlbumExpand() {
    if (isClosed) return;
    // Wait for in-flight single/batch expand to finish (bloc is sequential).
    if (_expandingAlbumIds.isNotEmpty) return;

    final batch = <String>[];
    while (batch.length < _albumExpandMaxConcurrent &&
        _pendingAlbumExpandIds.isNotEmpty) {
      final id = _pendingAlbumExpandIds.first;
      _pendingAlbumExpandIds.remove(id);
      if (_expandingAlbumIds.contains(id) || _expandedAlbumIds.contains(id)) {
        continue;
      }
      final stillNeeds = state.productsForMedia.any(
        (p) => p.id == id && p.needsAlbumExpand,
      );
      if (!stillNeeds) continue;
      batch.add(id);
    }
    if (batch.isEmpty) return;
    if (batch.length == 1) {
      add(StoreProfileExpandAlbumCollage(batch.first));
      return;
    }
    add(StoreProfileExpandAlbumBatch(batch));
  }

  /// When products API returned the full set, drop inflated album counts so
  /// `needsAlbumExpand` clears (stale cache / overcount must not loop).
  StoreProduct _clampAlbumCountIfExhausted(
    StoreProduct card, {
    required bool exhausted,
  }) {
    if (!exhausted) return card;
    final loaded = card.imagePaths.where((p) => p.trim().isNotEmpty).length;
    if (card.albumItemCount <= loaded) return card;
    return card.copyWith(albumItemCount: loaded);
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

  /// First ~2 Group rows (2×2) — decode these before the rest of the grid.
  static const int _firstPaintAlbumWarmCount = 4;

  /// Delay so warm does not fight the Cupertino push (Plan A1).
  static const Duration _gridDecodeWarmDelay = Duration(milliseconds: 360);

  /// Gap before warming albums below the first viewport.
  static const Duration _gridDecodeRestDelay = Duration(milliseconds: 220);

  List<String> _gridTileUrls(List<StoreProduct> products) => [
    // Album frames use up to 9 cells per listing on the first collage page.
    for (final product in products) ...product.imagePaths.take(9),
  ];

  Future<void> _warmGridUrlBatch(
    List<String> urls, {
    required int maxDecode,
    required int warmEpoch,
    int concurrency = 8,
  }) async {
    if (urls.isEmpty || maxDecode <= 0) return;
    if (isClosed || !_imageWarmOwner.allows(warmEpoch)) {
      StoreWarmQa.log(
        'PROFILE_WARM_SKIP batch store=${state.storeId} '
        'reason=${isClosed ? 'blocClosed' : 'ownerInactive'} epoch=$warmEpoch',
      );
      return;
    }
    // Match StoreProductGrid collage paint keys (Batch 2).
    final cacheWidth = CatalogImageCache.collageCellCacheWidth();
    StoreWarmQa.log(
      'PROFILE_WARM_RUN batch store=${state.storeId} urls=${urls.length} '
      'maxDecode=$maxDecode concurrency=$concurrency epoch=$warmEpoch',
    );
    await CatalogImageCache.warmDiskHits(
      urls,
      maxDecode: maxDecode,
      cacheWidth: cacheWidth,
      owner: _imageWarmOwner,
    );
    if (isClosed || !_imageWarmOwner.allows(warmEpoch)) {
      StoreWarmQa.log(
        'PROFILE_WARM_ABORT afterDisk store=${state.storeId} '
        'reason=${isClosed ? 'blocClosed' : 'ownerInactive'}',
      );
      return;
    }
    await CatalogImageCache.precacheUrls(
      urls,
      decode: true,
      maxDecode: maxDecode,
      cacheWidth: cacheWidth,
      concurrency: concurrency,
      owner: _imageWarmOwner,
    );
  }

  /// Reopen-safe: visible albums first, then the rest — never blocks emit.
  Future<void> _warmGridTilesBeforePaint(List<StoreProduct> products) async {
    if (products.isEmpty || isClosed) return;
    final warmEpoch = _imageWarmOwner.epoch;
    final storeId = state.storeId.trim();
    StoreWarmQa.step(
      'PROFILE_WARM_START',
      detail:
          'store=$storeId products=${products.length} '
          'owner=${_imageWarmOwner.debugLabel} epoch=$warmEpoch',
    );
    final first =
        products.length <= _firstPaintAlbumWarmCount
            ? products
            : products.sublist(0, _firstPaintAlbumWarmCount);
    final rest =
        products.length <= _firstPaintAlbumWarmCount
            ? const <StoreProduct>[]
            : products.sublist(_firstPaintAlbumWarmCount);

    final firstUrls = _gridTileUrls(first);
    // ~first page tiles for 4 albums; keep under defaultMaxDecode.
    await _warmGridUrlBatch(
      firstUrls,
      maxDecode: firstUrls.length.clamp(1, 36),
      warmEpoch: warmEpoch,
    );
    if (isClosed || rest.isEmpty) return;
    if (state.storeId.trim() != storeId) return;
    if (!_imageWarmOwner.allows(warmEpoch)) {
      StoreWarmQa.log(
        'PROFILE_WARM_SKIP rest store=$storeId reason=ownerInactive',
      );
      return;
    }

    await Future<void>.delayed(_gridDecodeRestDelay);
    if (isClosed || state.storeId.trim() != storeId) return;
    if (!_imageWarmOwner.allows(warmEpoch)) {
      StoreWarmQa.log(
        'PROFILE_WARM_SKIP restAfterDelay store=$storeId reason=ownerInactive',
      );
      return;
    }
    final restUrls = _gridTileUrls(rest);
    unawaited(
      _warmGridUrlBatch(
        restUrls,
        maxDecode: CatalogImageCache.defaultMaxDecode,
        warmEpoch: warmEpoch,
        concurrency: 4,
      ),
    );
  }

  bool _sameGridVisual(List<StoreProduct> a, List<StoreProduct> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].title != b[i].title) return false;
      // Like/view badges must refresh after wishlist unlike without image churn.
      if (a[i].likeCount != b[i].likeCount ||
          a[i].viewCount != b[i].viewCount ||
          a[i].isLocked != b[i].isLocked ||
          a[i].stockStatus != b[i].stockStatus ||
          a[i].mtoDays != b[i].mtoDays ||
          a[i].albumItemCount != b[i].albumItemCount) {
        return false;
      }
      final ap = a[i].imagePaths;
      final bp = b[i].imagePaths;
      if (ap.length != bp.length) return false;
      for (var j = 0; j < ap.length; j++) {
        if (ap[j] != bp[j]) return false;
      }
    }
    return true;
  }

  /// Write API products → cache, then emit only what cache holds.
  Future<void> _commitProducts(
    Emitter<StoreProfileState> emit,
    String storeId,
    List<StoreProduct> products, {
    bool isLoadingProducts = false,
    bool productsResolved = true,
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
      productsResolved: productsResolved,
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
    bool? productsResolved,
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
    final resolvedFlag = productsResolved ?? state.productsResolved;
    final nextPending = pendingUploads ?? state.pendingUploads;
    final nextAvailability = _listingAvailabilityFromProducts(visible);
    // Batch 4: skip no-op product emits (disk + warm / quiet overlap).
    if (infoMessage == null &&
        !clearDeletingProductId &&
        !clearError &&
        state.isLoadingProducts == isLoadingProducts &&
        state.productsResolved == resolvedFlag &&
        identical(state.pendingUploads, nextPending) &&
        state.listingAvailability == nextAvailability &&
        _sameGridVisual(state.products, visible) &&
        _sameGridVisual(state.productsForMedia, visible)) {
      if (visible.isNotEmpty) {
        final warmEpoch = _imageWarmOwner.epoch;
        StoreWarmQa.log(
          'PROFILE_WARM_SCHEDULE store=${state.storeId} '
          'products=${visible.length} epoch=$warmEpoch path=noopEmit',
        );
        unawaited(
          Future<void>.delayed(_gridDecodeWarmDelay, () {
            if (isClosed || !_imageWarmOwner.allows(warmEpoch)) {
              StoreWarmQa.log(
                'PROFILE_WARM_SKIP delayedStart store=${state.storeId} '
                'reason=${isClosed ? 'blocClosed' : 'ownerInactive'} '
                'path=noopEmit',
              );
              return;
            }
            unawaited(_warmGridTilesBeforePaint(visible));
          }),
        );
      }
      if (resolvedFlag || !isLoadingProducts) {
        _queueNeededAlbumExpands(visible);
      }
      return;
    }
    // Paint cache first (ThumbHash/blur OK). Warm decode in background so
    // reopen is not blocked on disk probe — matches tap→instant APK feel.
    emit(
      state.copyWith(
        products: visible,
        productsDetailed: visible,
        isLoadingProducts: isLoadingProducts,
        productsResolved: productsResolved,
        infoMessage: infoMessage,
        clearDeletingProductId: clearDeletingProductId,
        clearError: clearError,
        pendingUploads: pendingUploads,
        listingAvailability: nextAvailability,
        apiProductCount:
            state.apiProductCount ??
            (visible.isNotEmpty ? visible.length : null),
      ),
    );
    if (visible.isNotEmpty) {
      // Delay decode warm so it does not fight the store-open transition.
      final warmEpoch = _imageWarmOwner.epoch;
      StoreWarmQa.log(
        'PROFILE_WARM_SCHEDULE store=${state.storeId} '
        'products=${visible.length} epoch=$warmEpoch path=emit',
      );
      unawaited(
        Future<void>.delayed(_gridDecodeWarmDelay, () {
          if (isClosed || !_imageWarmOwner.allows(warmEpoch)) {
            StoreWarmQa.log(
              'PROFILE_WARM_SKIP delayedStart store=${state.storeId} '
              'reason=${isClosed ? 'blocClosed' : 'ownerInactive'} path=emit',
            );
            return;
          }
          unawaited(_warmGridTilesBeforePaint(visible));
        }),
      );
    }
    // After first paint / cache emit — hydrate >9 albums in background.
    if (productsResolved == true || !isLoadingProducts) {
      _queueNeededAlbumExpands(visible);
    }
  }

  /// Derive Added/Pending badges from list/product import flags — no N×
  /// `/import-targets` fan-out (legacy stubs often 404).
  Map<String, ListingImportAvailability> _listingAvailabilityFromProducts(
    List<StoreProduct> products,
  ) {
    if (state.isOwnStore || !state.canImport) return const {};
    final out = <String, ListingImportAvailability>{};
    for (final p in products) {
      final id = p.id.trim();
      if (id.isEmpty) continue;
      if (p.isAlreadyImported) {
        out[id] = ListingImportAvailability.alreadyAdded;
      } else if (p.isImportPending) {
        out[id] = ListingImportAvailability.pending;
      }
    }
    return out;
  }

  bool _sameListingAvailability(
    Map<String, ListingImportAvailability> previous,
    List<StoreProduct> products,
  ) {
    final next = _listingAvailabilityFromProducts(products);
    if (previous.length != next.length) return false;
    for (final e in next.entries) {
      if (previous[e.key] != e.value) return false;
    }
    return true;
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
    final canView = state.isOwnStore ? true : cached.canViewContent;
    final follow =
        state.isOwnStore ? StoreFollowStatus.self : cached.followStatus;
    final nextProductCount = cached.productCount ?? state.apiProductCount;
    // Unlocking with an empty grid: mark unresolved so UI stays blank (not
    // false empty). Shimmer only after LoadCollections confirms disk+warm miss.
    final newlyUnlocked = canView && !state.canViewContent;
    final unlockingEmpty =
        newlyUnlocked && state.products.isEmpty && state.pendingUploads.isEmpty;
    final isLoadingProducts = !canView ? false : state.isLoadingProducts;
    final productsResolved =
        !canView
            ? true
            : unlockingEmpty
            ? false
            : state.productsResolved;
    emit(
      state.copyWith(
        isLoadingStoreMeta: isLoadingStoreMeta,
        isUpdatingStoreImages: isUpdatingStoreImages,
        storeName: name.isNotEmpty ? name : state.storeName,
        overrideStoreLink: link.isNotEmpty ? link : state.overrideStoreLink,
        storeImages: cached.storeImages,
        coverImageUrl: cover.isNotEmpty ? cover : state.coverImageUrl,
        city: cached.city.isNotEmpty ? cached.city : state.city,
        privacy: cached.privacy,
        followerCount: cached.followerCount,
        followingCount: cached.followingCount,
        apiProductCount: nextProductCount,
        pendingFollowRequestCount:
            state.isOwnStore ? (cached.pendingRequestsCount ?? 0) : 0,
        canViewContent: canView,
        followStatus: follow,
        infoMessage: infoMessage,
        products: canView ? state.products : const [],
        clearProductsDetailed: !canView,
        isLoadingProducts: isLoadingProducts,
        productsResolved: productsResolved,
      ),
    );
  }

  Future<void> _onLoadMembers(
    StoreProfileLoadMembers event,
    Emitter<StoreProfileState> emit,
  ) async {
    if (!state.isOwnStore || !_canLoadOwnerAdminData) {
      emit(state.copyWith(isLoadingMembers: false));
      return;
    }
    final storeId = state.storeId.trim();
    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      emit(state.copyWith(isLoadingMembers: false));
      return;
    }

    final cached = _storeMembersMemory[storeId];
    final lastAt = _storeMembersNetworkAt[storeId];
    final fresh =
        cached != null &&
        lastAt != null &&
        DateTime.now().difference(lastAt) < _storeMembersQuietTtl;
    if (fresh) {
      emit(
        state.copyWith(
          members: List<TeamMember>.from(cached),
          isLoadingMembers: false,
          currentUserId: _session.profile?.id ?? state.currentUserId,
        ),
      );
      AppLog.d(_tag, 'Skip members network store=$storeId (quiet TTL)');
      CatalogApiCallLog.markStoreProfileMilestone(reason: 'store_members_ttl');
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
      final mapped = await _fetchStoreMembersCoalesced(storeId);
      if (emit.isDone) return;
      AppLog.d(_tag, 'Loaded ${mapped.length} store members');
      emit(
        state.copyWith(
          members: mapped,
          isLoadingMembers: false,
          currentUserId: _session.profile?.id ?? state.currentUserId,
        ),
      );
      CatalogApiCallLog.markStoreProfileMilestone(reason: 'store_members');
    } catch (e) {
      AppLog.e(_tag, 'Members load failed', e);
      // Staff / non-owner must not see OWNER_REQUIRED as a switch toast.
      if (_isOwnerOnlyAdminError(e)) {
        emit(state.copyWith(isLoadingMembers: false, clearError: true));
        return;
      }
      emit(
        state.copyWith(
          isLoadingMembers: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  /// One in-flight members list per store across bloc remounts.
  Future<List<TeamMember>> _fetchStoreMembersCoalesced(String storeId) {
    final id = storeId.trim();
    final existing = _storeMembersInFlight[id];
    if (existing != null) return existing;

    final future = _fetchStoreMembersNetwork(id);
    _storeMembersInFlight[id] = future;
    future
        .then((mapped) {
          _storeMembersMemory[id] = mapped;
          _storeMembersNetworkAt[id] = DateTime.now();
        }, onError: (_) {})
        .whenComplete(() {
          if (identical(_storeMembersInFlight[id], future)) {
            _storeMembersInFlight.remove(id);
          }
        });
    return future;
  }

  Future<List<TeamMember>> _fetchStoreMembersNetwork(String storeId) async {
    // Batch 5: first page only on profile open — full cursor walk blocked
    // first paint for large teams. Remaining pages fill memory in background.
    final first = await _storeRepository.fetchMembers(
      storeId: storeId,
      limit: 50,
    );
    final all = List<StoreMember>.from(first.items);
    final mapped = await _mapEnrichedMembers(all);

    final next = first.nextCursor?.trim() ?? '';
    if (next.isNotEmpty) {
      unawaited(_fetchRemainingStoreMembers(storeId, seed: all, cursor: next));
    }
    return mapped;
  }

  Future<List<TeamMember>> _mapEnrichedMembers(List<StoreMember> all) async {
    final mapped = [for (var i = 0; i < all.length; i++) _mapMember(all[i], i)];
    try {
      final enrichedApi = await DeviceContactNames.enrichMembers(all);
      return [
        for (var i = 0; i < enrichedApi.length; i++)
          _mapMember(enrichedApi[i], i),
      ];
    } catch (_) {
      return mapped;
    }
  }

  Future<void> _fetchRemainingStoreMembers(
    String storeId, {
    required List<StoreMember> seed,
    required String cursor,
  }) async {
    try {
      final all = List<StoreMember>.from(seed);
      var next = cursor;
      while (next.isNotEmpty) {
        final page = await _storeRepository.fetchMembers(
          storeId: storeId,
          limit: 50,
          cursor: next,
        );
        all.addAll(page.items);
        next = page.nextCursor?.trim() ?? '';
      }
      final mapped = await _mapEnrichedMembers(all);
      _storeMembersMemory[storeId] = mapped;
      _storeMembersNetworkAt[storeId] = DateTime.now();
      if (isClosed || state.storeId.trim() != storeId) return;
      if (mapped.length <= state.members.length) return;
      // Soft UI refresh when still on this store (header/team chrome).
      if (state.isOwnStore && _canLoadOwnerAdminData) {
        add(const StoreProfileLoadMembers());
      }
    } catch (e) {
      AppLog.d(_tag, 'Background members pages failed store=$storeId err=$e');
    }
  }

  Future<void> _onLoadImportRequestCount(
    StoreProfileLoadImportRequestCount event,
    Emitter<StoreProfileState> emit,
  ) async {
    // TODO(backend): re-enable when GET …/stores/:id/import-requests is live
    // (ImportRepository.listStoreRequests). Endpoint 404s today.
  }

  Future<void> _onExpandAlbumCollage(
    StoreProfileExpandAlbumCollage event,
    Emitter<StoreProfileState> emit,
  ) async {
    final listingId = event.listingId.trim();
    final storeId = state.storeId.trim();
    if (listingId.isEmpty ||
        storeId.isEmpty ||
        storeId == 'my_store' ||
        storeId == 'other_store') {
      return;
    }
    // One-shot per album (§4). Failed attempts stay retryable (not marked).
    if (_expandingAlbumIds.contains(listingId) ||
        _expandedAlbumIds.contains(listingId)) {
      return;
    }

    // Swipe or pump claimed this id — drop from deferred queue.
    _pendingAlbumExpandIds.remove(listingId);

    StoreProduct? card;
    for (final p in state.productsForMedia) {
      if (p.id == listingId) {
        card = p;
        break;
      }
    }
    if (card == null || !card.needsAlbumExpand) {
      _scheduleAlbumExpandPump(afterExpand: true);
      return;
    }

    _expandingAlbumIds.add(listingId);
    try {
      final expanded = await _fetchExpandedAlbum(storeId: storeId, card: card);
      if (emit.isDone) return;
      if (expanded == null) return;

      _expandedAlbumIds.add(listingId);
      final pathsChanged = _pathsChanged(card.imagePaths, expanded.imagePaths);
      final countChanged = expanded.albumItemCount != card.albumItemCount;
      if (!pathsChanged && !countChanged) return;

      final next = [
        for (final p in state.productsForMedia)
          if (p.id == listingId) expanded else p,
      ];
      await _commitProducts(
        emit,
        storeId,
        next,
        isLoadingProducts: false,
        productsResolved: true,
      );
      AppLog.d(
        _tag,
        'Expanded album collage id=$listingId '
        'frames=${expanded.imagePaths.length}/'
        '${expanded.displayAlbumItemCount}',
      );
    } catch (e) {
      AppLog.e(_tag, 'Expand album collage failed id=$listingId', e);
    } finally {
      _expandingAlbumIds.remove(listingId);
      _scheduleAlbumExpandPump(afterExpand: true);
    }
  }

  Future<void> _onExpandAlbumBatch(
    StoreProfileExpandAlbumBatch event,
    Emitter<StoreProfileState> emit,
  ) async {
    final storeId = state.storeId.trim();
    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      return;
    }

    final cards = <String, StoreProduct>{};
    for (final rawId in event.listingIds) {
      final listingId = rawId.trim();
      if (listingId.isEmpty) continue;
      if (_expandingAlbumIds.contains(listingId) ||
          _expandedAlbumIds.contains(listingId)) {
        continue;
      }
      _pendingAlbumExpandIds.remove(listingId);
      StoreProduct? card;
      for (final p in state.productsForMedia) {
        if (p.id == listingId) {
          card = p;
          break;
        }
      }
      if (card == null || !card.needsAlbumExpand) continue;
      cards[listingId] = card;
      _expandingAlbumIds.add(listingId);
    }

    if (cards.isEmpty) {
      _scheduleAlbumExpandPump(afterExpand: true);
      return;
    }

    try {
      final results = await Future.wait([
        for (final entry in cards.entries)
          _fetchExpandedAlbum(storeId: storeId, card: entry.value).then(
            (expanded) => (
              id: entry.key,
              card: entry.value,
              expanded: expanded,
            ),
          ),
      ]);
      if (emit.isDone) return;

      var next = List<StoreProduct>.from(state.productsForMedia);
      var changed = false;
      for (final r in results) {
        final expanded = r.expanded;
        if (expanded == null) continue;
        _expandedAlbumIds.add(r.id);
        final idx = next.indexWhere((p) => p.id == r.id);
        if (idx < 0) continue;
        if (expanded.albumItemCount == next[idx].albumItemCount &&
            !_pathsChanged(next[idx].imagePaths, expanded.imagePaths)) {
          continue;
        }
        next[idx] = expanded;
        changed = true;
        AppLog.d(
          _tag,
          'Expanded album collage id=${r.id} '
          'frames=${expanded.imagePaths.length}/'
          '${expanded.displayAlbumItemCount} (batch)',
        );
      }
      if (changed) {
        await _commitProducts(
          emit,
          storeId,
          next,
          isLoadingProducts: false,
          productsResolved: true,
        );
      }
    } catch (e) {
      AppLog.e(_tag, 'Expand album batch failed', e);
    } finally {
      for (final id in cards.keys) {
        _expandingAlbumIds.remove(id);
      }
      _scheduleAlbumExpandPump(afterExpand: true);
    }
  }

  bool _pathsChanged(List<String> a, List<String> b) {
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return true;
    }
    return false;
  }

  /// Returns updated card, or null on failure. Marks nothing — caller owns sets.
  Future<StoreProduct?> _fetchExpandedAlbum({
    required String storeId,
    required StoreProduct card,
  }) async {
    final listingId = card.id.trim();
    try {
      final limit =
          card.displayAlbumItemCount > 100
              ? 100
              : (card.displayAlbumItemCount < 9
                  ? 9
                  : card.displayAlbumItemCount);
      final page = await _collectionRepository.listStoreProducts(
        storeId: storeId,
        collectionId: listingId,
        limit: limit,
      );

      final exhausted =
          page.items.isEmpty || !page.hasMore || page.items.length < limit;

      if (page.items.isEmpty) {
        return _clampAlbumCountIfExhausted(card, exhausted: true);
      }

      var expanded = CatalogUiMapper.expandCollectionCard(
        card: card,
        products: page.items,
        albumExhausted: exhausted,
      );
      return _clampAlbumCountIfExhausted(expanded, exhausted: exhausted);
    } catch (e) {
      AppLog.e(_tag, 'Expand album fetch failed id=$listingId', e);
      return null;
    }
  }

  Future<void> _onProbeImportAvailability(
    StoreProfileProbeImportAvailability event,
    Emitter<StoreProfileState> emit,
  ) async {
    // Legacy N× GET /import-targets removed (often 404 stubs). Badges come
    // from list/product import flags via _listingAvailabilityFromProducts.
    if (state.isOwnStore || !state.canImport) return;
    final products = state.products;
    if (products.isEmpty) return;
    final availability = _listingAvailabilityFromProducts(products);
    ImportQa.step(
      'Source products (visitor flags)',
      detail:
          'store=${state.storeId} cards=${products.length} '
          'flagBadges=${availability.length}',
    );
    if (emit.isDone) return;
    emit(state.copyWith(listingAvailability: availability));
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
      // Disk unlock must not wait for GET store — start collections now so
      // reopen paints from products cache during the meta network round-trip.
      if (!state.isOwnStore) {
        _requestInitialCollections();
      }
    } else if (state.coverImageUrl.trim().isNotEmpty) {
      unawaited(CatalogImageCache.precacheUrls([state.coverImageUrl]));
      emit(state.copyWith(isLoadingStoreMeta: true, clearError: true));
    } else {
      emit(state.copyWith(isLoadingStoreMeta: true, clearError: true));
    }

    // Soft open path: skip duplicate GET /stores/:id within TTL (remount /
    // double Ensure). Mutations pass force: true.
    if (!event.force) {
      final last = _storeMetaNetworkAt[storeId];
      if (last != null &&
          DateTime.now().difference(last) < _storeMetaQuietTtl) {
        AppLog.d(_tag, 'Skip store meta network store=$storeId (quiet TTL)');
        emit(state.copyWith(isLoadingStoreMeta: false));
        CatalogApiCallLog.markStoreProfileMilestone(
          reason: 'store_meta_ttl_skip',
        );
        return;
      }
    }

    try {
      final previousFollow = state.followStatus;
      final store = await _fetchStoreMetaCoalesced(storeId, force: event.force);
      if (emit.isDone) return;
      AppLog.d(
        _tag,
        'Store meta loaded images=${store.images.length} '
        'cover=${store.coverImageUrl.isNotEmpty} '
        'privacy=${store.privacy?.apiValue} '
        'canView=${store.resolvedCanViewContent} '
        'follow=${store.followStatusRaw} '
        'notifyUploads=${store.notifyUploads}',
      );
      final previouslyCouldView = state.canViewContent;
      final snapshot = StoreMetaSnapshot.fromCatalogStore(store);
      // Promote to catalogue chrome only while already acting as this store.
      // Personal + owner/member relationship must not gain Add (STORE_PROFILE_REQUIRED).
      final actingId = _session.activeStoreId?.trim() ?? '';
      final actingAsThisStore =
          actingId.isNotEmpty && actingId == storeId.trim();
      final promoteToCatalogue =
          !state.isOwnStore &&
          actingAsThisStore &&
          (store.isOwn || store.relationship == StoreRelationship.member);
      if (promoteToCatalogue) {
        emit(
          state.copyWith(
            isOwnStore: true,
            followStatus: StoreFollowStatus.self,
          ),
        );
        if (_session.isActingAsOwner) {
          add(const StoreProfileLoadMembers());
        }
      }
      await _commitStoreMeta(
        emit,
        storeId,
        snapshot,
        isLoadingStoreMeta: false,
      );
      if (emit.isDone) return;
      if (!state.isOwnStore && state.followStatus.isFollowing) {
        if (store.notifyUploads != null) {
          emit(state.copyWith(notifyUploads: store.notifyUploads));
        } else if (previousFollow.isPending) {
          // Private store just approved — enable upload push to match bell ON.
          emit(state.copyWith(notifyUploads: true));
          await _enableNotifyUploads(storeId, emit);
        }
      }
      if (!state.isOwnStore) {
        if (state.canViewContent) {
          // First unlock after cold meta, or still empty after disk kick.
          if (!previouslyCouldView) {
            _requestInitialCollections(allowAfterUnlock: true);
          } else if (state.products.isEmpty) {
            _requestInitialCollections();
          }
        }
      } else if (_canLoadOwnerAdminData &&
          state.privacy.isPrivate &&
          state.pendingFollowRequestCount > 0) {
        add(const StoreProfileLoadFollowRequestPreviews());
      }
      CatalogApiCallLog.markStoreProfileMilestone(reason: 'store_meta');
    } catch (e) {
      AppLog.e(_tag, 'Load store meta failed', e);
      emit(state.copyWith(isLoadingStoreMeta: false));
      CatalogApiCallLog.markStoreProfileMilestone(reason: 'store_meta_error');
    }
  }

  /// Soft opens share one in-flight `GET /stores/:id` across bloc remounts.
  ///
  /// Batch 5: soft joins in-flight. [force] awaits any in-flight GET then
  /// starts a fresh one (no parallel duplicate; follow/privacy still see
  /// post-mutation meta).
  Future<CatalogStore> _fetchStoreMetaCoalesced(
    String storeId, {
    bool force = false,
  }) async {
    final id = storeId.trim();
    final existing = _storeMetaInFlight[id];
    if (existing != null) {
      if (!force) return existing;
      try {
        await existing;
      } catch (_) {}
      final again = _storeMetaInFlight[id];
      if (again != null) return again;
    }

    final future = _storeRepository.fetchStore(id);
    _storeMetaInFlight[id] = future;
    try {
      final store = await future;
      _storeMetaNetworkAt[id] = DateTime.now();
      return store;
    } finally {
      if (identical(_storeMetaInFlight[id], future)) {
        _storeMetaInFlight.remove(id);
      }
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
          errorMessage:
              'A store can have at most ${StoreRequest.maxStoreImages} showcase images.',
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
      AppLog.e(_tag, 'Delete store images failed', e);
      emit(
        state.copyWith(
          isUpdatingStoreImages: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _onFollowPressed(
    StoreProfileFollowPressed event,
    Emitter<StoreProfileState> emit,
  ) async {
    if (state.isOwnStore || state.isFollowBusy) return;
    // Owner/member rows use followStatus self — never Follow yourself.
    if (state.followStatus == StoreFollowStatus.self ||
        state.followStatus == StoreFollowStatus.member) {
      return;
    }
    if (state.followStatus.isFollowing || state.followStatus.isPending) return;
    final storeId = state.storeId;
    if (storeId.isEmpty || storeId == 'other_store') return;

    emit(state.copyWith(isFollowBusy: true, clearError: true));
    try {
      final result = await _storeRepository.followStore(storeId);
      if (emit.isDone) return;
      // Slim follow payloads must not be parsed as a CatalogStore — that
      // incorrectly unlocked private content (privacy omitted → treated public).
      final canView = result.canViewContentAfterAction;
      final snap = StoreMetaSnapshot(
        storeName: state.storeName,
        storeLink: state.overrideStoreLink ?? state.storeLink,
        coverImageUrl: state.coverImageUrl,
        storeImages: state.storeImages,
        city: state.city,
        privacy: state.privacy,
        followerCount: result.followerCount ?? state.followerCount,
        followingCount: state.followingCount,
        productCount: state.apiProductCount,
        pendingRequestsCount: result.pendingRequestsCount,
        canViewContent: canView,
        followStatus: result.status,
      );
      await _commitStoreMeta(emit, storeId, snap, isLoadingStoreMeta: false);
      if (emit.isDone) return;
      // UI defaults bell ON; must PATCH so backend sends `new_upload` pushes.
      emit(state.copyWith(isFollowBusy: false, notifyUploads: true));
      if (result.isFollowing) {
        await _enableNotifyUploads(storeId, emit);
      }
      // Quiet refresh for accurate counts / canView from GET store.
      add(const StoreProfileLoadStoreMeta(force: true));
      if (canView) {
        add(const StoreProfileLoadCollections());
      }
    } on CatalogApiException catch (e) {
      AppLog.e(_tag, 'Follow failed', e);
      if (e.code == 'ALREADY_FOLLOWING') {
        await _applyFollowRecovery(
          emit,
          storeId,
          StoreFollowStatus.following,
          canView: true,
        );
        return;
      }
      if (e.code == 'FOLLOW_REQUEST_ALREADY_PENDING') {
        await _applyFollowRecovery(
          emit,
          storeId,
          StoreFollowStatus.pending,
          canView: false,
        );
        return;
      }
      emit(
        state.copyWith(
          isFollowBusy: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Follow failed', e);
      emit(
        state.copyWith(
          isFollowBusy: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _onUnfollowPressed(
    StoreProfileUnfollowPressed event,
    Emitter<StoreProfileState> emit,
  ) async {
    if (state.isOwnStore || state.isFollowBusy) return;
    if (state.followStatus == StoreFollowStatus.none) return;
    final storeId = state.storeId;
    if (storeId.isEmpty || storeId == 'other_store') return;

    emit(state.copyWith(isFollowBusy: true, clearError: true));
    try {
      await _storeRepository.unfollowStore(storeId);
      if (emit.isDone) return;
      final canView = state.privacy == StorePrivacyMode.private ? false : true;
      final snap = StoreMetaSnapshot(
        storeName: state.storeName,
        storeLink: state.overrideStoreLink ?? state.storeLink,
        coverImageUrl: state.coverImageUrl,
        storeImages: state.storeImages,
        city: state.city,
        privacy: state.privacy,
        followerCount: state.followerCount,
        followingCount: state.followingCount,
        productCount: state.apiProductCount,
        canViewContent: canView,
        followStatus: StoreFollowStatus.none,
      );
      await _commitStoreMeta(emit, storeId, snap, isLoadingStoreMeta: false);
      if (emit.isDone) return;
      emit(state.copyWith(isFollowBusy: false));
      add(const StoreProfileLoadStoreMeta(force: true));
      if (canView && state.products.isEmpty) {
        add(const StoreProfileLoadCollections());
      }
    } on CatalogApiException catch (e) {
      AppLog.e(_tag, 'Unfollow failed', e);
      if (e.code == 'FOLLOW_NOT_FOUND') {
        await _applyFollowRecovery(
          emit,
          storeId,
          StoreFollowStatus.none,
          canView: state.privacy != StorePrivacyMode.private,
        );
        return;
      }
      emit(
        state.copyWith(
          isFollowBusy: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Unfollow failed', e);
      emit(
        state.copyWith(
          isFollowBusy: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _applyFollowRecovery(
    Emitter<StoreProfileState> emit,
    String storeId,
    StoreFollowStatus status, {
    required bool canView,
  }) async {
    final snap = StoreMetaSnapshot(
      storeName: state.storeName,
      storeLink: state.overrideStoreLink ?? state.storeLink,
      coverImageUrl: state.coverImageUrl,
      storeImages: state.storeImages,
      city: state.city,
      privacy: state.privacy,
      followerCount: state.followerCount,
      followingCount: state.followingCount,
      productCount: state.apiProductCount,
      canViewContent: canView,
      followStatus: status,
    );
    await _commitStoreMeta(emit, storeId, snap, isLoadingStoreMeta: false);
    if (emit.isDone) return;
    emit(state.copyWith(isFollowBusy: false));
    add(const StoreProfileLoadStoreMeta(force: true));
    if (canView) add(const StoreProfileLoadCollections());
  }

  Future<void> _onLoadFollowRequestPreviews(
    StoreProfileLoadFollowRequestPreviews event,
    Emitter<StoreProfileState> emit,
  ) async {
    if (!state.isOwnStore || !_canLoadOwnerAdminData) return;
    final storeId = state.storeId;
    if (storeId.isEmpty || storeId == 'my_store') return;
    try {
      final page = await _storeRepository.fetchFollowRequests(
        storeId: storeId,
        limit: 20,
      );
      if (emit.isDone) return;
      final pending =
          page.items
              .where((e) => e.uiStatus == FollowRequestUiStatus.pending)
              .toList();
      emit(
        state.copyWith(
          pendingFollowRequestCount: pending.length,
          followRequestPreviewNames: pending
              .take(2)
              .map((e) => e.name)
              .toList(growable: false),
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Follow request previews failed', e);
    }
  }

  bool _isOwnerOnlyAdminError(Object e) {
    if (e is! CatalogApiException) return false;
    switch (e.code) {
      case 'OWNER_REQUIRED':
      case 'UPLOAD_OWNER_REQUIRED':
      case 'PROFILE_STORE_MISMATCH':
      case 'STORE_PROFILE_REQUIRED':
        return true;
      default:
        return false;
    }
  }

  Future<void> _onToggleNotifyUploads(
    StoreProfileToggleNotifyUploads event,
    Emitter<StoreProfileState> emit,
  ) async {
    if (!state.followStatus.isFollowing) return;
    final next = !state.notifyUploads;
    emit(state.copyWith(notifyUploads: next));
    try {
      final confirmed = await _storeRepository.patchFollowNotifyUploads(
        storeId: state.storeId,
        notifyUploads: next,
      );
      if (confirmed != next) {
        emit(state.copyWith(notifyUploads: confirmed));
      }
    } catch (e) {
      AppLog.e(_tag, 'Toggle notifyUploads failed', e);
      emit(state.copyWith(notifyUploads: !next));
    }
  }

  /// Aligns server follow preference with the ON bell (upload push).
  Future<void> _enableNotifyUploads(
    String storeId,
    Emitter<StoreProfileState> emit,
  ) async {
    try {
      final confirmed = await _storeRepository.patchFollowNotifyUploads(
        storeId: storeId,
        notifyUploads: true,
      );
      if (emit.isDone) return;
      emit(state.copyWith(notifyUploads: confirmed));
      AppLog.d(_tag, 'notifyUploads enabled store=$storeId → $confirmed');
    } catch (e) {
      // Keep local bell ON; user can re-toggle. Upload push stays off until OK.
      AppLog.e(_tag, 'enable notifyUploads failed store=$storeId', e);
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
      emit(state.copyWith(products: next, productsDetailed: next));
      return;
    }
    await _commitProducts(emit, storeId, next);
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
    // Silent pops often carry a nested product id (details from collection
    // browse). Never invent a new top-level listing for those — that showed
    // as a ghost "Title (1 item)" card until the next collections refresh.
    if (!replaced) {
      if (event.silent) return;
      next.insert(0, updated);
    }
    final storeId = state.storeId;
    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      emit(
        state.copyWith(
          products: next,
          productsDetailed: next,
          infoMessage: event.silent ? null : 'Product updated.',
        ),
      );
      return;
    }
    await _commitProducts(
      emit,
      storeId,
      next,
      infoMessage: event.silent ? null : 'Product updated.',
    );
    if (!event.silent) {
      add(const StoreProfileQuietRefreshCollections());
    }
  }

  Future<void> _onProductDeleted(
    StoreProfileProductDeleted event,
    Emitter<StoreProfileState> emit,
  ) async {
    final productId = event.productId.trim();
    if (productId.isEmpty || state.deletingProductId != null) return;

    final storeId = state.storeId;
    final nestedStripped = OwnerItemDelete.stripDeletedIds(
      products: state.products,
      deletedIds: {productId},
    );
    final wasNested =
        nestedStripped.length != state.products.length ||
        !_sameProductIds(nestedStripped, state.products);
    final isListing = state.products.any((p) => p.id.trim() == productId);

    List<StoreProduct> withoutListing(List<StoreProduct> source) =>
        source.where((p) => p.id != productId).toList();

    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      final next = wasNested ? nestedStripped : withoutListing(state.products);
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
      // Nested jewel (or details already deleted): prefer product delete.
      if (wasNested && !isListing) {
        try {
          await _collectionRepository.deleteProduct(productId: productId);
          AppLog.d(_tag, 'Deleted nested product $productId');
        } on CatalogApiException catch (e) {
          final gone =
              e.statusCode == 404 ||
              e.code == 'PRODUCT_NOT_FOUND' ||
              e.code == 'NOT_FOUND' ||
              e.code == 'COLLECTION_NOT_FOUND';
          if (!gone) rethrow;
          AppLog.d(_tag, 'Nested product $productId already gone');
        }
        // Last item in a collage → remove the empty parent collection.
        for (final parent in state.products) {
          final had = parent.photoAssetIds.any((id) => id.trim() == productId);
          if (!had) continue;
          final still = nestedStripped.any((p) => p.id == parent.id);
          if (still) continue;
          try {
            await _collectionRepository.deleteCollection(
              storeId: storeId,
              listingId: parent.id,
            );
            AppLog.d(_tag, 'Deleted emptied parent listing ${parent.id}');
          } catch (e) {
            AppLog.e(_tag, 'Empty parent delete failed ${parent.id}', e);
          }
        }
        await _commitProducts(
          emit,
          storeId,
          nestedStripped,
          infoMessage: 'Product deleted.',
          clearDeletingProductId: true,
        );
        add(const StoreProfileQuietRefreshCollections());
        return;
      }

      // Whole listing / collection.
      try {
        await _collectionRepository.deleteProduct(productId: productId);
        AppLog.d(_tag, 'Deleted product $productId');
      } on CatalogApiException catch (e) {
        final missingProduct =
            e.statusCode == 404 ||
            e.code == 'PRODUCT_NOT_FOUND' ||
            e.code == 'NOT_FOUND';
        if (!missingProduct) rethrow;
        await _collectionRepository.deleteCollection(
          storeId: storeId,
          listingId: productId,
        );
        AppLog.d(_tag, 'Deleted collection $productId (product 404 fallback)');
      }
      await _commitProducts(
        emit,
        storeId,
        withoutListing(state.products),
        infoMessage: 'Product deleted.',
        clearDeletingProductId: true,
      );
      add(const StoreProfileQuietRefreshCollections());
    } catch (e) {
      AppLog.e(_tag, 'Delete product/collection failed', e);
      final alreadyGone =
          e is CatalogApiException &&
          (e.statusCode == 404 ||
              e.code == 'COLLECTION_NOT_FOUND' ||
              e.code == 'PRODUCT_NOT_FOUND' ||
              e.code == 'NOT_FOUND');
      if (alreadyGone) {
        final next =
            wasNested ? nestedStripped : withoutListing(state.products);
        await _commitProducts(
          emit,
          storeId,
          next,
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

  bool _sameProductIds(List<StoreProduct> a, List<StoreProduct> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
      if (a[i].imagePaths.length != b[i].imagePaths.length) return false;
    }
    return true;
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
              deleted == 1 ? 'Product deleted.' : '$deleted products deleted.',
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

  Future<void> _onItemsDeleted(
    StoreProfileItemsDeleted event,
    Emitter<StoreProfileState> emit,
  ) async {
    final keys =
        event.photoKeys.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (keys.isEmpty || state.deletingProductId != null) return;

    final storeId = state.storeId;
    final products =
        state.productsForMedia.isNotEmpty
            ? state.productsForMedia
            : state.products;

    Map<String, String> targets;
    try {
      targets = await OwnerItemDelete.resolveTargets(
        photoKeys: keys,
        products: products,
        storeId: storeId,
        collections: _collectionRepository,
      );
    } catch (e) {
      AppLog.e(_tag, 'Resolve item delete targets failed', e);
      emit(state.copyWith(errorMessage: CatalogErrorMapper.toUserMessage(e)));
      return;
    }
    if (targets.isEmpty) {
      emit(state.copyWith(errorMessage: 'Could not resolve selected items.'));
      return;
    }

    // Group legacy photo ids by listing; product deletes are per-id.
    final productIds = <String>{};
    final legacyByListing = <String, Set<String>>{};
    final listingIdsTouched = <String>{};
    for (final entry in targets.entries) {
      final id = entry.key.trim();
      final listingId = entry.value.trim();
      if (id.isEmpty || listingId.isEmpty) continue;
      listingIdsTouched.add(listingId);
      if (OwnerItemDelete.isLegacyPhotoId(id)) {
        legacyByListing.putIfAbsent(listingId, () => <String>{}).add(id);
      } else {
        productIds.add(id);
      }
    }

    // Listings where every frame is selected → delete whole collection.
    final deleteWholeListings = <String>{};
    final byId = {for (final p in products) p.id: p};
    for (final listingId in listingIdsTouched) {
      final card = byId[listingId];
      if (card == null) continue;
      final selectedKeysForListing = keys.where(
        (k) => k.startsWith('$listingId|'),
      );
      final selectedIndexes = <int>{
        for (final k in selectedKeysForListing)
          int.tryParse(k.substring(listingId.length + 1)) ?? -1,
      }..removeWhere((i) => i < 0);
      final frameCount = card.imagePaths.isEmpty ? 1 : card.imagePaths.length;
      if (selectedIndexes.length >= frameCount) {
        deleteWholeListings.add(listingId);
      }
    }

    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      final next = OwnerItemDelete.stripDeletedIds(
        products: state.products,
        deletedIds: {...productIds, ...deleteWholeListings},
      );
      emit(
        state.copyWith(
          products: next,
          productsDetailed: next,
          infoMessage:
              keys.length == 1
                  ? 'Item deleted.'
                  : '${keys.length} items deleted.',
        ),
      );
      return;
    }

    var failed = 0;
    final deletedIds = <String>{...deleteWholeListings};

    for (final listingId in deleteWholeListings) {
      emit(state.copyWith(deletingProductId: listingId, clearError: true));
      try {
        await _collectionRepository.deleteCollection(
          storeId: storeId,
          listingId: listingId,
        );
        AppLog.d(_tag, 'Deleted whole listing $listingId (all items selected)');
      } catch (e) {
        AppLog.e(_tag, 'Whole listing delete failed for $listingId', e);
        final gone =
            e is CatalogApiException &&
            (e.statusCode == 404 || e.code == 'COLLECTION_NOT_FOUND');
        if (!gone) failed++;
      }
    }

    for (final productId in productIds) {
      if (deleteWholeListings.contains(targets[productId])) continue;
      emit(state.copyWith(deletingProductId: productId, clearError: true));
      try {
        await _collectionRepository.deleteProduct(productId: productId);
        deletedIds.add(productId);
        AppLog.d(_tag, 'Deleted item product $productId');
      } on CatalogApiException catch (e) {
        final gone =
            e.statusCode == 404 ||
            e.code == 'PRODUCT_NOT_FOUND' ||
            e.code == 'NOT_FOUND';
        if (gone) {
          deletedIds.add(productId);
        } else {
          AppLog.e(_tag, 'Item product delete failed for $productId', e);
          failed++;
        }
      } catch (e) {
        AppLog.e(_tag, 'Item product delete failed for $productId', e);
        failed++;
      }
    }

    for (final entry in legacyByListing.entries) {
      final listingId = entry.key;
      if (deleteWholeListings.contains(listingId)) continue;
      final photoIds = entry.value.toList(growable: false);
      if (photoIds.isEmpty) continue;
      emit(state.copyWith(deletingProductId: listingId, clearError: true));
      try {
        await _collectionRepository.deletePhotos(
          storeId: storeId,
          listingId: listingId,
          photoIds: photoIds,
        );
        deletedIds.addAll(photoIds);
        AppLog.d(
          _tag,
          'Deleted ${photoIds.length} photos from listing $listingId',
        );
      } catch (e) {
        AppLog.e(_tag, 'Photo delete failed for $listingId', e);
        failed++;
      }
    }

    // If deleting nested items emptied a listing, drop the collection too.
    for (final listingId in listingIdsTouched) {
      if (deleteWholeListings.contains(listingId)) continue;
      final card = byId[listingId];
      if (card == null) continue;
      final emptied = OwnerItemDelete.isListingEmptied(card, deletedIds);
      final strippedAway =
          !OwnerItemDelete.stripDeletedIds(
            products: [card],
            deletedIds: deletedIds,
          ).any((p) => p.id == listingId);
      if (!emptied && !strippedAway) continue;

      emit(state.copyWith(deletingProductId: listingId, clearError: true));
      // Always drop from local grid even if collection delete fails — quiet
      // refresh will omit empty collections (photoCount==0 / no products).
      deletedIds.add(listingId);
      try {
        await _collectionRepository.deleteCollection(
          storeId: storeId,
          listingId: listingId,
        );
        AppLog.d(_tag, 'Deleted emptied listing $listingId');
      } catch (e) {
        AppLog.e(_tag, 'Empty listing delete failed for $listingId', e);
        final gone =
            e is CatalogApiException &&
            (e.statusCode == 404 || e.code == 'COLLECTION_NOT_FOUND');
        if (!gone) failed++;
      }
    }

    // Also force-drop whole listings selected in full (API may have failed).
    deletedIds.addAll(deleteWholeListings);

    final next = OwnerItemDelete.stripDeletedIds(
      products: state.products,
      deletedIds: deletedIds,
    );
    // Also strip from detailed albums when present.
    final nextDetailed =
        state.productsDetailed.isEmpty
            ? next
            : OwnerItemDelete.stripDeletedIds(
              products: state.productsDetailed,
              deletedIds: deletedIds,
            );

    await StoreProductsCache.instance.write(storeId, nextDetailed);
    final info =
        deletedIds.isEmpty
            ? null
            : (deletedIds.length <= 1
                ? 'Item deleted.'
                : '${deletedIds.length} items deleted.');
    final err =
        failed == 0
            ? null
            : (deletedIds.isEmpty
                ? 'Could not delete items.'
                : 'Some items could not be deleted.');
    emit(
      state.copyWith(
        products: next,
        productsDetailed: nextDetailed,
        clearDeletingProductId: true,
        clearInfoMessage: info == null,
        clearError: err == null,
        infoMessage: info,
        errorMessage: err,
      ),
    );
    if (deletedIds.isNotEmpty) {
      add(const StoreProfileQuietRefreshCollections());
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
    if (!event.silent) {
      add(const StoreProfileQuietRefreshCollections());
    }
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
    // Retry clears this id first; success keeps it finished.
    if (_finishedUploadIds.contains(pending.id)) return;
    final index = state.pendingUploads.indexWhere((p) => p.id == pending.id);
    if (index >= 0) {
      // Retry / re-seed — replace the failed or stale tile in place.
      final next = [...state.pendingUploads];
      next[index] = pending;
      emit(state.copyWith(pendingUploads: next, clearError: true));
      return;
    }
    emit(
      state.copyWith(
        pendingUploads: [pending, ...state.pendingUploads],
        clearError: true,
      ),
    );
  }

  void _onPendingUploadProgress(
    StoreProfilePendingUploadProgress event,
    Emitter<StoreProfileState> emit,
  ) {
    if (_finishedUploadIds.contains(event.pendingId)) return;
    final index = state.pendingUploads.indexWhere(
      (p) => p.id == event.pendingId,
    );
    if (index < 0) return;
    final current = state.pendingUploads[index];
    // Commit already landed — ignore late S3 progress during tick reveal.
    if (current.isRevealing) return;
    final updated = current.copyWith(
      photos: event.photos,
      photoCount:
          event.photos.isNotEmpty ? event.photos.length : current.photoCount,
      isCommitting: event.isCommitting,
    );
    if (updated == current) return;
    final next = [...state.pendingUploads];
    next[index] = updated;
    emit(state.copyWith(pendingUploads: next));
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
        if (p.id == event.pendingId) p.copyWith(listingId: listingId) else p,
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
    final published = event.product.copyWith(
      canEdit: event.product.canEdit || state.isOwnStore,
      canDelete: event.product.canDelete || state.isOwnStore,
    );
    final partial =
        event.partialMessage?.trim().isNotEmpty == true
            ? event.partialMessage!.trim()
            : null;

    final index = state.pendingUploads.indexWhere(
      (p) => p.id == event.pendingId,
    );
    // No pending tile (left mid-flight) — commit product immediately.
    if (index < 0) {
      await _finalizePublishedUpload(
        emit,
        pendingId: event.pendingId,
        published: published,
        partialMessage: partial,
      );
      return;
    }

    // Hold product; UI staggers checks one-by-one, then reveal-finished.
    _pendingReveals[event.pendingId] = (
      product: published,
      partialMessage: partial,
    );
    final current = state.pendingUploads[index];
    if (current.isRevealing) return;
    final next = [...state.pendingUploads];
    next[index] = current.copyWith(isRevealing: true, isCommitting: false);
    emit(state.copyWith(pendingUploads: next));
  }

  Future<void> _onPendingRevealFinished(
    StoreProfilePendingRevealFinished event,
    Emitter<StoreProfileState> emit,
  ) async {
    final held = _pendingReveals.remove(event.pendingId);
    if (held == null) {
      // Reveal already finalized or success never held — drop pending only.
      final nextPending =
          state.pendingUploads.where((p) => p.id != event.pendingId).toList();
      if (nextPending.length != state.pendingUploads.length) {
        emit(state.copyWith(pendingUploads: nextPending));
      }
      return;
    }
    await _finalizePublishedUpload(
      emit,
      pendingId: event.pendingId,
      published: held.product,
      partialMessage: held.partialMessage,
    );
  }

  Future<void> _finalizePublishedUpload(
    Emitter<StoreProfileState> emit, {
    required String pendingId,
    required StoreProduct published,
    String? partialMessage,
  }) async {
    final nextPending =
        state.pendingUploads.where((p) => p.id != pendingId).toList();
    final withoutDup =
        state.products.where((p) => p.id != published.id).toList();
    final next = [published, ...withoutDup];
    // Success is silent (product appears in grid). Only surface partial
    // upload failures (e.g. some photos failed).
    final partial =
        partialMessage?.trim().isNotEmpty == true
            ? partialMessage!.trim()
            : null;

    final storeId = state.storeId;
    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      emit(
        state.copyWith(
          pendingUploads: nextPending,
          products: next,
          productsDetailed: next,
          infoMessage: partial,
        ),
      );
      return;
    }
    await _commitProducts(
      emit,
      storeId,
      next,
      infoMessage: partial,
      pendingUploads: nextPending,
    );
    add(const StoreProfileQuietRefreshCollections());
  }

  void _onPendingUploadFailed(
    StoreProfilePendingUploadFailed event,
    Emitter<StoreProfileState> emit,
  ) {
    _pendingReveals.remove(event.pendingId);
    // Do not mark finished — user can tap close icon to retry.
    final index = state.pendingUploads.indexWhere(
      (p) => p.id == event.pendingId,
    );
    final fromCoord =
        _uploadCoordinator
            .pendingForStore(state.storeId)
            .where((p) => p.id == event.pendingId)
            .toList();
    final failed =
        fromCoord.isNotEmpty
            ? fromCoord.first
            : (index >= 0
                ? state.pendingUploads[index].copyWith(
                  hasFailed: true,
                  failureMessage: event.message,
                  isRevealing: false,
                  isCommitting: false,
                  photos: [
                    for (final photo in state.pendingUploads[index].photos)
                      photo.copyWith(status: PendingPhotoStatus.failed),
                  ],
                )
                : null);
    if (failed == null) {
      emit(state.copyWith(errorMessage: event.message));
      return;
    }
    final next = [...state.pendingUploads];
    if (index >= 0) {
      next[index] = failed;
    } else {
      next.insert(0, failed);
    }
    emit(state.copyWith(pendingUploads: next, errorMessage: event.message));
  }

  void _onPendingUploadRetry(
    StoreProfilePendingUploadRetry event,
    Emitter<StoreProfileState> emit,
  ) {
    final id = event.pendingId.trim();
    if (id.isEmpty) return;
    _finishedUploadIds.remove(id);
    _pendingReveals.remove(id);
    final ok = _uploadCoordinator.retryPending(id);
    if (!ok) {
      emit(
        state.copyWith(
          errorMessage: 'Could not retry upload. Try publishing again.',
        ),
      );
      return;
    }
    // Optimistic UI — loaders again until coordinator Started/Progress lands.
    final index = state.pendingUploads.indexWhere((p) => p.id == id);
    if (index < 0) return;
    final current = state.pendingUploads[index];
    final resetPhotos = [
      for (final photo in current.photos)
        PendingPhotoSlot(localPath: photo.localPath),
    ];
    final next = [...state.pendingUploads];
    next[index] = PendingProductUpload(
      id: current.id,
      storeId: current.storeId,
      title: current.title,
      photoCount:
          resetPhotos.isNotEmpty ? resetPhotos.length : current.photoCount,
      photos: resetPhotos,
    );
    emit(state.copyWith(pendingUploads: next, clearError: true));
  }

  @override
  Future<void> close() {
    _clearAlbumExpandQueue(resetIdleGate: true);
    StoreWarmQa.step(
      'PROFILE_CLOSE',
      detail: 'store=${state.storeId} owner=${_imageWarmOwner.debugLabel}',
    );
    // Batch 7A: only this profile's warm lease — route dispose does not cancel.
    CatalogImageCache.cancelOffscreenWarm(
      _imageWarmOwner,
      reason: 'storeProfileBlocClose',
    );
    StoreProductsPrefetcher.instance.cancelCollageWarmForStore(state.storeId);
    StoreWarmQa.endOpenSession(reason: 'profileClose');
    unawaited(_uploadSub?.cancel() ?? Future<void>.value());
    return super.close();
  }
}
