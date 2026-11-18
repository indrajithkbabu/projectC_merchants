import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/chat_inbox/chat_inbox_bloc.dart';
import 'package:project_c/bloc/contacts/contacts_bloc.dart';
import 'package:project_c/bloc/store_listing/store_listing_bloc.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/models/catalog/chat_api_models.dart';
import 'package:project_c/models/store_channel.dart';
import 'package:project_c/presentation/chat/chat_models.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/chat/chat_repository.dart';
import 'package:project_c/presentation/chat/chat_widgets/chat_pieces.dart';
import 'package:project_c/presentation/chat/new_group_route.dart';
import 'package:project_c/presentation/main_shell/tabs/contacts_tab.dart';

/// New chat: group, find stores, invite, then stores and followers.
class NewChatRoute extends StatefulWidget {
  const NewChatRoute({super.key, this.contactsBloc, this.storeListingBloc});

  final ContactsBloc? contactsBloc;
  final StoreListingBloc? storeListingBloc;

  @override
  State<NewChatRoute> createState() => _NewChatRouteState();
}

class _NewChatRouteState extends State<NewChatRoute> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  bool _opening = false;
  StreamSubscription<StoreListingState>? _listingSub;
  StreamSubscription<ContactsState>? _contactsSub;

  @override
  void initState() {
    super.initState();
    _listingSub = widget.storeListingBloc?.stream.listen((_) {
      if (mounted) setState(() {});
    });
    _contactsSub = widget.contactsBloc?.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _listingSub?.cancel();
    _contactsSub?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final people = _matches(_people(), query);
    final stores = people.where((person) => person.isStoreAccount).toList();
    final followers = people.where((person) => !person.isStoreAccount).toList();

    return ScreenWrapper(
      backgroundColor: AppColors.scaffold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              4,
              ScreenWrapper.statusBarTop(context) + 4,
              8,
              8,
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: AppColors.backIcon,
                  ),
                ),
                Expanded(
                  child: Text(
                    'New chat',
                    style: AppTextStyles.headline(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: AppPadding.screenHorizontal,
            child: TextField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
              style: AppTextStyles.body(fontSize: 15),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search name or number',
                hintStyle: AppTextStyles.hint(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (query.isEmpty) ...[
            // _Action(
            //   icon: Icons.group_add_outlined,
            //   label: 'New group',
            //   onTap: () {
            //     Navigator.of(context).push(
            //       MaterialPageRoute<void>(
            //         builder: (_) => const NewGroupRoute(),
            //       ),
            //     );
            //   },
            // ),
            _Action(
              icon: Icons.storefront_outlined,
              label: 'Find stores',
              onTap: _findStores,
            ),
            _Action(
              icon: Icons.person_add_alt_1_outlined,
              label: 'Invite friends',
              onTap: () {
                Navigator.of(context).pushNamed(
                  Routes.inviteFriendsRoute,
                  arguments: <String, Object?>{
                    'contactsBloc': widget.contactsBloc,
                  },
                );
              },
            ),
          ],
          Expanded(
            child:
                people.isEmpty
                    ? Center(
                      child: Text(
                        query.isEmpty ? 'No stores yet' : 'No matching people',
                        style: AppTextStyles.bodySecondary(),
                      ),
                    )
                    : ListView(
                      children: [
                        if (stores.isNotEmpty) _label('Stores'),
                        for (final person in stores) _person(person),
                        if (followers.isNotEmpty) _label('Contacts'),
                        for (final person in followers) _person(person),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(
        text,
        style: AppTextStyles.caption(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _person(ChatActor person) {
    return ListTile(
      leading: ChatAvatar(actor: person, size: 44),
      title: Text(person.name, style: AppTextStyles.label(fontSize: 16)),
      subtitle:
          person.phone.isEmpty
              ? null
              : Text(person.phone, style: AppTextStyles.caption(fontSize: 12)),
      onTap: () => _open(person),
    );
  }

  void _findStores() {
    final contacts = widget.contactsBloc;
    final listing = widget.storeListingBloc;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return MultiBlocProvider(
            providers: [
              if (contacts != null)
                BlocProvider<ContactsBloc>.value(value: contacts)
              else
                BlocProvider(create: (_) => ContactsBloc()),
              if (listing != null)
                BlocProvider<StoreListingBloc>.value(value: listing)
              else
                BlocProvider(create: (_) => StoreListingBloc()),
            ],
            child: const ContactsTab(showBack: true),
          );
        },
      ),
    );
  }

  List<ChatActor> _people() {
    final stores =
        widget.storeListingBloc?.state.allStores ?? const <StoreChannel>[];
    final contacts =
        widget.contactsBloc?.state.deviceContacts ??
        const <ContactInviteCandidate>[];
    return [
      for (final store in stores)
        if (!store.isOwn &&
            RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(store.id.trim()))
          ChatActor(
            id: store.id.trim(),
            name: store.name.trim().isEmpty ? 'Store' : store.name.trim(),
            isStoreAccount: true,
            phone: store.phone,
          ),
      for (final contact in contacts)
        if (contact.phone.trim().isNotEmpty)
          ChatActor(
            id: contact.phone.trim(),
            name:
                contact.name.trim().isEmpty
                    ? contact.phone.trim()
                    : contact.name.trim(),
            phone: contact.phone.trim(),
          ),
    ];
  }

  List<ChatActor> _matches(List<ChatActor> people, String query) {
    if (query.isEmpty) return people;
    return people.where((person) {
      final phone = person.phone.replaceAll(RegExp(r'\s+'), '');
      return person.name.toLowerCase().contains(query) || phone.contains(query);
    }).toList();
  }

  Future<void> _open(ChatActor person) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final repository = ServiceLocator.get<ChatRepository>();
      final ChatRelationship relationship;
      if (person.isStoreAccount) {
        relationship = await repository.openStoreChat(person.id);
      } else {
        final phone = _internationalPhone(person.phone);
        if (phone == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Use a mobile number with country code.'),
            ),
          );
          return;
        }
        relationship = await repository.openCustomerChat(phone);
      }
      if (!mounted || relationship.id.trim().isEmpty) return;
      context.read<ChatInboxBloc>().add(const ChatInboxRefreshed());
      final other = relationship.otherSide;
      final title =
          (other?.name.trim().isNotEmpty == true)
              ? other!.name.trim()
              : person.name;
      await Navigator.of(context).pushReplacementNamed(
        Routes.chatThreadRoute,
        arguments: <String, Object?>{
          'chatId': relationship.id,
          'api': true,
          'title': title,
          'isStore': person.isStoreAccount || other?.isStore == true,
        },
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }
}

String? _internationalPhone(String raw) {
  final compact = raw.replaceAll(RegExp(r'[\s-]'), '');
  if (compact.startsWith('+') && compact.length >= 8) return compact;
  final digits = compact.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 10) return '+91$digits';
  if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
  if (digits.length == 11 && digits.startsWith('0')) {
    return '+91${digits.substring(1)}';
  }
  return null;
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(label, style: AppTextStyles.label(fontSize: 16)),
      onTap: onTap,
    );
  }
}
