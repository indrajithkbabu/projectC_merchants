import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/catalog/search_models.dart';
import 'package:project_c/presentation/search/search_widgets/search_chips.dart';
import 'package:project_c/presentation/search/search_widgets/search_shimmers.dart';

class SearchSuggestionList extends StatelessWidget {
  const SearchSuggestionList({
    super.key,
    required this.suggestions,
    required this.onTap,
    this.isLoading = false,
  });

  final List<SearchSuggestMatch> suggestions;
  final ValueChanged<SearchSuggestMatch> onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading && suggestions.isEmpty) {
      return const SearchSuggestionShimmer();
    }

    if (suggestions.isEmpty) {
      return Center(
        child: Text(
          'No matches',
          style: AppTextStyles.bodySecondary(),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        const SearchSectionHeader(title: 'Matches'),
        const SizedBox(height: 8),
        for (final item in suggestions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => onTap(item),
            title: Text(
              item.isStore ? item.name : item.title,
              style: AppTextStyles.body(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              item.isStore
                  ? item.city
                  : [
                      item.storeName,
                      if (item.city.isNotEmpty) item.city,
                      if (item.netWeight != null) '${item.netWeight} g',
                    ].where((e) => e.trim().isNotEmpty).join(' · '),
              style: AppTextStyles.caption(fontSize: 12),
            ),
            trailing: Text(
              item.isStore ? 'Store' : 'Product',
              style: AppTextStyles.caption(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    item.isStore
                        ? AppColors.primary
                        : AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
