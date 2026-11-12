import 'package:flutter/material.dart';
import 'package:project_c/presentation/chat/chat_models.dart';

/// In-memory merchant chat. Screens listen to [instance].
///
/// Replace this store when the chat API exists. Widgets should keep reading
/// threads, settings, and these methods rather than growing their own copies.
class ChatMockStore extends ChangeNotifier {
  ChatMockStore._() {
    _seed();
  }

  static final ChatMockStore instance = ChatMockStore._();

  static const _swatches = <Color>[
    Color(0xFFC4A265),
    Color(0xFFB76E79),
    Color(0xFF8C6A3D),
    Color(0xFF6E7F8C),
    Color(0xFF7D6B8A),
    Color(0xFF3E6B5A),
  ];

  final List<ChatThread> _threads = [];
  final List<ChatActor> followers = [];
  final List<String> quickReplies = [];
  final List<ChatProductRef> _mockCatalog = [];
  List<ChatProductRef> _liveCatalog = const [];

  String staffName = 'Suresh';
  String storeName = 'My store';
  bool autoReplyOn = true;
  String autoReplyText = 'Thanks for your interest. We will reply soon.';

  int _seq = 1;
  int _nextTicket = 1046;
  String _catalogKey = '';

  /// Called from the shell tab during build. Does not notify.
  void syncSession({
    required String staffName,
    required String storeName,
    required List<ChatProductRef> catalog,
  }) {
    final nextStaff = staffName.trim().isEmpty ? 'You' : staffName.trim();
    final nextStore = storeName.trim().isEmpty ? 'My store' : storeName.trim();
    this.staffName = nextStaff;
    this.storeName = nextStore;
    final key = catalog.map((item) => item.id).join('|');
    if (key == _catalogKey) return;
    _catalogKey = key;
    _liveCatalog = List<ChatProductRef>.unmodifiable(catalog);
  }

  List<ChatProductRef> get shareCatalog =>
      _liveCatalog.isNotEmpty ? _liveCatalog : _mockCatalog;

  List<ChatThread> get visibleThreads {
    final listed = _threads.where((thread) => thread.listed).toList();
    listed.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return listed;
  }

  /// Customers see store chats. Store owners see people, stores, and groups.
  List<ChatThread> inbox({required bool storesOnly}) {
    if (!storesOnly) return visibleThreads;
    return visibleThreads
        .where(
          (thread) =>
              thread.kind == ChatKind.store ||
              thread.outbound ||
              thread.customer.isStoreAccount,
        )
        .toList();
  }

  int get totalUnread =>
      visibleThreads.fold(0, (sum, thread) => sum + thread.unreadCount);

  ChatThread? threadById(String id) {
    for (final thread in _threads) {
      if (thread.id == id) return thread;
    }
    return null;
  }

  List<ChatProductGroup> get productGroups {
    final groups = <String, ChatProductGroup>{};
    for (final thread in _threads) {
      if (!thread.listed || thread.outbound) continue;
      for (final discussion in thread.discussions) {
        final product = discussion.product;
        if (product == null) continue;
        final latest = _discussionActivity(thread, discussion);
        final group = groups.putIfAbsent(
          product.id,
          () => ChatProductGroup(product: product, latestAt: latest),
        );
        if (latest.isAfter(group.latestAt)) group.latestAt = latest;
        group.customers.add(
          ChatProductCustomer(
            threadId: thread.id,
            discussionId: discussion.id,
            name: thread.customer.name,
            unread: thread.unreadInDiscussion(discussion.id),
          ),
        );
      }
    }
    final list = groups.values.toList();
    list.sort((a, b) => b.latestAt.compareTo(a.latestAt));
    return list;
  }

  /// The signed-in person is the store owner in this mock.
  /// Remove-from-store uses this single flag.
  bool isOwner = true;

  void focusThread(String id, {String? discussionId}) {
    final thread = threadById(id);
    if (thread == null) return;
    final chosen =
        discussionId != null &&
                thread.discussions.any((item) => item.id == discussionId)
            ? discussionId
            : thread.resumeDiscussionId();
    if (chosen != null) {
      thread.openDiscussionId = chosen;
      thread.discussionById(chosen)?.mentionUnread = false;
    }
    for (final message in thread.messages) {
      final inGeneral = message.discussionId == null;
      final inOpen =
          message.discussionId != null &&
          message.discussionId == thread.openDiscussionId;
      if ((inGeneral || inOpen) && message.unread) {
        message.unread = false;
      }
    }
    // The thread reads this store during its first build. Notifying here can
    // mark the shell list dirty while the route is still mounting.
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  void openDiscussion(String threadId, String discussionId) {
    final thread = threadById(threadId);
    if (thread == null) return;
    if (thread.discussionById(discussionId) == null) return;
    thread.openDiscussionId = discussionId;
    thread.discussionById(discussionId)?.mentionUnread = false;
    for (final message in thread.messages) {
      if (message.discussionId == discussionId) message.unread = false;
    }
    notifyListeners();
  }

  void collapseDiscussion(String threadId) {
    final thread = threadById(threadId);
    if (thread == null || thread.openDiscussionId == null) return;
    thread.openDiscussionId = null;
    notifyListeners();
  }

  void sendText(
    String threadId,
    String raw, {
    String? discussionId,
    ChatQuote? quote,
    bool teamOnly = false,
  }) {
    final text = raw.trim();
    if (text.isEmpty) return;
    final thread = threadById(threadId);
    if (thread == null || thread.status == ChatStatus.closed) return;
    var target = _sendableDiscussion(thread, discussionId);
    if (target == null && teamOnly) {
      target = _addDiscussion(thread, name: '', product: null);
    }
    thread.listed = true;
    thread.customerTyping = false;
    final mentions = _mentionsIn(thread, text);
    thread.messages.add(
      ChatMessage(
        id: _id('msg'),
        kind: ChatMessageKind.text,
        side: ChatSenderSide.merchant,
        at: DateTime.now(),
        text: text,
        mine: true,
        discussionId: target,
        receipt: ChatReceipt.sent,
        quote: quote,
        teamOnly: teamOnly,
        mentions: mentions,
        writerStore: teamOnly ? storeName : '',
      ),
    );
    if (target != null) {
      thread.openDiscussionId = target;
    }
    notifyListeners();
  }

  void sendProduct(
    String threadId,
    ChatProductRef product, {
    String? discussionId,
  }) {
    final thread = threadById(threadId);
    if (thread == null || thread.status == ChatStatus.closed) return;
    final target = _sendableDiscussion(thread, discussionId);
    thread.listed = true;
    thread.customerTyping = false;
    thread.messages.add(
      ChatMessage(
        id: _id('msg'),
        kind: ChatMessageKind.productShare,
        side: ChatSenderSide.merchant,
        at: DateTime.now(),
        mine: true,
        discussionId: target,
        receipt: ChatReceipt.sent,
        suggestedAlternative: target != null,
        products: [product],
        text: product.name,
      ),
    );
    if (target != null) {
      thread.openDiscussionId = target;
      final discussion = thread.discussionById(target);
      if (discussion != null && discussion.product == null) {
        discussion.product = product;
      }
    }
    notifyListeners();
  }

  void sendPhoto(
    String threadId, {
    String? discussionId,
    String mediaPath = '',
    int mediaColorValue = 0xFFC4A265,
    String caption = '',
  }) {
    _sendMedia(
      threadId,
      kind: ChatMessageKind.photo,
      discussionId: discussionId,
      text: caption,
      mediaPath: mediaPath,
      mediaColorValue: mediaColorValue,
    );
  }

  void sendFile(
    String threadId, {
    String? discussionId,
    required String name,
  }) {
    final label = name.trim().isEmpty ? 'File' : name.trim();
    _sendMedia(
      threadId,
      kind: ChatMessageKind.file,
      discussionId: discussionId,
      text: label,
    );
  }

  void _sendMedia(
    String threadId, {
    required ChatMessageKind kind,
    String? discussionId,
    String text = '',
    String mediaPath = '',
    int mediaColorValue = 0,
  }) {
    final thread = threadById(threadId);
    if (thread == null || thread.status == ChatStatus.closed) return;
    final target = _sendableDiscussion(thread, discussionId);
    thread.listed = true;
    thread.customerTyping = false;
    thread.messages.add(
      ChatMessage(
        id: _id('msg'),
        kind: kind,
        side: ChatSenderSide.merchant,
        at: DateTime.now(),
        text: text,
        mine: true,
        discussionId: target,
        receipt: ChatReceipt.sent,
        mediaPath: mediaPath,
        mediaColorValue: mediaColorValue,
      ),
    );
    if (target != null) thread.openDiscussionId = target;
    notifyListeners();
  }

  void toggleStar(String threadId, String messageId) {
    final thread = threadById(threadId);
    if (thread == null) return;
    for (final message in thread.messages) {
      if (message.id != messageId) continue;
      message.starred = !message.starred;
      notifyListeners();
      return;
    }
  }

  void setBlocked(String threadId, bool blocked) {
    final thread = threadById(threadId);
    if (thread == null || thread.blocked == blocked) return;
    thread.blocked = blocked;
    notifyListeners();
  }

  void setCustomerNote(String threadId, String raw) {
    final thread = threadById(threadId);
    if (thread == null) return;
    thread.customerNote = raw.trim();
    thread.customerNoteBy = staffName;
    notifyListeners();
  }

  void removeMember(String threadId, String memberId) {
    final thread = threadById(threadId);
    if (thread == null || !isOwner) return;
    final self = staffName.trim();
    thread.members.removeWhere((member) {
      if (member.id == 'self' || member.name.trim() == self) return false;
      return member.id == memberId;
    });
    notifyListeners();
  }

  void leaveGroup(String threadId) {
    final thread = threadById(threadId);
    if (thread == null || thread.kind != ChatKind.group) return;
    thread.listed = false;
    notifyListeners();
  }

  void addMembers(String threadId, List<ChatActor> picked) {
    final thread = threadById(threadId);
    if (thread == null) return;
    for (final actor in picked) {
      final exists = thread.members.any(
        (member) => member.id == actor.id || member.name == actor.name,
      );
      if (exists) continue;
      if (actor.isStoreAccount) {
        thread.members.add(
          ChatMember(
            id: actor.id,
            name: actor.name,
            storeName: actor.name,
            phone: actor.phone,
          ),
        );
        for (final person in actor.team) {
          final already = thread.members.any((member) => member.id == person.id);
          if (!already) thread.members.add(person);
        }
      } else {
        thread.members.add(
          ChatMember(
            id: actor.id,
            name: actor.name,
            phone: actor.phone,
          ),
        );
      }
    }
    notifyListeners();
  }

  void closeDiscussion(String threadId) {
    final thread = threadById(threadId);
    if (thread == null || thread.status == ChatStatus.closed) return;
    final discussion = thread.discussionById(thread.openDiscussionId);
    if (discussion == null || discussion.status == DiscussionStatus.closed) {
      return;
    }
    discussion.status = DiscussionStatus.closed;
    thread.messages.add(
      ChatMessage(
        id: _id('status'),
        kind: ChatMessageKind.status,
        side: ChatSenderSide.merchant,
        at: DateTime.now(),
        discussionId: discussion.id,
        text: 'You closed this discussion · ${chatClock(DateTime.now())}',
      ),
    );
    notifyListeners();
  }

  void reopenDiscussion(String threadId) {
    final thread = threadById(threadId);
    if (thread == null || thread.status == ChatStatus.closed) return;
    final discussion = thread.discussionById(thread.openDiscussionId);
    if (discussion == null || discussion.status == DiscussionStatus.open) {
      return;
    }
    discussion.status = DiscussionStatus.open;
    thread.messages.add(
      ChatMessage(
        id: _id('status'),
        kind: ChatMessageKind.status,
        side: ChatSenderSide.merchant,
        at: DateTime.now(),
        discussionId: discussion.id,
        text: 'You reopened this discussion · ${chatClock(DateTime.now())}',
      ),
    );
    notifyListeners();
  }

  void closeChat(String threadId) {
    final thread = threadById(threadId);
    if (thread == null || thread.status == ChatStatus.closed) return;
    thread.status = ChatStatus.closed;
    thread.customerTyping = false;
    thread.messages.add(
      ChatMessage(
        id: _id('status'),
        kind: ChatMessageKind.status,
        side: ChatSenderSide.merchant,
        at: DateTime.now(),
        text: 'You closed this chat · ${chatClock(DateTime.now())}',
      ),
    );
    notifyListeners();
  }

  void reopenChat(String threadId) {
    final thread = threadById(threadId);
    if (thread == null || thread.status == ChatStatus.open) return;
    _nextTicket += 1;
    thread.ticket = _nextTicket;
    thread.status = ChatStatus.open;
    thread.messages.add(
      ChatMessage(
        id: _id('status'),
        kind: ChatMessageKind.status,
        side: ChatSenderSide.merchant,
        at: DateTime.now(),
        text: 'You reopened this chat as Ticket #${thread.ticket}',
      ),
    );
    notifyListeners();
  }

  String startChat(ChatActor follower) {
    for (final thread in _threads) {
      if (thread.customer.id == follower.id) return thread.id;
    }
    final thread = ChatThread(
      id: _id('chat'),
      customer: follower,
      status: ChatStatus.open,
      ticket: _nextTicket,
      openedAt: DateTime.now(),
      listed: false,
      kind: follower.isStoreAccount ? ChatKind.store : ChatKind.person,
      phone: follower.phone,
      members: [
        ChatMember(id: 'self', name: staffName, storeName: storeName),
        ChatMember(
          id: follower.id,
          name: follower.name,
          storeName: follower.isStoreAccount ? follower.name : '',
          phone: follower.phone,
        ),
      ],
      discussions: [],
      messages: [],
    );
    _nextTicket += 1;
    _threads.add(thread);
    notifyListeners();
    return thread.id;
  }

  void setAutoReply({bool? on, String? text, bool notify = true}) {
    if (on != null) autoReplyOn = on;
    if (text != null) autoReplyText = text;
    if (notify) notifyListeners();
  }

  void addQuickReply(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;
    quickReplies.add(text);
    notifyListeners();
  }

  void removeQuickReply(int index) {
    if (index < 0 || index >= quickReplies.length) return;
    quickReplies.removeAt(index);
    notifyListeners();
  }

  int unreadForStore(String storeId) {
    return threadById(_storeThreadId(storeId))?.unreadCount ?? 0;
  }

  /// Opens the enquiry thread with [storeName]. An empty thread stays out of
  /// the merchant inbox until a message is sent.
  String ensureStoreChat({
    required String storeId,
    required String storeName,
    bool notify = true,
  }) {
    final id = _storeThreadId(storeId);
    final existing = threadById(id);
    if (existing != null) return id;
    _threads.add(
      ChatThread(
        id: id,
        customer: ChatActor(
          id: id,
          name: storeName.trim().isEmpty ? 'Store' : storeName.trim(),
        ),
        status: ChatStatus.open,
        ticket: _nextTicket,
        openedAt: DateTime.now(),
        listed: false,
        outbound: true,
        kind: ChatKind.store,
        phone: '',
        members: [
          ChatMember(id: 'self', name: staffName, storeName: this.storeName),
          ChatMember(
            id: id,
            name: storeName.trim().isEmpty ? 'Store' : storeName.trim(),
            storeName: storeName.trim(),
          ),
        ],
        discussions: [],
        messages: [],
      ),
    );
    _nextTicket += 1;
    if (notify) notifyListeners();
    return id;
  }

  /// One discussion per selected photo. The question is copied into each
  /// discussion so the threads stay separate.
  String sendEnquiry({
    required String storeId,
    required String storeName,
    required String text,
    required List<ChatProductRef> products,
  }) {
    final id = ensureStoreChat(
      storeId: storeId,
      storeName: storeName,
      notify: false,
    );
    final thread = threadById(id);
    if (thread == null || products.isEmpty) return id;
    final body = text.trim().isEmpty ? 'Can I ask about these?' : text.trim();
    thread.listed = true;
    thread.customerTyping = false;
    final now = DateTime.now();
    String? first;
    for (final product in products) {
      final discussionId = _ensureDiscussion(thread, product, now);
      final alreadyAsked = thread.messages.any(
        (message) =>
            message.discussionId == discussionId &&
            message.mine &&
            message.text == body,
      );
      if (!alreadyAsked) {
        thread.messages.add(
          ChatMessage(
            id: _id('msg'),
            kind: ChatMessageKind.text,
            side: ChatSenderSide.customer,
            at: now,
            text: body,
            mine: true,
            receipt: ChatReceipt.sent,
            discussionId: discussionId,
          ),
        );
      }
      first ??= discussionId;
    }
    thread.openDiscussionId = first;
    notifyListeners();
    return id;
  }

  String _ensureDiscussion(
    ChatThread thread,
    ChatProductRef product,
    DateTime at,
  ) {
    final existing = thread.discussionIdForProduct(product.id);
    if (existing != null) return existing;
    final discussionId = _id('disc');
    thread.discussions.add(
      ProductDiscussion(
        id: discussionId,
        product: product,
        status: DiscussionStatus.open,
        sortOrder: _topOrder(thread),
      ),
    );
    if (autoReplyOn && autoReplyText.trim().isNotEmpty) {
      thread.messages.add(
        ChatMessage(
          id: _id('msg'),
          kind: ChatMessageKind.text,
          side: ChatSenderSide.merchant,
          at: at.add(const Duration(seconds: 1)),
          discussionId: discussionId,
          automatic: true,
          unread: true,
          text: autoReplyText.trim(),
        ),
      );
    }
    return discussionId;
  }

  String _storeThreadId(String storeId) => 'enquiry-${storeId.trim()}';

  Map<String, int> repliedBy(ChatThread thread) {
    final counts = <String, int>{};
    for (final message in thread.messages) {
      if (message.side != ChatSenderSide.merchant ||
          message.isStatus ||
          message.automatic) {
        continue;
      }
      final name = message.mine ? staffName : (message.staffName ?? staffName);
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return counts;
  }

  static ChatProductRef productFromTitle({
    required String id,
    required String title,
    required String detail,
    required String imageUrl,
    int toneIndex = 0,
  }) {
    final name = title.trim().isEmpty ? 'Product' : title.trim();
    return ChatProductRef(
      id: id,
      name: name,
      detail: detail.trim().isEmpty ? 'Product' : detail.trim(),
      color: _swatches[toneIndex.abs() % _swatches.length],
      imageUrl: imageUrl,
    );
  }

  String inboxPreview(ChatThread thread) {
    for (var i = thread.messages.length - 1; i >= 0; i--) {
      final message = thread.messages[i];
      if (message.isStatus) continue;
      if (!chatMessageVisible(message, storeName)) continue;
      final body = message.previewBody();
      if (body.isEmpty) continue;
      if (message.mine) return 'You: $body';
      final staff = message.staffName?.trim() ?? '';
      final name = staff.isNotEmpty ? staff : thread.customer.name;
      return '$name: $body';
    }
    return 'No messages yet';
  }

  String discussionPreview(ChatThread thread, ProductDiscussion discussion) {
    for (var i = thread.messages.length - 1; i >= 0; i--) {
      final message = thread.messages[i];
      if (message.discussionId != discussion.id || message.isStatus) continue;
      if (!chatMessageVisible(message, storeName)) continue;
      final body = message.previewBody();
      if (body.isEmpty) continue;
      if (message.mine) return 'You: $body';
      final staff = message.staffName?.trim() ?? '';
      final name = staff.isNotEmpty ? staff : thread.customer.name;
      return '$name: $body';
    }
    return 'No messages yet';
  }

  DateTime discussionActivity(ChatThread thread, ProductDiscussion discussion) {
    return _discussionActivity(thread, discussion);
  }

  void setMuted(String threadId, bool muted) {
    final thread = threadById(threadId);
    if (thread == null || thread.muted == muted) return;
    thread.muted = muted;
    notifyListeners();
  }

  int closeDiscussions(String threadId, Iterable<String> ids) {
    final thread = threadById(threadId);
    if (thread == null) return 0;
    var count = 0;
    for (final id in ids) {
      final discussion = thread.discussionById(id);
      if (discussion == null || discussion.status == DiscussionStatus.closed) {
        continue;
      }
      discussion.status = DiscussionStatus.closed;
      discussion.closedBy = staffName;
      count++;
    }
    if (count > 0) notifyListeners();
    return count;
  }

  void markDiscussionsRead(String threadId, Iterable<String> ids) {
    final thread = threadById(threadId);
    if (thread == null) return;
    final selected = ids.toSet();
    for (final discussion in thread.discussions) {
      if (selected.contains(discussion.id)) discussion.mentionUnread = false;
    }
    for (final message in thread.messages) {
      final id = message.discussionId;
      if (id != null && selected.contains(id)) message.unread = false;
    }
    notifyListeners();
  }

  void reorderOpenDiscussions(String threadId, int oldIndex, int newIndex) {
    final thread = threadById(threadId);
    if (thread == null) return;
    final open = thread.discussionsByOrder(open: true);
    if (oldIndex < 0 || oldIndex >= open.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0 || target >= open.length) return;
    final moved = open.removeAt(oldIndex);
    open.insert(target, moved);
    for (var i = 0; i < open.length; i++) {
      open[i].sortOrder = i;
    }
    notifyListeners();
  }

  void reopenDiscussionById(String threadId, String discussionId) {
    final thread = threadById(threadId);
    final discussion = thread?.discussionById(discussionId);
    if (thread == null || discussion == null) return;
    if (discussion.status == DiscussionStatus.open) return;
    discussion.status = DiscussionStatus.open;
    discussion.closedBy = '';
    discussion.mentionUnread = false;
    discussion.sortOrder = _topOrder(thread);
    for (final message in thread.messages) {
      if (message.discussionId == discussionId) message.unread = false;
    }
    notifyListeners();
  }

  String startDiscussion(
    String threadId, {
    String name = '',
    ChatProductRef? product,
  }) {
    final thread = threadById(threadId);
    if (thread == null) return '';
    final id = _addDiscussion(thread, name: name, product: product);
    thread.listed = true;
    thread.openDiscussionId = id;
    thread.messages.add(
      ChatMessage(
        id: _id('status'),
        kind: ChatMessageKind.status,
        side: ChatSenderSide.merchant,
        at: DateTime.now(),
        discussionId: id,
        text: 'Discussion started',
      ),
    );
    notifyListeners();
    return id;
  }

  String createGroup({required String name, required List<ChatActor> picked}) {
    final members = <ChatMember>[
      ChatMember(id: 'self', name: staffName, storeName: storeName),
    ];
    for (final actor in picked) {
      if (actor.isStoreAccount) {
        members.add(
          ChatMember(
            id: actor.id,
            name: actor.name,
            storeName: actor.name,
            phone: actor.phone,
          ),
        );
        members.addAll(actor.team);
      } else {
        members.add(
          ChatMember(
            id: actor.id,
            name: actor.name,
            storeName: storeName,
            phone: actor.phone,
          ),
        );
      }
    }
    final label = name.trim().isEmpty ? 'Group' : name.trim();
    final now = DateTime.now();
    final thread = ChatThread(
      id: _id('group'),
      customer: ChatActor(id: _id('group-actor'), name: label),
      status: ChatStatus.open,
      ticket: _nextTicket,
      openedAt: now,
      listed: true,
      kind: ChatKind.group,
      createdBy: staffName,
      members: members,
      discussions: [],
      messages: [
        ChatMessage(
          id: _id('status'),
          kind: ChatMessageKind.status,
          side: ChatSenderSide.merchant,
          at: now,
          text: '$staffName created this group',
        ),
      ],
    );
    _nextTicket += 1;
    final discussionId = _addDiscussion(thread, name: '', product: null);
    thread.openDiscussionId = discussionId;
    _threads.add(thread);
    notifyListeners();
    return thread.id;
  }

  String _addDiscussion(
    ChatThread thread, {
    required String name,
    required ChatProductRef? product,
  }) {
    final now = DateTime.now();
    var label = name.trim();
    if (label.isEmpty && product != null) label = '';
    if (label.isEmpty && product == null) {
      final date = chatDateName(now);
      final taken = thread.discussions.any(
        (item) => item.product == null && item.name == date,
      );
      label = taken ? '$date ${chatClock(now)}' : date;
    } else if (product == null && label == chatDateName(now)) {
      final taken = thread.discussions.any(
        (item) => item.product == null && item.name == label,
      );
      if (taken) label = '$label ${chatClock(now)}';
    }
    final discussion = ProductDiscussion(
      id: _id('disc'),
      product: product,
      status: DiscussionStatus.open,
      name: label,
      sortOrder: _topOrder(thread),
    );
    thread.discussions.add(discussion);
    return discussion.id;
  }

  int _topOrder(ChatThread thread) {
    var min = 0;
    for (final item in thread.discussions) {
      if (item.sortOrder < min) min = item.sortOrder;
    }
    return min - 1;
  }

  List<String> _mentionsIn(ChatThread thread, String text) {
    final names = <String>[
      for (final member in thread.members)
        if (member.name.trim().isNotEmpty) member.name.trim(),
    ];
    if (names.isEmpty) return const [];
    final found = <String>[];
    final pattern = RegExp(r'@([A-Za-z][A-Za-z0-9]*)');
    for (final match in pattern.allMatches(text)) {
      final token = match.group(1)!.toLowerCase();
      for (final name in names) {
        final first = name.split(RegExp(r'\s+')).first.toLowerCase();
        if (first == token && !found.contains(name)) found.add(name);
      }
    }
    return found;
  }

  String? _sendableDiscussion(ChatThread thread, String? discussionId) {
    final discussion = thread.discussionById(discussionId);
    if (discussion == null || discussion.status == DiscussionStatus.closed) {
      return null;
    }
    return discussion.id;
  }

  DateTime _discussionActivity(
    ChatThread thread,
    ProductDiscussion discussion,
  ) {
    DateTime latest = thread.openedAt;
    for (final message in thread.messages) {
      if (message.discussionId == discussion.id && message.at.isAfter(latest)) {
        latest = message.at;
      }
    }
    return latest;
  }

  String _id(String prefix) => '$prefix-${_seq++}';

  /// [hour] and [minute] only order events. The stamp is always in the past
  /// so a sample sent "today" never lands in the future.
  DateTime _at(int daysAgo, int hour, int minute) {
    final minutesIntoDay = hour * 60 + minute;
    final offset = daysAgo * 24 * 60 + (24 * 60 - minutesIntoDay);
    return DateTime.now().subtract(Duration(minutes: offset));
  }

  void _seed() {
    const bangle = ChatProductRef(
      id: 'prod-bangle',
      name: 'Kada bangle',
      detail: '7.73 g fine',
      color: Color(0xFFC4A265),
    );
    const hoops = ChatProductRef(
      id: 'prod-hoops',
      name: 'Gold hoops',
      detail: '4.2 g net',
      color: Color(0xFFB76E79),
    );
    const necklace = ChatProductRef(
      id: 'prod-necklace',
      name: 'Temple necklace',
      detail: '22.4 g fine',
      color: Color(0xFF8C6A3D),
    );
    const chain = ChatProductRef(
      id: 'prod-chain',
      name: 'Rope chain',
      detail: '12.0 g fine',
      color: Color(0xFF6E7F8C),
    );

    const ajith = ChatActor(id: 'cust-ajith', name: 'Ajith');
    const mehta = ChatActor(
      id: 'cust-mehta',
      name: 'Mehta Jewellers',
      isStoreAccount: true,
      phone: '9840011122',
      team: [
        ChatMember(
          id: 'mehta-arun',
          name: 'Arun',
          storeName: 'Mehta Jewellers',
          phone: '9840011123',
        ),
        ChatMember(
          id: 'mehta-divya',
          name: 'Divya',
          storeName: 'Mehta Jewellers',
          phone: '9840011124',
        ),
      ],
    );
    const mega = ChatActor(id: 'cust-mega', name: 'Meganathan');
    //const ajith = ChatActor(id: 'cust-ajith', name: 'Ajith');

    followers.addAll([
      mehta,
      mega,
      ajith,
      const ChatActor(id: 'cust-asha', name: 'Asha Menon'),
      const ChatActor(
        id: 'cust-vikram',
        name: 'Vikram Shah',
        isStoreAccount: true,
      ),
      const ChatActor(id: 'cust-lakshmi', name: 'Lakshmi Iyer'),
    ]);

    _mockCatalog.addAll([
      bangle,
      hoops,
      necklace,
      chain,
      const ChatProductRef(
        id: 'prod-jhumka',
        name: 'Jhumka',
        detail: '8.1 g fine',
        color: Color(0xFF7D6B8A),
      ),
      const ChatProductRef(
        id: 'prod-nosepin',
        name: 'Nose pin',
        detail: '1.2 g fine',
        color: Color(0xFF3E6B5A),
      ),
    ]);

    // quickReplies.addAll([
    //   'This one is 7.73 g.',
    //   'Yes, we can hold it until this evening.',
    //   'Made to order, about 3 weeks.',
    //   'I will share more photos in a moment.',
    // ]);

    _threads.add(
      ChatThread(
        id: 'chat-ajith',
        customer: ajith,
        status: ChatStatus.open,
        ticket: 1038,
        openedAt: _at(1, 16, 10),
        listed: true,
        openDiscussionId: 'disc-bangle',
        phone: '9840099001',
        customerNote: 'Prefers 22 kt. Visits on Saturdays.',
        customerNoteBy: 'Suresh',
        members: const [
          ChatMember(
            id: 'self',
            name: 'Suresh',
            storeName: 'My store',
            role: 'Owner',
            joined: 'Jan 2022',
          ),
          ChatMember(
            id: 'staff-priya',
            name: 'Priya',
            storeName: 'My store',
            role: 'Staff',
            joined: 'Mar 2024',
          ),
          ChatMember(
            id: 'staff-karthik',
            name: 'Karthik',
            storeName: 'My store',
            role: 'Staff',
            joined: 'Aug 2024',
          ),
          ChatMember(id: 'cust-ajith', name: 'Ajith', phone: '9840099001'),
        ],
        discussions: [
          ProductDiscussion(
            id: 'disc-bangle',
            product: bangle,
            status: DiscussionStatus.open,
            sortOrder: 0,
          ),
          ProductDiscussion(
            id: 'disc-hoops',
            product: hoops,
            status: DiscussionStatus.open,
            sortOrder: 1,
            mentionUnread: true,
          ),
          ProductDiscussion(
            id: 'disc-note',
            status: DiscussionStatus.open,
            name: '5 Nov',
            sortOrder: 2,
          ),
          ProductDiscussion(
            id: 'disc-necklace',
            product: necklace,
            status: DiscussionStatus.closed,
            closedBy: 'Ajith',
            sortOrder: 3,
          ),
        ],
        messages: [
          ChatMessage(
            id: 'm1',
            kind: ChatMessageKind.text,
            side: ChatSenderSide.customer,
            at: _at(1, 16, 10),
            text: 'Hi, do you take custom orders?',
          ),
          ChatMessage(
            id: 'm2',
            kind: ChatMessageKind.text,
            side: ChatSenderSide.merchant,
            at: _at(1, 16, 18),
            text: 'Yes, tell me what you are looking for.',
            mine: true,
            receipt: ChatReceipt.delivered,
          ),
          ChatMessage(
            id: 'm3',
            kind: ChatMessageKind.basket,
            side: ChatSenderSide.customer,
            at: _at(0, 11, 2),
            text: 'Can I ask about these three?',
            products: const [bangle, hoops, necklace],
          ),
          // ChatMessage(
          //   id: 'm4',
          //   kind: ChatMessageKind.text,
          //   side: ChatSenderSide.merchant,
          //   at: _at(0, 11, 3),
          //   discussionId: 'disc-bangle',
          //   automatic: true,
          //   text: autoReplyText,
          // ),
          ChatMessage(
            id: 'm5',
            kind: ChatMessageKind.text,
            side: ChatSenderSide.customer,
            at: _at(0, 11, 16),
            discussionId: 'disc-hoops',
            text: 'Are the hoops light enough for daily wear?',
          ),
          ChatMessage(
            id: 'm7',
            kind: ChatMessageKind.text,
            side: ChatSenderSide.customer,
            at: _at(0, 11, 44),
            discussionId: 'disc-bangle',
            text: 'Can you confirm if the weight is 7.73 grams?',
          ),
          ChatMessage(
            id: 'm8',
            kind: ChatMessageKind.text,
            side: ChatSenderSide.merchant,
            at: _at(0, 11, 47),
            discussionId: 'disc-bangle',
            mine: true,
            receipt: ChatReceipt.read,
            text: 'Yes, This one is 7.73 g.',
          ),
          ChatMessage(
            id: 'm9',
            kind: ChatMessageKind.text,
            side: ChatSenderSide.merchant,
            at: _at(0, 12, 8),
            discussionId: 'disc-necklace',
            staffName: 'Priya',
            text: 'This necklace is made to order, about 3 weeks.',
          ),
          ChatMessage(
            id: 'm10',
            kind: ChatMessageKind.status,
            side: ChatSenderSide.customer,
            at: _at(0, 12, 15),
            discussionId: 'disc-necklace',
            text: 'Ajith closed this discussion · ${chatClock(_at(0, 12, 15))}',
          ),
          ChatMessage(
            id: 'm6',
            kind: ChatMessageKind.text,
            side: ChatSenderSide.merchant,
            at: _at(0, 13, 2),
            discussionId: 'disc-hoops',
            staffName: 'Karthik',
            unread: true,
            text: '@Suresh just 4.2 g net. Want me to hold it?',
            mentions: const ['Suresh'],
          ),
          ChatMessage(
            id: 'm-note',
            kind: ChatMessageKind.text,
            side: ChatSenderSide.merchant,
            at: _at(0, 13, 10),
            discussionId: 'disc-bangle',
            mine: true,
            teamOnly: true,
            text: 'Hold this kada for the bridal order.',
          ),
          ChatMessage(
            id: 'm-hidden-note',
            kind: ChatMessageKind.text,
            side: ChatSenderSide.customer,
            at: _at(0, 13, 12),
            discussionId: 'disc-bangle',
            teamOnly: true,
            writerStore: 'Ajith Studio',
            text: 'This note belongs to the other store.',
          ),
          ChatMessage(
            id: 'm-photo',
            kind: ChatMessageKind.photo,
            side: ChatSenderSide.customer,
            at: _at(0, 11, 50),
            discussionId: 'disc-bangle',
            text: 'Hallmark photo',
            mediaColorValue: 0xFFC4A265,
          ),
          ChatMessage(
            id: 'm-file',
            kind: ChatMessageKind.file,
            side: ChatSenderSide.merchant,
            at: _at(0, 14, 20),
            discussionId: 'disc-note',
            mine: true,
            receipt: ChatReceipt.read,
            text: 'Rate card.pdf',
          ),
          ChatMessage(
            id: 'm-date',
            kind: ChatMessageKind.text,
            side: ChatSenderSide.customer,
            at: _at(0, 14, 2),
            discussionId: 'disc-note',
            text: 'Can we talk sizes before the wedding?',
          ),
        ],
      ),
    );

    _threads.add(
      ChatThread(
        id: 'chat-mehta',
        customer: mehta,
        status: ChatStatus.open,
        ticket: 1040,
        openedAt: _at(0, 10, 5),
        listed: true,
        kind: ChatKind.store,
        muted: true,
        phone: '9840011122',
        openDiscussionId: 'disc-chain',
        members: const [
          ChatMember(
            id: 'self',
            name: 'Suresh',
            storeName: 'My store',
            role: 'Owner',
            joined: 'Jan 2022',
          ),
          ChatMember(
            id: 'staff-priya',
            name: 'Priya',
            storeName: 'My store',
            role: 'Staff',
            joined: 'Mar 2024',
          ),
          ChatMember(
            id: 'staff-karthik',
            name: 'Karthik',
            storeName: 'My store',
            role: 'Staff',
            joined: 'Aug 2024',
          ),
          ChatMember(
            id: 'cust-mehta',
            name: 'Mehta Jewellers',
            storeName: 'Mehta Jewellers',
            phone: '9840011122',
          ),
          ChatMember(
            id: 'mehta-arun',
            name: 'Arun',
            storeName: 'Mehta Jewellers',
            role: 'Staff',
          ),
          ChatMember(
            id: 'mehta-divya',
            name: 'Divya',
            storeName: 'Mehta Jewellers',
            role: 'Staff',
          ),
        ],
        discussions: [
          ProductDiscussion(
            id: 'disc-chain',
            product: chain,
            status: DiscussionStatus.open,
            sortOrder: 0,
          ),
          ProductDiscussion(
            id: 'disc-hallmark',
            status: DiscussionStatus.open,
            name: 'Hallmark rates',
            sortOrder: 1,
          ),
        ],
        messages: [
          ChatMessage(
            id: 'm11',
            kind: ChatMessageKind.text,
            side: ChatSenderSide.customer,
            at: _at(0, 10, 5),
            discussionId: 'disc-chain',
            text: 'Do you have the rope chain in 22 kt?',
          ),
          ChatMessage(
            id: 'm12',
            kind: ChatMessageKind.text,
            side: ChatSenderSide.merchant,
            at: _at(0, 10, 22),
            discussionId: 'disc-chain',
            staffName: 'Karthik',
            text: 'Yes, Available',
          ),
          ChatMessage(
            id: 'm-hallmark',
            kind: ChatMessageKind.text,
            side: ChatSenderSide.customer,
            at: _at(0, 10, 40),
            discussionId: 'disc-hallmark',
            unread: true,
            text: 'What is today’s hallmark rate?',
          ),
        ],
      ),
    );

    _threads.add(
      ChatThread(
        id: 'chat-mega',
        customer: mega,
        status: ChatStatus.closed,
        ticket: 1032,
        openedAt: _at(1, 18, 2),
        listed: true,
        discussions: [],
        messages: [
          ChatMessage(
            id: 'm13',
            kind: ChatMessageKind.text,
            side: ChatSenderSide.customer,
            at: _at(1, 18, 2),
            text: 'Is the ring still available?',
          ),
          ChatMessage(
            id: 'm14',
            kind: ChatMessageKind.text,
            side: ChatSenderSide.merchant,
            at: _at(1, 18, 20),
            mine: true,
            receipt: ChatReceipt.read,
            text: 'Yes Available.',
          ),
          ChatMessage(
            id: 'm15',
            kind: ChatMessageKind.status,
            side: ChatSenderSide.merchant,
            at: _at(1, 18, 40),
            text: 'You closed this chat · ${chatClock(_at(1, 18, 40))}',
          ),
        ],
      ),
    );

    _threads.add(
      ChatThread(
        id: 'chat-bridal',
        customer: const ChatActor(id: 'group-bridal', name: 'Bridal team'),
        status: ChatStatus.open,
        ticket: 1044,
        openedAt: _at(0, 9, 30),
        listed: true,
        kind: ChatKind.group,
        createdBy: 'Suresh',
        members: const [
          ChatMember(
            id: 'self',
            name: 'Suresh',
            storeName: 'My store',
            role: 'Owner',
            joined: 'Jan 2022',
          ),
          ChatMember(
            id: 'staff-priya',
            name: 'Priya',
            storeName: 'My store',
            role: 'Staff',
            joined: 'Mar 2024',
          ),
          ChatMember(
            id: 'cust-mehta',
            name: 'Mehta Jewellers',
            storeName: 'Mehta Jewellers',
          ),
          ChatMember(
            id: 'mehta-arun',
            name: 'Arun',
            storeName: 'Mehta Jewellers',
          ),
        ],
        discussions: [
          ProductDiscussion(
            id: 'disc-bridal',
            product: necklace,
            status: DiscussionStatus.open,
            mentionUnread: true,
          ),
        ],
        messages: [
          ChatMessage(
            id: 'm-group-status',
            kind: ChatMessageKind.status,
            side: ChatSenderSide.merchant,
            at: _at(0, 9, 30),
            discussionId: 'disc-bridal',
            text: 'Suresh created this group',
          ),
          ChatMessage(
            id: 'm-group-1',
            kind: ChatMessageKind.text,
            side: ChatSenderSide.merchant,
            at: _at(0, 9, 40),
            discussionId: 'disc-bridal',
            staffName: 'Arun',
            unread: true,
            text: '@Priya can you confirm the necklace weight?',
            mentions: const ['Priya'],
          ),
        ],
      ),
    );

    // _threads.add(
    //   ChatThread(
    //     id: 'chat-ajith',
    //     customer: ajith,
    //     status: ChatStatus.open,
    //     ticket: 1042,
    //     openedAt: _at(0, 14, 10),
    //     listed: true,
    //     customerTyping: true,
    //     discussions: [],
    //     messages: [
    //       ChatMessage(
    //         id: 'm16',
    //         kind: ChatMessageKind.text,
    //         side: ChatSenderSide.customer,
    //         at: _at(0, 14, 10),
    //         text: 'Hi, are you there?',
    //       ),
    //     ],
    //   ),
    // );
  }
}
