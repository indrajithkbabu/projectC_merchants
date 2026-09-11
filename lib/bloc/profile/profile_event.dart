part of 'profile_bloc.dart';

sealed class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class ProfileFirstNameChanged extends ProfileEvent {
  const ProfileFirstNameChanged(this.value);

  final String value;

  @override
  List<Object?> get props => [value];
}

class ProfileLastNameChanged extends ProfileEvent {
  const ProfileLastNameChanged(this.value);

  final String value;

  @override
  List<Object?> get props => [value];
}

class ProfilePickImageRequested extends ProfileEvent {
  const ProfilePickImageRequested(this.source);

  final ImageSource source;

  @override
  List<Object?> get props => [source];
}

class ProfileRemoveImageRequested extends ProfileEvent {
  const ProfileRemoveImageRequested();
}

class ProfileContinuePressed extends ProfileEvent {
  const ProfileContinuePressed();
}

class ProfileClearMessage extends ProfileEvent {
  const ProfileClearMessage();
}

class ProfileClearCompleted extends ProfileEvent {
  const ProfileClearCompleted();
}
