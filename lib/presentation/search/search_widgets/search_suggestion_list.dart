import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/catalog/search_models.dart';
import 'package:project_c/presentation/search/search_widgets/search_chips.dart';
import 'package:project_c/presentation/search/search_widgets/search_shimmers.dart';
import 'package:project_c/presentation/search/search_widgets/search_store_privacy_row.dart';

class SearchSuggestionList extends StatelessWidget {
  const SearchSuggestionList({
    super.key,
    required this.suggestions,
    required this.onTap,
    this.onFollowStore,
    this.followBusyStoreId,
    this.isLoading = false,
  });

  final List<SearchSuggestMatch> suggestions;
  final ValueChanged<SearchSuggestMatch> onTap;
  final ValueChanged<SearchSuggestMatch>? onFollowStore;
  final String? followBusyStoreId;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading && suggestions.isEmpty) {
      return const SearchSuggestionShimmer();
    }

    // Private-store products stay hidden for non-followers.
    final visible =
        suggestions
            .where((e) => e.isStore || e.isContentVisible)
            .toList(growable: false);
    final stores = visible.where((e) => e.isStore).toList(growable: false);
    final products = visible.where((e) => !e.isStore).toList(growable: false);

    if (visible.isEmpty) {
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
        if (stores.isNotEmpty) ...[
          const SearchSectionHeader(title: 'Stores'),
          const SizedBox(height: 4),
          for (final item in stores)
            SearchStorePrivacyRow(
              store: item,
              onTap: () => onTap(item),
              onFollow:
                  onFollowStore == null ? null : () => onFollowStore!(item),
              isFollowBusy: followBusyStoreId == item.id,
            ),
          const SizedBox(height: 12),
        ],
        if (products.isNotEmpty) ...[
          const SearchSectionHeader(title: 'Products'),
          const SizedBox(height: 4),
          for (final item in products)
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => onTap(item),
              title: Text(
                item.title,
                style: AppTextStyles.body(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                [
                  item.storeName,
                  if (item.city.isNotEmpty) item.city,
                  if (item.netWeight != null && item.netWeight! > 0)
                    '${item.netWeight} g',
                ].where((e) => e.trim().isNotEmpty).join(' · '),
                style: AppTextStyles.caption(fontSize: 12),
              ),
              trailing: Text(
                'Product',
                style: AppTextStyles.caption(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ],
    );
  }
}
