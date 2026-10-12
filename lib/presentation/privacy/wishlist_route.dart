import 'package:flutter/material.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/app_shimmer.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/shell_tab_title_bar.dart';
import 'package:project_c/models/catalog/wishlist_api_models.dart';
import 'package:project_c/models/product_details_feed_item.dart';
import 'package:project_c/models/store_privacy_mode.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/privacy/privacy_widgets/wishlist_item_card.dart';
import 'package:project_c/services/wishlist_prefetcher.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/store/store_repository.dart';
import 'package:project_c/webservice/wishlist/wishlist_repository.dart';

/// Wishlist tab / body (walkthrough screen 12) — photo likes via catalog API.
class WishlistRoute extends StatefulWidget {
  const WishlistRoute({
    super.key,
    this.onBack,
    this.bottomInset = 0,
    this.embeddedInShell = false,
    this.refreshSignal = 0,
  });

  final VoidCallback? onBack;

  /// Extra bottom padding (e.g. shell floating nav reserved height).
  final double bottomInset;

  /// Shell tab: match Stores/Contacts title size + status-bar padding.
  final bool embeddedInShell;

  /// Bump from the shell when the Wishlist tab is selected so likes appear
  /// without remounting (quiet refresh when items already painted).
  final int refreshSignal;

  @override
  State<WishlistRoute> createState() => _WishlistRouteState();
}

class _WishlistRouteState extends State<WishlistRoute> {
  late final WishlistRepository _wishlist;
  late final StoreRepository _stores;

  List<WishlistItem> _items = const [];
  String? _nextCursor;
  /// Shell tab never blocks on shimmer — paint warm/empty then quiet-fill.
  bool _loading = false;
  bool _loadingMore = false;
  String? _busyId;
  String? _followBusyStoreId;
  String? _storeFilterId;

  @override
  void initState() {
    super.initState();
    _wishlist = ServiceLocator.get<WishlistRepository>();
    _stores = ServiceLocator.get<StoreRepository>();
    final warm = WishlistPrefetcher.instance.peek();
    if (warm != null) {
      _items = warm.items;
      _nextCursor = warm.nextCursor;
      // Quiet refresh in background so tab open stays instant.
      _load(reset: true, quiet: true);
    } else if (widget.embeddedInShell) {
      // Join auth/home prefetch — no shimmer while waiting.
      _load(reset: true, quiet: true, preferPrefetch: true);
    } else {
      _loading = true;
      _load(reset: true);
    }
  }

  @override
  void didUpdateWidget(covariant WishlistRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshSignal != oldWidget.refreshSignal &&
        widget.refreshSignal > 0) {
      _load(reset: true, quiet: true, forceRefresh: true);
    }
  }

  Future<void> _load({
    required bool reset,
    bool quiet = false,
    bool preferPrefetch = false,
    bool forceRefresh = false,
  }) async {
    if (reset) {
      if (quiet || widget.embeddedInShell) {
        // Keep painted items; never flash shimmer on the shell tab.
        setState(() => _nextCursor = null);
      } else {
        setState(() {
          _loading = true;
          _nextCursor = null;
        });
      }
    } else {
      if (_loadingMore || _nextCursor == null) return;
      setState(() => _loadingMore = true);
    }
    try {
      final WishlistPage page;
      if (reset && (preferPrefetch || forceRefresh || widget.embeddedInShell)) {
        page =
            forceRefresh
                ? await WishlistPrefetcher.instance.refresh()
                : await WishlistPrefetcher.instance.ensure();
        if (!forceRefresh) {
          // ensure() may return a stale warm page — adopt + still ok.
          WishlistPrefetcher.instance.adopt(page);
        }
      } else if (reset) {
        page = await _wishlist.fetchWishlist(status: 'all');
        WishlistPrefetcher.instance.adopt(page);
      } else {
        page = await _wishlist.fetchWishlist(
          cursor: _nextCursor,
          status: 'all',
        );
      }
      if (!mounted) return;
      setState(() {
        _items = reset ? page.items : [..._items, ...page.items];
        _nextCursor = page.nextCursor;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(e))),
      );
    }
  }

  List<WishlistItem> get _visible {
    final id = _storeFilterId;
    if (id == null || id.isEmpty) return _items;
    return _items.where((e) => e.store.id == id).toList(growable: false);
  }

  Map<String, int> get _storeCounts {
    final map = <String, int>{};
    for (final item in _items) {
      final id = item.store.id.trim();
      if (id.isEmpty) continue;
      map[id] = (map[id] ?? 0) + 1;
    }
    return map;
  }

  Map<String, String> get _storeNames {
    final map = <String, String>{};
    for (final item in _items) {
      final id = item.store.id.trim();
      if (id.isEmpty) continue;
      map.putIfAbsent(
        id,
        () =>
            item.store.name.trim().isEmpty
                ? 'Store'
                : item.store.name.trim(),
      );
    }
    return map;
  }

  Future<void> _remove(WishlistItem item) async {
    final id = item.id.trim();
    if (id.isEmpty || _busyId != null) return;
    setState(() => _busyId = id);
    try {
      // Prefer photo unlike when ids are known (keeps server likeCount in sync).
      final assetId = item.assetId.trim();
      final listingId = item.listingId.trim();
      if (item.isActive && assetId.isNotEmpty && listingId.isNotEmpty) {
        try {
          await _wishlist.unlikePhoto(
            listingId: listingId,
            photoId: assetId,
            storeId: item.store.id.trim().isEmpty ? null : item.store.id.trim(),
          );
        } catch (_) {
          await _wishlist.removeWishlistItem(id);
        }
      } else {
        await _wishlist.removeWishlistItem(id);
      }
      if (!mounted) return;
      setState(() {
        _items = _items.where((e) => e.id != id).toList(growable: false);
        _busyId = null;
        if (_storeFilterId != null &&
            !_items.any((e) => e.store.id == _storeFilterId)) {
          _storeFilterId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(e))),
      );
    }
  }

  Future<void> _followLocked(WishlistItem item) async {
    final storeId = item.store.id.trim();
    if (storeId.isEmpty || _followBusyStoreId != null) return;
    final cancel = item.store.followStatus.isPending;
    setState(() => _followBusyStoreId = storeId);
    try {
      final result =
          cancel
              ? await _stores.unfollowStore(storeId)
              : await _stores.followStore(storeId);
      if (!mounted) return;
      final nextStatus =
          cancel ? StoreFollowStatus.none : result.status;
      setState(() {
        _items =
            _items.map((e) {
              if (e.store.id != storeId) return e;
              return e.copyWith(
                store: e.store.copyWith(followStatus: nextStatus),
              );
            }).toList(growable: false);
        _followBusyStoreId = null;
      });
      if (!cancel && nextStatus.isFollowing) {
        // Access restored — reload so locked stubs can become active.
        await _load(reset: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _followBusyStoreId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(e))),
      );
    }
  }

  StoreProduct _productFromItem(WishlistItem item) {
    return StoreProduct(
      id: item.listingId.trim(),
      title: item.displayTitle,
      description: item.description,
      tags: [
        if (item.tag.isNotEmpty) item.tag,
      ],
      imagePaths:
          item.photo.url.trim().isEmpty
              ? const <String>[]
              : [item.photo.url],
      photoAssetIds:
          item.assetId.trim().isEmpty
              ? const <String>[]
              : [item.assetId],
      imageThumbhashes:
          (item.photo.thumbhash?.trim().isNotEmpty ?? false)
              ? [item.photo.thumbhash!.trim()]
              : const <String>[],
    );
  }

  String _storeLinkFor(WishlistItem item) {
    final slug = item.store.slug.trim();
    return slug.isEmpty ? '' : '$slug.jewelflow.app';
  }

  /// Active items with a photo — swipe feed for product details.
  List<WishlistItem> get _swipeableVisible =>
      _visible
          .where(
            (e) =>
                e.isActive &&
                e.listingId.trim().isNotEmpty &&
                e.store.id.trim().isNotEmpty &&
                e.photo.url.trim().isNotEmpty,
          )
          .toList(growable: false);

  Future<void> _openItem(WishlistItem item) async {
    if (item.isLocked) {
      final storeId = item.store.id.trim();
      if (storeId.isEmpty) return;
      await Navigator.of(context).pushNamed(
        Routes.storeProfileRoute,
        arguments: <String, Object?>{
          'storeId': storeId,
          'storeName': item.store.name,
          if (item.store.slug.isNotEmpty)
            'storeLink': '${item.store.slug}.jewelflow.app',
          'isOwnStore': false,
        },
      );
      if (mounted) await _load(reset: true, quiet: true);
      return;
    }
    final listingId = item.listingId.trim();
    final storeId = item.store.id.trim();
    if (listingId.isEmpty || storeId.isEmpty) return;

    final swipeable = _swipeableVisible;
    final feedIndex = swipeable.indexWhere((e) => e.id == item.id);
    final feed =
        swipeable
            .map((e) {
              final product = _productFromItem(e);
              final path =
                  product.imagePaths.isEmpty ? '' : product.imagePaths.first;
              final link = _storeLinkFor(e);
              return ProductDetailsFeedItem(
                product: product,
                imageIndex: 0,
                path: path,
                storeId: e.store.id.trim(),
                storeName:
                    e.store.name.trim().isEmpty ? null : e.store.name.trim(),
                storeLink: link.isEmpty ? null : link,
              );
            })
            .toList(growable: false);

    final product = _productFromItem(item);
    final link = _storeLinkFor(item);
    final likedIds = <String>{
      for (final e in swipeable)
        if (e.assetId.trim().isNotEmpty) e.assetId.trim(),
    };

    await Navigator.of(context).pushNamed(
      Routes.productDetailsRoute,
      arguments: <String, Object?>{
        'product': product,
        'storeId': storeId,
        'storeName': item.store.name,
        if (link.isNotEmpty) 'storeLink': link,
        'isOwnStore': false,
        'imageIndex': 0,
        if (likedIds.isNotEmpty) 'likedPhotoIds': likedIds.toList(),
        if (item.assetId.trim().isNotEmpty)
          'likedPhotoId': item.assetId.trim(),
        if (feed.isNotEmpty) 'galleryFeed': feed,
        if (feed.isNotEmpty)
          'galleryFeedIndex': feedIndex < 0 ? 0 : feedIndex,
      },
    );
    // Pick up likes/unlikes made in product details without remount shimmer.
    if (mounted) await _load(reset: true, quiet: true);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final storeCounts = _storeCounts;
    final storeNames = _storeNames;
    final total = _items.length;
    final storeCount = storeCounts.length;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding:
              widget.embeddedInShell
                  ? ShellTabTitleBar.padding(context)
                  : AppPadding.screen(top: 4, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.embeddedInShell)
                const ShellTabTitleBar(title: 'Wishlist')
              else
                Row(
                  children: [
                    if (widget.onBack != null)
                      AppBackButton(onPressed: widget.onBack),
                    Expanded(
                      child: Text(
                        'Wishlist',
                        style: AppTextStyles.headline(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              Text(
                '$total liked items from $storeCount stores',
                style: AppTextStyles.bodySecondary(fontSize: 14),
              ),
              if (storeCounts.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'All $total',
                        selected: _storeFilterId == null,
                        onTap: () => setState(() => _storeFilterId = null),
                      ),
                      const SizedBox(width: 8),
                      for (final entry in storeCounts.entries) ...[
                        _FilterChip(
                          label:
                              '${storeNames[entry.key] ?? 'Store'} ${entry.value}',
                          selected: _storeFilterId == entry.key,
                          onTap:
                              () => setState(
                                () => _storeFilterId = entry.key,
                              ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child:
              // Shell tab: never shimmer (warm/prefetch paints immediately).
              _loading && !widget.embeddedInShell
                  ? const _WishlistShimmer()
                  : visible.isEmpty
                  ? Center(
                    child: Padding(
                      padding: AppPadding.screenHorizontal,
                      child: Text(
                        _items.isEmpty
                            ? 'Liked photos appear here.'
                            : 'No items from this store.',
                        style: AppTextStyles.bodySecondary(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                  : NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (_nextCursor == null || _loadingMore) return false;
                      if (n.metrics.pixels <
                          n.metrics.maxScrollExtent - 240) {
                        return false;
                      }
                      _load(reset: false);
                      return false;
                    },
                    child: RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh:
                          () => _load(
                            reset: true,
                            quiet: widget.embeddedInShell,
                            forceRefresh: true,
                          ),
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: [
                          SliverPadding(
                            padding: AppPadding.screen(top: 4, bottom: 8),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    // Equal width & height for every tile.
                                    childAspectRatio: 1,
                                  ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final item = visible[index];
                                  return WishlistItemCard(
                                    item: item,
                                    onTap: () => _openItem(item),
                                    onRemove: () => _remove(item),
                                    onFollow:
                                        item.isLocked
                                            ? () => _followLocked(item)
                                            : null,
                                    isFollowBusy:
                                        _followBusyStoreId == item.store.id,
                                    isRemoveBusy: _busyId == item.id,
                                  );
                                },
                                childCount: visible.length,
                              ),
                            ),
                          ),
                          if (_loadingMore)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
        ),
        Padding(
          padding: AppPadding.screen(bottom: 24),
          child: Text(
            'Only you can see your Wishlist. Stores see a like count, '
            'never the list.',
            style: AppTextStyles.caption(height: 1.4),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );

    if (widget.bottomInset <= 0) return body;
    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomInset),
      child: body,
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
      color:
          selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  selected
                      ? AppColors.primary.withValues(alpha: 0.35)
                      : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.label(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color:
                  selected ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _WishlistShimmer extends StatefulWidget {
  const _WishlistShimmer();

  @override
  State<_WishlistShimmer> createState() => _WishlistShimmerState();
}

class _WishlistShimmerState extends State<_WishlistShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return GridView.builder(
          padding: AppPadding.screen(top: 4, bottom: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemCount: 6,
          itemBuilder: (_, __) {
            return Container(
              decoration: AppShimmer.box(t, radius: 12),
            );
          },
        );
      },
    );
  }
}
