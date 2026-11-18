part of 'chat_inbox_bloc.dart';

class ChatInboxState extends Equatable {
  const ChatInboxState({
    this.profileId = '',
    this.items = const [],
    this.nextCursor,
    this.capabilities,
    this.writesEnabled = false,
    this.unavailable = false,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.hasFetched = false,
    this.errorMessage,
  });

  final String profileId;
  final List<ChatRelationship> items;
  final String? nextCursor;
  final ChatCapabilities? capabilities;
  final bool writesEnabled;

  /// Capabilities or `CHAT_DISABLED` say chat is off.
  final bool unavailable;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool hasFetched;
  final String? errorMessage;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  int unreadCount({required bool storesOnly}) {
    if (unavailable) return 0;
    var sum = 0;
    for (final item in items) {
      if (storesOnly && item.otherSide?.isStore != true) continue;
      sum += item.unreadCount;
    }
    return sum;
  }

  ChatInboxState copyWith({
    String? profileId,
    List<ChatRelationship>? items,
    String? nextCursor,
    bool clearCursor = false,
    ChatCapabilities? capabilities,
    bool? writesEnabled,
    bool? unavailable,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? hasFetched,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChatInboxState(
      profileId: profileId ?? this.profileId,
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      capabilities: capabilities ?? this.capabilities,
      writesEnabled: writesEnabled ?? this.writesEnabled,
      unavailable: unavailable ?? this.unavailable,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasFetched: hasFetched ?? this.hasFetched,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    profileId,
    items,
    nextCursor,
    capabilities,
    writesEnabled,
    unavailable,
    isLoading,
    isRefreshing,
    isLoadingMore,
    hasFetched,
    errorMessage,
  ];
}
