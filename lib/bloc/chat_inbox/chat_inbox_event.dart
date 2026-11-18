part of 'chat_inbox_bloc.dart';

sealed class ChatInboxEvent extends Equatable {
  const ChatInboxEvent();

  @override
  List<Object?> get props => [];
}

/// Load the inbox for [profileId]. The same id does not start a second load.
class ChatInboxProfileSelected extends ChatInboxEvent {
  const ChatInboxProfileSelected(this.profileId);

  /// `personal:<userId>`, `store:<storeId>`, or empty before bootstrap.
  final String profileId;

  @override
  List<Object?> get props => [profileId];
}

class ChatInboxRefreshed extends ChatInboxEvent {
  const ChatInboxRefreshed();
}
