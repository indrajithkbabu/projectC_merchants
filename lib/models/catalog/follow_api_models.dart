import 'package:equatable/equatable.dart';
import 'package:project_c/models/store_privacy_mode.dart';

/// Result of `POST|DELETE /stores/:id/follow` (slim payloads, not a full store).
class FollowActionResult extends Equatable {
  const FollowActionResult({
    required this.status,
    this.followerType,
    this.targetStoreId,
    this.followerCount,
    this.pendingRequestsCount,
  });

  /// Mapped from API `status`: `active` → following, `pending`, `none`.
  final StoreFollowStatus status;
  final String? followerType;
  final String? targetStoreId;
  final int? followerCount;
  final int? pendingRequestsCount;

  bool get isPending => status.isPending;
  bool get isFollowing => status.isFollowing;
  bool get canViewContentAfterAction => status.isFollowing;

  factory FollowActionResult.fromJson(Map<String, dynamic> json) {
    final rawStatus =
        (json['status'] as String?)?.trim().toLowerCase() ??
        (json['followStatus'] as String?)?.trim().toLowerCase() ??
        '';
    final StoreFollowStatus status;
    switch (rawStatus) {
      case 'active':
      case 'following':
        status = StoreFollowStatus.following;
      case 'pending':
        status = StoreFollowStatus.pending;
      case 'self':
        status = StoreFollowStatus.self;
      case 'member':
        status = StoreFollowStatus.member;
      case 'none':
      case 'rejected':
      case 'removed':
      default:
        status = StoreFollowStatus.none;
    }

    final target =
        json['targetStore'] ??
        json['targetStoreId'] ??
        json['storeId'];
    return FollowActionResult(
      status: status,
      followerType: json['followerType'] as String?,
      targetStoreId: target is String ? target : null,
      followerCount: (json['followerCount'] as num?)?.toInt(),
      pendingRequestsCount: (json['pendingRequestsCount'] as num?)?.toInt(),
    );
  }

  @override
  List<Object?> get props => [
    status,
    followerType,
    targetStoreId,
    followerCount,
    pendingRequestsCount,
  ];
}

/// One row from `GET /stores/:id/follow-requests`.
class FollowRequestItem extends Equatable {
  const FollowRequestItem({
    required this.id,
    required this.userId,
    required this.followerType,
    required this.name,
    this.storeId,
    this.slug,
    this.avatar,
    this.phone,
    this.city,
    this.requestedAt,
    this.productCount,
    this.uiStatus = FollowRequestUiStatus.pending,
  });

  final String id;
  final String userId;
  final String followerType; // store | individual
  final String name;
  final String? storeId;
  final String? slug;
  final String? avatar;
  final String? phone;
  final String? city;
  final DateTime? requestedAt;
  final int? productCount;
  final FollowRequestUiStatus uiStatus;

  bool get isStore => followerType.trim().toLowerCase() == 'store';
  bool get isIndividual => !isStore;

  String get initial {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t.substring(0, 1).toUpperCase();
  }

  FollowRequestItem copyWith({FollowRequestUiStatus? uiStatus}) {
    return FollowRequestItem(
      id: id,
      userId: userId,
      followerType: followerType,
      name: name,
      storeId: storeId,
      slug: slug,
      avatar: avatar,
      phone: phone,
      city: city,
      requestedAt: requestedAt,
      productCount: productCount,
      uiStatus: uiStatus ?? this.uiStatus,
    );
  }

  factory FollowRequestItem.fromJson(Map<String, dynamic> json) {
    final type =
        (json['followerType'] as String?)?.trim().toLowerCase() ?? 'individual';
    DateTime? requestedAt;
    final rawAt = json['requestedAt'];
    if (rawAt is String && rawAt.isNotEmpty) {
      requestedAt = DateTime.tryParse(rawAt);
    }
    return FollowRequestItem(
      id: '${json['id'] ?? ''}',
      userId: '${json['userId'] ?? ''}',
      followerType: type == 'store' ? 'store' : 'individual',
      name: '${json['name'] ?? ''}'.trim(),
      storeId:
          json['storeId'] is String
              ? (json['storeId'] as String).trim()
              : null,
      slug: json['slug'] is String ? (json['slug'] as String).trim() : null,
      avatar:
          json['avatar'] is String ? (json['avatar'] as String).trim() : null,
      phone: json['phone'] is String ? (json['phone'] as String).trim() : null,
      city: json['city'] is String ? (json['city'] as String).trim() : null,
      requestedAt: requestedAt,
      productCount:
          (json['productCount'] as num?)?.toInt() ??
          (json['collectionCount'] as num?)?.toInt(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    followerType,
    name,
    storeId,
    slug,
    avatar,
    phone,
    city,
    requestedAt,
    productCount,
    uiStatus,
  ];
}

enum FollowRequestUiStatus { pending, approved, deleted }

class FollowRequestPage extends Equatable {
  const FollowRequestPage({required this.items, this.nextCursor});

  final List<FollowRequestItem> items;
  final String? nextCursor;

  factory FollowRequestPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items =
        raw is List
            ? raw
                .whereType<Map>()
                .map(
                  (e) => FollowRequestItem.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .where((e) => e.userId.isNotEmpty)
                .toList()
            : const <FollowRequestItem>[];
    final cursor = json['nextCursor'];
    return FollowRequestPage(
      items: items,
      nextCursor: cursor is String && cursor.isNotEmpty ? cursor : null,
    );
  }

  @override
  List<Object?> get props => [items, nextCursor];
}

/// One row from `GET /stores/:id/followers`.
class FollowerListItem extends Equatable {
  const FollowerListItem({
    required this.id,
    required this.userId,
    required this.followerType,
    required this.name,
    this.storeId,
    this.slug,
    this.avatar,
    this.city,
    this.followedAt,
  });

  final String id;
  final String userId;
  final String followerType;
  final String name;
  final String? storeId;
  final String? slug;
  final String? avatar;
  final String? city;
  final DateTime? followedAt;

  bool get isStore => followerType.trim().toLowerCase() == 'store';
  bool get isIndividual => !isStore;

  String get initial {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t.substring(0, 1).toUpperCase();
  }

  String get typeLabel => isStore ? 'Store' : 'Individual';

  String get subtitle {
    final cityPart = city?.trim() ?? '';
    final kind = isStore ? 'store' : 'individual';
    if (cityPart.isEmpty) return kind;
    return '$cityPart · $kind';
  }

  factory FollowerListItem.fromJson(Map<String, dynamic> json) {
    final type =
        (json['followerType'] as String?)?.trim().toLowerCase() ?? 'individual';
    DateTime? followedAt;
    final rawAt = json['followedAt'];
    if (rawAt is String && rawAt.isNotEmpty) {
      followedAt = DateTime.tryParse(rawAt);
    }
    return FollowerListItem(
      id: '${json['id'] ?? ''}',
      userId: '${json['userId'] ?? ''}',
      followerType: type == 'store' ? 'store' : 'individual',
      name: '${json['name'] ?? ''}'.trim(),
      storeId:
          json['storeId'] is String
              ? (json['storeId'] as String).trim()
              : null,
      slug: json['slug'] is String ? (json['slug'] as String).trim() : null,
      avatar:
          json['avatar'] is String ? (json['avatar'] as String).trim() : null,
      city: json['city'] is String ? (json['city'] as String).trim() : null,
      followedAt: followedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    followerType,
    name,
    storeId,
    slug,
    avatar,
    city,
    followedAt,
  ];
}

class FollowerListPage extends Equatable {
  const FollowerListPage({required this.items, this.nextCursor});

  final List<FollowerListItem> items;
  final String? nextCursor;

  factory FollowerListPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items =
        raw is List
            ? raw
                .whereType<Map>()
                .map(
                  (e) => FollowerListItem.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .where((e) => e.userId.isNotEmpty || e.name.isNotEmpty)
                .toList()
            : const <FollowerListItem>[];
    final cursor = json['nextCursor'];
    return FollowerListPage(
      items: items,
      nextCursor: cursor is String && cursor.isNotEmpty ? cursor : null,
    );
  }

  @override
  List<Object?> get props => [items, nextCursor];
}

/// One row from `GET /stores/:id/following` (stores this store follows).
class FollowingListItem extends Equatable {
  const FollowingListItem({
    required this.id,
    required this.storeId,
    required this.name,
    this.slug,
    this.city,
    this.avatar,
    this.privacy,
    this.followerCount = 0,
    this.followedAt,
    this.followStatus = StoreFollowStatus.following,
  });

  final String id;
  final String storeId;
  final String name;
  final String? slug;
  final String? city;
  final String? avatar;
  final StorePrivacyMode? privacy;
  final int followerCount;
  final DateTime? followedAt;
  final StoreFollowStatus followStatus;

  String get initial {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t.substring(0, 1).toUpperCase();
  }

  String get subtitle {
    final cityPart = city?.trim() ?? '';
    if (cityPart.isEmpty) return 'store';
    return '$cityPart · store';
  }

  FollowingListItem copyWith({StoreFollowStatus? followStatus}) {
    return FollowingListItem(
      id: id,
      storeId: storeId,
      name: name,
      slug: slug,
      city: city,
      avatar: avatar,
      privacy: privacy,
      followerCount: followerCount,
      followedAt: followedAt,
      followStatus: followStatus ?? this.followStatus,
    );
  }

  factory FollowingListItem.fromJson(Map<String, dynamic> json) {
    DateTime? followedAt;
    final rawAt = json['followedAt'];
    if (rawAt is String && rawAt.isNotEmpty) {
      followedAt = DateTime.tryParse(rawAt);
    }
    final storeId =
        '${json['storeId'] ?? json['id'] ?? ''}'.trim();
    final statusRaw =
        (json['followStatus'] as String?) ?? (json['status'] as String?);
    var status = storeFollowStatusFromString(statusRaw);
    if (status == StoreFollowStatus.none) {
      status = StoreFollowStatus.following;
    }
    return FollowingListItem(
      id: '${json['id'] ?? storeId}',
      storeId: storeId,
      name: '${json['name'] ?? ''}'.trim(),
      slug: json['slug'] is String ? (json['slug'] as String).trim() : null,
      city: json['city'] is String ? (json['city'] as String).trim() : null,
      avatar:
          json['avatar'] is String ? (json['avatar'] as String).trim() : null,
      privacy:
          json['privacy'] is String
              ? StorePrivacyModeX.fromApi(json['privacy'] as String)
              : null,
      followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
      followedAt: followedAt,
      followStatus: status,
    );
  }

  @override
  List<Object?> get props => [
    id,
    storeId,
    name,
    slug,
    city,
    avatar,
    privacy,
    followerCount,
    followedAt,
    followStatus,
  ];
}

class FollowingListPage extends Equatable {
  const FollowingListPage({required this.items, this.nextCursor});

  final List<FollowingListItem> items;
  final String? nextCursor;

  factory FollowingListPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items =
        raw is List
            ? raw
                .whereType<Map>()
                .map(
                  (e) => FollowingListItem.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .where((e) => e.storeId.isNotEmpty)
                .toList()
            : const <FollowingListItem>[];
    final cursor = json['nextCursor'];
    return FollowingListPage(
      items: items,
      nextCursor: cursor is String && cursor.isNotEmpty ? cursor : null,
    );
  }

  @override
  List<Object?> get props => [items, nextCursor];
}
