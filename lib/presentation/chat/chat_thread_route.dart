import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:project_c/bloc/chat_inbox/chat_inbox_bloc.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/catalog/chat_api_models.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/chat/chat_mock_store.dart';
import 'package:project_c/presentation/chat/chat_models.dart';
import 'package:project_c/presentation/chat/chat_profile_route.dart';
import 'package:project_c/presentation/chat/chat_widgets/chat_pieces.dart';
import 'package:project_c/presentation/chat/chat_widgets/chat_sheets.dart';
import 'package:project_c/presentation/chat/chat_widgets/chat_timeline.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/chat/chat_repository.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';

class ChatThreadRoute extends StatefulWidget {
  const ChatThreadRoute({
    super.key,
    required this.chatId,
    this.openDiscussionId,
    this.fromApi = false,
    this.title = '',
    this.isStore = false,
    this.productId = '',
    this.productImageUrl = '',
  });

  final String chatId;
  final String? openDiscussionId;

  /// Relationship loaded from the catalog chat API. Uses this same screen.
  final bool fromApi;
  final String title;
  final bool isStore;

  /// Photo the reply was sent about. The chat snapshot does not include it.
  final String productId;
  final String productImageUrl;

  @override
  State<ChatThreadRoute> createState() => _ChatThreadRouteState();
}

class _ChatThreadRouteState extends State<ChatThreadRoute> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  ChatQuote? _quote;
  String? _quoteMessageId;
  bool _sending = false;
  bool _pulling = false;
  Timer? _live;
  String? _lastReadId;
  bool _teamNote = false;
  bool _aboutCleared = false;
  String? _trackedOpen;
  int _seenCount = -1;
  ChatMessage? _menuMessage;
  bool _attachOpen = false;
  double _keyboardInset = 0;
  double _wallpaperWidth = 0;
  double _wallpaperHeight = 0;

  @override
  void initState() {
    super.initState();
    if (widget.fromApi) {
      ChatMockStore.instance.ensureRemoteThread(
        id: widget.chatId,
        title: widget.title,
        isStore: widget.isStore,
      );
      _loadRemote();
    }
    ChatMockStore.instance.focusThread(
      widget.chatId,
      discussionId: widget.openDiscussionId,
    );
    _composer.addListener(() {
      if (mounted) setState(() {});
    });
    _focus.addListener(_onComposerFocus);
  }

  void _onComposerFocus() {
    if (!mounted || !_attachOpen || !_focus.hasFocus) return;
    setState(() => _attachOpen = false);
  }

  @override
  void dispose() {
    _live?.cancel();
    _focus.removeListener(_onComposerFocus);
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
          return PopScope(
            canPop: menuMessage == null,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && menuMessage != null) {
                setState(() => _menuMessage = null);
              }
            },
            child: Column(
              children: [
                _ThreadHeader(
                  thread: thread,
                  title: thread.customer.name,
                  typing: typing,
                  onProfile: () => openChatProfile(context, thread),
                  onNew: closed ? null : () => _startDiscussion(thread),
                ),
                if (menuMessage != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: _MessageMenu(
                      message: menuMessage,
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
                        setState(() => _menuMessage = null);
                      },
                    ),
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
                                selectedMessageId: menuMessage?.id,
                                onClearSelection:
                                    menuMessage == null
                                        ? null
                                        : () =>
                                            setState(() => _menuMessage = null),
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
                                attachOpen: _attachOpen,
                                onClearQuote:
                                    () => setState(() => _quote = null),
                                onToggleTeam:
                                    () =>
                                        setState(() => _teamNote = !_teamNote),
                                onSend: () => _send(thread),
                                onAttach: _toggleAttach,
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.topCenter,
                                child: _attachOpen
                                    ? _AttachTray(
                                        onPick: (choice) =>
                                            _pickAttach(thread, choice),
                                        onSendPhotos: (paths) =>
                                            _sendGalleryPhotos(thread, paths),
                                      )
                                    : const SizedBox(width: double.infinity),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
      _quoteMessageId = message.id;
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

  void _toggleAttach() {
    HapticFeedback.selectionClick();
    final next = !_attachOpen;
    if (next) _focus.unfocus();
    setState(() => _attachOpen = next);
  }

  Future<void> _pickAttach(ChatThread thread, String choice) async {
    setState(() => _attachOpen = false);
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
    if (choice == 'photo' || choice == 'camera') {
      try {
        final file = await ImagePicker().pickImage(
          source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        );
        if (file == null || !mounted) return;
        if (thread.remote && !_teamNote) {
          await _sendRemotePhoto(thread, file.path, discussionId: discussionId);
          return;
        }
        ChatMockStore.instance.sendPhoto(
          thread.id,
          discussionId: discussionId,
          mediaPath: file.path,
          teamOnly: _teamNote,
        );
      } catch (_) {
        if (!mounted) return;
        if (thread.remote) {
          final where = choice == 'camera' ? 'Camera' : 'Gallery';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$where is unavailable.')),
          );
          return;
        }
        ChatMockStore.instance.sendPhoto(
          thread.id,
          discussionId: discussionId,
          caption: 'Photo',
          teamOnly: _teamNote,
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

  Future<void> _sendGalleryPhotos(ChatThread thread, List<String> paths) async {
    setState(() => _attachOpen = false);
    final discussionId = _targetDiscussion(thread);
    if (thread.remote &&
        !_teamNote &&
        (discussionId == null || !_catalogId(discussionId))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Send a message to start this discussion.'),
        ),
      );
      return;
    }
    for (final path in paths) {
      if (!mounted) return;
      if (thread.remote && !_teamNote) {
        await _sendRemotePhoto(thread, path, discussionId: discussionId);
      } else {
        ChatMockStore.instance.sendPhoto(
          thread.id,
          discussionId: discussionId,
          mediaPath: path,
          teamOnly: _teamNote,
        );
      }
    }
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
    final isPhoto = message.kind == ChatMessageKind.photo;
    final caption = message.text.trim();
    return ChatQuote(
      senderLabel: label,
      text: isPhoto && caption.isEmpty ? '' : message.previewBody(),
      product: message.products.isEmpty ? null : message.products.first,
      mediaPath: isPhoto ? message.mediaPath : '',
      remotePhotoId: isPhoto ? message.remotePhotoId : '',
    );
  }

  void _send(ChatThread thread) {
    final text = _composer.text;
    if (text.trim().isEmpty || _sending) return;
    if (thread.remote && !_teamNote) {
      final body = text.trim();
      final discussionId = _targetDiscussion(thread);
      final quote = _quote;
      final replyToId = _quoteMessageId;
      _composer.clear();
      setState(() {
        _quote = null;
        _quoteMessageId = null;
      });
      if (discussionId == null || !_catalogId(discussionId)) {
        final draft =
            discussionId == null ? null : thread.discussionById(discussionId);
        _sendFirstRemote(
          thread,
          body,
          quote: quote,
          title: draft?.name,
          draftId: discussionId,
        );
        return;
      }
      _sendRemote(
        thread,
        body,
        discussionId: discussionId,
        quote: quote,
        replyToId: replyToId,
      );
      return;
    }
    ChatMockStore.instance.sendText(
      thread.id,
      text,
      discussionId: _targetDiscussion(thread),
      quote: _quote,
      teamOnly: _teamNote,
    );
    _composer.clear();
    setState(() {
      _quote = null;
      _quoteMessageId = null;
    });
  }

  Future<void> _loadRemote() async {
    final repository = ServiceLocator.get<ChatRepository>();
    try {
      final page = await repository.listDiscussions(
        relationshipId: widget.chatId,
        limit: 50,
      );
      if (!mounted) return;
      final discussions = <ProductDiscussion>[];
      final messages = <ChatMessage>[];
      final readTargets = <(String, String)>[];
      for (final item in page.items) {
        discussions.add(
          ProductDiscussion(
            id: item.id,
            name: item.title,
            status:
                item.isClosed ? DiscussionStatus.closed : DiscussionStatus.open,
            product: _productPin(item),
          ),
        );
        final history = await repository.listMessages(
          discussionId: item.id,
          limit: 50,
        );
        if (!mounted) return;
        final replyPhotos = _replyPhotoIds(history.items);
        messages.addAll(
          history.items.map(
            (message) => _apiMessage(
              message,
              item.id,
              replyPhotos: replyPhotos,
            ),
          ),
        );
        final newestOther = _newestOtherMessage(history.items);
        if (newestOther != null) readTargets.add((item.id, newestOther));
      }
      final images = await _productImages(page.items);
      for (var i = 0; i < discussions.length; i++) {
        final snap = i < page.items.length ? page.items[i].product : null;
        final current = discussions[i].product;
        if (current == null || snap == null) continue;
        final url = images[snap.id] ?? '';
        if (url.isEmpty) continue;
        discussions[i].product = ChatProductRef(
          id: current.id,
          name: current.name,
          detail: current.detail,
          color: current.color,
          imageUrl: url,
        );
      }
      ChatMockStore.instance.setRemoteContent(
        id: widget.chatId,
        discussions: discussions,
        messages: messages,
        openDiscussionId: widget.openDiscussionId,
      );
      final marked = await _markRemoteRead(repository, readTargets);
      if (marked && mounted) {
        context.read<ChatInboxBloc>().add(const ChatInboxRefreshed());
      }
      _startLive();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(error))),
      );
    }
  }

  Future<void> _sendFirstRemote(
    ChatThread thread,
    String text, {
    required ChatQuote? quote,
    String? title,
    String? draftId,
  }) async {
    setState(() => _sending = true);
    try {
      final discussion = await ServiceLocator.get<ChatRepository>()
          .startDiscussion(
            relationshipId: thread.id,
            firstMessage: text,
            title: title,
          );
      if (!mounted) return;
      if (draftId != null) {
        ChatMockStore.instance.dropDiscussion(thread.id, draftId);
      }
      final sent = discussion.lastMessage;
      final message = sent == null ? null : _apiMessage(sent, discussion.id);
      ChatMockStore.instance.addRemoteDiscussion(
        threadId: thread.id,
        discussion: ProductDiscussion(
          id: discussion.id,
          name: discussion.title,
          status:
              discussion.isClosed
                  ? DiscussionStatus.closed
                  : DiscussionStatus.open,
          product: _productPin(discussion),
        ),
        message:
            message == null
                ? null
                : ChatMessage(
                  id: message.id,
                  kind: message.kind,
                  side: message.side,
                  at: message.at,
                  text: message.text.isEmpty ? text : message.text,
                  mine: true,
                  discussionId: discussion.id,
                  receipt: message.receipt ?? ChatReceipt.sent,
                  quote: quote ?? message.quote,
                  remotePhotoId: message.remotePhotoId,
                ),
      );
      context.read<ChatInboxBloc>().add(const ChatInboxRefreshed());
    } catch (error) {
      if (!mounted) return;
      _composer.text = text;
      setState(() => _quote = quote);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendRemote(
    ChatThread thread,
    String text, {
    required String? discussionId,
    required ChatQuote? quote,
    required String? replyToId,
  }) async {
    if (discussionId == null) {
      _composer.text = text;
      setState(() => _quote = quote);
      return;
    }
    setState(() => _sending = true);
    final reply =
        replyToId != null && RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(replyToId)
            ? replyToId
            : null;
    try {
      final sent = await ServiceLocator.get<ChatRepository>().sendMessage(
        discussionId: discussionId,
        text: text,
        replyToId: reply,
      );
      if (!mounted) return;
      final message = _apiMessage(sent, discussionId);
      ChatMockStore.instance.addRemoteMessage(
        thread.id,
        ChatMessage(
          id: message.id,
          kind: message.kind,
          side: message.side,
          at: message.at,
          text: message.text,
          mine: true,
          discussionId: discussionId,
          receipt: ChatReceipt.sent,
          quote: quote ?? message.quote,
        ),
      );
      context.read<ChatInboxBloc>().add(const ChatInboxRefreshed());
    } catch (error) {
      if (!mounted) return;
      _composer.text = text;
      setState(() => _quote = quote);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendRemotePhoto(
    ChatThread thread,
    String path, {
    required String? discussionId,
  }) async {
    if (discussionId == null || !_catalogId(discussionId) || _sending) {
      if (mounted && (discussionId == null || !_catalogId(discussionId))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Send a message to start this discussion.'),
          ),
        );
      }
      return;
    }
    setState(() => _sending = true);
    final repository = ServiceLocator.get<ChatRepository>();
    try {
      final maxBytes =
          context.read<ChatInboxBloc>().state.capabilities?.limits.photoBytes ??
          (8 * 1024 * 1024);
      final uploadPath = await _shrinkChatPhoto(path, maxBytes: maxBytes);
      if (!mounted) return;
      if (uploadPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That photo is too large to send.')),
        );
        return;
      }
      final uploaded = await repository.uploadPhoto(
        discussionId: discussionId,
        filePath: uploadPath,
      );
      if (uploaded.id.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That photo could not be sent.')),
        );
        return;
      }
      final sent = await repository.sendMessage(
        discussionId: discussionId,
        text: '',
        photoIds: [uploaded.id],
      );
      if (!mounted) return;
      final message = _apiMessage(sent, discussionId);
      ChatMockStore.instance.addRemoteMessage(
        thread.id,
        ChatMessage(
          id: message.id,
          kind: ChatMessageKind.photo,
          side: message.side,
          at: message.at,
          text: message.text == 'Photo' ? '' : message.text,
          mine: true,
          discussionId: discussionId,
          receipt: message.receipt ?? ChatReceipt.sent,
          remotePhotoId: uploaded.id,
          mediaPath: path,
        ),
      );
      context.read<ChatInboxBloc>().add(const ChatInboxRefreshed());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<Map<String, String>> _productImages(
    List<ChatDiscussion> discussions,
  ) async {
    final images = <String, String>{};
    final hintedId = widget.productId.trim();
    final hintedUrl = widget.productImageUrl.trim();
    if (hintedId.isNotEmpty && hintedUrl.isNotEmpty) {
      images[hintedId] = hintedUrl;
    }
    final missing = <String>[];
    for (final discussion in discussions) {
      final id = discussion.product?.id.trim() ?? '';
      if (id.isEmpty || images.containsKey(id) || missing.contains(id)) {
        continue;
      }
      missing.add(id);
    }
    if (missing.isEmpty) return images;
    final repository = ServiceLocator.get<CollectionRepository>();
    await Future.wait(
      missing.map((id) async {
        try {
          final product = await repository.fetchProduct(productId: id);
          final thumb = product.primaryImageThumbnailUrl.trim();
          final full = product.primaryImageUrl.trim();
          final url = thumb.isNotEmpty ? thumb : full;
          if (url.isNotEmpty) images[id] = url;
        } catch (_) {}
      }),
    );
    return images;
  }

  void _startLive() {
    if (!widget.fromApi || _live != null) return;
    _live = Timer.periodic(const Duration(seconds: 4), (_) => _pullLive());
  }

  Future<void> _pullLive() async {
    if (!mounted || _sending || _pulling) return;
    final thread = ChatMockStore.instance.threadById(widget.chatId);
    final discussionId = thread?.openDiscussionId?.trim() ?? '';
    if (!_catalogId(discussionId)) return;
    _pulling = true;
    final repository = ServiceLocator.get<ChatRepository>();
    try {
      final page = await repository.listMessages(
        discussionId: discussionId,
        limit: 50,
      );
      if (!mounted) return;
      final replyPhotos = _replyPhotoIds(page.items);
      ChatMockStore.instance.mergeRemoteMessages(widget.chatId, [
        for (final item in page.items)
          _apiMessage(item, discussionId, replyPhotos: replyPhotos),
      ]);
      final newest = _newestOtherMessage(page.items);
      if (newest != null && newest != _lastReadId) {
        await repository.acknowledgeReceipt(
          discussionId: discussionId,
          messageId: newest,
          state: 'read',
        );
        _lastReadId = newest;
      }
    } catch (_) {
    } finally {
      _pulling = false;
    }
  }

  Future<bool> _markRemoteRead(
    ChatRepository repository,
    List<(String, String)> targets,
  ) async {
    var marked = false;
    for (final target in targets) {
      try {
        await repository.acknowledgeReceipt(
          discussionId: target.$1,
          messageId: target.$2,
          state: 'read',
        );
        _lastReadId = target.$2;
        marked = true;
      } catch (_) {}
    }
    return marked;
  }
}

bool _catalogId(String? value) {
  final id = value?.trim() ?? '';
  return RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(id);
}

String? _newestOtherMessage(List<ChatApiMessage> messages) {
  for (final message in messages) {
    if (message.author.isViewerSide) continue;
    if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(message.id)) continue;
    return message.id;
  }
  return null;
}

ChatProductRef? _productPin(ChatDiscussion discussion) {
  final snap = discussion.product;
  final name =
      (snap != null && snap.name.trim().isNotEmpty)
          ? snap.name.trim()
          : discussion.title.trim();
  if (name.isEmpty) return null;
  final detail =
      snap?.fields.values.isNotEmpty == true ? snap!.fields.values.first : '';
  return ChatProductRef(
    id: (snap != null && snap.id.isNotEmpty) ? snap.id : discussion.id,
    name: name,
    detail: detail.isEmpty ? 'Product' : detail,
    color: const Color(0xFFC4A265),
  );
}

/// Fits a chat photo under [maxBytes] (server `photoBytes`, 8 MB by default).
/// Photos already under the limit are uploaded unchanged.
Future<String?> _shrinkChatPhoto(String sourcePath, {required int maxBytes}) async {
  final source = File(sourcePath);
  if (!source.existsSync()) return null;
  final limit = maxBytes > 0 ? maxBytes : 8 * 1024 * 1024;
  if (source.lengthSync() <= limit) return sourcePath;

  const edges = [2560, 1920, 1600, 1280, 1024, 800];
  const qualities = [80, 65, 50, 35];
  final directory = await getTemporaryDirectory();
  for (final edge in edges) {
    for (final quality in qualities) {
      final bytes = await FlutterImageCompress.compressWithFile(
        sourcePath,
        minWidth: edge,
        minHeight: edge,
        quality: quality,
        format: CompressFormat.jpeg,
        keepExif: false,
        autoCorrectionAngle: true,
      );
      if (bytes == null || bytes.isEmpty || bytes.length > limit) continue;
      final file = File(
        '${directory.path}/chat-photo-${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    }
  }
  return null;
}

Map<String, String> _replyPhotoIds(List<ChatApiMessage> items) {
  return {
    for (final item in items)
      if (item.photos.isNotEmpty) item.id: item.photos.first.id,
  };
}

ChatMessage _apiMessage(
  ChatApiMessage message,
  String discussionId, {
  Map<String, String> replyPhotos = const {},
}) {
  final receipt = message.otherSideReceipt;
  ChatReceipt? tick;
  if (message.author.isViewerSide && receipt != null) {
    if (receipt.read) {
      tick = ChatReceipt.read;
    } else if (receipt.delivered) {
      tick = ChatReceipt.delivered;
    } else {
      tick = ChatReceipt.sent;
    }
  }
  final reply = message.reply;
  final photo =
      message.removed || message.photos.isEmpty ? null : message.photos.first;
  final body =
      message.removed ? 'Message removed' : (message.body?.trim() ?? '');
  return ChatMessage(
    id: message.id,
    kind: photo == null ? ChatMessageKind.text : ChatMessageKind.photo,
    side:
        message.author.isViewerSide
            ? ChatSenderSide.merchant
            : ChatSenderSide.customer,
    at: message.createdAt ?? DateTime.now(),
    text: body,
    mine: message.author.isViewerSide,
    discussionId: discussionId,
    receipt: tick,
    remotePhotoId: photo?.id ?? '',
    quote: _quoteFromApi(reply, replyPhotos),
  );
}

ChatQuote? _quoteFromApi(
  ChatMessageReply? reply,
  Map<String, String> replyPhotos,
) {
  if (reply == null) return null;
  final photoId = reply.photoId.trim().isNotEmpty
      ? reply.photoId.trim()
      : (replyPhotos[reply.id] ?? '');
  final body = reply.body.trim();
  if (body.isEmpty && photoId.isEmpty) return null;
  final label = reply.authorName.trim();
  return ChatQuote(
    senderLabel: label.isEmpty ? 'Message' : label,
    text: photoId.isNotEmpty && body.toLowerCase() == 'photo' ? '' : body,
    remotePhotoId: photoId,
  );
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

class _AttachChoice {
  const _AttachChoice(this.id, this.label, this.icon, this.color);

  final String id;
  final String label;
  final IconData icon;
  final Color color;
}

class _AttachTray extends StatefulWidget {
  const _AttachTray({required this.onPick, required this.onSendPhotos});

  final ValueChanged<String> onPick;
  final ValueChanged<List<String>> onSendPhotos;

  @override
  State<_AttachTray> createState() => _AttachTrayState();
}

class _AttachTrayState extends State<_AttachTray> {
  static const _choices = [
    _AttachChoice('photo', 'Gallery', Icons.photo_rounded, Color(0xFF0B84FF)),
    _AttachChoice(
      'camera',
      'Camera',
      Icons.photo_camera_rounded,
      Color(0xFFE91E63),
    ),
    _AttachChoice(
      'product',
      'Catalogue',
      Icons.grid_view_rounded,
      Color(0xFF00A884),
    ),
    _AttachChoice(
      'file',
      'Document',
      Icons.description_rounded,
      Color(0xFF7E57C2),
    ),
  ];
  static const _pageSize = 60;
  static const _maxSelect = 10;
  static final FilterOptionGroup _newestFirst = FilterOptionGroup(
    orders: const [
      OrderOption(type: OrderOptionType.createDate, asc: false),
    ],
  );

  final ScrollController _scroll = ScrollController();
  final List<AssetEntity> _assets = [];
  final List<AssetEntity> _selected = [];
  AssetPathEntity? _album;
  int _page = 0;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _denied = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loadingMore || _loading) return;
    if (_assets.length >= _total) return;
    if (_scroll.position.pixels < _scroll.position.maxScrollExtent - 480) {
      return;
    }
    _loadMore();
  }

  Future<void> _load() async {
    try {
      final permission = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.image,
            mediaLocation: false,
          ),
        ),
      );
      if (!mounted) return;
      if (!permission.hasAccess) {
        setState(() {
          _denied = true;
          _loading = false;
        });
        return;
      }
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
        filterOption: _newestFirst,
      );
      if (!mounted) return;
      if (paths.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      final album =
          paths.where((path) => path.isAll).firstOrNull ?? paths.first;
      final total = await album.assetCountAsync;
      final page = await album.getAssetListPaged(page: 0, size: _pageSize);
      if (!mounted) return;
      setState(() {
        _album = album;
        _total = total;
        _assets
          ..clear()
          ..addAll(page);
        _page = 1;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _denied = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    final album = _album;
    if (album == null || _loadingMore || _assets.length >= _total) return;
    _loadingMore = true;
    try {
      final page = await album.getAssetListPaged(page: _page, size: _pageSize);
      if (!mounted) return;
      setState(() {
        _assets.addAll(page);
        _page += 1;
      });
    } catch (_) {
    } finally {
      _loadingMore = false;
    }
  }

  void _toggle(AssetEntity asset) {
    final index = _selected.indexWhere((item) => item.id == asset.id);
    if (index >= 0) {
      setState(() => _selected.removeAt(index));
      return;
    }
    if (_selected.length >= _maxSelect) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can select up to 10 photos.')),
      );
      return;
    }
    setState(() => _selected.add(asset));
  }

  Future<void> _sendSelected() async {
    if (_sending || _selected.isEmpty) return;
    setState(() => _sending = true);
    final paths = <String>[];
    for (final asset in _selected) {
      try {
        final file = await asset.file;
        if (file != null) paths.add(file.path);
      } catch (_) {}
    }
    if (!mounted) return;
    if (paths.isEmpty) {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Those photos could not be opened.')),
      );
      return;
    }
    widget.onSendPhotos(paths);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.48;
    return Material(
      color: chatBar,
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final choice in _choices)
                    Expanded(child: _choiceButton(choice)),
                ],
              ),
            ),
            Expanded(child: _gallery(bottom)),
          ],
        ),
      ),
    );
  }

  Widget _choiceButton(_AttachChoice choice) {
    return InkWell(
      onTap: () => widget.onPick(choice.id),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: choice.color,
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 38,
                height: 38,
                child: Icon(choice.icon, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              choice.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption(fontSize: 11, color: chatInk),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gallery(double bottom) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_denied) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Allow photo access to choose images',
              style: AppTextStyles.caption(fontSize: 13, color: chatMuted),
            ),
            TextButton(
              onPressed: PhotoManager.openSetting,
              child: const Text('Settings'),
            ),
          ],
        ),
      );
    }
    if (_assets.isEmpty) {
      return Center(
        child: Text(
          'No photos on this device',
          style: AppTextStyles.caption(fontSize: 13, color: chatMuted),
        ),
      );
    }
    return Stack(
      children: [
        GridView.builder(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(2, 0, 2, 8 + bottom),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: _assets.length,
          itemBuilder: (context, index) {
            final asset = _assets[index];
            final selected = _selected.indexWhere((item) => item.id == asset.id);
            return GestureDetector(
              onTap: () => _toggle(asset),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image(
                    image: AssetEntityImageProvider(
                      asset,
                      isOriginal: false,
                      thumbnailSize: const ThumbnailSize.square(240),
                    ),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                  if (selected >= 0)
                    const ColoredBox(color: Color(0x66000000)),
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected >= 0 ? chatSend : const Color(0x66000000),
                        border: Border.all(color: Colors.white, width: 1.4),
                      ),
                      child: selected >= 0
                          ? Text(
                              '${selected + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (_selected.isNotEmpty)
          Positioned(
            right: 14,
            bottom: 12 + bottom,
            child: GestureDetector(
              onTap: _sending ? null : _sendSelected,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xFF00A884),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ),
            ),
          ),
      ],
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
    required this.attachOpen,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ChatQuote? quote;
  final bool teamNote;
  final VoidCallback onClearQuote;
  final VoidCallback onToggleTeam;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final bool attachOpen;

  @override
  Widget build(BuildContext context) {
    final bottom = attachOpen ? 0.0 : MediaQuery.paddingOf(context).bottom;
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
        border: Border(left: BorderSide(color: chatQuoteAccent, width: 3)),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: chatQuoteAccent,
                  ),
                ),
                if (quote.previewText.isNotEmpty)
                  Text(
                    quote.previewText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption(fontSize: 12, color: chatMuted),
                  ),
              ],
            ),
          ),
          if (quote.hasPhoto) ...[
            const SizedBox(width: 8),
            ChatQuoteThumb(quote: quote, size: 40),
          ],
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
    required this.onReply,
    required this.onTeam,
    required this.onCopy,
    required this.onStar,
  });

  final ChatMessage message;
  final VoidCallback onReply;
  final VoidCallback onTeam;
  final VoidCallback onCopy;
  final VoidCallback onStar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 4),
      child: Material(
        color:
            AppColors.isNight
                ? const Color(0xFF233138)
                : const Color(0xFF2A2F32),
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 196),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
