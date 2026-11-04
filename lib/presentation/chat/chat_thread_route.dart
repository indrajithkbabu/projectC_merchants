import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/presentation/chat/chat_mock_store.dart';
import 'package:project_c/presentation/chat/chat_models.dart';
import 'package:project_c/presentation/chat/chat_widgets/chat_pieces.dart';
import 'package:project_c/presentation/chat/chat_widgets/chat_sheets.dart';
import 'package:project_c/presentation/chat/chat_widgets/chat_timeline.dart';

class ChatThreadRoute extends StatefulWidget {
  const ChatThreadRoute({
    super.key,
    required this.chatId,
    this.openDiscussionId,
  });

  final String chatId;
  final String? openDiscussionId;

  @override
  State<ChatThreadRoute> createState() => _ChatThreadRouteState();
}

class _ChatThreadRouteState extends State<ChatThreadRoute> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  ChatQuote? _quote;
  bool _aboutCleared = false;
  String? _trackedOpen;
  int _seenCount = -1;

  @override
  void initState() {
    super.initState();
    ChatMockStore.instance.focusThread(
      widget.chatId,
      discussionId: widget.openDiscussionId,
    );
    _composer.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    _focus.dispose();
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
          _trackOpen(thread);
          _stickToEnd(thread.messages.length);
          final closed = thread.status == ChatStatus.closed;
          final subtitle =
              thread.customerTyping && !closed
                  ? 'typing…'
                  : thread.outbound
                  ? 'Store'
                  : (thread.customer.isStoreAccount
                      ? 'Store account'
                      : 'Customer');
          return Column(
            children: [
              _ThreadHeader(
                thread: thread,
                subtitle: subtitle,
                typing: thread.customerTyping && !closed,
                onDetails: () => showChatDetailsSheet(context, thread),
              ),
              ChatProductChips(
                thread: thread,
                onOpen:
                    (id) =>
                        ChatMockStore.instance.openDiscussion(thread.id, id),
              ),
              Expanded(
                child: ChatTimeline(
                  scrollController: _scroll,
                  thread: thread,
                  onReply:
                      (message) =>
                          setState(() => _quote = _quoteFor(thread, message)),
                  onCloseDiscussion: () {
                    HapticFeedback.selectionClick();
                    ChatMockStore.instance.closeDiscussion(thread.id);
                  },
                  onReopenDiscussion: () {
                    HapticFeedback.selectionClick();
                    ChatMockStore.instance.reopenDiscussion(thread.id);
                  },
                  onOpenProduct: (product) {
                    final id = thread.discussionIdForProduct(product.id);
                    if (id == null) return;
                    ChatMockStore.instance.openDiscussion(thread.id, id);
                  },
                ),
              ),
              if (closed)
                _ClosedBar(
                  onReopen: () {
                    HapticFeedback.selectionClick();
                    ChatMockStore.instance.reopenChat(thread.id);
                  },
                )
              else
                _Composer(
                  controller: _composer,
                  focusNode: _focus,
                  quickReplies:
                      thread.outbound
                          ? const <String>[]
                          : ChatMockStore.instance.quickReplies,
                  quote: _quote,
                  about: _aboutLabel(thread),
                  onClearQuote: () => setState(() => _quote = null),
                  onClearAbout: () => setState(() => _aboutCleared = true),
                  onPickReply: (phrase) {
                    _composer.text = phrase;
                    _composer.selection = TextSelection.collapsed(
                      offset: phrase.length,
                    );
                    _focus.requestFocus();
                  },
                  onShare: () => _share(thread),
                  onSend: () => _send(thread),
                ),
            ],
          );
        },
      ),
    );
  }

  void _trackOpen(ChatThread thread) {
    if (_trackedOpen == thread.openDiscussionId) return;
    _trackedOpen = thread.openDiscussionId;
    _aboutCleared = false;
    _seenCount = -1;
  }

  void _stickToEnd(int count) {
    if (count == _seenCount) return;
    final initial = _seenCount < 0;
    final grew = count > _seenCount;
    _seenCount = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (initial) {
        _scroll.jumpTo(target);
      } else if (grew) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  String? _targetDiscussion(ChatThread thread) {
    if (_aboutCleared) return null;
    final discussion = thread.discussionById(thread.openDiscussionId);
    if (discussion == null || discussion.status == DiscussionStatus.closed) {
      return null;
    }
    if (thread.status == ChatStatus.closed) return null;
    return discussion.id;
  }

  String? _aboutLabel(ChatThread thread) {
    final id = _targetDiscussion(thread);
    return thread.discussionById(id)?.product.name;
  }

  ChatQuote _quoteFor(ChatThread thread, ChatMessage message) {
    final staff = message.staffName?.trim() ?? '';
    final label =
        message.mine
            ? 'You'
            : (staff.isNotEmpty ? staff : thread.customer.name);
    return ChatQuote(
      senderLabel: label,
      text: message.previewBody(),
      product: message.products.isEmpty ? null : message.products.first,
    );
  }

  void _send(ChatThread thread) {
    final text = _composer.text;
    if (text.trim().isEmpty) return;
    ChatMockStore.instance.sendText(
      thread.id,
      text,
      discussionId: _targetDiscussion(thread),
      quote: _quote,
    );
    _composer.clear();
    setState(() => _quote = null);
  }

  Future<void> _share(ChatThread thread) async {
    final product = await showShareProductSheet(context);
    if (product == null || !mounted) return;
    ChatMockStore.instance.sendProduct(
      thread.id,
      product,
      discussionId: _targetDiscussion(thread),
    );
  }
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({
    required this.thread,
    required this.subtitle,
    required this.typing,
    required this.onDetails,
  });

  final ChatThread thread;
  final String subtitle;
  final bool typing;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        4,
        ScreenWrapper.statusBarTop(context) + 4,
        4,
        6,
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
          ChatAvatar(actor: thread.customer, size: 36),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  thread.customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(
                    fontSize: 12,
                    fontWeight: typing ? FontWeight.w600 : FontWeight.w400,
                    color: typing ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Chat details',
            onPressed: onDetails,
            icon: Icon(Icons.more_horiz_rounded, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _ClosedBar extends StatelessWidget {
  const _ClosedBar({required this.onReopen});

  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'This chat is closed',
              style: AppTextStyles.body(fontSize: 15),
            ),
          ),
          TextButton(onPressed: onReopen, child: const Text('Reopen')),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.quickReplies,
    required this.quote,
    required this.about,
    required this.onClearQuote,
    required this.onClearAbout,
    required this.onPickReply,
    required this.onShare,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> quickReplies;
  final ChatQuote? quote;
  final String? about;
  final VoidCallback onClearQuote;
  final VoidCallback onClearAbout;
  final ValueChanged<String> onPickReply;
  final VoidCallback onShare;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final canSend = controller.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (quickReplies.isNotEmpty)
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: quickReplies.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final phrase = quickReplies[index];
                  return ActionChip(
                    label: Text(
                      phrase,
                      style: AppTextStyles.caption(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    backgroundColor: AppColors.surfaceSecondary,
                    side: BorderSide(color: AppColors.border),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onPickReply(phrase),
                  );
                },
              ),
            ),
          if (quote != null) ...[
            const SizedBox(height: 6),
            _QuoteDraft(quote: quote!, onClear: onClearQuote),
          ],
          // if (about != null) ...[
          //   const SizedBox(height: 6),
          //   Align(
          //     alignment: Alignment.centerLeft,
          //     child: InputChip(
          //       label: Text(
          //         'About $about',
          //         style: AppTextStyles.caption(
          //           fontSize: 12,
          //           color: AppColors.textPrimary,
          //         ),
          //       ),
          //       onDeleted: onClearAbout,
          //       backgroundColor: AppColors.surfaceSecondary,
          //       side: BorderSide(color: AppColors.border),
          //       visualDensity: VisualDensity.compact,
          //       deleteIconColor: AppColors.textSecondary,
          //     ),
          //   ),
          // ],
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Share a product',
                onPressed: onShare,
                icon: Icon(Icons.add_rounded, color: AppColors.textPrimary),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTextStyles.body(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Message',
                    hintStyle: AppTextStyles.hint(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceSecondary,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Send',
                onPressed: canSend ? onSend : null,
                icon: Icon(
                  Icons.send_rounded,
                  color: canSend ? AppColors.primary : AppColors.textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuoteDraft extends StatelessWidget {
  const _QuoteDraft({required this.quote, required this.onClear});

  final ChatQuote quote;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: AppColors.primary, width: 2)),
      ),
      child: Row(
        children: [
          if (quote.product != null) ...[
            ChatProductThumb(product: quote.product!, size: 28, radius: 6),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote.senderLabel,
                  style: AppTextStyles.caption(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  quote.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cancel reply',
            onPressed: onClear,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
