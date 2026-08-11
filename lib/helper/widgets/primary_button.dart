import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.isLoading = false,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool isLoading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !isLoading && onPressed != null;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: canTap ? 1 : 0.45,
        child: ElevatedButton(
          onPressed: canTap ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            disabledForegroundColor: AppColors.textOnPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Text(label, style: AppTextStyles.button()),
        ),
      ),
    );
  }
}
