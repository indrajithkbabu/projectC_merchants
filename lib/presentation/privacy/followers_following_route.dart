import 'package:flutter/material.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/catalog/follow_api_models.dart';
import 'package:project_c/models/store_privacy_mode.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/store/store_repository.dart';

enum FollowersFollowingTab { followers, following }

/// Owner Followers / Following lists (walkthrough screen 07).
class FollowersFollowingRoute extends StatefulWidget {
  const FollowersFollowingRoute({
    super.key,
    required this.storeId,
    required this.storeName,
    this.initialTab = FollowersFollowingTab.followers,
    this.followerCount = 0,
    this.followingCount = 0,
  });

  final String storeId;
  final String storeName;
  final FollowersFollowingTab initialTab;
  final int followerCount;
  final int followingCount;

  @override
  State<FollowersFollowingRoute> createState() =>
      _FollowersFollowingRouteState();
}

class _FollowersFollowingRouteState extends State<FollowersFollowingRoute> {
  late final StoreRepository _stores;
  late FollowersFollowingTab _tab;
  final _searchCtrl = TextEditingController();

  List<FollowerListItem> _followers = const [];
  List<FollowingListItem> _following = const [];
  bool _loadingFollowers = true;
  bool _loadingFollowing = true;
  String? _actingId;

  int _followerCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _stores = ServiceLocator.get<StoreRepository>();
    _tab = widget.initialTab;
    _followerCount = widget.followerCount;
    _followingCount = widget.followingCount;
    _searchCtrl.addListener(() => setState(() {}));
    _loadFollowers();
    _loadFollowing();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _query => _searchCtrl.text.trim().toLowerCase();

  Future<void> _loadFollowers() async {
    setState(() => _loadingFollowers = true);
    try {
      final page = await _stores.fetchFollowers(storeId: widget.storeId);
      if (!mounted) return;
      setState(() {
        _followers = page.items;
        if (page.items.length > _followerCount) {
          _followerCount = page.items.length;
        }
        _loadingFollowers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingFollowers = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(e))),
      );
    }
  }

  Future<void> _loadFollowing() async {
    setState(() => _loadingFollowing = true);
    try {
      final page = await _stores.fetchFollowing(storeId: widget.storeId);
      if (!mounted) return;
      setState(() {
        _following = page.items;
        if (page.items.length > _followingCount) {
          _followingCount = page.items.length;
        }
        _loadingFollowing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingFollowing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(e))),
      );
    }
  }

  List<FollowerListItem> get _filteredFollowers {
    final q = _query;
    if (q.isEmpty) return _followers;
    return _followers
        .where((e) {
          return e.name.toLowerCase().contains(q) ||
              (e.city?.toLowerCase().contains(q) ?? false) ||
              e.typeLabel.toLowerCase().contains(q);
        })
        .toList(growable: false);
  }

  List<FollowingListItem> get _filteredFollowing {
    final q = _query;
    if (q.isEmpty) return _following;
    return _following
        .where((e) {
          return e.name.toLowerCase().contains(q) ||
              (e.city?.toLowerCase().contains(q) ?? false);
        })
        .toList(growable: false);
  }

  Future<void> _removeFollower(FollowerListItem item) async {
    if (_actingId != null) return;
    setState(() => _actingId = item.userId);
    try {
      await _stores.removeFollower(
        storeId: widget.storeId,
        followerUserId: item.userId,
      );
      if (!mounted) return;
      setState(() {
        _followers =
            _followers.where((e) => e.userId != item.userId).toList();
        _followerCount = (_followerCount - 1).clamp(0, 1 << 30);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _actingId = null);
    }
  }

  Future<void> _unfollowStore(FollowingListItem item) async {
    if (_actingId != null) return;
    setState(() => _actingId = item.storeId);
    try {
      await _stores.unfollowStore(item.storeId);
      if (!mounted) return;
      setState(() {
        _following =
            _following.where((e) => e.storeId != item.storeId).toList();
        _followingCount = (_followingCount - 1).clamp(0, 1 << 30);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _actingId = null);
    }
  }

  void _openFollower(FollowerListItem item) {
    if (item.isStore) {
      final storeId = item.storeId?.trim() ?? '';
      if (storeId.isEmpty) return;
      Navigator.of(context).pushNamed(
        Routes.storeProfileRoute,
        arguments: {
          'storeId': storeId,
          'storeName': item.name,
          'isOwnStore': false,
          if (item.slug != null && item.slug!.isNotEmpty)
            'storeLink': '${item.slug}.jewelflow.app',
        },
      );
      return;
    }
    Navigator.of(context).pushNamed(
      Routes.followRequesterProfileRoute,
      arguments: <String, dynamic>{
        'request': {
          'id': item.id,
          'userId': item.userId,
          'followerType': item.followerType,
          'name': item.name,
          'storeId': item.storeId,
          'slug': item.slug,
          'avatar': item.avatar,
          'city': item.city,
        },
        'ownerStoreId': widget.storeId,
        'ownerStoreName': widget.storeName,
        'readOnly': true,
      },
    );
  }

  void _openFollowing(FollowingListItem item) {
    Navigator.of(context).pushNamed(
      Routes.storeProfileRoute,
      arguments: {
        'storeId': item.storeId,
        'storeName': item.name,
        'isOwnStore': false,
        if (item.slug != null && item.slug!.isNotEmpty)
          'storeLink': '${item.slug}.jewelflow.app',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading =
        _tab == FollowersFollowingTab.followers
            ? _loadingFollowers
            : _loadingFollowing;

    return ScreenWrapper(
      backgroundColor: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: AppPadding.screen(
              top: ScreenWrapper.statusBarTop(context),
              bottom: 8,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    AppBackButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Text(
                        widget.storeName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.headline(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 12),
                _Tabs(
                  followerCount: _followerCount,
                  followingCount: _followingCount,
                  selected: _tab,
                  onChanged: (tab) {
                    if (tab == _tab) return;
                    setState(() => _tab = tab);
                  },
                ),
                const SizedBox(height: 12),
                _SearchField(controller: _searchCtrl),
              ],
            ),
          ),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child:
                loading &&
                        (_tab == FollowersFollowingTab.followers
                            ? _followers.isEmpty
                            : _following.isEmpty)
                    ? const Center(child: CircularProgressIndicator())
                    : _tab == FollowersFollowingTab.followers
                    ? _FollowersList(
                      items: _filteredFollowers,
                      actingId: _actingId,
                      onRemove: _removeFollower,
                      onOpen: _openFollower,
                    )
                    : _FollowingList(
                      items: _filteredFollowing,
                      actingId: _actingId,
                      onAction: _unfollowStore,
                      onOpen: _openFollowing,
                    ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.followerCount,
    required this.followingCount,
    required this.selected,
    required this.onChanged,
  });

  final int followerCount;
  final int followingCount;
  final FollowersFollowingTab selected;
  final ValueChanged<FollowersFollowingTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TabLabel(
            label: '$followerCount Followers',
            selected: selected == FollowersFollowingTab.followers,
            onTap: () => onChanged(FollowersFollowingTab.followers),
          ),
        ),
        Expanded(
          child: _TabLabel(
            label: '$followingCount Following',
            selected: selected == FollowersFollowingTab.following,
            onTap: () => onChanged(FollowersFollowingTab.following),
          ),
        ),
      ],
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color:
                    selected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
          Container(
            height: 2,
            color: selected ? AppColors.textPrimary : Colors.transparent,
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: AppTextStyles.body(),
      decoration: InputDecoration(
        hintText: 'Search',
        hintStyle: AppTextStyles.body(color: AppColors.textHint),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: AppColors.surfaceSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

class _FollowersList extends StatelessWidget {
  const _FollowersList({
    required this.items,
    required this.actingId,
    required this.onRemove,
    required this.onOpen,
  });

  final List<FollowerListItem> items;
  final String? actingId;
  final ValueChanged<FollowerListItem> onRemove;
  final ValueChanged<FollowerListItem> onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No followers yet.',
          style: AppTextStyles.bodySecondary(),
        ),
      );
    }
    return ListView.separated(
      padding: AppPadding.screen(top: 4, bottom: 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final item = items[index];
        return _AccountRow(
          name: item.name,
          subtitle: item.subtitle,
          typeLabel: item.typeLabel,
          isStore: item.isStore,
          initial: item.initial,
          actionLabel: 'Remove',
          actionBusy: actingId == item.userId,
          onAction: () => onRemove(item),
          onOpen: () => onOpen(item),
        );
      },
    );
  }
}

class _FollowingList extends StatelessWidget {
  const _FollowingList({
    required this.items,
    required this.actingId,
    required this.onAction,
    required this.onOpen,
  });

  final List<FollowingListItem> items;
  final String? actingId;
  final ValueChanged<FollowingListItem> onAction;
  final ValueChanged<FollowingListItem> onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Not following anyone yet.',
          style: AppTextStyles.bodySecondary(),
        ),
      );
    }
    return ListView.separated(
      padding: AppPadding.screen(top: 4, bottom: 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final item = items[index];
        final pending = item.followStatus.isPending;
        return _AccountRow(
          name: item.name,
          subtitle: item.subtitle,
          typeLabel: 'Store',
          isStore: true,
          initial: item.initial,
          actionLabel: pending ? 'Requested' : 'Following',
          actionBusy: actingId == item.storeId,
          onAction: () => onAction(item),
          onOpen: () => onOpen(item),
        );
      },
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.name,
    required this.subtitle,
    required this.typeLabel,
    required this.isStore,
    required this.initial,
    required this.actionLabel,
    required this.actionBusy,
    required this.onAction,
    required this.onOpen,
  });

  final String name;
  final String subtitle;
  final String typeLabel;
  final bool isStore;
  final String initial;
  final String actionLabel;
  final bool actionBusy;
  final VoidCallback onAction;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              _Avatar(initial: initial, isStore: isStore),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _TypePill(label: typeLabel, isStore: isStore),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ActionChip(
                label: actionLabel,
                busy: actionBusy,
                onTap: onAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.isStore});

  final String initial;
  final bool isStore;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        shape: isStore ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: isStore ? BorderRadius.circular(12) : null,
      ),
      child: Text(
        initial,
        style: AppTextStyles.body(
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.label, required this.isStore});

  final String label;
  final bool isStore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isStore ? AppColors.primary : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isStore ? AppColors.textOnPrimary : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child:
              busy
                  ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textPrimary,
                    ),
                  )
                  : Text(
                    label,
                    style: AppTextStyles.caption(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
        ),
      ),
    );
  }
}
