import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/catalog_store.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/profile/profile_repository.dart';
import 'package:project_c/webservice/store/store_repository.dart';
import 'package:project_c/webservice/store/store_request.dart';

part 'store_setup_event.dart';
part 'store_setup_state.dart';

class StoreSetupBloc extends Bloc<StoreSetupEvent, StoreSetupState> {
  StoreSetupBloc({
    StoreRepository? storeRepository,
    ProfileRepository? profileRepository,
    ImagePicker? imagePicker,
  }) : _storeRepository =
           storeRepository ?? ServiceLocator.get<StoreRepository>(),
       _profileRepository =
           profileRepository ?? ServiceLocator.get<ProfileRepository>(),
       _imagePicker = imagePicker ?? ImagePicker(),
       super(const StoreSetupState()) {
    on<StoreNameChanged>(_onStoreNameChanged);
    on<StoreAvailabilityCheckRequested>(_onAvailabilityCheckRequested);
    on<StoreImagesPickRequested>(_onImagesPickRequested);
    on<StoreImageRemoved>(_onImageRemoved);
    on<StoreCreatePressed>(_onCreatePressed);
    on<StoreSkipPressed>(_onSkipPressed);
    on<StoreClearMessage>(_onClearMessage);
    on<StoreClearCompleted>(_onClearCompleted);
  }

  final StoreRepository _storeRepository;
  final ProfileRepository _profileRepository;
  final ImagePicker _imagePicker;
  Timer? _checkDebounceTimer;
  static const _tag = 'StoreSetupBloc';

  /// Downscale on pick so multipart create/append stays under nginx body limits.
  static const _pickMaxDimension = 1600.0;
  static const _pickQuality = 80;

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

  Future<void> _onImagesPickRequested(
    StoreImagesPickRequested event,
    Emitter<StoreSetupState> emit,
  ) async {
    final remaining = StoreRequest.maxStoreImages - state.imagePaths.length;
    if (remaining <= 0 || state.isPickingImages) return;
    emit(state.copyWith(isPickingImages: true, clearError: true));
    try {
      final picked = await _imagePicker.pickMultiImage(
        imageQuality: _pickQuality,
        maxWidth: _pickMaxDimension,
        maxHeight: _pickMaxDimension,
      );
      if (picked.isEmpty) {
        emit(state.copyWith(isPickingImages: false));
        return;
      }
      final next = [
        ...state.imagePaths,
        ...picked.map((e) => e.path).take(remaining),
      ];
      emit(
        state.copyWith(
          imagePaths: next,
          isPickingImages: false,
          clearError: picked.length <= remaining,
          errorMessage:
              picked.length > remaining
                  ? 'Only $remaining more photo(s) could be added (max ${StoreRequest.maxStoreImages}).'
                  : null,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Pick store images failed', e);
      emit(
        state.copyWith(
          isPickingImages: false,
          errorMessage: 'Unable to open image picker right now.',
        ),
      );
    }
  }

  void _onImageRemoved(StoreImageRemoved event, Emitter<StoreSetupState> emit) {
    if (event.index < 0 || event.index >= state.imagePaths.length) return;
    final next = List<String>.from(state.imagePaths)..removeAt(event.index);
    emit(state.copyWith(imagePaths: next, clearError: true));
  }

  Future<void> _onCreatePressed(
    StoreCreatePressed event,
    Emitter<StoreSetupState> emit,
  ) async {
    if (!state.canContinue) return;
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final files =
          state.imagePaths
              .where((p) => p.trim().isNotEmpty)
              .map(File.new)
              .toList();
      final store = await _createStoreResilient(
        name: state.storeName.trim(),
        slug: state.storeHandle,
        imageFiles: files,
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

  /// Avoids nginx 413 by never sending all showcase photos in one multipart.
  ///
  /// Create with the first photo (or none), then append remaining files
  /// one-by-one. If a single-file create still hits 413, create without
  /// images and append each file separately.
  Future<CatalogStore> _createStoreResilient({
    required String name,
    required String slug,
    required List<File> imageFiles,
  }) async {
    if (imageFiles.isEmpty) {
      return _storeRepository.createStore(name: name, slug: slug);
    }

    CatalogStore store;
    var pending = List<File>.from(imageFiles);

    try {
      store = await _storeRepository.createStore(
        name: name,
        slug: slug,
        imageFiles: [pending.first],
      );
      pending = pending.sublist(1);
    } on CatalogApiException catch (e) {
      if (!_isPayloadTooLarge(e)) rethrow;
      AppLog.d(
        _tag,
        'createStore 413 with first image — create without images then append',
      );
      store = await _storeRepository.createStore(name: name, slug: slug);
      // Keep full list for append below.
    }

    var appendFailed = 0;
    for (var i = 0; i < pending.length; i++) {
      try {
        store = await _storeRepository.appendStoreImages(
          storeId: store.id,
          imageFiles: [pending[i]],
        );
      } catch (e) {
        appendFailed++;
        AppLog.e(_tag, 'appendStoreImages failed index=$i', e);
        // Continue so a partial image failure does not leave the user stuck
        // with STORE_ALREADY_OWNED on retry after the store was created.
      }
    }

    if (appendFailed > 0) {
      AppLog.d(
        _tag,
        'Store created but $appendFailed showcase photo(s) failed to upload',
      );
    }
    return store;
  }

  bool _isPayloadTooLarge(CatalogApiException e) {
    return e.statusCode == 413 ||
        e.code == 'HTTP_413' ||
        e.code == 'PAYLOAD_TOO_LARGE' ||
        e.code == 'REQUEST_ENTITY_TOO_LARGE';
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
