part of 'account_profile_bloc.dart';

class AccountProfileState extends Equatable {
  const AccountProfileState({
    this.profile,
    this.isRefreshing = false,
    this.isUpdatingImage = false,
    this.isDeletingAccount = false,
    this.accountDeleted = false,
    this.errorMessage,
  });

  final CatalogProfile? profile;
  final bool isRefreshing;
  final bool isUpdatingImage;
  final bool isDeletingAccount;
  final bool accountDeleted;
  final String? errorMessage;

  bool get hasProfileImage {
    final url = profile?.effectiveProfileImageUrl ?? '';
    return url.isNotEmpty;
  }

  AccountProfileState copyWith({
    CatalogProfile? profile,
    bool? isRefreshing,
    bool? isUpdatingImage,
    bool? isDeletingAccount,
    bool? accountDeleted,
    String? errorMessage,
    bool clearError = false,
    bool clearAccountDeleted = false,
  }) {
    return AccountProfileState(
      profile: profile ?? this.profile,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isUpdatingImage: isUpdatingImage ?? this.isUpdatingImage,
      isDeletingAccount: isDeletingAccount ?? this.isDeletingAccount,
      accountDeleted:
          clearAccountDeleted
              ? false
              : (accountDeleted ?? this.accountDeleted),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    profile,
    isRefreshing,
    isUpdatingImage,
    isDeletingAccount,
    accountDeleted,
    errorMessage,
  ];
}
