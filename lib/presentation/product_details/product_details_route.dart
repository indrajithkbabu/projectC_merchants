import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/bulk_upload/bulk_upload_bloc.dart';
import 'package:project_c/bloc/product_details/product_details_bloc.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/main_shell/shell_nav.dart';
import 'package:project_c/presentation/product_details/product_details_widgets/product_details_widgets.dart';
import 'package:project_c/services/product_details_preferences.dart';
import 'package:project_c/services/store_products_prefetcher.dart';
import 'package:project_c/services/view_beacon.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';

class ProductDetailsRoute extends StatefulWidget {
  const ProductDetailsRoute({super.key});

  @override
  State<ProductDetailsRoute> createState() => _ProductDetailsRouteState();
}

class _ProductDetailsRouteState extends State<ProductDetailsRoute> {
  late PageController _pageController;
  late final ScrollController _thumbController;

  /// PageView index: gallery-feed index when [ProductDetailsState.hasGalleryFeed],
  /// otherwise image index within the active product.
  int _pageIndex = 0;
  bool _showInfo = false;
  late bool _previewAll;
  late bool _previewDetails;
  bool _imageZoomed = false;
  Map<String, Object?>? _popResult;
  Timer? _viewDwellTimer;

  @override
  void initState() {
    super.initState();
    final blocState = context.read<ProductDetailsBloc>().state;
    final initialPage =
        blocState.hasGalleryFeed
            ? blocState.galleryFeedIndex
            : blocState.initialImageIndex;
    _pageIndex = initialPage;
    _pageController = PageController(initialPage: initialPage);
    _thumbController = ScrollController();

    final prefs = ServiceLocator.get<ProductDetailsPreferences>();
    _previewAll = prefs.previewAll;
    _previewDetails = prefs.previewDetails;
    if (!prefs.isLoaded) {
      prefs.load().then((_) {
        if (!mounted) return;
        final allChanged = prefs.previewAll != _previewAll;
        final detailsChanged = prefs.previewDetails != _previewDetails;
        if (!allChanged && !detailsChanged) return;
        setState(() {
          _previewAll = prefs.previewAll;
          _previewDetails = prefs.previewDetails;
        });
        if (_previewAll) _scheduleThumbScroll();
      });
    } else if (_previewAll) {
      _scheduleThumbScroll();
    }
    _warmMedia(blocState);
    _restartViewDwell(blocState);
  }

  void _warmMedia(ProductDetailsState state) {
    final urls = <String>[
      ...ProductImagePaths.displayable(state.product.imagePaths),
      if (state.hasGalleryFeed)
        for (final item in state.galleryFeed!) item.path,
    ];
    // Disk for feed; decode only current page ± lookahead (scales to long feeds).
    // ignore: unawaited_futures
    CatalogImageCache.precacheUrls(urls);
    // ignore: unawaited_futures
    CatalogImageCache.warmWindow(
      urls: urls,
      firstIndex: _pageIndex - 2,
      lastIndex: _pageIndex + 3,
      cacheWidth: CatalogImageCache.fullCacheWidth(),
    );
  }

  void _scheduleThumbScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_previewAll) return;
      _scrollThumbTo(_pageIndex);
    });
  }

  @override
  void dispose() {
    _viewDwellTimer?.cancel();
    // ignore: unawaited_futures
    ViewBeacon.instance.flush();
    _pageController.dispose();
    _thumbController.dispose();
    super.dispose();
  }

  void _restartViewDwell(ProductDetailsState state) {
    _viewDwellTimer?.cancel();
    _viewDwellTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      final current = context.read<ProductDetailsBloc>().state;
      final photoIndex = _productImageIndex(current);
      final photoId = current.photoIdAt(photoIndex);
      if (photoId.isNotEmpty) {
        ViewBeacon.instance.enqueuePhoto(photoId);
      }
      final listingId = current.product.id.trim();
      if (listingId.isNotEmpty) {
        ViewBeacon.instance.enqueueCollection(listingId);
      }
      final subId = current.subGroupIdForPhoto(photoIndex);
      if (subId != null && subId.isNotEmpty) {
        ViewBeacon.instance.enqueueSubgroup(subId);
      }
    });
  }

  /// Swap pager so the next paint lands on [targetPage] (fallback when a
  /// single-item search feed expands after detail load).
  void _reseatPager(int targetPage) {
    if (_pageIndex == targetPage && _pageController.hasClients) {
      final page = _pageController.page;
      if (page != null && page.round() == targetPage) return;
    }
    final old = _pageController;
    _pageController = PageController(initialPage: targetPage);
    _pageIndex = targetPage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      old.dispose();
      if (mounted && _previewAll) _scrollThumbTo(targetPage);
    });
  }

  void _scrollThumbTo(int index) {
    if (!_thumbController.hasClients) return;
    const itemExtent = 72.0;
    final targetOffset = (index * itemExtent) - 120;
    final clamped = targetOffset.clamp(
      _thumbController.position.minScrollExtent,
      _thumbController.position.maxScrollExtent,
    );
    _thumbController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _goToPage(int index) {
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _openStoreGroup(ProductDetailsState state) {
    final storeId = state.storeId?.trim() ?? '';
    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      return;
    }
    final productId = state.product.id.trim();
    if (productId.isEmpty) return;

    // Warm products during the route transition (same as store listing tap).
    StoreProductsPrefetcher.instance.prefetch(storeId);

    Navigator.of(context).pushNamed(
      Routes.storeProfileRoute,
      arguments: <String, Object?>{
        'storeId': storeId,
        'storeName': state.storeName,
        'storeLink': state.storeLink,
        'isOwnStore': state.isOwnStore,
        'focusProductId': productId,
      },
    );
  }

  int _productImageIndex(ProductDetailsState state) {
    if (state.hasGalleryFeed) {
      final feed = state.galleryFeed!;
      if (_pageIndex < 0 || _pageIndex >= feed.length) return 0;
      return feed[_pageIndex].imageIndex;
    }
    return _pageIndex;
  }

  String? _currentImagePath(ProductDetailsState state) {
    if (state.hasGalleryFeed) {
      final feed = state.galleryFeed!;
      if (_pageIndex < 0 || _pageIndex >= feed.length) return null;
      final path = feed[_pageIndex].path.trim();
      return path.isEmpty ? null : path;
    }
    final paths = state.product.imagePaths;
    if (paths.isEmpty || _pageIndex < 0 || _pageIndex >= paths.length) {
      return null;
    }
    final path = paths[_pageIndex].trim();
    return path.isEmpty ? null : path;
  }

  void _onPageChanged(int index, ProductDetailsState state) {
    setState(() {
      _pageIndex = index;
      // Re-enable swipe after leaving a zoomed page (page itself resets on dispose).
      _imageZoomed = false;
    });
    _warmMedia(state);
    if (_previewAll) _scrollThumbTo(index);
    if (state.hasGalleryFeed) {
      final entry = state.galleryFeed![index];
      final activeId = context.read<ProductDetailsBloc>().state.product.id;
      if (entry.product.id != activeId) {
        context.read<ProductDetailsBloc>().add(
          ProductDetailsActivateProduct(
            entry.product,
            storeId: entry.storeId,
            storeName: entry.storeName,
            storeLink: entry.storeLink,
            seedCategory: entry.seedCategory,
          ),
        );
      }
    }
    final latest = context.read<ProductDetailsBloc>().state;
    _restartViewDwell(latest);
  }

  List<String> _editTags(ProductDetailsState state) {
    final raw = state.apiTag.trim();
    if (raw.isEmpty) return [];
    return raw
        .split(',')
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  Future<void> _openEdit(ProductDetailsState state) async {
    context.read<ProductDetailsBloc>().add(const ProductDetailsClearOpenEdit());
    final storeId = state.storeId;
    if (storeId == null || storeId.isEmpty) return;

    final choice = await showModalBottomSheet<_EditChoice>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(
                    'Edit title, tags & photos',
                    style: AppTextStyles.body(),
                  ),
                  onTap:
                      () => Navigator.of(
                        sheetContext,
                      ).pop(_EditChoice.metadataPhotos),
                ),
                ListTile(
                  leading: const Icon(Icons.tune_rounded),
                  title: Text(
                    'Refine items & details',
                    style: AppTextStyles.body(),
                  ),
                  onTap:
                      () =>
                          Navigator.of(sheetContext).pop(_EditChoice.refine),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || choice == null) return;

    switch (choice) {
      case _EditChoice.metadataPhotos:
        await _openMetadataEdit(state);
      case _EditChoice.refine:
        await _openRefineEdit(state);
    }
  }

  Future<void> _openMetadataEdit(ProductDetailsState state) async {
    final storeId = state.storeId;
    if (storeId == null || storeId.isEmpty) return;

    final result = await Navigator.of(context).pushNamed(
      Routes.addProductFormRoute,
      arguments: <String, Object?>{
        'mode': 'edit',
        'storeId': storeId,
        'listingId': state.product.id,
        'revision': state.revision,
        'title': state.product.title,
        'description': state.product.description,
        'tags': _editTags(state),
        'imagePaths': state.product.imagePaths,
        'photoAssetIds': state.product.photoAssetIds,
      },
    );
    if (!mounted) return;
    if (result is! Map) return;

    final payload = Map<String, Object?>.from(result);
    final revision = payload['revision'];
    final apiTag = (payload['apiTag'] as String?) ?? '';
    final product = StoreProduct.fromMap(payload);
    _popResult = <String, Object?>{
      'updated': true,
      ...product.toMap(),
      if (payload['replacedListingId'] is String)
        'replacedListingId': payload['replacedListingId'],
    };
    context.read<ProductDetailsBloc>().add(
      ProductDetailsApplyEditedProduct(
        product: product,
        revision: revision is int ? revision : state.revision,
        apiTag: apiTag,
      ),
    );
  }

  Future<void> _openRefineEdit(ProductDetailsState state) async {
    final storeId = state.storeId;
    if (storeId == null || storeId.isEmpty) return;

    BulkUploadBloc? bloc;
    try {
      final detail = await ServiceLocator.get<CollectionRepository>()
          .fetchCollection(storeId: storeId, listingId: state.product.id);
      if (!mounted) return;
      bloc = BulkUploadBloc.fromCollectionDetail(
        detail: detail,
        storeId: storeId,
      );
      final result = await Navigator.of(context).pushNamed(
        Routes.addProductGroupPreviewRoute,
        arguments: <String, Object?>{'bloc': bloc},
      );
      if (!mounted) return;
      if (result is! Map) return;

      final payload = Map<String, Object?>.from(result);
      final revision = payload['revision'];
      final apiTag = (payload['apiTag'] as String?) ?? '';
      final product = StoreProduct.fromMap(payload);
      _popResult = <String, Object?>{
        'updated': true,
        ...product.toMap(),
      };
      context.read<ProductDetailsBloc>().add(
        ProductDetailsApplyEditedProduct(
          product: product,
          revision: revision is int ? revision : state.revision,
          apiTag: apiTag,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(e))),
      );
    } finally {
      await bloc?.close();
    }
  }

  void _popDetails() {
    Navigator.of(context).pop(_popResult);
  }

  void _openOwnWishlist(BuildContext context) {
    final session = ServiceLocator.get<CatalogSession>();
    final storeId = session.ownStoreId?.trim() ?? '';
    if (storeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a store to open Wishlist from My store.'),
        ),
      );
      return;
    }
    // Land on shell Wishlist tab (owner bottom-nav removed from store profile).
    Navigator.of(context).popUntil(
      (route) =>
          route.settings.name == Routes.storeListingRoute || route.isFirst,
    );
    ShellNav.request(ShellNavTab.wishlist);
  }

  Future<void> _confirmDeletePhoto(ProductDetailsState state) async {
    final isLastPhoto = state.product.imagePaths.length <= 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            isLastPhoto ? 'Delete this product?' : 'Remove this photo?',
            style: AppTextStyles.headline(fontSize: 18),
          ),
          content: Text(
            isLastPhoto
                ? 'This product has only one photo. Deleting it removes the whole product from your store.'
                : 'Only this photo will be removed. The product and its other photos stay in your store.',
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
    if (!mounted || confirmed != true) return;
    context.read<ProductDetailsBloc>().add(
      ProductDetailsDeletePressed(
        imageIndex: _productImageIndex(state),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<ProductDetailsBloc, ProductDetailsState>(
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
            context.read<ProductDetailsBloc>().add(
              const ProductDetailsClearMessage(),
            );
          },
        ),
        BlocListener<ProductDetailsBloc, ProductDetailsState>(
          listenWhen:
              (prev, curr) =>
                  curr.showWishlistSnack && !prev.showWishlistSnack,
          listener: (context, state) {
            context.read<ProductDetailsBloc>().add(
              const ProductDetailsClearWishlistSnack(),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Saved to Wishlist'),
                action: SnackBarAction(
                  label: 'View',
                  onPressed: () => _openOwnWishlist(context),
                ),
              ),
            );
          },
        ),
        BlocListener<ProductDetailsBloc, ProductDetailsState>(
          listenWhen: (prev, curr) => curr.shouldOpenEdit && !prev.shouldOpenEdit,
          listener: (context, state) => _openEdit(state),
        ),
        BlocListener<ProductDetailsBloc, ProductDetailsState>(
          listenWhen:
              (prev, curr) =>
                  prev.isLoadingPhotos &&
                  !curr.isLoadingPhotos &&
                  curr.hasGalleryFeed &&
                  (prev.galleryFeed?.length != curr.galleryFeed?.length ||
                      prev.galleryFeedIndex != curr.galleryFeedIndex),
          listener: (context, state) {
            // Prefer search prefetch (full feed on push). This path is the
            // fallback when a 1-item seed expands — reseat before paint.
            _reseatPager(state.galleryFeedIndex);
          },
        ),
        BlocListener<ProductDetailsBloc, ProductDetailsState>(
          listenWhen:
              (prev, curr) =>
                  prev.isLoadingPhotos &&
                  !curr.isLoadingPhotos &&
                  !curr.hasGalleryFeed &&
                  (prev.product.imagePaths.length !=
                          curr.product.imagePaths.length ||
                      prev.initialImageIndex != curr.initialImageIndex),
          listener: (context, state) {
            // Wishlist / single-photo seed → full collection: jump to the
            // matched liked photo (keeps heart filled, avoids flash to photo 0).
            _reseatPager(state.initialImageIndex);
            _restartViewDwell(state);
          },
        ),
        BlocListener<ProductDetailsBloc, ProductDetailsState>(
          listenWhen:
              (prev, curr) =>
                  prev.isLoadingPhotos &&
                  !curr.isLoadingPhotos &&
                  curr.product.photoAssetIds.isNotEmpty &&
                  prev.product.id == curr.product.id,
          listener: (context, state) => _restartViewDwell(state),
        ),
        BlocListener<ProductDetailsBloc, ProductDetailsState>(
          listenWhen:
              (prev, curr) =>
                  prev.isDeleting &&
                  !curr.isDeleting &&
                  curr.product.imagePaths.length <
                      prev.product.imagePaths.length,
          listener: (context, state) {
            _popResult = <String, Object?>{
              'updated': true,
              ...state.product.toMap(),
            };
            if (state.hasGalleryFeed) {
              // Leave gallery feed paging as-is; gallery will sync on pop.
              return;
            }
            final last =
                state.product.imagePaths.isEmpty
                    ? 0
                    : state.product.imagePaths.length - 1;
            final nextIndex = _pageIndex > last ? last : _pageIndex;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (_pageController.hasClients) {
                _pageController.jumpToPage(nextIndex);
              }
              if (nextIndex != _pageIndex) {
                setState(() => _pageIndex = nextIndex);
              }
            });
          },
        ),
        BlocListener<ProductDetailsBloc, ProductDetailsState>(
          listenWhen: (prev, curr) => curr.isDeleted && !prev.isDeleted,
          listener: (context, state) {
            context.read<ProductDetailsBloc>().add(
              const ProductDetailsClearDeleted(),
            );
            Navigator.of(context).pop(<String, Object?>{
              'deleted': true,
              'productId': state.product.id,
            });
          },
        ),
      ],
      child: ScreenWrapper(
        backgroundColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _popDetails();
          },
          child: BlocBuilder<ProductDetailsBloc, ProductDetailsState>(
          builder: (context, state) {
            final product = state.product;
            final imagePaths = product.imagePaths;
            final feed = state.galleryFeed;
            final useFeed = state.hasGalleryFeed;
            final pageCount =
                useFeed
                    ? feed!.length
                    : (imagePaths.isEmpty ? 1 : imagePaths.length);
            final photoIndex = _productImageIndex(state);

            return Stack(
              children: [
                Positioned.fill(
                  child: PageView.builder(
                    controller: _pageController,
                    physics:
                        _imageZoomed
                            ? const NeverScrollableScrollPhysics()
                            : const BouncingScrollPhysics(
                              parent: PageScrollPhysics(),
                            ),
                    itemCount: pageCount,
                    onPageChanged: (index) => _onPageChanged(index, state),
                    itemBuilder: (context, index) {
                      final path =
                          useFeed
                              ? feed![index].path
                              : (imagePaths.isEmpty
                                  ? null
                                  : imagePaths[index]);
                      final tone =
                          useFeed
                              ? feed![index].product.toneIndex
                              : product.toneIndex;

                      if (path == null ||
                          path.isEmpty ||
                          !ProductImagePaths.isDisplayable(path)) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _showInfo = !_showInfo),
                          child: _ImagePlaceholder(tone: tone),
                        );
                      }

                      return ProductDetailsZoomablePhoto(
                        // Key so each page keeps its own transform / zoom state.
                        key: ValueKey<String>('pd-zoom-$index-$path'),
                        path: path,
                        isActive: index == _pageIndex,
                        onTap: () => setState(() => _showInfo = !_showInfo),
                        onZoomChanged: (zoomed) {
                          if (!mounted) return;
                          // Only the active page drives PageView physics.
                          if (index != _pageIndex && zoomed) return;
                          if (_imageZoomed == zoomed) return;
                          setState(() => _imageZoomed = zoomed);
                        },
                      );
                    },
                  ),
                ),
                // Tap-to-show chrome: back + title + menu, then store / category.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: !_showInfo,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: _showInfo ? 1 : 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.72),
                              Colors.black.withValues(alpha: 0.28),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: AppPadding.screen(
                            top: ScreenWrapper.statusBarTop(context),
                            bottom: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _RoundIconButton(
                                    icon: Icons.arrow_back_ios_new_rounded,
                                    onTap: _popDetails,
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        left: 10,
                                        right: 8,
                                      ),
                                      child: Text(
                                        state
                                            .titlePartsForPhoto(photoIndex)
                                            .title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.body(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textOnPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (state.isDeleting)
                                    Padding(
                                      padding: EdgeInsets.only(right: 8),
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.textOnPrimary,
                                        ),
                                      ),
                                    ),
                                  _ViewCountChip(
                                    count: state.viewCountForPhoto(photoIndex),
                                  ),
                                  _LikeIconButton(
                                    liked: state.isPhotoLiked(photoIndex),
                                    likeCount: state.likeCountForPhoto(
                                      photoIndex,
                                    ),
                                    busy: state.isLikeBusy,
                                    onTap: () {
                                      context.read<ProductDetailsBloc>().add(
                                        ProductDetailsLikePressed(
                                          imageIndex: photoIndex,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  PopupMenuButton<_OverflowAction>(
                                    tooltip: 'More',
                                    color: AppColors.surface,
                                    elevation: 8,
                                    offset: const Offset(0, 40),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    onSelected: (action) {
                                      final prefs =
                                          ServiceLocator.get<
                                            ProductDetailsPreferences
                                          >();
                                      switch (action) {
                                        case _OverflowAction.edit:
                                          context
                                              .read<ProductDetailsBloc>()
                                              .add(
                                                const ProductDetailsEditPressed(),
                                              );
                                        case _OverflowAction.share:
                                          final path = _currentImagePath(state);
                                          context
                                              .read<ProductDetailsBloc>()
                                              .add(
                                                ProductDetailsSharePressed(
                                                  imagePath: path ?? '',
                                                ),
                                              );
                                        case _OverflowAction.delete:
                                          if (!state.isDeleting) {
                                            _confirmDeletePhoto(state);
                                          }
                                        case _OverflowAction.previewAll:
                                          setState(
                                            () => _previewAll = !_previewAll,
                                          );
                                          prefs.setPreviewAll(_previewAll);
                                          if (_previewAll) {
                                            _scheduleThumbScroll();
                                          }
                                        case _OverflowAction.previewDetails:
                                          setState(
                                            () =>
                                                _previewDetails =
                                                    !_previewDetails,
                                          );
                                          prefs.setPreviewDetails(
                                            _previewDetails,
                                          );
                                      }
                                    },
                                    itemBuilder: (menuContext) {
                                      return [
                                        if (state.canEdit)
                                          PopupMenuItem(
                                            value: _OverflowAction.edit,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.edit_outlined,
                                                  size: 20,
                                                  color: AppColors.textPrimary,
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  'Edit',
                                                  style: AppTextStyles.body(),
                                                ),
                                              ],
                                            ),
                                          ),
                                        PopupMenuItem(
                                          value: _OverflowAction.share,
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.share_rounded,
                                                size: 20,
                                                color: AppColors.textPrimary,
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Share',
                                                style: AppTextStyles.body(),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (state.canEdit)
                                          PopupMenuItem(
                                            value: _OverflowAction.delete,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 20,
                                                  color: AppColors.error,
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  'Delete',
                                                  style: AppTextStyles.body(
                                                    color: AppColors.error,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (pageCount > 1)
                                          CheckedPopupMenuItem(
                                            value: _OverflowAction.previewAll,
                                            checked: _previewAll,
                                            child: Text(
                                              'Preview all',
                                              style: AppTextStyles.body(),
                                            ),
                                          ),
                                        CheckedPopupMenuItem(
                                          value:
                                              _OverflowAction.previewDetails,
                                          checked: _previewDetails,
                                          child: Text(
                                            'Preview details',
                                            style: AppTextStyles.body(),
                                          ),
                                        ),
                                      ];
                                    },
                                    child: Material(
                                      color: Colors.black.withValues(
                                        alpha: 0.35,
                                      ),
                                      shape: const CircleBorder(),
                                      child: SizedBox(
                                        width: 36,
                                        height: 36,
                                        child: Icon(
                                          Icons.more_vert_rounded,
                                          size: 18,
                                          color: AppColors.textOnPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (state.storeName.trim().isNotEmpty) ...[
                                const SizedBox(height: 14),
                                if (state.showStoreGroupLink &&
                                    (state.storeId?.trim().isNotEmpty ??
                                        false))
                                  GestureDetector(
                                    onTap: () => _openStoreGroup(state),
                                    behavior: HitTestBehavior.opaque,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            state.storeName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.body(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textOnPrimary
                                                  .withValues(alpha: 0.88),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 20,
                                          color: AppColors.textOnPrimary
                                              .withValues(alpha: 0.88),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Text(
                                    state.storeName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.body(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textOnPrimary.withValues(
                                        alpha: 0.88,
                                      ),
                                    ),
                                  ),
                              ],
                              if (_previewDetails)
                                Builder(
                                  builder: (context) {
                                    final category = state
                                        .categoryLabelForPhoto(photoIndex);
                                    if (category.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        top:
                                            state.storeName.trim().isNotEmpty
                                                ? 10
                                                : 14,
                                      ),
                                      child: ProductDetailsCategoryPill(
                                        label: category,
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    ignoring: !_showInfo,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: _showInfo ? 1 : 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                              Colors.black.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: AppPadding.screen(top: 56, bottom: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ProductMetaPanel(
                                product: product,
                                specDisplay: state.specDisplayForPhoto(
                                  photoIndex,
                                ),
                                previewDetails: _previewDetails,
                              ),
                              if (_previewAll && pageCount > 1) ...[
                                const SizedBox(height: 12),
                                ProductDetailsThumbStrip(
                                  paths: [
                                    for (var i = 0; i < pageCount; i++)
                                      useFeed
                                          ? feed![i].path
                                          : (imagePaths.isEmpty
                                              ? null
                                              : imagePaths[i]),
                                  ],
                                  activeIndex: _pageIndex,
                                  controller: _thumbController,
                                  onTapIndex: _goToPage,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        ),
      ),
    );
  }
}

class _ProductMetaPanel extends StatefulWidget {
  const _ProductMetaPanel({
    required this.product,
    this.specDisplay,
    required this.previewDetails,
  });

  final StoreProduct product;
  final PhotoSpecDisplay? specDisplay;
  final bool previewDetails;

  @override
  State<_ProductMetaPanel> createState() => _ProductMetaPanelState();
}

class _ProductMetaPanelState extends State<_ProductMetaPanel> {
  bool _detailsExpanded = false;

  @override
  void didUpdateWidget(covariant _ProductMetaPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Collapse when swiping to another photo's specs.
    if (oldWidget.specDisplay != widget.specDisplay) {
      _detailsExpanded = false;
    }
    // Hide expanded rows when Preview details is turned off.
    if (!widget.previewDetails && oldWidget.previewDetails) {
      _detailsExpanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final specDisplay = widget.specDisplay;
    final hasDescription = product.description.trim().isNotEmpty;
    final showWeight = widget.previewDetails;
    final hasPrimary = showWeight && (specDisplay?.hasPrimaryWeight ?? false);
    final details =
        showWeight
            ? (specDisplay?.detailLines ?? const <String>[])
            : const <String>[];
    final hasDetails = details.isNotEmpty;
    final fallbackLine = showWeight ? (specDisplay?.line.trim() ?? '') : '';
    final showFallback =
        showWeight &&
        !hasPrimary &&
        fallbackLine.isNotEmpty &&
        fallbackLine != 'Precise details applied';

    if (!hasDescription && !hasPrimary && !hasDetails && !showFallback) {
      return const SizedBox.shrink();
    }

    final muted = AppColors.textOnPrimary.withValues(alpha: 0.55);
    final strong = AppColors.textOnPrimary.withValues(alpha: 0.95);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasPrimary)
            GestureDetector(
              onTap:
                  hasDetails
                      ? () => setState(
                        () => _detailsExpanded = !_detailsExpanded,
                      )
                      : null,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: specDisplay!.primaryLabel!,
                            style: AppTextStyles.body(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: strong,
                            ),
                          ),
                          TextSpan(
                            text: '  ${specDisplay.primaryValue!}',
                            style: AppTextStyles.body(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (hasDetails)
                    Icon(
                      _detailsExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: muted,
                    ),
                ],
              ),
            )
          else if (showFallback)
            Text(
              fallbackLine,
              style: AppTextStyles.body(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: strong,
              ),
            ),
          if (hasPrimary && hasDetails && _detailsExpanded) ...[
            const SizedBox(height: 10),
            for (var i = 0; i < details.length; i++) ...[
              if (i > 0) const SizedBox(height: 4),
              Text(
                details[i],
                style: AppTextStyles.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
            ],
          ],
          if (hasDescription) ...[
            if (hasPrimary || showFallback || (hasDetails && _detailsExpanded))
              const SizedBox(height: 10),
            Text(
              product.description,
              style: AppTextStyles.body(
                fontSize: 14,
                color: AppColors.textOnPrimary.withValues(alpha: 0.92),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// class _TagChip extends StatelessWidget {
//   const _TagChip({required this.label});
//
//   final String label;
//
//   @override
//   Widget build(BuildContext context) {
//     final display = label.startsWith('#') ? label : '#$label';
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//       decoration: BoxDecoration(
//         color: Colors.white.withValues(alpha: 0.14),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
//       ),
//       child: Text(
//         display,
//         style: AppTextStyles.caption(
//           fontWeight: FontWeight.w600,
//           color: AppColors.textOnPrimary,
//         ),
//       ),
//     );
//   }
// }

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: AppColors.textOnPrimary),
        ),
      ),
    );
  }
}

class _ViewCountChip extends StatelessWidget {
  const _ViewCountChip({this.count});

  final int? count;

  @override
  Widget build(BuildContext context) {
    if (count == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 15,
                color: AppColors.textOnPrimary,
              ),
              const SizedBox(width: 4),
              Text(
                _formatCount(count!),
                style: AppTextStyles.caption(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOnPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LikeIconButton extends StatelessWidget {
  const _LikeIconButton({
    required this.liked,
    required this.busy,
    required this.onTap,
    this.likeCount,
  });

  final bool liked;
  final int? likeCount;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showCount = likeCount != null;
    final child =
        busy
            ? Padding(
              padding: const EdgeInsets.all(9),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textOnPrimary,
                ),
              ),
            )
            : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 18,
                  color:
                      liked ? AppColors.error : AppColors.textOnPrimary,
                ),
                if (showCount) ...[
                  const SizedBox(width: 4),
                  Text(
                    _formatCount(likeCount!),
                    style: AppTextStyles.caption(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                ],
              ],
            );

    if (!showCount) {
      return Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: busy ? null : onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(width: 36, height: 36, child: child),
        ),
      );
    }

    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: SizedBox(height: 20, child: child),
        ),
      ),
    );
  }
}

String _formatCount(int value) {
  if (value < 1000) return '$value';
  if (value < 10000) {
    final k = value / 1000;
    final text = k == k.roundToDouble() ? '${k.toInt()}' : k.toStringAsFixed(1);
    return '${text}k';
  }
  if (value < 1000000) return '${(value / 1000).floor()}k';
  final m = value / 1000000;
  final text = m == m.roundToDouble() ? '${m.toInt()}' : m.toStringAsFixed(1);
  return '${text}M';
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.tone});

  final int tone;

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone % 4) {
      0 => [
        AppColors.surfaceSecondary,
        AppColors.primary.withValues(alpha: 0.45),
      ],
      1 => [
        AppColors.surfaceSecondary,
        AppColors.primaryDark.withValues(alpha: 0.42),
      ],
      2 => [
        AppColors.surfaceSecondary,
        AppColors.accent.withValues(alpha: 0.35),
      ],
      _ => [
        AppColors.surfaceSecondary,
        AppColors.success.withValues(alpha: 0.38),
      ],
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.diamond_outlined,
          size: 48,
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}

enum _EditChoice { metadataPhotos, refine }

enum _OverflowAction { edit, share, delete, previewAll, previewDetails }
