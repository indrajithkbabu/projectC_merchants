import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/account_profile/account_profile_bloc.dart';
import 'package:project_c/bloc/store_gallery/store_gallery_bloc.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/floating_bottom_nav_bar.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/product_view_mode.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_my_store_tab.dart';
import 'package:project_c/services/product_view_preferences.dart';

/// Shell "My store" tab — Instagram-style owner UI ([StoreMyStoreTab]).
/// Settings opens from the toolbar hamburger.
class MyStoreTab extends StatefulWidget {
  const MyStoreTab({super.key});

  @override
  State<MyStoreTab> createState() => MyStoreTabState();
}

class MyStoreTabState extends State<MyStoreTab> {
  final Set<String> _selectedIds = {};
  bool _selectionMode = false;

  /// Consumes shell system-back while multi-select is active.
  bool consumeSystemBack() {
    if (!_selectionMode) return false;
    _exitSelection();
    return true;
  }

  void _exitSelection() {
    if (!_selectionMode && _selectedIds.isEmpty) return;
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _enterSelection(StoreProduct product) {
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..add(product.id);
    });
  }

  void _toggleSelected(StoreProduct product) {
    setState(() {
      if (_selectedIds.contains(product.id)) {
        _selectedIds.remove(product.id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(product.id);
      }
    });
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final count = _selectedIds.length;
    if (count == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            count == 1 ? 'Delete product?' : 'Delete $count products?',
            style: AppTextStyles.headline(fontSize: 18),
          ),
          content: Text(
            count == 1
                ? 'This removes the selected product from your store. Linked imports in other stores will also stop showing it.'
                : 'This removes the selected products from your store. Linked imports in other stores will also stop showing them.',
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
    final ids = _selectedIds.toList();
    _exitSelection();
    context.read<StoreProfileBloc>().add(StoreProfileProductsDeleted(ids));
  }

  Future<void> _openCollectionBrowse(
    BuildContext context,
    StoreProfileState state,
    StoreProduct product,
  ) async {
    StoreProduct media = product;
    for (final p in state.productsForMedia) {
      if (p.id == product.id) {
        media = p;
        break;
      }
    }
    // ignore: unawaited_futures
    CatalogImageCache.precacheUrls(
      ProductImagePaths.displayable(media.imagePaths),
      cacheWidth: CatalogImageCache.gridCacheWidth(),
    );
    final result = await Navigator.of(context).pushNamed(
      Routes.collectionBrowseRoute,
      arguments: <String, Object?>{
        'product': media,
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

    final newCollectionId = (payload['newCollectionId'] as String?)?.trim();
    if (payload['refreshCollections'] == true ||
        (newCollectionId != null && newCollectionId.isNotEmpty)) {
      context.read<StoreProfileBloc>().add(const StoreProfileLoadCollections());
      return;
    }

    if (payload['updated'] == true && payload.containsKey('id')) {
      context.read<StoreProfileBloc>().add(
        StoreProfileProductUpdated(
          StoreProduct.fromMap(payload),
          replacedListingId: payload['replacedListingId'] as String?,
        ),
      );
    }
  }

  Future<void> _openProductDetails(
    BuildContext context,
    StoreProfileState state,
    StoreProduct product, {
    int imageIndex = 0,
  }) async {
    StoreProduct media = product;
    for (final p in state.productsForMedia) {
      if (p.id == product.id) {
        media = p;
        break;
      }
    }

    final galleryState = StoreGalleryState(
      products: state.productsForMedia,
      storeName: state.storeName,
      storeLink: state.storeLink,
      storeId: state.storeId,
      isOwnStore: state.isOwnStore,
      sections: StoreGalleryState.buildSections(state.productsForMedia),
    );
    final feed = galleryState.buildPhotoFeed();
    final feedIndex = galleryState.feedIndexFor(
      productId: media.id,
      imageIndex: imageIndex,
    );

    final result = await Navigator.of(context).pushNamed(
      Routes.productDetailsRoute,
      arguments: <String, Object?>{
        'product': media,
        'storeName': state.storeName,
        'storeLink': state.storeLink,
        'storeId': state.storeId,
        'isOwnStore': state.isOwnStore,
        'imageIndex': imageIndex,
        'galleryFeed': feed,
        'galleryFeedIndex': feedIndex,
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

    if (payload['updated'] == true && payload.containsKey('id')) {
      context.read<StoreProfileBloc>().add(
        StoreProfileProductUpdated(
          StoreProduct.fromMap(payload),
          replacedListingId: payload['replacedListingId'] as String?,
        ),
      );
    }
  }

  void _onProductTap(
    BuildContext context,
    StoreProfileState state,
    StoreProduct product,
    ProductViewMode viewMode,
  ) {
    if (_selectionMode) {
      _toggleSelected(product);
      return;
    }
    if (viewMode == ProductViewMode.group) {
      _openCollectionBrowse(context, state, product);
      return;
    }
    _openProductDetails(context, state, product);
  }

  Future<void> _openFollowersFollowing(
    BuildContext context,
    StoreProfileState state, {
    required String initialTab,
  }) async {
    await Navigator.of(context).pushNamed(
      Routes.followersFollowingRoute,
      arguments: {
        'storeId': state.storeId,
        'storeName': state.storeName,
        'initialTab': initialTab,
        'followerCount': state.followerCount,
        'followingCount': state.followingCount,
      },
    );
    if (!context.mounted) return;
    context.read<StoreProfileBloc>().add(const StoreProfileLoadStoreMeta());
  }

  Future<void> _openFollowRequests(
    BuildContext context,
    StoreProfileState state,
  ) async {
    await Navigator.of(context).pushNamed(
      Routes.followRequestsRoute,
      arguments: {
        'storeId': state.storeId,
        'storeName': state.storeName,
      },
    );
    if (!context.mounted) return;
    context.read<StoreProfileBloc>().add(
      const StoreProfileLoadFollowRequestPreviews(),
    );
    context.read<StoreProfileBloc>().add(const StoreProfileLoadStoreMeta());
  }

  Future<void> _openImportRequests(
    BuildContext context,
    StoreProfileState state,
  ) async {
    await Navigator.of(context).pushNamed(
      Routes.storeImportRequestsRoute,
      arguments: <String, Object?>{
        'storeId': state.storeId,
        'storeName': state.storeName,
      },
    );
    if (!context.mounted) return;
    // TODO(backend): re-enable with import-requests count when API is live.
    // context.read<StoreProfileBloc>().add(
    //   const StoreProfileLoadImportRequestCount(),
    // );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).pushNamed(
      Routes.settingsRoute,
      arguments: <String, Object?>{
        'accountProfileBloc': context.read<AccountProfileBloc>(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewPrefs = ServiceLocator.get<ProductViewPreferences>();
    final bottomInset = FloatingBottomNavBar.reservedHeight(context);
    final top = ScreenWrapper.statusBarTop(context);

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
      child: BlocBuilder<StoreProfileBloc, StoreProfileState>(
        builder: (context, state) {
          return ListenableBuilder(
            listenable: viewPrefs,
            builder: (context, _) {
              final viewMode = viewPrefs.mode;
              // Match store-profile parent chrome: AppPadding.screen + status bar.
              return Padding(
                padding: AppPadding.screen(top: top, bottom: 0),
                child: Column(
                  children: [
                    if (_selectionMode)
                      _ShellSelectionBar(
                        count: _selectedIds.length,
                        onCancel: _exitSelection,
                        onDelete:
                            _selectedIds.isEmpty
                                ? null
                                : () => _confirmDeleteSelected(context),
                      ),
                    Expanded(
                      child: StoreMyStoreTab(
                        state: state,
                        showBack: false,
                        onBack: () {},
                        onOpenSettings: () => _openSettings(context),
                        onFollowersTap:
                            () => _openFollowersFollowing(
                              context,
                              state,
                              initialTab: 'followers',
                            ),
                        onFollowingTap:
                            () => _openFollowersFollowing(
                              context,
                              state,
                              initialTab: 'following',
                            ),
                        onOpenImportRequests:
                            () => _openImportRequests(context, state),
                        onOpenFollowRequests:
                            () => _openFollowRequests(context, state),
                        onProductTap:
                            (product) => _onProductTap(
                              context,
                              state,
                              product,
                              viewMode,
                            ),
                        onProductLongPress: _enterSelection,
                        bottomInset: bottomInset,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ShellSelectionBar extends StatelessWidget {
  const _ShellSelectionBar({
    required this.count,
    required this.onCancel,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onCancel;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              TextButton(
                onPressed: onCancel,
                child: Text(
                  'Cancel',
                  style: AppTextStyles.body(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: Text(
                  count == 0 ? 'Select products' : '$count selected',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: onDelete,
                child: Text(
                  'Delete',
                  style: AppTextStyles.body(
                    fontWeight: FontWeight.w700,
                    color:
                        onDelete == null
                            ? AppColors.textSecondary
                            : AppColors.error,
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
