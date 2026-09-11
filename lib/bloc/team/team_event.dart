part of 'team_bloc.dart';

sealed class TeamEvent extends Equatable {
  const TeamEvent();

  @override
  List<Object?> get props => [];
}

class TeamContactsLoadRequested extends TeamEvent {
  const TeamContactsLoadRequested();
}

class TeamSearchChanged extends TeamEvent {
  const TeamSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class TeamMemberToggled extends TeamEvent {
  const TeamMemberToggled(this.memberId);

  final String memberId;

  @override
  List<Object?> get props => [memberId];
}

class TeamContinuePressed extends TeamEvent {
  const TeamContinuePressed();
}

class TeamClearCompleted extends TeamEvent {
  const TeamClearCompleted();
}

class TeamClearMessage extends TeamEvent {
  const TeamClearMessage();
}
