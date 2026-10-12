import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/catalog_ui_mapper.dart';
import 'package:project_c/helper/device_contact_names.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/models/catalog/catalog_page.dart';
import 'package:project_c/models/catalog/catalog_store.dart';
import 'package:project_c/models/store_channel.dart';
import 'package:project_c/services/store_home_prefetcher.dart';
import 'package:project_c/services/store_products_prefetcher.dart';
import 'package:project_c/storage/store_home_cache.dart';
import 'package:project_c/storage/store_meta_cache.dart';
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
       // Empty + loading → shimmer only when no disk/memory home cache.
       super(const StoreListingState(isLoading: true)) {
    on<StoreListingSearchChanged>(_onSearchChanged);
    on<StoreListingRefreshed>(_onRefreshed);
    on<StoreListingLoadMore>(_onLoadMore);
    on<StoreListingDeleteAccountRequested>(_onDeleteAccountRequested);
    on<StoreListingClearMessage>(_onClearMessage);
    on<StoreListingClearAccountDeleted>(_onClearAccountDeleted);
    on<StoreListingCachedNamesReady>(_onCachedNamesReady);
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
    final hadVisible = state.allStores.isNotEmpty;

    // Kill+reopen: paint disk/memory home immediately — no shimmer wait.
    if (!hadVisible) {
      final painted = await _tryPaintCachedHome(emit);
      if (!painted) {
        emit(
          state.copyWith(isLoading: true, clearError: true, clearCursor: true),
        );
      }
    } else {
      // Pull-to-refresh: keep list visible (shimmer only when empty).
      emit(state.copyWith(isLoading: true, clearError: true, clearCursor: true));
    }

    final paintedFromCache = state.allStores.isNotEmpty;

    try {
      // After a disk paint, force network so the list stays fresh.
      final page =
          paintedFromCache
              ? await StoreHomePrefetcher.instance.refresh(limit: 40)
              : await StoreHomePrefetcher.instance.ensure(limit: 40);

      // Prefer names on first empty paint when contacts are warm/in-flight.
      // If we already showed cache, never block the soft refresh on contacts.
      final List<StoreChannel> stores;
      final awaitContacts =
          !paintedFromCache &&
          (DeviceContactNames.isReady || DeviceContactNames.isLoading);
      if (awaitContacts) {
        stores = await _mapAndEnrich(page.items);
      } else if (DeviceContactNames.isReady) {
        stores = [
          for (final store in _mapStores(page.items))
            store.copyWith(
              contactName:
                  DeviceContactNames.lookup(store.phone)?.trim() ?? '',
            ),
        ];
      } else {
        stores = _applyCachedContactNames(_mapStores(page.items));
      }

      AppLog.d(_tag, 'Loaded ${stores.length} stores');
      emit(
        state.copyWith(
          isLoading: false,
          allStores: stores,
          nextCursor: page.nextCursor,
        ),
      );
      await _persistHome(page, stores);
      _afterHomePaint(stores, page.items);

      if (!DeviceContactNames.isReady) {
        final enriched = await _enrichContactNames(stores);
        if (!emit.isDone) {
          emit(state.copyWith(allStores: enriched));
          await _persistHome(page, enriched);
        }
      }
    } catch (e) {
      AppLog.e(_tag, 'Home load failed', e);
      // Keep cached rows if we already painted them.
      if (state.allStores.isNotEmpty) {
        emit(state.copyWith(isLoading: false, clearError: true));
      } else {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: CatalogErrorMapper.toUserMessage(e),
          ),
        );
      }
    }
  }

  /// Returns true when disk/memory home was emitted (skip empty shimmer).
  Future<bool> _tryPaintCachedHome(Emitter<StoreListingState> emit) async {
    final page =
        StoreHomeCache.instance.readMemory() ??
        await StoreHomeCache.instance.read();
    if (page == null || page.items.isEmpty) return false;

    var stores = _applyCachedContactNames(_mapStores(page.items));
    if (DeviceContactNames.isReady) {
      stores = [
        for (final store in stores)
          store.copyWith(
            contactName:
                DeviceContactNames.lookup(store.phone)?.trim() ??
                store.contactName,
          ),
      ];
    }

    final covers = [for (final s in stores) s.coverImageUrl];
    // Re-attach on-disk files (fast) so FileImage paints without network flash.
    // Full decode may already be in flight from auth/home prefetch.
    await CatalogImageCache.probeDisk(covers);
    unawaited(CatalogImageCache.warmAvatars(covers));

    AppLog.d(_tag, 'Painted ${stores.length} stores from home cache');
    emit(
      state.copyWith(
        isLoading: false,
        allStores: stores,
        nextCursor: page.nextCursor,
      ),
    );
    _afterHomePaint(stores, page.items);

    if (!DeviceContactNames.isReady) {
      // ignore: unawaited_futures
      () async {
        final enriched = await _enrichContactNames(stores);
        if (isClosed) return;
        add(StoreListingCachedNamesReady(enriched));
      }();
    }
    return true;
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
      final cover = s.coverImageUrl.trim();
      if (cover.isNotEmpty) {
        unawaited(StoreMetaCache.instance.writeCover(s.id, cover));
      }
    }
  }

  Future<void> _persistHome(
    CatalogPage<CatalogStore> page,
    List<StoreChannel> stores,
  ) async {
    final names = <String, String>{
      for (final s in stores)
        if (s.phone.trim().isNotEmpty && s.contactName.trim().isNotEmpty)
          s.phone.trim(): s.contactName.trim(),
    };
    await StoreHomeCache.instance.write(page, contactNames: names);
  }

  List<StoreChannel> _applyCachedContactNames(List<StoreChannel> stores) {
    final cached = StoreHomeCache.instance.contactNamesMemory();
    if (cached.isEmpty) return stores;
    return [
      for (final store in stores)
        store.copyWith(
          contactName:
              cached[store.phone.trim()]?.trim() ?? store.contactName,
        ),
    ];
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
      emit(
        state.copyWith(
          isLoadingMore: false,
          allStores: [...state.allStores, ...mapped],
          nextCursor: page.nextCursor,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Load more failed', e);
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

  Future<void> _onCachedNamesReady(
    StoreListingCachedNamesReady event,
    Emitter<StoreListingState> emit,
  ) async {
    if (event.stores.isEmpty) return;
    if (state.allStores.length != event.stores.length) return;
    emit(state.copyWith(allStores: event.stores));
    final mem = StoreHomeCache.instance.readMemory();
    if (mem != null) {
      await _persistHome(mem, event.stores);
    }
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
          contactName: DeviceContactNames.lookup(store.phone)?.trim() ?? '',
        ),
    ];
  }

  Future<List<StoreChannel>> _mapAndEnrich(
    List<CatalogStore> stores, {
    int colorOffset = 0,
  }) async {
    return _enrichContactNames(_mapStores(stores, colorOffset: colorOffset));
  }
}
