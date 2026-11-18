import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/catalog_api_call_log.dart';
import 'package:project_c/helper/catalog_ui_mapper.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/store_warm_qa.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/services/product_upload_coordinator.dart';
import 'package:project_c/storage/store_meta_cache.dart';
import 'package:project_c/storage/store_products_cache.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';

/// Warms enriched products + collage image files **before** store profile opens.
///
/// Single enrich path shared with [StoreProfileBloc] quiet refresh (API-2 / BE-2):
/// `listCollections?include=products&productsLimit=9` → map embedded `products[]`
/// when present → legacy `products?collectionId=` / `fetchCollection` only when
/// embedded is empty but `photoCount > 0`.
///
/// Call [prefetch] on store tap (never block navigation). Batch I2:
/// [setListingCatalog] + [noteListingVisibility] enrich stores that are
/// actually in the Home viewport (not list order alone).
/// [ensure] / [refresh] coalesce in-flight work; quiet [refresh] with
/// `force: false` skips when last network was within [quietRefreshTtl].
class StoreProductsPrefetcher {
  StoreProductsPrefetcher._();

  static final StoreProductsPrefetcher instance = StoreProductsPrefetcher._();

  static const _tag = 'StoreProductsPrefetcher';

  /// Frames to hydrate per collage card (Group album first page).
  static const collageProductLimit = 9;

  /// First ~2 Group rows — warm these before albums further down (Plan A1).
  static const firstPaintAlbumWarmCount = 4;

  /// Soft quiet refresh — skip network if enriched within this window.
  static const quietRefreshTtl = Duration(seconds: 45);

  /// Batch I2 — max viewport rows considered for cover warm / enrich candidates.
  static const listingVisibleCandidateLimit = 4;

  /// Batch I2 — max stores to soft-enrich from Home at once.
  static const listingEnrichLimit = 3;

  /// Batch I2 — parallel listing enrich GETs.
  static const listingEnrichMaxConcurrent = 2;

  /// Batch I2 — rows just below the viewport to prime next scroll.
  static const listingUpcomingCount = 2;

  /// Fraction of tile height that must be on-screen to count as visible.
  static const listingVisibilityMinFraction = 0.2;

  static const _listingVisibilityDebounce = Duration(milliseconds: 180);

  /// Delay decode so open transition is not fighting image work.
  static const _collageDecodeWarmDelay = Duration(milliseconds: 360);

  /// After visible albums, warm the rest of the grid.
  static const _collageDecodeRestDelay = Duration(milliseconds: 220);

  final Map<String, Future<List<StoreProduct>>> _inFlight = {};
  final Map<String, DateTime> _lastNetworkAt = {};

  /// Last store the user opened — idle listing warm prioritizes this id.
  String? _lastOpenedStoreId;

  /// Collage warm lease for the current [_lastOpenedStoreId] (Batch 7A).
  CatalogWarmOwner? _collageWarmOwner;
  String? _collageWarmStoreId;

  /// Stores whose Discover profile closed before collage warm was leased.
  /// Cleared on next [prefetch] / [noteProfileOpened] so reopen can warm again.
  /// Prevents late [ensure]/[refresh] from starting decode after leave (Flow 3).
  final Set<String> _collageWarmSuppressed = <String>{};

  /// Home list order (id + cover) for upcoming-row selection.
  List<({String id, String coverImageUrl})> _listingCatalog = const [];

  /// storeId → latest visible fraction from [VisibilityDetector].
  final Map<String, double> _listingVisibility = {};

  /// Desired enrich set from the latest viewport recompute.
  final LinkedHashSet<String> _listingEnrichWanted = LinkedHashSet<String>();

  final Queue<String> _listingEnrichQueue = Queue<String>();
  final Set<String> _listingEnrichRunningIds = <String>{};
  int _listingEnrichRunning = 0;
  bool _listingPrefetchPaused = false;
  bool _listingHasRealVisibility = false;
  Timer? _listingViewportDebounce;

  /// True when a network enrich finished within [quietRefreshTtl].
  bool isFresh(String storeId) {
    final id = storeId.trim();
    if (id.isEmpty) return false;
    final last = _lastNetworkAt[id];
    if (last == null) return false;
    return DateTime.now().difference(last) < quietRefreshTtl;
  }

  /// Fire-and-forget warm for [storeId] (safe to call on every tap).
  ///
  /// Sync body only records [storeId] — disk / image / logging / ensure are
  /// deferred so [Navigator.pushNamed] is not delayed by async helpers that
  /// run until their first `await` on the calling stack (Batch 1).
  ///
  /// [networkEnrich] false → disk/memory prime only (profile switch / shell
  /// Ensure owns the single collections GET). Avoids opening STORE_OPEN
  /// before `/home` warm and double-fetching with Ensure.
  void prefetch(
    String storeId, {
    String coverImageUrl = '',
    bool networkEnrich = true,
  }) {
    final id = storeId.trim();
    if (id.isEmpty || id == 'my_store' || id == 'other_store') return;
    _lastOpenedStoreId = id;
    // Re-open / new tap: allow collage warm again for this store.
    _collageWarmSuppressed.remove(id);
    final cover = coverImageUrl.trim();
    StoreWarmQa.step(
      'PREFETCH_TAP',
      detail: 'store=$id networkEnrich=$networkEnrich',
    );
    // Defer off the tap / push stack — preserves dedupe + cache seeding.
    scheduleMicrotask(() {
      if (_lastOpenedStoreId != id) {
        StoreWarmQa.log(
          'PREFETCH_SKIP microtask store=$id reason=superseded '
          'last=$_lastOpenedStoreId',
        );
        return;
      }
      _prefetchAfterNavigation(
        id,
        coverImageUrl: cover,
        networkEnrich: networkEnrich,
      );
    });
  }

  void _prefetchAfterNavigation(
    String id, {
    required String coverImageUrl,
    required bool networkEnrich,
  }) {
    if (networkEnrich) {
      CatalogApiCallLog.beginStoreProfileScope(id);
    }
    if (coverImageUrl.isNotEmpty) {
      // ignore: unawaited_futures
      StoreMetaCache.instance.writeCover(id, coverImageUrl);
      // ignore: unawaited_futures
      CatalogImageCache.precacheUrls([coverImageUrl]);
    }
    // Memory/disk prime (no decode).
    // ignore: unawaited_futures
    StoreProductsCache.instance.read(id);
    // ignore: unawaited_futures
    StoreMetaCache.instance.read(id);
    if (!networkEnrich) return;
    // Batch 5: profile Ensure owns the collections GET after first paint.
    // Cold (empty memory): start ensure immediately so it overlaps the
    // transition and joins Ensure via _inFlight. Warm memory: skip — avoids
    // a redundant delayed GET that raced Ensure at +340ms.
    final mem = StoreProductsCache.instance.readMemory(id);
    if (mem == null || mem.isEmpty) {
      // ignore: unawaited_futures
      ensure(id);
    }
  }

  /// Seed Home catalog order after `/home` paint (covers + upcoming rows).
  ///
  /// Does **not** treat list order as viewport visibility (Batch I2). Enrich
  /// starts from [noteListingVisibility] / provisional first-frame rows.
  void setListingCatalog(
    Iterable<({String id, String coverImageUrl})> stores,
  ) {
    _listingCatalog = [
      for (final s in stores)
        if (s.id.trim().isNotEmpty &&
            s.id.trim() != 'my_store' &&
            s.id.trim() != 'other_store')
          (id: s.id.trim(), coverImageUrl: s.coverImageUrl.trim()),
    ];
    final catalogIds = {for (final s in _listingCatalog) s.id};
    _listingVisibility.removeWhere((id, _) => !catalogIds.contains(id));
    StoreWarmQa.event('HOME_CATALOG_SET', {
      'stores': _listingCatalog.length,
      'paused': _listingPrefetchPaused,
    });
    // Tab leave / profile push owns pause — do not resume from catalog seed.
    if (_listingPrefetchPaused) return;
    // Until VisibilityDetector reports, use top rows as provisional visible.
    if (!_listingHasRealVisibility) {
      _recomputeListingViewport(provisional: true);
    } else {
      _scheduleListingViewportRecompute();
    }
  }

  /// Test hook: replace listing network enrich (keeps queue/concurrency gates).
  @visibleForTesting
  Future<List<StoreProduct>> Function(String storeId)?
  debugListingEnrichOverride;

  /// Test hook: replace [ensure]/[refresh] network enrich (Batch I5 cold tests).
  @visibleForTesting
  Future<List<StoreProduct>> Function(String storeId)?
  debugNetworkEnrichOverride;

  @visibleForTesting
  Set<String> get debugListingEnrichWanted =>
      Set<String>.unmodifiable(_listingEnrichWanted);

  @visibleForTesting
  List<String> get debugListingEnrichQueue =>
      List<String>.unmodifiable(_listingEnrichQueue);

  @visibleForTesting
  Set<String> get debugListingEnrichRunningIds =>
      Set<String>.unmodifiable(_listingEnrichRunningIds);

  @visibleForTesting
  int get debugListingEnrichRunning => _listingEnrichRunning;

  @visibleForTesting
  bool get debugListingPrefetchPaused => _listingPrefetchPaused;

  @visibleForTesting
  bool get debugListingHasRealVisibility => _listingHasRealVisibility;

  /// Clears listing viewport state between tests (does not touch collage leases).
  @visibleForTesting
  void debugResetListingPrefetch() {
    _listingViewportDebounce?.cancel();
    _listingViewportDebounce = null;
    _listingCatalog = const [];
    _listingVisibility.clear();
    _listingEnrichWanted.clear();
    _listingEnrichQueue.clear();
    _listingEnrichRunningIds.clear();
    _listingEnrichRunning = 0;
    _listingPrefetchPaused = false;
    _listingHasRealVisibility = false;
    _lastOpenedStoreId = null;
    _lastNetworkAt.clear();
    debugListingEnrichOverride = null;
    debugNetworkEnrichOverride = null;
  }

  /// Bypass visibility debounce (fakeAsync / unit tests).
  @visibleForTesting
  void debugFlushListingViewport({bool provisional = false}) {
    _listingViewportDebounce?.cancel();
    _listingViewportDebounce = null;
    _recomputeListingViewport(provisional: provisional);
  }

  /// Report a listing tile's on-screen fraction (from [VisibilityDetector]).
  void noteListingVisibility(String storeId, {required double visibleFraction}) {
    final id = storeId.trim();
    if (id.isEmpty || id == 'my_store' || id == 'other_store') return;
    if (_listingPrefetchPaused) return;
    final fraction = visibleFraction.clamp(0.0, 1.0);
    if (fraction < listingVisibilityMinFraction) {
      if (_listingVisibility.remove(id) != null) {
        _listingHasRealVisibility = true;
        _scheduleListingViewportRecompute();
      }
      return;
    }
    final prev = _listingVisibility[id];
    _listingVisibility[id] = fraction;
    _listingHasRealVisibility = true;
    // Ignore tiny fraction jitter while scrolling.
    if (prev != null && (prev - fraction).abs() < 0.05) return;
    _scheduleListingViewportRecompute();
  }

  /// Home tab / route left — stop starting new listing enrich work.
  void pauseListingViewportPrefetch() {
    _listingPrefetchPaused = true;
    _listingViewportDebounce?.cancel();
    _listingViewportDebounce = null;
    _listingEnrichQueue.clear();
    _listingEnrichWanted.clear();
    StoreWarmQa.event('LISTING_PREFETCH_PAUSE', {
      'running': _listingEnrichRunning,
    });
  }

  /// Home tab / route visible again.
  void resumeListingViewportPrefetch() {
    _listingPrefetchPaused = false;
    if (_listingCatalog.isEmpty) return;
    _scheduleListingViewportRecompute();
  }

  /// Legacy entry: cover-warm only for [limit] rows; enrich via viewport path.
  ///
  /// Prefer [setListingCatalog] + [noteListingVisibility] (Batch I2).
  void prefetchVisible(
    Iterable<({String id, String coverImageUrl})> stores, {
    int limit = listingVisibleCandidateLimit,
    int enrichLimit = listingEnrichLimit,
  }) {
    setListingCatalog(stores);
    // Cover warm for first [limit] catalog rows (not an enrich signal).
    var n = 0;
    for (final store in _listingCatalog) {
      if (n >= limit) break;
      final cover = store.coverImageUrl;
      if (cover.isNotEmpty) {
        // ignore: unawaited_futures
        StoreMetaCache.instance.writeCover(store.id, cover);
        // ignore: unawaited_futures
        CatalogImageCache.precacheUrls([cover]);
      }
      n++;
    }
    StoreWarmQa.event('PREFETCH_VISIBLE_START', {
      'limit': limit,
      'enrichLimit': enrichLimit,
      'mode': 'viewport',
    });
  }

  void _scheduleListingViewportRecompute() {
    if (_listingPrefetchPaused) return;
    _listingViewportDebounce?.cancel();
    _listingViewportDebounce = Timer(_listingVisibilityDebounce, () {
      _recomputeListingViewport(provisional: false);
    });
  }

  void _recomputeListingViewport({required bool provisional}) {
    if (_listingPrefetchPaused) return;
    final catalog = _listingCatalog;
    if (catalog.isEmpty) return;

    final indexById = <String, int>{
      for (var i = 0; i < catalog.length; i++) catalog[i].id: i,
    };

    List<String> visibleOrdered;
    if (provisional && !_listingHasRealVisibility) {
      visibleOrdered = [
        for (final s in catalog.take(listingVisibleCandidateLimit)) s.id,
      ];
      StoreWarmQa.event('VISIBLE_STORES_IDENTIFIED', {
        'candidates': visibleOrdered.length,
        'note': 'provisionalFirstFrame',
      });
    } else {
      final visibleEntries = <({String id, int index, double fraction})>[
        for (final e in _listingVisibility.entries)
          if (e.value >= listingVisibilityMinFraction &&
              indexById.containsKey(e.key))
            (id: e.key, index: indexById[e.key]!, fraction: e.value),
      ]..sort((a, b) {
        final byIndex = a.index.compareTo(b.index);
        if (byIndex != 0) return byIndex;
        return b.fraction.compareTo(a.fraction);
      });
      visibleOrdered = [
        for (final e in visibleEntries.take(listingVisibleCandidateLimit))
          e.id,
      ];
      StoreWarmQa.event('VISIBLE_STORES_IDENTIFIED', {
        'visible': visibleOrdered.length,
        'visibleCap': listingVisibleCandidateLimit,
        'note': 'viewport',
      });
    }

    final upcoming = selectListingUpcomingIds(
      catalogIds: [for (final s in catalog) s.id],
      visibleOrdered: visibleOrdered,
      upcomingCount: listingUpcomingCount,
    );

    final selected = selectVisibleStoreEnrichIds(
      visibleOrdered: visibleOrdered,
      upcomingOrdered: upcoming,
      lastOpened: _lastOpenedStoreId,
      enrichLimit: listingEnrichLimit,
    );

    // Cover warm for visible (+ upcoming) only — avoid whole-list decode.
    final coverIds = <String>{
      ...visibleOrdered,
      ...upcoming.take(listingUpcomingCount),
    };
    var coverWarm = 0;
    for (final s in catalog) {
      if (!coverIds.contains(s.id)) continue;
      if (s.coverImageUrl.isEmpty) continue;
      // ignore: unawaited_futures
      StoreMetaCache.instance.writeCover(s.id, s.coverImageUrl);
      // ignore: unawaited_futures
      CatalogImageCache.precacheUrls([s.coverImageUrl]);
      coverWarm++;
    }

    _listingEnrichWanted
      ..clear()
      ..addAll(selected);

    // Drop queued work that left the viewport / upcoming set.
    final kept = Queue<String>();
    while (_listingEnrichQueue.isNotEmpty) {
      final id = _listingEnrichQueue.removeFirst();
      if (_listingEnrichWanted.contains(id) &&
          !_listingEnrichRunningIds.contains(id)) {
        kept.add(id);
      }
    }
    _listingEnrichQueue
      ..clear()
      ..addAll(kept);

    for (final id in selected) {
      if (_listingEnrichRunningIds.contains(id)) continue;
      if (_listingEnrichQueue.contains(id)) continue;
      if (!_listingEnrichNeeded(id)) {
        StoreWarmQa.event('PREFETCH_STORE_SKIPPED', {
          'store': id,
          'reason': 'alreadyWarm',
        });
        continue;
      }
      _listingEnrichQueue.add(id);
    }

    StoreWarmQa.event('PREFETCH_VISIBLE_START', {
      'limit': listingVisibleCandidateLimit,
      'enrichLimit': listingEnrichLimit,
      'maxConcurrent': listingEnrichMaxConcurrent,
      'mode': provisional ? 'provisional' : 'viewport',
    });
    StoreWarmQa.event('PREFETCH_VISIBLE_COMPLETE', {
      'selectedEnrich': selected.length,
      'queued': _listingEnrichQueue.length,
      'coverWarm': coverWarm,
      'upcoming': upcoming.length,
      'peakInFlight': StoreWarmQa.enrichInFlightPeak,
    });
    _pumpListingEnrichQueue();
  }

  bool _listingEnrichNeeded(String storeId) {
    final mem = StoreProductsCache.instance.readMemory(storeId);
    if (mem != null && mem.isNotEmpty) return false;
    // Fresh empty store — do not re-GET on every scroll.
    if (isFresh(storeId)) return false;
    return true;
  }

  void _pumpListingEnrichQueue() {
    if (_listingPrefetchPaused) return;
    while (_listingEnrichRunning < listingEnrichMaxConcurrent &&
        _listingEnrichQueue.isNotEmpty) {
      final id = _listingEnrichQueue.removeFirst();
      if (!_listingEnrichWanted.contains(id)) continue;
      if (_listingEnrichRunningIds.contains(id)) continue;
      if (!_listingEnrichNeeded(id)) continue;
      _listingEnrichRunning++;
      _listingEnrichRunningIds.add(id);
      // ignore: unawaited_futures
      _ensureForListingPrefetch(id).whenComplete(() {
        _listingEnrichRunningIds.remove(id);
        if (_listingEnrichRunning > 0) _listingEnrichRunning--;
        _pumpListingEnrichQueue();
      });
    }
  }

  /// Listing soft-enrich with I1 metrics + concurrency gate (Batch I2).
  Future<List<StoreProduct>> _ensureForListingPrefetch(String storeId) async {
    final id = storeId.trim();
    if (_listingPrefetchPaused || !_listingEnrichWanted.contains(id)) {
      StoreWarmQa.event('PREFETCH_STORE_SKIPPED', {
        'store': id,
        'reason': 'noLongerWanted',
      });
      return StoreProductsCache.instance.readMemory(id) ?? const [];
    }
    StoreWarmQa.event('PREFETCH_STORE_START', {'store': id});
    final mem = StoreProductsCache.instance.readMemory(id);
    if (mem != null && mem.isNotEmpty) {
      StoreWarmQa.event('PREFETCH_STORE_CACHE_HIT', {
        'store': id,
        'source': 'memory',
        'products': mem.length,
      });
      return mem;
    } else if (isFresh(id)) {
      StoreWarmQa.event('PREFETCH_STORE_CACHE_HIT', {
        'store': id,
        'source': 'freshEmpty',
        'products': 0,
      });
      return const [];
    } else {
      StoreWarmQa.event('PREFETCH_STORE_CACHE_MISS', {
        'store': id,
        'source': 'memory',
      });
    }
    final override = debugListingEnrichOverride;
    final sw = Stopwatch()..start();
    StoreWarmQa.trackEnrichStart();
    try {
      final products =
          override != null ? await override(id) : await ensure(id);
      // Test override skips [ensure]'s network timestamp — still mark fresh so
      // scroll recomputes do not re-queue the same store.
      if (override != null) {
        _lastNetworkAt[id] = DateTime.now();
      }
      sw.stop();
      StoreWarmQa.event('PREFETCH_STORE_ENRICH_COMPLETE', {
        'store': id,
        'products': products.length,
        'ms': sw.elapsedMilliseconds,
        'ok': true,
        'inFlight': StoreWarmQa.enrichInFlight,
      });
      return products;
    } catch (e) {
      sw.stop();
      StoreWarmQa.event('PREFETCH_STORE_ENRICH_COMPLETE', {
        'store': id,
        'ms': sw.elapsedMilliseconds,
        'ok': false,
      });
      StoreWarmQa.event('PREFETCH_STORE_SKIPPED', {
        'store': id,
        'reason': 'error',
      });
      rethrow;
    } finally {
      StoreWarmQa.trackEnrichEnd();
    }
  }

  /// Returns enriched products with collage image files on disk.
  Future<List<StoreProduct>> ensure(String storeId) {
    final id = storeId.trim();
    final existing = _inFlight[id];
    if (existing != null) {
      StoreWarmQa.event('COLLECTION_REQUEST_START', {
        'store': id,
        'joinedInFlight': true,
        'op': 'ensure',
        'source': 'inFlight',
      });
      return existing.then((products) {
        StoreWarmQa.event('COLLECTION_REQUEST_END', {
          'store': id,
          'joinedInFlight': true,
          'op': 'ensure',
          'products': products.length,
          'ok': true,
        });
        return products;
      });
    }

    final future = _load(id);
    _inFlight[id] = future;
    future.whenComplete(() {
      if (identical(_inFlight[id], future)) _inFlight.remove(id);
    });
    return future;
  }

  /// Network enrich (or cache when [force] is false and TTL still valid).
  ///
  /// Mutation-driven callers pass [force] true (default). Quiet refresh after
  /// warm paint passes `force: false` so a just-completed prefetch is not
  /// repeated within [quietRefreshTtl].
  Future<List<StoreProduct>> refresh(String storeId, {bool force = true}) {
    final id = storeId.trim();
    if (id.isEmpty || id == 'my_store' || id == 'other_store') {
      return Future.value(const []);
    }
    if (!force) {
      final last = _lastNetworkAt[id];
      if (last != null && DateTime.now().difference(last) < quietRefreshTtl) {
        AppLog.d(
          _tag,
          'Skip quiet refresh store=$id (TTL ${quietRefreshTtl.inSeconds}s)',
        );
        StoreWarmQa.event('QUIET_REFRESH_START', {
          'store': id,
          'force': false,
          'source': 'ttlSkip',
        });
        return StoreProductsCache.instance.read(id).then((cached) async {
          if (cached != null && cached.isNotEmpty) {
            final visible = _visibleCached(id, cached);
            StoreWarmQa.event('QUIET_REFRESH_END', {
              'store': id,
              'source': 'ttlCache',
              'products': visible.length,
              'ok': true,
            });
            return visible;
          }
          final ensured = await ensure(id);
          StoreWarmQa.event('QUIET_REFRESH_END', {
            'store': id,
            'source': 'ttlEnsure',
            'products': ensured.length,
            'ok': true,
          });
          return ensured;
        });
      }
    }

    final existing = _inFlight[id];
    if (existing != null) {
      StoreWarmQa.event('COLLECTION_REQUEST_START', {
        'store': id,
        'joinedInFlight': true,
        'op': 'refresh',
        'force': force,
      });
      return existing;
    }

    if (!force) {
      StoreWarmQa.event('QUIET_REFRESH_START', {
        'store': id,
        'force': false,
        'source': 'network',
      });
    }

    final future = _refreshNetwork(id);
    _inFlight[id] = future;
    future.whenComplete(() {
      if (identical(_inFlight[id], future)) _inFlight.remove(id);
    });
    if (!force) {
      return future.then((products) {
        StoreWarmQa.event('QUIET_REFRESH_END', {
          'store': id,
          'source': 'network',
          'products': products.length,
          'ok': true,
        });
        return products;
      });
    }
    return future;
  }

  /// Drop TTL so the next quiet refresh / ensure can network again.
  void invalidate(String storeId) {
    final id = storeId.trim();
    if (id.isEmpty) return;
    _lastNetworkAt.remove(id);
  }

  void invalidateAll() => _lastNetworkAt.clear();

  Future<List<StoreProduct>> _load(String storeId) async {
    final sw = Stopwatch()..start();
    final cached = await StoreProductsCache.instance.read(storeId);
    if (cached != null && cached.isNotEmpty) {
      final visible = _visibleCached(storeId, cached);
      // Batch 6: do not decode-warm on cache hit — StoreProfileBloc owns
      // post-paint warm (_warmGridTilesBeforePaint). Avoids double decode
      // during the open transition. Network enrich still warms below.
      CatalogApiCallLog.markStoreProfileMilestone(
        reason: 'store_enrich_cache:$storeId',
      );
      sw.stop();
      StoreWarmQa.event('COLLECTION_REQUEST_START', {
        'store': storeId,
        'joinedInFlight': false,
        'op': 'ensure',
        'source': 'cache',
      });
      StoreWarmQa.event('COLLECTION_REQUEST_END', {
        'store': storeId,
        'op': 'ensure',
        'source': 'cache',
        'products': visible.length,
        'ms': sw.elapsedMilliseconds,
        'ok': true,
      });
      return visible;
    }

    // Empty stores are not kept as a non-null cache hit (read treats [] as
    // miss). Still honor TTL so open does not re-GET collections.
    if (isFresh(storeId)) {
      AppLog.d(_tag, 'Skip enrich store=$storeId (fresh empty)');
      CatalogApiCallLog.markStoreProfileMilestone(
        reason: 'store_enrich_cache:$storeId',
      );
      sw.stop();
      StoreWarmQa.event('COLLECTION_REQUEST_START', {
        'store': storeId,
        'joinedInFlight': false,
        'op': 'ensure',
        'source': 'freshEmpty',
      });
      StoreWarmQa.event('COLLECTION_REQUEST_END', {
        'store': storeId,
        'op': 'ensure',
        'source': 'freshEmpty',
        'products': 0,
        'ms': sw.elapsedMilliseconds,
        'ok': true,
      });
      return const [];
    }

    return _refreshNetwork(storeId);
  }

  List<String> _collageUrls(List<StoreProduct> products) => [
    for (final p in products) ...p.imagePaths.take(collageProductLimit),
  ];

  /// Profile route / shell is mounting [storeId] — allow collage warm again
  /// (covers deep links that skip [prefetch]).
  void noteProfileOpened(String storeId) {
    final id = storeId.trim();
    if (id.isEmpty || id == 'my_store' || id == 'other_store') return;
    _lastOpenedStoreId = id;
    _collageWarmSuppressed.remove(id);
  }

  /// Stop collage warm for [storeId] when that Store Profile closes (Batch 7A).
  ///
  /// Always suppresses further collage warm for [storeId] until the next
  /// [prefetch] / [noteProfileOpened] — even when no lease exists yet
  /// (`held=null`), so a late [ensure] completion cannot start decode after
  /// the user left.
  void cancelCollageWarmForStore(String storeId) {
    final id = storeId.trim();
    if (id.isEmpty) return;
    _collageWarmSuppressed.add(id);

    if (_collageWarmStoreId != id) {
      StoreWarmQa.log(
        'PREFETCH_CANCEL_SUPPRESS store=$id held=$_collageWarmStoreId '
        '(block late collage warm)',
      );
      return;
    }
    final owner = _collageWarmOwner;
    StoreWarmQa.step(
      'PREFETCH_CANCEL',
      detail: 'store=$id owner=${owner?.debugLabel ?? 'none'}',
    );
    if (owner != null) {
      CatalogImageCache.cancelOffscreenWarm(
        owner,
        reason: 'prefetcherStoreClose',
      );
    }
    _collageWarmOwner = null;
    _collageWarmStoreId = null;
  }

  bool _shouldSkipCollageWarm(String storeId, {required String phase}) {
    if (_collageWarmSuppressed.contains(storeId)) {
      StoreWarmQa.log(
        'PREFETCH_SKIP $phase store=$storeId reason=suppressedAfterClose',
      );
      return true;
    }
    // Another store claimed open via tap / profile load — drop stale enrich.
    final last = _lastOpenedStoreId;
    if (last != null && last != storeId) {
      StoreWarmQa.log(
        'PREFETCH_SKIP $phase store=$storeId reason=notLastOpened last=$last',
      );
      return true;
    }
    return false;
  }

  void _warmCollageInBackground(
    List<StoreProduct> products, {
    required String storeId,
  }) {
    if (products.isEmpty) return;
    final id = storeId.trim();
    if (id.isEmpty) return;
    if (_shouldSkipCollageWarm(id, phase: 'collageWarm')) return;
    CatalogImageCache.ensureCatalogMemoryBudget();

    // Batch 7A: replace prior store's collage lease — do not use a global gen.
    final openedId = id;
    final previous = _collageWarmOwner;
    if (previous != null) {
      CatalogImageCache.cancelOffscreenWarm(
        previous,
        reason: 'prefetcherReplace',
      );
    }
    final owner = CatalogImageCache.createWarmOwner(
      debugLabel: 'prefetcher:$openedId',
    );
    _collageWarmOwner = owner;
    _collageWarmStoreId = openedId;
    final warmEpoch = owner.epoch;
    StoreWarmQa.step(
      'PREFETCH_WARM',
      detail:
          'store=$openedId products=${products.length} '
          'owner=${owner.debugLabel} epoch=$warmEpoch',
    );

    final first =
        products.length <= firstPaintAlbumWarmCount
            ? products
            : products.sublist(0, firstPaintAlbumWarmCount);
    final rest =
        products.length <= firstPaintAlbumWarmCount
            ? const <StoreProduct>[]
            : products.sublist(firstPaintAlbumWarmCount);

    final firstUrls = _collageUrls(first);
    final restUrls = _collageUrls(rest);

    // Visible albums: light disk probe soon (no decode), then decode after
    // the push. Rest of the grid waits longer so first paint stays light.
    // Decode width matches StoreProductGrid collage paint (Batch 2).
    final collageWidth = CatalogImageCache.collageCellCacheWidth();
    if (firstUrls.isNotEmpty) {
      unawaited(CatalogImageCache.precacheUrls(firstUrls, owner: owner));
      unawaited(
        Future<void>.delayed(_collageDecodeWarmDelay, () {
          if (_shouldSkipCollageWarm(openedId, phase: 'delayedFirst')) {
            return;
          }
          if (!owner.allows(warmEpoch)) {
            StoreWarmQa.log(
              'PREFETCH_SKIP delayedFirst store=$openedId reason=ownerInactive',
            );
            return;
          }
          StoreWarmQa.log(
            'PREFETCH_DECODE first store=$openedId urls=${firstUrls.length}',
          );
          CatalogImageCache.precacheUrls(
            firstUrls,
            decode: true,
            maxDecode: firstUrls.length.clamp(1, 36),
            cacheWidth: collageWidth,
            owner: owner,
          );
        }),
      );
    }
    if (restUrls.isEmpty) return;
    unawaited(
      Future<void>.delayed(
        _collageDecodeWarmDelay + _collageDecodeRestDelay,
        () {
          if (_shouldSkipCollageWarm(openedId, phase: 'delayedRest')) {
            return;
          }
          if (!owner.allows(warmEpoch)) {
            StoreWarmQa.log(
              'PREFETCH_SKIP delayedRest store=$openedId reason=ownerInactive',
            );
            return;
          }
          StoreWarmQa.log(
            'PREFETCH_DECODE rest store=$openedId urls=${restUrls.length}',
          );
          // Disk-only for the rest first; lighter decode concurrency while
          // the user may be scrolling (Batch 6).
          unawaited(CatalogImageCache.precacheUrls(restUrls, owner: owner));
          CatalogImageCache.precacheUrls(
            restUrls,
            decode: true,
            maxDecode: CatalogImageCache.defaultMaxDecode,
            cacheWidth: collageWidth,
            concurrency: 4,
            owner: owner,
          );
        },
      ),
    );
  }

  List<StoreProduct> _visibleCached(String storeId, List<StoreProduct> cached) {
    final hidden = ServiceLocator.get<ProductUploadCoordinator>()
        .inFlightListingIdsForStore(storeId);
    final visible =
        hidden.isEmpty
            ? List<StoreProduct>.from(cached)
            : [
              for (final p in cached)
                if (!hidden.contains(p.id)) p,
            ];
    visible.sort((a, b) => b.id.compareTo(a.id));
    return visible;
  }

  Future<List<StoreProduct>> _refreshNetwork(String storeId) async {
    final sw = Stopwatch()..start();
    StoreWarmQa.event('COLLECTION_REQUEST_START', {
      'store': storeId,
      'joinedInFlight': false,
      'op': 'refreshNetwork',
      'source': 'network',
    });
    try {
      final override = debugNetworkEnrichOverride;
      if (override != null) {
        final products = await override(storeId);
        await StoreProductsCache.instance.write(storeId, products);
        _lastNetworkAt[storeId] = DateTime.now();
        sw.stop();
        StoreWarmQa.event('COLLECTION_REQUEST_END', {
          'store': storeId,
          'op': 'refreshNetwork',
          'source': 'debugOverride',
          'products': products.length,
          'ms': sw.elapsedMilliseconds,
          'ok': true,
        });
        return products;
      }

      final repo = ServiceLocator.get<CollectionRepository>();
      final hidden = ServiceLocator.get<ProductUploadCoordinator>()
          .inFlightListingIdsForStore(storeId);

      // Batch I5 — network wait includes HTTP + JSON decode inside the repo.
      // Mapping is timed separately below (cannot split JSON from HTTP without
      // changing the API client).
      final networkSw = Stopwatch()..start();
      StoreWarmQa.event('COLLECTION_NETWORK_WAIT_START', {'store': storeId});
      // BE-2: one-call collage hydrate when BE embeds products[].
      final page = await repo.listCollections(
        storeId: storeId,
        limit: 50,
        include: 'products',
        productsLimit: collageProductLimit,
      );
      networkSw.stop();
      StoreWarmQa.event('COLLECTION_NETWORK_WAIT_END', {
        'store': storeId,
        'ms': networkSw.elapsedMilliseconds,
        'collections': page.items.length,
        'note': 'httpPlusJsonDecode',
      });

      final summaries = [
        for (final summary in page.items)
          if (!hidden.contains(summary.id)) summary,
      ];

      // Batch 5: map embedded cards synchronously first (no per-collection GET).
      // Only summaries that still need network go through concurrent legacy.
      final mapSw = Stopwatch()..start();
      var embeddedHits = 0;
      var legacyHits = 0;
      final products = <StoreProduct>[];
      final legacySummaries = <CollectionSummary>[];

      for (final summary in summaries) {
        final embedded = storeProductFromEmbeddedSummary(
          summary,
          productsLimit: collageProductLimit,
        );
        if (embedded != null) {
          products.add(embedded);
          embeddedHits++;
          continue;
        }
        if (summary.photoCount > 0) {
          // Empty/unusable embed but BE reports photos — legacy GET.
          legacySummaries.add(summary);
        }
        // Else: empty listing or non-displayable embed — omit (no cover ghost).
      }
      mapSw.stop();

      StoreWarmQa.event('PRODUCTS_EMBEDDED_MAPPED', {
        'store': storeId,
        'collections': summaries.length,
        'embedded': embeddedHits,
        'legacyNeeded': legacySummaries.length,
        'mapMs': mapSw.elapsedMilliseconds,
      });

      if (legacySummaries.isNotEmpty) {
        StoreWarmQa.event('LEGACY_FALLBACK_START', {
          'store': storeId,
          'count': legacySummaries.length,
        });
      }
      const concurrency = 4;
      final legacySw = Stopwatch()..start();
      for (var i = 0; i < legacySummaries.length; i += concurrency) {
        final end =
            i + concurrency > legacySummaries.length
                ? legacySummaries.length
                : i + concurrency;
        final chunk = legacySummaries.sublist(i, end);
        final chunkProducts = await Future.wait([
          for (final summary in chunk)
            _productFromSummary(repo: repo, storeId: storeId, summary: summary),
        ]);
        for (final product in chunkProducts) {
          if (product == null) continue;
          products.add(product);
          legacyHits++;
        }
      }
      if (legacySummaries.isNotEmpty) {
        legacySw.stop();
        StoreWarmQa.event('LEGACY_FALLBACK_END', {
          'store': storeId,
          'legacy': legacyHits,
          'ms': legacySw.elapsedMilliseconds,
          'ok': true,
        });
      }
      products.sort((a, b) => b.id.compareTo(a.id));
      // Cache + return before decode so ensure() unblocks profile paint;
      // collage decode keeps warming during / after first grid frame.
      await StoreProductsCache.instance.write(storeId, products);
      _lastNetworkAt[storeId] = DateTime.now();
      _warmCollageInBackground(products, storeId: storeId);
      AppLog.d(
        _tag,
        'Enriched store=$storeId collections=${products.length} '
        'embedded=$embeddedHits legacy=$legacyHits '
        'limit=$collageProductLimit',
      );
      CatalogApiCallLog.markStoreProfileMilestone(
        reason: 'store_enrich:$storeId',
      );
      sw.stop();
      StoreWarmQa.event('COLLECTION_REQUEST_END', {
        'store': storeId,
        'op': 'refreshNetwork',
        'source': 'network',
        'collections': summaries.length,
        'products': products.length,
        'embedded': embeddedHits,
        'legacy': legacyHits,
        'ms': sw.elapsedMilliseconds,
        'ok': true,
      });
      return products;
    } catch (e) {
      AppLog.e(_tag, 'Enrich failed store=$storeId', e);
      sw.stop();
      StoreWarmQa.event('COLLECTION_REQUEST_END', {
        'store': storeId,
        'op': 'refreshNetwork',
        'source': 'network',
        'ms': sw.elapsedMilliseconds,
        'ok': false,
      });
      final cached = await StoreProductsCache.instance.read(storeId);
      return cached ?? const [];
    }
  }

  /// Null = omit from grid (empty after item delete — no cover ghost).
  ///
  /// Prefer [storeProductFromEmbeddedSummary] (called first in
  /// [_refreshNetwork]). This path is the legacy network fallback.
  Future<StoreProduct?> _productFromSummary({
    required CollectionRepository repo,
    required String storeId,
    required CollectionSummary summary,
  }) async {
    final cover = CatalogUiMapper.summaryToProduct(summary);

    // BE-2 — already attempted sync; retry here only if caller skipped it.
    final embedded = storeProductFromEmbeddedSummary(
      summary,
      productsLimit: collageProductLimit,
    );
    if (embedded != null) return embedded;
    if (summary.products.isNotEmpty && summary.photoCount <= 0) {
      AppLog.d(
        _tag,
        'Skip empty collection ${summary.id} (embedded has no displayable)',
      );
      return null;
    }

    try {
      // Legacy: products?collectionId= when embed missing (old BE / empty embed).
      // List productCount is often live-only while pending imports still appear.
      try {
        final page = await repo.listStoreProducts(
          storeId: storeId,
          collectionId: summary.id,
          limit: collageProductLimit,
        );
        if (page.items.isNotEmpty) {
          return CatalogUiMapper.collectionCardFromProducts(
            summary: summary,
            products: page.items,
          );
        }
        if (summary.photoCount <= 0) {
          AppLog.d(
            _tag,
            'Skip empty collection ${summary.id} (products=0 photoCount=0)',
          );
          return null;
        }
      } catch (e) {
        AppLog.d(
          _tag,
          'products?collectionId enrich miss id=${summary.id} err=$e',
        );
        if (summary.photoCount <= 0) return null;
      }

      final detail = await repo.fetchCollection(
        storeId: storeId,
        listingId: summary.id,
      );
      final detailed = CatalogUiMapper.detailToProduct(detail);
      final hasDisplayable = detailed.imagePaths.any(
        ProductImagePaths.isDisplayable,
      );
      if (!hasDisplayable) {
        AppLog.d(
          _tag,
          'Skip empty collection ${summary.id} (detail has no displayable photos)',
        );
        return null;
      }
      final coverUrl = cover.primaryImagePath?.trim() ?? '';
      final withListCreated = detailed.copyWith(
        createdAt: summary.createdAt ?? detailed.createdAt,
        likeCount:
            detailed.likeCount ??
            summary.likeCount ??
            summary.cover.likeCount ??
            cover.likeCount,
      );
      if (coverUrl.isEmpty) return withListCreated;
      final rest =
          withListCreated.imagePaths
              .where((p) => p.trim() != coverUrl)
              .toList();
      return withListCreated.copyWith(imagePaths: [coverUrl, ...rest]);
    } catch (_) {
      if (summary.photoCount <= 0) return null;
      return cover;
    }
  }
}

/// Pure Batch I2 selector: visible first, then upcoming, then last-opened.
///
/// Caps at [enrichLimit]. Does not fetch; used by listing viewport recompute
/// and unit tests.
List<String> selectVisibleStoreEnrichIds({
  required List<String> visibleOrdered,
  required List<String> upcomingOrdered,
  String? lastOpened,
  int enrichLimit = StoreProductsPrefetcher.listingEnrichLimit,
}) {
  if (enrichLimit <= 0) return const [];
  final out = <String>[];
  final seen = <String>{};

  void consider(String raw) {
    final id = raw.trim();
    if (id.isEmpty || id == 'my_store' || id == 'other_store') return;
    if (!seen.add(id)) return;
    out.add(id);
  }

  for (final id in visibleOrdered) {
    if (out.length >= enrichLimit) break;
    consider(id);
  }
  for (final id in upcomingOrdered) {
    if (out.length >= enrichLimit) break;
    consider(id);
  }
  final opened = lastOpened?.trim() ?? '';
  if (out.length < enrichLimit && opened.isNotEmpty) {
    consider(opened);
  }
  return out.take(enrichLimit).toList(growable: false);
}

/// Rows immediately after the last visible catalog index (scroll-ahead).
List<String> selectListingUpcomingIds({
  required List<String> catalogIds,
  required List<String> visibleOrdered,
  int upcomingCount = StoreProductsPrefetcher.listingUpcomingCount,
}) {
  if (upcomingCount <= 0 || catalogIds.isEmpty || visibleOrdered.isEmpty) {
    return const [];
  }
  final indexById = <String, int>{
    for (var i = 0; i < catalogIds.length; i++) catalogIds[i]: i,
  };
  var maxVisibleIndex = -1;
  for (final id in visibleOrdered) {
    final i = indexById[id];
    if (i != null && i > maxVisibleIndex) maxVisibleIndex = i;
  }
  if (maxVisibleIndex < 0) return const [];
  final visibleSet = visibleOrdered.toSet();
  final out = <String>[];
  for (var i = maxVisibleIndex + 1;
      i < catalogIds.length && out.length < upcomingCount;
      i++) {
    final id = catalogIds[i];
    if (visibleSet.contains(id)) continue;
    out.add(id);
  }
  return out;
}

/// BE-2 collage card from embedded `products[]` — sync, no network.
///
/// Returns null when embed is empty or has no displayable URLs (caller may
/// fall back to legacy `products?collectionId=` / collection detail).
StoreProduct? storeProductFromEmbeddedSummary(
  CollectionSummary summary, {
  int productsLimit = StoreProductsPrefetcher.collageProductLimit,
}) {
  if (summary.products.isEmpty) return null;
  final capped =
      summary.products.length > productsLimit
          ? summary.products.take(productsLimit).toList()
          : summary.products;
  final card = CatalogUiMapper.collectionCardFromProducts(
    summary: summary,
    products: capped,
  );
  final hasDisplayable = card.imagePaths.any(ProductImagePaths.isDisplayable);
  return hasDisplayable ? card : null;
}
