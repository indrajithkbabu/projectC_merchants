import 'package:flutter/material.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/presentation/team/team_widgets/team_member_avatar.dart';

class StoreProfileLogo extends StatelessWidget {
  const StoreProfileLogo({super.key, required this.size});

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
  });

  final StoreProfileState state;
  final VoidCallback? onAddMembers;
  final VoidCallback? onCopyStoreLink;

  @override
  Widget build(BuildContext context) {
    final previewMembers = state.teammates.take(3).toList();
    return Column(
      children: [
        const StoreProfileLogo(size: 86),
        const SizedBox(height: 14),
        Text(
          state.storeName,
          style: AppTextStyles.headline(
            fontSize: 34,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onCopyStoreLink,
          behavior: HitTestBehavior.opaque,
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
        const SizedBox(height: 10),
        Row(
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
            Flexible(child: _MembersLabel(state: state, onAddMembers: onAddMembers)),
          ],
        ),
      ],
    );
  }
}

class _MembersLabel extends StatelessWidget {
  const _MembersLabel({required this.state, this.onAddMembers});

  final StoreProfileState state;
  final VoidCallback? onAddMembers;

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

    if (state.showAddMembersCta) {
      return GestureDetector(
        onTap: onAddMembers,
        behavior: HitTestBehavior.opaque,
        child: Text.rich(
          TextSpan(
            style: AppTextStyles.caption(fontSize: 14),
            children: [
              TextSpan(
                text: 'Add members',
                style: AppTextStyles.caption(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              TextSpan(text: ' · $productsLabel'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Text(
      '${state.teammateCount} members · $productsLabel',
      style: AppTextStyles.caption(fontSize: 14),
      textAlign: TextAlign.center,
    );
  }
}
