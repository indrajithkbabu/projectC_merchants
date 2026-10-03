import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/catalog/search_models.dart';
import 'package:project_c/presentation/search/search_widgets/search_chips.dart';
import 'package:project_c/presentation/search/search_widgets/search_shimmers.dart';

class SearchDiscoverPanel extends StatelessWidget {
  const SearchDiscoverPanel({
    super.key,
    required this.recent,
    required this.trending,
    required this.categories,
    required this.onRecentTap,
    required this.onClearRecent,
    required this.onTrendingTap,
    required this.onCategoryTap,
    this.isLoading = false,
  });

  final List<SearchRecentEntry> recent;
  final List<String> trending;
  final List<SearchMetaCategory> categories;
  final ValueChanged<SearchRecentEntry> onRecentTap;
  final VoidCallback onClearRecent;
  final ValueChanged<String> onTrendingTap;
  final ValueChanged<SearchMetaCategory> onCategoryTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading &&
        recent.isEmpty &&
        trending.isEmpty &&
        categories.isEmpty) {
      return const SearchDiscoverShimmer();
    }

    final visibleRecent = recent.take(3).toList();

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (visibleRecent.isNotEmpty) ...[
          SearchSectionHeader(
            title: 'Recent',
            trailing: TextButton(
              onPressed: onClearRecent,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              ),
              child: Text(
                'Clear',
                style: AppTextStyles.label(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          for (final item in visibleRecent)
            ListTile(
              dense: true,
              visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
              minVerticalPadding: 0,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                item.isStore ? Icons.storefront_outlined : Icons.history_rounded,
                color: AppColors.textSecondary,
                size: 22,
              ),
              title: Text(
                item.displayText,
                style: AppTextStyles.body(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle:
                  item.label.isEmpty
                      ? null
                      : Text(
                        item.label,
                        style: AppTextStyles.caption(fontSize: 12),
                      ),
              onTap: () => onRecentTap(item),
            ),
          const SizedBox(height: 12),
        ],
        if (trending.isNotEmpty) ...[
          const SearchSectionHeader(title: 'Trending now'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in trending)
                SearchPillChip(
                  label: tag,
                  onTap: () => onTrendingTap(tag),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (categories.isNotEmpty) ...[
          const SizedBox(height: 8),
          const SearchSectionHeader(title: 'Browse by category'),
          const SizedBox(height: 8),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.5,
            ),
            itemBuilder: (context, index) {
              final tile = categories[index];
              return Material(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onCategoryTap(tile),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          tile.label,
                          style: AppTextStyles.body(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${tile.productCount} product${tile.productCount == 1 ? '' : 's'}',
                          style: AppTextStyles.caption(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
