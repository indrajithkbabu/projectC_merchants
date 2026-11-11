import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/store_gallery/store_gallery_bloc.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/catalog_ui_mapper.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/floating_bottom_nav_bar.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/product_view_mode.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/main_shell/profile_sheets.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_my_store_tab.dart';
import 'package:project_c/services/product_view_preferences.dart';

/// Shell "My store" / active-store Profile tab — Instagram-style UI.
/// Menu opens from the toolbar hamburger (role-based sheet preferred).
class MyStoreTab extends StatefulWidget {
  const MyStoreTab({
    super.key,
    this.onOpenMenu,
    this.onOpenSwitcher,
    this.showSwitcherDot = false,
    this.roleBadge,
    this.canManageStore = true,
  });

  final VoidCallback? onOpenMenu;
  final VoidCallback? onOpenSwitcher;
  final bool showSwitcherDot;
  final String? roleBadge;
  final bool canManageStore;

  @override
  State<MyStoreTab> createState() => MyStoreTabState();
}

class MyStoreTabState extends State<MyStoreTab> {
  /// Photo keys `"listingId|imageIndex"` for per-item multi-delete.
  final Set<String> _selectedPhotoKeys = {};
  bool _selectionMode = false;

  /// Consumes shell system-back while multi-select is active.
  bool consumeSystemBack() {
    if (!_selectionMode) return false;
    _exitSelection();
    return true;
  }

  void _exitSelection() {
    if (!_selectionMode && _selectedPhotoKeys.isEmpty) return;
    setState(() {
      _selectionMode = false;
      _selectedPhotoKeys.clear();
    });
  }

  void _enterSelection(StoreProduct product, int imageIndex) {
    setState(() {
      _selectionMode = true;
      _selectedPhotoKeys
        ..clear()
        ..add(StoreMyStoreTab.photoKey(product.id, imageIndex));
    });
  }

  void _toggleSelected(StoreProduct product, int imageIndex) {
    final key = StoreMyStoreTab.photoKey(product.id, imageIndex);
    setState(() {
      if (_selectedPhotoKeys.contains(key)) {
        _selectedPhotoKeys.remove(key);
        if (_selectedPhotoKeys.isEmpty) _selectionMode = false;
      } else {
        _selectedPhotoKeys.add(key);
      }
    });
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final count = _selectedPhotoKeys.length;
    if (count == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            count == 1 ? 'Delete item?' : 'Delete $count items?',
            style: AppTextStyles.headline(fontSize: 18),
          ),
          content: Text(
            count == 1
                ? 'This removes the selected item from your store. The rest of the product stays.'
                : 'This removes the selected items from your store. Remaining items in each product stay.',
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
    final keys = _selectedPhotoKeys.toList();
    _exitSelection();
    context.read<StoreProfileBloc>().add(StoreProfileItemsDeleted(keys));
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
      _applyProductUpdatedPayload(context, payload);
    }
  }

  /// Same merge rules as store profile: silent = bump existing listing only.
  void _applyProductUpdatedPayload(
    BuildContext context,
    Map<String, Object?> payload,
  ) {
    final incoming = StoreProduct.fromMap(payload);
    final silent = payload['silent'] == true;
    var product = incoming;
    if (silent) {
      final products = context.read<StoreProfileBloc>().state.products;
      StoreProduct? matched;
      for (final p in products) {
        if (p.id == incoming.id) {
          matched = p.copyWith(
            likeCount: incoming.likeCount,
            viewCount: incoming.viewCount ?? p.viewCount,
            wishlistCount: incoming.wishlistCount,
            clearWishlistCount:
                incoming.wishlistCount == null &&
                payload.containsKey('wishlistCount'),
          );
          break;
        }
      }
      if (matched == null) return;
      product = matched;
    }
    context.read<StoreProfileBloc>().add(
      StoreProfileProductUpdated(
        product,
        replacedListingId: payload['replacedListingId'] as String?,
        silent: silent,
      ),
    );
  }

  Future<void> _openProductDetails(
    BuildContext context,
    StoreProfileState state,
    StoreProduct product, {
    int imageIndex = 0,
  }) async {
    StoreProduct listing = product;
    for (final p in state.productsForMedia) {
      if (p.id == product.id) {
        listing = p;
        break;
      }
    }
    final resolved = CatalogUiMapper.resolveCollageTap(listing, imageIndex);
    final media = resolved.product;
    final openIndex = resolved.imageIndex;

    final galleryState = StoreGalleryState(
      products: state.productsForMedia,
      storeName: state.storeName,
      storeLink: state.storeLink,
      storeId: state.storeId,
      isOwnStore: state.isOwnStore,
      sections: StoreGalleryState.buildSections(state.productsForMedia),
    );
    final safeIndex =
        openIndex < 0
            ? 0
            : (openIndex >= media.imagePaths.length ? 0 : openIndex);
    final masterAt =
        media.imagePaths.isEmpty ? '' : media.imagePaths[safeIndex].trim();
    final tapPath =
        masterAt.isNotEmpty
            ? masterAt
            : (listing.imagePaths.isEmpty ||
                    imageIndex < 0 ||
                    imageIndex >= listing.imagePaths.length
                ? ''
                : listing.imagePaths[imageIndex].trim());
    final openFeed = galleryState.resolveOpenFeed(
      productId: media.id,
      imageIndex: openIndex,
      path: tapPath,
    );

    final result = await Navigator.of(context).pushNamed(
      Routes.productDetailsRoute,
      arguments: <String, Object?>{
        'product': media,
        'storeName': state.storeName,
        'storeLink': state.storeLink,
        'storeId': state.storeId,
        'isOwnStore': state.isOwnStore,
        'imageIndex': openIndex,
        if (openFeed.useFeed) ...{
          'galleryFeed': openFeed.feed,
          'galleryFeedIndex': openFeed.index,
        },
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
      _applyProductUpdatedPayload(context, payload);
    }
  }

  void _onProductTap(
    BuildContext context,
    StoreProfileState state,
    StoreProduct product,
    ProductViewMode viewMode, {
    int imageIndex = 0,
  }) {
    if (_selectionMode) {
      _toggleSelected(product, imageIndex);
      return;
    }
    if (viewMode == ProductViewMode.group) {
      _openCollectionBrowse(context, state, product);
      return;
    }
    _openProductDetails(context, state, product, imageIndex: imageIndex);
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
    // Prefer shared helper so ProfileContextBloc is passed for role actions.
    // ignore: discarded_futures
    openProfileSettings(context);
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
                        count: _selectedPhotoKeys.length,
                        onCancel: _exitSelection,
                        onDelete:
                            _selectedPhotoKeys.isEmpty
                                ? null
                                : () => _confirmDeleteSelected(context),
                      ),
                    Expanded(
                      child: StoreMyStoreTab(
                        state: state,
                        showBack: false,
                        onBack: () {},
                        onOpenSettings:
                            widget.onOpenMenu ?? () => _openSettings(context),
                        onOpenSwitcher: widget.onOpenSwitcher,
                        onOpenStaff: () {
                          final storeId = state.storeId.trim();
                          if (storeId.isEmpty) return;
                          Navigator.of(context).pushNamed(
                            Routes.staffListRoute,
                            arguments: <String, Object?>{
                              'storeId': storeId,
                              'storeName': state.storeName,
                            },
                          );
                        },
                        showSwitcherDot: widget.showSwitcherDot,
                        roleBadge: widget.roleBadge,
                        canManageStore: widget.canManageStore,
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
                            (product, imageIndex) => _onProductTap(
                              context,
                              state,
                              product,
                              viewMode,
                              imageIndex: imageIndex,
                            ),
                        onProductLongPress:
                            widget.canManageStore ? _enterSelection : null,
                        selectedPhotoKeys: _selectedPhotoKeys,
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
                  count == 0 ? 'Select items' : '$count selected',
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
