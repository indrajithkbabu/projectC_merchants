import 'dart:io';

import 'package:project_c/models/catalog/catalog_page.dart';
import 'package:project_c/models/catalog/chat_api_models.dart';
import 'package:project_c/resources/endpoints.dart';
import 'package:project_c/webservice/catalog_api_client.dart';

/// Phase 1 chat reads. The active profile header comes from [CatalogApiClient].
class ChatRequest {
  ChatRequest({required CatalogApiClient apiClient}) : _api = apiClient;

  final CatalogApiClient _api;

  /// POST `/chat/relationships` with a store id. Returns the existing chat
  /// when this profile already has one with that store.
  Future<ChatRelationship> createStoreRelationship({
    required String targetStoreId,
  }) async {
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.chatRelationships,
      body: {'targetStoreId': targetStoreId.trim()},
      requiresAuth: true,
    );
    return ChatRelationship.fromJson(json ?? const <String, dynamic>{});
  }

  /// POST `/chat/relationships` with a customer phone. Store profile only.
  Future<ChatRelationship> createCustomerRelationship({
    required String customerPhone,
  }) async {
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.chatRelationships,
      body: {'customerPhone': customerPhone.trim()},
      requiresAuth: true,
    );
    return ChatRelationship.fromJson(json ?? const <String, dynamic>{});
  }

  /// POST `/chat/relationships/:id/discussions`
  ///
  /// [operationId] must stay the same if this exact send is retried.
  Future<ChatDiscussion> createDiscussion({
    required String relationshipId,
    required String operationId,
    required String firstMessage,
    String? title,
    String? productId,
  }) async {
    final trimmedTitle = title?.trim();
    final trimmedProduct = productId?.trim();
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.chatRelationshipDiscussions(relationshipId.trim()),
      body: <String, dynamic>{
        'operationId': operationId,
        'firstMessage': firstMessage,
        if (trimmedTitle != null && trimmedTitle.isNotEmpty)
          'title': trimmedTitle,
        if (trimmedProduct != null && trimmedProduct.isNotEmpty)
          'productId': trimmedProduct,
      },
      requiresAuth: true,
    );
    return ChatDiscussion.fromJson(json ?? const <String, dynamic>{});
  }

  /// GET `/chat/capabilities`
  Future<ChatCapabilities> getCapabilities() async {
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.chatCapabilities,
      requiresAuth: true,
    );
    return ChatCapabilities.fromJson(json ?? const <String, dynamic>{});
  }

  /// GET `/chat/relationships?view&limit&cursor`
  ///
  /// [view] cursors are not interchangeable. A cursor from `inbox` cannot
  /// be sent with `requests` or `archived`.
  Future<CatalogPage<ChatRelationship>> listRelationships({
    ChatRelationshipView view = ChatRelationshipView.inbox,
    int limit = 20,
    String? cursor,
  }) async {
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.chatRelationships,
      query: _pageQuery(limit: limit, cursor: cursor)
        ..['view'] = view.queryValue,
      requiresAuth: true,
    );
    return chatRelationshipPage(json ?? const <String, dynamic>{});
  }

  /// GET `/chat/relationships/:relationshipId/discussions`
  Future<CatalogPage<ChatDiscussion>> listDiscussions({
    required String relationshipId,
    int limit = 20,
    String? cursor,
    ChatDiscussionListStatus? status,
  }) async {
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.chatRelationshipDiscussions(relationshipId.trim()),
      query: _pageQuery(limit: limit, cursor: cursor)
        ..addAll(
          status == null ? const {} : {'status': status.queryValue},
        ),
      requiresAuth: true,
    );
    return chatDiscussionPage(json ?? const <String, dynamic>{});
  }

  /// POST `/chat/discussions/:discussionId/messages`
  Future<ChatApiMessage> sendMessage({
    required String discussionId,
    required String operationId,
    String text = '',
    String? replyToId,
    List<String> photoIds = const [],
  }) async {
    final reply = replyToId?.trim();
    final bodyText = text.trim();
    final photos = [
      for (final id in photoIds)
        if (id.trim().isNotEmpty) id.trim(),
    ];
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.chatDiscussionMessages(discussionId.trim()),
      body: <String, dynamic>{
        'operationId': operationId,
        if (bodyText.isNotEmpty) 'text': bodyText,
        if (photos.isNotEmpty) 'photoIds': photos,
        if (reply != null && reply.isNotEmpty) 'replyToId': reply,
      },
      requiresAuth: true,
    );
    return ChatApiMessage.fromJson(json ?? const <String, dynamic>{});
  }

  /// POST multipart field `photo`. The returned id is attached with [sendMessage].
  Future<ChatPhotoUpload> uploadPhoto({
    required String discussionId,
    required String filePath,
  }) async {
    final file = File(filePath);
    final name = file.uri.pathSegments.isEmpty
        ? 'photo.jpg'
        : file.uri.pathSegments.last;
    final json = await _api.sendMultipart(
      path: Endpoints.chatDiscussionPhotos(discussionId.trim()),
      fields: const <String, String>{},
      files: [
        CatalogMultipartFile(field: 'photo', file: file, filename: name),
      ],
    );
    return ChatPhotoUpload.fromJson(json ?? const <String, dynamic>{});
  }

  /// POST `/chat/discussions/:id/receipt`. [state] is `delivered` or `read`.
  Future<void> acknowledgeReceipt({
    required String discussionId,
    required String messageId,
    required String state,
  }) async {
    await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.chatDiscussionReceipt(discussionId.trim()),
      body: <String, dynamic>{
        'messageId': messageId.trim(),
        'state': state,
      },
      requiresAuth: true,
    );
  }

  /// GET `/chat/photos/:photoId` as WebP bytes.
  Future<List<int>> downloadPhoto(String photoId) {
    return _api.getBytes(path: Endpoints.chatPhoto(photoId.trim()));
  }

  /// GET `/chat/discussions/:discussionId/messages`
  ///
  /// Pages are newest-first. [cursor] loads the next older page.
  Future<CatalogPage<ChatApiMessage>> listMessages({
    required String discussionId,
    int limit = 20,
    String? cursor,
  }) async {
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.chatDiscussionMessages(discussionId.trim()),
      query: _pageQuery(limit: limit, cursor: cursor),
      requiresAuth: true,
    );
    return chatMessagePage(json ?? const <String, dynamic>{});
  }

  Map<String, String> _pageQuery({required int limit, String? cursor}) {
    final size = limit < 1 ? 1 : (limit > 50 ? 50 : limit);
    final token = cursor?.trim();
    return <String, String>{
      'limit': '$size',
      if (token != null && token.isNotEmpty) 'cursor': token,
    };
  }
}
