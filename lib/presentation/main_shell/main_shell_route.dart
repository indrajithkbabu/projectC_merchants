import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/account_profile/account_profile_bloc.dart';
import 'package:project_c/bloc/auth/auth_bloc.dart';
import 'package:project_c/bloc/profile_context/profile_context_bloc.dart';
import 'package:project_c/bloc/store_listing/store_listing_bloc.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/profile_switching_log.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/floating_bottom_nav_bar.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/main/app.dart' show scaffoldMessengerKey;
import 'package:project_c/models/catalog/profile_context.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/main_shell/profile_sheets.dart';
import 'package:project_c/presentation/main_shell/shell_nav.dart';
import 'package:project_c/presentation/chat/chat_mock_store.dart';
import 'package:project_c/presentation/chat/chat_tab.dart';
import 'package:project_c/presentation/main_shell/tabs/my_store_tab.dart';
import 'package:project_c/presentation/main_shell/tabs/personal_profile_tab.dart';
import 'package:project_c/presentation/main_shell/tabs/wishlist_tab.dart';
import 'package:project_c/presentation/store_listing/store_listing_route.dart';
import 'package:project_c/services/store_products_prefetcher.dart';
import 'package:project_c/services/wishlist_prefetcher.dart';

/// Post-onboarding root: Stores · Message · Wishlist · Profile.
///
/// Profile tab is Personal-style when acting as Personal, otherwise the active
/// store's My-store UI. Settings lives under the Profile hamburger sheet.
class MainShellRoute extends StatefulWidget {
  const MainShellRoute({super.key});

  @override
  State<MainShellRoute> createState() => _MainShellRouteState();
}

class _MainShellRouteState extends State<MainShellRoute> {
  /// Always 0..3: Stores | Message | Wishlist | Profile.
  int _index = 0;
  int _wishlistRefreshSignal = 0;
  final GlobalKey<MyStoreTabState> _myStoreKey = GlobalKey<MyStoreTabState>();
  DateTime? _lastExitBackAt;
  int? _handledSwitchToken;
  String? _loggedProfileTabId;

  @override
  void initState() {
    super.initState();
    ShellNav.pending.addListener(_onShellNavRequest);
    ProfileSwitchingLog.d(
      'PS-10',
      'MainShell tabs=Stores|Message|Wishlist|Profile (no Settings tab)',
    );
  }

  @override
  void dispose() {
    ShellNav.pending.removeListener(_onShellNavRequest);
    super.dispose();
  }

  void _onShellNavRequest() {
    final tab = ShellNav.takePending();
    if (tab == null || !mounted) return;
    final index = switch (tab) {
      ShellNavTab.stores => 0,
      ShellNavTab.contacts => 1,
      ShellNavTab.chats => 1,
      ShellNavTab.wishlist => 2,
      ShellNavTab.cart => 2,
      ShellNavTab.profile => 3,
      ShellNavTab.myStore => 3,
      ShellNavTab.settings => null,
    };
    if (index == null) return;
    _onTabChanged(context, index);
  }

  void _onTabChanged(BuildContext context, int value) {
    final sameTab = value == _index;
    if (sameTab && value != 2) return;
    _lastExitBackAt = null;
    setState(() {
      _index = value;
      if (value == 2) {
        _wishlistRefreshSignal++;
      }
    });
    if (value == 0) {
      context.read<StoreListingBloc>().add(const StoreListingRefreshed());
    } else if (value == 3) {
      context.read<AccountProfileBloc>().add(const AccountProfileRefreshed());
      context.read<ProfileContextBloc>().add(
        const ProfileContextRefreshed(quiet: true),
      );
      final profileCtx = context.read<ProfileContextBloc>().state;
      final storeId = profileCtx.activeStoreId?.trim() ?? '';
      // Follow-request inbox is owner-only; staff must not hit that API.
      if (storeId.isNotEmpty && profileCtx.isOwner) {
        try {
          context.read<StoreProfileBloc>().add(
            const StoreProfileLoadFollowRequestPreviews(),
          );
        } catch (_) {
          // Store bloc may not exist while Personal is active.
        }
      }
    }
  }

  void _handleShellBack({required bool actingAsStore}) {
    if (actingAsStore &&
        (_myStoreKey.currentState?.consumeSystemBack() ?? false)) {
      return;
    }
    if (_index != 0) {
      ProfileSwitchingLog.d(
        'PS-83',
        'shell back from tab=$_index → Stores',
      );
      _onTabChanged(context, 0);
      return;
    }
    final now = DateTime.now();
    if (_lastExitBackAt != null &&
        now.difference(_lastExitBackAt!) < const Duration(seconds: 2)) {
      ProfileSwitchingLog.d('PS-83', 'shell double-back → exit');
      SystemNavigator.pop();
      return;
    }
    _lastExitBackAt = now;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Press back again to exit'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  List<FloatingNavItem> _navItems({
    required ActableProfile? active,
    required bool profileSelected,
    required bool showProfileDot,
    required int chatUnread,
  }) {
    final initials = active?.displayInitials ?? 'Me';
    final imageUrl = active?.effectiveAvatarUrl.trim() ?? '';
    return [
      const FloatingNavItem(
        tab: FloatingNavTab.stores,
        label: 'Stores',
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
      ),
      FloatingNavItem(
        tab: FloatingNavTab.contacts,
        label: 'Message',
        icon: Icons.chat_bubble_outline_rounded,
        activeIcon: Icons.chat_bubble_rounded,
        badgeCount: chatUnread,
      ),
      const FloatingNavItem(
        tab: FloatingNavTab.wishlist,
        label: 'Wishlist',
        icon: Icons.favorite_border_rounded,
        activeIcon: Icons.favorite_rounded,
      ),
      FloatingNavItem(
        tab: FloatingNavTab.profile,
        label: 'Profile',
        icon: Icons.account_circle_outlined,
        showDot: showProfileDot,
        avatar: _NavProfileAvatar(
          key: const ValueKey('shell-nav-profile-avatar'),
          initials: initials,
          imageUrl: imageUrl,
          selected: profileSelected,
        ),
      ),
    ];
  }

  Widget _profileTab(ProfileContextState ctx) {
    final active = ctx.activeProfile;
    final activeId = active?.id ?? '(none)';
    if (_loggedProfileTabId != activeId) {
      _loggedProfileTabId = activeId;
      if (active != null && active.isStore) {
        final canManageStore =
            (ctx.permissions.manageStore || ctx.permissions.manageProducts) &&
            !active.isStaff;
        ProfileSwitchingLog.d(
          'PS-13/34/60/61',
          'Profile tab store=$activeId role=${active.role.name} '
          'badge=${active.isStaff ? "Staff" : (active.isOwner ? "Owner" : "?")} '
          'canManageStore=$canManageStore '
          'inviteDot=${ctx.hasOtherUnreadOrInvite}',
        );
      } else {
        ProfileSwitchingLog.d(
          'PS-11/13/24',
          'Profile tab Personal active=$activeId '
          'badge=Personal inviteDot=${ctx.hasOtherUnreadOrInvite}',
        );
      }
    }
    if (active != null && active.isStore) {
      final canManage =
          ctx.permissions.manageStore || ctx.permissions.manageProducts;
      return MyStoreTab(
        key: _myStoreKey,
        onOpenMenu: () => showProfileHamburgerSheet(context),
        onOpenSwitcher: () => showProfileSwitcherSheet(context),
        showSwitcherDot: ctx.hasOtherUnreadOrInvite,
        roleBadge: active.isStaff
            ? 'Staff'
            : (active.isOwner ? 'Owner' : null),
        canManageStore: canManage && !active.isStaff,
      );
    }
    return const PersonalProfileTab();
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
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(Routes.authPhoneRoute, (route) => false);
          },
        ),
        BlocListener<ProfileContextBloc, ProfileContextState>(
          listenWhen:
              (prev, curr) =>
                  curr.toastMessage != null &&
                  curr.toastMessage != prev.toastMessage,
          listener: (context, state) {
            final message = state.toastMessage?.trim();
            if (message == null || message.isEmpty) return;
            scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(content: Text(message)),
            );
            context.read<ProfileContextBloc>().add(
              const ProfileContextClearToast(),
            );
          },
        ),
        BlocListener<ProfileContextBloc, ProfileContextState>(
          listenWhen:
              (prev, curr) =>
                  curr.errorMessage != null &&
                  curr.errorMessage != prev.errorMessage,
          listener: (context, state) {
            final message = state.errorMessage?.trim();
            if (message == null || message.isEmpty) return;
            scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(content: Text(message)),
            );
            context.read<ProfileContextBloc>().add(
              const ProfileContextClearError(),
            );
          },
        ),
        BlocListener<ProfileContextBloc, ProfileContextState>(
          listenWhen:
              (prev, curr) =>
                  curr.switchAnimationToken != null &&
                  curr.switchAnimationToken != prev.switchAnimationToken,
          listener: (context, state) async {
            final token = state.switchAnimationToken;
            if (token == null || token == _handledSwitchToken) return;
            _handledSwitchToken = token;
            final target = state.switchTarget ?? state.activeProfile;
            if (target == null) {
              context.read<ProfileContextBloc>().add(
                const ProfileContextClearSwitchAnimation(),
              );
              return;
            }
            ProfileSwitchingLog.d(
              'PS-22/23',
              'switch moment ~500ms target=${target.id} '
              'name=${target.name} role=${target.role.name}',
            );
            // Fire-and-forget overlay; close after ~500ms (UI 2.2).
            // ignore: unawaited_futures
            showGeneralDialog<void>(
              context: context,
              barrierDismissible: false,
              barrierColor: Colors.black,
              transitionDuration: const Duration(milliseconds: 160),
              pageBuilder: (dialogContext, anim, secondary) {
                return _SwitchMomentOverlay(profile: target);
              },
            );
            await Future<void>.delayed(const Duration(milliseconds: 520));
            if (context.mounted) {
              Navigator.of(context, rootNavigator: true).maybePop();
              context.read<ProfileContextBloc>().add(
                const ProfileContextClearSwitchAnimation(),
              );
            }
          },
        ),
      ],
      child: BlocBuilder<ProfileContextBloc, ProfileContextState>(
        buildWhen:
            (prev, curr) =>
                prev.activeProfile?.id != curr.activeProfile?.id ||
                prev.activeProfile?.effectiveAvatarUrl !=
                    curr.activeProfile?.effectiveAvatarUrl ||
                prev.activeProfile?.name != curr.activeProfile?.name ||
                prev.hasOtherUnreadOrInvite != curr.hasOtherUnreadOrInvite ||
                prev.permissions != curr.permissions,
        builder: (context, ctx) {
          final active = ctx.activeProfile;
          final actingAsStore = active?.isStore == true;
          final storeId = ctx.activeStoreId?.trim() ?? '';
          final storeName = active?.name.trim() ?? 'My store';
          final storeCover = active?.effectiveAvatarUrl.trim() ?? '';
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
                      ChatTab(
                        activeProfileName: active?.name,
                        storesOnly: !actingAsStore,
                        storeId: storeId,
                      ),
                      WishlistTab(refreshSignal: _wishlistRefreshSignal),
                      _profileTab(ctx),
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
                            keyboardOpen ? const Offset(0, 1.15) : Offset.zero,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          opacity: keyboardOpen ? 0 : 1,
                          child: IgnorePointer(
                            ignoring: keyboardOpen,
                            child: ListenableBuilder(
                              listenable: ChatMockStore.instance,
                              builder: (context, _) {
                                return FloatingBottomNavBar(
                                  currentIndex: safeIndex,
                                  onChanged:
                                      (value) => _onTabChanged(context, value),
                                  onLongPress: (value) {
                                    if (value == 3) {
                                      showProfileSwitcherSheet(
                                        context,
                                        source: 'longPress',
                                      );
                                    }
                                  },
                                  items: _navItems(
                                    active: active,
                                    profileSelected: safeIndex == 3,
                                    showProfileDot: ctx.hasOtherUnreadOrInvite,
                                    chatUnread: ChatMockStore.instance
                                        .inbox(storesOnly: !actingAsStore)
                                        .fold<int>(
                                          0,
                                          (sum, thread) =>
                                              sum + thread.unreadCount,
                                        ),
                                  ),
                                );
                              },
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

          body = PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              _handleShellBack(actingAsStore: actingAsStore);
            },
            child: body,
          );

          if (!actingAsStore || storeId.isEmpty) return body;

          return BlocProvider(
            key: ValueKey('shell-active-store:$storeId'),
            create: (_) {
              StoreProductsPrefetcher.instance.prefetch(
                storeId,
                coverImageUrl: storeCover,
              );
              WishlistPrefetcher.instance.prefetch();
              // Always host as "own" shell profile; gate CTAs via permissions.
              return StoreProfileBloc(
                storeName: storeName.isEmpty ? 'My store' : storeName,
                members: const [],
                isOwnStore: true,
                storeId: storeId,
                storeLink: active?.slug,
                coverImageUrl: storeCover.isEmpty ? null : storeCover,
              );
            },
            child: body,
          );
        },
      ),
    );
  }
}

class _SwitchMomentOverlay extends StatelessWidget {
  const _SwitchMomentOverlay({required this.profile});

  final ActableProfile profile;

  @override
  Widget build(BuildContext context) {
    final url = profile.effectiveAvatarUrl.trim();
    return Material(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (url.isNotEmpty)
              CatalogNetworkAvatar(
                url: url,
                size: 88,
                backgroundColor: AppColors.surfaceSecondary,
              )
            else
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.primary.withValues(alpha: 0.85),
                child: Text(
                  profile.displayInitials,
                  style: AppTextStyles.headline(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnPrimary,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              profile.name,
              style: AppTextStyles.headline(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact Profile nav avatar: photo when uploaded, otherwise initials.
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
  String _readyUrl = '';
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
    final bg = widget.selected ? AppColors.primary : AppColors.surfaceSecondary;
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
    final paintUrl =
        (_readyUrl == target && target.isNotEmpty)
            ? target
            : (_displayUrl.isNotEmpty ? _displayUrl : '');

    if (paintUrl.isNotEmpty) {
      return CatalogNetworkAvatar(
        key: ValueKey('nav-avatar:$paintUrl'),
        url: paintUrl,
        size: 22,
        backgroundColor: bg,
      );
    }

    if (target.isNotEmpty) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      );
    }

    return CircleAvatar(radius: 11, backgroundColor: bg, child: label);
  }
}
