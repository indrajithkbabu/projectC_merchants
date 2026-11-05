import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/contacts/contacts_bloc.dart';
import 'package:project_c/bloc/store_listing/store_listing_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/chat/chat_mock_store.dart';
import 'package:project_c/presentation/chat/chat_models.dart';
import 'package:project_c/presentation/chat/chat_widgets/chat_pieces.dart';
import 'package:project_c/presentation/chat/new_group_route.dart';
import 'package:project_c/presentation/main_shell/tabs/contacts_tab.dart';

/// New chat: group, find stores, invite, then stores and followers.
class NewChatRoute extends StatefulWidget {
  const NewChatRoute({
    super.key,
    this.contactsBloc,
    this.storeListingBloc,
  });

  final ContactsBloc? contactsBloc;
  final StoreListingBloc? storeListingBloc;

  @override
  State<NewChatRoute> createState() => _NewChatRouteState();
}

class _NewChatRouteState extends State<NewChatRoute> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final people =
        ChatMockStore.instance.followers.where((person) {
          if (query.isEmpty) return true;
          final phone = person.phone.replaceAll(RegExp(r'\s+'), '');
          return person.name.toLowerCase().contains(query) ||
              phone.contains(query);
        }).toList();
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
            _Action(
              icon: Icons.group_add_outlined,
              label: 'New group',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const NewGroupRoute()),
                );
              },
            ),
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
                        'No matching people',
                        style: AppTextStyles.bodySecondary(),
                      ),
                    )
                    : ListView(
                      children: [
                        if (stores.isNotEmpty) _label('Stores'),
                        for (final person in stores) _person(person),
                        if (followers.isNotEmpty) _label('Followers'),
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

  void _open(ChatActor person) {
    final chatId = ChatMockStore.instance.startChat(person);
    Navigator.of(context).pushReplacementNamed(
      Routes.chatThreadRoute,
      arguments: <String, String?>{'chatId': chatId},
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
  });

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
