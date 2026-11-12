import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/chat/chat_mock_store.dart';
import 'package:project_c/presentation/chat/chat_models.dart';
import 'package:project_c/presentation/chat/chat_profile_route.dart';
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
  ChatMessage? _menuMessage;
  double _keyboardInset = 0;
  double _wallpaperWidth = 0;
  double _wallpaperHeight = 0;

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
      resizeToAvoidBottomInset: false,
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
          final discussionClosed =
              discussion?.status == DiscussionStatus.closed;
          final typing = thread.customerTyping && !closed ? 'typing…' : null;
          final menuMessage = _menuMessage;
          final media = MediaQuery.of(context);
          final reportedInset = media.viewInsets.bottom;
          if (media.size.width != _wallpaperWidth) {
            _wallpaperWidth = media.size.width;
            _wallpaperHeight = media.size.height;
          } else if (reportedInset == 0 &&
              media.size.height > _wallpaperHeight) {
            _wallpaperHeight = media.size.height;
          }
          final windowShrink = (_wallpaperHeight - media.size.height).clamp(
            0.0,
            double.infinity,
          );
          final keyboard = (reportedInset - windowShrink).clamp(
            0.0,
            double.infinity,
          );
          if (_keyboardInset != reportedInset) {
            _keyboardInset = reportedInset;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || !_scroll.hasClients) return;
              _scroll.jumpTo(_scroll.position.maxScrollExtent);
            });
          }
          return Stack(
            children: [
              Column(
                children: [
                  _ThreadHeader(
                    thread: thread,
                    title: thread.customer.name,
                    typing: typing,
                    onProfile: () => openChatProfile(context, thread),
                    onNew: closed ? null : () => _startDiscussion(thread),
                  ),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: _wallpaperHeight,
                          child: Image(
                            image: const AssetImage('assets/images/chat_bg.png'),
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            gaplessPlayback: true,
                            height: _wallpaperHeight,
                            width: media.size.width,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(bottom: keyboard),
                          child: Column(
                          children: [
                            Expanded(
                              child: ChatTimeline(
                                scrollController: _scroll,
                                thread: thread,
                                onReply:
                                    (message) =>
                                        _reply(thread, message, team: false),
                                onMessageMenu: (message) => _openMenu(message),
                                onOpenProduct:
                                    (product) => _openPinned(thread, product),
                              ),
                            ),
                            if (closed || thread.blocked)
                              _ClosedBar(
                                label:
                                    thread.blocked
                                        ? 'You blocked this chat'
                                        : 'This chat is closed',
                                action: thread.blocked ? 'Unblock' : 'Reopen',
                                onReopen: () {
                                  HapticFeedback.selectionClick();
                                  if (thread.blocked) {
                                    ChatMockStore.instance.setBlocked(
                                      thread.id,
                                      false,
                                    );
                                  } else {
                                    ChatMockStore.instance.reopenChat(
                                      thread.id,
                                    );
                                  }
                                },
                              )
                            else if (discussionClosed)
                              _ClosedBar(
                                label: 'This discussion is closed',
                                action: 'Reopen',
                                onReopen: () {
                                  HapticFeedback.selectionClick();
                                  ChatMockStore.instance.reopenDiscussion(
                                    thread.id,
                                  );
                                },
                              )
                            else
                              _Composer(
                                controller: _composer,
                                focusNode: _focus,
                                quote: _quote,
                                teamNote: _teamNote,
                                onClearQuote:
                                    () => setState(() => _quote = null),
                                onToggleTeam:
                                    () =>
                                        setState(() => _teamNote = !_teamNote),
                                onSend: () => _send(thread),
                                onAttach: () => _attach(thread),
                              ),
                          ],
                        ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (menuMessage != null)
                Positioned.fill(
                  child: _MessageMenu(
                    message: menuMessage,
                    onDismiss: () => setState(() => _menuMessage = null),
                    onReply: () {
                      setState(() => _menuMessage = null);
                      _reply(thread, menuMessage, team: false);
                    },
                    onTeam: () {
                      setState(() => _menuMessage = null);
                      _reply(thread, menuMessage, team: true);
                    },
                    onCopy: () async {
                      await Clipboard.setData(
                        ClipboardData(text: menuMessage.previewBody()),
                      );
                      if (!mounted) return;
                      setState(() => _menuMessage = null);
                    },
                    onStar: () {
                      ChatMockStore.instance.toggleStar(
                        thread.id,
                        menuMessage.id,
                      );
                    },
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

  void _openMenu(ChatMessage message) {
    HapticFeedback.mediumImpact();
    setState(() => _menuMessage = message);
  }

  void _startDiscussion(ChatThread thread) {
    ChatMockStore.instance.startDiscussion(thread.id);
  }

  Future<void> _attach(ChatThread thread) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.grid_view_rounded),
                title: const Text('Catalogue'),
                onTap: () => Navigator.pop(context, 'product'),
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Photo'),
                onTap: () => Navigator.pop(context, 'photo'),
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: const Text('File'),
                onTap: () => Navigator.pop(context, 'file'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || choice == null) return;
    final discussionId = _targetDiscussion(thread);
    if (choice == 'product') {
      final product = await showShareProductSheet(context);
      if (product == null) return;
      ChatMockStore.instance.sendProduct(
        thread.id,
        product,
        discussionId: discussionId,
      );
      return;
    }
    if (choice == 'photo') {
      try {
        final file = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (file != null) {
          ChatMockStore.instance.sendPhoto(
            thread.id,
            discussionId: discussionId,
            mediaPath: file.path,
          );
          return;
        }
      } catch (_) {
        if (!mounted) return;
        ChatMockStore.instance.sendPhoto(
          thread.id,
          discussionId: discussionId,
          caption: 'Photo',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gallery is unavailable. Added a sample photo.'),
          ),
        );
      }
      return;
    }
    final name = await _askFileName();
    if (name == null || name.trim().isEmpty) return;
    ChatMockStore.instance.sendFile(
      thread.id,
      discussionId: discussionId,
      name: name,
    );
  }

  Future<String?> _askFileName() {
    final controller = TextEditingController(text: 'Rate card.pdf');
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('File'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
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
    required this.onProfile,
    this.typing,
    this.onNew,
  });

  final ChatThread thread;
  final String title;
  final String? typing;
  final VoidCallback onProfile;
  final VoidCallback? onNew;

  @override
  Widget build(BuildContext context) {
    final line = typing?.trim() ?? '';
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
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              2,
              ScreenWrapper.statusBarTop(context) + 2,
              4,
              line.isEmpty ? 4 : 0,
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
                        Row(
                          children: [
                            Flexible(
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
                            if (thread.muted) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.notifications_off_outlined,
                                size: 15,
                                color: chatMuted,
                              ),
                            ],
                          ],
                        ),
                        if (line.isNotEmpty)
                          Text(
                            line,
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
                if (onNew != null)
                  IconButton(
                    tooltip: 'New discussion',
                    onPressed: onNew,
                    icon: Icon(Icons.add_rounded, size: 22, color: chatInk),
                  ),
              ],
            ),
          ),
          ChatDiscussionBar(
            thread: thread,
            onOpen:
                (id) => ChatMockStore.instance.openDiscussion(thread.id, id),
            onAll: () {
              Navigator.of(context).pushNamed(
                Routes.chatDiscussionsRoute,
                arguments: <String, String>{'chatId': thread.id},
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ClosedBar extends StatelessWidget {
  const _ClosedBar({
    required this.onReopen,
    this.label = 'This chat is closed',
    this.action = 'Reopen',
  });

  final VoidCallback onReopen;
  final String label;
  final String action;

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
          Expanded(child: Text(label, style: AppTextStyles.body(fontSize: 15))),
          TextButton(onPressed: onReopen, child: Text(action)),
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
    required this.onClearQuote,
    required this.onToggleTeam,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ChatQuote? quote;
  final bool teamNote;
  final VoidCallback onClearQuote;
  final VoidCallback onToggleTeam;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final canSend = controller.text.trim().isNotEmpty;
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(6, 6, 6, 6 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (teamNote)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Center(
                child: Text(
                  'Only your team sees this',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: chatTeamNote,
                  ),
                ),
              ),
            ),
          if (quote != null) ...[
            const SizedBox(height: 6),
            _QuoteDraft(quote: quote!, onClear: onClearQuote),
          ],
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _RoundIcon(
                  tooltip: 'Attach',
                  onTap: onAttach,
                  color: Colors.transparent,
                  icon: Icons.attach_file_rounded,
                  iconColor: chatInk,
                ),
              ),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: chatField,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(2, 2, 2, 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4, left: 2),
                          child: _RoundIcon(
                            tooltip:
                                teamNote ? 'Team note on' : 'Note to your team',
                            onTap: onToggleTeam,
                            color: Colors.transparent,
                            icon: Icons.lock_rounded,
                            iconColor: teamNote ? chatTeamNote : chatMuted,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            cursorColor: chatInk,
                            focusNode: focusNode,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            style: AppTextStyles.body(
                              fontSize: 16,
                              color: chatInk,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Message',
                              hintStyle: AppTextStyles.hint(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Colors.grey,
                              ),
                              filled: false,
                              isDense: true,
                              contentPadding: const EdgeInsets.fromLTRB(
                                4,
                                10,
                                8,
                                10,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4, right: 2),
                          child: _RoundIcon(
                            tooltip: 'Send',
                            onTap: canSend ? onSend : null,
                            color: Colors.transparent,
                            icon: Icons.send_rounded,
                            iconColor: canSend ? chatSend : chatMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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

class _MessageMenu extends StatelessWidget {
  const _MessageMenu({
    required this.message,
    required this.onDismiss,
    required this.onReply,
    required this.onTeam,
    required this.onCopy,
    required this.onStar,
  });

  final ChatMessage message;
  final VoidCallback onDismiss;
  final VoidCallback onReply;
  final VoidCallback onTeam;
  final VoidCallback onCopy;
  final VoidCallback onStar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.28),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IgnorePointer(
                  child: ChatBubble(
                    message: message,
                    alignRight: message.mine,
                    onReply: () {},
                  ),
                ),
                const SizedBox(height: 12),
                Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MenuAction(label: 'Reply', onTap: onReply),
                        _MenuAction(
                          label: 'Reply to team',
                          color: chatTeamNote,
                          icon: Icons.lock_outline_rounded,
                          onTap: onTeam,
                        ),
                        _MenuAction(label: 'Copy', onTap: onCopy),
                        _MenuAction(
                          label: message.starred ? 'Unstar' : 'Star',
                          onTap: onStar,
                        ),
                      ],
                    ),
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

class _MenuAction extends StatelessWidget {
  const _MenuAction({
    required this.label,
    required this.onTap,
    this.color,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: ink),
              const SizedBox(width: 8),
            ],
            Text(label, style: AppTextStyles.body(fontSize: 16, color: ink)),
          ],
        ),
      ),
    );
  }
}
