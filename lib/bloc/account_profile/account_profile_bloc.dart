import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/catalog_profile.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/profile/profile_repository.dart';

part 'account_profile_event.dart';
part 'account_profile_state.dart';

/// Owns GET /me for the Profile + Settings tabs (no blocking loaders).
class AccountProfileBloc
    extends Bloc<AccountProfileEvent, AccountProfileState> {
  AccountProfileBloc({
    ProfileRepository? profileRepository,
    CatalogSession? session,
  }) : _profileRepository =
           profileRepository ?? ServiceLocator.get<ProfileRepository>(),
       _session = session ?? ServiceLocator.get<CatalogSession>(),
       super(const AccountProfileState()) {
    on<AccountProfileStarted>(_onStarted);
    on<AccountProfileRefreshed>(_onRefreshed);
    on<AccountProfileDeleteRequested>(_onDeleteRequested);
    on<AccountProfileClearMessage>(_onClearMessage);
    on<AccountProfileClearAccountDeleted>(_onClearAccountDeleted);
    add(const AccountProfileStarted());
  }

  final ProfileRepository _profileRepository;
  final CatalogSession _session;
  static const _tag = 'AccountProfileBloc';

  Future<void> _onStarted(
    AccountProfileStarted event,
    Emitter<AccountProfileState> emit,
  ) async {
    final cached = _session.profile;
    if (cached != null) {
      emit(state.copyWith(profile: cached));
    }
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
      final profile = await _profileRepository.fetchMe();
      AppLog.d(_tag, 'GET /me → ${profile.displayName}');
      emit(
        state.copyWith(
          isRefreshing: false,
          profile: profile,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'GET /me failed', e);
      emit(
        state.copyWith(
          isRefreshing: false,
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
