import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
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
  bool _teamNote = false;
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
      backgroundColor: chatWallpaper,
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
          final discussion = thread.discussionById(thread.openDiscussionId);
          final discussionTitle = discussion?.title.trim() ?? '';
          final title =
              discussionTitle.isNotEmpty
                  ? discussionTitle
                  : thread.customer.name;
          final people = thread.peopleCount;
          final subtitle =
              thread.customerTyping && !closed
                  ? 'typing…'
                  : thread.muted
                  ? 'Muted · ${thread.customer.name} · $people people'
                  : '${thread.customer.name} · $people people';
          return Column(
            children: [
              _ThreadHeader(
                thread: thread,
                title: title,
                subtitle: subtitle,
                onProfile: () => showChatProfileSheet(context, thread),
                onTitle:
                    discussion?.product == null
                        ? null
                        : () => _openPinned(thread, discussion!.product!),
              ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/chat_bg.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                    Column(
                      children: [
                        Expanded(
                          child: ChatTimeline(
                            scrollController: _scroll,
                            thread: thread,
                            onReply:
                                (message) =>
                                    _reply(thread, message, team: false),
                            onMessageMenu: (message) => _menu(thread, message),
                            onOpenProduct:
                                (product) => _openPinned(thread, product),
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
                            quote: _quote,
                            teamNote: _teamNote,
                            storeName: ChatMockStore.instance.storeName,
                            onClearQuote: () => setState(() => _quote = null),
                            onToggleTeam:
                                () => setState(() => _teamNote = !_teamNote),
                            onSend: () => _send(thread),
                          ),
                      ],
                    ),
                  ],
                ),
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

  void _reply(ChatThread thread, ChatMessage message, {required bool team}) {
    setState(() {
      _quote = _quoteFor(thread, message);
      if (team) _teamNote = true;
    });
    _focus.requestFocus();
  }

  Future<void> _menu(ChatThread thread, ChatMessage message) async {
    HapticFeedback.mediumImpact();
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Reply'),
                onTap: () => Navigator.pop(context, 'reply'),
              ),
              ListTile(
                title: Text(
                  'Reply to team',
                  style: AppTextStyles.body(color: chatTeamNote),
                ),
                leading: Icon(Icons.lock_outline_rounded, color: chatTeamNote),
                onTap: () => Navigator.pop(context, 'team'),
              ),
              ListTile(
                title: const Text('Copy'),
                onTap: () => Navigator.pop(context, 'copy'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.previewBody()));
      return;
    }
    _reply(thread, message, team: action == 'team');
  }

  void _openPinned(ChatThread thread, ChatProductRef product) {
    StoreProfileBloc? bloc;
    try {
      bloc = context.read<StoreProfileBloc>();
    } catch (_) {
      bloc = null;
    }
    StoreProduct? match;
    if (bloc != null) {
      for (final item in bloc.state.productsForMedia) {
        if (item.id == product.id) {
          match = item;
          break;
        }
      }
    }
    if (match == null) return;
    Navigator.of(context).pushNamed(
      Routes.productDetailsRoute,
      arguments: <String, Object?>{
        'product': match,
        'storeName': thread.customer.name,
        'isOwnStore': !thread.outbound,
      },
    );
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
      teamOnly: _teamNote,
    );
    _composer.clear();
    setState(() => _quote = null);
  }
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({
    required this.thread,
    required this.title,
    required this.subtitle,
    required this.onProfile,
    this.onTitle,
  });

  final ChatThread thread;
  final String title;
  final String subtitle;
  final VoidCallback onProfile;
  final VoidCallback? onTitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: chatBar,
        border: Border(
          bottom: BorderSide(
            color:
                AppColors.isNight
                    ? const Color(0xFF222D34)
                    : const Color(0xFFE4E4E4),
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          2,
          ScreenWrapper.statusBarTop(context) + 2,
          12,
          8,
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: chatInk,
              ),
            ),
            GestureDetector(
              onTap: onProfile,
              child: ChatAvatar(
                actor: thread.customer,
                size: 34,
                group: thread.kind == ChatKind.group,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: onProfile,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: onTitle ?? onProfile,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: chatInk,
                        ),
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: chatMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (thread.muted)
              Icon(
                Icons.notifications_off_outlined,
                size: 16,
                color: chatMuted,
              ),
          ],
        ),
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
    required this.quote,
    required this.teamNote,
    required this.storeName,
    required this.onClearQuote,
    required this.onToggleTeam,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ChatQuote? quote;
  final bool teamNote;
  final String storeName;
  final VoidCallback onClearQuote;
  final VoidCallback onToggleTeam;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final canSend = controller.text.trim().isNotEmpty;
    final sendColor = teamNote ? chatTeamNote : chatSend;
    final sendIcon = teamNote ? const Color(0xFF1A1408) : Colors.white;
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(6, 6, 6, 6 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (teamNote)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_rounded, size: 14, color: chatTeamNote),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Only $storeName will see this',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: chatTeamNote,
                      ),
                    ),
                  ),
                ],
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
          const SizedBox(height: 4),
          DecoratedBox(
            decoration: BoxDecoration(
              color: chatField,
              borderRadius: BorderRadius.circular(24),
              border:
                  teamNote ? Border.all(color: chatTeamNote, width: 1.4) : null,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 2, 4, 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 2),
                    child: _RoundIcon(
                      tooltip: teamNote ? 'Team note on' : 'Note to your team',
                      onTap: onToggleTeam,
                      color: teamNote ? chatTeamNote : Colors.transparent,
                      icon: Icons.lock_rounded,
                      iconColor: teamNote ? const Color(0xFF1A1408) : chatMuted,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      cursorColor: Colors.white,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      style: AppTextStyles.body(fontSize: 16, color: chatInk),
                      decoration: InputDecoration(
                        hintText: teamNote ? 'Note to your team' : 'Message',
                        hintStyle: AppTextStyles.hint(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey,
                        ),
                        filled: false,
                        isDense: true,
                        contentPadding: const EdgeInsets.fromLTRB(4, 10, 8, 10),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, right: 2),
                    child: Material(
                      color: canSend ? sendColor : Colors.transparent,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: canSend ? onSend : null,
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(
                            Icons.send_rounded,
                            color: canSend ? sendIcon : chatMuted,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.tooltip,
    required this.onTap,
    required this.color,
    required this.icon,
    required this.iconColor,
  });

  final String tooltip;
  final VoidCallback? onTap;
  final Color color;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 18, color: iconColor),
          ),
        ),
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
