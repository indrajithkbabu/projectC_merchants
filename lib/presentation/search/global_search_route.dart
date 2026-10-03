import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/catalog/search_models.dart' as api;
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/navigation/smooth_fade_page_route.dart';
import 'package:project_c/presentation/search/search_models.dart';
import 'package:project_c/presentation/search/search_widgets/search_app_bar_field.dart';
import 'package:project_c/presentation/search/search_widgets/search_discover_panel.dart';
import 'package:project_c/presentation/search/search_widgets/search_filter_bar.dart';
import 'package:project_c/presentation/search/search_widgets/search_result_card.dart';
import 'package:project_c/presentation/search/search_widgets/search_shimmers.dart';
import 'package:project_c/presentation/search/search_widgets/search_suggestion_list.dart';
import 'package:project_c/services/search_recent_preferences.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/search/search_repository.dart';

enum _GlobalSearchPhase { discover, suggestions, results }

/// Platform-wide product search (Discover → suggestions → results).
class GlobalSearchRoute extends StatefulWidget {
  const GlobalSearchRoute({
    super.key,
    this.initialQuery,
    this.initialCategory,
  });

  final String? initialQuery;
  final String? initialCategory;

  @override
  State<GlobalSearchRoute> createState() => _GlobalSearchRouteState();
}

class _GlobalSearchRouteState extends State<GlobalSearchRoute> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final SearchRepository _repo;
  late final SearchRecentPreferences _recents;

  SearchFilterSelection _filters = const SearchFilterSelection();
  SearchFilterCatalog _catalog = const SearchFilterCatalog();
  _GlobalSearchPhase _phase = _GlobalSearchPhase.discover;
  String _committedQuery = '';

  api.SearchMeta _meta = const api.SearchMeta();
  List<api.SearchRecentEntry> _recent = const [];
  List<api.SearchSuggestMatch> _suggestions = const [];
  List<SearchProductResult> _results = const [];
  String _countLine = '';
  int _totalProducts = 0;
  String? _nextCursor;

  bool _keepKeyboard = true;
  bool _focusArmed = false;
  bool _metaLoading = false;
  bool _suggestLoading = false;
  bool _resultsLoading = false;
  bool _loadingMore = false;
  bool _recordRecentOnNextResults = false;
  bool _openingProduct = false;
  Animation<double>? _routeAnimation;
  AnimationStatusListener? _routeFocusListener;
  Timer? _suggestDebounce;
  int _suggestSeq = 0;
  int _searchSeq = 0;

  bool get _shouldAutofocus {
    final category = widget.initialCategory?.trim();
    final query = widget.initialQuery?.trim();
    return (category == null || category.isEmpty) &&
        (query == null || query.isEmpty);
  }

  @override
  void initState() {
    super.initState();
    _repo = ServiceLocator.get<SearchRepository>();
    _recents = ServiceLocator.get<SearchRecentPreferences>();
    _controller = TextEditingController()..addListener(_onControllerTick);
    _focusNode = FocusNode();

    final category = widget.initialCategory?.trim();
    final query = widget.initialQuery?.trim();
    if (category != null && category.isNotEmpty) {
      _filters = _filters.copyWith(categories: {category});
      _controller.text = category;
      _committedQuery = '';
      _phase = _GlobalSearchPhase.results;
      _keepKeyboard = false;
      _loadResults();
    } else if (query != null && query.isNotEmpty) {
      _controller.text = query;
      _committedQuery = query;
      _phase = _GlobalSearchPhase.results;
      _keepKeyboard = false;
      _recordRecentOnNextResults = true;
      _loadResults();
    } else {
      _loadMeta();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_focusArmed || !_shouldAutofocus) return;
    _focusArmed = true;
    _armKeyboardAfterTransition();
  }

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    if (_routeAnimation != null && _routeFocusListener != null) {
      _routeAnimation!.removeStatusListener(_routeFocusListener!);
    }
    _controller.removeListener(_onControllerTick);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onControllerTick() {
    if (mounted) setState(() {});
  }

  void _armKeyboardAfterTransition() {
    final animation = ModalRoute.of(context)?.animation;
    _routeAnimation = animation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      _showKeyboard();
      return;
    }
    _routeFocusListener = (status) {
      if (status != AnimationStatus.completed) return;
      if (_routeAnimation != null && _routeFocusListener != null) {
        _routeAnimation!.removeStatusListener(_routeFocusListener!);
      }
      _routeFocusListener = null;
      _showKeyboard();
    };
    animation.addStatusListener(_routeFocusListener!);
  }

  void _showKeyboard() {
    if (!mounted || !_keepKeyboard) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_keepKeyboard) return;
      if (!_focusNode.hasFocus) _focusNode.requestFocus();
    });
  }

  void _hideKeyboard() {
    _keepKeyboard = false;
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  void _onFieldTap() => _keepKeyboard = true;

  void _snack(String message) {
    if (!mounted || message.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadMeta() async {
    setState(() => _metaLoading = true);
    try {
      // Ignore stub `recentSearches` from meta — use device-local history only.
      final results = await Future.wait([
        _repo.fetchMeta(),
        _recents.read(),
      ]);
      if (!mounted) return;
      final meta = results[0] as api.SearchMeta;
      final recent = results[1] as List<api.SearchRecentEntry>;
      setState(() {
        _meta = meta;
        _recent = recent;
        _metaLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final recent = await _recents.read();
      if (!mounted) return;
      setState(() {
        _recent = recent;
        _metaLoading = false;
      });
      _snack(CatalogErrorMapper.toUserMessage(e));
    }
  }

  Future<void> _clearRecent() async {
    final next = await _recents.clear();
    if (!mounted) return;
    setState(() => _recent = next);
  }

  Future<void> _rememberQuery(String text, {String label = ''}) async {
    final next = await _recents.addQuery(text: text, label: label);
    if (!mounted) return;
    setState(() => _recent = next);
  }

  Future<void> _rememberStore({
    required String name,
    String? storeId,
    String? slug,
  }) async {
    final next = await _recents.addStore(
      name: name,
      storeId: storeId,
      slug: slug,
    );
    if (!mounted) return;
    setState(() => _recent = next);
  }

  /// Text searches from the field / recent / trending should not keep
  /// leftover facet filters (e.g. prior category=chain + new q=kada).
  SearchFilterSelection _filtersForFreshQuery() {
    return SearchFilterSelection(sort: _filters.sort);
  }

  void _onQueryChanged(String value) {
    final trimmed = value.trim();
    _suggestDebounce?.cancel();
    if (trimmed.isEmpty) {
      setState(() {
        _phase = _GlobalSearchPhase.discover;
        _committedQuery = '';
        _suggestions = const [];
      });
      return;
    }
    if (_phase == _GlobalSearchPhase.results) {
      // Keep showing results until submit; still refresh suggestions quietly.
    } else {
      setState(() => _phase = _GlobalSearchPhase.suggestions);
    }
    _suggestDebounce = Timer(const Duration(milliseconds: 200), () {
      _loadSuggestions(trimmed);
    });
  }

  Future<void> _loadSuggestions(String q) async {
    final seq = ++_suggestSeq;
    setState(() => _suggestLoading = true);
    try {
      final res = await _repo.suggest(q: q);
      if (!mounted || seq != _suggestSeq) return;
      setState(() {
        _suggestions = res.matches;
        _suggestLoading = false;
        if (_phase != _GlobalSearchPhase.results) {
          _phase = _GlobalSearchPhase.suggestions;
        }
      });
    } catch (e) {
      if (!mounted || seq != _suggestSeq) return;
      setState(() => _suggestLoading = false);
      _snack(CatalogErrorMapper.toUserMessage(e));
    }
  }

  Future<void> _commitSearch(
    String raw, {
    bool resetFilters = true,
  }) async {
    final query = raw.trim();
    if (resetFilters) {
      _filters = _filtersForFreshQuery();
    }
    if (query.isEmpty && !_filters.hasActiveFilters) {
      setState(() {
        _phase = _GlobalSearchPhase.discover;
        _committedQuery = '';
        _results = const [];
      });
      return;
    }
    _hideKeyboard();
    setState(() {
      _committedQuery = query;
      _filters = _filters;
      _phase = _GlobalSearchPhase.results;
      _recordRecentOnNextResults = query.isNotEmpty;
    });
    await _loadResults(reset: true);
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
      final page = await _repo.search(
        _filters.toApiQuery(
          q: _committedQuery.isEmpty ? null : _committedQuery,
          cursor: reset ? null : _nextCursor,
        ),
      );
      if (!mounted || seq != _searchSeq) return;
      final countLine =
          page.summary.countLine.isNotEmpty
              ? page.summary.countLine
              : '${page.summary.totalProducts} products';
      final shouldRecord =
          reset && _recordRecentOnNextResults && _committedQuery.isNotEmpty;
      _recordRecentOnNextResults = false;
      setState(() {
        final mapped = page.items.map(SearchProductResult.fromHit).toList();
        _results = reset ? mapped : [..._results, ...mapped];
        _catalog = SearchFilterCatalog.fromFacets(page.facets);
        _countLine = countLine;
        _totalProducts = page.summary.totalProducts;
        _nextCursor = page.nextCursor;
        _resultsLoading = false;
        _loadingMore = false;
        _phase = _GlobalSearchPhase.results;
      });
      if (shouldRecord) {
        await _rememberQuery(_committedQuery, label: countLine);
      }
    } catch (e) {
      if (!mounted || seq != _searchSeq) return;
      _recordRecentOnNextResults = false;
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
      _phase = _GlobalSearchPhase.results;
    });
    await _loadResults(reset: true);
  }

  Future<({SearchFilterCatalog catalog, int totalProducts})> _previewFilters(
    SearchFilterSelection selection,
  ) async {
    final page = await _repo.search(
      selection.toApiQuery(
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
    _hideKeyboard();
    final next = await Navigator.of(context).pushNamed(
      Routes.searchFiltersRoute,
      arguments: <String, Object?>{
        'scope': SearchFilterScope.global,
        'initial': _filters,
        'initialCatalog': _catalog,
        'initialTotal': _totalProducts,
        'loadPreview': _previewFilters,
      },
    );
    if (!mounted || next is! SearchFilterSelection) return;
    await _applyFilters(next);
  }

  void _openStoreProfile({
    required String storeId,
    required String storeName,
    String? storeSlug,
  }) {
    if (storeId.isEmpty) {
      // Gap: recent store entries may omit id — fall back to text search.
      _controller.text = storeName;
      _commitSearch(storeName);
      return;
    }
    _rememberStore(name: storeName, storeId: storeId, slug: storeSlug);
    _hideKeyboard();
    Navigator.of(context).pushNamed(
      Routes.storeProfileRoute,
      arguments: <String, Object?>{
        'storeId': storeId,
        'storeName': storeName,
        if (storeSlug != null && storeSlug.isNotEmpty)
          'storeLink': '$storeSlug.jewelflow.app',
        'isOwnStore': false,
      },
    );
  }

  /// Opens product details with a swipe feed of current search results.
  /// Pass [useResultsFeed]: false for suggest taps (single hit only).
  Future<void> _openProductDetails(
    SearchProductResult product, {
    bool useResultsFeed = true,
  }) async {
    final listingId = product.listingId;
    final storeId = product.storeId.trim();
    if (listingId.isEmpty || storeId.isEmpty) return;
    if (_openingProduct) return;
    _openingProduct = true;
    _hideKeyboard();
    try {
      final pool =
          useResultsFeed && _results.isNotEmpty ? _results : [product];
      final tappedIndex = pool.indexWhere((r) => r.id == product.id);
      final args = SearchProductResult.productDetailsArgsFromResults(
        results: pool,
        tappedIndex: tappedIndex < 0 ? 0 : tappedIndex,
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

  void _onSuggestionTap(api.SearchSuggestMatch suggestion) {
    if (suggestion.isStore) {
      _openStoreProfile(
        storeId: suggestion.id,
        storeName: suggestion.name,
        storeSlug: suggestion.slug,
      );
      return;
    }
    final product = SearchProductResult.fromSuggest(suggestion);
    if (product.storeId.isNotEmpty && product.listingId.isNotEmpty) {
      _openProductDetails(product, useResultsFeed: false);
      return;
    }
    // Fallback if suggest omits storeId (older payloads).
    _controller.text = suggestion.title;
    _commitSearch(suggestion.title);
  }

  Future<void> _popRoute() async {
    _hideKeyboard();
    if (!mounted) return;
    await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        _keepKeyboard = false;
        _focusNode.unfocus();
      },
      child: ScreenWrapper(
        backgroundColor: AppColors.background,
        statusBarIconBrightness: Brightness.dark,
        child: EdgeBackSwipe(
          onBack: _popRoute,
          child: Column(
            children: [
              Padding(
                padding: AppPadding.screen(
                  top: ScreenWrapper.statusBarTop(context) + 4,
                  bottom: 6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppBackButton(onPressed: _popRoute),
                        const SizedBox(width: 4),
                        Text(
                          'Discover',
                          style: AppTextStyles.headline(fontSize: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SearchAppBarField(
                      controller: _controller,
                      focusNode: _focusNode,
                      hintText: 'Search products, tags or stores',
                      showCancel: true,
                      onTap: _onFieldTap,
                      onCancel: () {
                        if (_controller.text.isEmpty &&
                            !_filters.hasActiveFilters &&
                            _phase == _GlobalSearchPhase.discover) {
                          _popRoute();
                          return;
                        }
                        _controller.clear();
                        setState(() {
                          _phase = _GlobalSearchPhase.discover;
                          _committedQuery = '';
                          _filters = _filters.clearedFilters(
                            keepSort: _filters.sort,
                          );
                          _results = const [];
                          _suggestions = const [];
                        });
                        _keepKeyboard = true;
                        _showKeyboard();
                      },
                      onClear: () {
                        _controller.clear();
                        setState(() {
                          _phase = _GlobalSearchPhase.discover;
                          _committedQuery = '';
                          _suggestions = const [];
                        });
                        _keepKeyboard = true;
                        _showKeyboard();
                      },
                      onChanged: _onQueryChanged,
                      onSubmitted: _commitSearch,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: GestureDetector(
                  onTap: _hideKeyboard,
                  behavior: HitTestBehavior.translucent,
                  child: Padding(
                    padding: AppPadding.screenHorizontal,
                    child: switch (_phase) {
                      _GlobalSearchPhase.discover => SearchDiscoverPanel(
                        isLoading: _metaLoading,
                        recent: _recent,
                        trending: _meta.trendingTags,
                        categories: _meta.categories,
                        onClearRecent: _clearRecent,
                        onRecentTap: (item) {
                          if (item.isStore) {
                            _openStoreProfile(
                              storeId: item.storeId ?? '',
                              storeName: item.name,
                              storeSlug: item.slug,
                            );
                            return;
                          }
                          _controller.text = item.text;
                          _commitSearch(item.text);
                        },
                        onTrendingTap: (tag) {
                          _controller.text = tag;
                          _commitSearch(tag);
                        },
                        onCategoryTap: (tile) {
                          _hideKeyboard();
                          setState(() {
                            _filters = SearchFilterSelection(
                              sort: _filters.sort,
                              categories: {tile.key},
                            );
                            _controller.text = tile.label;
                            _committedQuery = '';
                            _phase = _GlobalSearchPhase.results;
                            _recordRecentOnNextResults = false;
                          });
                          _loadResults(reset: true);
                        },
                      ),
                      _GlobalSearchPhase.suggestions => SearchSuggestionList(
                        isLoading: _suggestLoading,
                        suggestions: _suggestions,
                        onTap: _onSuggestionTap,
                      ),
                      _GlobalSearchPhase.results =>
                        _resultsLoading && _results.isEmpty
                            ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                SearchFilterBar(
                                  selection: _filters,
                                  catalog: _catalog,
                                  scope: SearchFilterScope.global,
                                  onChanged: _applyFilters,
                                  onOpenAllFilters: _openAllFilters,
                                ),
                                const SizedBox(height: 6),
                                const SearchCountLineShimmer(),
                                const SizedBox(height: 8),
                                const Expanded(
                                  child: SearchResultsGridShimmer(
                                    showStoreLine: true,
                                    padding: EdgeInsets.only(bottom: 24),
                                  ),
                                ),
                              ],
                            )
                            : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                SearchFilterBar(
                                  selection: _filters,
                                  catalog: _catalog,
                                  scope: SearchFilterScope.global,
                                  onChanged: _applyFilters,
                                  onOpenAllFilters: _openAllFilters,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _countLine,
                                  style: AppTextStyles.caption(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: SearchResultsGrid(
                                    products: _results,
                                    showStoreLine: true,
                                    padding: const EdgeInsets.only(bottom: 24),
                                    isLoadingMore: _loadingMore,
                                    onLoadMore:
                                        _nextCursor == null
                                            ? null
                                            : () => _loadResults(reset: false),
                                    onProductTap: _openProductDetails,
                                  ),
                                ),
                              ],
                            ),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
