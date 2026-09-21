import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/store_channel.dart';

class StoreListingTile extends StatelessWidget {
  const StoreListingTile({
    super.key,
    required this.store,
    required this.onTap,
  });

  final StoreChannel store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: Color(store.avatarColor),
        child: Text(
          store.initials,
          style: AppTextStyles.label(
            fontWeight: FontWeight.w700,
            color: AppColors.textOnPrimary,
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              store.name,
              style: AppTextStyles.body(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (store.isOwn) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'You',
                style: AppTextStyles.caption(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        store.storeLink,
        style: AppTextStyles.caption(),
      ),
    );
  }
}
