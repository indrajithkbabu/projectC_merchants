import 'package:project_c/models/catalog/activity_api_models.dart';
import 'package:project_c/resources/endpoints.dart';
import 'package:project_c/webservice/catalog_api_client.dart';

/// HTTP for in-app activity feed + unread badge.
class ActivityRequest {
  ActivityRequest({required CatalogApiClient apiClient}) : _api = apiClient;

  final CatalogApiClient _api;

  /// GET `/activity?limit&cursor`
  Future<ActivityFeedPage> fetchActivity({
    int limit = 20,
    String? cursor,
  }) async {
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.activity,
      query: <String, String>{
        'limit': '$limit',
        if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
      },
      requiresAuth: true,
    );
    return ActivityFeedPage.fromJson(json ?? const <String, dynamic>{});
  }

  /// GET `/activity/unread-count`
  Future<int> fetchUnreadCount() async {
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.activityUnreadCount,
      requiresAuth: true,
    );
    return (json?['unreadCount'] as num?)?.toInt() ?? 0;
  }

  /// POST `/activity/read` — mark specific ids or all.
  Future<int> markRead({
    List<String>? notificationIds,
    bool all = false,
  }) async {
    final body = <String, dynamic>{
      if (all) 'all': true,
      if (!all && notificationIds != null && notificationIds.isNotEmpty)
        'notificationIds': notificationIds,
    };
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.activityRead,
      body: body,
      requiresAuth: true,
    );
    return (json?['markedReadCount'] as num?)?.toInt() ?? 0;
  }
}
