part of 'contacts_bloc.dart';

sealed class ContactsEvent extends Equatable {
  const ContactsEvent();

  @override
  List<Object?> get props => [];
}

class ContactsStarted extends ContactsEvent {
  const ContactsStarted();
}

class ContactsRefreshed extends ContactsEvent {
  const ContactsRefreshed();
}

class ContactsClearMessage extends ContactsEvent {
  const ContactsClearMessage();
}
