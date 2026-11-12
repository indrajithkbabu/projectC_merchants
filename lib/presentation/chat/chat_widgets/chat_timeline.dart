import 'package:flutter/material.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/presentation/chat/chat_mock_store.dart';
import 'package:project_c/presentation/chat/chat_models.dart';
import 'package:project_c/presentation/chat/chat_widgets/chat_pieces.dart';

class ChatTimeline extends StatelessWidget {
  const ChatTimeline({
    super.key,
    required this.thread,
    required this.onReply,
    required this.onOpenProduct,
    this.onMessageMenu,
    this.scrollController,
  });

  final ChatThread thread;
  final ScrollController? scrollController;
  final ValueChanged<ChatMessage> onReply;
  final ValueChanged<ChatMessage>? onMessageMenu;
  final ValueChanged<ChatProductRef> onOpenProduct;

  @override
  Widget build(BuildContext context) {
    final selected =
        thread.discussionById(thread.openDiscussionId) ??
        (thread.discussions.isEmpty ? null : thread.discussions.first);
    if (selected != null) {
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        children: [
          _OpenDiscussion(
            thread: thread,
            discussion: selected,
            onReply: onReply,
            onMessageMenu: onMessageMenu,
            onOpenProduct: onOpenProduct,
          ),
          if (thread.customerTyping && thread.status == ChatStatus.open)
            const ChatTypingDots(),
        ],
      );
    }

    final items = _slots(thread);
    if (items.isEmpty && !thread.customerTyping) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No messages yet.\nSay hello to ${thread.customer.name}.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary(),
          ),
        ),
      );
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i == 0 || !chatSameDay(items[i - 1].at, items[i].at))
            ChatDayChip(label: chatDayLabel(items[i].at)),
          if (items[i].general != null) _general(items[i].general!),
        ],
        if (thread.customerTyping && thread.status == ChatStatus.open)
          const ChatTypingDots(),
      ],
    );
  }

  Widget _general(ChatMessage message) {
    if (message.isStatus) return ChatStatusLine(text: message.text);
    final onRight = _onRight(message);
    return Align(
      alignment: onRight ? Alignment.centerRight : Alignment.centerLeft,
      child: ChatBubble(
        message: message,
        alignRight: onRight,
        senderLabel: _groupLabel(message),
        onReply: () => onReply(message),
        onLongPress:
            onMessageMenu == null ? null : () => onMessageMenu!(message),
        onSecondaryTap:
            onMessageMenu == null ? null : () => onMessageMenu!(message),
        onProductTap: onOpenProduct,
      ),
    );
  }

  bool _onRight(ChatMessage message) => _messageOnRight(thread, message);

  String? _groupLabel(ChatMessage message) {
    if (thread.kind != ChatKind.group || message.mine) return null;
    final staff = message.staffName?.trim() ?? '';
    if (staff.isEmpty) return null;
    return staff;
  }
}

class _Slot {
  _Slot.general(this.general) : at = general!.at;

  final ChatMessage? general;
  final DateTime at;
}

bool _messageOnRight(ChatThread thread, ChatMessage message) {
  if (message.mine) return true;
  final ours = ChatMockStore.instance.storeName.trim();
  final writer = message.writerStore.trim();
  if (writer.isNotEmpty) return writer == ours || writer == 'My store';
  final staff = message.staffName?.trim() ?? '';
  if (staff.isNotEmpty) {
    for (final member in thread.members) {
      if (member.name == staff) return chatMemberOnViewerStore(member, ours);
    }
  }
  if (thread.outbound || thread.kind == ChatKind.group) return false;
  return message.side == ChatSenderSide.merchant;
}

List<_Slot> _slots(ChatThread thread) {
  final slots = <_Slot>[
    for (final message in thread.messages)
      if (message.discussionId == null &&
          message.kind != ChatMessageKind.basket)
        _Slot.general(message),
  ];
  slots.sort((a, b) => a.at.compareTo(b.at));
  return slots;
}

class _OpenDiscussion extends StatelessWidget {
  const _OpenDiscussion({
    required this.thread,
    required this.discussion,
    required this.onReply,
    required this.onOpenProduct,
    this.onMessageMenu,
  });

  final ChatThread thread;
  final ProductDiscussion discussion;
  final ValueChanged<ChatMessage> onReply;
  final ValueChanged<ChatMessage>? onMessageMenu;
  final ValueChanged<ChatProductRef> onOpenProduct;

  @override
  Widget build(BuildContext context) {
    final viewer = ChatMockStore.instance.storeName;
    final messages =
        thread.messages
            .where(
              (message) =>
                  message.discussionId == discussion.id &&
                  chatMessageVisible(message, viewer),
            )
            .toList()
          ..sort((a, b) => a.at.compareTo(b.at));
    return Column(
      children: [
        if (discussion.product != null)
          _DiscussionProduct(
            product: discussion.product!,
            onTap: () => onOpenProduct(discussion.product!),
          ),
        for (var i = 0; i < messages.length; i++) ...[
          if (i == 0 || !chatSameDay(messages[i - 1].at, messages[i].at))
            ChatDayChip(label: chatDayLabel(messages[i].at)),
          if (messages[i].isStatus)
            ChatStatusLine(text: messages[i].text)
          else
            Align(
              alignment:
                  _messageOnRight(thread, messages[i])
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
              child: ChatBubble(
                message: messages[i],
                alignRight: _ownStore(messages[i]),
                senderLabel: _senderName(messages, i),
                senderStore: _senderStore(messages, i),
                onReply: () => onReply(messages[i]),
                onLongPress:
                    onMessageMenu == null
                        ? null
                        : () => onMessageMenu!(messages[i]),
                onSecondaryTap:
                    onMessageMenu == null
                        ? null
                        : () => onMessageMenu!(messages[i]),
                onProductTap: onOpenProduct,
              ),
            ),
        ],
      ],
    );
  }

  bool _ownStore(ChatMessage message) => _messageOnRight(thread, message);

  String? _senderName(List<ChatMessage> messages, int index) {
    final message = messages[index];
    if (message.isStatus) return null;
    final name = _nameFor(message);
    if (name == null) return null;
    if (index > 0 && _sameSender(messages[index - 1], message)) return null;
    return name;
  }

  String? _senderStore(List<ChatMessage> messages, int index) {
    if (_senderName(messages, index) == null) return null;
    final message = messages[index];
    final store = _storeFor(message);
    final ours = ChatMockStore.instance.storeName.trim();
    if (store.isEmpty) return null;
    if (store == ours || store == 'My store') return null;
    return store;
  }

  String? _nameFor(ChatMessage message) {
    final self = ChatMockStore.instance.staffName.trim();
    final staff = message.staffName?.trim() ?? '';
    if (message.mine && (staff.isEmpty || staff == self)) return null;
    if (message.mine) return staff;
    if (staff.isNotEmpty) return staff;
    if (thread.kind == ChatKind.person) return null;
    final name = thread.customer.name.trim();
    return name.isEmpty ? null : name;
  }

  bool _sameSender(ChatMessage previous, ChatMessage message) {
    if (previous.isStatus || message.isStatus) return false;
    if (previous.mine != message.mine) return false;
    return (previous.staffName?.trim() ?? '') ==
        (message.staffName?.trim() ?? '');
  }

  String _storeFor(ChatMessage message) {
    final staff = message.staffName?.trim() ?? '';
    if (staff.isEmpty) {
      if (thread.kind == ChatKind.store || thread.customer.isStoreAccount) {
        return thread.customer.name.trim();
      }
      return '';
    }
    for (final member in thread.members) {
      if (member.name == staff && member.storeName.trim().isNotEmpty) {
        return member.storeName.trim();
      }
    }
    return '';
  }
}

class _DiscussionProduct extends StatelessWidget {
  const _DiscussionProduct({required this.product, required this.onTap});

  final ChatProductRef product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Material(
        color: chatField,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ChatProductThumb(product: product, size: 52, radius: 8),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: chatInk,
                        ),
                      ),
                      if (product.detail.trim().isNotEmpty)
                        Text(
                          product.detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption(
                            fontSize: 12,
                            color: chatMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChatDiscussionBar extends StatefulWidget {
  const ChatDiscussionBar({
    super.key,
    required this.thread,
    required this.onOpen,
    required this.onAll,
  });

  final ChatThread thread;
  final ValueChanged<String> onOpen;
  final VoidCallback onAll;

  @override
  State<ChatDiscussionBar> createState() => _ChatDiscussionBarState();
}

class _ChatDiscussionBarState extends State<ChatDiscussionBar> {
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _keys = {};
  String? _revealed;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.thread.discussionsByOrder(open: true);
    if (open.length < 2) return const SizedBox.shrink();
    final selected = widget.thread.openDiscussionId;
    if (_revealed != selected) {
      _revealed = selected;
      _reveal(selected);
    }
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(8, 0, 4, 8),
              itemCount: open.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final discussion = open[index];
                final on = selected == discussion.id;
                final unread = widget.thread.unreadInDiscussion(discussion.id);
                final key = _keys.putIfAbsent(discussion.id, GlobalKey.new);
                return KeyedSubtree(
                  key: key,
                  child: Material(
                    color: on ? chatField : chatMuted.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: () => widget.onOpen(discussion.id),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                on
                                    ? chatField
                                    : chatMuted.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (discussion.product != null)
                              ChatProductThumb(
                                product: discussion.product!,
                                size: 26,
                                radius: 13,
                              )
                            else
                              Icon(
                                Icons.sticky_note_2_outlined,
                                size: 18,
                                color: chatMuted,
                              ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: Text(
                                discussion.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: chatInk,
                                ),
                              ),
                            ),
                            if (discussion.mentionUnread && unread == 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                '@',
                                style: AppTextStyles.caption(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: chatReadTick,
                                ),
                              ),
                            ] else if (unread > 0) ...[
                              const SizedBox(width: 6),
                              ChatUnreadBadge(count: unread),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            tooltip: 'All discussions',
            onPressed: widget.onAll,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.chevron_right_rounded, size: 22, color: chatMuted),
          ),
        ],
      ),
    );
  }

  void _reveal(String? id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = id == null ? null : _keys[id]?.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }
}
