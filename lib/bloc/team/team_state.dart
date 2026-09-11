part of 'team_bloc.dart';

class TeamMember extends Equatable {
  const TeamMember({
    required this.id,
    required this.name,
    required this.handle,
    required this.avatarColor,
    this.phone = '',
  });

  final String id;
  final String name;
  /// Secondary label (typically formatted phone).
  final String handle;
  final String phone;
  final int avatarColor;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 &&
        parts.first.isNotEmpty &&
        parts.last.isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, trimmed.length.clamp(0, 2)).toUpperCase();
  }

  @override
  List<Object?> get props => [id, name, handle, phone, avatarColor];
}

class TeamState extends Equatable {
  const TeamState({
    this.query = '',
    this.allContacts = const [],
    this.searchResults = const [],
    this.addedIds = const {},
    this.isLoadingContacts = false,
    this.permissionDenied = false,
    this.isSubmitting = false,
    this.isCompleted = false,
    this.errorMessage,
  });

  final String query;
  final List<TeamMember> allContacts;
  final List<TeamMember> searchResults;
  final Set<String> addedIds;
  final bool isLoadingContacts;
  final bool permissionDenied;
  final bool isSubmitting;
  final bool isCompleted;
  final String? errorMessage;

  List<TeamMember> get addedMembers =>
      allContacts.where((m) => addedIds.contains(m.id)).toList();

  int get addedCount => addedIds.length;

  TeamState copyWith({
    String? query,
    List<TeamMember>? allContacts,
    List<TeamMember>? searchResults,
    Set<String>? addedIds,
    bool? isLoadingContacts,
    bool? permissionDenied,
    bool? isSubmitting,
    bool? isCompleted,
    String? errorMessage,
    bool clearCompleted = false,
    bool clearError = false,
  }) {
    return TeamState(
      query: query ?? this.query,
      allContacts: allContacts ?? this.allContacts,
      searchResults: searchResults ?? this.searchResults,
      addedIds: addedIds ?? this.addedIds,
      isLoadingContacts: isLoadingContacts ?? this.isLoadingContacts,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isCompleted: clearCompleted ? false : (isCompleted ?? this.isCompleted),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    query,
    allContacts,
    searchResults,
    addedIds,
    isLoadingContacts,
    permissionDenied,
    isSubmitting,
    isCompleted,
    errorMessage,
  ];
}
