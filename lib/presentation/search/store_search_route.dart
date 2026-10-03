import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/catalog/search_models.dart' as api;
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/search/search_models.dart';
import 'package:project_c/presentation/search/search_widgets/search_app_bar_field.dart';
import 'package:project_c/presentation/search/search_widgets/search_chips.dart';
import 'package:project_c/presentation/search/search_widgets/search_filter_bar.dart';
import 'package:project_c/presentation/search/search_widgets/search_result_card.dart';
import 'package:project_c/presentation/search/search_widgets/search_shimmers.dart';
import 'package:project_c/presentation/search/search_widgets/search_suggestion_list.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/search/search_repository.dart';

/// Store-scoped search & filter.
class StoreSearchRoute extends StatefulWidget {
  const StoreSearchRoute({
    super.key,
    required this.storeId,
    required this.storeName,
    this.storeCity,
    this.productCount,
  });

  final String storeId;
  final String storeName;
  final String? storeCity;
  final int? productCount;

  @override
  State<StoreSearchRoute> createState() => _StoreSearchRouteState();
}

class _StoreSearchRouteState extends State<StoreSearchRoute>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final SearchRepository _repo;
  late final ScrollController _resultsScrollController;
  late final AnimationController _chromeAnim;
  late final Animation<double> _chromeFactor;
  final GlobalKey _chromeKey = GlobalKey();

  SearchFilterSelection _filters = const SearchFilterSelection();
  SearchFilterCatalog _catalog = const SearchFilterCatalog();
  bool _showSuggestions = false;
  String _committedQuery = '';
  bool _chromeVisible = true;
  double _measuredChromeHeight = 0;
  double _prevChromeAnimValue = 1;

  api.StoreFacetsResponse? _facets;
  List<api.SearchSuggestMatch> _suggestions = const [];
  List<SearchProductResult> _results = const [];
  String _countLine = '';
  int _matchedTotal = 0;
  String? _nextCursor;

  bool _facetsLoading = false;
  bool _suggestLoading = false;
  bool _resultsLoading = false;
  bool _loadingMore = false;
  bool _openingProduct = false;
  Timer? _suggestDebounce;
  int _suggestSeq = 0;
  int _searchSeq = 0;

  String get _resolvedStoreName =>
      (_facets?.storeName.isNotEmpty ?? false)
          ? _facets!.storeName
          : widget.storeName;

  String get _resolvedCity {
    final fromFacets = _facets?.city.trim() ?? '';
    if (fromFacets.isNotEmpty) return fromFacets;
    return widget.storeCity?.trim() ?? '';
  }

  int get _totalInStore =>
      _facets?.totalProducts ?? widget.productCount ?? _results.length;

  bool get _showingInventory =>
      !_showSuggestions &&
      _committedQuery.isEmpty &&
      !_filters.hasActiveFilters;

  bool get _canCollapseChrome =>
      !_showSuggestions && !_resultsLoading && _results.length > 2;

  /// Approx. height of the first results row (2 items).
  double _firstTwoItemsExtent(BuildContext context) {
    final width =
        MediaQuery.sizeOf(context).width - (AppPadding.horizontal * 2);
    final cellWidth = (width - 10) / 2;
    final cellHeight = cellWidth / 0.58;
    return cellHeight + 14;
  }

  @override
  void initState() {
    super.initState();
    _repo = ServiceLocator.get<SearchRepository>();
    _controller = TextEditingController()..addListener(() => setState(() {}));
    _focusNode = FocusNode();
    _resultsScrollController = ScrollController();
    _chromeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: 1,
    )..addListener(_compensateScrollForChrome);
    _chromeFactor = CurvedAnimation(
      parent: _chromeAnim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _bootstrap();
  }

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    _chromeAnim.removeListener(_compensateScrollForChrome);
    _chromeAnim.dispose();
    _resultsScrollController.dispose();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _captureChromeHeight() {
    final box = _chromeKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && box.size.height > 0) {
      _measuredChromeHeight = box.size.height;
    }
  }

  void _compensateScrollForChrome() {
    if (!_resultsScrollController.hasClients) {
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

    final pos = _resultsScrollController.position;
    final maxExtent = math.max(pos.maxScrollExtent, pos.pixels + delta);
    final next = (pos.pixels + delta).clamp(pos.minScrollExtent, maxExtent);
    if ((next - pos.pixels).abs() < 0.05) return;
    _resultsScrollController.jumpTo(next.toDouble());
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
      _focusNode.unfocus();
      _chromeAnim.reverse();
    }
  }

  bool _onResultsScroll(ScrollNotification notification) {
    if (!_canCollapseChrome) {
      if (!_chromeVisible) _setChromeVisible(true);
      return false;
    }
    if (notification is! ScrollUpdateNotification) return false;
    if (notification.metrics.axis != Axis.vertical) return false;

    final pixels = notification.metrics.pixels;
    final delta = notification.scrollDelta ?? 0;
    final topZone = _firstTwoItemsExtent(context);

    // Unhide only once the first row (2 items) is back in view.
    if (pixels <= topZone) {
      if (!_chromeVisible) _setChromeVisible(true);
      return false;
    }

    // Hide when scrolling down past the first row.
    if (delta > 2 && _chromeVisible) {
      _setChromeVisible(false);
    }
    return false;
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadFacets(), _loadResults(reset: true)]);
  }

  void _snack(String message) {
    if (!mounted || message.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadFacets() async {
    setState(() => _facetsLoading = true);
    try {
      final facets = await _repo.fetchStoreFacets(widget.storeId);
      if (!mounted) return;
      setState(() {
        _facets = facets;
        _facetsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _facetsLoading = false);
      _snack(CatalogErrorMapper.toUserMessage(e));
    }
  }

  void _onQueryChanged(String value) {
    final trimmed = value.trim();
    _suggestDebounce?.cancel();
    if (trimmed.isEmpty) {
      setState(() {
        _showSuggestions = false;
        _committedQuery = '';
        _suggestions = const [];
      });
      _setChromeVisible(true);
      if (!_filters.hasActiveFilters) {
        _loadResults(reset: true);
      }
      return;
    }
    setState(() => _showSuggestions = true);
    _setChromeVisible(true);
    _suggestDebounce = Timer(const Duration(milliseconds: 200), () {
      _loadSuggestions(trimmed);
    });
  }

  Future<void> _loadSuggestions(String q) async {
    final seq = ++_suggestSeq;
    setState(() => _suggestLoading = true);
    try {
      final res = await _repo.suggest(q: q, storeId: widget.storeId);
      if (!mounted || seq != _suggestSeq) return;
      setState(() {
        _suggestions = res.matches;
        _suggestLoading = false;
      });
    } catch (e) {
      if (!mounted || seq != _suggestSeq) return;
      setState(() => _suggestLoading = false);
      _snack(CatalogErrorMapper.toUserMessage(e));
    }
  }

  void _commitSearch(String raw) {
    _focusNode.unfocus();
    setState(() {
      _committedQuery = raw.trim();
      _showSuggestions = false;
    });
    _loadResults(reset: true);
  }

  void _applyInventoryChip(api.StoreSummaryChip chip) {
    setState(() {
      _showSuggestions = false;
      _committedQuery = '';
      _controller.clear();
      if (chip.type == 'purity') {
        _filters = const SearchFilterSelection().copyWith(
          purities: {chip.value},
        );
      } else if (chip.type == 'metal') {
        _filters = const SearchFilterSelection().copyWith(
          metals: {chip.value},
        );
      } else {
        _filters = const SearchFilterSelection().copyWith(
          categories: {chip.value},
        );
      }
    });
    _loadResults(reset: true);
  }

  Future<void> _loadResults({bool reset = true}) async {
    final seq = ++_searchSeq;
    if (reset) {
      setState(() {
        _resultsLoading = true;
        _nextCursor = null;
      });
    } else {
      if (_loadingMore || _nextCursor == null) return;
      setState(() => _loadingMore = true);
    }

    try {
      final page = await _repo.storeSearch(
        storeId: widget.storeId,
        query: _filters.toApiQuery(
          q: _committedQuery.isEmpty ? null : _committedQuery,
          cursor: reset ? null : _nextCursor,
        ),
      );
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        final mapped = page.items.map(SearchProductResult.fromHit).toList();
        _results = reset ? mapped : [..._results, ...mapped];
        _catalog = SearchFilterCatalog.fromFacets(page.facets);
        _countLine =
            page.summary.countLine.isNotEmpty
                ? page.summary.countLine
                : '${page.summary.totalProducts} of $_totalInStore items in this store';
        _matchedTotal = page.summary.totalProducts;
        _nextCursor = page.nextCursor;
        _resultsLoading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _resultsLoading = false;
        _loadingMore = false;
      });
      _snack(CatalogErrorMapper.toUserMessage(e));
    }
  }

  Future<void> _applyFilters(SearchFilterSelection next) async {
    setState(() {
      _filters = next;
      _showSuggestions = false;
    });
    await _loadResults(reset: true);
  }

  Future<({SearchFilterCatalog catalog, int totalProducts})> _previewFilters(
    SearchFilterSelection selection,
  ) async {
    final page = await _repo.storeSearch(
      storeId: widget.storeId,
      query: selection.toApiQuery(
        q: _committedQuery.isEmpty ? null : _committedQuery,
        limit: 1,
      ),
    );
    return (
      catalog: SearchFilterCatalog.fromFacets(page.facets),
      totalProducts: page.summary.totalProducts,
    );
  }

  Future<void> _openAllFilters() async {
    _focusNode.unfocus();
    final next = await Navigator.of(context).pushNamed(
      Routes.searchFiltersRoute,
      arguments: <String, Object?>{
        'scope': SearchFilterScope.inStore,
        'initial': _filters,
        'initialCatalog': _catalog,
        'initialTotal': _matchedTotal,
        'loadPreview': _previewFilters,
        'storeName': _resolvedStoreName,
      },
    );
    if (!mounted || next is! SearchFilterSelection) return;
    await _applyFilters(next);
  }

  /// Opens product details with a swipe feed of current in-store search results.
  Future<void> _openProductDetails(SearchProductResult product) async {
    final listingId = product.listingId;
    final storeId =
        product.storeId.trim().isNotEmpty
            ? product.storeId.trim()
            : widget.storeId.trim();
    if (listingId.isEmpty || storeId.isEmpty) return;
    if (_openingProduct) return;
    _openingProduct = true;
    _focusNode.unfocus();
    try {
      final pool = _results.isNotEmpty ? _results : [product];
      final tappedIndex = pool.indexWhere((r) => r.id == product.id);
      final args = SearchProductResult.productDetailsArgsFromResults(
        results: pool,
        tappedIndex: tappedIndex < 0 ? 0 : tappedIndex,
        storeIdFallback: widget.storeId.trim(),
        storeNameFallback: _resolvedStoreName,
      );
      if (!mounted) return;
      await Navigator.of(context).pushNamed(
        Routes.productDetailsRoute,
        arguments: args,
      );
    } finally {
      _openingProduct = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final city = _resolvedCity;
    final headerMeta = [
      if (city.isNotEmpty) city,
      '$_totalInStore product${_totalInStore == 1 ? '' : 's'}',
    ].join(' · ');

    return ScreenWrapper(
      backgroundColor: AppColors.background,
      statusBarIconBrightness: Brightness.dark,
      child: Column(
        children: [
          Padding(
            padding: AppPadding.screen(
              top: ScreenWrapper.statusBarTop(context) + 8,
              bottom: 8,
            ),
            child: Row(
              children: [
                AppBackButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _resolvedStoreName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.headline(fontSize: 18),
                      ),
                      Text(
                        headerMeta,
                        style: AppTextStyles.caption(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: AppPadding.screenHorizontal,
              child:
                  _showSuggestions
                      ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SearchAppBarField(
                            controller: _controller,
                            focusNode: _focusNode,
                            hintText: 'Search this store',
                            onChanged: _onQueryChanged,
                            onSubmitted: _commitSearch,
                            onClear: () {
                              _controller.clear();
                              setState(() {
                                _committedQuery = '';
                                _showSuggestions = false;
                                _suggestions = const [];
                              });
                              _loadResults(reset: true);
                            },
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: SearchSuggestionList(
                              isLoading: _suggestLoading,
                              suggestions: _suggestions,
                              onTap: (suggestion) {
                                if (suggestion.isStore) return;
                                final product =
                                    SearchProductResult.fromSuggest(
                                      suggestion,
                                    );
                                if (product.listingId.isNotEmpty) {
                                  _openProductDetails(product);
                                  return;
                                }
                                _controller.text = suggestion.title;
                                _commitSearch(suggestion.title);
                              },
                            ),
                          ),
                        ],
                      )
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizeTransition(
                            sizeFactor: _chromeFactor,
                            axisAlignment: -1,
                            child: KeyedSubtree(
                              key: _chromeKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SearchAppBarField(
                                    controller: _controller,
                                    focusNode: _focusNode,
                                    hintText: 'Search this store',
                                    onChanged: _onQueryChanged,
                                    onSubmitted: _commitSearch,
                                    onClear: () {
                                      _controller.clear();
                                      setState(() {
                                        _committedQuery = '';
                                        _showSuggestions = false;
                                        _suggestions = const [];
                                      });
                                      _setChromeVisible(true);
                                      _loadResults(reset: true);
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  SearchFilterBar(
                                    selection: _filters,
                                    catalog: _catalog,
                                    scope: SearchFilterScope.inStore,
                                    onChanged: (next) {
                                      _setChromeVisible(true);
                                      _applyFilters(next);
                                    },
                                    onOpenAllFilters: () {
                                      _setChromeVisible(true);
                                      _openAllFilters();
                                    },
                                  ),
                                  if (_showingInventory) ...[
                                    const SizedBox(height: 14),
                                    const SearchSectionHeader(
                                      title: 'What this store has',
                                    ),
                                    const SizedBox(height: 10),
                                    if (_facetsLoading &&
                                        (_facets?.summaryChips.isEmpty ??
                                            true))
                                      const SearchSummaryChipsShimmer()
                                    else
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          for (final chip
                                              in _facets?.summaryChips ??
                                                  const <
                                                    api.StoreSummaryChip
                                                  >[])
                                            SearchPillChip(
                                              label: chip.label,
                                              onTap: () {
                                                _setChromeVisible(true);
                                                _applyInventoryChip(chip);
                                              },
                                            ),
                                        ],
                                      ),
                                  ],
                                  const SizedBox(height: 12),
                                  if (_resultsLoading && _results.isEmpty)
                                    const SearchCountLineShimmer()
                                  else
                                    Text(
                                      _countLine.isNotEmpty
                                          ? _countLine
                                          : '${_results.length} of $_totalInStore items in this store',
                                      style: AppTextStyles.caption(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  const SizedBox(height: 10),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: NotificationListener<ScrollNotification>(
                              onNotification: _onResultsScroll,
                              child:
                                  _resultsLoading && _results.isEmpty
                                      ? SearchResultsGridShimmer(
                                        showStoreLine: false,
                                        padding: const EdgeInsets.only(
                                          bottom: 24,
                                        ),
                                      )
                                      : SearchResultsGrid(
                                        controller: _resultsScrollController,
                                        products: _results,
                                        showStoreLine: false,
                                        padding: const EdgeInsets.only(
                                          bottom: 24,
                                        ),
                                        isLoadingMore: _loadingMore,
                                        onLoadMore:
                                            _nextCursor == null
                                                ? null
                                                : () =>
                                                    _loadResults(reset: false),
                                        onProductTap: _openProductDetails,
                                      ),
                            ),
                          ),
                        ],
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
