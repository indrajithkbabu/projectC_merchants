import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/primary_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/catalog/catalog_store.dart';
import 'package:project_c/models/catalog/follow_api_models.dart';
import 'package:project_c/models/store_privacy_mode.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/store/store_repository.dart';

/// Requester profile before approve/delete (walkthrough screens 05–06).
class FollowRequesterProfileRoute extends StatefulWidget {
  const FollowRequesterProfileRoute({
    super.key,
    required this.request,
    required this.ownerStoreId,
    required this.ownerStoreName,
    this.readOnly = false,
  });

  final FollowRequestItem request;
  final String ownerStoreId;
  final String ownerStoreName;

  /// When true (opened from Followers list), hide Confirm/Delete card.
  final bool readOnly;

  @override
  State<FollowRequesterProfileRoute> createState() =>
      _FollowRequesterProfileRouteState();
}

class _FollowRequesterProfileRouteState
    extends State<FollowRequesterProfileRoute> {
  late final StoreRepository _stores;
  late FollowRequestItem _request;
  CatalogStore? _requesterStore;
  bool _loadingStore = false;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _stores = ServiceLocator.get<StoreRepository>();
    _request = widget.request;
    if (_request.isStore) {
      final id = _request.storeId?.trim() ?? '';
      if (id.isNotEmpty) {
        _loadRequesterStore(id);
      }
    }
  }

  Future<void> _loadRequesterStore(String storeId) async {
    setState(() => _loadingStore = true);
    try {
      final store = await _stores.fetchStore(storeId);
      if (!mounted) return;
      setState(() {
        _requesterStore = store;
        _loadingStore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingStore = false);
    }
  }

  Future<void> _accept() async {
    if (_acting || _request.uiStatus != FollowRequestUiStatus.pending) return;
    setState(() => _acting = true);
    try {
      await _stores.acceptFollowRequest(
        storeId: widget.ownerStoreId,
        followerUserId: _request.userId,
      );
      if (!mounted) return;
      setState(() {
        _request = _request.copyWith(uiStatus: FollowRequestUiStatus.approved);
        _acting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _acting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(e))),
      );
    }
  }

  Future<void> _reject() async {
    if (_acting || _request.uiStatus != FollowRequestUiStatus.pending) return;
    setState(() => _acting = true);
    try {
      await _stores.rejectFollowRequest(
        storeId: widget.ownerStoreId,
        followerUserId: _request.userId,
      );
      if (!mounted) return;
      setState(() {
        _request = _request.copyWith(uiStatus: FollowRequestUiStatus.deleted);
        _acting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _acting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(e))),
      );
    }
  }

  void _popWithStatus() {
    Navigator.of(context).pop(_request.uiStatus);
  }

  @override
  Widget build(BuildContext context) {
    final name = _request.name.trim().isEmpty ? 'Unknown' : _request.name.trim();
    final ownerName =
        widget.ownerStoreName.trim().isEmpty
            ? 'your store'
            : widget.ownerStoreName.trim();

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
            child: Row(
              children: [
                AppBackButton(
                  onPressed:
                      widget.readOnly
                          ? () => Navigator.of(context).maybePop()
                          : _popWithStatus,
                ),
                Expanded(
                  child: Text(
                    name,
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
          ),
          Expanded(
            child: ListView(
              padding: AppPadding.screen(top: 4, bottom: 24),
              children: [
                if (!widget.readOnly) ...[
                  _DecisionCard(
                    name: name,
                    ownerStoreName: ownerName,
                    status: _request.uiStatus,
                    acting: _acting,
                    onConfirm: _accept,
                    onDelete: _reject,
                  ),
                  const SizedBox(height: 20),
                ],
                if (_request.isIndividual)
                  _IndividualBody(request: _request)
                else
                  _StoreBody(
                    request: _request,
                    store: _requesterStore,
                    loading: _loadingStore,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({
    required this.name,
    required this.ownerStoreName,
    required this.status,
    required this.acting,
    required this.onConfirm,
    required this.onDelete,
  });

  final String name;
  final String ownerStoreName;
  final FollowRequestUiStatus status;
  final bool acting;
  final VoidCallback onConfirm;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (status == FollowRequestUiStatus.approved)
              Text(
                'Approved · they can see your products',
                style: AppTextStyles.body(
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              )
            else if (status == FollowRequestUiStatus.deleted)
              Text(
                'Request deleted.',
                style: AppTextStyles.body(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              )
            else ...[
              Text(
                '$name wants to follow $ownerStoreName. If you confirm, '
                'they can see your products and photos.',
                style: AppTextStyles.body(height: 1.4),
              ),
              const SizedBox(height: 14),
              PrimaryButton(
                label: 'Confirm',
                isLoading: acting,
                onPressed: acting ? null : onConfirm,
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: acting ? null : onDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: BorderSide(color: AppColors.border),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
            ],
          ],
        ),
      ),
    );
  }
}

class _IndividualBody extends StatelessWidget {
  const _IndividualBody({required this.request});

  final FollowRequestItem request;

  @override
  Widget build(BuildContext context) {
    final city = request.city?.trim() ?? '';
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Text(
            request.initial,
            style: AppTextStyles.title(
              fontSize: 36,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _StatRow(
          following: '—',
          products: '—',
          followers: '—',
        ),
        const SizedBox(height: 12),
        const _TypePill(label: 'Individual'),
        const SizedBox(height: 10),
        Text(
          city.isEmpty
              ? 'Individual buyer'
              : 'Individual buyer · $city',
          style: AppTextStyles.bodySecondary(fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Individual accounts don't have a store or products. "
                    'They follow stores to browse jewellery privately.',
                    style: AppTextStyles.caption(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StoreBody extends StatelessWidget {
  const _StoreBody({
    required this.request,
    required this.store,
    required this.loading,
  });

  final FollowRequestItem request;
  final CatalogStore? store;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final city = (store?.city.trim().isNotEmpty == true)
        ? store!.city.trim()
        : (request.city?.trim() ?? '');
    final products =
        store?.productCount ?? request.productCount;
    final followers = store?.followerCount;
    final following = store?.followingCount;
    final privacy = store?.privacy;
    final avatarUrl =
        (request.avatar?.trim().isNotEmpty == true)
            ? request.avatar!.trim()
            : (store?.coverImageUrl ?? '');
    final canView = store?.resolvedCanViewContent;

    final metaParts = <String>[
      'Jewellery store',
      if (city.isNotEmpty) city,
      if (privacy != null) privacy.label,
    ];

    return Column(
      children: [
        _StoreLogo(initial: request.initial, avatarUrl: avatarUrl),
        const SizedBox(height: 16),
        _StatRow(
          products: products == null ? '—' : '$products',
          followers: followers == null ? '—' : '$followers',
          following: following == null ? '—' : '$following',
          storeLayout: true,
        ),
        const SizedBox(height: 12),
        const _TypePill(label: 'Store'),
        const SizedBox(height: 10),
        Text(
          metaParts.join(' · '),
          style: AppTextStyles.bodySecondary(fontSize: 14),
          textAlign: TextAlign.center,
        ),
        if (loading) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 2),
        ],
        if (canView == true) ...[
          const SizedBox(height: 16),
          Text(
            'You can already see this store\'s products.',
            style: AppTextStyles.caption(height: 1.4),
            textAlign: TextAlign.center,
          ),
        ] else if (canView == false) ...[
          const SizedBox(height: 16),
          Text(
            'This store keeps products private until you follow.',
            style: AppTextStyles.caption(height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _StoreLogo extends StatelessWidget {
  const _StoreLogo({required this.initial, required this.avatarUrl});

  final String initial;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final hasUrl = avatarUrl.trim().isNotEmpty;
    return Container(
      width: 96,
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        image:
            hasUrl
                ? DecorationImage(
                  image: CachedNetworkImageProvider(avatarUrl),
                  fit: BoxFit.cover,
                )
                : null,
      ),
      child:
          hasUrl
              ? null
              : Text(
                initial,
                style: AppTextStyles.title(
                  fontSize: 36,
                  color: AppColors.primary,
                ),
              ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.following,
    required this.products,
    required this.followers,
    this.storeLayout = false,
  });

  final String following;
  final String products;
  final String followers;
  final bool storeLayout;

  @override
  Widget build(BuildContext context) {
    final cells =
        storeLayout
            ? <(String, String)>[
              (products, 'Products'),
              (followers, 'Followers'),
              (following, 'Following'),
            ]
            : <(String, String)>[
              (following, 'Following'),
              (products, 'Products'),
              (followers, 'Followers'),
            ];

    return Row(
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                Text(
                  cells[i].$1,
                  style: AppTextStyles.headline(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cells[i].$2,
                  style: AppTextStyles.caption(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          height: 1.1,
        ),
      ),
    );
  }
}
