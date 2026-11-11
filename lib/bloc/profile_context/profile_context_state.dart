part of 'profile_context_bloc.dart';

class ProfileContextState extends Equatable {
  const ProfileContextState({
    this.bootstrap,
    this.isLoading = false,
    this.isSwitching = false,
    this.switchAnimationToken,
    this.switchTarget,
    this.toastMessage,
    this.errorMessage,
  });

  final ProfileBootstrap? bootstrap;
  final bool isLoading;
  final bool isSwitching;

  /// Bumped when a switch moment should play; UI clears via event.
  final int? switchAnimationToken;
  final ActableProfile? switchTarget;
  final String? toastMessage;
  final String? errorMessage;

  ActableProfile? get activeProfile => bootstrap?.activeProfile;

  ProfilePermissions get permissions =>
      bootstrap?.permissions ?? ProfilePermissions.personalDefaults;

  bool get isPersonal => activeProfile?.isPersonal ?? true;

  bool get isStore => activeProfile?.isStore ?? false;

  bool get isOwner => activeProfile?.isOwner ?? false;

  bool get isStaff => activeProfile?.isStaff ?? false;

  String? get activeStoreId {
    final active = activeProfile;
    if (active == null || !active.isStore) return null;
    final id = active.accountId.trim();
    return id.isEmpty ? null : id;
  }

  /// Red-dot for pending store invitations only (chat unread is out of scope).
  bool get hasOtherUnreadOrInvite {
    final summary = bootstrap?.invitationSummary;
    if (summary?.hasPending == true || (summary?.pendingCount ?? 0) > 0) {
      return true;
    }
    return bootstrap?.pendingInvitations.isNotEmpty ?? false;
  }

  bool get canCreateStore {
    final b = bootstrap;
    if (b == null) return false;
    return b.storeCreation.canCreate &&
        (b.activeProfile.isPersonal
            ? (b.permissions.createStore || b.storeCreation.canCreate)
            : false);
  }

  ProfileContextState copyWith({
    ProfileBootstrap? bootstrap,
    bool? isLoading,
    bool? isSwitching,
    int? switchAnimationToken,
    ActableProfile? switchTarget,
    String? toastMessage,
    String? errorMessage,
    bool clearBootstrap = false,
    bool clearSwitchAnimation = false,
    bool clearToast = false,
    bool clearError = false,
  }) {
    return ProfileContextState(
      bootstrap: clearBootstrap ? null : (bootstrap ?? this.bootstrap),
      isLoading: isLoading ?? this.isLoading,
      isSwitching: isSwitching ?? this.isSwitching,
      switchAnimationToken:
          clearSwitchAnimation
              ? null
              : (switchAnimationToken ?? this.switchAnimationToken),
      switchTarget:
          clearSwitchAnimation ? null : (switchTarget ?? this.switchTarget),
      toastMessage: clearToast ? null : (toastMessage ?? this.toastMessage),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    bootstrap,
    isLoading,
    isSwitching,
    switchAnimationToken,
    switchTarget,
    toastMessage,
    errorMessage,
  ];
}
