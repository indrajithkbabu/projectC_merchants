import 'package:flutter/material.dart';
import 'package:project_c/bloc/store_setup/store_setup_bloc.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';

class StoreLinkCard extends StatelessWidget {
  const StoreLinkCard({super.key, required this.state});

  final StoreSetupState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your store link', style: AppTextStyles.caption()),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  state.fullStoreLink.isEmpty
                      ? 'your-store.jewelflow.app'
                      : state.fullStoreLink,
                  style: AppTextStyles.body(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              _AvailabilityBadge(status: state.availabilityStatus),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({required this.status});

  final StoreLinkAvailabilityStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == StoreLinkAvailabilityStatus.idle) {
      return Text(
        'Waiting',
        style: AppTextStyles.caption(fontWeight: FontWeight.w600),
      );
    }
    if (status == StoreLinkAvailabilityStatus.checking) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.8),
          ),
          const SizedBox(width: 6),
          Text(
            'Checking',
            style: AppTextStyles.caption(fontWeight: FontWeight.w600),
          ),
        ],
      );
    }
    if (status == StoreLinkAvailabilityStatus.available) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: AppColors.success,
          ),
          const SizedBox(width: 4),
          Text(
            'Available',
            style: AppTextStyles.caption(
              color: AppColors.success,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 16,
          color: AppColors.error,
        ),
        const SizedBox(width: 4),
        Text(
          'Unavailable',
          style: AppTextStyles.caption(
            color: AppColors.error,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
