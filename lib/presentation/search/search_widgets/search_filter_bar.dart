import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/presentation/search/search_models.dart';

/// Horizontal filter strip — Flipkart-style “Sort & Filter” + per-group dropdowns.
///
/// Multi-select groups and sort close the menu after each pick.
class SearchFilterBar extends StatelessWidget {
  const SearchFilterBar({
    super.key,
    required this.selection,
    required this.catalog,
    required this.scope,
    required this.onChanged,
    required this.onOpenAllFilters,
  });

  final SearchFilterSelection selection;
  final SearchFilterCatalog catalog;
  final SearchFilterScope scope;
  final ValueChanged<SearchFilterSelection> onChanged;
  final VoidCallback onOpenAllFilters;

  bool get _inStore => scope == SearchFilterScope.inStore;

  @override
  Widget build(BuildContext context) {
    final groups = <_FilterDropdownSpec>[
      _FilterDropdownSpec(
        title: 'Category',
        options: catalog.categories,
        selected: selection.categories,
        onToggle: (next) => onChanged(selection.copyWith(categories: next)),
      ),
      _FilterDropdownSpec(
        title: 'Metal',
        options: catalog.metals,
        selected: selection.metals,
        onToggle: (next) => onChanged(selection.copyWith(metals: next)),
      ),
      _FilterDropdownSpec(
        title: 'Purity',
        options: catalog.purities,
        selected: selection.purities,
        onToggle: (next) => onChanged(selection.copyWith(purities: next)),
      ),
      _FilterDropdownSpec(
        title: 'Weight',
        options: catalog.weights,
        selected: selection.weights,
        onToggle: (next) => onChanged(selection.copyWith(weights: next)),
      ),
      _FilterDropdownSpec(
        title: 'Size',
        options: catalog.sizes,
        selected: selection.sizes,
        onToggle: (next) => onChanged(selection.copyWith(sizes: next)),
      ),
      _FilterDropdownSpec(
        title: 'Wastage',
        options: catalog.wastages,
        selected: selection.wastages,
        onToggle: (next) => onChanged(selection.copyWith(wastages: next)),
      ),
      if (!_inStore) ...[
        _FilterDropdownSpec(
          title: 'Store',
          options: catalog.stores,
          selected: selection.stores,
          onToggle: (next) => onChanged(selection.copyWith(stores: next)),
        ),
        _FilterDropdownSpec(
          title: 'Location',
          options: catalog.locations,
          selected: selection.locations,
          onToggle: (next) => onChanged(selection.copyWith(locations: next)),
        ),
      ],
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _SortAndFilterPill(
            active: selection.hasActiveFilters ||
                selection.sort != SearchSortOption.newest,
            onTap: onOpenAllFilters,
          ),
          for (final group in groups) ...[
            const SizedBox(width: 8),
            _MultiFilterDropdown(
              spec: group,
              greyZeroCounts: _inStore,
            ),
          ],
          const SizedBox(width: 8),
          _SortDropdown(
            sort: selection.sort,
            onChanged: (sort) => onChanged(selection.copyWith(sort: sort)),
          ),
        ],
      ),
    );
  }
}

class _SortAndFilterPill extends StatelessWidget {
  const _SortAndFilterPill({
    required this.active,
    required this.onTap,
  });

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: active ? AppColors.primary : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 16,
                color: active ? AppColors.primary : AppColors.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                'Sort & Filter',
                style: AppTextStyles.label(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterDropdownSpec {
  const _FilterDropdownSpec({
    required this.title,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final String title;
  final List<SearchFilterOption> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onToggle;
}

class _MultiFilterDropdown extends StatefulWidget {
  const _MultiFilterDropdown({
    required this.spec,
    required this.greyZeroCounts,
  });

  final _FilterDropdownSpec spec;
  final bool greyZeroCounts;

  @override
  State<_MultiFilterDropdown> createState() => _MultiFilterDropdownState();
}

class _MultiFilterDropdownState extends State<_MultiFilterDropdown> {
  final MenuController _menuController = MenuController();

  _FilterDropdownSpec get spec => widget.spec;

  String get _buttonLabel {
    if (spec.selected.isEmpty) return spec.title;
    if (spec.selected.length == 1) {
      final value = spec.selected.first;
      for (final o in spec.options) {
        if (o.value == value) return o.label;
      }
      return value;
    }
    return '${spec.title} · ${spec.selected.length}';
  }

  void _applySelection(Set<String> next) {
    spec.onToggle(next);
    _menuController.close();
  }

  @override
  Widget build(BuildContext context) {
    final active = spec.selected.isNotEmpty;
    final greyZeroCounts = widget.greyZeroCounts;
    return MenuAnchor(
      controller: _menuController,
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
        elevation: const WidgetStatePropertyAll(6),
        shadowColor: WidgetStatePropertyAll(
          Colors.black.withValues(alpha: 0.12),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 6),
        ),
        maximumSize: const WidgetStatePropertyAll(Size(280, 340)),
      ),
      builder: (context, controller, child) {
        return _FilterPill(
          label: _buttonLabel,
          active: active,
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
        );
      },
      menuChildren: [
        if (spec.options.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'No options',
              style: AppTextStyles.bodySecondary(fontSize: 13),
            ),
          )
        else
          for (final option in spec.options)
            CheckboxMenuButton(
              closeOnActivate: true,
              value: spec.selected.contains(option.value),
              onChanged:
                  greyZeroCounts &&
                          !option.isAvailable &&
                          !spec.selected.contains(option.value)
                      ? null
                      : (checked) {
                        final next = {...spec.selected};
                        if (checked == true) {
                          next.add(option.value);
                        } else {
                          next.remove(option.value);
                        }
                        _applySelection(next);
                      },
              child: Text(
                option.count > 0
                    ? '${option.label} (${option.count})'
                    : option.label,
                style: AppTextStyles.body(
                  fontSize: 14,
                  color:
                      greyZeroCounts && !option.isAvailable
                          ? AppColors.textHint
                          : AppColors.textPrimary,
                ),
              ),
            ),
        if (spec.selected.isNotEmpty) ...[
          const Divider(height: 8),
          MenuItemButton(
            onPressed: () => _applySelection({}),
            child: Text(
              'Clear ${spec.title.toLowerCase()}',
              style: AppTextStyles.label(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({
    required this.sort,
    required this.onChanged,
  });

  final SearchSortOption sort;
  final ValueChanged<SearchSortOption> onChanged;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
        elevation: const WidgetStatePropertyAll(6),
        shadowColor: WidgetStatePropertyAll(
          Colors.black.withValues(alpha: 0.12),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 6),
        ),
      ),
      builder: (context, controller, child) {
        return _FilterPill(
          label: sort.label,
          active: sort != SearchSortOption.newest,
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
        );
      },
      menuChildren: [
        for (final option in SearchSortOption.values)
          MenuItemButton(
            onPressed: () => onChanged(option),
            trailingIcon:
                sort == option
                    ? const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: AppColors.primary,
                    )
                    : null,
            child: Text(
              option.label,
              style: AppTextStyles.body(
                fontSize: 14,
                fontWeight:
                    sort == option ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.navBarActivePill : AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTextStyles.label(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: active ? AppColors.primary : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
