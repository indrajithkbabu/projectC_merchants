import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/store_privacy_mode.dart';

/// Locked product area for private stores the viewer cannot see (08–09).
class StorePrivateContentGate extends StatelessWidget {
  const StorePrivateContentGate({
    super.key,
    required this.storeName,
    required this.followStatus,
  });

  final String storeName;
  final StoreFollowStatus followStatus;

  @override
  Widget build(BuildContext context) {
    final pending = followStatus.isPending;
    final shortName = _shortStoreName(storeName);
    final body =
        pending
            ? 'Request sent. You\'ll be notified when $shortName approves, '
                'and their products will appear here.'
            : 'Follow $storeName to see their products and photos.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 48),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 32,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'This store is private',
            style: AppTextStyles.title(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: AppTextStyles.body(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  static String _shortStoreName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'the store';
    final first = trimmed.split(RegExp(r'\s+')).first;
    return first.isEmpty ? trimmed : first;
  }
}
