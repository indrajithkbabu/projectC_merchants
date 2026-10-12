import 'package:flutter/material.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/catalog/follow_api_models.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/store/store_repository.dart';

enum _FollowRequestFilter { all, stores, individuals }

/// Owner follow-request inbox (walkthrough screen 04).
class FollowRequestsRoute extends StatefulWidget {
  const FollowRequestsRoute({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  final String storeId;
  final String storeName;

  @override
  State<FollowRequestsRoute> createState() => _FollowRequestsRouteState();
}

class _FollowRequestsRouteState extends State<FollowRequestsRoute> {
  late final StoreRepository _stores;
  _FollowRequestFilter _filter = _FollowRequestFilter.all;
  List<FollowRequestItem> _items = const [];
  bool _loading = true;
  String? _actingUserId;

  @override
  void initState() {
    super.initState();
    _stores = ServiceLocator.get<StoreRepository>();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final page = await _stores.fetchFollowRequests(storeId: widget.storeId);
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(e))),
      );
    }
  }

  List<FollowRequestItem> get _filtered {
    switch (_filter) {
      case _FollowRequestFilter.all:
        return _items;
      case _FollowRequestFilter.stores:
        return _items.where((e) => e.isStore).toList(growable: false);
      case _FollowRequestFilter.individuals:
        return _items.where((e) => e.isIndividual).toList(growable: false);
    }
  }

  void _updateItem(String userId, FollowRequestUiStatus status) {
    setState(() {
      _items =
          _items
              .map(
                (e) =>
                    e.userId == userId ? e.copyWith(uiStatus: status) : e,
              )
              .toList(growable: false);
    });
  }

  Future<void> _accept(FollowRequestItem item) async {
    if (_actingUserId != null) return;
    setState(() => _actingUserId = item.userId);
    try {
      await _stores.acceptFollowRequest(
        storeId: widget.storeId,
        followerUserId: item.userId,
      );
      if (!mounted) return;
      _updateItem(item.userId, FollowRequestUiStatus.approved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _actingUserId = null);
    }
  }

  Future<void> _reject(FollowRequestItem item) async {
    if (_actingUserId != null) return;
    setState(() => _actingUserId = item.userId);
    try {
      await _stores.rejectFollowRequest(
        storeId: widget.storeId,
        followerUserId: item.userId,
      );
      if (!mounted) return;
      _updateItem(item.userId, FollowRequestUiStatus.deleted);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _actingUserId = null);
    }
  }

  Future<void> _openProfile(FollowRequestItem item) async {
    final result = await Navigator.of(context).pushNamed(
      Routes.followRequesterProfileRoute,
      arguments: <String, dynamic>{
        'request': followRequestItemToMap(item),
        'ownerStoreId': widget.storeId,
        'ownerStoreName': widget.storeName,
      },
    );
    if (!mounted) return;
    if (result is FollowRequestUiStatus) {
      _updateItem(item.userId, result);
    } else if (result is Map && result['uiStatus'] is String) {
      final raw = (result['uiStatus'] as String).trim().toLowerCase();
      final status = FollowRequestUiStatus.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => item.uiStatus,
      );
      if (status != item.uiStatus) {
        _updateItem(item.userId, status);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
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
                        'Follow requests',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.headline(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 14),
                _FilterSegments(
                  selected: _filter,
                  onChanged: (next) {
                    if (next == _filter) return;
                    setState(() => _filter = next);
                  },
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child:
                _loading && _items.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : rows.isEmpty
                    ? Center(
                      child: Padding(
                        padding: AppPadding.screenHorizontal,
                        child: Text(
                          'No follow requests',
                          style: AppTextStyles.bodySecondary(),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                    : ListView.separated(
                      padding: AppPadding.screen(top: 8, bottom: 16),
                      itemCount: rows.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index == rows.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 12),
                            child: Text(
                              'Tap a name to see who is asking before you '
                              "decide. Deleting a request doesn't notify them.",
                              style: AppTextStyles.caption(height: 1.4),
                            ),
                          );
                        }
                        final item = rows[index];
                        return _FollowRequestRow(
                          item: item,
                          acting: _actingUserId == item.userId,
                          onConfirm: () => _accept(item),
                          onDelete: () => _reject(item),
                          onOpenProfile: () => _openProfile(item),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic> followRequestItemToMap(FollowRequestItem item) {
  return <String, dynamic>{
    'id': item.id,
    'userId': item.userId,
    'followerType': item.followerType,
    'name': item.name,
    'storeId': item.storeId,
    'slug': item.slug,
    'avatar': item.avatar,
    'phone': item.phone,
    'city': item.city,
    'requestedAt': item.requestedAt?.toIso8601String(),
    'productCount': item.productCount,
    'uiStatus': item.uiStatus.name,
  };
}

FollowRequestItem followRequestItemFromMap(Map<dynamic, dynamic> raw) {
  final map = Map<String, dynamic>.from(raw);
  final base = FollowRequestItem.fromJson(map);
  final statusRaw = '${map['uiStatus'] ?? ''}'.trim().toLowerCase();
  final status = FollowRequestUiStatus.values.firstWhere(
    (e) => e.name == statusRaw,
    orElse: () => FollowRequestUiStatus.pending,
  );
  return base.copyWith(uiStatus: status);
}

class _FilterSegments extends StatelessWidget {
  const _FilterSegments({required this.selected, required this.onChanged});

  final _FollowRequestFilter selected;
  final ValueChanged<_FollowRequestFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final filter in _FollowRequestFilter.values)
            Expanded(
              child: _FilterChip(
                label: switch (filter) {
                  _FollowRequestFilter.all => 'All',
                  _FollowRequestFilter.stores => 'Stores',
                  _FollowRequestFilter.individuals => 'Individuals',
                },
                selected: selected == filter,
                onTap: () => onChanged(filter),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.label(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color:
                  selected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _FollowRequestRow extends StatelessWidget {
  const _FollowRequestRow({
    required this.item,
    required this.acting,
    required this.onConfirm,
    required this.onDelete,
    required this.onOpenProfile,
  });

  final FollowRequestItem item;
  final bool acting;
  final VoidCallback onConfirm;
  final VoidCallback onDelete;
  final VoidCallback onOpenProfile;

  String get _subtitle {
    if (item.isStore) {
      final n = item.productCount;
      if (n == null) return item.city?.trim().isNotEmpty == true ? '' : '';
      return n == 1 ? '1 product' : '$n products';
    }
    final phone = item.phone?.trim() ?? '';
    if (phone.isEmpty) return '';
    return _truncatePhone(phone);
  }

  static String _truncatePhone(String phone) {
    if (phone.length <= 8) return phone;
    return '${phone.substring(0, 4)}...${phone.substring(phone.length - 3)}';
  }

  @override
  Widget build(BuildContext context) {
    final city = item.city?.trim() ?? '';
    final subtitle = _subtitle;
    final decided = item.uiStatus != FollowRequestUiStatus.pending;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RequesterAvatar(item: item),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: onOpenProfile,
                              child: Text(
                                item.name.isEmpty ? 'Unknown' : item.name,
                                style: AppTextStyles.body(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _TypePill(
                            label: item.isStore ? 'Store' : 'Individual',
                          ),
                        ],
                      ),
                      if (city.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          city,
                          style: AppTextStyles.caption(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTextStyles.caption(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (item.uiStatus == FollowRequestUiStatus.approved)
              Text(
                'Approved',
                style: AppTextStyles.label(
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              )
            else if (item.uiStatus == FollowRequestUiStatus.deleted)
              Text(
                'Request deleted',
                style: AppTextStyles.label(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: acting || decided ? null : onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                        disabledBackgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child:
                          acting
                              ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.textOnPrimary,
                                ),
                              )
                              : Text(
                                'Confirm',
                                style: AppTextStyles.label(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textOnPrimary,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: acting || decided ? null : onDelete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: BorderSide(color: AppColors.border),
                        backgroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Delete',
                        style: AppTextStyles.label(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _RequesterAvatar extends StatelessWidget {
  const _RequesterAvatar({required this.item});

  final FollowRequestItem item;

  @override
  Widget build(BuildContext context) {
    final radius = item.isStore ? 10.0 : 22.0;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        item.initial,
        style: AppTextStyles.label(
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          height: 1.1,
        ),
      ),
    );
  }
}
