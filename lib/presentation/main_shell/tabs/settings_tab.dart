import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/account_profile/account_profile_bloc.dart';
import 'package:project_c/bloc/auth/auth_bloc.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/floating_bottom_nav_bar.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/product_view_mode.dart';
import 'package:project_c/models/store_privacy_mode.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/services/product_view_preferences.dart';
import 'package:project_c/services/screenshot_protection_service.dart';
import 'package:project_c/services/store_privacy_preferences.dart';
import 'package:project_c/services/theme_preferences.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({
    super.key,
    this.showBack = false,
  });

  /// When true (pushed from My store), show back + Account privacy.
  /// Import requests live on My store (not here).
  final bool showBack;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            'Delete account?',
            style: AppTextStyles.title(fontSize: 18),
          ),
          content: Text(
            'This permanently deletes your catalog account. You will need to sign in again to continue.',
            style: AppTextStyles.bodySecondary(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Cancel', style: AppTextStyles.body()),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Delete',
                style: AppTextStyles.body(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (!context.mounted || confirmed != true) return;
    context.read<AccountProfileBloc>().add(
      const AccountProfileDeleteRequested(),
    );
  }

  Future<void> _logout(BuildContext context) async {
    context.read<AuthBloc>().add(const AuthLoggedOut());
    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.authPhoneRoute,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad =
        showBack
            ? 24 + MediaQuery.paddingOf(context).bottom
            : FloatingBottomNavBar.reservedHeight(context) + 8;
    final protection = ServiceLocator.get<ScreenshotProtectionService>();
    final viewPrefs = ServiceLocator.get<ProductViewPreferences>();
    final themePrefs = ServiceLocator.get<ThemePreferences>();
    return BlocBuilder<AccountProfileBloc, AccountProfileState>(
      builder: (context, state) {
        final profile = state.profile;
        final ownStore = profile?.ownStore;

        return ListView(
          padding: AppPadding.screen(
            top:
                showBack
                    ? ScreenWrapper.statusBarTop(context) + 4
                    : ScreenWrapper.statusBarTop(context) + 8,
            bottom: bottomPad,
          ),
          children: [
            if (showBack) ...[
              Row(
                children: [
                  AppBackButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Settings',
                      style: AppTextStyles.headline(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ] else
              Text(
                'Settings',
                style: AppTextStyles.headline(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 16),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  label: 'Name',
                  value: profile?.displayName ?? '—',
                ),
                _SettingsRow(
                  label: 'Mobile',
                  value: profile?.phone ?? '—',
                ),
                if (ownStore != null)
                  _SettingsRow(
                    label: 'Store',
                    value: ownStore.name,
                  ),
              ],
            ),
            if (showBack && ownStore != null) ...[
              const SizedBox(height: 16),
              _AccountPrivacyTile(
                onTap:
                    () => Navigator.of(
                      context,
                    ).pushNamed(Routes.accountPrivacyRoute),
              ),
              // Import requests moved to My store primary CTA (not shown here).
            ],
            const SizedBox(height: 16),
            Text(
              'View products',
              style: AppTextStyles.label(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: viewPrefs,
              builder: (context, _) {
                return _SettingsGroup(
                  children: [
                    for (final mode in ProductViewMode.values)
                      _SettingsRadioRow(
                        label: mode.label,
                        subtitle: mode.subtitle,
                        selected: viewPrefs.mode == mode,
                        onTap: () => viewPrefs.setMode(mode),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Appearance',
              style: AppTextStyles.label(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: themePrefs,
              builder: (context, _) {
                return _SettingsGroup(
                  children: [
                    for (final mode in AppAppearance.values)
                      _SettingsRadioRow(
                        label: mode.label,
                        subtitle: mode.subtitle,
                        selected: themePrefs.appearance == mode,
                        onTap: () => themePrefs.setAppearance(mode),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _SettingsGroup(
              children: [
                ListenableBuilder(
                  listenable: protection,
                  builder: (context, _) {
                    return _SettingsToggle(
                      label: 'Allow screenshots',
                      subtitle:
                          'Also controls screen recording. Off by default for privacy.',
                      value: protection.allowScreenshots,
                      onChanged: (value) {
                        protection.setAllowScreenshots(value);
                      },
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SettingsGroup(
              children: [
                _SettingsAction(
                  label: 'Log out',
                  color: AppColors.accent,
                  onTap: () => _logout(context),
                ),
                _SettingsAction(
                  label:
                      state.isDeletingAccount
                          ? 'Deleting…'
                          : 'Delete account',
                  color: AppColors.error,
                  onTap:
                      state.isDeletingAccount
                          ? null
                          : () => _confirmDelete(context),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _AccountPrivacyTile extends StatelessWidget {
  const _AccountPrivacyTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final prefs = ServiceLocator.get<StorePrivacyPreferences>();
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) {
        return Material(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      prefs.isPrivate
                          ? Icons.lock_outline_rounded
                          : Icons.public_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account privacy',
                          style: AppTextStyles.body(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          prefs.mode.label,
                          style: AppTextStyles.caption(),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: AppColors.border,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTextStyles.body()),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTextStyles.bodySecondary(),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRadioRow extends StatelessWidget {
  const _SettingsRadioRow({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.body()),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppColors.primary : AppColors.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  const _SettingsToggle({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.body()),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: value,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SettingsAction extends StatelessWidget {
  const _SettingsAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: AppTextStyles.body(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
