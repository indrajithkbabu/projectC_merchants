import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';

/// Telegram-style filled search field used by global and in-store search.
class SearchAppBarField extends StatelessWidget {
  const SearchAppBarField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.showCancel = false,
    this.onCancel,
    this.readOnly = false,
    this.onTap,
    this.autofocus = false,
    this.heroTag,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool showCancel;
  final VoidCallback? onCancel;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool autofocus;

  /// When set, wraps the field so it can fly from Stores home into Discover.
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final field = Material(
      color: Colors.transparent,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        readOnly: readOnly,
        onTap: onTap,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
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
          suffixIcon:
              controller.text.isEmpty
                  ? null
                  : IconButton(
                    tooltip: 'Clear',
                    onPressed: onClear,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
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

    final heroField =
        heroTag == null
            ? field
            : Hero(
              tag: heroTag!,
              transitionOnUserGestures: true,
              child: field,
            );

    return Row(
      children: [
        Expanded(child: heroField),
        if (showCancel) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: onCancel,
            child: Text(
              'Cancel',
              style: AppTextStyles.label(
                fontSize: 15,
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
