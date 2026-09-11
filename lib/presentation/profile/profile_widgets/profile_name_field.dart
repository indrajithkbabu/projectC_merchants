import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';

class ProfileNameField extends StatelessWidget {
  const ProfileNameField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    required this.onChanged,
    this.textInputAction = TextInputAction.next,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.label(
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: textInputAction,
          style: AppTextStyles.body(fontSize: 28, fontWeight: FontWeight.w400),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTextStyles.hint(
              fontSize: 28,
              fontWeight: FontWeight.w400,
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }
}
