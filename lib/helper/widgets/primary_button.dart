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
    this.progress,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool isLoading;
  /// When [isLoading] and set (0–1), shows a fill + percent instead of a spinner.
  final double? progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !isLoading && onPressed != null;
    final clamped = progress?.clamp(0.0, 1.0).toDouble();
    final showProgress = isLoading && clamped != null;

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
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child:
              showProgress
                  ? _ProgressLabel(progress: clamped)
                  : isLoading
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

class _ProgressLabel extends StatelessWidget {
  const _ProgressLabel({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final target = progress.clamp(0.0, 1.0);
    final percent = (target * 100).round();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  width: constraints.maxWidth * target,
                  color: AppColors.textOnPrimary.withValues(alpha: 0.28),
                ),
              ),
              Center(
                child: Text('$percent%', style: AppTextStyles.button()),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: AppColors.textOnPrimary.withValues(alpha: 0.18),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        width: constraints.maxWidth * target,
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
