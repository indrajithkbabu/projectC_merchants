import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/catalog_ui_mapper.dart';
import 'package:project_c/helper/device_contact_names.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/models/catalog/catalog_store.dart';
import 'package:project_c/models/store_channel.dart';
import 'package:project_c/services/store_home_prefetcher.dart';
import 'package:project_c/services/store_products_prefetcher.dart';
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
       // Start loading so first paint shows shimmer until warm/network arrives.
       super(const StoreListingState(isLoading: true)) {
    on<StoreListingSearchChanged>(_onSearchChanged);
    on<StoreListingRefreshed>(_onRefreshed);
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
    // Keep previous rows visible — never flash a blocking loader.
    final useWarm = state.allStores.isEmpty;
    emit(state.copyWith(isLoading: true, clearError: true, clearCursor: true));
    try {
      final page =
          useWarm
              ? await StoreHomePrefetcher.instance.ensure(limit: 40)
              : await StoreHomePrefetcher.instance.refresh(limit: 40);

      // Never block first paint on the contacts permission dialog (Android
      // hangs if a second request races). Use warm names when ready; else
      // paint phones first and enrich after.
      final List<StoreChannel> stores;
      if (DeviceContactNames.isReady) {
        stores = await _mapAndEnrich(page.items);
      } else {
        stores = _mapStores(page.items);
      }
      AppLog.d(_tag, 'Loaded ${stores.length} stores');
      emit(
        state.copyWith(
          isLoading: false,
          allStores: stores,
          nextCursor: page.nextCursor,
        ),
      );
      // Soft-warm first few store product grids while user browses the list.
      StoreProductsPrefetcher.instance.prefetchVisible([
        for (final s in stores) (id: s.id, coverImageUrl: s.coverImageUrl),
      ]);
      // Warm store logos so profile header / listing avatar don't flash-load.
      unawaited(
        CatalogImageCache.precacheUrls([
          for (final s in stores) ...s.imageUrls,
        ]),
      );
      for (final s in page.items) {
        final cover = s.coverImageUrl.trim();
        if (cover.isNotEmpty) {
          unawaited(StoreMetaCache.instance.writeCover(s.id, cover));
        }
      }

      if (!DeviceContactNames.isReady) {
        final enriched = await _enrichContactNames(stores);
        if (!emit.isDone) {
          emit(state.copyWith(allStores: enriched));
        }
      }
    } catch (e) {
      AppLog.e(_tag, 'Home load failed', e);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
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
