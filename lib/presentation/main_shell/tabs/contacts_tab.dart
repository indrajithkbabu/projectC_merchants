import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/contacts/contacts_bloc.dart';
import 'package:project_c/bloc/store_listing/store_listing_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/safe_display_text.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/floating_bottom_nav_bar.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/store_channel.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/services/store_products_prefetcher.dart';

/// Contacts tab: Invite Friends + Stores. Phone contacts appear only while
/// searching (or on the dedicated Invite Friends screen).
class ContactsTab extends StatefulWidget {
  const ContactsTab({super.key});

  @override
  State<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<ContactsTab> {
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
    // Short debounce keeps typing smooth while still feeling instant.
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

  Future<void> _pullToRefresh() async {
    final contacts = context.read<ContactsBloc>();
    final listing = context.read<StoreListingBloc>();
    contacts.add(const ContactsRefreshed());
    listing.add(const StoreListingRefreshed());
    await Future.wait([
      contacts.stream.firstWhere((s) => !s.isRefreshing),
      listing.stream.firstWhere((s) => !s.isLoading),
    ]);
  }

  void _openStore(StoreChannel store) {
    StoreProductsPrefetcher.instance.prefetch(
      store.id,
      coverImageUrl: store.coverImageUrl,
    );
    Navigator.of(context).pushNamed(
      Routes.storeProfileRoute,
      arguments: <String, Object?>{
        'store': store,
        'members': const [],
      },
    );
  }

  void _openInviteFriends() {
    // Push immediately — do not wait on keyboard dismiss (felt like a stall).
    final bloc = context.read<ContactsBloc>();
    Navigator.of(context).pushNamed(
      Routes.inviteFriendsRoute,
      arguments: <String, Object?>{'contactsBloc': bloc},
    );
  }

  bool _storeMatches(StoreChannel store, String q) {
    if (q.isEmpty) return true;
    if (store.name.toLowerCase().contains(q)) return true;
    if (store.contactName.toLowerCase().contains(q)) return true;
    if (store.handle.toLowerCase().contains(q)) return true;
    return store.phone.contains(q);
  }

  bool _inviteMatches(ContactInviteCandidate invite, String q) {
    if (q.isEmpty) return false;
    if (invite.name.toLowerCase().contains(q)) return true;
    return invite.phone.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = FloatingBottomNavBar.reservedHeight(context) + 8;

    return BlocListener<ContactsBloc, ContactsState>(
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
      child: ColoredBox(
        color: AppColors.scaffold,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: AppPadding.screen(
                top: ScreenWrapper.statusBarTop(context) + 8,
                bottom: 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contacts',
                    style: AppTextStyles.headline(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ContactsSearchField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onClear: () {
                      _debounce?.cancel();
                      _searchController.clear();
                      _filterQuery.value = '';
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: _filterQuery,
                builder: (context, rawQuery, _) {
                  final q = rawQuery.trim().toLowerCase();
                  final searching = q.isNotEmpty;
                  return BlocBuilder<StoreListingBloc, StoreListingState>(
                    buildWhen:
                        (prev, curr) =>
                            prev.allStores != curr.allStores ||
                            prev.isLoading != curr.isLoading,
                    builder: (context, listingState) {
                      return BlocBuilder<ContactsBloc, ContactsState>(
                        buildWhen:
                            (prev, curr) =>
                                prev.deviceContacts != curr.deviceContacts ||
                                prev.invitingPhone != curr.invitingPhone ||
                                prev.isRefreshing != curr.isRefreshing ||
                                prev.permissionDenied !=
                                    curr.permissionDenied,
                        builder: (context, state) {
                          final peerStores =
                              listingState.allStores
                                  .where((s) => !s.isOwn)
                                  .where((s) => _storeMatches(s, q))
                                  .toList(growable: false);
                          final invites =
                              searching
                                  ? state.deviceContacts
                                      .where((c) => _inviteMatches(c, q))
                                      .toList(growable: false)
                                  : const <ContactInviteCandidate>[];

                          final isEmpty =
                              peerStores.isEmpty && invites.isEmpty;
                          final loading =
                              state.isRefreshing || listingState.isLoading;

                          return RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: _pullToRefresh,
                            child:
                                isEmpty && !loading && searching
                                    ? _EmptySearch(bottomPad: bottomPad)
                                    : _ContactsResultsList(
                                      bottomPad: bottomPad,
                                      searching: searching,
                                      peerStores: peerStores,
                                      invites: invites,
                                      invitingPhone: state.invitingPhone,
                                      loading: loading && isEmpty,
                                      avatarColorFor: _avatarColorFor,
                                      onInviteFriends: _openInviteFriends,
                                      onOpenStore: _openStore,
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

class _ContactsSearchField extends StatelessWidget {
  const _ContactsSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final hasText = controller.text.isNotEmpty;
        return TextField(
          controller: controller,
          onChanged: onChanged,
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
                      onPressed: onClear,
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
    );
  }
}

class _ContactsResultsList extends StatelessWidget {
  const _ContactsResultsList({
    required this.bottomPad,
    required this.searching,
    required this.peerStores,
    required this.invites,
    required this.invitingPhone,
    required this.loading,
    required this.avatarColorFor,
    required this.onInviteFriends,
    required this.onOpenStore,
  });

  final double bottomPad;
  final bool searching;
  final List<StoreChannel> peerStores;
  final List<ContactInviteCandidate> invites;
  final String? invitingPhone;
  final bool loading;
  final Color Function(String seed) avatarColorFor;
  final VoidCallback onInviteFriends;
  final ValueChanged<StoreChannel> onOpenStore;

  @override
  Widget build(BuildContext context) {
    // Section indices in a flat lazy list.
    final showInviteCta = !searching;
    final showStores = peerStores.isNotEmpty;
    final showInvites = searching && invites.isNotEmpty;
    final showEmptyStoresHint =
        !searching && peerStores.isEmpty && !loading;
    final showLoading = loading;

    final sections = <_SectionKind>[
      if (showInviteCta) _SectionKind.inviteCta,
      if (showStores) _SectionKind.stores,
      if (showInvites) _SectionKind.invites,
      if (showEmptyStoresHint) _SectionKind.emptyStores,
      if (showLoading) _SectionKind.loading,
    ];

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppPadding.screen(top: 4, bottom: bottomPad),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final kind = sections[index];
        final topGap = index == 0 ? 0.0 : 12.0;
        switch (kind) {
          case _SectionKind.inviteCta:
            return Padding(
              padding: EdgeInsets.only(top: topGap),
              child: _CardSection(
                children: [
                  _ActionTile(
                    icon: Icons.person_add_alt_1_rounded,
                    iconBackground: AppColors.primary,
                    label: 'Invite Friends',
                    onTap: onInviteFriends,
                  ),
                ],
              ),
            );
          case _SectionKind.stores:
            return Padding(
              padding: EdgeInsets.only(top: topGap),
              child: _CardSection(
                header:
                    searching
                        ? 'Stores · ${peerStores.length}'
                        : 'Stores',
                children: [
                  for (var i = 0; i < peerStores.length; i++) ...[
                    if (i > 0)
                      const Divider(
                        height: 1,
                        indent: 68,
                        color: AppColors.border,
                      ),
                    _StoreTile(
                      store: peerStores[i],
                      onTap: () => onOpenStore(peerStores[i]),
                    ),
                  ],
                ],
              ),
            );
          case _SectionKind.invites:
            return Padding(
              padding: EdgeInsets.only(top: topGap),
              child: _CardSection(
                header: 'Invite · ${invites.length}',
                children: [
                  for (var i = 0; i < invites.length; i++) ...[
                    if (i > 0)
                      const Divider(
                        height: 1,
                        indent: 68,
                        color: AppColors.border,
                      ),
                    _InviteTile(
                      invite: invites[i],
                      avatarColor: avatarColorFor(
                        invites[i].phone.isNotEmpty
                            ? invites[i].phone
                            : invites[i].name,
                      ),
                      isBusy: invitingPhone == invites[i].phone,
                    ),
                  ],
                ],
              ),
            );
          case _SectionKind.emptyStores:
            return Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Text(
                'No stores yet. Pull to refresh, or invite friends to JewelFlow.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary(),
              ),
            );
          case _SectionKind.loading:
            return Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Text(
                  'Loading…',
                  style: AppTextStyles.bodySecondary(),
                ),
              ),
            );
        }
      },
    );
  }
}

enum _SectionKind { inviteCta, stores, invites, emptyStores, loading }

class _CardSection extends StatelessWidget {
  const _CardSection({required this.children, this.header});

  final String? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null && header!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Text(
                  header!,
                  style: AppTextStyles.caption(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconBackground,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBackground;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: iconBackground,
        child: Icon(icon, color: AppColors.textOnPrimary, size: 22),
      ),
      title: Text(
        label,
        style: AppTextStyles.body(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    );
  }
}

class _StoreTile extends StatelessWidget {
  const _StoreTile({required this.store, required this.onTap});

  final StoreChannel store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = store.listingSubtitle;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: Color(store.avatarColor),
        child: Text(
          SafeDisplayText.initials(displayName: store.name),
          style: AppTextStyles.label(
            fontWeight: FontWeight.w700,
            color: AppColors.textOnPrimary,
          ),
        ),
      ),
      title: Text(
        SafeDisplayText.sanitize(store.name),
        style: AppTextStyles.body(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle:
          subtitle.isEmpty
              ? null
              : Text(
                SafeDisplayText.sanitize(subtitle),
                style: AppTextStyles.caption(),
              ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
        style: AppTextStyles.body(fontWeight: FontWeight.w600, fontSize: 16),
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

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.bottomPad});

  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppPadding.screen(top: 48, bottom: bottomPad),
      children: [
        Text(
          'No matches',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySecondary(),
        ),
        const SizedBox(height: 8),
        Text(
          'Try a different name or phone number.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption(),
        ),
      ],
    );
  }
}
