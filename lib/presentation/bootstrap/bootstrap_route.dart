import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/auth/auth_bloc.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/catalog_ui_mapper.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/device_contact_names.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/floating_bottom_nav_bar.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/helper/widgets/shell_tab_title_bar.dart';
import 'package:project_c/models/catalog/catalog_profile.dart';
import 'package:project_c/models/store_channel.dart';
import 'package:project_c/presentation/onboarding/onboarding_widgets/jewel_flow_logo.dart';
import 'package:project_c/presentation/store_listing/store_listing_widgets/store_listing_shimmer.dart';
import 'package:project_c/presentation/store_listing/store_listing_widgets/store_listing_tile.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/storage/session_storage.dart';
import 'package:project_c/storage/store_home_cache.dart';

/// Cold-start gate shown while [AuthBloc] restores the session.
///
/// Signed-in kill+reopen: real Stores chrome (title, bell, search, floating
/// nav) + cached home rows when available. Unsigned / first launch: logo after
/// a fast local-token probe.
class BootstrapRoute extends StatefulWidget {
  const BootstrapRoute({super.key});

  @override
  State<BootstrapRoute> createState() => _BootstrapRouteState();
}

class _BootstrapRouteState extends State<BootstrapRoute> {
  /// `null` = still probing secure storage; avoid logo flash for signed-in.
  bool? _hasLocalTokens;

  @override
  void initState() {
    super.initState();
    _probeLocalTokens();
  }

  Future<void> _probeLocalTokens() async {
    try {
      final session = ServiceLocator.get<CatalogSession>();
      if (session.isSignedIn) {
        if (mounted) setState(() => _hasLocalTokens = true);
        return;
      }
      final tokens = await ServiceLocator.get<SessionStorage>().readTokens();
      if (!mounted) return;
      setState(
        () => _hasLocalTokens = tokens?.accessToken.isNotEmpty == true,
      );
    } catch (_) {
      if (mounted) setState(() => _hasLocalTokens = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen:
          (prev, curr) =>
              prev.isRestoringSession != curr.isRestoringSession ||
              prev.isAuthenticated != curr.isAuthenticated ||
              prev.profile != curr.profile,
      builder: (context, state) {
        final showHomeChrome =
            state.isAuthenticated || _hasLocalTokens == true;
        final showLogo =
            !state.isAuthenticated && _hasLocalTokens == false;
        return ScreenWrapper(
          backgroundColor: AppColors.background,
          resizeToAvoidBottomInset: false,
          extendBodyBehindBottom: true,
          child:
              showHomeChrome
                  ? const _BootstrapHomePreview()
                  : showLogo
                  ? const Center(child: JewelFlowLogo(size: 92))
                  : const SizedBox.expand(),
        );
      },
    );
  }
}

/// Real home shell chrome + cached listing (interactions disabled until shell).
class _BootstrapHomePreview extends StatefulWidget {
  const _BootstrapHomePreview();

  @override
  State<_BootstrapHomePreview> createState() => _BootstrapHomePreviewState();
}

class _BootstrapHomePreviewState extends State<_BootstrapHomePreview> {
  /// Same palette as [StoreListingBloc] so cached tiles match the real list.
  static const _avatarPalette = <int>[
    0xFF2AABEE,
    0xFF8E44AD,
    0xFF2980B9,
    0xFF16A085,
    0xFFE67E22,
    0xFFE74C3C,
  ];

  /// `null` while reading disk; empty → list shimmer; non-empty → tiles.
  /// Seed sync from memory so reopen never flashes shimmer when cache is warm.
  List<StoreChannel>? _stores = _storesFromMemory();

  static List<StoreChannel>? _storesFromMemory() {
    final page = StoreHomeCache.instance.readMemory();
    if (page == null) return null;
    if (page.items.isEmpty) return const [];
    return [
      for (var i = 0; i < page.items.length; i++)
        CatalogUiMapper.storeToChannel(
          page.items[i],
          avatarColor: _avatarPalette[i % _avatarPalette.length],
        ).copyWith(
          contactName: _staticContactName(page.items[i].phone),
        ),
    ];
  }

  static String _staticContactName(String phone) {
    final cached = StoreHomeCache.instance.contactNameFor(phone)?.trim() ?? '';
    if (cached.isNotEmpty) return cached;
    if (!DeviceContactNames.isReady) return '';
    return DeviceContactNames.lookup(phone)?.trim() ?? '';
  }

  @override
  void initState() {
    super.initState();
    if (_stores == null) {
      _loadCachedListing();
    } else if (_stores!.isNotEmpty) {
      // ignore: unawaited_futures
      CatalogImageCache.warmAvatars([
        for (final s in _stores!) s.coverImageUrl,
      ]);
    }
  }

  Future<void> _loadCachedListing() async {
    try {
      final page =
          StoreHomeCache.instance.readMemory() ??
          await StoreHomeCache.instance.read();
      if (!mounted) return;
      if (page == null || page.items.isEmpty) {
        setState(() => _stores = const []);
        return;
      }

      final stores = <StoreChannel>[
        for (var i = 0; i < page.items.length; i++)
          CatalogUiMapper.storeToChannel(
            page.items[i],
            avatarColor: _avatarPalette[i % _avatarPalette.length],
          ).copyWith(
            contactName: _contactNameFor(page.items[i].phone),
          ),
      ];

      // ignore: unawaited_futures
      CatalogImageCache.warmAvatars([
        for (final s in stores) s.coverImageUrl,
      ]);

      if (!mounted) return;
      setState(() => _stores = stores);
    } catch (_) {
      if (mounted) setState(() => _stores = const []);
    }
  }

  String _contactNameFor(String phone) {
    final cached = StoreHomeCache.instance.contactNameFor(phone)?.trim() ?? '';
    if (cached.isNotEmpty) return cached;
    if (!DeviceContactNames.isReady) return '';
    return DeviceContactNames.lookup(phone)?.trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final session = ServiceLocator.get<CatalogSession>();
    final profile =
        context.select<AuthBloc, CatalogProfile?>((b) => b.state.profile) ??
        session.profile;
    final hasStore = (profile?.ownStore?.id.trim() ?? '').isNotEmpty;
    final bottomPad = FloatingBottomNavBar.reservedHeight(context) + 8;
    final stores = _stores;

    // Visual-only: real shell mounts next; avoid premature search/tab routes.
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: ShellTabTitleBar.padding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShellTabTitleBar(
                      title: 'Stores',
                      trailing:
                          hasStore
                              ? SizedBox(
                                width: 40,
                                height: ShellTabTitleBar.rowHeight,
                                child: IconButton(
                                  tooltip: 'Activity',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: ShellTabTitleBar.rowHeight,
                                  ),
                                  onPressed: () {},
                                  icon: Icon(
                                    Icons.notifications_none_rounded,
                                    size: 24,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              )
                              : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),
                    const _HomeSearchField(),
                  ],
                ),
              ),
              Expanded(
                child:
                    stores == null || stores.isEmpty
                        ? StoreListingShimmer(
                          padding: AppPadding.screen(
                            top: 8,
                            bottom: bottomPad,
                          ),
                        )
                        : ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          padding: AppPadding.screen(
                            top: 8,
                            bottom: bottomPad,
                          ),
                          itemCount: stores.length,
                          itemBuilder: (context, index) {
                            return StoreListingTile(
                              store: stores[index],
                              onTap: () {},
                            );
                          },
                        ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingBottomNavBar(
              currentIndex: 0,
              onChanged: (_) {},
              items: _navItems(hasStore: hasStore),
            ),
          ),
        ],
      ),
    );
  }

  List<FloatingNavItem> _navItems({required bool hasStore}) {
    if (!hasStore) {
      return const [
        FloatingNavItem(
          tab: FloatingNavTab.stores,
          label: 'Stores',
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
        ),
        FloatingNavItem(
          tab: FloatingNavTab.contacts,
          label: 'Contacts',
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
        ),
        FloatingNavItem(
          tab: FloatingNavTab.settings,
          label: 'Settings',
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings_rounded,
        ),
        FloatingNavItem(
          tab: FloatingNavTab.profile,
          label: 'Profile',
          icon: Icons.account_circle_outlined,
          activeIcon: Icons.account_circle_rounded,
        ),
      ];
    }
    return const [
      FloatingNavItem(
        tab: FloatingNavTab.stores,
        label: 'Stores',
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
      ),
      FloatingNavItem(
        tab: FloatingNavTab.contacts,
        label: 'Contacts',
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
      ),
      FloatingNavItem(
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
      ),
    ];
  }
}

/// Matches [StoreListingRoute] search field (read-only entry look).
class _HomeSearchField extends StatelessWidget {
  const _HomeSearchField();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: TextField(
        readOnly: true,
        showCursor: false,
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
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
