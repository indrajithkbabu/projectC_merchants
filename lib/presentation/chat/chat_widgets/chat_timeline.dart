import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/presentation/chat/chat_models.dart';
import 'package:project_c/presentation/chat/chat_widgets/chat_pieces.dart';

class ChatTimeline extends StatelessWidget {
  const ChatTimeline({
    super.key,
    required this.thread,
    required this.onReply,
    required this.onCloseDiscussion,
    required this.onReopenDiscussion,
    required this.onOpenProduct,
    this.scrollController,
  });

  final ChatThread thread;
  final ScrollController? scrollController;
  final ValueChanged<ChatMessage> onReply;
  final VoidCallback onCloseDiscussion;
  final VoidCallback onReopenDiscussion;
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
            onClose: onCloseDiscussion,
            onReopen: onReopenDiscussion,
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
            _general(items[i].general!, _showStaff(items, i)),
        ],
        if (thread.customerTyping && thread.status == ChatStatus.open)
          const ChatTypingDots(),
      ],
    );
  }

  Widget _general(ChatMessage message, bool showStaff) {
    if (message.isStatus) return ChatStatusLine(text: message.text);
    final onRight = _onRight(message);
    return Align(
      alignment: onRight ? Alignment.centerRight : Alignment.centerLeft,
      child: ChatBubble(
        message: message,
        alignRight: onRight,
        showStaffName: showStaff,
        showAutomaticLabel: !thread.outbound,
        onReply: () => onReply(message),
        onProductTap: onOpenProduct,
      ),
    );
  }

  bool _onRight(ChatMessage message) => _messageOnRight(thread, message);

  bool _showStaff(List<_Slot> items, int index) {
    final message = items[index].general;
    if (message == null || message.mine || message.isStatus) return false;
    if (index == 0) return true;
    final previous = items[index - 1].general;
    if (previous == null || previous.discussionId != null) return true;
    return previous.staffName != message.staffName || previous.mine;
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
    required this.onClose,
    required this.onReopen,
    required this.onOpenProduct,
  });

  final ChatThread thread;
  final ProductDiscussion discussion;
  final ValueChanged<ChatMessage> onReply;
  final VoidCallback onClose;
  final VoidCallback onReopen;
  final ValueChanged<ChatProductRef> onOpenProduct;

  @override
  Widget build(BuildContext context) {
    final messages =
        thread.messages
            .where((message) => message.discussionId == discussion.id)
            .toList()
          ..sort((a, b) => a.at.compareTo(b.at));
    final chatOpen = thread.status == ChatStatus.open;
    final discussionOpen = discussion.status == DiscussionStatus.open;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: discussionOpen ? AppColors.border : AppColors.textHint,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
            child: Row(
              children: [
                ChatProductThumb(product: discussion.product, size: 40),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        discussion.product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label(fontSize: 14),
                      ),
                      Text(
                        '${discussion.product.detail} · ${discussionOpen ? 'Open' : 'Closed'}',
                        style: AppTextStyles.caption(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (chatOpen && discussionOpen)
                  TextButton(onPressed: onClose, child: const Text('Close'))
                else if (chatOpen && !discussionOpen)
                  TextButton(onPressed: onReopen, child: const Text('Reopen')),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Column(
              children: [
                for (var i = 0; i < messages.length; i++)
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
                        showStaffName: _showStaff(messages, i),
                        showAutomaticLabel: !thread.outbound,
                        onReply: () => onReply(messages[i]),
                        onProductTap: onOpenProduct,
                      ),
                    ),
              ],
            ),
          ),
          // if (chatOpen && discussionOpen)
          //   Padding(
          //     padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          //     child: Text(
          //       'Your next message goes here',
          //       style: AppTextStyles.caption(
          //         fontSize: 12,
          //         color: AppColors.textHint,
          //       ),
          //     ),
          //   ),
        ],
      ),
    );
  }

  bool _showStaff(List<ChatMessage> messages, int index) {
    final message = messages[index];
    if (message.mine || message.isStatus) return false;
    final staff = message.staffName?.trim() ?? '';
    if (staff.isEmpty) return false;
    if (index == 0) return true;
    final previous = messages[index - 1];
    if (previous.isStatus || previous.mine) return true;
    return previous.staffName != message.staffName;
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
                      ChatProductThumb(
                        product: discussion.product,
                        size: 28,
                        radius: 6,
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          discussion.product.name,
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
