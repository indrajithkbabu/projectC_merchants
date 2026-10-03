part of 'contacts_bloc.dart';

/// Device contact eligible for WhatsApp invite.
class ContactInviteCandidate extends Equatable {
  const ContactInviteCandidate({
    required this.phone,
    required this.name,
  });

  final String phone;
  final String name;

  @override
  List<Object?> get props => [phone, name];
}

class ContactsState extends Equatable {
  const ContactsState({
    this.members = const [],
    this.teamMembers = const [],
    this.deviceContacts = const [],
    this.storeId,
    this.storeName,
    this.storeLink,
    this.hasOwnStore = false,
    this.permissionDenied = false,
    this.isRefreshing = false,
    this.invitingPhone,
    this.errorMessage,
  });

  /// Raw store members from API.
  final List<StoreMember> members;

  /// People on your store team (GET …/members, excluding self).
  final List<StoreMember> teamMembers;

  /// Device contacts not already on the team — WhatsApp invite.
  final List<ContactInviteCandidate> deviceContacts;

  final String? storeId;
  final String? storeName;
  final String? storeLink;
  final bool hasOwnStore;
  final bool permissionDenied;
  final bool isRefreshing;
  final String? invitingPhone;
  final String? errorMessage;

  /// Team + device only; “With stores” comes from [StoreListingBloc] /home.
  bool get isTeamAndDeviceEmpty =>
      teamMembers.isEmpty && deviceContacts.isEmpty;

  ContactsState copyWith({
    List<StoreMember>? members,
    List<StoreMember>? teamMembers,
    List<ContactInviteCandidate>? deviceContacts,
    String? storeId,
    String? storeName,
    String? storeLink,
    bool? hasOwnStore,
    bool? permissionDenied,
    bool? isRefreshing,
    String? invitingPhone,
    String? errorMessage,
    bool clearError = false,
    bool clearStore = false,
    bool clearInviting = false,
  }) {
    return ContactsState(
      members: members ?? this.members,
      teamMembers: teamMembers ?? this.teamMembers,
      deviceContacts: deviceContacts ?? this.deviceContacts,
      storeId: clearStore ? null : (storeId ?? this.storeId),
      storeName: clearStore ? null : (storeName ?? this.storeName),
      storeLink: clearStore ? null : (storeLink ?? this.storeLink),
      hasOwnStore: hasOwnStore ?? this.hasOwnStore,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      invitingPhone:
          clearInviting ? null : (invitingPhone ?? this.invitingPhone),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    members,
    teamMembers,
    deviceContacts,
    storeId,
    storeName,
    storeLink,
    hasOwnStore,
    permissionDenied,
    isRefreshing,
    invitingPhone,
    errorMessage,
  ];
}
