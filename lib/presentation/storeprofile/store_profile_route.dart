import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project_c/bloc/add_store_product/add_store_product_bloc.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_product_grid.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_profile_collapsing_header.dart';

class StoreProfileRoute extends StatelessWidget {
  const StoreProfileRoute({super.key});

  Future<void> _addProducts(BuildContext context) async {
    final source = await showModalBottomSheet<_ImagePickSource>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded),
                  title: Text('Camera', style: AppTextStyles.body()),
                  onTap:
                      () => Navigator.of(context).pop(_ImagePickSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: Text('Gallery', style: AppTextStyles.body()),
                  onTap:
                      () => Navigator.of(context).pop(_ImagePickSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!context.mounted || source == null) return;

    final picker = ImagePicker();
    final selectedItems = <GalleryImageItem>[];

    try {
      if (source == _ImagePickSource.camera) {
        final photo = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1920,
          maxHeight: 1920,
        );
        if (photo != null) {
          selectedItems.add(
            GalleryImageItem(
              id: 'camera_${photo.path.hashCode}',
              filePath: photo.path,
              isPlaceholder: false,
            ),
          );
        }
      } else {
        final photos = await picker.pickMultiImage(
          imageQuality: 85,
          maxWidth: 1920,
          maxHeight: 1920,
        );
        final limited = photos.take(25).toList();
        for (var i = 0; i < limited.length; i++) {
          final photo = limited[i];
          selectedItems.add(
            GalleryImageItem(
              id: 'gallery_${photo.path.hashCode}_$i',
              filePath: photo.path,
              isPlaceholder: false,
            ),
          );
        }
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open image picker right now.')),
      );
      return;
    }

    if (!context.mounted || selectedItems.isEmpty) return;

    final published = await Navigator.of(context).pushNamed(
      Routes.addProductFormRoute,
      arguments: <String, Object?>{
        'selectedItems': selectedItems,
        'storeId': context.read<StoreProfileBloc>().state.storeId,
      },
    );
    if (!context.mounted) return;
    if (published is Map) {
      final payload = Map<String, Object?>.from(published);
      context.read<StoreProfileBloc>().add(
        StoreProfileProductPublished(StoreProduct.fromMap(payload)),
      );
    }
  }

  Future<void> _openProductDetails(
    BuildContext context,
    StoreProfileState state,
    StoreProduct product,
  ) async {
    final result = await Navigator.of(context).pushNamed(
      Routes.productDetailsRoute,
      arguments: <String, Object?>{
        'product': product,
        'storeName': state.storeName,
        'storeLink': state.storeLink,
        'storeId': state.storeId,
        'isOwnStore': state.isOwnStore,
      },
    );
    if (!context.mounted || result is! Map) return;

    final payload = Map<String, Object?>.from(result);
    if (payload['deleted'] == true) {
      final productId = payload['productId'] as String?;
      if (productId == null || productId.isEmpty) return;
      context.read<StoreProfileBloc>().add(
        StoreProfileProductDeleted(productId),
      );
      return;
    }

    if (payload['updated'] == true) {
      context.read<StoreProfileBloc>().add(
        StoreProfileProductUpdated(
          StoreProduct.fromMap(payload),
          replacedListingId: payload['replacedListingId'] as String?,
        ),
      );
    }
  }

  Future<void> _confirmDeleteProduct(
    BuildContext context,
    StoreProduct product,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            'Delete product?',
            style: AppTextStyles.headline(fontSize: 18),
          ),
          content: Text(
            'This removes "${product.title}" from your store. Linked imports in other stores will also stop showing it.',
            style: AppTextStyles.body(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Cancel', style: AppTextStyles.button()),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Delete',
                style: AppTextStyles.button(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
    if (!context.mounted || confirmed != true) return;
    context.read<StoreProfileBloc>().add(
      StoreProfileProductDeleted(product.id),
    );
  }

  Future<void> _openGallery(
    BuildContext context,
    StoreProfileState state,
  ) async {
    final result = await Navigator.of(context).pushNamed(
      Routes.storeGalleryRoute,
      arguments: <String, Object?>{
        'products': state.products,
        'storeName': state.storeName,
        'storeLink': state.storeLink,
        'storeId': state.storeId,
        'isOwnStore': state.isOwnStore,
      },
    );
    if (!context.mounted || result is! Map) return;
    final products = result['products'];
    if (products is! List) return;
    final mapped = products.whereType<StoreProduct>().toList();
    // Replace local list with gallery's post-edit/delete snapshot.
    context.read<StoreProfileBloc>().add(
      StoreProfileProductsReplaced(mapped),
    );
  }

  Future<void> _openAddMembers(
    BuildContext context,
    StoreProfileState state,
  ) async {
    await Navigator.of(context).pushNamed(
      Routes.addTeamRoute,
      arguments: state.storeName,
    );
    if (!context.mounted) return;
    // Returning via system back (without Continue) — refresh members.
    context.read<StoreProfileBloc>().add(const StoreProfileLoadMembers());
  }

  Future<void> _copyStoreLink(
    BuildContext context,
    StoreProfileState state,
  ) async {
    final link = state.storeLink.trim();
    if (link.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Store link copied')),
    );
  }

  void _openImport(BuildContext context, StoreProfileState state) {
    if (state.isOwnStore) {
      Navigator.of(context).pushNamed(Routes.storeListingRoute);
      return;
    }
    Navigator.of(context).pushNamed(
      Routes.storeImportSelectRoute,
      arguments: <String, Object?>{
        'storeId': state.storeId,
        'storeName': state.storeName,
        'storeLink': state.storeLink,
        'products': state.products,
        'avatarColor': state.avatarColor,
      },
    );
  }

  void _onBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop();
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.storeListingRoute,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<StoreProfileBloc, StoreProfileState>(
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
            context.read<StoreProfileBloc>().add(
              const StoreProfileClearMessage(),
            );
          },
        ),
        BlocListener<StoreProfileBloc, StoreProfileState>(
          listenWhen:
              (prev, curr) =>
                  curr.infoMessage != null &&
                  curr.infoMessage != prev.infoMessage,
          listener: (context, state) {
            final message = state.infoMessage?.trim();
            if (message == null || message.isEmpty) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
            context.read<StoreProfileBloc>().add(
              const StoreProfileClearMessage(),
            );
          },
        ),
      ],
      child: ScreenWrapper(
        backgroundColor: AppColors.background,
        statusBarIconBrightness: Brightness.dark,
        child: BlocBuilder<StoreProfileBloc, StoreProfileState>(
          builder: (context, state) {
            return Padding(
              padding: AppPadding.screen(
                top: ScreenWrapper.statusBarTop(context),
                bottom: 24,
              ),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: StoreProfileCollapsingHeaderDelegate(
                      state: state,
                      onBack: () => _onBack(context),
                      onAddProducts: () => _addProducts(context),
                      onImport: () => _openImport(context, state),
                      onAddMembers:
                          state.showAddMembersCta
                              ? () => _openAddMembers(context, state)
                              : null,
                      onCopyStoreLink: () => _copyStoreLink(context, state),
                      onViewAll:
                          state.products.isNotEmpty
                              ? () => _openGallery(context, state)
                              : null,
                      toolbarActions: [
                        if (state.showImportRequestsBadge) ...[
                          _ImportRequestsIconButton(
                            count: state.pendingImportRequestCount,
                            onTap: () async {
                              await Navigator.of(context).pushNamed(
                                Routes.storeImportRequestsRoute,
                                arguments: <String, Object?>{
                                  'storeId': state.storeId,
                                  'storeName': state.storeName,
                                },
                              );
                              if (!context.mounted) return;
                              context.read<StoreProfileBloc>().add(
                                const StoreProfileLoadImportRequestCount(),
                              );
                            },
                          ),
                          if (state.products.isNotEmpty)
                            const SizedBox(width: 8),
                        ],
                        if (state.products.isNotEmpty)
                          _RoundIconButton(
                            icon: Icons.photo_library_outlined,
                            onTap: () => _openGallery(context, state),
                          ),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 16),
                    sliver: StoreProductGrid(
                      products: state.products,
                      deletingProductId: state.deletingProductId,
                      onProductTap:
                          (product) => _openProductDetails(
                            context,
                            state,
                            product,
                          ),
                      onProductDelete:
                          state.isOwnStore
                              ? (product) =>
                                  _confirmDeleteProduct(context, product)
                              : null,
                    ).buildSliver(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

enum _ImagePickSource { camera, gallery }

class _ImportRequestsIconButton extends StatelessWidget {
  const _ImportRequestsIconButton({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badge = count > 99 ? '99+' : '$count';
    return Material(
      color: AppColors.surfaceSecondary,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Center(
                child: Icon(
                  Icons.access_time_sharp,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
              ),
              if (count > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16),
                    height: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.background, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badge,
                      style: AppTextStyles.caption(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textOnPrimary,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSecondary,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
