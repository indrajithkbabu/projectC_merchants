part of 'profile_context_bloc.dart';

abstract class ProfileContextEvent extends Equatable {
  const ProfileContextEvent();

  @override
  List<Object?> get props => const [];
}

class ProfileContextStarted extends ProfileContextEvent {
  const ProfileContextStarted();
}

class ProfileContextRefreshed extends ProfileContextEvent {
  const ProfileContextRefreshed({this.quiet = true});

  final bool quiet;

  @override
  List<Object?> get props => [quiet];
}

class ProfileContextSelectProfile extends ProfileContextEvent {
  const ProfileContextSelectProfile(this.profileId, {this.quiet = false});

  final String profileId;

  /// When true (e.g. Create store prep → Personal), skip the switch-moment overlay.
  final bool quiet;

  @override
  List<Object?> get props => [profileId, quiet];
}

class ProfileContextAcceptInvite extends ProfileContextEvent {
  const ProfileContextAcceptInvite(this.invitationId);

  final String invitationId;

  @override
  List<Object?> get props => [invitationId];
}

class ProfileContextDeclineInvite extends ProfileContextEvent {
  const ProfileContextDeclineInvite(this.invitationId);

  final String invitationId;

  @override
  List<Object?> get props => [invitationId];
}

/// Recover after PROFILE_ACCESS_REMOVED: clear stale work, reload, select Personal.
class ProfileContextAccessRemovedRecover extends ProfileContextEvent {
  const ProfileContextAccessRemovedRecover();
}

/// After create-store: PATCH select `store:<id>` and toast.
class ProfileContextSelectCreatedStore extends ProfileContextEvent {
  const ProfileContextSelectCreatedStore({
    required this.storeId,
    required this.storeName,
  });

  final String storeId;
  final String storeName;

  @override
  List<Object?> get props => [storeId, storeName];
}

class ProfileContextLeaveActiveStore extends ProfileContextEvent {
  const ProfileContextLeaveActiveStore();
}

class ProfileContextDeleteActiveStore extends ProfileContextEvent {
  const ProfileContextDeleteActiveStore();
}

class ProfileContextClearToast extends ProfileContextEvent {
  const ProfileContextClearToast();
}

class ProfileContextClearError extends ProfileContextEvent {
  const ProfileContextClearError();
}

class ProfileContextClearSwitchAnimation extends ProfileContextEvent {
  const ProfileContextClearSwitchAnimation();
}
