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
import 'package:project_c/presentation/onboarding/onboarding_widgets/jewel_flow_logo.dart';
import 'package:project_c/presentation/store_listing/store_listing_widgets/store_listing_tile.dart';

/// Stores list (GET /home). When [embeddedInShell] is true, omits its own
/// [ScreenWrapper] so [MainShellRoute] can host the floating nav.
class StoreListingRoute extends StatefulWidget {
  const StoreListingRoute({super.key, this.embeddedInShell = false});

  final bool embeddedInShell;

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
                          const JewelFlowLogo(size: 32),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Stores',
                              style: AppTextStyles.headline(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Search stores and import catalogues',
                        style: AppTextStyles.caption(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onTapOutside: (_) => _dismissKeyboard(),
                        onSubmitted: (_) => _dismissKeyboard(),
                        onChanged:
                            (value) => context.read<StoreListingBloc>().add(
                              StoreListingSearchChanged(value),
                            ),
                        style: AppTextStyles.body(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Search stores',
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
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
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
                            ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: AppPadding.screen(
                                top: 8,
                                bottom: bottomPad,
                              ),
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.sizeOf(context).height * 0.22,
                                ),
                                Center(
                                  child: AnimatedOpacity(
                                    opacity: state.isLoading ? 0.45 : 1,
                                    duration: const Duration(milliseconds: 220),
                                    child: Text(
                                      state.isLoading
                                          ? 'Loading stores…'
                                          : 'No stores found',
                                      style: AppTextStyles.bodySecondary(),
                                    ),
                                  ),
                                ),
                              ],
                            )
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
