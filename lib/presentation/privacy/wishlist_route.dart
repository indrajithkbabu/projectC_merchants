import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/app_shimmer.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/shell_tab_title_bar.dart';
import 'package:project_c/models/catalog/wishlist_api_models.dart';
import 'package:project_c/models/product_details_feed_item.dart';
import 'package:project_c/models/store_privacy_mode.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/privacy/privacy_widgets/wishlist_item_card.dart';
import 'package:project_c/presentation/search/search_models.dart';
import 'package:project_c/presentation/search/search_widgets/search_app_bar_field.dart';
import 'package:project_c/presentation/search/search_widgets/search_filter_bar.dart';
import 'package:project_c/services/wishlist_prefetcher.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/store/store_repository.dart';
import 'package:project_c/webservice/wishlist/wishlist_repository.dart';

/// Wishlist tab / body (walkthrough screen 12) — private bookmarks via catalog API.
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

class _WishlistRouteState extends State<WishlistRoute>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  /// Pinch zoom-in → fewer cells (min 2). Zoom-out → denser grid (max 9).
  /// Default matches the existing 2-column wishlist layout.
  static const _minColumns = 2.0;
  static const _maxColumns = 9.0;

  late final WishlistRepository _wishlist;
  late final StoreRepository _stores;
  late final TextEditingController _searchCtrl;
  late final FocusNode _searchFocus;
  late final ScrollController _scrollController;
  late final AnimationController _chromeAnim;
  late final Animation<double> _chromeFactor;
  late final AnimationController _columnSnap;
  final GlobalKey _chromeKey = GlobalKey();

  List<WishlistItem> _items = const [];
  String? _nextCursor;
  /// Shell tab never blocks on shimmer — paint warm/empty then quiet-fill.
  bool _loading = false;
  bool _loadingMore = false;
  String? _busyId;
  String? _followBusyStoreId;
  SearchFilterSelection _filters = const SearchFilterSelection();
  bool _chromeVisible = true;
  double _measuredChromeHeight = 0;
  double _prevChromeAnimValue = 1;
  /// True after the soft keyboard was clearly open while search was focused.
  /// Used so swipe/back IME dismiss can clear stuck focus without racing the
  /// open animation (which can briefly report inset 0).
  bool _sawImeWhileFocused = false;
  Timer? _imeDismissUnfocusTimer;
  /// Suppresses scroll-collapse while chrome animates or search is focusing.
  bool _suppressScrollCollapse = false;
  Timer? _suppressScrollCollapseTimer;

  /// Continuous column count while pinching (snaps to int on release).
  double _columns = _minColumns;
  double _pinchBaseColumns = _minColumns;
  bool _pinching = false;
  final Map<int, Offset> _pinchPointers = <int, Offset>{};
  double? _pinchStartDistance;
  int _lastWarmedColumns = _minColumns.toInt();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wishlist = ServiceLocator.get<WishlistRepository>();
    _stores = ServiceLocator.get<StoreRepository>();
    _searchCtrl = TextEditingController();
    _searchFocus = FocusNode();
    _scrollController = ScrollController();
    _searchCtrl.addListener(() => setState(() {}));
    _searchFocus.addListener(_onSearchFocusChanged);
    _chromeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1,
    )..addListener(_compensateScrollForChrome);
    _chromeFactor = CurvedAnimation(
      parent: _chromeAnim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _columnSnap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _imeDismissUnfocusTimer?.cancel();
    _suppressScrollCollapseTimer?.cancel();
    _chromeAnim.removeListener(_compensateScrollForChrome);
    _chromeAnim.dispose();
    _columnSnap.dispose();
    _scrollController.dispose();
    _searchFocus.removeListener(_onSearchFocusChanged);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  int get _crossAxisCount =>
      _columns.round().clamp(_minColumns.toInt(), _maxColumns.toInt());

  double _gridSpacing(int cols) {
    if (cols >= 6) return 2;
    if (cols >= 4) return 4;
    return 10;
  }

  List<String> get _photoUrls => [
    for (final item in _items)
      if (!item.isLocked && item.photo.url.trim().startsWith('http'))
        item.photo.url.trim(),
  ];

  void _warmWishlistGrid({required int columns}) {
    final urls = _photoUrls;
    if (urls.isEmpty) return;
    final warmCount = CatalogImageCache.mediaGridWarmCount(columns: columns);
    // ignore: unawaited_futures
    CatalogImageCache.warmWindow(
      urls: urls,
      firstIndex: 0,
      lastIndex: math.min(urls.length - 1, warmCount - 1),
      cacheWidth: CatalogImageCache.gridCacheWidth(),
    );
    _lastWarmedColumns = math.max(_lastWarmedColumns, columns);
  }

  double? _pinchFingerDistance() {
    if (_pinchPointers.length < 2) return null;
    final pts = _pinchPointers.values.toList(growable: false);
    return (pts[0] - pts[1]).distance;
  }

  void _onPinchPointerDown(PointerDownEvent event) {
    _pinchPointers[event.pointer] = event.position;
    if (_pinchPointers.length == 2 && !_pinching) {
      _pinchStartDistance = _pinchFingerDistance();
      if (_pinchStartDistance != null && _pinchStartDistance! >= 12) {
        _onPinchStart(_columns);
      }
    }
  }

  void _onPinchPointerMove(PointerMoveEvent event) {
    if (!_pinchPointers.containsKey(event.pointer)) return;
    _pinchPointers[event.pointer] = event.position;
    if (!_pinching || _pinchPointers.length < 2) return;
    final start = _pinchStartDistance;
    final now = _pinchFingerDistance();
    if (start == null || now == null || start < 12) return;
    _onPinchUpdate(now / start);
  }

  void _onPinchPointerEnd(PointerEvent event) {
    _pinchPointers.remove(event.pointer);
    if (_pinching && _pinchPointers.length < 2) {
      _pinchStartDistance = null;
      _onPinchEnd();
    }
  }

  void _onPinchStart(double baseColumns) {
    _searchFocus.unfocus();
    _columnSnap.stop();
    setState(() {
      _pinching = true;
      _pinchBaseColumns = baseColumns;
    });
  }

  void _onPinchUpdate(double scale) {
    if (!_pinching || !scale.isFinite || scale <= 0) return;
    // Pinch out (scale > 1) → fewer columns (zoom in). Pinch in → more columns.
    final next = (_pinchBaseColumns / scale).clamp(_minColumns, _maxColumns);
    if ((next - _columns).abs() < 0.008) return;
    setState(() => _columns = next);
    final cols = next.round().clamp(_minColumns.toInt(), _maxColumns.toInt());
    if (cols > _lastWarmedColumns) {
      _warmWishlistGrid(columns: cols);
    }
  }

  void _onPinchEnd() {
    if (!_pinching) return;
    final from = _columns;
    final to =
        from
            .round()
            .clamp(_minColumns.toInt(), _maxColumns.toInt())
            .toDouble();
    setState(() => _pinching = false);
    _warmWishlistGrid(columns: to.toInt());
    if ((from - to).abs() < 0.02) {
      if (from != to) setState(() => _columns = to);
      return;
    }
    final anim = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(parent: _columnSnap, curve: Curves.easeOutCubic),
    );
    void tick() {
      if (!mounted) return;
      setState(() => _columns = anim.value);
    }

    anim.addListener(tick);
    _columnSnap.forward(from: 0).whenComplete(() {
      anim.removeListener(tick);
      if (!mounted) return;
      setState(() => _columns = to);
    });
  }

  double _imeBottomInset(BuildContext context) {
    final mq = MediaQuery.viewInsetsOf(context).bottom;
    // Prefer the larger signal — shell uses resizeToAvoidBottomInset: false
    // and swipe-dismiss can update View insets before MediaQuery in some builds.
    final view = View.maybeOf(context);
    if (view == null) return mq;
    final fromView = view.viewInsets.bottom / view.devicePixelRatio;
    return math.max(mq, fromView);
  }

  void _unfocusSearchIfImeClosed() {
    if (!_searchFocus.hasFocus) return;
    if (_imeBottomInset(context) > 0) return;
    _sawImeWhileFocused = false;
    _searchFocus.unfocus();
  }

  void _scheduleUnfocusAfterImeDismiss() {
    _imeDismissUnfocusTimer?.cancel();
    _imeDismissUnfocusTimer = Timer(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      if (_imeBottomInset(context) > 0) return;
      _unfocusSearchIfImeClosed();
    });
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final inset = _imeBottomInset(context);

    // Require a real open (threshold) so the open animation's inset flicker
    // cannot arm a false dismiss.
    if (_searchFocus.hasFocus && inset > 48) {
      _sawImeWhileFocused = true;
      _imeDismissUnfocusTimer?.cancel();
      _imeDismissUnfocusTimer = null;
      return;
    }

    if (_sawImeWhileFocused && inset <= 0 && _searchFocus.hasFocus) {
      // Swipe-down / back hid the keypad but left the FocusNode hot.
      _scheduleUnfocusAfterImeDismiss();
    }
    if (!_searchFocus.hasFocus) {
      _sawImeWhileFocused = false;
    }
  }

  void _onSearchFocusChanged() {
    if (_searchFocus.hasFocus) {
      _pauseScrollCollapse();
      _setChromeVisible(true);
      // If IME is already gone when focus flips on, do not arm dismiss logic.
      if (_imeBottomInset(context) <= 0) {
        _sawImeWhileFocused = false;
      }
    } else {
      _sawImeWhileFocused = false;
      _imeDismissUnfocusTimer?.cancel();
      _imeDismissUnfocusTimer = null;
    }
  }

  void _pauseScrollCollapse({
    Duration hold = const Duration(milliseconds: 320),
  }) {
    _suppressScrollCollapse = true;
    _suppressScrollCollapseTimer?.cancel();
    _suppressScrollCollapseTimer = Timer(hold, () {
      if (mounted) _suppressScrollCollapse = false;
    });
  }

  /// Approx. height of the first wishlist grid row at the current column count.
  double _firstRowExtent(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cols = _crossAxisCount;
    final spacing = _gridSpacing(cols);
    final tile =
        (width - AppPadding.horizontal * 2 - spacing * (cols - 1)) / cols;
    return tile + spacing;
  }

  /// Collapse when the IME is closed. Stuck focus after swipe-dismiss must not
  /// block minimize — unfocus runs on IME dismiss and on user scroll.
  bool get _canCollapseChrome =>
      !_loading &&
      _visible.length > 2 &&
      !_pinching &&
      !_suppressScrollCollapse &&
      !_chromeAnim.isAnimating &&
      _imeBottomInset(context) <= 0;

  void _captureChromeHeight() {
    final box = _chromeKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && box.size.height > 0) {
      _measuredChromeHeight = box.size.height;
    }
  }

  void _compensateScrollForChrome() {
    if (!_scrollController.hasClients) {
      _prevChromeAnimValue = _chromeAnim.value;
      return;
    }
    final height = _measuredChromeHeight;
    if (height <= 0) {
      _prevChromeAnimValue = _chromeAnim.value;
      return;
    }
    final value = _chromeAnim.value;
    // Collapsing (1→0): viewport grows from top → bump scroll to keep items still.
    final delta = height * (_prevChromeAnimValue - value);
    _prevChromeAnimValue = value;
    if (delta.abs() < 0.05) return;

    final pos = _scrollController.position;
    final maxExtent = math.max(pos.maxScrollExtent, pos.pixels + delta);
    final next = (pos.pixels + delta).clamp(pos.minScrollExtent, maxExtent);
    if ((next - pos.pixels).abs() < 0.05) return;
    _scrollController.jumpTo(next.toDouble());
  }

  void _setChromeVisible(bool visible) {
    if (_chromeVisible == visible) return;
    if (_chromeVisible) {
      _captureChromeHeight();
    }
    _chromeVisible = visible;
    if (visible) {
      _chromeAnim.forward();
    } else {
      _searchFocus.unfocus();
      _chromeAnim.reverse();
    }
  }

  bool _onGridScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    // Pagination
    if (_nextCursor != null &&
        !_loadingMore &&
        notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 240) {
      _load(reset: false);
    }

    if (notification is! ScrollUpdateNotification) return false;

    // Ignore layout/IME/jumpTo corrections — only user scrolls toggle chrome.
    final userDriven =
        notification.dragDetails != null ||
        (_scrollController.hasClients &&
            _scrollController.position.userScrollDirection !=
                ScrollDirection.idle);
    if (!userDriven) return false;

    // Swipe-dismissed keypad often leaves the field focused — clear it so
    // minimize can run on this / the next scroll update.
    _unfocusSearchIfImeClosed();

    if (!_canCollapseChrome) {
      if (!_chromeVisible && _imeBottomInset(context) <= 0) {
        _setChromeVisible(true);
      }
      return false;
    }

    final pixels = notification.metrics.pixels;
    final delta = notification.scrollDelta ?? 0;
    final topZone = _firstRowExtent(context);

    // Expand again when the first row is back in view (scroll up).
    if (pixels <= topZone) {
      if (!_chromeVisible) _setChromeVisible(true);
      return false;
    }

    // Collapse when scrolling down past the first row.
    if (delta > 2 && _chromeVisible) {
      _setChromeVisible(false);
    }
    return false;
  }

  void _expandChromeAndFocusSearch() {
    _pauseScrollCollapse();
    _setChromeVisible(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocus.requestFocus();
    });
  }

  Widget _collapsedChromeActions() {
    final filtersActive =
        _filters.hasActiveFilters ||
        _filters.sort != SearchSortOption.newest;
    final queryActive = _searchCtrl.text.trim().isNotEmpty;
    return AnimatedBuilder(
      animation: _chromeAnim,
      builder: (context, child) {
        final t = (1.0 - _chromeAnim.value).clamp(0.0, 1.0);
        if (t < 0.04) return const SizedBox.shrink();
        return Opacity(
          opacity: Curves.easeOutCubic.transform(t),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: ShellTabTitleBar.rowHeight,
            child: IconButton(
              tooltip: 'Search',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: ShellTabTitleBar.rowHeight,
              ),
              onPressed: _expandChromeAndFocusSearch,
              icon: Badge(
                isLabelVisible: queryActive,
                smallSize: 8,
                backgroundColor: AppColors.primary,
                child: Icon(
                  Icons.search_rounded,
                  size: 24,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          if (_items.isNotEmpty)
            SizedBox(
              width: 40,
              height: ShellTabTitleBar.rowHeight,
              child: IconButton(
                tooltip: 'Sort & Filter',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: ShellTabTitleBar.rowHeight,
                ),
                onPressed: _openAllFilters,
                icon: Badge(
                  isLabelVisible: filtersActive,
                  smallSize: 8,
                  backgroundColor: AppColors.primary,
                  child: Icon(
                    Icons.tune_rounded,
                    size: 22,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void didUpdateWidget(covariant WishlistRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshSignal != oldWidget.refreshSignal &&
        widget.refreshSignal > 0) {
      // Leaving + returning to the shell tab must not keep a typed query.
      if (_searchCtrl.text.isNotEmpty) {
        _searchCtrl.clear();
      }
      _searchFocus.unfocus();
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
        page = await _wishlist.fetchWishlist();
        WishlistPrefetcher.instance.adopt(page);
      } else {
        page = await _wishlist.fetchWishlist(cursor: _nextCursor);
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

  String get _query => _searchCtrl.text.trim().toLowerCase();

  SearchFilterCatalog get _catalog => _catalogFromItems(_items);

  List<WishlistItem> get _visible =>
      _filterItems(_items, filters: _filters, query: _query);

  List<WishlistItem> _filterItems(
    List<WishlistItem> source, {
    required SearchFilterSelection filters,
    required String query,
  }) {
    final q = query.trim().toLowerCase();
    final metals = filters.metals;
    final purities = filters.purities;
    final stores = filters.stores;
    var list =
        source.where((item) {
          if (stores.isNotEmpty && !stores.contains(item.store.id.trim())) {
            return false;
          }
          if (metals.isNotEmpty) {
            final itemMetals = item.metalFilterValues;
            if (itemMetals.isEmpty || !itemMetals.any(metals.contains)) {
              return false;
            }
          }
          if (purities.isNotEmpty) {
            final p = item.purityFilterValue;
            if (p.isEmpty || !purities.contains(p)) return false;
          }
          if (q.isEmpty) return true;
          final hay =
              '${item.displayTitle} ${item.collectionName} ${item.tag} '
              '${item.store.name} ${item.metalFilterValues.join(' ')} '
              '${item.purityLabel}'.toLowerCase();
          return hay.contains(q);
        }).toList();

    switch (filters.sort) {
      case SearchSortOption.newest:
      case SearchSortOption.popular:
      case SearchSortOption.mostViewed:
        // Wishlist API has no viewCount / likeCount — newest (likedAt) fallback.
        list.sort((a, b) {
          final at = a.likedAt?.millisecondsSinceEpoch ?? 0;
          final bt = b.likedAt?.millisecondsSinceEpoch ?? 0;
          return bt.compareTo(at);
        });
      case SearchSortOption.lightest:
        list.sort((a, b) {
          final aw = a.weightSortValue ?? double.infinity;
          final bw = b.weightSortValue ?? double.infinity;
          return aw.compareTo(bw);
        });
      case SearchSortOption.heaviest:
        list.sort((a, b) {
          final aw = a.weightSortValue ?? -double.infinity;
          final bw = b.weightSortValue ?? -double.infinity;
          return bw.compareTo(aw);
        });
    }
    return list;
  }

  SearchFilterCatalog _catalogFromItems(List<WishlistItem> items) {
    final metalCounts = <String, int>{};
    final purityCounts = <String, int>{};
    final storeCounts = <String, int>{};
    final storeNames = <String, String>{};
    for (final item in items) {
      for (final m in item.metalFilterValues) {
        metalCounts[m] = (metalCounts[m] ?? 0) + 1;
      }
      final p = item.purityFilterValue;
      if (p.isNotEmpty) purityCounts[p] = (purityCounts[p] ?? 0) + 1;
      final sid = item.store.id.trim();
      if (sid.isNotEmpty) {
        storeCounts[sid] = (storeCounts[sid] ?? 0) + 1;
        storeNames.putIfAbsent(
          sid,
          () =>
              item.store.name.trim().isEmpty
                  ? 'Store'
                  : item.store.name.trim(),
        );
      }
    }
    final metalKeys = metalCounts.keys.toList()..sort();
    final purityKeys = purityCounts.keys.toList()..sort();
    final storeKeys = storeCounts.keys.toList()
      ..sort(
        (a, b) => (storeNames[a] ?? a).compareTo(storeNames[b] ?? b),
      );
    return SearchFilterCatalog(
      metals: [
        for (final k in metalKeys)
          SearchFilterOption(
            value: k,
            label: _metalLabel(k),
            count: metalCounts[k] ?? 0,
          ),
      ],
      purities: [
        for (final k in purityKeys)
          SearchFilterOption(
            value: k,
            label: k.endsWith('%') ? k : '$k%',
            count: purityCounts[k] ?? 0,
          ),
      ],
      stores: [
        for (final k in storeKeys)
          SearchFilterOption(
            value: k,
            label: storeNames[k] ?? 'Store',
            count: storeCounts[k] ?? 0,
          ),
      ],
    );
  }

  static String _metalLabel(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  void _applyFilters(SearchFilterSelection next) {
    setState(() => _filters = next);
  }

  Future<void> _openAllFilters() async {
    _searchFocus.unfocus();
    final catalog = _catalog;
    final next = await Navigator.of(context).pushNamed(
      Routes.searchFiltersRoute,
      arguments: <String, Object?>{
        'scope': SearchFilterScope.wishlist,
        'initial': _filters,
        'initialCatalog': catalog,
        'initialTotal': _visible.length,
        'loadPreview': (SearchFilterSelection selection) async {
          final count =
              _filterItems(
                _items,
                filters: selection,
                query: _query,
              ).length;
          return (catalog: _catalogFromItems(_items), totalProducts: count);
        },
      },
    );
    if (!mounted || next is! SearchFilterSelection) return;
    _applyFilters(next);
  }

  Widget _countPill(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        '$count',
        style: AppTextStyles.label(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Future<void> _remove(WishlistItem item) async {
    final id = item.id.trim();
    if (id.isEmpty || _busyId != null) return;
    setState(() => _busyId = id);
    try {
      // Private wishlist only — never public unlike / likeCount.
      final targetId = item.listingId.trim();
      var removed = false;
      try {
        await _wishlist.removeWishlistItem(id);
        removed = true;
      } catch (_) {
        // Fall through to product/collection delete by target id.
      }
      if (!removed && targetId.isNotEmpty) {
        if (item.isCollection) {
          await _wishlist.removeWishlistCollection(collectionId: targetId);
        } else {
          await _wishlist.removeWishlistProduct(productId: targetId);
        }
      } else if (!removed) {
        throw StateError('Unable to remove wishlist item');
      }
      if (!mounted) return;
      setState(() {
        _items = _items.where((e) => e.id != id).toList(growable: false);
        _busyId = null;
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

  /// Active product rows with a photo — swipe feed for product details.
  List<WishlistItem> get _swipeableVisible =>
      _visible
          .where(
            (e) =>
                e.isProduct &&
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

    // Collection wishlist rows → collection browse (not product details).
    if (item.isCollection) {
      final link = _storeLinkFor(item);
      final product = StoreProduct(
        id: listingId,
        title: item.displayTitle,
        description: item.description,
        tags: const [],
        imagePaths:
            item.photo.url.trim().isEmpty
                ? const <String>[]
                : [item.photo.url],
        imageThumbhashes:
            (item.photo.thumbhash?.trim().isNotEmpty ?? false)
                ? [item.photo.thumbhash!.trim()]
                : const <String>[],
      );
      await Navigator.of(context).pushNamed(
        Routes.collectionBrowseRoute,
        arguments: <String, Object?>{
          'product': product,
          'storeId': storeId,
          'storeName': item.store.name,
          if (link.isNotEmpty) 'storeLink': link,
          'isOwnStore': false,
        },
      );
      if (mounted) await _load(reset: true, quiet: true);
      return;
    }

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

    await Navigator.of(context).pushNamed(
      Routes.productDetailsRoute,
      arguments: <String, Object?>{
        'product': product,
        'storeId': storeId,
        'storeName': item.store.name,
        if (link.isNotEmpty) 'storeLink': link,
        'isOwnStore': false,
        'imageIndex': 0,
        // Bookmark ≠ public like — seed wishlist only.
        'isWishlisted': true,
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
    final total = _items.length;
    final catalog = _catalog;
    final countBadge = total > 0 ? _countPill(total) : null;
    // Float nav over content — reserve space inside scrollables only
    // (never shrink the whole tab with outer bottom padding / blank band).
    final bottomPad =
        widget.bottomInset > 0 ? widget.bottomInset + 8 : 24.0;

    final collapsedActions = _collapsedChromeActions();

    return Column(
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
                ShellTabTitleBar(
                  title: 'Wishlist',
                  titleBadge: countBadge,
                  trailing: collapsedActions,
                )
              else
                SizedBox(
                  height: ShellTabTitleBar.rowHeight,
                  child: Row(
                    children: [
                      if (widget.onBack != null)
                        AppBackButton(onPressed: widget.onBack),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
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
                              if (countBadge != null) ...[
                                const SizedBox(width: 8),
                                countBadge,
                              ],
                            ],
                          ),
                        ),
                      ),
                      collapsedActions,
                    ],
                  ),
                ),
              SizeTransition(
                sizeFactor: _chromeFactor,
                axisAlignment: -1,
                child: FadeTransition(
                  opacity: _chromeFactor,
                  child: KeyedSubtree(
                    key: _chromeKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        SearchAppBarField(
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          hintText: 'Search wishlist',
                          onChanged: (_) => setState(() {}),
                          onClear: () {
                            _searchCtrl.clear();
                            setState(() {});
                            _setChromeVisible(true);
                          },
                        ),
                        if (_items.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SearchFilterBar(
                            selection: _filters,
                            catalog: catalog,
                            scope: SearchFilterScope.wishlist,
                            onChanged: (next) {
                              _setChromeVisible(true);
                              _applyFilters(next);
                            },
                            onOpenAllFilters: () {
                              _setChromeVisible(true);
                              _openAllFilters();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child:
              // Shell tab: never shimmer (warm/prefetch paints immediately).
              _loading && !widget.embeddedInShell
                  ? _WishlistShimmer(bottomPad: bottomPad)
                  : visible.isEmpty
                  ? Center(
                    child: Padding(
                      padding: AppPadding.screen(bottom: bottomPad),
                      child: Text(
                        _items.isEmpty
                            ? 'Wishlisted photos appear here.'
                            : 'No matching items.',
                        style: AppTextStyles.bodySecondary(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                  : Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _onPinchPointerDown,
                    onPointerMove: _onPinchPointerMove,
                    onPointerUp: _onPinchPointerEnd,
                    onPointerCancel: _onPinchPointerEnd,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _onGridScroll,
                      child: RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh:
                            () => _load(
                              reset: true,
                              quiet: widget.embeddedInShell,
                              forceRefresh: true,
                            ),
                        child: CustomScrollView(
                          controller: _scrollController,
                          physics:
                              _pinching
                                  ? const NeverScrollableScrollPhysics()
                                  : const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                          slivers: [
                            SliverPadding(
                              padding: AppPadding.screen(
                                top: 4,
                                bottom: bottomPad,
                              ),
                              sliver: SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: _crossAxisCount,
                                      crossAxisSpacing: _gridSpacing(
                                        _crossAxisCount,
                                      ),
                                      mainAxisSpacing: _gridSpacing(
                                        _crossAxisCount,
                                      ),
                                      childAspectRatio: 1,
                                    ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final item = visible[index];
                                    return IgnorePointer(
                                      ignoring: _pinching,
                                      child: WishlistItemCard(
                                        key: ValueKey(item.id),
                                        item: item,
                                        onTap: () => _openItem(item),
                                        onRemove: () => _remove(item),
                                        onFollow:
                                            item.isLocked
                                                ? () => _followLocked(item)
                                                : null,
                                        isFollowBusy:
                                            _followBusyStoreId ==
                                            item.store.id,
                                        isRemoveBusy: _busyId == item.id,
                                      ),
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
        ),
      ],
    );
  }
}

class _WishlistShimmer extends StatefulWidget {
  const _WishlistShimmer({this.bottomPad = 16});

  final double bottomPad;

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
          padding: AppPadding.screen(top: 4, bottom: widget.bottomPad),
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
