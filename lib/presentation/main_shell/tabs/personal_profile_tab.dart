import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/account_profile/account_profile_bloc.dart';
import 'package:project_c/bloc/profile_context/profile_context_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/profile_switching_log.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/floating_bottom_nav_bar.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/catalog/catalog_profile.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/main_shell/profile_sheets.dart';
import 'package:project_c/presentation/main_shell/shell_nav.dart';
import 'package:share_plus/share_plus.dart';

/// Instagram-like Personal profile tab (UI 1.1).
class PersonalProfileTab extends StatelessWidget {
  const PersonalProfileTab({super.key});

  String _initials(CatalogProfile? profile, String fallback) {
    final first = profile?.firstName?.trim() ?? '';
    final last = profile?.lastName?.trim() ?? '';
    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    if (first.isNotEmpty) {
      return first.substring(0, first.length.clamp(0, 2)).toUpperCase();
    }
    return fallback;
  }

  Future<void> _shareProfile(BuildContext context, String name) async {
    await Share.share('Check out $name on Catly');
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = FloatingBottomNavBar.reservedHeight(context) + 8;
    return BlocBuilder<ProfileContextBloc, ProfileContextState>(
      builder: (context, ctx) {
        return BlocBuilder<AccountProfileBloc, AccountProfileState>(
          builder: (context, account) {
            final profile = account.profile;
            final active = ctx.activeProfile;
            final name =
                active?.name.trim().isNotEmpty == true
                    ? active!.name.trim()
                    : (profile?.displayName.trim().isNotEmpty == true
                        ? profile!.displayName.trim()
                        : 'You');
            final initials = active?.displayInitials.isNotEmpty == true
                ? active!.displayInitials
                : _initials(profile, 'Me');
            final imageUrl =
                (active?.effectiveAvatarUrl.trim().isNotEmpty == true)
                    ? active!.effectiveAvatarUrl.trim()
                    : (profile?.effectiveProfileImageUrl.trim() ?? '');
            final showDot = ctx.hasOtherUnreadOrInvite;

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                context.read<ProfileContextBloc>().add(
                  const ProfileContextRefreshed(quiet: false),
                );
                context.read<AccountProfileBloc>().add(
                  const AccountProfileRefreshed(),
                );
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppPadding.screen(
                  top: ScreenWrapper.statusBarTop(context) + 8,
                  bottom: bottomPad,
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap:
                              () => showProfileSwitcherSheet(
                                context,
                                source: 'chevron',
                              ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: AppTextStyles.headline(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.textPrimary,
                                  size: 22,
                                ),
                                if (showDot) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.error,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Menu',
                        onPressed: () {
                          ProfileSwitchingLog.d(
                            'PS-11/12',
                            'Personal hamburger → Settings',
                          );
                          showProfileHamburgerSheet(context);
                        },
                        icon: Icon(
                          Icons.menu_rounded,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _ProfileAvatar(size: 86, initials: initials, imageUrl: imageUrl),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: AppTextStyles.headline(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            // Personal has no public handle/slug — show role only.
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSecondary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                active?.roleLabel.trim().isNotEmpty == true
                                    ? active!.roleLabel
                                    : 'Personal',
                                style: AppTextStyles.caption(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _GreyButton(
                          label: 'Edit profile',
                          onTap:
                              () => Navigator.of(
                                context,
                              ).pushNamed(Routes.profileSetupRoute),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _GreyButton(
                          label: 'Share profile',
                          onTap: () => _shareProfile(context, name),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Saved',
                    style: AppTextStyles.body(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => ShellNav.request(ShellNavTab.wishlist),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.favorite_border_rounded,
                            color: AppColors.textSecondary,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Wishlist preview',
                            style: AppTextStyles.bodySecondary(),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Open Wishlist tab',
                            style: AppTextStyles.caption(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.size,
    required this.initials,
    required this.imageUrl,
  });

  final double size;
  final String initials;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    if (url.isNotEmpty) {
      return CatalogNetworkAvatar(
        url: url,
        size: size,
        backgroundColor: AppColors.surfaceSecondary,
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.85),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppTextStyles.headline(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w700,
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}

class _GreyButton extends StatelessWidget {
  const _GreyButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Material(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.body(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
