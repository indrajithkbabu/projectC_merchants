import 'package:flutter/material.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/models/catalog/activity_api_models.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/privacy/privacy_widgets/activity_feed_shimmer.dart';
import 'package:project_c/presentation/privacy/privacy_widgets/activity_notification_tile.dart';
import 'package:project_c/presentation/privacy/privacy_widgets/follow_requests_banner.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/notification/activity_repository.dart';

/// In-app Activity feed (Screen 13) — Instagram-style list from `GET /activity`.
///
/// Opened from Stores home notification icon (`activity_route`).
class ActivityRoute extends StatefulWidget {
  const ActivityRoute({
    super.key,
    required this.storeId,
    required this.storeName,
    this.pendingCount = 0,
    this.previewNames = const [],
    this.onOpenRequests,
    this.onBack,
  });

  final String storeId;
  final String storeName;
  final int pendingCount;
  final List<String> previewNames;
  final VoidCallback? onOpenRequests;
  final VoidCallback? onBack;

  @override
  State<ActivityRoute> createState() => _ActivityRouteState();
}

class _ActivityRouteState extends State<ActivityRoute> {
  late final ActivityRepository _activity;
  late final CatalogSession _session;

  bool _loading = true;
  bool _loadingMore = false;
  String? _nextCursor;
  List<ActivityItem> _items = const [];
  int _pendingCount = 0;
  List<String> _previewNames = const [];

  @override
  void initState() {
    super.initState();
    _activity = ServiceLocator.get<ActivityRepository>();
    _session = ServiceLocator.get<CatalogSession>();
    _pendingCount = widget.pendingCount;
    _previewNames = widget.previewNames;
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    try {
      final page = await _activity.fetchActivity(limit: 30);
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _nextCursor = page.nextCursor;
        if (page.pendingFollowRequestsCount > 0 ||
            page.pendingFollowRequests.isNotEmpty) {
          _pendingCount = page.pendingFollowRequestsCount;
          _previewNames =
              page.pendingFollowRequests
                  .map((e) => e.follower.name.trim())
                  .where((e) => e.isNotEmpty)
                  .take(2)
                  .toList(growable: false);
        }
        _loading = false;
      });
      // Clear home-bell unread badge; keep NEW section for this visit.
      // ignore: unawaited_futures
      _activity.markAllRead();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(e))),
      );
    }
  }

  Future<void> _refresh() async {
    try {
      final page = await _activity.fetchActivity(limit: 30);
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _nextCursor = page.nextCursor;
        if (page.pendingFollowRequestsCount > 0 ||
            page.pendingFollowRequests.isNotEmpty) {
          _pendingCount = page.pendingFollowRequestsCount;
          _previewNames =
              page.pendingFollowRequests
                  .map((e) => e.follower.name.trim())
                  .where((e) => e.isNotEmpty)
                  .take(2)
                  .toList(growable: false);
        } else if (page.pendingFollowRequestsCount == 0) {
          _pendingCount = 0;
          _previewNames = const [];
        }
      });
      // ignore: unawaited_futures
      _activity.markAllRead();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(e))),
      );
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || cursor.isEmpty || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _activity.fetchActivity(limit: 30, cursor: cursor);
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...page.items];
        _nextCursor = page.nextCursor;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(e))),
      );
    }
  }

  void _openFollowRequests() {
    if (widget.onOpenRequests != null) {
      widget.onOpenRequests!();
      return;
    }
    final storeId = widget.storeId.trim();
    if (storeId.isEmpty) return;
    Navigator.of(context).pushNamed(
      Routes.followRequestsRoute,
      arguments: <String, Object?>{
        'storeId': storeId,
        'storeName':
            widget.storeName.trim().isEmpty ? 'My store' : widget.storeName,
      },
    );
  }

  void _openStore({
    required String storeId,
    String storeName = '',
    bool? isOwnStore,
    String? focusProductId,
  }) {
    final id = storeId.trim();
    if (id.isEmpty) return;
    final ownId = _session.ownStoreId?.trim() ?? '';
    final own = isOwnStore ?? (ownId.isNotEmpty && ownId == id);
    Navigator.of(context).pushNamed(
      Routes.storeProfileRoute,
      arguments: <String, Object?>{
        'storeId': id,
        'storeName': storeName.trim().isEmpty ? 'Store' : storeName.trim(),
        'isOwnStore': own,
        if (focusProductId != null && focusProductId.trim().isNotEmpty)
          'focusProductId': focusProductId.trim(),
      },
    );
  }

  void _onItemTap(ActivityItem item) {
    final storeId = item.store?.id.trim() ?? '';
    final storeName = item.store?.name.trim() ?? '';
    switch (item.type) {
      case ActivityItemType.followRequest:
        _openFollowRequests();
        return;
      case ActivityItemType.requestApproved:
      case ActivityItemType.newFollower:
        _openStore(storeId: storeId, storeName: storeName);
        return;
      case ActivityItemType.newUpload:
      case ActivityItemType.productLiked:
        _openStore(
          storeId: storeId,
          storeName: storeName,
          isOwnStore: item.type == ActivityItemType.productLiked,
          focusProductId: item.entityId,
        );
        return;
      case ActivityItemType.unknown:
        if (storeId.isNotEmpty) {
          _openStore(storeId: storeId, storeName: storeName);
        }
        return;
    }
  }

  List<Widget> _section({
    required String label,
    required List<ActivityItem> items,
  }) {
    if (items.isEmpty) return const [];
    return [
      const SizedBox(height: 20),
      _SectionHeader(label: label),
      const SizedBox(height: 4),
      for (var i = 0; i < items.length; i++)
        ActivityNotificationTile(
          item: items[i],
          onTap: () => _onItemTap(items[i]),
          showDivider: i < items.length - 1,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final showBanner = _pendingCount > 0;
    final unread = _items.where((e) => !e.read).toList(growable: false);
    final earlier = _items.where((e) => e.read).toList(growable: false);
    final hasBack = widget.onBack != null;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 240) {
          // ignore: unawaited_futures
          _loadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: AppPadding.screen(
            top: hasBack ? 4 : 8,
            bottom: 40,
          ),
          children: [
            _Header(hasBack: hasBack, onBack: widget.onBack),
            if (showBanner) ...[
              const SizedBox(height: 16),
              FollowRequestsBanner(
                pendingCount: _pendingCount,
                previewNames: _previewNames,
                onTap: _openFollowRequests,
              ),
            ],
            if (_loading)
              const ActivityFeedShimmer()
            else if (_items.isEmpty && !showBanner)
              const _EmptyState()
            else ...[
              ..._section(label: 'New', items: unread),
              ..._section(label: 'Earlier', items: earlier),
              if (_loadingMore) ...[
                const SizedBox(height: 8),
                const ActivityRowShimmer(),
              ],
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.hasBack, this.onBack});

  final bool hasBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    if (!hasBack) {
      return Text(
        'Activity',
        style: AppTextStyles.headline(
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return Row(
      children: [
        AppBackButton(onPressed: onBack),
        Expanded(
          child: Text(
            'Activity',
            textAlign: TextAlign.center,
            style: AppTextStyles.headline(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 40),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.body(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 12),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 34,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No activity yet',
            style: AppTextStyles.body(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Likes, follows, and new uploads from stores you follow will show up here.',
            style: AppTextStyles.bodySecondary(fontSize: 14, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
