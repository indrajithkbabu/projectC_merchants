import 'package:flutter/material.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/primary_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/store_privacy_mode.dart';
import 'package:project_c/services/store_privacy_preferences.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';

/// Account privacy (walkthrough pages 01–02). Entered from Profile when the
/// user has an own store. Radios preview the non-follower matrix; applying a
/// change always opens a confirm sheet first, then PATCHes store privacy.
class AccountPrivacyRoute extends StatefulWidget {
  const AccountPrivacyRoute({super.key});

  @override
  State<AccountPrivacyRoute> createState() => _AccountPrivacyRouteState();
}

class _AccountPrivacyRouteState extends State<AccountPrivacyRoute> {
  late final StorePrivacyPreferences _prefs;
  late StorePrivacyMode _preview;
  bool _hydrating = false;

  @override
  void initState() {
    super.initState();
    _prefs = ServiceLocator.get<StorePrivacyPreferences>();
    _preview = _prefs.mode;
    _prefs.addListener(_syncFromPrefs);
    _hydrateFromServer();
  }

  @override
  void dispose() {
    _prefs.removeListener(_syncFromPrefs);
    super.dispose();
  }

  void _syncFromPrefs() {
    if (!mounted) return;
    setState(() => _preview = _prefs.mode);
  }

  Future<void> _hydrateFromServer() async {
    if (_hydrating) return;
    setState(() => _hydrating = true);
    try {
      await _prefs.refreshFromServer();
    } catch (_) {
      // Keep cached local mode; user can still try switching.
    } finally {
      if (mounted) setState(() => _hydrating = false);
    }
  }

  Future<void> _onSelectMode(StorePrivacyMode next) async {
    if (_prefs.isBusy) return;
    if (_prefs.mode == next) {
      setState(() => _preview = next);
      return;
    }
    setState(() => _preview = next);
    final pendingForSheet =
        next == StorePrivacyMode.public
            ? _prefs.pendingFollowRequestCount
            : 0;
    final confirmed = await showStorePrivacyConfirmSheet(
      context,
      next: next,
      pendingRequestCount: pendingForSheet,
    );
    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _preview = _prefs.mode);
      return;
    }
    try {
      await _prefs.setMode(next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Store is now ${next.label.toLowerCase()}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _preview = _prefs.mode);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenWrapper(
      backgroundColor: AppColors.background,
      child: ListView(
        padding: AppPadding.screen(
          top: ScreenWrapper.statusBarTop(context),
          bottom: 24,
        ),
        children: [
          AppBackButton(
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: 8),
          Text(
            'Account privacy',
            style: AppTextStyles.headline(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_hydrating || _prefs.isBusy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: 20),
          Text(
            'WHO CAN SEE YOUR STORE',
            style: AppTextStyles.label(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _PrivacyOptionsCard(
            selected: _preview,
            onSelect: _onSelectMode,
          ),
          const SizedBox(height: 20),
          Text(
            'WHAT A NON-FOLLOWER SEES',
            style: AppTextStyles.label(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _NonFollowerMatrix(mode: _preview),
          const SizedBox(height: 12),
          Text(
            'Approved followers always see everything. You can remove a '
            'follower at any time from your Followers list.',
            style: AppTextStyles.caption(height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _PrivacyOptionsCard extends StatelessWidget {
  const _PrivacyOptionsCard({
    required this.selected,
    required this.onSelect,
  });

  final StorePrivacyMode selected;
  final ValueChanged<StorePrivacyMode> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _PrivacyOptionRow(
            mode: StorePrivacyMode.public,
            selected: selected == StorePrivacyMode.public,
            onTap: () => onSelect(StorePrivacyMode.public),
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: AppColors.border,
          ),
          _PrivacyOptionRow(
            mode: StorePrivacyMode.private,
            selected: selected == StorePrivacyMode.private,
            onTap: () => onSelect(StorePrivacyMode.private),
          ),
        ],
      ),
    );
  }
}

class _PrivacyOptionRow extends StatelessWidget {
  const _PrivacyOptionRow({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final StorePrivacyMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: AppTextStyles.body(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mode.whoCanSeeSubtitle,
                    style: AppTextStyles.caption(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NonFollowerMatrix extends StatelessWidget {
  const _NonFollowerMatrix({required this.mode});

  final StorePrivacyMode mode;

  @override
  Widget build(BuildContext context) {
    final private = mode.isPrivate;
    final rows = <({String label, String status, bool positive})>[
      (label: 'Store name, logo, city', status: 'Visible', positive: true),
      (label: 'Follower & product counts', status: 'Visible', positive: true),
      (
        label: 'Product photos & details',
        status: private ? 'Hidden' : 'Visible',
        positive: !private,
      ),
      (
        label: 'Products in global search',
        status: private ? 'Hidden' : 'Visible',
        positive: !private,
      ),
      (
        label: 'Following',
        status: private ? 'Needs approval' : 'Instant',
        positive: !private,
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(rows[i].label, style: AppTextStyles.body()),
                    ),
                    Text(
                      rows[i].status,
                      style: AppTextStyles.body(
                        fontWeight: FontWeight.w600,
                        color:
                            rows[i].positive
                                ? AppColors.success
                                : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Confirm sheet before applying a privacy mode change (page 02).
Future<bool?> showStorePrivacyConfirmSheet(
  BuildContext context, {
  required StorePrivacyMode next,
  required int pendingRequestCount,
}) {
  final toPublic = next == StorePrivacyMode.public;
  final bullets =
      toPublic
          ? <String>[
            'Anyone can see all your products and photos.',
            'Your products appear in global search and trending.',
            if (pendingRequestCount > 0)
              '$pendingRequestCount pending request${pendingRequestCount == 1 ? '' : 's'} will be approved automatically.',
          ]
          : <String>[
            'Current followers keep access.',
            'New followers need your approval.',
            'Products leave search, trending and categories for non-followers.',
          ];

  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Switch to ${next.label.toLowerCase()}?',
                style: AppTextStyles.title(fontSize: 20),
              ),
              const SizedBox(height: 12),
              for (final bullet in bullets) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ', style: AppTextStyles.body()),
                      Expanded(
                        child: Text(bullet, style: AppTextStyles.body()),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Switch to ${next.label.toLowerCase()}',
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                child: Text(
                  'Cancel',
                  style: AppTextStyles.body(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
