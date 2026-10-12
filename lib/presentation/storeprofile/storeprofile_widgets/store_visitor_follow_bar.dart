import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/store_privacy_mode.dart';

/// Products / Followers / Following counts for store profiles.
///
/// Owner may pass [onFollowersTap] / [onFollowingTap] to open list screens.
/// Visitors leave taps null (counts are display-only).
class StoreVisitorCountsRow extends StatelessWidget {
  const StoreVisitorCountsRow({
    super.key,
    required this.productCount,
    required this.followerCount,
    required this.followingCount,
    this.onFollowersTap,
    this.onFollowingTap,
    this.alignStart = false,
  });

  final int productCount;
  final int followerCount;
  final int followingCount;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  /// When true, each count column is left-aligned (e.g. My store name + Products).
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CountCell(
            value: productCount,
            label: 'Products',
            alignStart: alignStart,
          ),
        ),
        Expanded(
          child: _CountCell(
            value: followerCount,
            label: 'Followers',
            onTap: onFollowersTap,
            alignStart: alignStart,
          ),
        ),
        Expanded(
          child: _CountCell(
            value: followingCount,
            label: 'Following',
            onTap: onFollowingTap,
            alignStart: alignStart,
          ),
        ),
      ],
    );
  }
}

class _CountCell extends StatelessWidget {
  const _CountCell({
    required this.value,
    required this.label,
    this.onTap,
    this.alignStart = false,
  });

  final int value;
  final String label;
  final VoidCallback? onTap;
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment:
          alignStart ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          '$value',
          style: AppTextStyles.title(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption()),
      ],
    );
    if (onTap == null) return column;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: 4,
            horizontal: alignStart ? 0 : 4,
          ),
          child: column,
        ),
      ),
    );
  }
}

/// Follow / Requested / Following (+ optional notify bell) for visitors.
class StoreVisitorFollowBar extends StatelessWidget {
  const StoreVisitorFollowBar({
    super.key,
    required this.followStatus,
    required this.isBusy,
    required this.notifyUploads,
    required this.storeName,
    required this.onFollow,
    required this.onUnfollow,
    required this.onToggleNotify,
  });

  final StoreFollowStatus followStatus;
  final bool isBusy;
  final bool notifyUploads;
  final String storeName;
  final VoidCallback onFollow;
  final VoidCallback onUnfollow;
  final VoidCallback onToggleNotify;

  @override
  Widget build(BuildContext context) {
    if (followStatus.isFollowing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _SecondaryFollowButton(
                  label: 'Following',
                  isBusy: isBusy,
                  onTap: onUnfollow,
                ),
              ),
              const SizedBox(width: 10),
              _NotifyBellButton(
                enabled: notifyUploads,
                isBusy: isBusy,
                onTap: onToggleNotify,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            notifyUploads
                ? 'You\'ll be notified when ${_short(storeName)} uploads '
                    'new products.'
                : 'Upload notifications are off.',
            style: AppTextStyles.caption(height: 1.35),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    if (followStatus.isPending) {
      return _SecondaryFollowButton(
        label: 'Requested',
        isBusy: isBusy,
        onTap: onUnfollow,
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isBusy ? null : onFollow,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child:
            isBusy
                ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppColors.textOnPrimary,
                  ),
                )
                : Text(
                  'Follow',
                  style: AppTextStyles.button(),
                ),
      ),
    );
  }

  static String _short(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'this store';
    final first = trimmed.split(RegExp(r'\s+')).first;
    return first.isEmpty ? trimmed : first;
  }
}

class _SecondaryFollowButton extends StatelessWidget {
  const _SecondaryFollowButton({
    required this.label,
    required this.isBusy,
    required this.onTap,
  });

  final String label;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Material(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: isBusy ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child:
                isBusy
                    ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.textPrimary,
                      ),
                    )
                    : Text(
                      label,
                      style: AppTextStyles.button(
                        color: AppColors.textPrimary,
                      ),
                    ),
          ),
        ),
      ),
    );
  }
}

class _NotifyBellButton extends StatelessWidget {
  const _NotifyBellButton({
    required this.enabled,
    required this.isBusy,
    required this.onTap,
  });

  final bool enabled;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: isBusy ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Icon(
            enabled
                ? Icons.notifications_rounded
                : Icons.notifications_off_outlined,
            color: AppColors.textPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }
}
