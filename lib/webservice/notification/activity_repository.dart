import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/activity_api_models.dart';
import 'package:project_c/webservice/notification/activity_request.dart';

abstract class ActivityRepository {
  Future<ActivityFeedPage> fetchActivity({int limit = 20, String? cursor});

  Future<int> fetchUnreadCount();

  Future<int> markAllRead();

  Future<int> markReadIds(List<String> notificationIds);
}

class ActivityRepositoryImpl implements ActivityRepository {
  ActivityRepositoryImpl({required ActivityRequest request})
    : _request = request;

  static const _tag = 'ActivityRepository';

  final ActivityRequest _request;

  @override
  Future<ActivityFeedPage> fetchActivity({
    int limit = 20,
    String? cursor,
  }) {
    AppLog.d(_tag, 'fetchActivity limit=$limit cursor=${cursor ?? "-"}');
    return _request.fetchActivity(limit: limit, cursor: cursor);
  }

  @override
  Future<int> fetchUnreadCount() {
    return _request.fetchUnreadCount();
  }

  @override
  Future<int> markAllRead() {
    AppLog.d(_tag, 'markAllRead');
    return _request.markRead(all: true);
  }

  @override
  Future<int> markReadIds(List<String> notificationIds) {
    AppLog.d(_tag, 'markReadIds count=${notificationIds.length}');
    return _request.markRead(notificationIds: notificationIds);
  }
}
