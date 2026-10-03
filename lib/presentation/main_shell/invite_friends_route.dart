import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/contacts/contacts_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/safe_display_text.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/whatsapp_invite.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';

/// Telegram-style Invite Friends: share action + lazy device contact list.
class InviteFriendsRoute extends StatefulWidget {
  const InviteFriendsRoute({super.key});

  @override
  State<InviteFriendsRoute> createState() => _InviteFriendsRouteState();
}

class _InviteFriendsRouteState extends State<InviteFriendsRoute> {
  static const _avatarPalette = <Color>[
    Color(0xFF2AABEE),
    Color(0xFFE67E22),
    Color(0xFF8E44AD),
    Color(0xFF16A085),
    Color(0xFFE74C3C),
    Color(0xFF2980B9),
    Color(0xFF27AE60),
    Color(0xFFD35400),
  ];

  late final TextEditingController _searchController;
  final ValueNotifier<String> _filterQuery = ValueNotifier<String>('');
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _filterQuery.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      if (_filterQuery.value != value) {
        _filterQuery.value = value;
      }
    });
  }

  Color _avatarColorFor(String seed) {
    if (seed.isEmpty) return _avatarPalette.first;
    final hash = seed.codeUnits.fold<int>(0, (a, b) => a + b);
    return _avatarPalette[hash % _avatarPalette.length];
  }

  Future<void> _shareAppInvite(ContactsState state) async {
    final message = WhatsAppInvite.appInviteMessage(
      storeLink: state.storeLink,
    );
    final opened = await WhatsAppInvite.shareText(message);
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Could not open WhatsApp. Install WhatsApp or try again.',
        ),
      ),
    );
  }

  List<ContactInviteCandidate> _filtered(
    List<ContactInviteCandidate> all,
    String rawQuery,
  ) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return all;
    return [
      for (final c in all)
        if (c.name.toLowerCase().contains(q) || c.phone.contains(q)) c,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ScreenWrapper(
      backgroundColor: AppColors.scaffold,
      statusBarIconBrightness: Brightness.dark,
      child: BlocListener<ContactsBloc, ContactsState>(
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
          context.read<ContactsBloc>().add(const ContactsClearMessage());
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: AppPadding.screen(
                top: ScreenWrapper.statusBarTop(context) + 4,
                bottom: 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppBackButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Invite Friends',
                          style: AppTextStyles.headline(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: _searchController,
                    builder: (context, _) {
                      final hasText = _searchController.text.isNotEmpty;
                      return TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: AppTextStyles.body(fontSize: 15),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search',
                          hintStyle: AppTextStyles.hint(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.textSecondary,
                          ),
                          suffixIcon:
                              hasText
                                  ? IconButton(
                                    tooltip: 'Clear',
                                    onPressed: () {
                                      _debounce?.cancel();
                                      _searchController.clear();
                                      _filterQuery.value = '';
                                    },
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: AppColors.textSecondary,
                                    ),
                                  )
                                  : null,
                          filled: true,
                          fillColor: AppColors.surface,
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
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<ContactsBloc, ContactsState>(
                buildWhen:
                    (prev, curr) =>
                        prev.deviceContacts != curr.deviceContacts ||
                        prev.invitingPhone != curr.invitingPhone ||
                        prev.permissionDenied != curr.permissionDenied ||
                        prev.isRefreshing != curr.isRefreshing ||
                        prev.storeLink != curr.storeLink,
                builder: (context, state) {
                  return ValueListenableBuilder<String>(
                    valueListenable: _filterQuery,
                    builder: (context, rawQuery, _) {
                      if (state.permissionDenied) {
                        return ListView(
                          padding: AppPadding.screen(top: 4, bottom: 24),
                          children: [
                            _ShareCard(onTap: () => _shareAppInvite(state)),
                            const SizedBox(height: 24),
                            Text(
                              'Allow contacts access to invite people from your phone book.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.caption(),
                            ),
                          ],
                        );
                      }

                      final invites = _filtered(
                        state.deviceContacts,
                        rawQuery,
                      );
                      final q = rawQuery.trim();
                      final showEmpty =
                          invites.isEmpty && !state.isRefreshing;
                      final showLoading =
                          invites.isEmpty && state.isRefreshing;
                      final contactCount = invites.length;
                      // 0 = share header; then contacts OR empty/loading.
                      final itemCount =
                          1 + (contactCount > 0 ? contactCount : 1);

                      return ListView.builder(
                        padding: AppPadding.screen(top: 4, bottom: 24),
                        itemCount: itemCount,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Column(
                              children: [
                                _ShareCard(
                                  onTap: () => _shareAppInvite(state),
                                ),
                                const SizedBox(height: 12),
                              ],
                            );
                          }

                          if (showEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 24,
                              ),
                              child: Text(
                                q.isEmpty
                                    ? 'No phone contacts to invite yet.'
                                    : 'No matches',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodySecondary(),
                              ),
                            );
                          }

                          if (showLoading) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 32),
                              child: Center(
                                child: Text(
                                  'Loading contacts…',
                                  style: AppTextStyles.bodySecondary(),
                                ),
                              ),
                            );
                          }

                          final i = index - 1;
                          final isFirst = i == 0;
                          final isLast = i == contactCount - 1;
                          return Material(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.vertical(
                              top:
                                  isFirst
                                      ? const Radius.circular(14)
                                      : Radius.zero,
                              bottom:
                                  isLast
                                      ? const Radius.circular(14)
                                      : Radius.zero,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isFirst) const SizedBox(height: 4),
                                if (!isFirst)
                                  const Divider(
                                    height: 1,
                                    indent: 68,
                                    color: AppColors.border,
                                  ),
                                _InviteContactTile(
                                  invite: invites[i],
                                  avatarColor: _avatarColorFor(
                                    invites[i].phone.isNotEmpty
                                        ? invites[i].phone
                                        : invites[i].name,
                                  ),
                                  isBusy:
                                      state.invitingPhone ==
                                      invites[i].phone,
                                ),
                                if (isLast) const SizedBox(height: 4),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 2,
          ),
          leading: const CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary,
            child: Icon(
              Icons.ios_share_rounded,
              color: AppColors.textOnPrimary,
              size: 22,
            ),
          ),
          title: Text(
            'Share JewelFlow',
            style: AppTextStyles.body(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

class _InviteContactTile extends StatelessWidget {
  const _InviteContactTile({
    required this.invite,
    required this.avatarColor,
    required this.isBusy,
  });

  final ContactInviteCandidate invite;
  final Color avatarColor;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final phone = SafeDisplayText.sanitize(invite.phone);
    final name = SafeDisplayText.sanitize(invite.name);
    final initials = SafeDisplayText.initials(
      displayName: invite.name,
      phone: invite.phone,
    );
    return ListTile(
      onTap:
          isBusy
              ? null
              : () => context.read<ContactsBloc>().add(
                ContactsInvitePressed(invite.phone),
              ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 2,
      ),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: avatarColor,
        child: Text(
          initials,
          style: AppTextStyles.label(
            fontWeight: FontWeight.w700,
            color: AppColors.textOnPrimary,
          ),
        ),
      ),
      title: Text(
        name,
        style: AppTextStyles.body(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(phone, style: AppTextStyles.caption()),
      trailing: Text(
        isBusy ? '…' : 'Invite',
        style: AppTextStyles.label(
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
