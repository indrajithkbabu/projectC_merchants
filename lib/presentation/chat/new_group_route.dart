import 'package:flutter/material.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/chat/chat_mock_store.dart';
import 'package:project_c/presentation/chat/chat_models.dart';
import 'package:project_c/presentation/chat/chat_widgets/chat_pieces.dart';

/// Pick stores and people, then name the group. A store adds its whole team.
class NewGroupRoute extends StatefulWidget {
  const NewGroupRoute({super.key});

  @override
  State<NewGroupRoute> createState() => _NewGroupRouteState();
}

class _NewGroupRouteState extends State<NewGroupRoute> {
  final List<ChatActor> _picked = [];

  @override
  Widget build(BuildContext context) {
    final people = ChatMockStore.instance.followers;
    final stores = people.where((actor) => actor.isStoreAccount).toList();
    final team = people.where((actor) => !actor.isStoreAccount).toList();
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
                    'New group',
                    style: AppTextStyles.headline(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _picked.isEmpty ? null : _nameGroup,
                  child: const Text('Next'),
                ),
              ],
            ),
          ),
          if (_picked.isEmpty)
            Padding(
              padding: AppPadding.screenHorizontal,
              child: Text(
                'Add stores or people',
                style: AppTextStyles.caption(),
              ),
            )
          else
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: AppPadding.screenHorizontal,
                itemCount: _picked.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final actor = _picked[index];
                  return GestureDetector(
                    onTap: () => setState(() => _picked.remove(actor)),
                    child: Column(
                      children: [
                        ChatAvatar(actor: actor, size: 44),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 64,
                          child: Text(
                            actor.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: ListView(
              children: [
                if (stores.isNotEmpty) _section('Stores'),
                for (final actor in stores) _row(actor, store: true),
                if (team.isNotEmpty) _section('Your team'),
                for (final actor in team) _row(actor, store: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: AppTextStyles.caption(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _row(ChatActor actor, {required bool store}) {
    final on = _picked.any((item) => item.id == actor.id);
    final people = store ? actor.team.length + 1 : 1;
    return ListTile(
      leading: ChatAvatar(actor: actor, size: 44),
      title: Text(actor.name, style: AppTextStyles.label(fontSize: 16)),
      subtitle:
          store
              ? Text(
                'Store · $people people',
                style: AppTextStyles.caption(fontSize: 12),
              )
              : null,
      trailing: Icon(
        on ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: on ? chatReadTick : AppColors.textSecondary,
      ),
      onTap: () {
        setState(() {
          if (on) {
            _picked.removeWhere((item) => item.id == actor.id);
          } else {
            _picked.add(actor);
          }
        });
      },
    );
  }

  Future<void> _nameGroup() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Group name'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed:
                  () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    final chatId = ChatMockStore.instance.createGroup(
      name: name,
      picked: List<ChatActor>.of(_picked),
    );
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.chatThreadRoute,
      (route) => route.isFirst,
      arguments: <String, String?>{
        'chatId': chatId,
        'openDiscussionId':
            ChatMockStore.instance.threadById(chatId)?.openDiscussionId,
      },
    );
  }
}
