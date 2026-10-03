import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project_c/bloc/add_store_product/add_store_product_bloc.dart';
import 'package:project_c/bloc/store_gallery/store_gallery_bloc.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/media_source_sheet.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/product_view_mode.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/pending_uploads_sliver.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_images_manager_sheet.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_product_gallery_sliver.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_product_grid.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_profile_collapsing_header.dart';
import 'package:project_c/services/product_view_preferences.dart';

class StoreProfileRoute extends StatefulWidget {
  const StoreProfileRoute({super.key, this.focusProductId});

  /// When set (e.g. from search product-details store chevron), scroll to and
  /// highlight this listing’s group card with a primary border.
  final String? focusProductId;

  @override
  State<StoreProfileRoute> createState() => _StoreProfileRouteState();
}

class _StoreProfileRouteState extends State<StoreProfileRoute>
    with SingleTickerProviderStateMixin {
  late final AnimationController _headerExpand;
  late final Animation<double> _headerExpandT;
  final Set<String> _selectedIds = {};
  bool _selectionMode = false;
  final GlobalKey _focusProductKey = GlobalKey();
  bool _didScrollToFocus = false;

  @override
  void initState() {
    super.initState();
    // Start collapsed (listing-first); tap header to reveal store details.
    _headerExpand = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: 0,
    );
    _headerExpandT = CurvedAnimation(
      parent: _headerExpand,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _headerExpand.dispose();
    super.dispose();
  }

  bool get _isHeaderExpanded => _headerExpand.value > 0.001;

  void _collapseHeaderDetails() {
    if (!_isHeaderExpanded) return;
    if (_headerExpand.status == AnimationStatus.reverse) return;
    _headerExpand.reverse();
  }

  void _toggleHeaderDetails() {
    if (_headerExpand.status == AnimationStatus.completed ||
        _headerExpand.status == AnimationStatus.forward) {
      _headerExpand.reverse();
    } else {
      _headerExpand.forward();
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification) return false;
    // Ignore bounce / ballistic motion after finger lift — only collapse while
    // the user is actively dragging upward (content moves up, positive delta).
    if (notification.dragDetails == null) return false;
    final delta = notification.scrollDelta ?? 0;
    if (delta > 1.5 && _isHeaderExpanded) {
      _collapseHeaderDetails();
    }
    return false;
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

  Future<void> _addProducts(BuildContext context) async {
    final source = await showMediaSourceSheet(context);

    if (!context.mounted || source == null) return;

    final picker = ImagePicker();
    final selectedItems = <GalleryImageItem>[];

    try {
      final rawPaths = <String>[];
      if (source == MediaPickSource.camera) {
        final photo = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1920,
          maxHeight: 1920,
        );
        if (photo != null) rawPaths.add(photo.path);
      } else {
        final photos = await picker.pickMultiImage(
          imageQuality: 85,
          maxWidth: 1920,
          maxHeight: 1920,
        );
        for (final photo in photos.take(50)) {
          rawPaths.add(photo.path);
        }
      }

      if (rawPaths.isEmpty) return;

      for (var i = 0; i < rawPaths.length; i++) {
        final path = rawPaths[i];
        selectedItems.add(
          GalleryImageItem(
            id:
                source == MediaPickSource.camera
                    ? 'camera_${path.hashCode}'
                    : 'gallery_${path.hashCode}_$i',
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

  Future<void> _openGallery(
    BuildContext context,
    StoreProfileState state,
  ) async {
    final result = await Navigator.of(context).pushNamed(
      Routes.storeGalleryRoute,
      arguments: <String, Object?>{
        'products': state.productsForMedia,
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

  void _onBack(BuildContext context) {
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
  }) {
    final canSelect = state.isOwnStore;
    final deletingId = state.deletingProductId;
    final deletingIds =
        deletingId == null || deletingId.isEmpty
            ? <String>{}
            : <String>{deletingId};
    final focusId = widget.focusProductId?.trim() ?? '';
    final focusProductId = focusId.isEmpty ? null : focusId;
    final pending = state.pendingUploads;

    _scheduleScrollToFocus(state);

    final productsSliver =
        viewMode == ProductViewMode.gallery
            ? StoreProductGallerySliver(
              products: state.productsForMedia,
              isLoading: state.isLoadingProducts && pending.isEmpty,
              selectionMode: _selectionMode,
              selectedIds: _selectedIds,
              focusProductId: focusProductId,
              focusKey: focusProductId == null ? null : _focusProductKey,
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
              focusKey: focusProductId == null ? null : _focusProductKey,
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
        statusBarIconBrightness: Brightness.dark,
        child: BlocBuilder<StoreProfileBloc, StoreProfileState>(
          builder: (context, state) {
            return ListenableBuilder(
              listenable: viewPrefs,
              builder: (context, _) {
                final viewMode = viewPrefs.mode;
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
                        child: NotificationListener<ScrollNotification>(
                          onNotification: _onScrollNotification,
                          child: AnimatedBuilder(
                            animation: _headerExpandT,
                            builder: (context, _) {
                              return CustomScrollView(
                                physics: const BouncingScrollPhysics(),
                                slivers: [
                                  SliverPersistentHeader(
                                    pinned: true,
                                    delegate:
                                        StoreProfileCollapsingHeaderDelegate(
                                      state: state,
                                      expandT: _headerExpandT.value,
                                      onToggleDetails: _toggleHeaderDetails,
                                      onBack: () => _onBack(context),
                                      onAddProducts:
                                          () => _addProducts(context),
                                      onImport:
                                          () => _openImport(context, state),
                                      onSearch:
                                          () =>
                                              _openStoreSearch(context, state),
                                      onAddMembers:
                                          state.showAddMembersCta
                                              ? () => _openAddMembers(
                                                context,
                                                state,
                                              )
                                              : null,
                                      onCopyStoreLink:
                                          () =>
                                              _copyStoreLink(context, state),
                                      onManageImages:
                                          state.isOwnStore
                                              ? () =>
                                                  showStoreImagesManagerSheet(
                                                    context,
                                                  )
                                              : null,
                                      onViewAll:
                                          state.products.isNotEmpty
                                              ? () => _openGallery(
                                                context,
                                                state,
                                              )
                                              : null,
                                    ),
                                  ),
                                  SliverPadding(
                                    padding: EdgeInsets.only(
                                      bottom:
                                          16 +
                                          MediaQuery.paddingOf(context).bottom,
                                    ),
                                    sliver: _productsSliver(
                                      state: state,
                                      viewMode: viewMode,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
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
