import 'package:flutter/material.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/presentation/team/team_widgets/team_member_avatar.dart';

class StoreProfileLogo extends StatelessWidget {
  const StoreProfileLogo({
    super.key,
    required this.size,
    this.imageUrl,
  });

  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.255;
    final url = imageUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: size,
          height: size,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _FallbackLogo(size: size),
          ),
        ),
      );
    }
    return _FallbackLogo(size: size);
  }
}

class _FallbackLogo extends StatelessWidget {
  const _FallbackLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.255;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: Icon(
        Icons.storefront_rounded,
        color: AppColors.textOnPrimary,
        size: size * 0.44,
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
  });

  final StoreProfileState state;
  final VoidCallback? onAddMembers;
  final VoidCallback? onCopyStoreLink;
  final VoidCallback? onToggleDetails;
  final VoidCallback? onManageImages;

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
                                ? const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.textOnPrimary,
                                  ),
                                )
                                : const Icon(
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
                const Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: AppColors.accent,
                ),
              ],
            ),
          ),
        ),
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
                Flexible(child: _MembersProductsLabel(state: state)),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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

class _MembersProductsLabel extends StatelessWidget {
  const _MembersProductsLabel({required this.state});

  final StoreProfileState state;

  @override
  Widget build(BuildContext context) {
    final productsLabel = '${state.productCount} products';

    if (!state.isOwnStore) {
      return Text(
        productsLabel,
        style: AppTextStyles.caption(fontSize: 14),
        textAlign: TextAlign.center,
      );
    }

    return Text(
      '${state.teammateCount} members · $productsLabel',
      style: AppTextStyles.caption(fontSize: 14),
      textAlign: TextAlign.center,
    );
  }
}
