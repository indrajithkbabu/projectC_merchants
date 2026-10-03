import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/primary_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/presentation/search/search_models.dart';

typedef SearchFilterPreviewLoader =
    Future<({SearchFilterCatalog catalog, int totalProducts})> Function(
      SearchFilterSelection selection,
    );

/// Full-screen Flipkart-style filters (split nav + options + Apply).
///
/// Pop with [SearchFilterSelection] on Apply, or `null` on back.
class SearchFiltersRoute extends StatefulWidget {
  const SearchFiltersRoute({
    super.key,
    required this.scope,
    required this.initial,
    required this.initialCatalog,
    required this.initialTotal,
    required this.loadPreview,
    this.storeName,
  });

  final SearchFilterScope scope;
  final SearchFilterSelection initial;
  final SearchFilterCatalog initialCatalog;
  final int initialTotal;
  final SearchFilterPreviewLoader loadPreview;
  final String? storeName;

  @override
  State<SearchFiltersRoute> createState() => _SearchFiltersRouteState();
}

enum _FilterSection {
  sort,
  category,
  metal,
  purity,
  weight,
  size,
  wastage,
  store,
  location,
}

class _SearchFiltersRouteState extends State<SearchFiltersRoute> {
  late SearchFilterSelection _selection;
  late SearchFilterCatalog _catalog;
  late int _totalProducts;
  bool _loading = false;
  Timer? _debounce;
  _FilterSection _section = _FilterSection.sort;

  bool get _inStore => widget.scope == SearchFilterScope.inStore;

  List<_FilterSection> get _sections => [
    _FilterSection.sort,
    _FilterSection.category,
    _FilterSection.metal,
    _FilterSection.purity,
    _FilterSection.weight,
    _FilterSection.size,
    _FilterSection.wastage,
    if (!_inStore) ...[_FilterSection.store, _FilterSection.location],
  ];

  @override
  void initState() {
    super.initState();
    _selection = widget.initial;
    _catalog = widget.initialCatalog;
    _totalProducts = widget.initialTotal;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  String _sectionLabel(_FilterSection section) => switch (section) {
    _FilterSection.sort => 'Sort',
    _FilterSection.category => 'Category',
    _FilterSection.metal => 'Metal',
    _FilterSection.purity => 'Purity',
    _FilterSection.weight => 'Weight',
    _FilterSection.size => 'Size',
    _FilterSection.wastage => 'Wastage',
    _FilterSection.store => 'Store',
    _FilterSection.location => 'Location',
  };

  int _sectionActiveCount(_FilterSection section) => switch (section) {
    _FilterSection.sort =>
      _selection.sort == SearchSortOption.newest ? 0 : 1,
    _FilterSection.category => _selection.categories.length,
    _FilterSection.metal => _selection.metals.length,
    _FilterSection.purity => _selection.purities.length,
    _FilterSection.weight => _selection.weights.length,
    _FilterSection.size => _selection.sizes.length,
    _FilterSection.wastage => _selection.wastages.length,
    _FilterSection.store => _selection.stores.length,
    _FilterSection.location => _selection.locations.length,
  };

  void _toggle(
    Set<String> current,
    String value,
    void Function(Set<String>) apply,
  ) {
    final next = {...current};
    if (next.contains(value)) {
      next.remove(value);
    } else {
      next.add(value);
    }
    setState(() => apply(next));
    _schedulePreview();
  }

  void _schedulePreview() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _runPreview);
  }

  Future<void> _runPreview() async {
    setState(() => _loading = true);
    try {
      final result = await widget.loadPreview(_selection);
      if (!mounted) return;
      setState(() {
        _catalog = result.catalog;
        _totalProducts = result.totalProducts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _clearAll() {
    setState(() {
      _selection = _selection.clearedFilters(keepSort: SearchSortOption.newest);
    });
    _schedulePreview();
  }

  String get _applyLabel {
    if (_loading) return 'Updating…';
    if (_totalProducts <= 0) return 'No matches — adjust filters';
    final n = _totalProducts;
    return 'See $n product${n == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ScreenWrapper(
      backgroundColor: AppColors.background,
      statusBarIconBrightness: Brightness.dark,
      child: Column(
        children: [
          Padding(
            padding: AppPadding.screen(
              top: ScreenWrapper.statusBarTop(context) + 4,
              bottom: 8,
            ),
            child: Row(
              children: [
                AppBackButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Text(
                    'Filters',
                    style: AppTextStyles.headline(fontSize: 18),
                  ),
                ),
                TextButton(
                  onPressed: _clearAll,
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    'Clear All Filters',
                    style: AppTextStyles.label(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 118,
                  child: ColoredBox(
                    color: AppColors.scaffold,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      children: [
                        for (final section in _sections)
                          _NavTile(
                            label: _sectionLabel(section),
                            selected: _section == section,
                            activeCount: _sectionActiveCount(section),
                            onTap: () => setState(() => _section = section),
                          ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, color: AppColors.border),
                Expanded(
                  child: ColoredBox(
                    color: AppColors.surface,
                    child: _buildRightPanel(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: AppPadding.screen(top: 10, bottom: bottomInset + 10),
            child: PrimaryButton(
              label: _applyLabel,
              enabled: !_loading && _totalProducts > 0,
              isLoading: _loading,
              onPressed:
                  _loading || _totalProducts <= 0
                      ? null
                      : () => Navigator.of(context).pop(_selection),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel() {
    if (_section == _FilterSection.sort) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        children: [
          for (final option in SearchSortOption.values)
            _SortTile(
              label: option.label,
              selected: _selection.sort == option,
              onTap: () {
                setState(() => _selection = _selection.copyWith(sort: option));
                _schedulePreview();
              },
            ),
        ],
      );
    }

    final options = switch (_section) {
      _FilterSection.category => _catalog.categories,
      _FilterSection.metal => _catalog.metals,
      _FilterSection.purity => _catalog.purities,
      _FilterSection.weight => _catalog.weights,
      _FilterSection.size => _catalog.sizes,
      _FilterSection.wastage => _catalog.wastages,
      _FilterSection.store => _catalog.stores,
      _FilterSection.location => _catalog.locations,
      _FilterSection.sort => const <SearchFilterOption>[],
    };
    final selected = switch (_section) {
      _FilterSection.category => _selection.categories,
      _FilterSection.metal => _selection.metals,
      _FilterSection.purity => _selection.purities,
      _FilterSection.weight => _selection.weights,
      _FilterSection.size => _selection.sizes,
      _FilterSection.wastage => _selection.wastages,
      _FilterSection.store => _selection.stores,
      _FilterSection.location => _selection.locations,
      _FilterSection.sort => const <String>{},
    };

    if (options.isEmpty) {
      return Center(
        child: Text('No options', style: AppTextStyles.bodySecondary()),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 16),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];
        final isOn = selected.contains(option.value);
        final disabled = _inStore && !option.isAvailable && !isOn;
        return CheckboxListTile(
          value: isOn,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: AppColors.primary,
          enabled: !disabled,
          title: Text(
            option.count > 0
                ? '${option.label} (${option.count})'
                : option.label,
            style: AppTextStyles.body(
              fontSize: 14,
              color: disabled ? AppColors.textHint : AppColors.textPrimary,
            ),
          ),
          onChanged:
              disabled
                  ? null
                  : (_) {
                    switch (_section) {
                      case _FilterSection.category:
                        _toggle(
                          _selection.categories,
                          option.value,
                          (n) =>
                              _selection = _selection.copyWith(categories: n),
                        );
                      case _FilterSection.metal:
                        _toggle(
                          _selection.metals,
                          option.value,
                          (n) => _selection = _selection.copyWith(metals: n),
                        );
                      case _FilterSection.purity:
                        _toggle(
                          _selection.purities,
                          option.value,
                          (n) => _selection = _selection.copyWith(purities: n),
                        );
                      case _FilterSection.weight:
                        _toggle(
                          _selection.weights,
                          option.value,
                          (n) => _selection = _selection.copyWith(weights: n),
                        );
                      case _FilterSection.size:
                        _toggle(
                          _selection.sizes,
                          option.value,
                          (n) => _selection = _selection.copyWith(sizes: n),
                        );
                      case _FilterSection.wastage:
                        _toggle(
                          _selection.wastages,
                          option.value,
                          (n) => _selection = _selection.copyWith(wastages: n),
                        );
                      case _FilterSection.store:
                        _toggle(
                          _selection.stores,
                          option.value,
                          (n) => _selection = _selection.copyWith(stores: n),
                        );
                      case _FilterSection.location:
                        _toggle(
                          _selection.locations,
                          option.value,
                          (n) =>
                              _selection = _selection.copyWith(locations: n),
                        );
                      case _FilterSection.sort:
                        break;
                    }
                  },
        );
      },
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.label,
    required this.selected,
    required this.activeCount,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.surface : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              Container(
                width: 4,
                height: double.infinity,
                color: selected ? AppColors.primary : Colors.transparent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color:
                        selected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ),
              if (activeCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
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

class _SortTile extends StatelessWidget {
  const _SortTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(
        label,
        style: AppTextStyles.body(
          fontSize: 14,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing:
          selected
              ? const Icon(Icons.check_rounded, color: AppColors.primary)
              : null,
      onTap: onTap,
    );
  }
}
