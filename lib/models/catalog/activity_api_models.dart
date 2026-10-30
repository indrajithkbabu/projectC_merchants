import 'package:equatable/equatable.dart';
import 'package:project_c/helper/be_verify.dart';

/// Actor on an activity row (follower / liker).
class ActivityActor extends Equatable {
  const ActivityActor({
    required this.id,
    required this.name,
    this.phone = '',
    this.avatarUrl = '',
  });

  final String id;
  final String name;
  final String phone;
  final String avatarUrl;

  factory ActivityActor.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ActivityActor(id: '', name: '');
    }
    return ActivityActor(
      id: '${json['id'] ?? ''}'.trim(),
      name: '${json['name'] ?? ''}'.trim(),
      phone: '${json['phone'] ?? ''}'.trim(),
      // Docs use `image`; older payloads used avatarUrl / avatar.
      avatarUrl:
          '${json['image'] ?? json['avatarUrl'] ?? json['avatar'] ?? ''}'
              .trim(),
    );
  }

  @override
  List<Object?> get props => [id, name, phone, avatarUrl];
}

/// Store summary on an activity row.
class ActivityStoreRef extends Equatable {
  const ActivityStoreRef({
    required this.id,
    required this.name,
    this.slug = '',
    this.logoUrl = '',
  });

  final String id;
  final String name;
  final String slug;
  final String logoUrl;

  factory ActivityStoreRef.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ActivityStoreRef(id: '', name: '');
    }
    return ActivityStoreRef(
      id: '${json['id'] ?? ''}'.trim(),
      name: '${json['name'] ?? ''}'.trim(),
      slug: '${json['slug'] ?? ''}'.trim(),
      logoUrl:
          '${json['logoUrl'] ?? json['avatarUrl'] ?? json['coverUrl'] ?? ''}'
              .trim(),
    );
  }

  @override
  List<Object?> get props => [id, name, slug, logoUrl];
}

/// One pending follow-request summary from `GET /activity`.
class ActivityPendingFollowRequest extends Equatable {
  const ActivityPendingFollowRequest({
    required this.followId,
    required this.storeId,
    required this.follower,
    this.requestedAt,
  });

  final String followId;
  final String storeId;
  final ActivityActor follower;
  final DateTime? requestedAt;

  factory ActivityPendingFollowRequest.fromJson(Map<String, dynamic> json) {
    final followerRaw = json['follower'];
    return ActivityPendingFollowRequest(
      followId: '${json['followId'] ?? json['id'] ?? ''}'.trim(),
      storeId: '${json['storeId'] ?? ''}'.trim(),
      follower: ActivityActor.fromJson(
        followerRaw is Map
            ? Map<String, dynamic>.from(followerRaw)
            : null,
      ),
      requestedAt: DateTime.tryParse('${json['requestedAt'] ?? ''}'),
    );
  }

  @override
  List<Object?> get props => [followId, storeId, follower, requestedAt];
}

/// Activity feed row types from catalog notifications API.
enum ActivityItemType {
  followRequest,
  requestApproved,
  newFollower,
  newUpload,
  productLiked,
  unknown,
}

ActivityItemType activityItemTypeFromString(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'follow_request':
      return ActivityItemType.followRequest;
    case 'request_approved':
      return ActivityItemType.requestApproved;
    case 'new_follower':
      return ActivityItemType.newFollower;
    case 'new_upload':
      return ActivityItemType.newUpload;
    case 'product_liked':
      return ActivityItemType.productLiked;
    default:
      return ActivityItemType.unknown;
  }
}

/// One item from `GET /activity`.
class ActivityItem extends Equatable {
  const ActivityItem({
    required this.id,
    required this.type,
    required this.read,
    required this.createdAt,
    this.actor,
    this.store,
    this.entityId = '',
    this.count = 1,
    this.thumbnails = const [],
    this.title = '',
    this.message = '',
  });

  final String id;
  final ActivityItemType type;
  final ActivityActor? actor;
  final ActivityStoreRef? store;
  final String entityId;
  final int count;
  final List<String> thumbnails;
  final bool read;
  final DateTime createdAt;

  /// Optional server title/message (e.g. product_liked copy).
  final String title;
  final String message;

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    final actorRaw = json['actor'];
    final storeRaw = json['store'];
    final thumbs = json['thumbnails'];
    final dataRaw = json['data'];
    final data =
        dataRaw is Map
            ? Map<String, dynamic>.from(dataRaw)
            : const <String, dynamic>{};
    final productId =
        '${json['entityId'] ?? json['productId'] ?? data['productId'] ?? json['listingId'] ?? ''}'
            .trim();
    final type = activityItemTypeFromString(json['type'] as String?);
    final item = ActivityItem(
      id: '${json['id'] ?? ''}'.trim(),
      type: type,
      actor:
          actorRaw is Map
              ? ActivityActor.fromJson(Map<String, dynamic>.from(actorRaw))
              : null,
      store:
          storeRaw is Map
              ? ActivityStoreRef.fromJson(Map<String, dynamic>.from(storeRaw))
              : null,
      entityId: productId,
      count: (json['count'] as num?)?.toInt() ?? 1,
      thumbnails:
          thumbs is List
              ? thumbs
                  .map((e) => '$e'.trim())
                  .where((e) => e.isNotEmpty)
                  .toList(growable: false)
              : const [],
      read: json['read'] as bool? ?? false,
      createdAt:
          DateTime.tryParse('${json['createdAt'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      title: '${json['title'] ?? ''}'.trim(),
      message: '${json['message'] ?? ''}'.trim(),
    );
    if (type == ActivityItemType.productLiked) {
      final actorOk = (item.actor?.id.trim().isNotEmpty ?? false);
      final entityOk = item.entityId.isNotEmpty;
      if (actorOk && entityOk) {
        BeVerify.ok(
          '4a product_liked',
          detail:
              'entity=${BeVerify.shortId(item.entityId)} '
              'actor=${BeVerify.shortId(item.actor?.id)} '
              'msg=${item.message.isNotEmpty}',
        );
      } else {
        BeVerify.fail(
          '4a product_liked incomplete',
          detail:
              'entityOk=$entityOk actorOk=$actorOk '
              'typeRaw=${json['type']}',
        );
      }
    }
    return item;
  }

  ActivityItem copyWith({bool? read}) {
    return ActivityItem(
      id: id,
      type: type,
      actor: actor,
      store: store,
      entityId: entityId,
      count: count,
      thumbnails: thumbnails,
      read: read ?? this.read,
      createdAt: createdAt,
      title: title,
      message: message,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    actor,
    store,
    entityId,
    count,
    thumbnails,
    read,
    createdAt,
    title,
    message,
  ];
}

/// `GET /activity` response.
class ActivityFeedPage extends Equatable {
  const ActivityFeedPage({
    this.pendingFollowRequestsCount = 0,
    this.pendingFollowRequests = const [],
    this.items = const [],
    this.nextCursor,
  });

  final int pendingFollowRequestsCount;
  final List<ActivityPendingFollowRequest> pendingFollowRequests;
  final List<ActivityItem> items;
  final String? nextCursor;

  factory ActivityFeedPage.fromJson(Map<String, dynamic> json) {
    final pendingRaw = json['pendingFollowRequests'];
    final itemsRaw = json['items'];
    final cursor = json['nextCursor'];
    return ActivityFeedPage(
      pendingFollowRequestsCount:
          (json['pendingFollowRequestsCount'] as num?)?.toInt() ?? 0,
      pendingFollowRequests:
          pendingRaw is List
              ? pendingRaw
                  .whereType<Map>()
                  .map(
                    (e) => ActivityPendingFollowRequest.fromJson(
                      Map<String, dynamic>.from(e),
                    ),
                  )
                  .toList(growable: false)
              : const [],
      items:
          itemsRaw is List
              ? itemsRaw
                  .whereType<Map>()
                  .map(
                    (e) => ActivityItem.fromJson(Map<String, dynamic>.from(e)),
                  )
                  .toList(growable: false)
              : const [],
      nextCursor:
          cursor is String && cursor.trim().isNotEmpty ? cursor.trim() : null,
    );
  }

  @override
  List<Object?> get props => [
    pendingFollowRequestsCount,
    pendingFollowRequests,
    items,
    nextCursor,
  ];
}
