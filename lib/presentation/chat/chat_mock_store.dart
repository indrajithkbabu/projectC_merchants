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
    final listed =
        _threads.where((thread) => thread.listed && !thread.outbound).toList();
    listed.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return listed;
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
        final latest = _discussionActivity(thread, discussion);
        final group = groups.putIfAbsent(
          discussion.product.id,
          () => ChatProductGroup(product: discussion.product, latestAt: latest),
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

  void focusThread(String id, {String? discussionId}) {
    final thread = threadById(id);
    if (thread == null) return;
    if (discussionId != null &&
        thread.discussions.any((item) => item.id == discussionId)) {
      thread.openDiscussionId = discussionId;
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
  }) {
    final text = raw.trim();
    if (text.isEmpty) return;
    final thread = threadById(threadId);
    if (thread == null || thread.status == ChatStatus.closed) return;
    final target = _sendableDiscussion(thread, discussionId);
    thread.listed = true;
    thread.customerTyping = false;
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
        discussions: [
          ProductDiscussion(
            id: 'disc-bangle',
            product: bangle,
            status: DiscussionStatus.open,
          ),
          ProductDiscussion(
            id: 'disc-hoops',
            product: hoops,
            status: DiscussionStatus.open,
          ),
          ProductDiscussion(
            id: 'disc-necklace',
            product: necklace,
            status: DiscussionStatus.closed,
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
            quote: const ChatQuote(
              senderLabel: 'Ajith',
              text: 'Can you confirm if the weight is 7.73 grams?',
            ),
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
            text: 'Yes, just 4.2 g net. Want me to hold it?',
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
        discussions: [
          ProductDiscussion(
            id: 'disc-chain',
            product: chain,
            status: DiscussionStatus.open,
          ),
        ],
        messages: [
          ChatMessage(
            id: 'm11',
            kind: ChatMessageKind.text,
            side: ChatSenderSide.customer,
            at: _at(0, 10, 5),
            unread: true,
            text: 'Do you have the rope chain in 22 kt?',
          ),
          ChatMessage(
            id: 'm12',
            kind: ChatMessageKind.text,
            side: ChatSenderSide.merchant,
            at: _at(0, 10, 22),
            discussionId: 'disc-chain',
            staffName: 'Karthik',
            unread: true,
            text: 'Yes, Available',
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
