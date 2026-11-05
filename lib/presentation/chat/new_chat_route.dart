import 'package:flutter/material.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/chat/chat_mock_store.dart';
import 'package:project_c/presentation/chat/chat_models.dart';
import 'package:project_c/presentation/chat/chat_widgets/chat_pieces.dart';

/// Searchable list of customers who follow the store. Opens the existing
/// chat or starts an empty one that stays off the list until a message is sent.
class NewChatRoute extends StatefulWidget {
  const NewChatRoute({super.key});

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
          return person.name.toLowerCase().contains(query);
        }).toList();

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
            padding: AppPadding.screen(bottom: 8),
            child: Text(
              'Customers who follow the store',
              style: AppTextStyles.caption(),
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
                hintText: 'Search',
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
          const SizedBox(height: 8),
          Expanded(
            child:
                people.isEmpty
                    ? Center(
                      child: Text(
                        'No matching customers',
                        style: AppTextStyles.bodySecondary(),
                      ),
                    )
                    : ListView.separated(
                      itemCount: people.length,
                      separatorBuilder:
                          (_, _) => Divider(
                            height: 1,
                            indent: 72,
                            color: AppColors.divider,
                          ),
                      itemBuilder: (context, index) {
                        final person = people[index];
                        return InkWell(
                          onTap: () => _open(person),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppPadding.horizontal,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                ChatAvatar(actor: person, size: 44),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          person.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.label(
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      if (person.isStoreAccount) ...[
                                        const SizedBox(width: 6),
                                        const ChatStoreTag(),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
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
