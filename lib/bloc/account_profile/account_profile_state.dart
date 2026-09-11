part of 'account_profile_bloc.dart';

class AccountProfileState extends Equatable {
  const AccountProfileState({
    this.profile,
    this.isRefreshing = false,
    this.isDeletingAccount = false,
    this.accountDeleted = false,
    this.errorMessage,
  });

  final CatalogProfile? profile;
  final bool isRefreshing;
  final bool isDeletingAccount;
  final bool accountDeleted;
  final String? errorMessage;

  AccountProfileState copyWith({
    CatalogProfile? profile,
    bool? isRefreshing,
    bool? isDeletingAccount,
    bool? accountDeleted,
    String? errorMessage,
    bool clearError = false,
    bool clearAccountDeleted = false,
  }) {
    return AccountProfileState(
      profile: profile ?? this.profile,
      isRefreshing: isRefreshing ?? this.isRefreshing,
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
    isDeletingAccount,
    accountDeleted,
    errorMessage,
  ];
}
