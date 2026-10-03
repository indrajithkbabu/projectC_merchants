import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/store_listing/store_listing_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/floating_bottom_nav_bar.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/store_channel.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/services/store_products_prefetcher.dart';
import 'package:project_c/presentation/store_listing/store_listing_widgets/store_listing_shimmer.dart';
import 'package:project_c/presentation/store_listing/store_listing_widgets/store_listing_tile.dart';

/// Stores list (GET /home). When [embeddedInShell] is true, omits its own
/// [ScreenWrapper] so [MainShellRoute] can host the floating nav.
class StoreListingRoute extends StatefulWidget {
  const StoreListingRoute({
    super.key,
    this.embeddedInShell = false,
    this.onProfileAvatarTap,
  });

  final bool embeddedInShell;

  /// Optional: open Profile tab from the header avatar (shell only).
  final VoidCallback? onProfileAvatarTap;

  @override
  State<StoreListingRoute> createState() => _StoreListingRouteState();
}

class _StoreListingRouteState extends State<StoreListingRoute> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
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
    // Warm products + collage images during the route transition.
    StoreProductsPrefetcher.instance.prefetch(
      store.id,
      coverImageUrl: store.coverImageUrl,
    );
    Navigator.of(context).pushNamed(
      Routes.storeProfileRoute,
      arguments: <String, Object?>{
        'store': store,
        'members': const [],
      },
    ).then((_) {
      if (!mounted) return;
      context.read<StoreListingBloc>().add(const StoreListingRefreshed());
    });
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
                  padding: AppPadding.screen(
                    top: ScreenWrapper.statusBarTop(context) + 8,
                    bottom: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Stores',
                              style: AppTextStyles.headline(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Theme(
                            data: Theme.of(context).copyWith(
                              splashFactory: NoSplash.splashFactory,
                              highlightColor: Colors.transparent,
                              splashColor: Colors.transparent,
                            ),
                            child: PopupMenuButton<_StoresOverflowAction>(
                              tooltip: 'More',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 40,
                              ),
                              offset: const Offset(0, 36),
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              surfaceTintColor: Colors.transparent,
                              color: AppColors.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: AppColors.border),
                              ),
                              // `child` (not `icon`) avoids IconButton’s 48dp
                              // inset so the ⋮ aligns with screen padding like
                              // the title.
                              child: const SizedBox(
                                width: 24,
                                height: 40,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Icon(
                                    Icons.more_vert_rounded,
                                    size: 24,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              onSelected: (action) {
                                if (action ==
                                    _StoresOverflowAction.createGroup) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('coming soon'),
                                    ),
                                  );
                                }
                              },
                              itemBuilder:
                                  (menuContext) => [
                                    PopupMenuItem(
                                      value: _StoresOverflowAction.createGroup,
                                      child: Text(
                                        'Create group',
                                        style: AppTextStyles.body(),
                                      ),
                                    ),
                                  ],
                            ),
                          ),
                        ],
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
                            Navigator.of(context).pushNamed(
                              Routes.globalSearchRoute,
                            );
                          },
                          style: AppTextStyles.body(fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Search products, tags or stores',
                            hintStyle: AppTextStyles.hint(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                            prefixIcon: const Icon(
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
                              borderSide: const BorderSide(
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
                const Divider(height: 1, color: AppColors.border),
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
                                          0.22,
                                    ),
                                    Center(
                                      child: Text(
                                        'No stores found',
                                        style: AppTextStyles.bodySecondary(),
                                      ),
                                    ),
                                  ],
                                ))
                            : ListView.separated(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: AppPadding.screen(
                                top: 8,
                                bottom: bottomPad,
                              ),
                              itemCount: stores.length,
                              separatorBuilder:
                                  (_, __) => const Divider(
                                    height: 1,
                                    indent: 68,
                                    color: AppColors.border,
                                  ),
                              itemBuilder: (context, index) {
                                final store = stores[index];
                                return StoreListingTile(
                                  store: store,
                                  onTap: () => _openStore(store),
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

    return ScreenWrapper(
      backgroundColor: AppColors.background,
      statusBarIconBrightness: Brightness.dark,
      child: body,
    );
  }
}

enum _StoresOverflowAction { createGroup }
