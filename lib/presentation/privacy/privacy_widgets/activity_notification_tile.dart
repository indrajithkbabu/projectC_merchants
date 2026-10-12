import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/catalog/activity_api_models.dart';

/// One Instagram-style activity row.
class ActivityNotificationTile extends StatelessWidget {
  const ActivityNotificationTile({
    super.key,
    required this.item,
    required this.onTap,
    this.showDivider = false,
  });

  final ActivityItem item;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final leadingUrl = _leadingUrl(item);
    final title = _titleFor(item);
    final subtitle = _subtitleFor(item);
    final timeLabel = _relativeTime(item.createdAt);
    final hasThumbs = item.thumbnails.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color:
              item.read
                  ? Colors.transparent
                  : AppColors.surfaceSecondary.withValues(alpha: 0.55),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment:
                    hasThumbs
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                children: [
                  _Avatar(url: leadingUrl, fallback: _fallbackLetter(item)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: title,
                                style: AppTextStyles.body(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                              if (subtitle.isNotEmpty)
                                TextSpan(
                                  text: ' $subtitle',
                                  style: AppTextStyles.body(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 1.35,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                            ],
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (timeLabel.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            timeLabel,
                            style: AppTextStyles.caption(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (hasThumbs) ...[
                          const SizedBox(height: 10),
                          _ThumbStrip(urls: item.thumbnails),
                        ],
                      ],
                    ),
                  ),
                  if (!item.read) ...[
                    const SizedBox(width: 10),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.border.withValues(alpha: 0.7),
          ),
      ],
    );
  }

  static String _leadingUrl(ActivityItem item) {
    final actorUrl = item.actor?.avatarUrl.trim() ?? '';
    if (actorUrl.isNotEmpty) return actorUrl;
    return item.store?.logoUrl.trim() ?? '';
  }

  static String _fallbackLetter(ActivityItem item) {
    final name =
        (item.actor?.name.trim().isNotEmpty == true
                ? item.actor!.name
                : item.store?.name ?? '?')
            .trim();
    if (name.isEmpty) return '?';
    return name.substring(0, 1).toUpperCase();
  }

  static String _titleFor(ActivityItem item) {
    switch (item.type) {
      case ActivityItemType.newFollower:
        return item.actor?.name.trim().isNotEmpty == true
            ? item.actor!.name.trim()
            : 'Someone';
      case ActivityItemType.productLiked:
        return item.actor?.name.trim().isNotEmpty == true
            ? item.actor!.name.trim()
            : 'Someone';
      case ActivityItemType.newUpload:
        return item.store?.name.trim().isNotEmpty == true
            ? item.store!.name.trim()
            : 'A store';
      case ActivityItemType.requestApproved:
        return item.store?.name.trim().isNotEmpty == true
            ? item.store!.name.trim()
            : 'A store';
      case ActivityItemType.followRequest:
        return item.actor?.name.trim().isNotEmpty == true
            ? item.actor!.name.trim()
            : 'Someone';
      case ActivityItemType.unknown:
        return item.store?.name.trim().isNotEmpty == true
            ? item.store!.name.trim()
            : 'Update';
    }
  }

  static String _subtitleFor(ActivityItem item) {
    switch (item.type) {
      case ActivityItemType.newFollower:
        return 'started following you.';
      case ActivityItemType.productLiked:
        final store = item.store?.name.trim() ?? '';
        return store.isEmpty
            ? 'liked your photo.'
            : 'liked your photo in $store.';
      case ActivityItemType.newUpload:
        final n = item.count < 1 ? 1 : item.count;
        return n == 1 ? 'added 1 new product.' : 'added $n new products.';
      case ActivityItemType.requestApproved:
        return 'accepted your request to follow.';
      case ActivityItemType.followRequest:
        return 'requested to follow you.';
      case ActivityItemType.unknown:
        return '';
    }
  }

  static String _relativeTime(DateTime at) {
    if (at.millisecondsSinceEpoch <= 0) return '';
    final diff = DateTime.now().toUtc().difference(at.toUtc());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) return '${weeks}w ago';
    return '${at.day}/${at.month}/${at.year}';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.fallback});

  final String url;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child:
          url.isEmpty
              ? ColoredBox(
                color: AppColors.surfaceSecondary,
                child: Center(
                  child: Text(
                    fallback,
                    style: AppTextStyles.body(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
              )
              : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: 48,
                height: 48,
                errorWidget:
                    (_, __, ___) => ColoredBox(
                      color: AppColors.surfaceSecondary,
                      child: Center(
                        child: Text(
                          fallback,
                          style: AppTextStyles.body(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ),
              ),
    );
  }
}

class _ThumbStrip extends StatelessWidget {
  const _ThumbStrip({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final shown = urls.take(3).toList(growable: false);
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: shown.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          return Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, width: 0.8),
            ),
            clipBehavior: Clip.antiAlias,
            child: CachedNetworkImage(
              imageUrl: shown[index],
              fit: BoxFit.cover,
              errorWidget:
                  (_, __, ___) =>
                      ColoredBox(color: AppColors.surfaceSecondary),
            ),
          );
        },
      ),
    );
  }
}
