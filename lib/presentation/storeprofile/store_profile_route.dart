import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/add_store_product/add_store_product_bloc.dart';
import 'package:project_c/bloc/store_gallery/store_gallery_bloc.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_gallery_picker.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/product_view_mode.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/privacy/privacy_widgets/follow_requests_banner.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/pending_uploads_sliver.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_images_manager_sheet.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_private_content_gate.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_product_gallery_sliver.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_product_grid.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_profile_collapsing_header.dart';
import 'package:project_c/services/product_view_preferences.dart';

class StoreProfileRoute extends StatefulWidget {
  const StoreProfileRoute({
    super.key,
    this.focusProductId,
  });

  /// When set (e.g. from search product-details store chevron), scroll to and
  /// highlight this listing’s group card with a primary border.
  final String? focusProductId;

  @override
  State<StoreProfileRoute> createState() => _StoreProfileRouteState();
}

class _StoreProfileRouteState extends State<StoreProfileRoute> {
  final Set<String> _selectedIds = {};
  bool _selectionMode = false;
  final GlobalKey _focusProductKey = GlobalKey();
  bool _didScrollToFocus = false;

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

  Future<void> _addProducts(BuildContext context) async {
    // Telegram-style: one gallery sheet; first cell is Camera (full capture).
    final selectedItems = <GalleryImageItem>[];

    try {
      final rawPaths = await ProductGalleryPicker.pickImagePaths(
        context,
        includeCamera: true,
      );
      if (!context.mounted || rawPaths.isEmpty) return;

      for (var i = 0; i < rawPaths.length; i++) {
        final path = rawPaths[i];
        selectedItems.add(
          GalleryImageItem(
            id: 'pick_${path.hashCode}_$i',
            filePath: path,
            isPlaceholder: false,
          ),
        );
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
      Routes.addProductGroupRoute,
      arguments: <String, Object?>{
        'selectedItems': selectedItems,
        'storeId': context.read<StoreProfileBloc>().state.storeId,
      },
    );
    if (!context.mounted) return;
    if (published is Map) {
      final payload = Map<String, Object?>.from(published);
      // Background upload already started — shimmer is driven by coordinator.
      if (payload['uploading'] == true) return;
      context.read<StoreProfileBloc>().add(
        StoreProfileProductPublished(StoreProduct.fromMap(payload)),
      );
      return;
    }
    // Done may popUntil store profile (result is null). Background upload
    // shimmers via coordinator; avoid a full-grid reload shimmer.
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

    // Ungroup → new collection (and similar structural moves): reload the grid
    // so the new listing appears and the source card counts/cover stay in sync.
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

  Future<void> _openStoreChannel(
    BuildContext context,
    StoreProfileState state,
  ) async {
    final imageUrls = <String>[
      for (final photo in state.storeImages)
        if (photo.url.trim().isNotEmpty) photo.url.trim(),
    ];
    if (imageUrls.isEmpty) {
      final cover = state.coverImageUrl.trim();
      if (cover.isNotEmpty) imageUrls.add(cover);
    }
    final products = state.productsForMedia;
    // Disk-warm catalog during the push (decode stays viewport-scoped on channel).
    // ignore: unawaited_futures
    CatalogImageCache.precacheUrls([
      ...imageUrls,
      for (final product in products)
        ...ProductImagePaths.displayable(product.imagePaths),
    ]);
    await Navigator.of(context).pushNamed(
      Routes.storeChannelRoute,
      arguments: <String, Object?>{
        'storeId': state.storeId,
        'storeName': state.storeName,
        'storeLink': state.storeLink,
        'imageUrls': imageUrls,
        'products': products,
        'followerCount': state.followerCount,
        'followingCount': state.followingCount,
        'productCount': state.productCount,
        'isOwnStore': state.isOwnStore,
        // Keep follow actions live on the channel screen.
        'profileBloc': context.read<StoreProfileBloc>(),
      },
    );
  }

  void _openStoreSearch(BuildContext context, StoreProfileState state) {
    Navigator.of(context).pushNamed(
      Routes.storeSearchRoute,
      arguments: <String, Object?>{
        'storeId': state.storeId,
        'storeName': state.storeName,
        'productCount': state.productCount,
      },
    );
  }

  Future<void> _openAddMembers(
    BuildContext context,
    StoreProfileState state,
  ) async {
    await Navigator.of(context).pushNamed(
      Routes.addTeamRoute,
      arguments: <String, Object?>{
        'storeName': state.storeName,
        'returnToProfile': true,
      },
    );
    if (!context.mounted) return;
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
    if (!state.canImport) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create your store before importing products.'),
        ),
      );
      return;
    }
    if (state.isOwnStore) {
      Navigator.of(context).pushNamed(Routes.storeListingRoute);
      return;
    }
    Navigator.of(context)
        .pushNamed(
          Routes.storeImportSelectRoute,
          arguments: <String, Object?>{
            'storeId': state.storeId,
            'storeName': state.storeName,
            'storeLink': state.storeLink,
            'products': state.productsForMedia,
            'avatarColor': state.avatarColor,
          },
        )
        .then((_) {
          if (!context.mounted) return;
          context.read<StoreProfileBloc>().add(
            const StoreProfileProbeImportAvailability(),
          );
        });
  }

  void _onProductInteraction(
    BuildContext context,
    StoreProfileState state,
    StoreProduct product,
    ProductViewMode viewMode, {
    int imageIndex = 0,
  }) {
    if (_selectionMode) {
      _toggleSelected(product);
      return;
    }
    // Group view: gallery-style collection browse (Select / Edit / Ungroup).
    // Single / Gallery: open the tapped collage/gallery photo in product details.
    if (viewMode == ProductViewMode.group) {
      _openCollectionBrowse(context, state, product);
      return;
    }
    _openProductDetails(context, state, product, imageIndex: imageIndex);
  }

  void _scheduleScrollToFocus(StoreProfileState state) {
    final focusId = widget.focusProductId?.trim() ?? '';
    if (focusId.isEmpty || _didScrollToFocus) return;
    if (!state.products.any((p) => p.id == focusId)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didScrollToFocus) return;
      final ctx = _focusProductKey.currentContext;
      if (ctx == null) return;
      _didScrollToFocus = true;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        alignment: 0.18,
      );
    });
  }

  Widget _productsSliver({
    required StoreProfileState state,
    required ProductViewMode viewMode,
    bool attachFocusKey = true,
  }) {
    if (state.isContentLocked) {
      if (state.isLoadingStoreMeta) {
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          ),
        );
      }
      return SliverToBoxAdapter(
        child: StorePrivateContentGate(
          storeName: state.storeName,
          followStatus: state.followStatus,
        ),
      );
    }

    final canSelect = state.isOwnStore;
    final deletingId = state.deletingProductId;
    final deletingIds =
        deletingId == null || deletingId.isEmpty
            ? <String>{}
            : <String>{deletingId};
    final focusId = widget.focusProductId?.trim() ?? '';
    final focusProductId = focusId.isEmpty ? null : focusId;
    final focusKey =
        attachFocusKey && focusProductId != null ? _focusProductKey : null;
    final pending = state.pendingUploads;

    if (attachFocusKey) {
      _scheduleScrollToFocus(state);
    }

    final productsSliver =
        viewMode == ProductViewMode.gallery
            ? StoreProductGallerySliver(
              products: state.productsForMedia,
              isLoading: state.isLoadingProducts && pending.isEmpty,
              selectionMode: _selectionMode,
              selectedIds: _selectedIds,
              focusProductId: focusProductId,
              focusKey: focusKey,
              onImageTap:
                  (product, imageIndex) => _onProductInteraction(
                    context,
                    state,
                    product,
                    viewMode,
                    imageIndex: imageIndex,
                  ),
              onProductLongPress:
                  canSelect ? (product) => _enterSelection(product) : null,
            )
            : StoreProductGrid(
              products: state.products,
              viewMode: viewMode,
              selectionMode: _selectionMode,
              selectedIds: _selectedIds,
              deletingProductIds: deletingIds,
              listingAvailability: state.listingAvailability,
              focusProductId: focusProductId,
              focusKey: focusKey,
              onProductTap:
                  (product, imageIndex) => _onProductInteraction(
                    context,
                    state,
                    product,
                    viewMode,
                    imageIndex: imageIndex,
                  ),
              onProductLongPress:
                  canSelect ? (product) => _enterSelection(product) : null,
            ).buildSliver(
              isLoading: state.isLoadingProducts && pending.isEmpty,
            );

    if (pending.isEmpty) return productsSliver;

    return SliverMainAxisGroup(
      slivers: [
        PendingUploadsSliver(pending: pending, viewMode: viewMode),
        if (viewMode != ProductViewMode.gallery)
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
        productsSliver,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewPrefs = ServiceLocator.get<ProductViewPreferences>();
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
        child: BlocBuilder<StoreProfileBloc, StoreProfileState>(
          builder: (context, state) {
            return ListenableBuilder(
              listenable: viewPrefs,
              builder: (context, _) {
                final viewMode = viewPrefs.mode;
                final bottomInset =
                    16 + MediaQuery.paddingOf(context).bottom;
                return Padding(
                  padding: AppPadding.screen(
                    top: ScreenWrapper.statusBarTop(context),
                    bottom: 0,
                  ),
                  child: Column(
                    children: [
                      if (_selectionMode)
                        _SelectionBar(
                          count: _selectedIds.length,
                          onCancel: _exitSelection,
                          onDelete:
                              _selectedIds.isEmpty
                                  ? null
                                  : () => _confirmDeleteSelected(context),
                        ),
                      Expanded(
                        // Discover listing for owner and visitor (no owner
                        // bottom nav — Wishlist / My store / Activity live on
                        // the main shell / home header).
                        child: _buildDiscoverBody(
                          context: context,
                          state: state,
                          viewMode: viewMode,
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
      ),
    );
  }

  /// Listing-first store profile (Discover + visitors). Compact header tap
  /// opens the Telegram-style [Routes.storeChannelRoute] (no in-place expand).
  Widget _buildDiscoverBody({
    required BuildContext context,
    required StoreProfileState state,
    required ProductViewMode viewMode,
    required double bottomInset,
    bool attachFocusKey = true,
  }) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: StoreProfileCollapsingHeaderDelegate(
            state: state,
            expandT: 0,
            onOpenStoreInfo: () => _openStoreChannel(context, state),
            onBack: () => _goHome(context),
            onAddProducts: () => _addProducts(context),
            onImport: () => _openImport(context, state),
            onSearch: () => _openStoreSearch(context, state),
            onAddMembers:
                state.showAddMembersCta
                    ? () => _openAddMembers(context, state)
                    : null,
            onCopyStoreLink: () => _copyStoreLink(context, state),
            onManageImages:
                state.isOwnStore
                    ? () => showStoreImagesManagerSheet(context)
                    : null,
            onFollowersTap:
                state.isOwnStore
                    ? () => _openFollowersFollowing(
                      context,
                      state,
                      initialTab: 'followers',
                    )
                    : null,
            onFollowingTap:
                state.isOwnStore
                    ? () => _openFollowersFollowing(
                      context,
                      state,
                      initialTab: 'following',
                    )
                    : null,
          ),
        ),
        if (state.showFollowRequestsBanner)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FollowRequestsBanner(
                pendingCount: state.pendingFollowRequestCount,
                previewNames: state.followRequestPreviewNames,
                onTap: () => _openFollowRequests(context, state),
              ),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.only(bottom: bottomInset),
          sliver: _productsSliver(
            state: state,
            viewMode: viewMode,
            attachFocusKey: attachFocusKey,
          ),
        ),
      ],
    );
  }

  /// Back from owner tabs / visitor header → store listing home.
  void _goHome(BuildContext context) {
    if (_selectionMode) {
      _exitSelection();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop();
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.storeListingRoute,
      (route) => false,
    );
  }

  Future<void> _openFollowersFollowing(
    BuildContext context,
    StoreProfileState state, {
    required String initialTab,
  }) async {
    if (!state.isOwnStore) return;
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
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
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
      padding: const EdgeInsets.only(bottom: 8),
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
                  count == 0
                      ? 'Select products'
                      : '$count selected',
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
