import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/models/catalog/catalog_profile.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/profile/profile_repository.dart';

part 'account_profile_event.dart';
part 'account_profile_state.dart';

/// Owns GET /me for the Profile + Settings tabs (no blocking loaders).
///
/// Cache-first: paint [CatalogSession] immediately; API writes session then
/// UI re-reads session. Image upload/delete → POST/DELETE → GET /me → cache.
class AccountProfileBloc
    extends Bloc<AccountProfileEvent, AccountProfileState> {
  AccountProfileBloc({
    ProfileRepository? profileRepository,
    CatalogSession? session,
    ImagePicker? imagePicker,
  }) : _profileRepository =
           profileRepository ?? ServiceLocator.get<ProfileRepository>(),
       _session = session ?? ServiceLocator.get<CatalogSession>(),
       _imagePicker = imagePicker ?? ImagePicker(),
       super(const AccountProfileState()) {
    on<AccountProfileStarted>(_onStarted);
    on<AccountProfileRefreshed>(_onRefreshed);
    on<AccountProfilePickImageRequested>(_onPickImageRequested);
    on<AccountProfileRemoveImageRequested>(_onRemoveImageRequested);
    on<AccountProfileDeleteRequested>(_onDeleteRequested);
    on<AccountProfileClearMessage>(_onClearMessage);
    on<AccountProfileClearAccountDeleted>(_onClearAccountDeleted);
    add(const AccountProfileStarted());
  }

  final ProfileRepository _profileRepository;
  final CatalogSession _session;
  final ImagePicker _imagePicker;
  static const _tag = 'AccountProfileBloc';

  Future<void> _onStarted(
    AccountProfileStarted event,
    Emitter<AccountProfileState> emit,
  ) async {
    // Show disk/memory session cache first (e.g. profile completed with no image).
    _emitFromCache(emit);
    await _refreshQuietly(emit);
  }

  Future<void> _onRefreshed(
    AccountProfileRefreshed event,
    Emitter<AccountProfileState> emit,
  ) async {
    await _refreshQuietly(emit);
  }

  Future<void> _refreshQuietly(Emitter<AccountProfileState> emit) async {
    emit(state.copyWith(isRefreshing: true, clearError: true));
    try {
      await _profileRepository.fetchMe();
      AppLog.d(_tag, 'GET /me → ${_session.profile?.displayName}');
      _emitFromCache(emit, isRefreshing: false, clearError: true);
    } catch (e) {
      AppLog.e(_tag, 'GET /me failed', e);
      // Keep showing last cached profile on refresh failure.
      _emitFromCache(
        emit,
        isRefreshing: false,
        errorMessage: CatalogErrorMapper.toUserMessage(e),
      );
    }
  }

  /// Emit only what [CatalogSession] holds (after API has written cache).
  void _emitFromCache(
    Emitter<AccountProfileState> emit, {
    bool? isRefreshing,
    bool? isUpdatingImage,
    String? errorMessage,
    bool clearError = false,
  }) {
    final cached = _session.profile;
    if (cached != null) {
      final url = cached.effectiveProfileImageUrl.trim();
      if (url.isNotEmpty) {
        unawaited(CatalogImageCache.precacheUrls([url]));
      }
    }
    if (emit.isDone) return;
    emit(
      state.copyWith(
        profile: cached ?? state.profile,
        isRefreshing: isRefreshing,
        isUpdatingImage: isUpdatingImage,
        errorMessage: errorMessage,
        clearError: clearError,
      ),
    );
  }

  Future<void> _onPickImageRequested(
    AccountProfilePickImageRequested event,
    Emitter<AccountProfileState> emit,
  ) async {
    if (state.isUpdatingImage) return;
    emit(state.copyWith(isUpdatingImage: true, clearError: true));
    try {
      final picked = await _imagePicker.pickImage(
        source: event.source,
        imageQuality: 85,
      );
      if (picked == null) {
        emit(state.copyWith(isUpdatingImage: false));
        return;
      }
      // POST → GET /me → session cache (repository), then paint from cache.
      await _profileRepository.uploadProfileImage(File(picked.path));
      AppLog.d(_tag, 'Profile image uploaded');
      _emitFromCache(emit, isUpdatingImage: false, clearError: true);
    } catch (e) {
      AppLog.e(_tag, 'Profile image upload failed', e);
      emit(
        state.copyWith(
          isUpdatingImage: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _onRemoveImageRequested(
    AccountProfileRemoveImageRequested event,
    Emitter<AccountProfileState> emit,
  ) async {
    if (state.isUpdatingImage) return;
    emit(state.copyWith(isUpdatingImage: true, clearError: true));
    try {
      await _profileRepository.deleteProfileImage();
      AppLog.d(_tag, 'Profile image deleted');
      _emitFromCache(emit, isUpdatingImage: false, clearError: true);
    } catch (e) {
      AppLog.e(_tag, 'Profile image delete failed', e);
      emit(
        state.copyWith(
          isUpdatingImage: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _onDeleteRequested(
    AccountProfileDeleteRequested event,
    Emitter<AccountProfileState> emit,
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
      AppLog.d(_tag, 'DELETE /me success');
      emit(
        state.copyWith(isDeletingAccount: false, accountDeleted: true),
      );
    } catch (e) {
      AppLog.e(_tag, 'DELETE /me failed', e);
      emit(
        state.copyWith(
          isDeletingAccount: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  void _onClearMessage(
    AccountProfileClearMessage event,
    Emitter<AccountProfileState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }

  void _onClearAccountDeleted(
    AccountProfileClearAccountDeleted event,
    Emitter<AccountProfileState> emit,
  ) {
    emit(state.copyWith(clearAccountDeleted: true));
  }
}
