import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project_c/bloc/account_profile/account_profile_bloc.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/floating_bottom_nav_bar.dart';
import 'package:project_c/helper/widgets/primary_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/catalog/catalog_profile.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/profile/profile_widgets/profile_photo_picker.dart';
import 'package:project_c/services/store_products_prefetcher.dart';
import 'package:project_c/webservice/import/import_repository.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  static const _tag = 'ProfileTab';

  int _pendingImportCount = 0;
  String? _countStoreId;

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
    final storeId = bloc.state.profile?.ownStore?.id.trim() ?? '';
    if (storeId.isNotEmpty) {
      await _loadImportRequestCount(storeId);
    }
  }

  Future<void> _loadImportRequestCount(String storeId) async {
    final id = storeId.trim();
    if (id.isEmpty) return;
    try {
      final repo = ServiceLocator.get<ImportRepository>();
      var pending = 0;
      String? cursor;
      do {
        final page = await repo.listStoreRequests(
          storeId: id,
          direction: 'incoming',
          limit: 50,
          cursor: cursor,
        );
        pending += page.items.where((r) => r.isPending).length;
        cursor = page.nextCursor;
      } while (cursor != null && cursor.isNotEmpty);
      if (!mounted) return;
      setState(() {
        _pendingImportCount = pending;
        _countStoreId = id;
      });
    } catch (e) {
      AppLog.e(_tag, 'Import request count failed', e);
    }
  }

  Future<void> _openImportRequests({
    required String storeId,
    required String storeName,
  }) async {
    await Navigator.of(context).pushNamed(
      Routes.storeImportRequestsRoute,
      arguments: <String, Object?>{
        'storeId': storeId,
        'storeName': storeName,
      },
    );
    if (!mounted) return;
    await _loadImportRequestCount(storeId);
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
        BlocListener<AccountProfileBloc, AccountProfileState>(
          listenWhen:
              (prev, curr) =>
                  prev.profile?.ownStore?.id != curr.profile?.ownStore?.id,
          listener: (context, state) {
            final storeId = state.profile?.ownStore?.id.trim() ?? '';
            if (storeId.isEmpty) {
              setState(() {
                _pendingImportCount = 0;
                _countStoreId = null;
              });
              return;
            }
            _loadImportRequestCount(storeId);
          },
        ),
      ],
      child: BlocBuilder<AccountProfileBloc, AccountProfileState>(
        builder: (context, state) {
          final profile = state.profile;
          final ownStore = profile?.ownStore;
          final imageUrl = profile?.effectiveProfileImageUrl ?? '';
          final storeId = ownStore?.id.trim() ?? '';
          if (storeId.isNotEmpty &&
              storeId != _countStoreId &&
              _countStoreId == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _loadImportRequestCount(storeId);
            });
          }

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
                  const SizedBox(height: 16),
                  _ImportRequestsTile(
                    pendingCount: _pendingImportCount,
                    onTap:
                        () => _openImportRequests(
                          storeId: ownStore.id,
                          storeName: ownStore.name,
                        ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        StoreProductsPrefetcher.instance.prefetch(ownStore.id);
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
                ] else ...[
                  const SizedBox(height: 24),
                  Text(
                    'Create a store to add products and import catalogues from other stores.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySecondary(height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Create store',
                    onPressed:
                        () => Navigator.of(
                          context,
                        ).pushNamed(Routes.storeSetupRoute),
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

class _ImportRequestsTile extends StatelessWidget {
  const _ImportRequestsTile({
    required this.pendingCount,
    required this.onTap,
  });

  final int pendingCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badge = pendingCount > 99 ? '99+' : '$pendingCount';
    return Material(
      color: AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inbox_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import requests',
                      style: AppTextStyles.body(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pendingCount > 0
                          ? '$pendingCount pending'
                          : 'Incoming and sent requests',
                      style: AppTextStyles.caption(),
                    ),
                  ],
                ),
              ),
              if (pendingCount > 0)
                Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badge,
                    style: AppTextStyles.caption(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textOnPrimary,
                      height: 1,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

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
