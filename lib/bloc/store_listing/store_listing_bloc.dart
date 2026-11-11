import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/catalog_ui_mapper.dart';
import 'package:project_c/helper/device_contact_names.dart';
import 'package:project_c/helper/phone_normalize.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/models/catalog/catalog_page.dart';
import 'package:project_c/models/catalog/catalog_store.dart';
import 'package:project_c/models/store_channel.dart';
import 'package:project_c/services/store_home_prefetcher.dart';
import 'package:project_c/services/store_products_prefetcher.dart';
import 'package:project_c/storage/store_home_cache.dart';
import 'package:project_c/storage/store_meta_cache.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/profile/profile_repository.dart';
import 'package:project_c/webservice/store/store_repository.dart';

part 'store_listing_event.dart';
part 'store_listing_state.dart';

class StoreListingBloc extends Bloc<StoreListingEvent, StoreListingState> {
  StoreListingBloc({
    StoreRepository? storeRepository,
    ProfileRepository? profileRepository,
  }) : _storeRepository =
           storeRepository ?? ServiceLocator.get<StoreRepository>(),
       _profileRepository =
           profileRepository ?? ServiceLocator.get<ProfileRepository>(),
       // Seed only when subtitles can be resolved (sidecar / contacts ready)
       // so bootstrap→shell never flashes empty → name/number.
       super(_initialState()) {
    on<StoreListingSearchChanged>(_onSearchChanged);
    // One refresh at a time — concurrent Refreshed races can flash empty shimmer.
    on<StoreListingRefreshed>(
      _onRefreshed,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
    on<StoreListingLoadMore>(_onLoadMore);
    on<StoreListingDeleteAccountRequested>(_onDeleteAccountRequested);
    on<StoreListingClearMessage>(_onClearMessage);
    on<StoreListingClearAccountDeleted>(_onClearAccountDeleted);
    add(const StoreListingRefreshed());
  }

  final StoreRepository _storeRepository;
  final ProfileRepository _profileRepository;
  static const _tag = 'StoreListingBloc';
  static const _avatarPalette = <int>[
    0xFF2AABEE,
    0xFF8E44AD,
    0xFF2980B9,
    0xFF16A085,
    0xFFE67E22,
    0xFFE74C3C,
  ];

  /// True until the constructor-driven first [StoreListingRefreshed] finishes.
  /// Lets that pass use [StoreHomePrefetcher.ensure] (consume auth warm) even
  /// when rows were seeded from disk.
  bool _initialFetchPending = true;

  /// Frame 0: memory cache with resolvable subtitles; else shimmer until enrich.
  static StoreListingState _initialState() {
    final page = StoreHomeCache.instance.readMemory();
    if (page == null || page.items.isEmpty) {
      return const StoreListingState(isLoading: true);
    }
    if (!_canSeedSubtitles(page)) {
      // Avoid painting nameless rows then swapping in contacts a few seconds later.
      return const StoreListingState(isLoading: true);
    }
    final stores = [
      for (var i = 0; i < page.items.length; i++)
        CatalogUiMapper.storeToChannel(
          page.items[i],
          avatarColor: _avatarPalette[i % _avatarPalette.length],
        ).copyWith(
          contactName: _resolvedContactName(page.items[i].phone),
        ),
    ];
    return StoreListingState(
      isLoading: false,
      allStores: stores,
      nextCursor: page.nextCursor,
    );
  }

  /// Sidecar names, live contacts index, or no phones → safe to seed.
  static bool _canSeedSubtitles(CatalogPage<CatalogStore> page) {
    final needsPhone = page.items.any((s) => s.phone.trim().isNotEmpty);
    if (!needsPhone) return true;
    if (DeviceContactNames.isReady) return true;
    return StoreHomeCache.instance.hasContactNames;
  }

  static String _resolvedContactName(String phone) {
    final cached = StoreHomeCache.instance.contactNameFor(phone)?.trim() ?? '';
    if (cached.isNotEmpty) return cached;
    if (!DeviceContactNames.isReady) return '';
    return DeviceContactNames.lookup(phone)?.trim() ?? '';
  }

  void _onSearchChanged(
    StoreListingSearchChanged event,
    Emitter<StoreListingState> emit,
  ) {
    emit(state.copyWith(query: event.query));
  }

  Future<void> _onRefreshed(
    StoreListingRefreshed event,
    Emitter<StoreListingState> emit,
  ) async {
    final isInitial = _initialFetchPending;
    final hadVisible = state.allStores.isNotEmpty;

    if (!hadVisible) {
      // Only paint cache when subtitles are already resolvable; otherwise shimmer
      // until home + contact enrich finish (single coherent land).
      final painted = await _tryPaintCachedHome(emit);
      if (!painted) {
        emit(
          state.copyWith(isLoading: true, clearError: true, clearCursor: true),
        );
      }
    } else {
      // Keep named rows visible (seeded cache / pull / tab). Never empty→shimmer.
      emit(state.copyWith(isLoading: true, clearError: true));
    }

    final paintedFromCache = state.allStores.isNotEmpty;

    try {
      unawaited(_warmCachedCovers());

      // First land (even with seed): consume auth prefetch. Later: force network.
      final page =
          (paintedFromCache && !isInitial)
              ? await StoreHomePrefetcher.instance.refresh(limit: 40)
              : await StoreHomePrefetcher.instance.ensure(limit: 40);

      // One coherent emit: owned-first order + contact names together.
      final stores = await _mapAndEnrich(page.items);

      AppLog.d(_tag, 'Loaded ${stores.length} stores (enriched, ready to land)');
      emit(
        state.copyWith(
          isLoading: false,
          allStores: stores,
          nextCursor: page.nextCursor,
        ),
      );
      await _persistHome(page, stores);
      _afterHomePaint(stores, page.items);
    } catch (e) {
      AppLog.e(_tag, 'Home load failed', e);
      Object displayError = e;
      // Owned-first cursor rollout: discard stale page cursor and retry once.
      if (e is CatalogApiException && e.code == 'INVALID_CURSOR') {
        StoreHomePrefetcher.instance.invalidate();
        await StoreHomeCache.instance.clearAll();
        try {
          final page = await StoreHomePrefetcher.instance.refresh(limit: 40);
          final stores = await _mapAndEnrich(page.items);
          emit(
            state.copyWith(
              isLoading: false,
              allStores: stores,
              nextCursor: page.nextCursor,
              clearError: true,
            ),
          );
          await _persistHome(page, stores);
          _afterHomePaint(stores, page.items);
          return;
        } catch (retryError) {
          AppLog.e(_tag, 'Home INVALID_CURSOR retry failed', retryError);
          displayError = retryError;
        }
      }
      // Keep prior rows on soft-refresh failure; first land shows the error.
      if (state.allStores.isNotEmpty) {
        emit(state.copyWith(isLoading: false, clearError: true));
      } else {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: CatalogErrorMapper.toUserMessage(displayError),
          ),
        );
      }
    } finally {
      _initialFetchPending = false;
    }
  }

  /// Cache paint only when names/phones can be shown without a later swap.
  Future<bool> _tryPaintCachedHome(Emitter<StoreListingState> emit) async {
    final page =
        StoreHomeCache.instance.readMemory() ??
        await StoreHomeCache.instance.read();
    if (page == null || page.items.isEmpty) return false;

    final needsPhone = page.items.any((s) => s.phone.trim().isNotEmpty);
    if (needsPhone &&
        !StoreHomeCache.instance.hasContactNames &&
        !DeviceContactNames.isReady) {
      // Let the network+enrich path own the first paint.
      return false;
    }

    // If sidecar is thin but contacts are in flight / ready, finish index first.
    if (needsPhone && !StoreHomeCache.instance.hasContactNames) {
      try {
        await DeviceContactNames.load();
      } catch (_) {}
    }

    final stores = _applyCachedContactNames(_mapStores(page.items));
    final enriched =
        DeviceContactNames.isReady
            ? [
              for (final store in stores)
                store.copyWith(
                  contactName:
                      DeviceContactNames.lookup(store.phone)?.trim() ??
                      store.contactName,
                ),
            ]
            : stores;

    final covers = [for (final s in enriched) s.coverImageUrl];
    AppLog.d(_tag, 'Painted ${enriched.length} stores from home cache');
    emit(
      state.copyWith(
        isLoading: false,
        allStores: enriched,
        nextCursor: page.nextCursor,
      ),
    );
    unawaited(CatalogImageCache.probeDisk(covers));
    unawaited(CatalogImageCache.warmAvatars(covers));
    _afterHomePaint(enriched, page.items);
    return true;
  }

  List<StoreChannel> _applyCachedContactNames(List<StoreChannel> mapped) {
    final out = <StoreChannel>[];
    for (final store in mapped) {
      final resolved = _resolvedContactName(store.phone);
      out.add(
        resolved.isNotEmpty
            ? store.copyWith(contactName: resolved)
            : store,
      );
    }
    return out;
  }

  Future<void> _warmCachedCovers() async {
    final page =
        StoreHomeCache.instance.readMemory() ??
        await StoreHomeCache.instance.read();
    if (page == null || page.items.isEmpty) return;
    final covers = [for (final s in page.items) s.coverImageUrl];
    unawaited(CatalogImageCache.probeDisk(covers));
    unawaited(CatalogImageCache.warmAvatars(covers));
  }

  void _afterHomePaint(
    List<StoreChannel> stores,
    List<CatalogStore> raw,
  ) {
    StoreProductsPrefetcher.instance.prefetchVisible([
      for (final s in stores) (id: s.id, coverImageUrl: s.coverImageUrl),
    ]);
    // Avatar-sized decode for visible covers (same key as CatalogNetworkAvatar).
    unawaited(
      CatalogImageCache.warmAvatars([
        for (final s in stores) s.coverImageUrl,
      ]),
    );
    // Disk-warm remaining showcase URLs (preview) — no full decode.
    unawaited(
      CatalogImageCache.precacheUrls([
        for (final s in stores) ...s.imageUrls,
      ]),
    );
    for (final s in raw) {
      // Seed relationship/followStatus so open-from-home never flashes Follow.
      unawaited(
        StoreMetaCache.instance.write(
          s.id,
          StoreMetaSnapshot.fromCatalogStore(s),
        ),
      );
    }
  }

  Future<void> _persistHome(
    CatalogPage<CatalogStore> page,
    List<StoreChannel> stores,
  ) async {
    final names = <String, String>{};
    for (final s in stores) {
      final phone = s.phone.trim();
      final name = s.contactName.trim();
      if (phone.isEmpty || name.isEmpty) continue;
      names[phone] = name;
      final e164 = PhoneNormalize.toE164(phone);
      if (e164 != null) names[e164] = name;
    }
    await StoreHomeCache.instance.write(page, contactNames: names);
  }

  Future<void> _onLoadMore(
    StoreListingLoadMore event,
    Emitter<StoreListingState> emit,
  ) async {
    final cursor = state.nextCursor;
    if (cursor == null ||
        cursor.isEmpty ||
        state.isLoadingMore ||
        state.isLoading) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true, clearError: true));
    try {
      final page = await _storeRepository.fetchHome(cursor: cursor);
      final mapped = await _mapAndEnrich(
        page.items,
        colorOffset: state.allStores.length,
      );
      // Preserve server owned-first order — only append.
      emit(
        state.copyWith(
          isLoadingMore: false,
          allStores: [...state.allStores, ...mapped],
          nextCursor: page.nextCursor,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Load more failed', e);
      if (e is CatalogApiException && e.code == 'INVALID_CURSOR') {
        // Stale owned-first cursor — drop pagination and reload page 1.
        emit(
          state.copyWith(
            isLoadingMore: false,
            clearCursor: true,
            clearError: true,
          ),
        );
        add(const StoreListingRefreshed());
        return;
      }
      emit(
        state.copyWith(
          isLoadingMore: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _onDeleteAccountRequested(
    StoreListingDeleteAccountRequested event,
    Emitter<StoreListingState> emit,
  ) async {
    if (state.isDeletingAccount) return;
    emit(
      state.copyWith(
        isDeletingAccount: true,
        clearError: true,
        clearAccountDeleted: true,
      ),
    );
    try {
      await _profileRepository.deleteAccount();
      AppLog.d(
        'TEST_COLD_START',
        'DELETE /me success → session cleared\n'
        '  next: AuthLoggedOut + auth_phone_route\n'
        '  then kill+launch → expect RESULT=UNSIGNED (A1/A4 helper)',
      );
      AppLog.d(_tag, 'Catalog account deleted');
      emit(
        state.copyWith(isDeletingAccount: false, accountDeleted: true),
      );
    } catch (e) {
      AppLog.e(_tag, 'Account delete failed', e);
      emit(
        state.copyWith(
          isDeletingAccount: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  void _onClearMessage(
    StoreListingClearMessage event,
    Emitter<StoreListingState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }

  void _onClearAccountDeleted(
    StoreListingClearAccountDeleted event,
    Emitter<StoreListingState> emit,
  ) {
    emit(state.copyWith(clearAccountDeleted: true));
  }

  List<StoreChannel> _mapStores(
    List<CatalogStore> stores, {
    int colorOffset = 0,
  }) {
    return [
      for (var i = 0; i < stores.length; i++)
        CatalogUiMapper.storeToChannel(
          stores[i],
          avatarColor:
              _avatarPalette[(colorOffset + i) % _avatarPalette.length],
        ),
    ];
  }

  Future<List<StoreChannel>> _enrichContactNames(
    List<StoreChannel> mapped,
  ) async {
    final needsLookup = mapped.any((s) => s.phone.trim().isNotEmpty);
    if (!needsLookup) return mapped;

    await DeviceContactNames.load();
    return [
      for (final store in mapped)
        store.copyWith(
          contactName:
              DeviceContactNames.lookup(store.phone)?.trim() ??
              store.contactName,
        ),
    ];
  }

  Future<List<StoreChannel>> _mapAndEnrich(
    List<CatalogStore> stores, {
    int colorOffset = 0,
  }) async {
    // Apply disk sidecar first so a contact miss still keeps last-known names.
    final mapped = _applyCachedContactNames(
      _mapStores(stores, colorOffset: colorOffset),
    );
    return _enrichContactNames(mapped);
  }
}
