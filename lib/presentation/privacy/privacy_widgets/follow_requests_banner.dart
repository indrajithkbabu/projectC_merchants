import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';

/// Owner banner for pending follow requests (walkthrough screen 03).
class FollowRequestsBanner extends StatelessWidget {
  const FollowRequestsBanner({
    super.key,
    required this.pendingCount,
    required this.onTap,
    this.previewNames = const [],
  });

  final int pendingCount;
  final List<String> previewNames;
  final VoidCallback onTap;

  static String subtitleFor({
    required List<String> previewNames,
    required int pendingCount,
  }) {
    final names =
        previewNames
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
    if (names.isEmpty) {
      if (pendingCount <= 0) return '';
      return pendingCount == 1
          ? '1 pending request'
          : '$pendingCount pending requests';
    }
    if (names.length == 1 && pendingCount <= 1) {
      return names.first;
    }
    final others =
        pendingCount > 1 ? pendingCount - 1 : (names.length - 1).clamp(0, 99);
    if (others <= 0) return names.first;
    return '${names.first} + $others others';
  }

  @override
  Widget build(BuildContext context) {
    final count = pendingCount < 0 ? 0 : pendingCount;
    final names =
        previewNames
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .take(2)
            .toList(growable: false);
    final subtitle = subtitleFor(
      previewNames: previewNames,
      pendingCount: count,
    );

    return Material(
      color: AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _OverlappingInitials(names: names),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Follow requests',
                      style: AppTextStyles.body(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _CountBadge(count: count),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlappingInitials extends StatelessWidget {
  const _OverlappingInitials({required this.names});

  final List<String> names;

  String _initial(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final shown = names.isEmpty ? const <String>['?'] : names;
    final width = shown.length == 1 ? 40.0 : 58.0;

    return SizedBox(
      width: width,
      height: 40,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 18.0,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surfaceSecondary, width: 2),
                ),
                child: Text(
                  _initial(shown[i]),
                  style: AppTextStyles.label(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        style: AppTextStyles.caption(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textOnPrimary,
          height: 1,
        ),
      ),
    );
  }
}
