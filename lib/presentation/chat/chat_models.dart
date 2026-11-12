import 'package:flutter/material.dart';

/// UI models for merchant chat. Shapes follow the walkthrough, not a backend
/// contract — swap the in-memory store when the API arrives.

enum ChatStatus { open, closed }

enum DiscussionStatus { open, closed }

enum ChatSenderSide { merchant, customer }

enum ChatReceipt { sent, delivered, read }

enum ChatMessageKind { text, productShare, basket, photo, file, status }

enum ChatKind { person, store, group }

/// Team-only notes. Everything else stays on the neutral palette.
const chatTeamNote = Color(0xFFE3B54E);

class ChatMember {
  const ChatMember({
    required this.id,
    required this.name,
    this.storeName = '',
    this.phone = '',
    this.role = '',
    this.joined = '',
  });

  final String id;
  final String name;
  final String storeName;
  final String phone;
  final String role;
  final String joined;
}

class ChatProductRef {
  const ChatProductRef({
    required this.id,
    required this.name,
    required this.detail,
    required this.color,
    this.imageUrl = '',
  });

  final String id;
  final String name;
  final String detail;
  final Color color;
  final String imageUrl;

  String get initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }
}

class ChatActor {
  const ChatActor({
    required this.id,
    required this.name,
    this.isStoreAccount = false,
    this.phone = '',
    this.team = const [],
  });

  final String id;
  final String name;
  final bool isStoreAccount;
  final String phone;

  /// People added when this store is picked for a group.
  final List<ChatMember> team;

  String get initials {
    final parts =
        name
            .trim()
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final word = parts.first;
      return word.substring(0, word.length.clamp(0, 2)).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class ChatQuote {
  const ChatQuote({
    required this.senderLabel,
    required this.text,
    this.product,
  });

  final String senderLabel;
  final String text;
  final ChatProductRef? product;
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.kind,
    required this.side,
    required this.at,
    this.text = '',
    this.staffName,
    this.mine = false,
    this.discussionId,
    this.receipt,
    this.unread = false,
    this.automatic = false,
    this.suggestedAlternative = false,
    this.quote,
    this.products = const [],
    this.teamOnly = false,
    this.mentions = const [],
    this.writerStore = '',
    this.starred = false,
    this.mediaPath = '',
    this.mediaColorValue = 0,
  });

  final String id;
  final ChatMessageKind kind;
  final ChatSenderSide side;
  final DateTime at;
  final String text;
  final String? staffName;
  final bool mine;
  final String? discussionId;
  ChatReceipt? receipt;
  bool unread;
  final bool automatic;
  final bool suggestedAlternative;
  final ChatQuote? quote;
  final List<ChatProductRef> products;
  final bool teamOnly;
  final List<String> mentions;

  /// Store that can see a team-only note. Empty notes stay with [mine].
  final String writerStore;
  bool starred;

  /// Local photo path. Empty uses [mediaColorValue] as a stand-in.
  final String mediaPath;
  final int mediaColorValue;

  bool get isStatus => kind == ChatMessageKind.status;

  String previewBody() {
    switch (kind) {
      case ChatMessageKind.status:
        return text;
      case ChatMessageKind.basket:
        if (text.trim().isNotEmpty) return text.trim();
        final count = products.length;
        return 'Asked about $count product${count == 1 ? '' : 's'}';
      case ChatMessageKind.productShare:
        if (text.trim().isNotEmpty) return text.trim();
        if (products.isEmpty) return 'Shared a product';
        return products.first.name;
      case ChatMessageKind.photo:
        if (text.trim().isNotEmpty) return text.trim();
        return 'Photo';
      case ChatMessageKind.file:
        if (text.trim().isNotEmpty) return text.trim();
        return 'File';
      case ChatMessageKind.text:
        return text.trim();
    }
  }
}

class ProductDiscussion {
  ProductDiscussion({
    required this.id,
    this.product,
    required this.status,
    this.name = '',
    this.closedBy = '',
    this.sortOrder = 0,
    this.mentionUnread = false,
  });

  final String id;
  ChatProductRef? product;
  DiscussionStatus status;
  String name;
  String closedBy;
  int sortOrder;
  bool mentionUnread;

  String get title {
    final named = name.trim();
    if (named.isNotEmpty) return named;
    final productName = product?.name.trim() ?? '';
    if (productName.isNotEmpty) return productName;
    return 'Discussion';
  }
}

class ChatThread {
  ChatThread({
    required this.id,
    required this.customer,
    required this.status,
    required this.ticket,
    required this.openedAt,
    required this.listed,
    required this.discussions,
    required this.messages,
    this.openDiscussionId,
    this.customerTyping = false,
    this.outbound = false,
    this.kind = ChatKind.person,
    this.muted = false,
    List<ChatMember> members = const [],
    this.phone = '',
    this.createdBy = '',
    this.blocked = false,
    this.customerNote = '',
    this.customerNoteBy = '',
  }) : members = List<ChatMember>.of(members);

  final String id;
  final ChatActor customer;
  ChatStatus status;
  int ticket;
  final DateTime openedAt;
  bool listed;
  String? openDiscussionId;
  bool customerTyping;

  /// This account is asking another store. Shown on Message with other chats.
  final bool outbound;
  final ChatKind kind;
  bool muted;
  final List<ChatMember> members;
  final String phone;
  final String createdBy;
  bool blocked;

  /// Short note about a customer. The signed-in store can read and edit it.
  /// Owner-versus-staff visibility is still open; see [chatShowsCustomerStoreRows].
  String customerNote;
  String customerNoteBy;
  final List<ProductDiscussion> discussions;
  final List<ChatMessage> messages;

  int get peopleCount => members.isEmpty ? 1 : members.length;

  bool get hasMention {
    for (final discussion in discussions) {
      if (discussion.status == DiscussionStatus.open &&
          discussion.mentionUnread) {
        return true;
      }
    }
    return false;
  }

  List<ProductDiscussion> discussionsByOrder({required bool open}) {
    final list =
        discussions
            .where(
              (item) =>
                  open
                      ? item.status == DiscussionStatus.open
                      : item.status == DiscussionStatus.closed,
            )
            .toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  String headerSubtitle() {
    final people = peopleCount;
    final prefix = muted ? 'Muted · ' : '';
    if (kind == ChatKind.group) {
      final stores = <String>{};
      for (final member in members) {
        final store = member.storeName.trim();
        if (store.isNotEmpty) stores.add(store);
      }
      final storeCount = stores.isEmpty ? 1 : stores.length;
      return '$prefix$storeCount stores, $people people';
    }
    if (kind == ChatKind.store || outbound) {
      return '${prefix}Store · $people people';
    }
    if (muted) return 'Muted';
    return customer.isStoreAccount ? 'Store account' : 'Customer';
  }

  /// Discussion to open when the chat is entered with no explicit target.
  /// Uses the discussion left open last, otherwise the one with the newest message.
  String? resumeDiscussionId() {
    if (discussionById(openDiscussionId) != null) return openDiscussionId;
    ProductDiscussion? best;
    DateTime bestAt = openedAt;
    for (final discussion in discussions) {
      var at = openedAt;
      for (final message in messages) {
        if (message.discussionId == discussion.id && message.at.isAfter(at)) {
          at = message.at;
        }
      }
      if (best == null || at.isAfter(bestAt)) {
        best = discussion;
        bestAt = at;
      }
    }
    return best?.id;
  }

  ProductDiscussion? discussionById(String? id) {
    if (id == null) return null;
    for (final discussion in discussions) {
      if (discussion.id == id) return discussion;
    }
    return null;
  }

  String? discussionIdForProduct(String productId) {
    for (final discussion in discussions) {
      if (discussion.product?.id == productId) return discussion.id;
    }
    return null;
  }

  int unreadInDiscussion(String discussionId) {
    var count = 0;
    for (final message in messages) {
      if (message.discussionId == discussionId &&
          message.unread &&
          !message.isStatus) {
        count++;
      }
    }
    return count;
  }

  int get unreadCount {
    var count = 0;
    for (final message in messages) {
      if (message.unread && !message.isStatus) count++;
    }
    return count;
  }

  ChatMessage? get lastContent {
    for (var i = messages.length - 1; i >= 0; i--) {
      if (!messages[i].isStatus) return messages[i];
    }
    return null;
  }

  DateTime get lastActivity {
    if (messages.isEmpty) return openedAt;
    return messages.last.at;
  }

  String previewText() {
    if (customerTyping && status == ChatStatus.open) return 'typing…';
    final last = lastContent;
    if (last == null) {
      if (messages.isEmpty) return 'No messages yet';
      return messages.last.previewBody();
    }
    final body = last.previewBody();
    final staff = last.staffName?.trim() ?? '';
    if (last.side == ChatSenderSide.merchant &&
        !last.mine &&
        staff.isNotEmpty) {
      return '$staff: $body';
    }
    return body;
  }
}

class ChatProductCustomer {
  const ChatProductCustomer({
    required this.threadId,
    required this.discussionId,
    required this.name,
    required this.unread,
  });

  final String threadId;
  final String discussionId;
  final String name;
  final int unread;
}

class ChatProductGroup {
  ChatProductGroup({required this.product, required this.latestAt});

  final ChatProductRef product;
  DateTime latestAt;
  final List<ChatProductCustomer> customers = [];

  int get customerCount => customers.length;
}

String chatClock(DateTime time) {
  final local = time.toLocal();
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute $suffix';
}

String chatDayLabel(DateTime time) {
  final local = time.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${local.day} ${months[local.month - 1]}';
}

String chatListTime(DateTime time) {
  final local = time.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return chatClock(local);
  if (diff == 1) return 'Yesterday';
  return chatDayLabel(local);
}

String chatDateName(DateTime time) {
  final local = time.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${local.day} ${months[local.month - 1]}';
}

bool chatMessageVisible(ChatMessage message, String viewerStore) {
  if (!message.teamOnly) return true;
  final writer = message.writerStore.trim();
  if (writer.isEmpty) return message.mine;
  return writer == viewerStore.trim();
}

/// Asked about and the customer team note stay visible to the signed-in store.
/// Which staff may see them is undecided, so the check lives in this one place.
bool chatShowsCustomerStoreRows(ChatThread thread) {
  return thread.kind == ChatKind.person && !thread.customer.isStoreAccount;
}

enum ChatSharedKind { product, photo, file }

class ChatSharedEntry {
  const ChatSharedEntry({
    required this.kind,
    required this.discussionId,
    required this.at,
    this.product,
    this.message,
    this.title = '',
    this.subtitle = '',
    this.sender = '',
  });

  final ChatSharedKind kind;
  final String discussionId;
  final DateTime at;
  final ChatProductRef? product;
  final ChatMessage? message;
  final String title;
  final String subtitle;
  final String sender;
}

List<ChatSharedEntry> chatSharedEntries(ChatThread thread, String viewerStore) {
  final entries = <ChatSharedEntry>[];
  final seenProducts = <String>{};
  for (final message in thread.messages) {
    if (!chatMessageVisible(message, viewerStore)) continue;
    if (message.kind == ChatMessageKind.productShare ||
        message.kind == ChatMessageKind.basket) {
      for (final product in message.products) {
        if (!seenProducts.add(product.id)) continue;
        entries.add(
          ChatSharedEntry(
            kind: ChatSharedKind.product,
            discussionId:
                message.discussionId ??
                thread.discussionIdForProduct(product.id) ??
                '',
            at: message.at,
            product: product,
            message: message,
            title: product.name,
            subtitle: product.detail,
            sender: _sharedSender(thread, message),
          ),
        );
      }
    } else if (message.kind == ChatMessageKind.photo ||
        message.kind == ChatMessageKind.file) {
      entries.add(
        ChatSharedEntry(
          kind:
              message.kind == ChatMessageKind.photo
                  ? ChatSharedKind.photo
                  : ChatSharedKind.file,
          discussionId: message.discussionId ?? '',
          at: message.at,
          message: message,
          title: message.previewBody(),
          sender: _sharedSender(thread, message),
        ),
      );
    }
  }
  for (final discussion in thread.discussions) {
    final product = discussion.product;
    if (product == null || !seenProducts.add(product.id)) continue;
    entries.add(
      ChatSharedEntry(
        kind: ChatSharedKind.product,
        discussionId: discussion.id,
        at: thread.openedAt,
        product: product,
        title: product.name,
        subtitle: product.detail,
      ),
    );
  }
  entries.sort((a, b) => b.at.compareTo(a.at));
  return entries;
}

String _sharedSender(ChatThread thread, ChatMessage message) {
  if (message.mine) return 'You';
  final staff = message.staffName?.trim() ?? '';
  if (staff.isNotEmpty) return staff;
  return thread.customer.name;
}

/// Seed members use "My store" until a session name is written onto them.
bool chatMemberOnViewerStore(ChatMember member, String viewerStore) {
  final store = member.storeName.trim();
  if (store.isEmpty) return false;
  if (store == viewerStore.trim()) return true;
  return store == 'My store';
}

bool chatSameDay(DateTime a, DateTime b) {
  final left = a.toLocal();
  final right = b.toLocal();
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
