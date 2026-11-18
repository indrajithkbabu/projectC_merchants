import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/account_profile/account_profile_bloc.dart';
import 'package:project_c/bloc/store_listing/store_listing_bloc.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/store_warm_qa.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/floating_bottom_nav_bar.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/helper/widgets/shell_tab_title_bar.dart';
import 'package:project_c/models/store_channel.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/services/store_products_prefetcher.dart';
import 'package:project_c/storage/store_products_cache.dart';
import 'package:project_c/presentation/store_listing/store_listing_widgets/store_listing_empty.dart';
import 'package:project_c/presentation/store_listing/store_listing_widgets/store_listing_shimmer.dart';
import 'package:project_c/presentation/store_listing/store_listing_widgets/store_listing_tile.dart';
import 'package:project_c/webservice/notification/activity_repository.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Stores list (GET /home). When [embeddedInShell] is true, omits its own
/// [ScreenWrapper] so [MainShellRoute] can host the floating nav.
class StoreListingRoute extends StatefulWidget {
  const StoreListingRoute({
    super.key,
    this.embeddedInShell = false,
    this.onProfileAvatarTap,
  });

  final bool embeddedInShell;

  /// Optional: open Profile (no store) or My store (own store) from the header
  /// avatar (shell only).
  final VoidCallback? onProfileAvatarTap;

  @override
  State<StoreListingRoute> createState() => _StoreListingRouteState();
}

class _StoreListingRouteState extends State<StoreListingRoute> {
  static const _tag = 'StoreListing';

  late final TextEditingController _searchController;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshActivityUnread();
    });
  }

  @override
  void dispose() {
    StoreProductsPrefetcher.instance.pauseListingViewportPrefetch();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _dismissKeyboard();
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 240) return;
    context.read<StoreListingBloc>().add(const StoreListingLoadMore());
  }

  void _openStore(StoreChannel store) {
    _dismissKeyboard();
    // Push first — never run prefetch/disk/image work on the tap stack before
    // Navigator (Batch 1). Prefetch schedules after push returns.
    final session = StoreWarmQa.beginOpenSession(store.id);
    final memHit = StoreProductsCache.instance.readMemory(store.id) != null;
    final preEnriched = StoreProductsPrefetcher.instance.isFresh(store.id);
    StoreWarmQa.event('LISTING_TAP', {
      'session': session,
      'store': store.id,
      'pre_enriched': preEnriched,
      'mem_hit': memHit,
    });
    StoreWarmQa.step(
      'LISTING_TAP',
      detail: 'store=${store.id} name=${store.name} push=store_profile_route',
    );
    StoreWarmQa.event('PROFILE_NAVIGATION_START', {
      'session': session,
      'store': store.id,
    });
    // Stop starting new Home enrich work while Profile is open; in-flight
    // ensure for this tap still joins via [prefetch] / _inFlight dedupe.
    StoreProductsPrefetcher.instance.pauseListingViewportPrefetch();
    Navigator.of(context)
        .pushNamed(
          Routes.storeProfileRoute,
          arguments: <String, Object?>{'store': store, 'members': []},
        )
        .whenComplete(() {
          if (!mounted) return;
          StoreProductsPrefetcher.instance.resumeListingViewportPrefetch();
        });
    StoreProductsPrefetcher.instance.prefetch(
      store.id,
      coverImageUrl: store.coverImageUrl,
    );
  }

  Future<void> _pullToRefresh() async {
    final bloc = context.read<StoreListingBloc>();
    if (bloc.state.isLoading && bloc.state.allStores.isNotEmpty) {
      await bloc.stream.firstWhere((s) => !s.isLoading);
      return;
    }
    bloc.add(const StoreListingRefreshed());
    await bloc.stream.firstWhere((s) => s.isLoading);
    await bloc.stream.firstWhere((s) => !s.isLoading);
    // ignore: unawaited_futures
    _refreshActivityUnread();
  }

  Future<void> _refreshActivityUnread() async {
    final listing = context.read<StoreListingBloc>();
    final ownId =
        context.read<AccountProfileBloc>().state.profile?.ownStore?.id.trim() ??
        '';
    if (ownId.isEmpty) {
      listing.add(const StoreListingActivityUnreadCleared());
      return;
    }
    try {
      final count =
          await ServiceLocator.get<ActivityRepository>().fetchUnreadCount();
      if (!mounted) return;
      listing.add(StoreListingActivityUnreadUpdated(count));
    } catch (e) {
      AppLog.d(_tag, 'activity unread skipped | $e');
    }
  }

  void _openActivity() {
    _dismissKeyboard();
    final ownStore = context.read<AccountProfileBloc>().state.profile?.ownStore;
    final storeId = ownStore?.id.trim() ?? '';
    if (storeId.isEmpty) return;
    final storeName =
        ownStore!.name.trim().isEmpty ? 'My store' : ownStore.name.trim();

    var pendingCount = 0;
    var previewNames = const <String>[];
    try {
      final profileBloc = context.read<StoreProfileBloc>();
      pendingCount = profileBloc.state.pendingFollowRequestCount;
      previewNames = profileBloc.state.followRequestPreviewNames;
      profileBloc.add(const StoreProfileLoadFollowRequestPreviews());
    } catch (_) {
      // No own-store bloc yet (rare); Activity still opens with empty banner.
    }

    Navigator.of(context)
        .pushNamed(
          Routes.activityRoute,
          arguments: <String, Object?>{
            'storeId': storeId,
            'storeName': storeName,
            'pendingCount': pendingCount,
            'previewNames': previewNames,
          },
        )
        .then((_) {
          if (!mounted) return;
          // Feed marks all read on open — clear badge via listing bloc.
          context.read<StoreListingBloc>().add(
            const StoreListingActivityUnreadCleared(),
          );
          // ignore: unawaited_futures
          _refreshActivityUnread();
        });
  }

  @override
  Widget build(BuildContext context) {
    final body = MultiBlocListener(
      listeners: [
        BlocListener<StoreListingBloc, StoreListingState>(
          listenWhen:
              (prev, curr) =>
                  curr.errorMessage != null &&
                  curr.errorMessage != prev.errorMessage,
          listener: (context, state) {
            final message = state.errorMessage?.trim();
            if (message == null || message.isEmpty) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
            context.read<StoreListingBloc>().add(
              const StoreListingClearMessage(),
            );
          },
        ),
        BlocListener<AccountProfileBloc, AccountProfileState>(
          listenWhen:
              (prev, curr) =>
                  prev.profile?.ownStore?.id != curr.profile?.ownStore?.id,
          listener: (context, state) {
            // ignore: unawaited_futures
            _refreshActivityUnread();
          },
        ),
      ],
      child: BlocBuilder<StoreListingBloc, StoreListingState>(
        builder: (context, state) {
          final stores = state.visibleStores;
          final bottomPad =
              widget.embeddedInShell
                  ? FloatingBottomNavBar.reservedHeight(context) + 8
                  : 24.0;
          return GestureDetector(
            onTap: _dismissKeyboard,
            behavior: HitTestBehavior.translucent,
            child: Column(
              children: [
                Padding(
                  padding: ShellTabTitleBar.padding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShellTabTitleBar(
                        title: 'Stores',
                        trailing: BlocBuilder<
                          AccountProfileBloc,
                          AccountProfileState
                        >(
                          buildWhen:
                              (prev, curr) =>
                                  prev.profile?.ownStore?.id !=
                                  curr.profile?.ownStore?.id,
                          builder: (context, profileState) {
                            final hasStore =
                                (profileState.profile?.ownStore?.id.trim() ??
                                        '')
                                    .isNotEmpty;
                            if (!hasStore) return const SizedBox.shrink();
                            return BlocBuilder<
                              StoreListingBloc,
                              StoreListingState
                            >(
                              buildWhen:
                                  (prev, curr) =>
                                      prev.activityUnread !=
                                      curr.activityUnread,
                              builder: (context, listingState) {
                                return SizedBox(
                                  width: 40,
                                  height: ShellTabTitleBar.rowHeight,
                                  child: IconButton(
                                    tooltip: 'Activity',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 40,
                                      minHeight: ShellTabTitleBar.rowHeight,
                                    ),
                                    onPressed: _openActivity,
                                    icon: Badge(
                                      isLabelVisible:
                                          listingState.activityUnread > 0,
                                      smallSize: 8,
                                      backgroundColor: AppColors.error,
                                      child: Icon(
                                        Icons.notifications_none_rounded,
                                        size: 24,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Material(
                        color: Colors.transparent,
                        child: TextField(
                          controller: _searchController,
                          readOnly: true,
                          showCursor: false,
                          onTap: () {
                            _dismissKeyboard();
                            Navigator.of(
                              context,
                            ).pushNamed(Routes.globalSearchRoute);
                          },
                          style: AppTextStyles.body(fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Search products, tags or stores',
                            hintStyle: AppTextStyles.hint(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: AppColors.textSecondary,
                            ),
                            filled: true,
                            fillColor: AppColors.surfaceSecondary,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(32),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(32),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(32),
                              borderSide: BorderSide(
                                color: AppColors.primary,
                                width: 1.2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _pullToRefresh,
                    child:
                        stores.isEmpty
                            ? (state.isLoading
                                ? StoreListingShimmer(
                                  padding: AppPadding.screen(
                                    top: 8,
                                    bottom: bottomPad,
                                  ),
                                )
                                : ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: AppPadding.screen(
                                    top: 8,
                                    bottom: bottomPad,
                                  ),
                                  children: [
                                    SizedBox(
                                      height:
                                          MediaQuery.sizeOf(context).height *
                                          0.18,
                                    ),
                                    const StoreListingEmpty(),
                                  ],
                                ))
                            : ListView.builder(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: AppPadding.screen(
                                top: 8,
                                bottom: bottomPad,
                              ),
                              itemCount: stores.length,
                              itemBuilder: (context, index) {
                                final store = stores[index];
                                return VisibilityDetector(
                                  key: Key('listing_vis_${store.id}'),
                                  onVisibilityChanged: (info) {
                                    StoreProductsPrefetcher.instance
                                        .noteListingVisibility(
                                      store.id,
                                      visibleFraction: info.visibleFraction,
                                    );
                                  },
                                  child: StoreListingTile(
                                    store: store,
                                    onTap: () => _openStore(store),
                                  ),
                                );
                              },
                            ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (widget.embeddedInShell) return body;

    return ScreenWrapper(backgroundColor: AppColors.background, child: body);
  }
}
