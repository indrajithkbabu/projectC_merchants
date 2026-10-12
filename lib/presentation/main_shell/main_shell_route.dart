import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/account_profile/account_profile_bloc.dart';
import 'package:project_c/bloc/auth/auth_bloc.dart';
import 'package:project_c/bloc/contacts/contacts_bloc.dart';
import 'package:project_c/bloc/store_listing/store_listing_bloc.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/floating_bottom_nav_bar.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/main_shell/shell_nav.dart';
import 'package:project_c/presentation/main_shell/tabs/contacts_tab.dart';
import 'package:project_c/presentation/main_shell/tabs/my_store_tab.dart';
import 'package:project_c/presentation/main_shell/tabs/profile_tab.dart';
import 'package:project_c/presentation/main_shell/tabs/settings_tab.dart';
import 'package:project_c/presentation/main_shell/tabs/wishlist_tab.dart';
import 'package:project_c/presentation/store_listing/store_listing_route.dart';
import 'package:project_c/services/store_products_prefetcher.dart';
import 'package:project_c/services/wishlist_prefetcher.dart';

/// Post-onboarding root: Telegram-style floating nav with Stores as home.
///
/// No store yet: Stores · Contacts · Settings · Profile.
/// Own store: Stores · Contacts · Wishlist · My store (Settings under My store).
class MainShellRoute extends StatefulWidget {
  const MainShellRoute({super.key});

  @override
  State<MainShellRoute> createState() => _MainShellRouteState();
}

class _MainShellRouteState extends State<MainShellRoute> {
  /// Always 0..3 for the visible tab set (IndexedStack index).
  int _index = 0;
  int _wishlistRefreshSignal = 0;

  @override
  void initState() {
    super.initState();
    ShellNav.pending.addListener(_onShellNavRequest);
  }

  @override
  void dispose() {
    ShellNav.pending.removeListener(_onShellNavRequest);
    super.dispose();
  }

  static bool _hasOwnStore(AccountProfileState state) {
    final id = state.profile?.ownStore?.id.trim() ?? '';
    return id.isNotEmpty;
  }

  void _onShellNavRequest() {
    final tab = ShellNav.takePending();
    if (tab == null || !mounted) return;
    final hasStore = _hasOwnStore(context.read<AccountProfileBloc>().state);
    final index = switch (tab) {
      ShellNavTab.stores => 0,
      ShellNavTab.contacts => 1,
      ShellNavTab.settings => hasStore ? null : 2,
      ShellNavTab.profile => hasStore ? null : 3,
      ShellNavTab.wishlist => hasStore ? 2 : null,
      ShellNavTab.myStore => hasStore ? 3 : null,
    };
    if (index == null) return;
    _onTabChanged(context, index, hasStore: hasStore);
  }

  void _onTabChanged(BuildContext context, int value, {required bool hasStore}) {
    final sameTab = value == _index;
    // Re-selecting Wishlist still quiet-refreshes so new likes appear.
    if (sameTab && !(hasStore && value == 2)) return;
    setState(() {
      _index = value;
      if (hasStore && value == 2) {
        _wishlistRefreshSignal++;
      }
    });
    if (value == 1) {
      context.read<ContactsBloc>().add(const ContactsRefreshed());
    } else if (value == 0) {
      context.read<StoreListingBloc>().add(const StoreListingRefreshed());
    } else if (!hasStore && (value == 2 || value == 3)) {
      context.read<AccountProfileBloc>().add(const AccountProfileRefreshed());
    } else if (hasStore && value == 3) {
      // Quiet follow-request preview refresh — no grid wipe.
      final bloc = context.read<StoreProfileBloc>();
      bloc.add(const StoreProfileLoadFollowRequestPreviews());
    }
  }

  List<FloatingNavItem> _navItems({
    required bool hasStore,
    required String profileInitials,
    required String profileImageUrl,
    required String storeCoverUrl,
    required bool profileOrMyStoreSelected,
  }) {
    if (!hasStore) {
      return [
        const FloatingNavItem(
          tab: FloatingNavTab.stores,
          label: 'Stores',
          icon: Icons.storefront_outlined,
          activeIcon: Icons.storefront_rounded,
        ),
        const FloatingNavItem(
          tab: FloatingNavTab.contacts,
          label: 'Contacts',
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
        ),
        const FloatingNavItem(
          tab: FloatingNavTab.settings,
          label: 'Settings',
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings_rounded,
        ),
        FloatingNavItem(
          tab: FloatingNavTab.profile,
          label: 'Profile',
          icon: Icons.account_circle_outlined,
          avatar: _NavProfileAvatar(
            key: const ValueKey('shell-nav-profile-avatar'),
            initials: profileInitials,
            imageUrl: profileImageUrl,
            selected: profileOrMyStoreSelected,
          ),
        ),
      ];
    }

    return [
      const FloatingNavItem(
        tab: FloatingNavTab.stores,
        label: 'Stores',
        icon: Icons.storefront_outlined,
        activeIcon: Icons.storefront_rounded,
      ),
      const FloatingNavItem(
        tab: FloatingNavTab.contacts,
        label: 'Contacts',
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
      ),
      const FloatingNavItem(
        tab: FloatingNavTab.wishlist,
        label: 'Wishlist',
        icon: Icons.favorite_border_rounded,
        activeIcon: Icons.favorite_rounded,
      ),
      FloatingNavItem(
        tab: FloatingNavTab.myStore,
        label: 'My store',
        icon: Icons.store_mall_directory_outlined,
        activeIcon: Icons.store_mall_directory_rounded,
        avatar:
            storeCoverUrl.isEmpty
                ? null
                : _NavProfileAvatar(
                  key: const ValueKey('shell-nav-my-store-avatar'),
                  initials: 'S',
                  imageUrl: storeCoverUrl,
                  selected: profileOrMyStoreSelected,
                ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AccountProfileBloc, AccountProfileState>(
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
            context.read<AccountProfileBloc>().add(
              const AccountProfileClearMessage(),
            );
          },
        ),
        BlocListener<AccountProfileBloc, AccountProfileState>(
          listenWhen:
              (prev, curr) => curr.accountDeleted && !prev.accountDeleted,
          listener: (context, state) {
            context.read<AccountProfileBloc>().add(
              const AccountProfileClearAccountDeleted(),
            );
            context.read<AuthBloc>().add(const AuthLoggedOut());
            Navigator.of(context).pushNamedAndRemoveUntil(
              Routes.authPhoneRoute,
              (route) => false,
            );
          },
        ),
      ],
      child: BlocBuilder<AccountProfileBloc, AccountProfileState>(
        buildWhen:
            (prev, curr) =>
                prev.profile?.ownStore?.id != curr.profile?.ownStore?.id ||
                prev.profile?.displayName != curr.profile?.displayName ||
                prev.profile?.firstName != curr.profile?.firstName ||
                prev.profile?.effectiveProfileImageUrl !=
                    curr.profile?.effectiveProfileImageUrl ||
                prev.profile?.ownStore?.coverImageUrl !=
                    curr.profile?.ownStore?.coverImageUrl ||
                prev.profile?.ownStore?.name != curr.profile?.ownStore?.name,
        builder: (context, profileState) {
          final hasStore = _hasOwnStore(profileState);
          final ownStore = profileState.profile?.ownStore;
          final storeId = ownStore?.id.trim() ?? '';
          final storeName = ownStore?.name.trim() ?? 'My store';
          final storeLink = ownStore?.storeLink.trim() ?? '';
          final storeCover = ownStore?.coverImageUrl.trim() ?? '';
          final initials = _profileInitials(profileState);
          final imageUrl =
              profileState.profile?.effectiveProfileImageUrl.trim() ?? '';

          // Clamp index if tab set changed (e.g. store created mid-session).
          final safeIndex = _index.clamp(0, 3);

          Widget body = ScreenWrapper(
            backgroundColor: AppColors.background,
            resizeToAvoidBottomInset: false,
            extendBodyBehindBottom: true,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: IndexedStack(
                    index: safeIndex,
                    sizing: StackFit.expand,
                    children: [
                      StoreListingRoute(
                        embeddedInShell: true,
                        onProfileAvatarTap: () {
                          setState(() => _index = 3);
                        },
                      ),
                      const ContactsTab(),
                      if (hasStore)
                        WishlistTab(refreshSignal: _wishlistRefreshSignal)
                      else
                        const SettingsTab(),
                      if (hasStore) const MyStoreTab() else const ProfileTab(),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Builder(
                    builder: (context) {
                      final keyboardOpen =
                          FloatingBottomNavBar.isKeyboardVisible(context);
                      return AnimatedSlide(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        offset:
                            keyboardOpen
                                ? const Offset(0, 1.15)
                                : Offset.zero,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          opacity: keyboardOpen ? 0 : 1,
                          child: IgnorePointer(
                            ignoring: keyboardOpen,
                            child: FloatingBottomNavBar(
                              currentIndex: safeIndex,
                              onChanged:
                                  (value) => _onTabChanged(
                                    context,
                                    value,
                                    hasStore: hasStore,
                                  ),
                              items: _navItems(
                                hasStore: hasStore,
                                profileInitials: initials,
                                profileImageUrl: imageUrl,
                                storeCoverUrl: storeCover,
                                profileOrMyStoreSelected: safeIndex == 3,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );

          if (!hasStore || storeId.isEmpty) return body;

          return BlocProvider(
            key: ValueKey('shell-own-store:$storeId'),
            create: (_) {
              StoreProductsPrefetcher.instance.prefetch(
                storeId,
                coverImageUrl: storeCover,
              );
              // Ensure wishlist is warm even if auth raced ahead of store create.
              WishlistPrefetcher.instance.prefetch();
              return StoreProfileBloc(
                storeName: storeName.isEmpty ? 'My store' : storeName,
                members: const [],
                isOwnStore: true,
                storeId: storeId,
                storeLink: storeLink.isEmpty ? null : storeLink,
                coverImageUrl: storeCover.isEmpty ? null : storeCover,
              );
            },
            child: body,
          );
        },
      ),
    );
  }

  String _profileInitials(AccountProfileState state) {
    final profile = state.profile;
    final first = profile?.firstName?.trim() ?? '';
    final last = profile?.lastName?.trim() ?? '';
    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    if (first.isNotEmpty) {
      return first.substring(0, first.length.clamp(0, 2)).toUpperCase();
    }
    return 'Me';
  }
}

/// Compact Profile / My-store nav avatar: photo when uploaded, otherwise initials.
///
/// Stateful so disk probe / decode can finish without flashing initials→photo
/// on cold reopen (common when shell mounts before ImageCache is ready).
class _NavProfileAvatar extends StatefulWidget {
  const _NavProfileAvatar({
    super.key,
    required this.initials,
    required this.imageUrl,
    required this.selected,
  });

  final String initials;
  final String imageUrl;
  final bool selected;

  @override
  State<_NavProfileAvatar> createState() => _NavProfileAvatarState();
}

class _NavProfileAvatarState extends State<_NavProfileAvatar> {
  /// Last URL we successfully warmed for paint.
  String _readyUrl = '';
  /// Keep showing the previous photo while a new URL warms (no initials flash).
  String _displayUrl = '';

  @override
  void initState() {
    super.initState();
    _prepare(widget.imageUrl);
  }

  @override
  void didUpdateWidget(covariant _NavProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _prepare(widget.imageUrl);
    }
  }

  Future<void> _prepare(String raw) async {
    final url = raw.trim();
    if (url.isEmpty) {
      if (!mounted) return;
      setState(() {
        _readyUrl = '';
        _displayUrl = '';
      });
      return;
    }
    if (CatalogImageCache.isDiskWarm(url)) {
      if (!mounted) return;
      setState(() {
        _readyUrl = url;
        _displayUrl = url;
      });
      // Keep memory decode fresh without blocking paint.
      // ignore: unawaited_futures
      CatalogImageCache.warmAvatars([url]);
      return;
    }
    await CatalogImageCache.warmAvatars([url]);
    if (!mounted || widget.imageUrl.trim() != url) return;
    setState(() {
      _readyUrl = url;
      _displayUrl = url;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg =
        widget.selected ? AppColors.primary : AppColors.surfaceSecondary;
    final label = Text(
      widget.initials,
      style: AppTextStyles.caption(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color:
            widget.selected
                ? AppColors.textOnPrimary
                : AppColors.navBarInactive,
      ),
    );

    final target = widget.imageUrl.trim();
    // Prefer ready target; else keep last photo; never flash initials over a URL.
    final paintUrl =
        (_readyUrl == target && target.isNotEmpty)
            ? target
            : (_displayUrl.isNotEmpty ? _displayUrl : '');

    if (paintUrl.isNotEmpty) {
      return CatalogNetworkAvatar(
        // Stable identity across selected/unselected rebuilds.
        key: ValueKey('nav-avatar:$paintUrl'),
        url: paintUrl,
        size: 22,
        backgroundColor: bg,
        // No initials fallback — avoids initials→photo flicker on reopen.
      );
    }

    if (target.isNotEmpty) {
      // URL known but still warming — solid circle, not initials.
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      );
    }

    return CircleAvatar(radius: 11, backgroundColor: bg, child: label);
  }
}
