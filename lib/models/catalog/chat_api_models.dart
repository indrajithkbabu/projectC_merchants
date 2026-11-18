import 'package:equatable/equatable.dart';
import 'package:project_c/models/catalog/catalog_page.dart';

/// Phase 1 chat HTTP models. These follow the catalog contract.
/// The Message screens still use the UI models in `chat_models.dart`.

enum ChatRelationshipView {
  inbox,
  requests,
  archived;

  String get queryValue => name;
}

enum ChatDiscussionListStatus {
  open,
  closed;

  String get queryValue => name;
}

DateTime? _chatDate(dynamic raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toLocal();
}

String? _messageBody(dynamic raw) {
  if (raw == null) return null;
  return raw.toString();
}

String? _optionalString(dynamic raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  return text.isEmpty ? null : text;
}

int _int(dynamic raw, int fallback) {
  if (raw is num) return raw.toInt();
  return int.tryParse('${raw ?? ''}') ?? fallback;
}

bool _bool(dynamic raw, {bool fallback = false}) {
  if (raw is bool) return raw;
  return fallback;
}

Map<String, dynamic>? _object(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}

List<Map<String, dynamic>> _objectList(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (_object(item) case final map?) map,
  ];
}

/// `GET /chat/capabilities`.
class ChatCapabilities extends Equatable {
  const ChatCapabilities({
    required this.enabled,
    required this.writesEnabled,
    required this.phase,
    required this.profileContextVersion,
    required this.features,
    required this.limits,
  });

  final bool enabled;
  final bool writesEnabled;
  final int phase;
  final int profileContextVersion;
  final ChatFeatureFlags features;
  final ChatLimits limits;

  factory ChatCapabilities.fromJson(Map<String, dynamic> json) {
    return ChatCapabilities(
      enabled: _bool(json['enabled']),
      writesEnabled: _bool(json['writesEnabled']),
      phase: _int(json['phase'], 1),
      profileContextVersion: _int(json['profileContextVersion'], 0),
      features: ChatFeatureFlags.fromJson(_object(json['features'])),
      limits: ChatLimits.fromJson(_object(json['limits'])),
    );
  }

  @override
  List<Object?> get props => [
    enabled,
    writesEnabled,
    phase,
    profileContextVersion,
    features,
    limits,
  ];
}

class ChatFeatureFlags extends Equatable {
  const ChatFeatureFlags({
    required this.customerStore,
    required this.storeStore,
    required this.text,
    required this.photos,
    required this.replies,
    required this.handlers,
    required this.multiProductEnquiry,
    required this.family,
    required this.notes,
    required this.mentions,
    required this.edits,
    required this.search,
  });

  final bool customerStore;
  final bool storeStore;
  final bool text;
  final bool photos;
  final bool replies;
  final bool handlers;
  final bool multiProductEnquiry;
  final bool family;
  final bool notes;
  final bool mentions;
  final bool edits;
  final bool search;

  factory ChatFeatureFlags.fromJson(Map<String, dynamic>? json) {
    final map = json ?? const <String, dynamic>{};
    return ChatFeatureFlags(
      customerStore: _bool(map['customerStore']),
      storeStore: _bool(map['storeStore']),
      text: _bool(map['text']),
      photos: _bool(map['photos']),
      replies: _bool(map['replies']),
      handlers: _bool(map['handlers']),
      multiProductEnquiry: _bool(map['multiProductEnquiry']),
      family: _bool(map['family']),
      notes: _bool(map['notes']),
      mentions: _bool(map['mentions']),
      edits: _bool(map['edits']),
      search: _bool(map['search']),
    );
  }

  @override
  List<Object?> get props => [
    customerStore,
    storeStore,
    text,
    photos,
    replies,
    handlers,
    multiProductEnquiry,
    family,
    notes,
    mentions,
    edits,
    search,
  ];
}

class ChatLimits extends Equatable {
  const ChatLimits({
    required this.textCharacters,
    required this.productsPerDiscussion,
    required this.photoBytes,
    required this.photoPixels,
    required this.photosPerMessage,
    required this.pageSizeMax,
    required this.messagesPerMinute,
    required this.uploadsPerHour,
    required this.contactsPerHour,
    required this.outreachPerDay,
    required this.mediaConcurrency,
  });

  final int textCharacters;
  final int productsPerDiscussion;
  final int photoBytes;
  final int photoPixels;
  final int photosPerMessage;
  final int pageSizeMax;
  final int messagesPerMinute;
  final int uploadsPerHour;
  final int contactsPerHour;
  final int outreachPerDay;
  final int mediaConcurrency;

  factory ChatLimits.fromJson(Map<String, dynamic>? json) {
    final map = json ?? const <String, dynamic>{};
    return ChatLimits(
      textCharacters: _int(map['textCharacters'], 4000),
      productsPerDiscussion: _int(map['productsPerDiscussion'], 20),
      photoBytes: _int(map['photoBytes'], 8388608),
      photoPixels: _int(map['photoPixels'], 20000000),
      photosPerMessage: _int(map['photosPerMessage'], 4),
      pageSizeMax: _int(map['pageSizeMax'], 50),
      messagesPerMinute: _int(map['messagesPerMinute'], 60),
      uploadsPerHour: _int(map['uploadsPerHour'], 60),
      contactsPerHour: _int(map['contactsPerHour'], 20),
      outreachPerDay: _int(map['outreachPerDay'], 10),
      mediaConcurrency: _int(map['mediaConcurrency'], 4),
    );
  }

  @override
  List<Object?> get props => [
    textCharacters,
    productsPerDiscussion,
    photoBytes,
    photoPixels,
    photosPerMessage,
    pageSizeMax,
    messagesPerMinute,
    uploadsPerHour,
    contactsPerHour,
    outreachPerDay,
    mediaConcurrency,
  ];
}

class ChatRelationshipSide extends Equatable {
  const ChatRelationshipSide({
    required this.id,
    required this.name,
    required this.isViewerSide,
  });

  /// `personal:<userId>` or `store:<storeId>`.
  final String id;
  final String name;
  final bool isViewerSide;

  bool get isStore => id.startsWith('store:');
  bool get isPersonal => id.startsWith('personal:');

  factory ChatRelationshipSide.fromJson(Map<String, dynamic> json) {
    return ChatRelationshipSide(
      id: '${json['id'] ?? ''}'.trim(),
      name: '${json['name'] ?? ''}'.trim(),
      isViewerSide: _bool(json['isViewerSide']),
    );
  }

  @override
  List<Object?> get props => [id, name, isViewerSide];
}

/// One side's delivered/read aggregate on an outgoing message.
class ChatSideReceipt extends Equatable {
  const ChatSideReceipt({required this.delivered, required this.read});

  final bool delivered;
  final bool read;

  factory ChatSideReceipt.fromJson(Map<String, dynamic> json) {
    return ChatSideReceipt(
      delivered: _bool(json['delivered']),
      read: _bool(json['read']),
    );
  }

  @override
  List<Object?> get props => [delivered, read];
}

class ChatMessageAuthor extends Equatable {
  const ChatMessageAuthor({
    required this.userId,
    required this.sideId,
    required this.name,
    required this.isViewerSide,
  });

  final String userId;
  final String sideId;
  final String name;
  final bool isViewerSide;

  factory ChatMessageAuthor.fromJson(Map<String, dynamic>? json) {
    final map = json ?? const <String, dynamic>{};
    return ChatMessageAuthor(
      userId: '${map['userId'] ?? ''}'.trim(),
      sideId: '${map['sideId'] ?? ''}'.trim(),
      name: '${map['name'] ?? ''}'.trim(),
      isViewerSide: _bool(map['isViewerSide']),
    );
  }

  @override
  List<Object?> get props => [userId, sideId, name, isViewerSide];
}

/// Upload result from `POST .../photos` before it is attached to a message.
class ChatPhotoUpload extends Equatable {
  const ChatPhotoUpload({
    required this.id,
    this.width,
    this.height,
    this.bytes,
    this.url = '',
  });

  final String id;
  final int? width;
  final int? height;
  final int? bytes;
  final String url;

  factory ChatPhotoUpload.fromJson(Map<String, dynamic> json) {
    return ChatPhotoUpload(
      id: '${json['id'] ?? ''}'.trim(),
      width: json['width'] is num ? (json['width'] as num).toInt() : null,
      height: json['height'] is num ? (json['height'] as num).toInt() : null,
      bytes: json['bytes'] is num ? (json['bytes'] as num).toInt() : null,
      url: '${json['url'] ?? ''}'.trim(),
    );
  }

  @override
  List<Object?> get props => [id, width, height, bytes, url];
}

class ChatPhotoRef extends Equatable {
  const ChatPhotoRef({
    required this.id,
    this.width,
    this.height,
    this.bytes,
    this.url = '',
  });

  final String id;
  final int? width;
  final int? height;
  final int? bytes;

  /// Authenticated relative path. Empty when the payload only carries an id.
  final String url;

  factory ChatPhotoRef.fromJson(dynamic raw) {
    if (raw is String) {
      return ChatPhotoRef(id: raw.trim());
    }
    final map = _object(raw);
    if (map == null) return const ChatPhotoRef(id: '');
    return ChatPhotoRef(
      id: '${map['id'] ?? map['photoId'] ?? ''}'.trim(),
      width: map['width'] is num ? (map['width'] as num).toInt() : null,
      height: map['height'] is num ? (map['height'] as num).toInt() : null,
      bytes: map['bytes'] is num ? (map['bytes'] as num).toInt() : null,
      url: '${map['url'] ?? ''}'.trim(),
    );
  }

  @override
  List<Object?> get props => [id, width, height, bytes, url];
}

class ChatMessageReply extends Equatable {
  const ChatMessageReply({
    required this.id,
    required this.body,
    required this.authorName,
    this.photoId = '',
  });

  final String id;
  final String body;
  final String authorName;
  final String photoId;

  factory ChatMessageReply.fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    final authorName = author is Map
        ? '${author['name'] ?? ''}'.trim()
        : '${author ?? ''}'.trim();
    return ChatMessageReply(
      id: '${json['id'] ?? json['messageId'] ?? ''}'.trim(),
      body: '${json['body'] ?? json['text'] ?? ''}'.trim(),
      authorName: authorName,
      photoId: _replyPhotoId(json),
    );
  }

  @override
  List<Object?> get props => [id, body, authorName, photoId];
}

String _replyPhotoId(Map<String, dynamic> json) {
  final direct = '${json['photoId'] ?? ''}'.trim();
  if (direct.isNotEmpty) return direct;
  final photos = json['photos'];
  if (photos is List && photos.isNotEmpty && photos.first is Map) {
    return '${(photos.first as Map)['id'] ?? ''}'.trim();
  }
  return '';
}

class ChatApiMessage extends Equatable {
  const ChatApiMessage({
    required this.id,
    required this.discussionId,
    required this.relationshipId,
    required this.author,
    required this.body,
    required this.photos,
    required this.createdAt,
    required this.removed,
    this.otherSideReceipt,
    this.reply,
  });

  final String id;
  final String discussionId;
  final String relationshipId;
  final ChatMessageAuthor author;

  /// Null when the message was removed.
  final String? body;
  final List<ChatPhotoRef> photos;
  final DateTime? createdAt;
  final bool removed;
  final ChatSideReceipt? otherSideReceipt;
  final ChatMessageReply? reply;

  factory ChatApiMessage.fromJson(Map<String, dynamic> json) {
    final receipt = _object(json['otherSideReceipt']);
    final reply = _object(json['reply']);
    return ChatApiMessage(
      id: '${json['id'] ?? ''}'.trim(),
      discussionId: '${json['discussionId'] ?? ''}'.trim(),
      relationshipId: '${json['relationshipId'] ?? ''}'.trim(),
      author: ChatMessageAuthor.fromJson(_object(json['author'])),
      body: _bool(json['removed']) ? null : _messageBody(json['body']),
      photos: [
        for (final raw in (json['photos'] as List?) ?? const [])
          if (ChatPhotoRef.fromJson(raw) case final photo)
            if (photo.id.isNotEmpty) photo,
      ],
      createdAt: _chatDate(json['createdAt']),
      removed: _bool(json['removed']),
      otherSideReceipt: receipt == null
          ? null
          : ChatSideReceipt.fromJson(receipt),
      reply: reply == null ? null : ChatMessageReply.fromJson(reply),
    );
  }

  @override
  List<Object?> get props => [
    id,
    discussionId,
    relationshipId,
    author,
    body,
    photos,
    createdAt,
    removed,
    otherSideReceipt,
    reply,
  ];
}

/// Descriptive product card on a discussion. No catalogue media URL.
class ChatProductSnapshot extends Equatable {
  const ChatProductSnapshot({
    required this.id,
    required this.name,
    this.fields = const {},
  });

  final String id;
  final String name;
  final Map<String, String> fields;

  factory ChatProductSnapshot.fromJson(Map<String, dynamic> json) {
    const skipped = {'id', 'productId', 'name', 'title'};
    final fields = <String, String>{};
    json.forEach((key, value) {
      if (skipped.contains(key)) return;
      if (value is String || value is num || value is bool) {
        final text = value.toString().trim();
        if (text.isNotEmpty) fields[key] = text;
      }
    });
    return ChatProductSnapshot(
      id: '${json['id'] ?? json['productId'] ?? ''}'.trim(),
      name: '${json['name'] ?? json['title'] ?? ''}'.trim(),
      fields: fields,
    );
  }

  @override
  List<Object?> get props => [id, name, fields];
}

class ChatDiscussion extends Equatable {
  const ChatDiscussion({
    required this.id,
    required this.relationshipId,
    required this.title,
    required this.status,
    this.closedBy,
    this.closedAt,
    this.product,
    this.products = const [],
    this.liveProductAvailable,
    this.handlerUserId,
    required this.canTakeover,
    required this.unanswered,
    required this.unreadCount,
    this.lastMessage,
    this.createdAt,
  });

  final String id;
  final String relationshipId;
  final String title;

  /// `open` or `closed`.
  final String status;
  final String? closedBy;
  final DateTime? closedAt;
  final ChatProductSnapshot? product;
  final List<ChatProductSnapshot> products;
  final bool? liveProductAvailable;
  final String? handlerUserId;
  final bool canTakeover;
  final bool unanswered;
  final int unreadCount;
  final ChatApiMessage? lastMessage;
  final DateTime? createdAt;

  bool get isOpen => status == ChatDiscussionListStatus.open.queryValue;
  bool get isClosed => status == ChatDiscussionListStatus.closed.queryValue;

  factory ChatDiscussion.fromJson(Map<String, dynamic> json) {
    final product = _object(json['product']);
    final lastMessage = _object(json['lastMessage']);
    final live = json['liveProductAvailable'];
    return ChatDiscussion(
      id: '${json['id'] ?? ''}'.trim(),
      relationshipId: '${json['relationshipId'] ?? ''}'.trim(),
      title: '${json['title'] ?? ''}'.trim(),
      status: '${json['status'] ?? ''}'.trim(),
      closedBy: _optionalString(json['closedBy']),
      closedAt: _chatDate(json['closedAt']),
      product: product == null ? null : ChatProductSnapshot.fromJson(product),
      products: [
        for (final item in _objectList(json['products']))
          ChatProductSnapshot.fromJson(item),
      ],
      liveProductAvailable: live is bool ? live : null,
      handlerUserId: _optionalString(json['handlerUserId']),
      canTakeover: _bool(json['canTakeover']),
      unanswered: _bool(json['unanswered']),
      unreadCount: _int(json['unreadCount'], 0),
      lastMessage: lastMessage == null
          ? null
          : ChatApiMessage.fromJson(lastMessage),
      createdAt: _chatDate(json['createdAt']),
    );
  }

  @override
  List<Object?> get props => [
    id,
    relationshipId,
    title,
    status,
    closedBy,
    closedAt,
    product,
    products,
    liveProductAvailable,
    handlerUserId,
    canTakeover,
    unanswered,
    unreadCount,
    lastMessage,
    createdAt,
  ];
}

class ChatRelationship extends Equatable {
  const ChatRelationship({
    required this.id,
    required this.sides,
    required this.state,
    required this.blocked,
    required this.blockedByViewer,
    required this.disabled,
    this.sharedCustomerPhone,
    this.requestSentAt,
    this.nextRequestAt,
    required this.muted,
    required this.archived,
    this.lastActivityAt,
    required this.unreadCount,
    this.lastMessage,
  });

  final String id;
  final List<ChatRelationshipSide> sides;

  /// `active`, `pending`, `declined`, or an expired pending request.
  final String state;
  final bool blocked;
  final bool blockedByViewer;
  final bool disabled;
  final String? sharedCustomerPhone;
  final DateTime? requestSentAt;
  final DateTime? nextRequestAt;
  final bool muted;
  final bool archived;
  final DateTime? lastActivityAt;
  final int unreadCount;
  final ChatApiMessage? lastMessage;

  ChatRelationshipSide? get otherSide {
    for (final side in sides) {
      if (!side.isViewerSide) return side;
    }
    return null;
  }

  factory ChatRelationship.fromJson(Map<String, dynamic> json) {
    final lastMessage = _object(json['lastMessage']);
    return ChatRelationship(
      id: '${json['id'] ?? ''}'.trim(),
      sides: [
        for (final item in _objectList(json['sides']))
          ChatRelationshipSide.fromJson(item),
      ],
      state: '${json['state'] ?? ''}'.trim(),
      blocked: _bool(json['blocked']),
      blockedByViewer: _bool(json['blockedByViewer']),
      disabled: _bool(json['disabled']),
      sharedCustomerPhone: _optionalString(json['sharedCustomerPhone']),
      requestSentAt: _chatDate(json['requestSentAt']),
      nextRequestAt: _chatDate(json['nextRequestAt']),
      muted: _bool(json['muted']),
      archived: _bool(json['archived']),
      lastActivityAt: _chatDate(json['lastActivityAt']),
      unreadCount: _int(json['unreadCount'], 0),
      lastMessage: lastMessage == null
          ? null
          : ChatApiMessage.fromJson(lastMessage),
    );
  }

  @override
  List<Object?> get props => [
    id,
    sides,
    state,
    blocked,
    blockedByViewer,
    disabled,
    sharedCustomerPhone,
    requestSentAt,
    nextRequestAt,
    muted,
    archived,
    lastActivityAt,
    unreadCount,
    lastMessage,
  ];
}

CatalogPage<T> _chatPage<T>(
  Map<String, dynamic> json,
  T Function(Map<String, dynamic> item) parse,
) {
  final cursor = _optionalString(json['nextCursor']);
  return CatalogPage<T>(
    items: [for (final item in _objectList(json['items'])) parse(item)],
    nextCursor: cursor,
  );
}

CatalogPage<ChatRelationship> chatRelationshipPage(Map<String, dynamic> json) {
  return _chatPage(json, ChatRelationship.fromJson);
}

CatalogPage<ChatDiscussion> chatDiscussionPage(Map<String, dynamic> json) {
  return _chatPage(json, ChatDiscussion.fromJson);
}

CatalogPage<ChatApiMessage> chatMessagePage(Map<String, dynamic> json) {
  return _chatPage(json, ChatApiMessage.fromJson);
}
