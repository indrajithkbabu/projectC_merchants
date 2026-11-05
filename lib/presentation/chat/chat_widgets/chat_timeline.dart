import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
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
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i == 0 || !chatSameDay(items[i - 1].at, items[i].at))
            ChatDayChip(label: chatDayLabel(items[i].at)),
          if (items[i].general != null)
            _general(items[i].general!),
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
  if (thread.outbound) return false;
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
                alignRight: _messageOnRight(thread, messages[i]),
                senderLabel: _senderLabel(messages, i),
                onReply: () => onReply(messages[i]),
                onLongPress:
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

  String? _senderLabel(List<ChatMessage> messages, int index) {
    if (thread.kind != ChatKind.group) return null;
    final message = messages[index];
    if (message.mine || message.isStatus) return null;
    final label = _labelFor(message);
    if (label == null || label.isEmpty) return null;
    return label;
  }

  String? _labelFor(ChatMessage message) {
    if (thread.kind != ChatKind.group || message.mine) return null;
    final staff = message.staffName?.trim() ?? '';
    final person = staff.isEmpty ? thread.customer.name : staff;
    final store = _storeFor(person);
    final ours = ChatMockStore.instance.storeName.trim();
    if (store.isNotEmpty && store != ours) return '$person · $store';
    if (person.trim().isEmpty) return null;
    return person;
  }

  String _storeFor(String name) {
    for (final member in thread.members) {
      if (member.name == name && member.storeName.trim().isNotEmpty) {
        return member.storeName.trim();
      }
    }
    return '';
  }
}

class ChatProductChips extends StatelessWidget {
  const ChatProductChips({
    super.key,
    required this.thread,
    required this.onOpen,
  });

  final ChatThread thread;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    if (thread.discussions.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        itemCount: thread.discussions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final discussion = thread.discussions[index];
          final selected = thread.openDiscussionId == discussion.id;
          final closed = discussion.status == DiscussionStatus.closed;
          final unread = thread.unreadInDiscussion(discussion.id);
          return Opacity(
            opacity: closed ? 0.5 : 1,
            child: Material(
              color: selected ? AppColors.surface : AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => onOpen(discussion.id),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          selected ? AppColors.textPrimary : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (discussion.product != null)
                        ChatProductThumb(
                          product: discussion.product!,
                          size: 28,
                          radius: 6,
                        )
                      else
                        Icon(
                          Icons.sticky_note_2_outlined,
                          size: 22,
                          color: AppColors.textSecondary,
                        ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          discussion.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (unread > 0) ...[
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
    );
  }
}
