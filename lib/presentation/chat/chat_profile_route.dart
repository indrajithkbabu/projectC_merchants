import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/chat/chat_mock_store.dart';
import 'package:project_c/presentation/chat/chat_models.dart';
import 'package:project_c/presentation/chat/chat_shared_route.dart';
import 'package:project_c/presentation/chat/chat_widgets/chat_pieces.dart';

void openChatProfile(
  BuildContext context,
  ChatThread thread, {
  String? memberId,
}) {
  Navigator.of(context).pushNamed(
    Routes.chatProfileRoute,
    arguments: <String, String?>{
      'chatId': thread.id,
      'memberId': memberId,
    },
  );
}

class ChatProfileRoute extends StatefulWidget {
  const ChatProfileRoute({super.key, required this.chatId, this.memberId});

  final String chatId;
  final String? memberId;

  @override
  State<ChatProfileRoute> createState() => _ChatProfileRouteState();
}

enum _ProfileKind { store, personal, staff, customer, group }

class _ChatProfileRouteState extends State<ChatProfileRoute> {
  bool _peopleOpen = false;
  bool _storesOpen = false;
  bool _groupsOpen = false;
  bool _askedOpen = false;
  bool _staffDiscussionsOpen = false;

  @override
  Widget build(BuildContext context) {
    return ScreenWrapper(
      backgroundColor: AppColors.scaffold,
      child: ListenableBuilder(
        listenable: ChatMockStore.instance,
        builder: (context, _) {
          final store = ChatMockStore.instance;
          final thread = store.threadById(widget.chatId);
          if (thread == null) {
            return const Center(child: Text('This chat is unavailable'));
          }
          final member = _member(thread);
          final kind = _kind(thread, member, store.storeName);
          final subject = _subject(store, thread, member, kind);
          final ownsChat = member == null || subject.id != thread.id;
          return Column(
            children: [
              _Bar(
                title: _title(kind),
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _Who(thread: subject, member: member, kind: kind),
                    const SizedBox(height: 16),
                    _Actions(
                      kind: kind,
                      muted: ownsChat && subject.muted,
                      onCatalogue: () => _catalogue(thread, kind),
                      onSearch: () => _search(thread),
                      onMute: () {
                        if (!ownsChat) {
                          _toast('Mute applies on their own chat');
                          return;
                        }
                        store.setMuted(subject.id, !subject.muted);
                      },
                      onMessage: () => _message(member, thread),
                      onAdd: () => _add(thread),
                    ),
                    const SizedBox(height: 12),
                    ..._rows(store, thread, subject, member, kind),
                    const SizedBox(height: 8),
                    ..._redRows(store, thread, member, kind),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  ChatMember? _member(ChatThread thread) {
    final id = widget.memberId?.trim() ?? '';
    if (id.isEmpty) return null;
    for (final member in thread.members) {
      if (member.id == id) return member;
    }
    return null;
  }

  _ProfileKind _kind(ChatThread thread, ChatMember? member, String viewerStore) {
    if (member != null) {
      if (chatMemberOnViewerStore(member, viewerStore)) {
        return _ProfileKind.staff;
      }
      return _ProfileKind.personal;
    }
    if (thread.kind == ChatKind.group) return _ProfileKind.group;
    if (thread.kind == ChatKind.store ||
        thread.outbound ||
        thread.customer.isStoreAccount) {
      return _ProfileKind.store;
    }
    return _ProfileKind.customer;
  }

  ChatThread _subject(
    ChatMockStore store,
    ChatThread thread,
    ChatMember? member,
    _ProfileKind kind,
  ) {
    if (kind != _ProfileKind.personal || member == null) return thread;
    for (final item in store.visibleThreads) {
      if (item.customer.id == member.id || item.customer.name == member.name) {
        return item;
      }
    }
    return thread;
  }

  String _title(_ProfileKind kind) {
    switch (kind) {
      case _ProfileKind.store:
        return 'Store';
      case _ProfileKind.personal:
        return 'Contact';
      case _ProfileKind.staff:
        return 'Staff';
      case _ProfileKind.customer:
        return 'Customer';
      case _ProfileKind.group:
        return 'Group';
    }
  }

  List<Widget> _rows(
    ChatMockStore store,
    ChatThread thread,
    ChatThread subject,
    ChatMember? member,
    _ProfileKind kind,
  ) {
    switch (kind) {
      case _ProfileKind.store:
        return [
          _sharedRow(thread),
          _linkRow(
            icon: Icons.forum_outlined,
            title: 'Discussions',
            onTap: () => _search(thread),
          ),
          _linkRow(
            icon: Icons.people_outline,
            title: 'People',
            trailing: _peopleOpen ? 'Hide' : '${thread.peopleCount}',
            onTap: () => setState(() => _peopleOpen = !_peopleOpen),
          ),
          if (_peopleOpen) _peopleList(thread),
        ];
      case _ProfileKind.personal:
        final ownChat = subject.id != thread.id;
        return [
          if (ownChat)
            _sharedRow(subject)
          else
            _linkRow(
              icon: Icons.collections_outlined,
              title: 'Shared',
              onTap: () => _toast('Nothing shared in a chat with ${member?.name ?? 'them'} yet'),
            ),
          _linkRow(
            icon: Icons.groups_outlined,
            title: 'Groups in common',
            trailing: '${_groups(store, member).length}',
            onTap: () => setState(() => _groupsOpen = !_groupsOpen),
          ),
          if (_groupsOpen) _groupList(_groups(store, member)),
        ];
      case _ProfileKind.staff:
        final discussions = _staffDiscussions(thread, member);
        return [
          _linkRow(
            icon: Icons.forum_outlined,
            title: 'Discussions',
            trailing: '${discussions.length}',
            onTap:
                () => setState(
                  () => _staffDiscussionsOpen = !_staffDiscussionsOpen,
                ),
          ),
          if (_staffDiscussionsOpen)
            _discussionList(thread, discussions),
          _linkRow(
            icon: Icons.event_outlined,
            title: 'Joined',
            trailing:
                (member?.joined.trim().isNotEmpty == true)
                    ? member!.joined
                    : '—',
            onTap: () {},
          ),
        ];
      case _ProfileKind.customer:
        final rows = <Widget>[
          if (chatShowsCustomerStoreRows(thread)) ...[
            _linkRow(
              icon: Icons.diamond_outlined,
              title: 'Asked about',
              trailing: '${_asked(thread).length}',
              onTap: () => setState(() => _askedOpen = !_askedOpen),
            ),
            if (_askedOpen) _askedList(thread),
            _linkRow(
              icon: Icons.lock_outline,
              title: 'Team note',
              subtitle:
                  thread.customerNote.trim().isEmpty
                      ? 'Only your store sees this'
                      : thread.customerNote,
              onTap: () => _editNote(thread),
            ),
          ],
          _linkRow(
            icon: Icons.forum_outlined,
            title: 'Discussions',
            onTap: () => _search(thread),
          ),
        ];
        return rows;
      case _ProfileKind.group:
        final stores = _stores(thread);
        return [
          _sharedRow(thread),
          _linkRow(
            icon: Icons.forum_outlined,
            title: 'Discussions',
            onTap: () => _search(thread),
          ),
          _linkRow(
            icon: Icons.storefront_outlined,
            title: 'Stores',
            trailing: '${stores.length}',
            onTap: () => setState(() => _storesOpen = !_storesOpen),
          ),
          if (_storesOpen) _storeList(thread, stores),
        ];
    }
  }

  List<Widget> _redRows(
    ChatMockStore store,
    ChatThread thread,
    ChatMember? member,
    _ProfileKind kind,
  ) {
    switch (kind) {
      case _ProfileKind.store:
      case _ProfileKind.customer:
        return [
          _redRow(
            thread.blocked ? 'Unblock' : 'Block',
            () => _block(thread),
          ),
        ];
      case _ProfileKind.personal:
        final own = _subject(store, thread, member, kind);
        final target = own.id == thread.id ? null : own;
        return [
          _redRow(
            target?.blocked == true ? 'Unblock' : 'Block',
            () => target == null ? _toast('No chat to block yet') : _block(target),
          ),
        ];
      case _ProfileKind.staff:
        final self =
            member != null &&
            (member.id == 'self' ||
                member.name.trim() == store.staffName.trim());
        if (!store.isOwner || self || member == null) return const [];
        return [
          _redRow('Remove from store', () => _remove(thread, member)),
        ];
      case _ProfileKind.group:
        return [_redRow('Leave group', () => _leave(thread))];
    }
  }

  Widget _linkRow({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
    String? trailing,
    Widget? below,
  }) {
    return _LinkRow(
      icon: icon,
      title: title,
      onTap: onTap,
      subtitle: subtitle,
      trailing: trailing,
      below: below,
    );
  }

  Widget _sharedRow(ChatThread thread) {
    final entries = chatSharedEntries(
      thread,
      ChatMockStore.instance.storeName,
    );
    final thumbs =
        entries
            .where(
              (entry) =>
                  entry.kind == ChatSharedKind.product ||
                  entry.kind == ChatSharedKind.photo,
            )
            .take(4)
            .toList();
    return _linkRow(
      icon: Icons.collections_outlined,
      title: 'Shared',
      onTap: () => openChatShared(context, thread.id),
      below:
          thumbs.isEmpty
              ? null
              : Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    for (final entry in thumbs) ...[
                      _Thumb(entry: entry),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
    );
  }

  Widget _peopleList(ChatThread thread) {
    final groups = <String, List<ChatMember>>{};
    for (final member in thread.members) {
      final key =
          member.storeName.trim().isEmpty ? 'People' : member.storeName.trim();
      groups.putIfAbsent(key, () => []).add(member);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              entry.key == 'My store'
                  ? ChatMockStore.instance.storeName
                  : entry.key,
              style: AppTextStyles.caption(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final member in entry.value)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              title: Text(member.name, style: AppTextStyles.body(fontSize: 15)),
              subtitle:
                  member.role.trim().isEmpty
                      ? null
                      : Text(member.role, style: AppTextStyles.caption()),
              onTap: () {
                if (chatMemberOnViewerStore(
                  member,
                  ChatMockStore.instance.storeName,
                )) {
                  openChatProfile(context, thread, memberId: member.id);
                  return;
                }
                openChatProfile(context, thread, memberId: member.id);
              },
            ),
        ],
      ],
    );
  }

  Widget _discussionList(ChatThread thread, List<ProductDiscussion> discussions) {
    if (discussions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text('No discussions yet', style: AppTextStyles.caption()),
      );
    }
    return Column(
      children: [
        for (final discussion in discussions)
          ListTile(
            dense: true,
            title: Text(discussion.title, style: AppTextStyles.body(fontSize: 15)),
            onTap: () => _openDiscussion(thread, discussion.id),
          ),
      ],
    );
  }

  Widget _askedList(ChatThread thread) {
    final products = _asked(thread);
    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text('Nothing asked about yet', style: AppTextStyles.caption()),
      );
    }
    return Column(
      children: [
        for (final product in products)
          ListTile(
            dense: true,
            leading: ChatProductThumb(product: product, size: 36, radius: 8),
            title: Text(product.name, style: AppTextStyles.body(fontSize: 15)),
            subtitle: Text(product.detail, style: AppTextStyles.caption()),
            onTap: () {
              final id = thread.discussionIdForProduct(product.id);
              if (id == null) return;
              _openDiscussion(thread, id);
            },
          ),
      ],
    );
  }

  Widget _groupList(List<ChatThread> groups) {
    if (groups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text('No groups in common', style: AppTextStyles.caption()),
      );
    }
    return Column(
      children: [
        for (final group in groups)
          ListTile(
            dense: true,
            title: Text(
              group.customer.name,
              style: AppTextStyles.body(fontSize: 15),
            ),
            onTap: () => _openDiscussion(group, group.resumeDiscussionId()),
          ),
      ],
    );
  }

  Widget _storeList(ChatThread thread, List<String> stores) {
    return Column(
      children: [
        for (final name in stores)
          ListTile(
            dense: true,
            title: Text(
              name == 'My store' ? ChatMockStore.instance.storeName : name,
              style: AppTextStyles.body(fontSize: 15),
            ),
            subtitle: Text(
              '${thread.members.where((member) => member.storeName.trim() == name).length} people',
              style: AppTextStyles.caption(),
            ),
            onTap: () => _openStore(name),
          ),
      ],
    );
  }

  List<ChatThread> _groups(ChatMockStore store, ChatMember? member) {
    if (member == null) return const [];
    return store.visibleThreads.where((thread) {
      if (thread.kind != ChatKind.group) return false;
      return thread.members.any(
        (item) => item.id == member.id || item.name == member.name,
      );
    }).toList();
  }

  List<ProductDiscussion> _staffDiscussions(
    ChatThread thread,
    ChatMember? member,
  ) {
    if (member == null) return const [];
    final ids = <String>{};
    for (final message in thread.messages) {
      if (message.staffName?.trim() == member.name &&
          message.discussionId != null) {
        ids.add(message.discussionId!);
      }
    }
    return [
      for (final discussion in thread.discussions)
        if (ids.contains(discussion.id)) discussion,
    ];
  }

  List<ChatProductRef> _asked(ChatThread thread) {
    final products = <ChatProductRef>[];
    final seen = <String>{};
    for (final discussion in thread.discussions) {
      final product = discussion.product;
      if (product != null && seen.add(product.id)) products.add(product);
    }
    for (final message in thread.messages) {
      for (final product in message.products) {
        if (seen.add(product.id)) products.add(product);
      }
    }
    return products;
  }

  List<String> _stores(ChatThread thread) {
    final names = <String>[];
    for (final member in thread.members) {
      final store = member.storeName.trim();
      if (store.isEmpty || names.contains(store)) continue;
      names.add(store);
    }
    return names;
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _catalogue(ChatThread thread, _ProfileKind kind) async {
    if (kind == _ProfileKind.customer) {
      ChatMockStore.instance.sendText(
        thread.id,
        'Sent you our catalogue.',
        discussionId: thread.resumeDiscussionId(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Catalogue sent')),
      );
      return;
    }
    await Navigator.of(context).pushNamed(
      Routes.storeProfileRoute,
      arguments: <String, Object?>{
        'storeName': thread.customer.name,
        'storeId': thread.customer.id,
        'isOwnStore': false,
      },
    );
  }

  void _search(ChatThread thread) {
    Navigator.of(context).pushNamed(
      Routes.chatDiscussionsRoute,
      arguments: <String, String>{'chatId': thread.id},
    );
  }

  void _message(ChatMember? member, ChatThread thread) {
    if (member == null) {
      _openDiscussion(thread, thread.resumeDiscussionId());
      return;
    }
    final id = ChatMockStore.instance.startChat(
      ChatActor(
        id: member.id,
        name: member.name,
        phone: member.phone,
        isStoreAccount: false,
      ),
    );
    Navigator.of(context).pushNamed(
      Routes.chatThreadRoute,
      arguments: <String, String?>{'chatId': id},
    );
  }

  Future<void> _add(ChatThread thread) async {
    final store = ChatMockStore.instance;
    final existing = thread.members.map((member) => member.id).toSet();
    final choices =
        store.followers.where((actor) => !existing.contains(actor.id)).toList();
    if (choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No one else to add')),
      );
      return;
    }
    final picked = await showModalBottomSheet<List<ChatActor>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => _AddPeople(choices: choices),
    );
    if (picked == null || picked.isEmpty) return;
    store.addMembers(thread.id, picked);
  }

  Future<void> _editNote(ChatThread thread) async {
    final controller = TextEditingController(text: thread.customerNote);
    final saved = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Team note'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Preferred purity, visiting day…',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (saved == null) return;
    ChatMockStore.instance.setCustomerNote(thread.id, saved);
  }

  Future<void> _block(ChatThread thread) async {
    final blocking = !thread.blocked;
    final ok = await _confirm(
      blocking ? 'Block ${thread.customer.name}?' : 'Unblock ${thread.customer.name}?',
      blocking
          ? 'You can unblock them later from this profile.'
          : 'They will be able to reach this chat again.',
      blocking ? 'Block' : 'Unblock',
    );
    if (!ok || !mounted) return;
    ChatMockStore.instance.setBlocked(thread.id, blocking);
    if (blocking) Navigator.of(context).maybePop();
  }

  Future<void> _remove(ChatThread thread, ChatMember member) async {
    final ok = await _confirm(
      'Remove ${member.name}?',
      'They will leave ${ChatMockStore.instance.storeName}.',
      'Remove',
    );
    if (!ok || !mounted) return;
    ChatMockStore.instance.removeMember(thread.id, member.id);
    Navigator.of(context).maybePop();
  }

  Future<void> _leave(ChatThread thread) async {
    final ok = await _confirm(
      'Leave ${thread.customer.name}?',
      'You will stop seeing this group.',
      'Leave',
    );
    if (!ok || !mounted) return;
    ChatMockStore.instance.leaveGroup(thread.id);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openDiscussion(ChatThread thread, String? discussionId) {
    Navigator.of(context).pushNamed(
      Routes.chatThreadRoute,
      arguments: <String, String?>{
        'chatId': thread.id,
        'openDiscussionId': discussionId,
      },
    );
  }

  void _openStore(String name) {
    final store = ChatMockStore.instance;
    for (final thread in store.visibleThreads) {
      if (thread.customer.name == name &&
          (thread.kind == ChatKind.store || thread.customer.isStoreAccount)) {
        openChatProfile(context, thread);
        return;
      }
    }
    final label = name == 'My store' ? store.storeName : name;
    Navigator.of(context).pushNamed(
      Routes.storeProfileRoute,
      arguments: <String, Object?>{
        'storeName': label,
        'isOwnStore': name == 'My store' || name == store.storeName,
      },
    );
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        );
      },
    );
    return ok == true;
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: ScreenWrapper.statusBarTop(context)),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.backIcon),
          ),
          Text(title, style: AppTextStyles.headline(fontSize: 20)),
        ],
      ),
    );
  }
}

class _Who extends StatelessWidget {
  const _Who({required this.thread, required this.member, required this.kind});

  final ChatThread thread;
  final ChatMember? member;
  final _ProfileKind kind;

  @override
  Widget build(BuildContext context) {
    final name = member?.name ?? thread.customer.name;
    final phone = (member?.phone ?? thread.phone).trim();
    final tag = _tag();
    return Column(
      children: [
        ChatAvatar(
          actor: ChatActor(
            id: member?.id ?? thread.customer.id,
            name: name,
            phone: phone,
            isStoreAccount: kind == _ProfileKind.store,
          ),
          size: 72,
          group: kind == _ProfileKind.group,
        ),
        const SizedBox(height: 10),
        Text(
          name,
          textAlign: TextAlign.center,
          style: AppTextStyles.headline(fontSize: 22),
        ),
        if (phone.isNotEmpty)
          Text(phone, style: AppTextStyles.bodySecondary()),
        if (tag != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(tag, style: AppTextStyles.caption(fontSize: 12)),
          ),
        ],
      ],
    );
  }

  String? _tag() {
    switch (kind) {
      case _ProfileKind.staff:
        final role = member?.role.trim().isNotEmpty == true ? member!.role : 'Staff';
        final store =
            member?.storeName == 'My store'
                ? ChatMockStore.instance.storeName
                : (member?.storeName ?? '');
        return store.isEmpty ? role : '$role · $store';
      case _ProfileKind.customer:
        return 'Customer · follows you';
      case _ProfileKind.store:
      case _ProfileKind.personal:
      case _ProfileKind.group:
        return null;
    }
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.kind,
    required this.muted,
    required this.onCatalogue,
    required this.onSearch,
    required this.onMute,
    required this.onMessage,
    required this.onAdd,
  });

  final _ProfileKind kind;
  final bool muted;
  final VoidCallback onCatalogue;
  final VoidCallback onSearch;
  final VoidCallback onMute;
  final VoidCallback onMessage;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];
    void add(IconData icon, String label, VoidCallback onTap) {
      buttons.add(_ActionButton(icon: icon, label: label, onTap: onTap));
    }

    switch (kind) {
      case _ProfileKind.store:
        add(Icons.grid_view_rounded, 'Catalogue', onCatalogue);
        add(Icons.search_rounded, 'Search', onSearch);
        add(
          muted ? Icons.notifications_off_outlined : Icons.notifications_none,
          muted ? 'Unmute' : 'Mute',
          onMute,
        );
      case _ProfileKind.personal:
        add(Icons.search_rounded, 'Search', onSearch);
        add(
          muted ? Icons.notifications_off_outlined : Icons.notifications_none,
          muted ? 'Unmute' : 'Mute',
          onMute,
        );
      case _ProfileKind.staff:
        add(Icons.chat_bubble_outline, 'Message', onMessage);
        add(Icons.search_rounded, 'Search', onSearch);
      case _ProfileKind.customer:
        add(Icons.chat_bubble_outline, 'Message', onMessage);
        add(Icons.grid_view_rounded, 'Catalogue', onCatalogue);
        add(
          muted ? Icons.notifications_off_outlined : Icons.notifications_none,
          muted ? 'Unmute' : 'Mute',
          onMute,
        );
      case _ProfileKind.group:
        add(Icons.person_add_alt, 'Add', onAdd);
        add(Icons.search_rounded, 'Search', onSearch);
        add(
          muted ? Icons.notifications_off_outlined : Icons.notifications_none,
          muted ? 'Unmute' : 'Mute',
          onMute,
        );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: buttons,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          children: [
            Icon(icon, color: AppColors.textPrimary),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyles.caption(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.below,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback onTap;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: AppColors.textPrimary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.body(fontSize: 16)),
                      if (subtitle != null && subtitle!.trim().isNotEmpty)
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption(),
                        ),
                    ],
                  ),
                ),
                if (trailing != null)
                  Text(trailing!, style: AppTextStyles.caption()),
                Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              ],
            ),
            if (below != null) below!,
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.entry});

  final ChatSharedEntry entry;

  @override
  Widget build(BuildContext context) {
    if (entry.product != null) {
      return ChatProductThumb(product: entry.product!, size: 44, radius: 8);
    }
    final message = entry.message;
    if (message != null && message.kind == ChatMessageKind.photo) {
      return ChatPhotoView(message: message, width: 44, height: 44, radius: 8);
    }
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.insert_drive_file_outlined, color: AppColors.textSecondary),
    );
  }
}

Widget _redRow(String title, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.report_gmailerrorred_rounded, color: Color(0xFFC0392B)),
          const SizedBox(width: 12),
          Text(
            title,
            style: AppTextStyles.body(fontSize: 16, color: const Color(0xFFC0392B)),
          ),
        ],
      ),
    ),
  );
}

class _AddPeople extends StatefulWidget {
  const _AddPeople({required this.choices});

  final List<ChatActor> choices;

  @override
  State<_AddPeople> createState() => _AddPeopleState();
}

class _AddPeopleState extends State<_AddPeople> {
  final Set<String> _picked = {};

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.55,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add',
                      style: AppTextStyles.headline(fontSize: 18),
                    ),
                  ),
                  TextButton(
                    onPressed:
                        _picked.isEmpty
                            ? null
                            : () {
                              final chosen =
                                  widget.choices
                                      .where((actor) => _picked.contains(actor.id))
                                      .toList();
                              Navigator.pop(context, chosen);
                            },
                    child: const Text('Add'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(bottom: bottom),
                children: [
                  for (final actor in widget.choices)
                    CheckboxListTile(
                      value: _picked.contains(actor.id),
                      title: Text(actor.name),
                      subtitle:
                          actor.isStoreAccount
                              ? const Text('Store')
                              : null,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _picked.add(actor.id);
                          } else {
                            _picked.remove(actor.id);
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
