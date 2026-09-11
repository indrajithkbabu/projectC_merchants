import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/profile/profile_repository.dart';
import 'package:project_c/webservice/store/store_repository.dart';

part 'store_setup_event.dart';
part 'store_setup_state.dart';

class StoreSetupBloc extends Bloc<StoreSetupEvent, StoreSetupState> {
  StoreSetupBloc({
    StoreRepository? storeRepository,
    ProfileRepository? profileRepository,
  }) : _storeRepository =
           storeRepository ?? ServiceLocator.get<StoreRepository>(),
       _profileRepository =
           profileRepository ?? ServiceLocator.get<ProfileRepository>(),
       super(const StoreSetupState()) {
    on<StoreNameChanged>(_onStoreNameChanged);
    on<StoreAvailabilityCheckRequested>(_onAvailabilityCheckRequested);
    on<StoreCreatePressed>(_onCreatePressed);
    on<StoreSkipPressed>(_onSkipPressed);
    on<StoreClearMessage>(_onClearMessage);
    on<StoreClearCompleted>(_onClearCompleted);
  }

  final StoreRepository _storeRepository;
  final ProfileRepository _profileRepository;
  Timer? _checkDebounceTimer;
  static const _tag = 'StoreSetupBloc';

  void _onStoreNameChanged(
    StoreNameChanged event,
    Emitter<StoreSetupState> emit,
  ) {
    final handle = _slugify(event.value);
    emit(
      state.copyWith(
        storeName: event.value,
        storeHandle: handle,
        availabilityStatus:
            handle.isEmpty
                ? StoreLinkAvailabilityStatus.idle
                : StoreLinkAvailabilityStatus.checking,
        clearError: true,
      ),
    );

    _checkDebounceTimer?.cancel();
    if (handle.isEmpty || !_isValidSlug(handle)) return;
    _checkDebounceTimer = Timer(const Duration(milliseconds: 400), () {
      add(StoreAvailabilityCheckRequested(handle));
    });
  }

  Future<void> _onAvailabilityCheckRequested(
    StoreAvailabilityCheckRequested event,
    Emitter<StoreSetupState> emit,
  ) async {
    if (event.handle != state.storeHandle || event.handle.isEmpty) return;
    if (!_isValidSlug(event.handle)) {
      emit(
        state.copyWith(
          availabilityStatus: StoreLinkAvailabilityStatus.unavailable,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        availabilityStatus: StoreLinkAvailabilityStatus.checking,
        clearError: true,
      ),
    );
    try {
      final result = await _storeRepository.checkSlugAvailability(event.handle);
      if (event.handle != state.storeHandle) return;
      emit(
        state.copyWith(
          availabilityStatus:
              result.available
                  ? StoreLinkAvailabilityStatus.available
                  : StoreLinkAvailabilityStatus.unavailable,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Slug check failed', e);
      if (event.handle != state.storeHandle) return;
      emit(
        state.copyWith(
          availabilityStatus: StoreLinkAvailabilityStatus.idle,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _onCreatePressed(
    StoreCreatePressed event,
    Emitter<StoreSetupState> emit,
  ) async {
    if (!state.canContinue) return;
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final store = await _storeRepository.createStore(
        name: state.storeName.trim(),
        slug: state.storeHandle,
      );
      AppLog.d(_tag, 'Store created id=${store.id}');
      emit(
        state.copyWith(
          isSubmitting: false,
          isCompleted: true,
          createdStoreId: store.id,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Store create failed', e);
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _onSkipPressed(
    StoreSkipPressed event,
    Emitter<StoreSetupState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _profileRepository.skipStoreOnboarding();
      AppLog.d(_tag, 'Store onboarding skipped');
      emit(
        state.copyWith(
          isSubmitting: false,
          isCompleted: true,
          skippedStore: true,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Skip store failed', e);
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  void _onClearMessage(StoreClearMessage event, Emitter<StoreSetupState> emit) {
    emit(state.copyWith(clearError: true));
  }

  void _onClearCompleted(
    StoreClearCompleted event,
    Emitter<StoreSetupState> emit,
  ) {
    emit(state.copyWith(clearCompleted: true));
  }

  bool _isValidSlug(String slug) {
    return RegExp(r'^[a-z0-9](?:[a-z0-9]|-(?=[a-z0-9])){2,49}$').hasMatch(slug);
  }

  String _slugify(String value) {
    final lower = value.toLowerCase().trim();
    final clean = lower.replaceAll(RegExp(r'[^a-z0-9\s-]'), '');
    final hyphenated = clean.replaceAll(RegExp(r'[\s-]+'), '-');
    return hyphenated.replaceAll(RegExp(r'^-+|-+$'), '');
  }

  @override
  Future<void> close() {
    _checkDebounceTimer?.cancel();
    return super.close();
  }
}
