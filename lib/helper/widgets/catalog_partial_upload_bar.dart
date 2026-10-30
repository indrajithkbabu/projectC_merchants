import 'package:flutter/material.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/primary_button.dart';

/// Scenario 3 bar: publish successes or retry permanent S3 failures.
class CatalogPartialUploadBar extends StatelessWidget {
  const CatalogPartialUploadBar({
    super.key,
    required this.successCount,
    required this.failedCount,
    required this.onPublishSuccesses,
    required this.onRetryFailed,
    this.isBusy = false,
  });

  final int successCount;
  final int failedCount;
  final VoidCallback onPublishSuccesses;
  final VoidCallback onRetryFailed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: AppPadding.screen(top: 12, bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$successCount of ${successCount + failedCount} photos uploaded',
                style: AppTextStyles.body(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '$failedCount failed after retries. Publish the successes or retry.',
                style: AppTextStyles.bodySecondary(fontSize: 13),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Publish $successCount Photos',
                enabled: !isBusy && successCount > 0,
                isLoading: isBusy,
                onPressed: onPublishSuccesses,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: isBusy ? null : onRetryFailed,
                child: Text(
                  'Retry Failed ($failedCount)',
                  style: AppTextStyles.button(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
