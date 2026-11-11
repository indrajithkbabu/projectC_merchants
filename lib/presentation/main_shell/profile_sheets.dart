import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/account_profile/account_profile_bloc.dart';
import 'package:project_c/bloc/profile_context/profile_context_bloc.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/profile_switching_log.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/catalog/profile_context.dart';
import 'package:project_c/navigation/routes.dart';

/// Profile ☰ opens Settings for Personal / Owner / Staff.
///
/// Role actions (Create store, Staff, Leave, Delete store, Log out, Delete
/// account) live on [SettingsTab], not in a hamburger action sheet.
Future<void> showProfileHamburgerSheet(BuildContext context) {
  ProfileSwitchingLog.d(
    'PS-12/51/60/61/82',
    'hamburger → Settings (role actions live on Settings)',
  );
  return openProfileSettings(context);
}

/// Push [Routes.settingsRoute], reusing shell blocs when available.
Future<void> openProfileSettings(BuildContext context) {
  AccountProfileBloc? accountBloc;
  ProfileContextBloc? profileCtx;
  try {
    accountBloc = context.read<AccountProfileBloc>();
  } catch (_) {
    accountBloc = null;
  }
  try {
    profileCtx = context.read<ProfileContextBloc>();
  } catch (_) {
    profileCtx = null;
  }
  final active = profileCtx?.state.activeProfile;
  final ctxState = profileCtx?.state;
  ProfileSwitchingLog.d(
    'PS-12/51/60/61/82',
    'open Settings active=${active?.id ?? "(none)"} '
    'role=${active?.role.name ?? "(none)"} '
    'personal=${ctxState?.isPersonal ?? true} '
    'owner=${ctxState?.isOwner ?? false} '
    'staff=${ctxState?.isStaff ?? false} '
    'canCreate=${ctxState?.canCreateStore ?? false}',
  );
  return Navigator.of(context).pushNamed(
    Routes.settingsRoute,
    arguments: <String, Object?>{
      if (accountBloc != null) 'accountProfileBloc': accountBloc,
      if (profileCtx != null) 'profileContextBloc': profileCtx,
    },
  );
}

/// Profile switcher bottom sheet (UI 2).
Future<void> showProfileSwitcherSheet(
  BuildContext context, {
  String source = 'chevron',
}) {
  final bloc = context.read<ProfileContextBloc>();
  final snap = bloc.state;
  ProfileSwitchingLog.d(
    'PS-20/21/25',
    'switcher open source=$source '
    'active=${snap.activeProfile?.id ?? "(none)"} '
    'profiles=${snap.bootstrap?.profiles.length ?? 0} '
    'pendingInvites=${snap.bootstrap?.pendingInvitations.length ?? 0} '
    'canCreate=${snap.canCreateStore || snap.permissions.createStore} '
    'rows=check/circle only (no unread badges)',
  );
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return BlocProvider.value(
        value: bloc,
        child: BlocBuilder<ProfileContextBloc, ProfileContextState>(
          builder: (context, state) {
            final bootstrap = state.bootstrap;
            final profiles = bootstrap?.profiles ?? const <ActableProfile>[];
            final invites =
                bootstrap?.pendingInvitations ?? const <PendingInvitation>[];
            final activeId = state.activeProfile?.id;
            final canCreate =
                bootstrap?.storeCreation.canCreate == true ||
                state.permissions.createStore;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(bottom: 8),
                          children: [
                            for (final profile in profiles)
                              _SwitcherProfileRow(
                                profile: profile,
                                selected: profile.id == activeId,
                                onTap: () {
                                  Navigator.of(sheetContext).pop();
                                  if (profile.id == activeId) return;
                                  context.read<ProfileContextBloc>().add(
                                    ProfileContextSelectProfile(profile.id),
                                  );
                                },
                              ),
                            for (final invite in invites)
                              _SwitcherInviteRow(
                                invite: invite,
                                onJoin: () {
                                  Navigator.of(sheetContext).pop();
                                  context.read<ProfileContextBloc>().add(
                                    ProfileContextAcceptInvite(
                                      invite.decisionId,
                                    ),
                                  );
                                },
                                onDecline: () {
                                  Navigator.of(sheetContext).pop();
                                  context.read<ProfileContextBloc>().add(
                                    ProfileContextDeclineInvite(
                                      invite.decisionId,
                                    ),
                                  );
                                },
                              ),
                            if (canCreate)
                              ListTile(
                                leading: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.surfaceSecondary,
                                  child: Icon(
                                    Icons.add_rounded,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                title: Text(
                                  'Create a store',
                                  style: AppTextStyles.body(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.of(sheetContext).pop();
                                  ProfileSwitchingLog.d(
                                    'PS-31/33',
                                    'Create a store from switcher '
                                    'wasPersonal=${state.activeProfile?.isPersonal == true}',
                                  );
                                  // API create uses Personal header from session;
                                  // switch to Personal first when acting as a store.
                                  if (state.activeProfile?.isPersonal != true) {
                                    for (final p
                                        in state.bootstrap?.profiles ??
                                            const <ActableProfile>[]) {
                                      if (p.isPersonal &&
                                          p.id.trim().isNotEmpty) {
                                        context.read<ProfileContextBloc>().add(
                                          ProfileContextSelectProfile(p.id),
                                        );
                                        break;
                                      }
                                    }
                                  }
                                  Navigator.of(
                                    context,
                                  ).pushNamed(Routes.storeSetupRoute);
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

Future<bool?> showDestructiveConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: AppTextStyles.headline(fontSize: 18, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        content: Text(
          body,
          style: AppTextStyles.bodySecondary(),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: EdgeInsets.zero,
        actions: [
          const Divider(height: 1),
          SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(
                      'Cancel',
                      style: AppTextStyles.body(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                Container(width: 1, color: AppColors.divider),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(
                      confirmLabel,
                      style: AppTextStyles.body(
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _SwitcherProfileRow extends StatelessWidget {
  const _SwitcherProfileRow({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final ActableProfile profile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: _AvatarCircle(
        initials: profile.displayInitials,
        imageUrl: profile.effectiveAvatarUrl,
      ),
      title: Text(
        profile.name,
        style: AppTextStyles.body(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        profile.roleLabel,
        style: AppTextStyles.caption(),
      ),
      trailing: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: selected ? AppColors.primary : AppColors.textSecondary,
      ),
    );
  }
}

class _SwitcherInviteRow extends StatelessWidget {
  const _SwitcherInviteRow({
    required this.invite,
    required this.onJoin,
    required this.onDecline,
  });

  final PendingInvitation invite;
  final VoidCallback onJoin;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.72,
      child: ListTile(
        leading: _AvatarCircle(
          initials: invite.displayInitials,
          imageUrl: invite.avatarUrl?.trim() ?? '',
        ),
        title: Text(
          invite.displayName,
          style: AppTextStyles.body(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          invite.label.trim().isEmpty ? 'Added you as staff' : invite.label,
          style: AppTextStyles.caption(),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onDecline,
              icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
              tooltip: 'Decline',
            ),
            TextButton(
              onPressed: onJoin,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(0, 34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                'Join',
                style: AppTextStyles.caption(
                  fontWeight: FontWeight.w700,
                  color: AppColors.background,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.initials, required this.imageUrl});

  final String initials;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    if (url.isNotEmpty) {
      return CatalogNetworkAvatar(
        url: url,
        size: 44,
        backgroundColor: AppColors.surfaceSecondary,
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.primary.withValues(alpha: 0.85),
      child: Text(
        initials,
        style: AppTextStyles.caption(
          fontWeight: FontWeight.w700,
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}
