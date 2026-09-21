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

class AccountProfilePickImageRequested extends AccountProfileEvent {
  const AccountProfilePickImageRequested(this.source);

  final ImageSource source;

  @override
  List<Object?> get props => [source];
}

class AccountProfileRemoveImageRequested extends AccountProfileEvent {
  const AccountProfileRemoveImageRequested();
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
