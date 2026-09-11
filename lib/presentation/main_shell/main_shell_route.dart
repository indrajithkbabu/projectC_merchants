import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/account_profile/account_profile_bloc.dart';
import 'package:project_c/bloc/auth/auth_bloc.dart';
import 'package:project_c/bloc/contacts/contacts_bloc.dart';
import 'package:project_c/bloc/store_listing/store_listing_bloc.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/floating_bottom_nav_bar.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/main_shell/tabs/contacts_tab.dart';
import 'package:project_c/presentation/main_shell/tabs/profile_tab.dart';
import 'package:project_c/presentation/main_shell/tabs/settings_tab.dart';
import 'package:project_c/presentation/store_listing/store_listing_route.dart';

/// Post-onboarding root: Telegram-style floating nav with Stores as home.
class MainShellRoute extends StatefulWidget {
  const MainShellRoute({super.key});

  @override
  State<MainShellRoute> createState() => _MainShellRouteState();
}

class _MainShellRouteState extends State<MainShellRoute> {
  int _index = 0;

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
      child: ScreenWrapper(
        backgroundColor: AppColors.background,
        statusBarIconBrightness: Brightness.dark,
        // Keep layout stable so the nav isn't pushed above the IME; we hide it instead.
        resizeToAvoidBottomInset: false,
        extendBodyBehindBottom: true,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: IndexedStack(
                index: _index,
                sizing: StackFit.expand,
                children: const [
                  StoreListingRoute(embeddedInShell: true),
                  ContactsTab(),
                  SettingsTab(),
                  ProfileTab(),
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
                        child: BlocBuilder<
                          AccountProfileBloc,
                          AccountProfileState
                        >(
                          buildWhen:
                              (prev, curr) =>
                                  prev.profile?.displayName !=
                                      curr.profile?.displayName ||
                                  prev.profile?.firstName !=
                                      curr.profile?.firstName,
                          builder: (context, state) {
                            final initials = _profileInitials(state);
                            return FloatingBottomNavBar(
                              currentIndex: _index,
                              onChanged: (value) {
                                if (value == _index) return;
                                setState(() => _index = value);
                                if (value == FloatingNavTab.contacts.index) {
                                  context.read<ContactsBloc>().add(
                                    const ContactsRefreshed(),
                                  );
                                } else if (value ==
                                    FloatingNavTab.stores.index) {
                                  context.read<StoreListingBloc>().add(
                                    const StoreListingRefreshed(),
                                  );
                                } else if (value ==
                                        FloatingNavTab.profile.index ||
                                    value == FloatingNavTab.settings.index) {
                                  context.read<AccountProfileBloc>().add(
                                    const AccountProfileRefreshed(),
                                  );
                                }
                              },
                              items: [
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
                                  avatar: CircleAvatar(
                                    radius: 11,
                                    backgroundColor:
                                        _index == FloatingNavTab.profile.index
                                            ? AppColors.primary
                                            : AppColors.surfaceSecondary,
                                    child: Text(
                                      initials,
                                      style: AppTextStyles.caption(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            _index ==
                                                    FloatingNavTab
                                                        .profile
                                                        .index
                                                ? AppColors.textOnPrimary
                                                : AppColors.navBarInactive,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
