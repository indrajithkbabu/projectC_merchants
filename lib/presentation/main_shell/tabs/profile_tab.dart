import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project_c/bloc/account_profile/account_profile_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/floating_bottom_nav_bar.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/catalog/catalog_profile.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/profile/profile_widgets/profile_photo_picker.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

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

  Future<void> _pullToRefresh(BuildContext context) async {
    final bloc = context.read<AccountProfileBloc>();
    bloc.add(const AccountProfileRefreshed());
    await bloc.stream.firstWhere((s) => !s.isRefreshing);
  }

  Future<void> _showImageOptions(
    BuildContext context,
    AccountProfileState state,
  ) async {
    final action = await showModalBottomSheet<_ProfileTabPhotoAction>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        final hasImage = state.hasProfileImage;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded),
                  title: Text('Use camera', style: AppTextStyles.body()),
                  onTap:
                      () => Navigator.of(
                        sheetContext,
                      ).pop(_ProfileTabPhotoAction.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: Text(
                    'Choose from gallery',
                    style: AppTextStyles.body(),
                  ),
                  onTap:
                      () => Navigator.of(
                        sheetContext,
                      ).pop(_ProfileTabPhotoAction.gallery),
                ),
                if (hasImage)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                    title: Text(
                      'Delete photo',
                      style: AppTextStyles.body(color: AppColors.error),
                    ),
                    onTap:
                        () => Navigator.of(
                          sheetContext,
                        ).pop(_ProfileTabPhotoAction.delete),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (!context.mounted || action == null) return;
    final bloc = context.read<AccountProfileBloc>();
    switch (action) {
      case _ProfileTabPhotoAction.gallery:
        bloc.add(
          const AccountProfilePickImageRequested(ImageSource.gallery),
        );
        return;
      case _ProfileTabPhotoAction.camera:
        bloc.add(
          const AccountProfilePickImageRequested(ImageSource.camera),
        );
        return;
      case _ProfileTabPhotoAction.delete:
        bloc.add(const AccountProfileRemoveImageRequested());
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = FloatingBottomNavBar.reservedHeight(context) + 8;
    return MultiBlocListener(
      listeners: [
        BlocListener<AccountProfileBloc, AccountProfileState>(
          listenWhen:
              (prev, curr) =>
                  curr.errorMessage != null &&
                  curr.errorMessage != prev.errorMessage,
          listener: (context, state) {
            final message = state.errorMessage?.trim();
            if (message == null || message.isEmpty) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
            context.read<AccountProfileBloc>().add(
              const AccountProfileClearMessage(),
            );
          },
        ),
      ],
      child: BlocBuilder<AccountProfileBloc, AccountProfileState>(
        builder: (context, state) {
          final profile = state.profile;
          final ownStore = profile?.ownStore;
          final imageUrl = profile?.effectiveProfileImageUrl ?? '';
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => _pullToRefresh(context),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppPadding.screen(
                top: ScreenWrapper.statusBarTop(context) + 24,
                bottom: bottomPad,
              ),
              children: [
                ProfilePhotoPicker(
                  firstName: profile?.firstName ?? _initials(profile),
                  imageUrl: imageUrl.isEmpty ? null : imageUrl,
                  isLoading: state.isUpdatingImage,
                  onTap: () => _showImageOptions(context, state),
                ),
                const SizedBox(height: 16),
                Text(
                  profile?.displayName ?? 'Your profile',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headline(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile?.phone ?? '',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySecondary(),
                ),
                const SizedBox(height: 20),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Column(
                      children: [
                        _InfoLine(
                          value: profile?.phone ?? '—',
                          label: 'Mobile',
                        ),
                        if (ownStore != null) ...[
                          const SizedBox(height: 14),
                          _InfoLine(
                            value: ownStore.name,
                            label: 'Store',
                          ),
                          const SizedBox(height: 14),
                          _InfoLine(
                            value: ownStore.storeLink,
                            label: 'Store link',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (ownStore != null) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed(
                          Routes.storeProfileRoute,
                          arguments: <String, Object?>{
                            'isOwnStore': true,
                            'storeId': ownStore.id,
                            'storeName': ownStore.name,
                            'storeLink': ownStore.storeLink,
                          },
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Open my store',
                        style: AppTextStyles.button(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _ProfileTabPhotoAction { camera, gallery, delete }

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTextStyles.body(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption()),
        ],
      ),
    );
  }
}
