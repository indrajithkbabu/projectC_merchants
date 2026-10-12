import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/catalog/search_models.dart';
import 'package:project_c/models/store_privacy_mode.dart';

/// Store row chrome for search (lock + private subtitle + Follow).
class SearchStorePrivacyRow extends StatelessWidget {
  const SearchStorePrivacyRow({
    super.key,
    required this.store,
    required this.onTap,
    this.onFollow,
    this.isFollowBusy = false,
  });

  final SearchSuggestMatch store;
  final VoidCallback onTap;
  final VoidCallback? onFollow;
  final bool isFollowBusy;

  @override
  Widget build(BuildContext context) {
    final city = store.city.trim();
    final subtitleParts = <String>[
      if (city.isNotEmpty) city,
      if (store.isPrivate) 'Private',
      if (store.isPrivate && !store.followStatus.isFollowing)
        'follow to see products',
    ];
    final subtitle = subtitleParts.join(' · ');
    final showFollow = store.showFollowChrome && onFollow != null;
    final followLabel =
        store.followStatus.isPending ? 'Requested' : 'Follow';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          store.name.trim().isEmpty
              ? '?'
              : store.name.trim().substring(0, 1).toUpperCase(),
          style: AppTextStyles.body(
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              store.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (store.isPrivate) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ],
      ),
      subtitle:
          subtitle.isEmpty
              ? null
              : Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption(fontSize: 12),
              ),
      trailing:
          showFollow
              ? _FollowChip(
                label: followLabel,
                busy: isFollowBusy,
                onTap: onFollow!,
              )
              : Text(
                'Store',
                style: AppTextStyles.caption(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
    );
  }
}

class _FollowChip extends StatelessWidget {
  const _FollowChip({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child:
              busy
                  ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textOnPrimary,
                    ),
                  )
                  : Text(
                    label,
                    style: AppTextStyles.caption(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textOnPrimary,
                    ),
                  ),
        ),
      ),
    );
  }
}
