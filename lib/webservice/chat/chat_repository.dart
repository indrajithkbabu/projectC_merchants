import 'dart:math';

import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/catalog_page.dart';
import 'package:project_c/models/catalog/chat_api_models.dart';
import 'package:project_c/webservice/chat/chat_request.dart';

abstract class ChatRepository {
  Future<ChatCapabilities> getCapabilities();

  Future<CatalogPage<ChatRelationship>> listRelationships({
    ChatRelationshipView view = ChatRelationshipView.inbox,
    int limit = 20,
    String? cursor,
  });

  Future<CatalogPage<ChatDiscussion>> listDiscussions({
    required String relationshipId,
    int limit = 20,
    String? cursor,
    ChatDiscussionListStatus? status,
  });

  Future<CatalogPage<ChatApiMessage>> listMessages({
    required String discussionId,
    int limit = 20,
    String? cursor,
  });

  /// Append public text and/or already uploaded photo ids.
  Future<ChatApiMessage> sendMessage({
    required String discussionId,
    required String text,
    String? replyToId,
    List<String> photoIds = const [],
  });

  Future<ChatPhotoUpload> uploadPhoto({
    required String discussionId,
    required String filePath,
  });

  /// Mark messages through [messageId] as delivered or read.
  Future<void> acknowledgeReceipt({
    required String discussionId,
    required String messageId,
    required String state,
  });

  Future<List<int>> downloadPhoto(String photoId);

  /// Get or create the chat with a store. Does not send a message.
  Future<ChatRelationship> openStoreChat(String targetStoreId);

  /// Get or create the chat with a registered customer phone.
  Future<ChatRelationship> openCustomerChat(String customerPhone);

  /// First message on a relationship that has no discussion yet.
  Future<ChatDiscussion> startDiscussion({
    required String relationshipId,
    required String firstMessage,
    String? title,
  });

  /// Get or create the chat with [targetStoreId], then start it with
  /// [firstMessage]. [productId] is sent only when it is a catalog id.
  Future<ChatDiscussion> sendFirstMessageToStore({
    required String targetStoreId,
    required String firstMessage,
    String? title,
    String? productId,
  });
}

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({required ChatRequest request}) : _request = request;

  static const _tag = 'ChatRepository';

  final ChatRequest _request;

  @override
  Future<ChatCapabilities> getCapabilities() {
    AppLog.d(_tag, 'getCapabilities');
    return _request.getCapabilities();
  }

  @override
  Future<CatalogPage<ChatRelationship>> listRelationships({
    ChatRelationshipView view = ChatRelationshipView.inbox,
    int limit = 20,
    String? cursor,
  }) {
    AppLog.d(_tag, 'listRelationships view=${view.queryValue}');
    return _request.listRelationships(
      view: view,
      limit: limit,
      cursor: cursor,
    );
  }

  @override
  Future<CatalogPage<ChatDiscussion>> listDiscussions({
    required String relationshipId,
    int limit = 20,
    String? cursor,
    ChatDiscussionListStatus? status,
  }) {
    AppLog.d(_tag, 'listDiscussions relationship=$relationshipId');
    return _request.listDiscussions(
      relationshipId: relationshipId,
      limit: limit,
      cursor: cursor,
      status: status,
    );
  }

  @override
  Future<CatalogPage<ChatApiMessage>> listMessages({
    required String discussionId,
    int limit = 20,
    String? cursor,
  }) {
    AppLog.d(_tag, 'listMessages discussion=$discussionId');
    return _request.listMessages(
      discussionId: discussionId,
      limit: limit,
      cursor: cursor,
    );
  }

  @override
  Future<ChatApiMessage> sendMessage({
    required String discussionId,
    required String text,
    String? replyToId,
    List<String> photoIds = const [],
  }) {
    AppLog.d(_tag, 'sendMessage discussion=$discussionId');
    return _request.sendMessage(
      discussionId: discussionId,
      operationId: _operationId(),
      text: text,
      replyToId: replyToId,
      photoIds: photoIds,
    );
  }

  @override
  Future<ChatPhotoUpload> uploadPhoto({
    required String discussionId,
    required String filePath,
  }) {
    AppLog.d(_tag, 'uploadPhoto discussion=$discussionId');
    return _request.uploadPhoto(
      discussionId: discussionId,
      filePath: filePath,
    );
  }

  @override
  Future<void> acknowledgeReceipt({
    required String discussionId,
    required String messageId,
    required String state,
  }) {
    AppLog.d(_tag, 'receipt discussion=$discussionId state=$state');
    return _request.acknowledgeReceipt(
      discussionId: discussionId,
      messageId: messageId,
      state: state,
    );
  }

  @override
  Future<List<int>> downloadPhoto(String photoId) {
    return _request.downloadPhoto(photoId);
  }

  @override
  Future<ChatRelationship> openStoreChat(String targetStoreId) {
    AppLog.d(_tag, 'openStoreChat store=$targetStoreId');
    return _request.createStoreRelationship(targetStoreId: targetStoreId);
  }

  @override
  Future<ChatRelationship> openCustomerChat(String customerPhone) {
    AppLog.d(_tag, 'openCustomerChat');
    return _request.createCustomerRelationship(customerPhone: customerPhone);
  }

  @override
  Future<ChatDiscussion> startDiscussion({
    required String relationshipId,
    required String firstMessage,
    String? title,
  }) {
    AppLog.d(_tag, 'startDiscussion relationship=$relationshipId');
    final named = title?.trim() ?? '';
    final short = named.length > 120 ? named.substring(0, 120) : named;
    return _request.createDiscussion(
      relationshipId: relationshipId,
      operationId: _operationId(),
      firstMessage: firstMessage,
      title: short.isEmpty ? null : short,
    );
  }

  @override
  Future<ChatDiscussion> sendFirstMessageToStore({
    required String targetStoreId,
    required String firstMessage,
    String? title,
    String? productId,
  }) async {
    AppLog.d(_tag, 'sendFirstMessageToStore store=$targetStoreId');
    final relationship = await _request.createStoreRelationship(
      targetStoreId: targetStoreId,
    );
    final named = title?.trim() ?? '';
    final product = productId?.trim() ?? '';
    final shortTitle = named.length > 120 ? named.substring(0, 120) : named;
    final catalogProduct = RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(product)
        ? product
        : null;
    return _request.createDiscussion(
      relationshipId: relationship.id,
      operationId: _operationId(),
      firstMessage: firstMessage,
      title: shortTitle.isEmpty ? null : shortTitle,
      productId: catalogProduct,
    );
  }
}

String _operationId() {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final salt = Random().nextInt(0x7fffffff).toRadixString(16).padLeft(8, '0');
  final id = 'c$time$salt';
  if (id.length > 128) return id.substring(0, 128);
  if (id.length < 16) return id.padRight(16, '0');
  return id;
}
