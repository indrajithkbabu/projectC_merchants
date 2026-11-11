import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/profile_switching_log.dart';
import 'package:project_c/models/catalog/profile_context.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/services/store_home_prefetcher.dart';
import 'package:project_c/services/store_products_prefetcher.dart';
import 'package:project_c/services/wishlist_prefetcher.dart';
import 'package:project_c/storage/store_home_cache.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/profile/profile_repository.dart';
import 'package:project_c/webservice/store/store_repository.dart';

part 'profile_context_event.dart';
part 'profile_context_state.dart';

class ProfileContextBloc
    extends Bloc<ProfileContextEvent, ProfileContextState> {
  ProfileContextBloc({
    ProfileRepository? profileRepository,
    StoreRepository? storeRepository,
    CatalogSession? session,
  }) : _profileRepository =
           profileRepository ?? ServiceLocator.get<ProfileRepository>(),
       _storeRepository =
           storeRepository ?? ServiceLocator.get<StoreRepository>(),
       _session = session ?? ServiceLocator.get<CatalogSession>(),
       super(
         ProfileContextState(
           bootstrap:
               (session ?? ServiceLocator.get<CatalogSession>()).bootstrap,
         ),
       ) {
    on<ProfileContextStarted>(_onStarted);
    on<ProfileContextRefreshed>(_onRefreshed);
    on<ProfileContextSelectProfile>(_onSelectProfile);
    on<ProfileContextAcceptInvite>(_onAcceptInvite);
    on<ProfileContextDeclineInvite>(_onDeclineInvite);
    on<ProfileContextAccessRemovedRecover>(_onAccessRemovedRecover);
    on<ProfileContextSelectCreatedStore>(_onSelectCreatedStore);
    on<ProfileContextLeaveActiveStore>(_onLeaveActiveStore);
    on<ProfileContextDeleteActiveStore>(_onDeleteActiveStore);
    on<ProfileContextClearToast>(_onClearToast);
    on<ProfileContextClearError>(_onClearError);
    on<ProfileContextClearSwitchAnimation>(_onClearSwitchAnimation);
  }

  static const _tag = 'ProfileContextBloc';

  final ProfileRepository _profileRepository;
  final StoreRepository _storeRepository;
  final CatalogSession _session;

  int _switchToken = 0;

  Future<void> _onStarted(
    ProfileContextStarted event,
    Emitter<ProfileContextState> emit,
  ) async {
    final active = _session.activeProfile;
    ProfileSwitchingLog.d(
      'PS-04/10/24',
      'ProfileContextStarted active=${active?.id ?? "(none)"} '
      'role=${active?.role.name ?? "(none)"} '
      'inviteDot=${state.hasOtherUnreadOrInvite} '
      'canCreate=${state.canCreateStore}',
    );
    emit(state.copyWith(bootstrap: _session.bootstrap, clearError: true));
    await _refreshQuietly(emit);
  }

  Future<void> _onRefreshed(
    ProfileContextRefreshed event,
    Emitter<ProfileContextState> emit,
  ) async {
    if (event.quiet) {
      await _refreshQuietly(emit);
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final bootstrap = await _profileRepository.fetchProfiles();
      ProfileSwitchingLog.d(
        'PS-20/24/45',
        'profiles refreshed active=${bootstrap.activeProfile.id} '
        'profiles=${bootstrap.profiles.length} '
        'pendingInvites=${bootstrap.pendingInvitations.length} '
        'inviteSummary pending=${bootstrap.invitationSummary.pendingCount}',
      );
      emit(
        state.copyWith(
          bootstrap: bootstrap,
          isLoading: false,
          clearError: true,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'fetchProfiles failed', e);
      if (_isAccessRemoved(e)) {
        add(const ProfileContextAccessRemovedRecover());
        return;
      }
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _refreshQuietly(Emitter<ProfileContextState> emit) async {
    try {
      final bootstrap = await _profileRepository.fetchProfiles();
      final prevActive = state.activeProfile?.id;
      final prevInvites = state.bootstrap?.pendingInvitations.length ?? 0;
      final nextInvites = bootstrap.pendingInvitations.length;
      if (prevActive != bootstrap.activeProfile.id ||
          prevInvites != nextInvites) {
        ProfileSwitchingLog.d(
          'PS-24/70',
          'quiet refresh active=${bootstrap.activeProfile.id} '
          'pendingInvites=$nextInvites',
        );
      }
      emit(state.copyWith(bootstrap: bootstrap, clearError: true));
    } catch (e) {
      AppLog.e(_tag, 'quiet refresh failed', e);
      if (_isAccessRemoved(e)) {
        add(const ProfileContextAccessRemovedRecover());
      }
    }
  }

  Future<void> _onSelectProfile(
    ProfileContextSelectProfile event,
    Emitter<ProfileContextState> emit,
  ) async {
    final profileId = event.profileId.trim();
    if (profileId.isEmpty) return;
    if (state.activeProfile?.id == profileId) return;

    ActableProfile? target;
    for (final p in state.bootstrap?.profiles ?? const <ActableProfile>[]) {
      if (p.id == profileId) {
        target = p;
        break;
      }
    }

    final fromId = state.activeProfile?.id ?? '(none)';
    ProfileSwitchingLog.d(
      'PS-22/23/70/74',
      'select start from=$fromId to=$profileId '
      'targetRole=${target?.role.name ?? "(unknown)"}',
    );

    emit(
      state.copyWith(
        isSwitching: true,
        switchTarget: target,
        switchAnimationToken: ++_switchToken,
        clearError: true,
        clearToast: true,
      ),
    );

    try {
      final bootstrap = await _profileRepository.selectActiveProfile(profileId);
      _warmCachesFor(bootstrap.activeProfile);
      ProfileSwitchingLog.d(
        'PS-22/23/63/64',
        'select ok active=${bootstrap.activeProfile.id} '
        'role=${bootstrap.activeProfile.role.name} '
        'name=${bootstrap.activeProfile.name} '
        'messageScope=as ${bootstrap.activeProfile.name}',
      );
      emit(
        state.copyWith(
          bootstrap: bootstrap,
          isSwitching: false,
          switchTarget: bootstrap.activeProfile,
          clearError: true,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'selectActiveProfile failed', e);
      ProfileSwitchingLog.e('PS-22/32', 'select failed to=$profileId', e);
      if (_isAccessRemoved(e)) {
        add(const ProfileContextAccessRemovedRecover());
        return;
      }
      emit(
        state.copyWith(
          isSwitching: false,
          clearSwitchAnimation: true,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _onAcceptInvite(
    ProfileContextAcceptInvite event,
    Emitter<ProfileContextState> emit,
  ) async {
    final id = event.invitationId.trim();
    if (id.isEmpty) return;
    emit(state.copyWith(isLoading: true, clearError: true, clearToast: true));
    final beforeActive = state.activeProfile?.id ?? '(none)';
    try {
      final invite = await _profileRepository.acceptInvitation(id);
      final bootstrap = await _profileRepository.fetchProfiles();
      final name = invite.displayName;
      ProfileSwitchingLog.d(
        'PS-43/71/75',
        'accept invite ok id=$id name=$name '
        'activeStill=$beforeActive '
        '(no auto-switch) newActive=${bootstrap.activeProfile.id} '
        'profiles=${bootstrap.profiles.length}',
      );
      emit(
        state.copyWith(
          bootstrap: bootstrap,
          isLoading: false,
          toastMessage: name.isEmpty ? 'Joined store' : 'You joined $name',
          clearError: true,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'acceptInvitation failed', e);
      ProfileSwitchingLog.e('PS-43/75', 'accept invite failed id=$id', e);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _onDeclineInvite(
    ProfileContextDeclineInvite event,
    Emitter<ProfileContextState> emit,
  ) async {
    final id = event.invitationId.trim();
    if (id.isEmpty) return;
    emit(state.copyWith(isLoading: true, clearError: true, clearToast: true));
    try {
      await _profileRepository.declineInvitation(id);
      final bootstrap = await _profileRepository.fetchProfiles();
      ProfileSwitchingLog.d(
        'PS-44',
        'decline invite ok id=$id '
        'pendingLeft=${bootstrap.pendingInvitations.length}',
      );
      emit(
        state.copyWith(
          bootstrap: bootstrap,
          isLoading: false,
          toastMessage: 'Invite declined',
          clearError: true,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'declineInvitation failed', e);
      ProfileSwitchingLog.e('PS-44', 'decline invite failed id=$id', e);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _onAccessRemovedRecover(
    ProfileContextAccessRemovedRecover event,
    Emitter<ProfileContextState> emit,
  ) async {
    AppLog.d(_tag, 'PROFILE_ACCESS_REMOVED recovery');
    final previousActiveId = state.activeProfile?.id.trim() ?? '';
    ProfileSwitchingLog.d(
      'PS-53/54/72/73',
      'PROFILE_ACCESS_REMOVED recovery start '
      'previousActive=$previousActiveId',
    );
    emit(
      state.copyWith(
        isLoading: true,
        isSwitching: false,
        clearSwitchAnimation: true,
        clearError: true,
      ),
    );
    try {
      StoreHomePrefetcher.instance.invalidate();
      // Omit stale X-Catalog-Profile: fetchProfiles uses omitProfileHeader.
      final bootstrap = await _profileRepository.fetchProfiles();
      final activeId = bootstrap.activeProfile.id.trim();
      final stillSelectable = bootstrap.profiles.any(
        (p) => p.id == activeId && p.selectable,
      );

      var next = bootstrap;
      // Only force Personal when the restored active profile is itself invalid.
      // Do not discard a different still-valid active profile because an older
      // queued request for another store failed.
      if (!stillSelectable) {
        final personal = _findPersonal(bootstrap);
        ProfileSwitchingLog.d(
          'PS-53/72',
          'active invalid → force Personal '
          'personal=${personal?.id ?? "(none)"}',
        );
        if (personal != null && personal.id.trim().isNotEmpty) {
          next = await _profileRepository.selectActiveProfile(personal.id);
        } else {
          await _session.applyBootstrap(bootstrap);
        }
      } else {
        // fetchProfiles already commits; keep session/UI aligned with returned
        // active profile (may still be a valid non-Personal store).
        ProfileSwitchingLog.d(
          'PS-54',
          'active still valid → keep active=$activeId '
          '(do not wipe unrelated profile)',
        );
        await _session.applyBootstrap(bootstrap);
      }

      final lostActive =
          previousActiveId.isNotEmpty &&
          !next.profiles.any((p) => p.id == previousActiveId && p.selectable);

      ProfileSwitchingLog.d(
        'PS-53/54/72/73',
        'recovery done nextActive=${next.activeProfile.id} '
        'lostPrevious=$lostActive',
      );

      emit(
        state.copyWith(
          bootstrap: next,
          isLoading: false,
          toastMessage:
              lostActive
                  ? 'You no longer have access to that store'
                  : null,
          clearToast: !lostActive,
          clearError: true,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'access-removed recovery failed', e);
      ProfileSwitchingLog.e('PS-53', 'access-removed recovery failed', e);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _onSelectCreatedStore(
    ProfileContextSelectCreatedStore event,
    Emitter<ProfileContextState> emit,
  ) async {
    final storeId = event.storeId.trim();
    if (storeId.isEmpty) return;
    final profileId = 'store:$storeId';
    final name = event.storeName.trim();
    ProfileSwitchingLog.d(
      'PS-30/32/34',
      'selectCreatedStore start storeId=$storeId name=$name',
    );
    emit(
      state.copyWith(
        isSwitching: true,
        switchAnimationToken: ++_switchToken,
        clearError: true,
        clearToast: true,
      ),
    );
    try {
      final bootstrap = await _profileRepository.selectActiveProfile(profileId);
      _warmCachesFor(bootstrap.activeProfile);
      ProfileSwitchingLog.d(
        'PS-30/34',
        'selectCreatedStore ok active=${bootstrap.activeProfile.id} '
        'role=${bootstrap.activeProfile.role.name} ownerChrome expected',
      );
      emit(
        state.copyWith(
          bootstrap: bootstrap,
          isSwitching: false,
          switchTarget: bootstrap.activeProfile,
          toastMessage: name.isEmpty ? 'Store created' : '$name created',
          clearError: true,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'selectCreatedStore failed', e);
      ProfileSwitchingLog.e(
        'PS-32',
        'select after create failed storeId=$storeId '
        '(do not create again)',
        e,
      );
      emit(
        state.copyWith(
          isSwitching: false,
          clearSwitchAnimation: true,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _onLeaveActiveStore(
    ProfileContextLeaveActiveStore event,
    Emitter<ProfileContextState> emit,
  ) async {
    final storeId = state.activeStoreId?.trim() ?? '';
    if (storeId.isEmpty) return;
    final storeName = state.activeProfile?.name.trim() ?? '';
    ProfileSwitchingLog.d(
      'PS-50',
      'leave store start storeId=$storeId name=$storeName',
    );
    emit(state.copyWith(isLoading: true, clearError: true, clearToast: true));
    try {
      await _storeRepository.leaveStore(storeId);
      final bootstrap = await _profileRepository.fetchProfiles();
      final personal = _findPersonal(bootstrap);
      var next = bootstrap;
      if (personal != null && bootstrap.activeProfile.id != personal.id) {
        next = await _profileRepository.selectActiveProfile(personal.id);
      }
      ProfileSwitchingLog.d(
        'PS-50',
        'leave ok nextActive=${next.activeProfile.id} '
        'storeGone=${!next.profiles.any((p) => p.accountId == storeId)}',
      );
      emit(
        state.copyWith(
          bootstrap: next,
          isLoading: false,
          toastMessage:
              storeName.isEmpty
                  ? 'You left the store'
                  : 'You left $storeName',
          clearError: true,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'leaveActiveStore failed', e);
      ProfileSwitchingLog.e('PS-50/51', 'leave store failed', e);
      if (_isAccessRemoved(e)) {
        add(const ProfileContextAccessRemovedRecover());
        return;
      }
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _onDeleteActiveStore(
    ProfileContextDeleteActiveStore event,
    Emitter<ProfileContextState> emit,
  ) async {
    final storeId = state.activeStoreId?.trim() ?? '';
    if (storeId.isEmpty) return;
    final storeName = state.activeProfile?.name.trim() ?? '';
    ProfileSwitchingLog.d(
      'PS-52/73',
      'delete store start storeId=$storeId name=$storeName',
    );
    emit(state.copyWith(isLoading: true, clearError: true, clearToast: true));
    try {
      final bootstrap = await _storeRepository.deleteStore(storeId);
      ProfileSwitchingLog.d(
        'PS-52/73',
        'delete ok nextActive=${bootstrap.activeProfile.id} '
        'owned=${bootstrap.storeCreation.ownedStoreCount} '
        'canCreate=${bootstrap.storeCreation.canCreate}',
      );
      emit(
        state.copyWith(
          bootstrap: bootstrap,
          isLoading: false,
          toastMessage:
              storeName.isEmpty ? 'Store deleted' : '$storeName deleted',
          clearError: true,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'deleteActiveStore failed', e);
      ProfileSwitchingLog.e('PS-52', 'delete store failed', e);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  void _onClearToast(
    ProfileContextClearToast event,
    Emitter<ProfileContextState> emit,
  ) {
    emit(state.copyWith(clearToast: true));
  }

  void _onClearError(
    ProfileContextClearError event,
    Emitter<ProfileContextState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }

  void _onClearSwitchAnimation(
    ProfileContextClearSwitchAnimation event,
    Emitter<ProfileContextState> emit,
  ) {
    emit(state.copyWith(clearSwitchAnimation: true, isSwitching: false));
  }

  ActableProfile? _findPersonal(ProfileBootstrap bootstrap) {
    for (final p in bootstrap.profiles) {
      if (p.isPersonal) return p;
    }
    return bootstrap.activeProfile.isPersonal ? bootstrap.activeProfile : null;
  }

  void _warmCachesFor(ActableProfile profile) {
    if (profile.isStore) {
      final id = profile.accountId.trim();
      if (id.isNotEmpty) {
        StoreProductsPrefetcher.instance.prefetch(
          id,
          coverImageUrl: profile.effectiveAvatarUrl,
        );
      }
    }
    WishlistPrefetcher.instance.prefetch();
    // Home cursors are versioned / profile-scoped — clear before re-warm.
    StoreHomePrefetcher.instance.invalidate();
    unawaited(
      StoreHomeCache.instance.clearAll().then((_) {
        StoreHomePrefetcher.instance.prefetch();
      }),
    );
  }

  bool _isAccessRemoved(Object e) {
    return e is CatalogApiException && e.code == 'PROFILE_ACCESS_REMOVED';
  }
}
