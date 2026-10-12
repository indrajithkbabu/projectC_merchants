import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/store_privacy_mode.dart';

/// Public / Private store pill on visitor store profiles (screens 08–10).
class StorePrivacyModePill extends StatelessWidget {
  const StorePrivacyModePill({
    super.key,
    required this.mode,
    this.label,
  });

  final StorePrivacyMode mode;

  /// Optional override (e.g. My store uses "Private account").
  final String? label;

  @override
  Widget build(BuildContext context) {
    final private = mode.isPrivate;
    final fg = private ? AppColors.textSecondary : AppColors.success;
    final bg =
        private
            ? AppColors.surfaceSecondary
            : AppColors.success.withValues(alpha: 0.14);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label ?? mode.pillLabel,
        style: AppTextStyles.caption(
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
