part of 'store_listing_bloc.dart';

class StoreListingState extends Equatable {
  const StoreListingState({
    this.query = '',
    this.allStores = const [],
    this.nextCursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isDeletingAccount = false,
    this.accountDeleted = false,
    this.errorMessage,
  });

  final String query;
  final List<StoreChannel> allStores;
  final String? nextCursor;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isDeletingAccount;
  final bool accountDeleted;
  final String? errorMessage;

  List<StoreChannel> get visibleStores {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return allStores;
    return allStores.where((store) {
      return store.name.toLowerCase().contains(q) ||
          store.handle.toLowerCase().contains(q) ||
          store.storeLink.toLowerCase().contains(q);
    }).toList();
  }

  StoreListingState copyWith({
    String? query,
    List<StoreChannel>? allStores,
    String? nextCursor,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isDeletingAccount,
    bool? accountDeleted,
    String? errorMessage,
    bool clearError = false,
    bool clearCursor = false,
    bool clearAccountDeleted = false,
  }) {
    return StoreListingState(
      query: query ?? this.query,
      allStores: allStores ?? this.allStores,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isDeletingAccount: isDeletingAccount ?? this.isDeletingAccount,
      accountDeleted:
          clearAccountDeleted
              ? false
              : (accountDeleted ?? this.accountDeleted),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    query,
    allStores,
    nextCursor,
    isLoading,
    isLoadingMore,
    isDeletingAccount,
    accountDeleted,
    errorMessage,
  ];
}
