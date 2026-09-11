part of 'account_profile_bloc.dart';

sealed class AccountProfileEvent extends Equatable {
  const AccountProfileEvent();

  @override
  List<Object?> get props => [];
}

class AccountProfileStarted extends AccountProfileEvent {
  const AccountProfileStarted();
}

class AccountProfileRefreshed extends AccountProfileEvent {
  const AccountProfileRefreshed();
}

class AccountProfileDeleteRequested extends AccountProfileEvent {
  const AccountProfileDeleteRequested();
}

class AccountProfileClearMessage extends AccountProfileEvent {
  const AccountProfileClearMessage();
}

class AccountProfileClearAccountDeleted extends AccountProfileEvent {
  const AccountProfileClearAccountDeleted();
}
