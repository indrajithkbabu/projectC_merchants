import 'package:flutter/material.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_privacy_mode_pill.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_visitor_follow_bar.dart';
import 'package:project_c/presentation/team/team_widgets/team_member_avatar.dart';

class StoreProfileLogo extends StatelessWidget {
  const StoreProfileLogo({
    super.key,
    required this.size,
    this.imageUrl,
    this.storeName = '',
  });

  final double size;
  final String? imageUrl;

  /// Used for initials when [imageUrl] is empty (no storefront icon).
  final String storeName;

  static String initialsFor(String name) {
    final parts =
        name
            .trim()
            .split(RegExp(r'\s+'))
            .where((p) => p.isNotEmpty)
            .toList(growable: false);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final w = parts.first;
      return w.length >= 2
          ? w.substring(0, 2).toUpperCase()
          : w.substring(0, 1).toUpperCase();
    }
    return ('${parts[0][0]}${parts[1][0]}').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    final fallback = _InitialsLogo(size: size, storeName: storeName);
    if (url.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: ProductMediaImage(
            path: url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            error: fallback,
          ),
        ),
      );
    }
    return fallback;
  }
}

class _InitialsLogo extends StatelessWidget {
  const _InitialsLogo({required this.size, required this.storeName});

  final double size;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    final initials = StoreProfileLogo.initialsFor(storeName);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: Text(
        initials,
        style: AppTextStyles.body(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}

class StoreProfileHeaderCard extends StatelessWidget {
  const StoreProfileHeaderCard({
    super.key,
    required this.state,
    this.onAddMembers,
    this.onCopyStoreLink,
    this.onToggleDetails,
    this.onManageImages,
    this.onFollow,
    this.onUnfollow,
    this.onToggleNotify,
    this.onFollowersTap,
    this.onFollowingTap,
  });

  final StoreProfileState state;
  final VoidCallback? onAddMembers;
  final VoidCallback? onCopyStoreLink;
  final VoidCallback? onToggleDetails;
  final VoidCallback? onManageImages;
  final VoidCallback? onFollow;
  final VoidCallback? onUnfollow;
  final VoidCallback? onToggleNotify;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  @override
  Widget build(BuildContext context) {
    if (!state.isOwnStore) {
      return _VisitorHeaderCard(
        state: state,
        onToggleDetails: onToggleDetails,
        onFollow: onFollow,
        onUnfollow: onUnfollow,
        onToggleNotify: onToggleNotify,
      );
    }
    return _OwnStoreHeaderCard(
      state: state,
      onAddMembers: onAddMembers,
      onCopyStoreLink: onCopyStoreLink,
      onToggleDetails: onToggleDetails,
      onManageImages: onManageImages,
      onFollowersTap: onFollowersTap,
      onFollowingTap: onFollowingTap,
    );
  }
}

class _OwnStoreHeaderCard extends StatelessWidget {
  const _OwnStoreHeaderCard({
    required this.state,
    this.onAddMembers,
    this.onCopyStoreLink,
    this.onToggleDetails,
    this.onManageImages,
    this.onFollowersTap,
    this.onFollowingTap,
  });

  final StoreProfileState state;
  final VoidCallback? onAddMembers;
  final VoidCallback? onCopyStoreLink;
  final VoidCallback? onToggleDetails;
  final VoidCallback? onManageImages;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  @override
  Widget build(BuildContext context) {
    final previewMembers = state.teammates.take(3).toList();
    return Column(
      children: [
        Column(
          children: [
            GestureDetector(
              onTap: onManageImages ?? onToggleDetails,
              behavior: HitTestBehavior.opaque,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  StoreProfileLogo(
                    size: 86,
                    imageUrl: state.coverImageUrl,
                    storeName: state.storeName,
                  ),
                  if (onManageImages != null)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.background,
                            width: 2,
                          ),
                        ),
                        child:
                            state.isUpdatingStoreImages
                                ? Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.textOnPrimary,
                                  ),
                                )
                                : Icon(
                                  Icons.camera_alt_rounded,
                                  size: 14,
                                  color: AppColors.textOnPrimary,
                                ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            StoreVisitorCountsRow(
              productCount: state.productCount,
              followerCount: state.followerCount,
              followingCount: state.followingCount,
              onFollowersTap: onFollowersTap,
              onFollowingTap: onFollowingTap,
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onToggleDetails,
              behavior: HitTestBehavior.opaque,
              child: Text(
                state.storeName,
                style: AppTextStyles.headline(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onCopyStoreLink,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    state.storeLink,
                    style: AppTextStyles.caption(
                      fontSize: 14,
                      color: AppColors.accent,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: AppColors.accent,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        StorePrivacyModePill(mode: state.privacy),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onToggleDetails,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (previewMembers.isNotEmpty) ...[
                  SizedBox(
                    width: 28 + ((previewMembers.length - 1) * 18),
                    height: 24,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (var i = 0; i < previewMembers.length; i++)
                          Positioned(
                            left: i * 18,
                            child: TeamMemberAvatar(
                              initials: previewMembers[i].initials,
                              color: Color(previewMembers[i].avatarColor),
                              radius: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    '${state.teammateCount} members · ${state.productCount} products',
                    style: AppTextStyles.caption(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (onAddMembers != null)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onAddMembers,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: Text(
                  'Add member',
                  style: AppTextStyles.caption(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Visitor identity matching screens 08–10 (counts, pill, Follow).
class _VisitorHeaderCard extends StatelessWidget {
  const _VisitorHeaderCard({
    required this.state,
    this.onToggleDetails,
    this.onFollow,
    this.onUnfollow,
    this.onToggleNotify,
  });

  final StoreProfileState state;
  final VoidCallback? onToggleDetails;
  final VoidCallback? onFollow;
  final VoidCallback? onUnfollow;
  final VoidCallback? onToggleNotify;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onToggleDetails,
          behavior: HitTestBehavior.opaque,
          child: StoreProfileLogo(
            size: 86,
            imageUrl: state.coverImageUrl,
            storeName: state.storeName,
          ),
        ),
        const SizedBox(height: 16),
        StoreVisitorCountsRow(
          productCount: state.productCount,
          followerCount: state.followerCount,
          followingCount: state.followingCount,
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: onToggleDetails,
          behavior: HitTestBehavior.opaque,
          child: Text(
            state.storeName,
            style: AppTextStyles.headline(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          state.visitorSubtitle,
          style: AppTextStyles.caption(fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        StorePrivacyModePill(mode: state.privacy),
        if (state.showVisitorFollowChrome &&
            onFollow != null &&
            onUnfollow != null &&
            onToggleNotify != null) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: StoreVisitorFollowBar(
              followStatus: state.followStatus,
              isBusy: state.isFollowBusy,
              notifyUploads: state.notifyUploads,
              storeName: state.storeName,
              onFollow: onFollow!,
              onUnfollow: onUnfollow!,
              onToggleNotify: onToggleNotify!,
            ),
          ),
        ],
      ],
    );
  }
}
