import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/account_profile/account_profile_bloc.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/catalog/catalog_profile.dart';

/// Compact account avatar for the Stores header.
///
/// Reads [AccountProfileBloc] only — no dedicated fetch. Image/initials come
/// from the session-backed profile cache the shell already holds.
class StoreListingProfileAvatar extends StatelessWidget {
  const StoreListingProfileAvatar({super.key, this.onTap, this.size = 36});

  final VoidCallback? onTap;
  final double size;

  String _initials(CatalogProfile? profile) {
    final first = profile?.firstName?.trim() ?? '';
    final last = profile?.lastName?.trim() ?? '';
    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    if (first.isNotEmpty) {
      return first.substring(0, first.length.clamp(0, 2)).toUpperCase();
    }
    final phone = profile?.phone ?? '';
    if (phone.length >= 2) return phone.substring(phone.length - 2);
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountProfileBloc, AccountProfileState>(
      buildWhen:
          (prev, curr) =>
              prev.profile?.effectiveProfileImageUrl !=
                  curr.profile?.effectiveProfileImageUrl ||
              prev.profile?.firstName != curr.profile?.firstName ||
              prev.profile?.lastName != curr.profile?.lastName ||
              prev.profile?.phone != curr.profile?.phone,
      builder: (context, state) {
        final profile = state.profile;
        final imageUrl = profile?.effectiveProfileImageUrl.trim() ?? '';
        final hasImage = imageUrl.isNotEmpty;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Ink(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceSecondary,
                border: Border.all(color: AppColors.border, width: 1),
                image:
                    hasImage
                        ? DecorationImage(
                          image: CachedNetworkImageProvider(
                            imageUrl,
                            cacheManager: CatalogImageCache.instance,
                          ),
                          fit: BoxFit.cover,
                        )
                        : null,
              ),
              child:
                  hasImage
                      ? null
                      : Center(
                        child: Text(
                          _initials(profile),
                          style: AppTextStyles.caption(
                            fontSize: size * 0.32,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
            ),
          ),
        );
      },
    );
  }
}
