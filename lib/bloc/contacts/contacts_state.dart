part of 'contacts_bloc.dart';

class ContactsState extends Equatable {
  const ContactsState({
    this.members = const [],
    this.storeId,
    this.storeName,
    this.hasOwnStore = false,
    this.isRefreshing = false,
    this.errorMessage,
  });

  final List<StoreMember> members;
  final String? storeId;
  final String? storeName;
  final bool hasOwnStore;
  final bool isRefreshing;
  final String? errorMessage;

  ContactsState copyWith({
    List<StoreMember>? members,
    String? storeId,
    String? storeName,
    bool? hasOwnStore,
    bool? isRefreshing,
    String? errorMessage,
    bool clearError = false,
    bool clearStore = false,
  }) {
    return ContactsState(
      members: members ?? this.members,
      storeId: clearStore ? null : (storeId ?? this.storeId),
      storeName: clearStore ? null : (storeName ?? this.storeName),
      hasOwnStore: hasOwnStore ?? this.hasOwnStore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    members,
    storeId,
    storeName,
    hasOwnStore,
    isRefreshing,
    errorMessage,
  ];
}
