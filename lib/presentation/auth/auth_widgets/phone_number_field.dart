import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';

class PhoneNumberField extends StatelessWidget {
  const PhoneNumberField({
    super.key,
    required this.dialCode,
    required this.displayNumber,
  });

  final String dialCode;
  final String displayNumber;

  @override
  Widget build(BuildContext context) {
    final hasNumber = displayNumber.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            dialCode,
            style: AppTextStyles.body(
              fontWeight: FontWeight.w600,
              fontSize: 17,
            ),
          ),
          Container(
            width: 1,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: AppColors.divider,
          ),
          Expanded(
            child: Text(
              hasNumber ? displayNumber : 'Phone number',
              style:
                  hasNumber
                      ? AppTextStyles.body(
                        fontWeight: FontWeight.w500,
                        fontSize: 17,
                      )
                      : AppTextStyles.hint(),
            ),
          ),
        ],
      ),
    );
  }
}
