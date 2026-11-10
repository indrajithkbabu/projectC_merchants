import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/chat/chat_mock_store.dart';
import 'package:project_c/presentation/chat/chat_models.dart';
import 'package:project_c/presentation/chat/chat_widgets/chat_pieces.dart';
import 'package:project_c/presentation/chat/chat_widgets/chat_sheets.dart';

/// Discussions inside one chat. One discussion never reaches this screen.
class ChatDiscussionsRoute extends StatefulWidget {
  const ChatDiscussionsRoute({super.key, required this.chatId});

  final String chatId;

  @override
  State<ChatDiscussionsRoute> createState() => _ChatDiscussionsRouteState();
}

class _ChatDiscussionsRouteState extends State<ChatDiscussionsRoute> {
  final TextEditingController _search = TextEditingController();
  final Set<String> _selected = {};
  String _query = '';
  bool _closed = false;
  bool _selecting = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenWrapper(
      backgroundColor: AppColors.scaffold,
      child: ListenableBuilder(
        listenable: ChatMockStore.instance,
        builder: (context, _) {
          final thread = ChatMockStore.instance.threadById(widget.chatId);
          if (thread == null) {
            return const Center(child: Text('This chat is unavailable'));
          }
          final searching = _query.trim().isNotEmpty;
          return Column(
            children: [
              _Header(
                thread: thread,
                selecting: _selecting,
                selectedCount: _selected.length,
                closed: _closed,
                onBack: () {
                  if (_selecting) {
                    setState(() {
                      _selecting = false;
                      _selected.clear();
                    });
                    return;
                  }
                  if (_closed) {
                    setState(() => _closed = false);
                    return;
                  }
                  Navigator.of(context).maybePop();
                },
                onProfile: () => showChatProfileSheet(context, thread),
                onNew: () => _newDiscussion(thread),
                onSelectAll: () => _selectAll(thread),
              ),
              Padding(
                padding: AppPadding.screenHorizontal,
                child: TextField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  style: AppTextStyles.body(fontSize: 15),
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
                    suffixIcon:
                        _query.isEmpty
                            ? null
                            : IconButton(
                              tooltip: 'Clear',
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                              icon: Icon(
                                Icons.close_rounded,
                                color: AppColors.textSecondary,
                              ),
                            ),
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
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 1.2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _body(thread, searching: searching)),
              if (_selecting)
                _SelectBar(
                  enabled: _selected.isNotEmpty,
                  onRead: () => _markRead(thread),
                  onClose: () => _closeSelected(thread),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _body(ChatThread thread, {required bool searching}) {
    final store = ChatMockStore.instance;
    if (searching) {
      final query = _query.trim().toLowerCase();
      final matches =
          thread.discussions.where((discussion) {
            final preview = store.discussionPreview(thread, discussion);
            return discussion.title.toLowerCase().contains(query) ||
                preview.toLowerCase().contains(query);
          }).toList();
      if (matches.isEmpty) {
        return Center(
          child: Text(
            'No discussions match \'${_query.trim()}\'',
            style: AppTextStyles.bodySecondary(),
          ),
        );
      }
      return ListView.separated(
        itemCount: matches.length,
        separatorBuilder:
            (_, _) => Divider(height: 1, color: AppColors.divider),
        itemBuilder: (context, index) {
          final discussion = matches[index];
          return _DiscussionRow(
            thread: thread,
            discussion: discussion,
            searching: true,
            selecting: _selecting,
            selected: _selected.contains(discussion.id),
            onTap: () => _tap(thread, discussion),
            onLongPress: () => _beginSelect(discussion),
            onReopen: () => _reopen(thread, discussion),
          );
        },
      );
    }

    if (_closed) {
      final closed = thread.discussionsByOrder(open: false);
      return ListView.separated(
        itemCount: closed.length,
        separatorBuilder:
            (_, _) => Divider(height: 1, color: AppColors.divider),
        itemBuilder: (context, index) {
          final discussion = closed[index];
          return _DiscussionRow(
            thread: thread,
            discussion: discussion,
            searching: false,
            selecting: false,
            selected: false,
            onTap: () => _openThread(thread, discussion.id),
            onReopen: () => _reopen(thread, discussion),
          );
        },
      );
    }

    final open = thread.discussionsByOrder(open: true);
    final closedCount =
        thread.discussions
            .where((item) => item.status == DiscussionStatus.closed)
            .length;
    return Column(
      children: [
        if (closedCount > 0)
          ListTile(
            leading: Icon(
              Icons.inventory_2_outlined,
              color: AppColors.textSecondary,
            ),
            title: Text('Closed', style: AppTextStyles.label(fontSize: 16)),
            trailing: Text(
              '$closedCount',
              style: AppTextStyles.caption(fontSize: 14),
            ),
            onTap: () => setState(() => _closed = true),
          ),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: open.length,
            onReorder: (oldIndex, newIndex) {
              ChatMockStore.instance.reorderOpenDiscussions(
                thread.id,
                oldIndex,
                newIndex,
              );
            },
            itemBuilder: (context, index) {
              final discussion = open[index];
              return _DiscussionRow(
                key: ValueKey(discussion.id),
                thread: thread,
                discussion: discussion,
                searching: false,
                selecting: _selecting,
                selected: _selected.contains(discussion.id),
                dragIndex: _selecting ? null : index,
                onTap: () => _tap(thread, discussion),
                onLongPress: () => _beginSelect(discussion),
              );
            },
          ),
        ),
      ],
    );
  }

  void _tap(ChatThread thread, ProductDiscussion discussion) {
    if (discussion.status == DiscussionStatus.closed) {
      _openThread(thread, discussion.id);
      return;
    }
    if (_selecting) {
      setState(() {
        if (!_selected.add(discussion.id)) _selected.remove(discussion.id);
        if (_selected.isEmpty) _selecting = false;
      });
      return;
    }
    _openThread(thread, discussion.id);
  }

  void _beginSelect(ProductDiscussion discussion) {
    if (discussion.status == DiscussionStatus.closed ||
        _query.trim().isNotEmpty) {
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _selecting = true;
      _selected.add(discussion.id);
    });
  }

  void _selectAll(ChatThread thread) {
    final open = thread.discussionsByOrder(open: true);
    setState(() {
      if (_selected.length == open.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(open.map((item) => item.id));
      }
    });
  }

  void _markRead(ChatThread thread) {
    ChatMockStore.instance.markDiscussionsRead(thread.id, _selected);
    final count = _selected.length;
    setState(() {
      _selecting = false;
      _selected.clear();
    });
    _toast(count == 1 ? 'Marked as read' : 'Marked as read');
  }

  void _closeSelected(ChatThread thread) {
    final count = ChatMockStore.instance.closeDiscussions(thread.id, _selected);
    setState(() {
      _selecting = false;
      _selected.clear();
    });
    if (count > 0) {
      _toast(count == 1 ? '1 discussion closed' : '$count discussions closed');
    }
  }

  void _reopen(ChatThread thread, ProductDiscussion discussion) {
    ChatMockStore.instance.reopenDiscussionById(thread.id, discussion.id);
    _toast('Reopened · ${discussion.title}');
    setState(() => _closed = false);
  }

  void _openThread(ChatThread thread, String discussionId) {
    Navigator.of(context).pushNamed(
      Routes.chatThreadRoute,
      arguments: <String, String?>{
        'chatId': thread.id,
        'openDiscussionId': discussionId,
      },
    );
  }

  Future<void> _newDiscussion(ChatThread thread) async {
    final started = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => _NewDiscussionSheet(chatId: thread.id),
    );
    if (started != true || !mounted) return;
    final current = ChatMockStore.instance.threadById(thread.id);
    final id = current?.openDiscussionId;
    if (id == null) return;
    _openThread(current!, id);
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.thread,
    required this.selecting,
    required this.selectedCount,
    required this.closed,
    required this.onBack,
    required this.onProfile,
    required this.onNew,
    required this.onSelectAll,
  });

  final ChatThread thread;
  final bool selecting;
  final int selectedCount;
  final bool closed;
  final VoidCallback onBack;
  final VoidCallback onProfile;
  final VoidCallback onNew;
  final VoidCallback onSelectAll;

  @override
  Widget build(BuildContext context) {
    final people = thread.headerSubtitle();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        4,
        ScreenWrapper.statusBarTop(context) + 4,
        4,
        8,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: selecting ? 'Cancel' : 'Back',
            onPressed: onBack,
            icon: Icon(
              selecting
                  ? Icons.close_rounded
                  : Icons.arrow_back_ios_new_rounded,
              size: selecting ? 24 : 20,
              color: AppColors.backIcon,
            ),
          ),
          if (!selecting && !closed) ...[
            GestureDetector(
              onTap: onProfile,
              child: ChatAvatar(
                actor: thread.customer,
                size: 36,
                group: thread.kind == ChatKind.group,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: GestureDetector(
              onTap: selecting || closed ? null : onProfile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selecting
                        ? '$selectedCount selected'
                        : closed
                        ? 'Closed'
                        : thread.customer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!selecting && !closed)
                    Text(
                      people,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption(fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
          if (selecting)
            TextButton(
              onPressed: onSelectAll,
              child: Text(
                selectedCount > 0 &&
                        selectedCount ==
                            thread.discussionsByOrder(open: true).length
                    ? 'Clear'
                    : 'Select all',
              ),
            )
          else if (!closed)
            IconButton(
              tooltip: 'New discussion',
              onPressed: onNew,
              icon: Icon(Icons.add_rounded, color: AppColors.textPrimary),
            ),
        ],
      ),
    );
  }
}

class _DiscussionRow extends StatelessWidget {
  const _DiscussionRow({
    super.key,
    required this.thread,
    required this.discussion,
    required this.searching,
    required this.selecting,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.onReopen,
    this.dragIndex,
  });

  final ChatThread thread;
  final ProductDiscussion discussion;
  final bool searching;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onReopen;
  final int? dragIndex;

  @override
  Widget build(BuildContext context) {
    final store = ChatMockStore.instance;
    final closed = discussion.status == DiscussionStatus.closed;
    final unread = closed ? 0 : thread.unreadInDiscussion(discussion.id);
    final preview = store.discussionPreview(thread, discussion);
    final time = chatListTime(store.discussionActivity(thread, discussion));
    final product = discussion.product;
    return Material(
      color: AppColors.scaffold,
      child: InkWell(
        onTap: onTap,
        onLongPress: closed ? null : onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (selecting) ...[
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? chatReadTick : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
              ],
              if (product != null)
                ChatProductThumb(product: product, size: 48)
              else
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.sticky_note_2_outlined,
                    color: AppColors.textSecondary,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      discussion.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label(fontSize: 15),
                    ),
                    Text(
                      closed && discussion.closedBy.trim().isNotEmpty
                          ? 'Closed by ${discussion.closedBy}'
                          : preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption(fontSize: 13),
                    ),
                    if (searching && closed)
                      Text(
                        'Closed',
                        style: AppTextStyles.caption(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    time,
                    style: AppTextStyles.caption(
                      fontSize: 12,
                      color:
                          unread > 0
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!closed && discussion.mentionUnread)
                        Text(
                          '@',
                          style: AppTextStyles.caption(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: chatReadTick,
                          ),
                        ),
                      if (unread > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          '$unread',
                          style: AppTextStyles.caption(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                      if (closed && onReopen != null)
                        TextButton(
                          onPressed: onReopen,
                          child: const Text('Reopen'),
                        ),
                    ],
                  ),
                ],
              ),
              if (dragIndex != null)
                ReorderableDragStartListener(
                  index: dragIndex!,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.drag_handle_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectBar extends StatelessWidget {
  const _SelectBar({
    required this.enabled,
    required this.onRead,
    required this.onClose,
  });

  final bool enabled;
  final VoidCallback onRead;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(8, 4, 8, 4 + bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: enabled ? onRead : null,
            child: const Text('Mark read'),
          ),
          const Spacer(),
          TextButton(
            onPressed: enabled ? onClose : null,
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _NewDiscussionSheet extends StatefulWidget {
  const _NewDiscussionSheet({required this.chatId});

  final String chatId;

  @override
  State<_NewDiscussionSheet> createState() => _NewDiscussionSheetState();
}

class _NewDiscussionSheetState extends State<_NewDiscussionSheet> {
  late final TextEditingController _name;
  ChatProductRef? _product;

  @override
  void initState() {
    super.initState();
    final date = chatDateName(DateTime.now());
    _name = TextEditingController(text: date);
    _name.selection = TextSelection(baseOffset: 0, extentOffset: date.length);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final catalog = ChatMockStore.instance.shareCatalog;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New discussion', style: AppTextStyles.headline(fontSize: 20)),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            autofocus: true,
            style: AppTextStyles.body(fontSize: 16),
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 8),
          Text('Product', style: AppTextStyles.caption()),
          const SizedBox(height: 6),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: catalog.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  final on = _product == null;
                  return _ProductPick(
                    label: 'None',
                    selected: on,
                    onTap: () => setState(() => _product = null),
                  );
                }
                final product = catalog[index - 1];
                return _ProductPick(
                  label: product.name,
                  selected: _product?.id == product.id,
                  onTap: () => setState(() => _product = product),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              ChatMockStore.instance.startDiscussion(
                widget.chatId,
                name: _name.text,
                product: _product,
              );
              Navigator.of(context).pop(true);
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}

class _ProductPick extends StatelessWidget {
  const _ProductPick({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.surfaceSecondary : AppColors.scaffold,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 88,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.textPrimary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption(fontSize: 12),
          ),
        ),
      ),
    );
  }
}
