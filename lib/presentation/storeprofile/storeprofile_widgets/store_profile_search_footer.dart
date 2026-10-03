import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';

/// Floating footer search field stacked above the store profile content.
///
/// Read-only; tap opens in-store search. Matches the Stores home / global
/// search field chrome exactly (height, padding, radius, fill).
class StoreProfileSearchFooter extends StatelessWidget {
  const StoreProfileSearchFooter({
    super.key,
    required this.onTap,
    this.hintText = 'Search products',
  });

  final VoidCallback onTap;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: TextField(
        readOnly: true,
        showCursor: false,
        onTap: onTap,
        style: AppTextStyles.body(fontSize: 15),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTextStyles.hint(
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textSecondary,
          ),
          filled: true,
          fillColor: AppColors.surfaceSecondary,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 1.2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
