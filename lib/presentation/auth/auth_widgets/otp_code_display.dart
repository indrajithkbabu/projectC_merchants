import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';

class OtpCodeDisplay extends StatelessWidget {
  const OtpCodeDisplay({super.key, required this.code, this.length = 6});

  final String code;
  final int length;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (index) {
        final hasDigit = index < code.length;
        final isActive = index == code.length && code.length < length;
        final digit = hasDigit ? code[index] : '';

        return Padding(
          padding: EdgeInsets.only(right: index == length - 1 ? 0 : 12),
          child: SizedBox(
            width: 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 36,
                  child: Center(
                    child: Text(digit, style: AppTextStyles.otpDigit()),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 2.5,
                  decoration: BoxDecoration(
                    color:
                        isActive
                            ? AppColors.primary
                            : hasDigit
                            ? AppColors.textPrimary
                            : AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
