import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/bulk_upload/bulk_upload_bloc.dart';
import 'package:project_c/bloc/product_details/product_details_bloc.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/be_verify.dart';
import 'package:project_c/helper/catalog_responsive_image.dart';
import 'package:project_c/helper/catalog_ui_mapper.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/merchant_profile_link.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/bulk_upload.dart';
import 'package:project_c/models/catalog/catalog_product_models.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/models/catalog/collection_specifications.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/navigation/telegram_photo_page_route.dart';
import 'package:project_c/presentation/add_store_product/compose_product_draft.dart';
import 'package:project_c/presentation/add_store_product/edit_refine_flow.dart';
import 'package:project_c/presentation/chat/chat_mock_store.dart';
import 'package:project_c/presentation/chat/chat_models.dart';
import 'package:project_c/presentation/product_details/product_details_widgets/product_details_widgets.dart';
import 'package:project_c/services/product_details_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:project_c/services/view_beacon.dart';
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

  /// Two fingers on the photo — lock [PageView] so pinch can start at 1×.
  bool _multiTouchLockingPage = false;
  Map<String, Object?>? _popResult;
  Timer? _viewDwellTimer;
  double _dismissDy = 0;

  /// Avoid thumb↔page feedback loops while one side drives the other.
  bool _syncingPageFromThumb = false;
  bool _syncingThumbFromPage = false;
  bool _thumbUserScrolling = false;

  /// Defer media warm / view-dwell until filmstrip scrub settles (Telegram-smooth).
  bool _deferWarmAfterThumbScrub = false;

  /// Gallery-feed product to activate after scrub settles (avoids mid-fling work).
  int? _pendingGalleryActivateIndex;

  /// Vertical dismiss via [Listener] (does not join the gesture arena, so
  /// horizontal PageView swipes stay snappy).
  int? _dismissPointer;
  Offset _dismissStart = Offset.zero;
  bool _dismissArmed = false;
  bool _pageSwipePreferred = false;
  double _dismissVelocityY = 0;

  /// Visitor composer for the photo on screen. Tap opens it; send starts
  /// that store's chat. Hidden on the owner's own store.
  bool _askComposerOpen = false;

  /// Weight chrome stays hidden while this is true (keyboard is up).
  bool _askShowKeyboard = false;
  final TextEditingController _askController = TextEditingController();
  final FocusNode _askFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _askFocus.addListener(_onAskFocusChanged);
    final blocState = context.read<ProductDetailsBloc>().state;
    final initialPage =
        blocState.hasGalleryFeed
            ? blocState.galleryFeedIndex
            : blocState.initialImageIndex;
    _pageIndex = initialPage;
    _pageController = PageController(initialPage: initialPage);
    _pageController.addListener(_onPageScroll);
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
    _askFocus.removeListener(_onAskFocusChanged);
    _askController.dispose();
    _askFocus.dispose();
    _viewDwellTimer?.cancel();
    // ignore: unawaited_futures
    ViewBeacon.instance.flush();
    _pageController.removeListener(_onPageScroll);
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
    old.removeListener(_onPageScroll);
    _pageController = PageController(initialPage: targetPage);
    _pageController.addListener(_onPageScroll);
    _pageIndex = targetPage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      old.dispose();
      if (mounted && _previewAll) _scrollThumbTo(targetPage, animate: false);
    });
  }

  static const double _thumbStride = ProductDetailsThumbStrip.itemStride;

  double _thumbOffsetForPage(double page) {
    if (!_thumbController.hasClients) return 0;
    final target = page * _thumbStride;
    return target.clamp(
      _thumbController.position.minScrollExtent,
      _thumbController.position.maxScrollExtent,
    );
  }

  void _scrollThumbTo(int index, {bool animate = true}) {
    if (!_thumbController.hasClients || _syncingPageFromThumb) return;
    final clamped = _thumbOffsetForPage(index.toDouble());
    if ((_thumbController.offset - clamped).abs() < 0.5) return;
    _syncingThumbFromPage = true;
    if (animate) {
      _thumbController
          .animateTo(
            clamped,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            _syncingThumbFromPage = false;
          });
    } else {
      _thumbController.jumpTo(clamped);
      _syncingThumbFromPage = false;
    }
  }

  /// Keep the filmstrip 1:1 with the pager while the main photo is mid-swipe.
  void _onPageScroll() {
    if (_syncingPageFromThumb || _thumbUserScrolling || !_previewAll) {
      return;
    }
    if (!_pageController.hasClients || !_thumbController.hasClients) return;
    final page = _pageController.page;
    if (page == null) return;
    final clamped = _thumbOffsetForPage(page);
    if ((_thumbController.offset - clamped).abs() < 0.5) return;
    _syncingThumbFromPage = true;
    _thumbController.jumpTo(clamped);
    _syncingThumbFromPage = false;
  }

  void _goToPage(int index) {
    if (!_pageController.hasClients) return;
    // Telegram: tap scrolls that thumb to center and shows the photo.
    _scrollThumbTo(index, animate: true);
    if (index == _pageIndex) {
      if (mounted) setState(() {});
      return;
    }
    _syncingPageFromThumb = true;
    _pageController.jumpToPage(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncingPageFromThumb = false;
      // Tap path uses quiet onPageChanged — sync chrome once here.
      if (mounted) setState(() {});
      final state = context.read<ProductDetailsBloc>().state;
      _activateGalleryProductIfNeeded(index, state);
      _warmMedia(state);
      _restartViewDwell(state);
    });
  }

  /// Called when the user slows on a thumb (inspect) or when scrub ends.
  /// Does not rebuild chrome mid-fling — that was killing free-flow momentum.
  void _onThumbScrollIndex(int index) {
    if (_syncingThumbFromPage || !_pageController.hasClients) return;
    _thumbUserScrolling = true;
    if (index == _pageIndex) return;
    _deferWarmAfterThumbScrub = true;
    _syncingPageFromThumb = true;
    _pageController.jumpToPage(index);
    // Keep flag true until the page notification finishes (same frame).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncingPageFromThumb = false;
    });
  }

  void _onThumbScrollEnd() {
    _thumbUserScrolling = false;
    _syncingPageFromThumb = false;
    // One chrome rebuild after free-flow settles (title / meta / highlight).
    if (mounted) {
      setState(() {
        final current = context.read<ProductDetailsBloc>().state;
        if (_askComposerOpen && _askTargetFor(current) == null) {
          _askComposerOpen = false;
          _askShowKeyboard = false;
        }
      });
      if (!_askComposerOpen) _askFocus.unfocus();
    }
    final state = context.read<ProductDetailsBloc>().state;
    final pendingGallery = _pendingGalleryActivateIndex;
    _pendingGalleryActivateIndex = null;
    if (pendingGallery != null) {
      _activateGalleryProductIfNeeded(pendingGallery, state);
    }
    if (_deferWarmAfterThumbScrub) {
      _deferWarmAfterThumbScrub = false;
      _warmMedia(state);
      _restartViewDwell(state);
    }
  }

  void _activateGalleryProductIfNeeded(int index, ProductDetailsState state) {
    if (!state.hasGalleryFeed) return;
    if (index < 0 || index >= state.galleryFeed!.length) return;
    final entry = state.galleryFeed![index];
    final activeId = state.product.id;
    if (entry.product.id == activeId) return;
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

  _AskTarget? _askTargetFor(ProductDetailsState state) {
    if (state.isOwnStore || state.isContentLocked) return null;
    final feed = state.galleryFeed;
    final useFeed =
        state.hasGalleryFeed &&
        feed != null &&
        _pageIndex >= 0 &&
        _pageIndex < feed.length;
    final StoreProduct product;
    final int imageIndex;
    final String storeId;
    final String storeName;
    if (useFeed) {
      final item = feed[_pageIndex];
      product = item.product;
      imageIndex = item.imageIndex;
      storeId = (item.storeId ?? state.storeId ?? '').trim();
      storeName = (item.storeName ?? state.storeName).trim();
    } else {
      product = state.product;
      imageIndex = _pageIndex;
      storeId = (state.storeId ?? '').trim();
      storeName = state.storeName.trim();
    }
    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      return null;
    }
    final rawTitle =
        useFeed && product.id != state.product.id
            ? product.title
            : state.titlePartsForPhoto(imageIndex).title;
    final title = rawTitle.trim().isEmpty ? 'Product' : rawTitle.trim();
    final meta = product.meta.trim();
    const swatches = <Color>[
      Color(0xFFC4A265),
      Color(0xFFB76E79),
      Color(0xFF8C6A3D),
      Color(0xFF6E7F8C),
    ];
    return _AskTarget(
      storeId: storeId,
      storeName: storeName.isEmpty ? 'Store' : storeName,
      product: ChatProductRef(
        id: '$storeId|${product.id}|$imageIndex',
        name: title,
        detail: meta.isEmpty ? 'Product' : meta,
        color: swatches[product.toneIndex.abs() % swatches.length],
        imageUrl: product.urlForRole(imageIndex, CatalogImageRole.grid),
      ),
    );
  }

  void _onAskFocusChanged() {
    if (!mounted || !_askComposerOpen) return;
    if (_askFocus.hasFocus == _askShowKeyboard) return;
    setState(() => _askShowKeyboard = _askFocus.hasFocus);
  }

  void _openAskComposer() {
    setState(() {
      _askComposerOpen = true;
      _askShowKeyboard = true;
      _showInfo = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_askComposerOpen) return;
      _askFocus.requestFocus();
    });
  }

  void _closeAskComposer() {
    _askFocus.unfocus();
    if (!_askComposerOpen && !_askShowKeyboard) return;
    setState(() {
      _askComposerOpen = false;
      _askShowKeyboard = false;
      _showInfo = false;
    });
  }

  /// Visitors who can ask: tap opens the composer. A second tap drops the
  /// keyboard so weight details can show; a third tap closes it.
  /// Own-store and zoomed photos keep the chrome toggle.
  void _onPhotoTap(ProductDetailsState state) {
    if (_imageZoomed) {
      setState(() => _showInfo = !_showInfo);
      return;
    }
    final canAsk = _askTargetFor(state) != null;
    if (_askComposerOpen) {
      if (_askShowKeyboard || _askFocus.hasFocus) {
        _askFocus.unfocus();
        if (_askShowKeyboard) {
          setState(() => _askShowKeyboard = false);
        }
        return;
      }
      _closeAskComposer();
      return;
    }
    if (canAsk) {
      _openAskComposer();
      return;
    }
    setState(() => _showInfo = !_showInfo);
  }

  void _onPhotoZoomChanged(int index, bool zoomed) {
    if (!mounted) return;
    if (index != _pageIndex && zoomed) return;
    final closeAsk = zoomed && _askComposerOpen;
    if (_imageZoomed == zoomed && !closeAsk) return;
    if (closeAsk) _askFocus.unfocus();
    setState(() {
      _imageZoomed = zoomed;
      if (zoomed) {
        _askComposerOpen = false;
        _askShowKeyboard = false;
      }
    });
  }

  void _sendAsk(ProductDetailsState state) {
    final target = _askTargetFor(state);
    final text = _askController.text.trim();
    if (target == null || text.isEmpty) return;
    HapticFeedback.selectionClick();
    final chatId = ChatMockStore.instance.sendEnquiry(
      storeId: target.storeId,
      storeName: target.storeName,
      text: text,
      products: [target.product],
    );
    _askController.clear();
    _askFocus.unfocus();
    setState(() {
      _askComposerOpen = false;
      _askShowKeyboard = false;
      _showInfo = false;
    });
    final openId = ChatMockStore.instance.threadById(chatId)?.openDiscussionId;
    Navigator.of(context).pushNamed(
      Routes.chatThreadRoute,
      arguments: <String, String?>{
        'chatId': chatId,
        'openDiscussionId': openId,
      },
    );
  }

  int _productImageIndex(ProductDetailsState state) {
    if (state.hasGalleryFeed) {
      final feed = state.galleryFeed!;
      if (_pageIndex < 0 || _pageIndex >= feed.length) return 0;
      final entry = feed[_pageIndex];
      // Same listing as the feed row: imageIndex is within that product.
      if (entry.product.id == state.product.id) {
        return entry.imageIndex;
      }
      // Collection-scoped product (e.g. after edit refresh) while the feed
      // still has per-product rows seeded with imageIndex 0 — map the
      // visible row onto state.product photo slots (B3.2 chrome).
      final path = entry.path.trim();
      if (path.isNotEmpty) {
        final byPath = state.product.imagePaths.indexWhere(
          (p) => p.trim() == path,
        );
        if (byPath >= 0) return byPath;
      }
      final feedProductId = entry.product.id.trim();
      if (feedProductId.isNotEmpty) {
        final ids = state.product.photoAssetIds;
        final byId = ids.indexWhere((id) => id.trim() == feedProductId);
        if (byId >= 0) return byId;
        for (var i = 0; i < ids.length; i++) {
          if (state.catalogProductIdForPhoto(i) == feedProductId) {
            return i;
          }
        }
        for (final asset in entry.product.photoAssetIds) {
          final a = asset.trim();
          if (a.isEmpty) continue;
          final byAsset = ids.indexWhere((id) => id.trim() == a);
          if (byAsset >= 0) return byAsset;
        }
      }
      if (feed.length == state.product.imagePaths.length &&
          state.product.imagePaths.isNotEmpty) {
        return _pageIndex.clamp(0, state.product.imagePaths.length - 1);
      }
      return entry.imageIndex;
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
    final scrubbing = _syncingPageFromThumb || _thumbUserScrolling;
    if (scrubbing) {
      // Quiet update — no setState. Parent rebuilds mid-fling stop the strip.
      _pageIndex = index;
      _imageZoomed = false;
      _multiTouchLockingPage = false;
      _deferWarmAfterThumbScrub = true;
      if (state.hasGalleryFeed) {
        _pendingGalleryActivateIndex = index;
      }
      return;
    }

    setState(() {
      _pageIndex = index;
      // Re-enable swipe after leaving a zoomed page (page itself resets on dispose).
      _imageZoomed = false;
      _multiTouchLockingPage = false;
      if (_askComposerOpen && _askTargetFor(state) == null) {
        _askComposerOpen = false;
        _askShowKeyboard = false;
      }
    });
    if (!_askComposerOpen) _askFocus.unfocus();
    _warmMedia(state);
    _restartViewDwell(state);
    // PageView swipe syncs the strip via [_onPageScroll]; settle align here.
    if (_previewAll) {
      _scrollThumbTo(index, animate: false);
    }
    _activateGalleryProductIfNeeded(index, state);
  }

  Future<void> _openEdit(ProductDetailsState state) async {
    context.read<ProductDetailsBloc>().add(const ProductDetailsClearOpenEdit());
    await _openRefineEdit(state);
  }

  Future<void> _editAvailability(ProductDetailsState state) async {
    final product = state.product;
    var stock = product.stockStatus ?? CatalogStockStatus.inStock;
    var locked = product.isLocked;
    var mtoDays = product.mtoDays ?? 7;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppPadding.horizontal,
                16,
                AppPadding.horizontal,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Availability',
                    style: AppTextStyles.headline(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Stock',
                    style: AppTextStyles.caption(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final s in CatalogStockStatus.values)
                        ChoiceChip(
                          label: Text(
                            s.shortLabel,
                            style: AppTextStyles.caption(
                              fontWeight: FontWeight.w600,
                              color:
                                  stock == s
                                      ? AppColors.textOnPrimary
                                      : AppColors.textPrimary,
                            ),
                          ),
                          selected: stock == s,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.surfaceSecondary,
                          side: BorderSide(
                            color:
                                stock == s
                                    ? AppColors.primary
                                    : AppColors.textPrimary.withValues(
                                      alpha: 0.25,
                                    ),
                          ),
                          showCheckmark: false,
                          onSelected: (_) => setSheetState(() => stock = s),
                        ),
                    ],
                  ),
                  if (stock == CatalogStockStatus.mto) ...[
                    const SizedBox(height: 12),
                    Text(
                      'MTO days',
                      style: AppTextStyles.caption(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      initialValue: '$mtoDays',
                      keyboardType: TextInputType.number,
                      style: AppTextStyles.body(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        isDense: true,
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: AppColors.surfaceSecondary,
                      ),
                      onChanged: (v) {
                        final n = int.tryParse(v.trim());
                        if (n != null && n > 0) mtoDays = n;
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Locked',
                      style: AppTextStyles.body(color: AppColors.textPrimary),
                    ),
                    subtitle: Text(
                      'Hidden from non-followers',
                      style: AppTextStyles.caption(
                        color: AppColors.textPrimary.withValues(alpha: 0.7),
                      ),
                    ),
                    value: locked,
                    onChanged: (v) => setSheetState(() => locked = v),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    child: Text(
                      'Save',
                      style: AppTextStyles.button(
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (!mounted || saved != true) return;

    final productIds = _availabilityProductIds(state);
    BeVerify.step(
      '3 Availability UI',
      detail:
          'listing=${BeVerify.shortId(product.id)} '
          'patchIds=${productIds.map(BeVerify.shortId).join(",")} '
          'stock=${stock.apiValue} locked=$locked',
    );
    if (productIds.isEmpty) {
      BeVerify.fail(
        'availability — no product ids (would 404 on collection id)',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not find a product id for availability. Try again after photos load.',
          ),
        ),
      );
      return;
    }
    if (productIds.contains(product.id.trim())) {
      BeVerify.info(
        'availability patch includes listing id',
        detail: 'ok if listing is a real product id',
      );
    } else {
      BeVerify.ok(
        'availability uses embedded product ids (not collection id)',
        detail: 'n=${productIds.length}',
      );
    }

    try {
      final repo = ServiceLocator.get<CollectionRepository>();
      final body = <String, dynamic>{
        'stock_status': stock.apiValue,
        if (stock == CatalogStockStatus.mto) 'mto_days': mtoDays,
        'is_locked': locked,
      };
      // Collection listings embed multiple CatalogProducts — PATCH each product
      // id (never the collection id; that 404s as PRODUCT_NOT_FOUND).
      CatalogProduct? last;
      for (final id in productIds) {
        last = await repo.updateProduct(productId: id, body: body);
      }
      if (!mounted) return;
      final mapped =
          last != null
              ? CatalogUiMapper.catalogProductToStoreProduct(last)
              : null;
      final nextLocked = mapped?.isLocked ?? locked;
      final nextStock = mapped?.stockStatus ?? stock;
      final nextMto = mapped?.mtoDays ?? mtoDays;
      final nextProduct = product.copyWith(
        isLocked: nextLocked,
        stockStatus: nextStock,
        mtoDays: nextMto,
      );
      BeVerify.ok(
        'availability applied locally',
        detail:
            'locked=$nextLocked stock=${nextStock.apiValue} '
            'pop updated=true',
      );
      context.read<ProductDetailsBloc>().add(
        ProductDetailsApplyEditedProduct(
          product: nextProduct,
          revision: state.revision,
        ),
      );
      // So store profile grid keeps lock/stock after pop → reopen.
      _popResult = <String, Object?>{'updated': true, ...nextProduct.toMap()};
    } catch (e) {
      BeVerify.fail('availability apply', detail: '$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(e))),
      );
    }
  }

  /// Real CatalogProduct ids for availability PATCH (not collection listing id).
  List<String> _availabilityProductIds(ProductDetailsState state) {
    final ids = <String>{};
    for (final id in state.product.photoAssetIds) {
      final trimmed = id.trim();
      if (trimmed.isNotEmpty && !trimmed.startsWith('img_')) {
        ids.add(trimmed);
      }
    }
    for (final id in state.productSpecsById.keys) {
      final trimmed = id.trim();
      if (trimmed.isNotEmpty && !trimmed.startsWith('img_')) {
        ids.add(trimmed);
      }
    }
    if (ids.isEmpty && state.usesProductLike) {
      final id = state.product.id.trim();
      if (id.isNotEmpty) ids.add(id);
    }
    return ids.toList(growable: false);
  }

  Future<void> _openRefineEdit(ProductDetailsState state) async {
    final storeId = state.storeId;
    if (storeId == null || storeId.isEmpty) return;

    BulkUploadBloc? bloc;
    try {
      final listingId =
          state.product.collectionId.trim().isNotEmpty
              ? state.product.collectionId.trim()
              : state.product.id;
      final detail = await ServiceLocator.get<CollectionRepository>()
          .fetchCollection(storeId: storeId, listingId: listingId);
      if (!mounted) return;
      final photoIndexBefore = _productImageIndex(state);
      final photoId = state.photoIdAt(photoIndexBefore);
      final pathBefore = _currentImagePath(state)?.trim() ?? '';
      bloc = BulkUploadBloc.fromCollectionDetail(
        detail: detail,
        storeId: storeId,
        initiallySelectedIds: photoId.isNotEmpty ? [photoId] : const [],
      );
      // Prefer the current photo; map img_… ↔ product `_id` when hydrate
      // ids differ from details photoAssetIds (jewel).
      var items = _refineItemsForPhoto(
        bloc: bloc,
        detail: detail,
        photoId: photoId,
      );
      if (items.isEmpty) {
        items = List<BulkUploadItem>.from(bloc.state.items);
      }
      if (items.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No photos available to edit.')),
        );
        return;
      }

      AppLog.d(
        kEditRefineLogTag,
        'details_edit → compose_direct '
        'photoId=${photoId.isEmpty ? '-' : photoId} '
        'items=${items.length}',
      );

      final stock = detail.stockStatus;
      final result = await openComposeRefineEdit(
        context: context,
        bloc: bloc,
        items: items,
        stockFallback: CatalogStockStatusFallback(
          stockStatus: composeStockStatusFromName(stock?.apiValue),
          mtoDays: detail.mtoDays,
          isLocked: detail.isLocked,
        ),
      );
      if (!mounted) return;
      if (result == null) return;

      final payload = Map<String, Object?>.from(result);
      final revision = payload['revision'];
      final apiTag = (payload['apiTag'] as String?) ?? '';
      var product = StoreProduct.fromMap(payload);

      // Re-fetch so weight/purity chrome (productSpecsById) matches what edit
      // just PATCHed — StoreProduct alone does not carry per-photo specs.
      ProductSpec? specifications;
      Map<String, ProductSpec>? productSpecsById;
      String? precisionTag;
      List<CollectionSubGroup>? subGroups;
      var nextRevision = revision is int ? revision : state.revision;
      var nextApiTag = apiTag;
      try {
        final refreshed = await ServiceLocator.get<CollectionRepository>()
            .fetchCollection(storeId: storeId, listingId: listingId);
        if (!mounted) return;
        product = CatalogUiMapper.detailToProduct(refreshed).copyWith(
          canEdit: product.canEdit || state.canEdit,
          canDelete: product.canDelete || state.canDelete,
          likeCount: product.likeCount ?? refreshed.likeCount,
          viewCount: product.viewCount ?? refreshed.viewCount,
        );
        nextRevision = refreshed.revision;
        nextApiTag =
            refreshed.tag.trim().isNotEmpty ? refreshed.tag : nextApiTag;
        specifications = ProductSpec.fromApiJson(
          refreshed.specifications?.toJson(),
        );
        productSpecsById = refreshed.productSpecsById;
        precisionTag = refreshed.precisionTag;
        subGroups = refreshed.subGroups;
      } catch (_) {
        // Keep payload product; details still get ApplyEditedProduct below.
      }

      // Stay on the edited photo when refetch reorders photos[] / products[].
      final preferredIndex = _indexOfEditedPhoto(
        product: product,
        productSpecsById: productSpecsById ?? const {},
        photoId: photoId,
        path: pathBefore,
        editedItemId: items.first.id.trim(),
        fallbackIndex: photoIndexBefore,
      );

      _popResult = <String, Object?>{
        'updated': true,
        ...product.toMap(),
      };
      // PageView indexes the gallery feed when present — resolve stay page
      // from the pre-apply feed (bloc state is not updated synchronously).
      final latest = context.read<ProductDetailsBloc>().state;
      var stayPage = preferredIndex;
      final existingFeed = latest.galleryFeed;
      if (latest.hasGalleryFeed &&
          existingFeed != null &&
          existingFeed.isNotEmpty) {
        final byPath =
            pathBefore.isEmpty
                ? -1
                : existingFeed.indexWhere((e) => e.path.trim() == pathBefore);
        if (byPath >= 0) {
          stayPage = byPath;
        } else if (preferredIndex >= 0 &&
            preferredIndex < existingFeed.length) {
          stayPage = preferredIndex;
        } else {
          stayPage = _pageIndex;
        }
      }
      context.read<ProductDetailsBloc>().add(
        ProductDetailsApplyEditedProduct(
          product: product,
          revision: nextRevision,
          apiTag: nextApiTag,
          specifications: specifications,
          productSpecsById: productSpecsById,
          precisionTag: precisionTag,
          subGroups: subGroups,
          preferredImageIndex: preferredIndex,
        ),
      );
      if (mounted && stayPage != _pageIndex) {
        _reseatPager(stayPage);
      }
      AppLog.d(
        kEditRefineLogTag,
        'details_edit applied stayIndex=$preferredIndex '
        'stayPage=$stayPage '
        'photoId=${photoId.isEmpty ? '-' : photoId} '
        'editedItem=${items.first.id}',
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

  /// Current-photo refine set: exact id, then img_ ↔ product `_id` via specs.
  List<BulkUploadItem> _refineItemsForPhoto({
    required BulkUploadBloc bloc,
    required CollectionDetail detail,
    required String photoId,
  }) {
    final selectedIds = bloc.state.selectedItemIds.toSet();
    final matched = [
      for (final item in bloc.state.items)
        if (selectedIds.contains(item.id)) item,
    ];
    if (matched.isNotEmpty) return matched;
    if (photoId.isEmpty) return const [];

    final known = {for (final item in bloc.state.items) item.id};
    if (known.contains(photoId)) {
      return [
        for (final item in bloc.state.items)
          if (item.id == photoId) item,
      ];
    }

    final seed = detail.productSpecsById[photoId];
    if (seed == null) return const [];
    for (final item in bloc.state.items) {
      final spec = detail.productSpecsById[item.id];
      if (spec == null) continue;
      if (identical(spec, seed) || spec == seed) {
        return [item];
      }
    }
    return const [];
  }

  /// Find the slide that matches the photo we edited (id, product sibling, or URL).
  int _indexOfEditedPhoto({
    required StoreProduct product,
    required Map<String, ProductSpec> productSpecsById,
    required String photoId,
    required String path,
    required String editedItemId,
    required int fallbackIndex,
  }) {
    final ids = product.photoAssetIds;
    final paths = product.imagePaths;
    int clamp(int i) {
      if (paths.isEmpty) return 0;
      if (i < 0) return 0;
      if (i >= paths.length) return paths.length - 1;
      return i;
    }

    if (photoId.isNotEmpty) {
      final byId = ids.indexWhere((id) => id.trim() == photoId);
      if (byId >= 0) return clamp(byId);
    }
    if (editedItemId.isNotEmpty) {
      final byItem = ids.indexWhere((id) => id.trim() == editedItemId);
      if (byItem >= 0) return clamp(byItem);
    }

    // img_ on details vs product `_id` on hydrate / photoAssetIds after refetch.
    final seedId = photoId.isNotEmpty ? photoId : editedItemId;
    if (seedId.isNotEmpty && productSpecsById.isNotEmpty) {
      final seed = productSpecsById[seedId];
      if (seed != null) {
        for (var i = 0; i < ids.length; i++) {
          final id = ids[i].trim();
          if (id.isEmpty) continue;
          final spec = productSpecsById[id];
          if (spec != null && (identical(spec, seed) || spec == seed)) {
            return clamp(i);
          }
        }
      }
    }

    if (path.isNotEmpty) {
      final byPath = paths.indexWhere((p) => p.trim() == path);
      if (byPath >= 0) return clamp(byPath);
    }
    return clamp(fallbackIndex);
  }

  void _popDetails() {
    // So Telegram close continues from the dragged frame (not a full-size flash).
    if (_dismissDy > 0) {
      final dismissT = (_dismissDy / 240).clamp(0.0, 1.0);
      TelegramPhotoCloseAnchor.arm(dy: _dismissDy, scale: 1 - dismissT * 0.08);
    } else {
      TelegramPhotoCloseAnchor.clear();
    }
    // Push aggregated like / view / wishlist counts to the store card on close.
    var result = _popResult;
    if (mounted) {
      final state = context.read<ProductDetailsBloc>().state;
      final product = state.product;
      final likes = product.likeCount ?? 0;
      final views = product.viewCount ?? 0;
      final wish = state.wishlistedProductIds.length;
      if (result == null && (likes > 0 || views > 0 || wish > 0)) {
        result = <String, Object?>{
          'updated': true,
          'silent': true,
          ...product.toMap(),
          if (wish > 0) 'wishlistCount': wish,
        };
      } else if (result != null && wish > 0) {
        result = <String, Object?>{...result, 'wishlistCount': wish};
      }
    }
    Navigator.of(context).pop(result);
  }

  void _resetDismissTracking() {
    _dismissPointer = null;
    _dismissArmed = false;
    _pageSwipePreferred = false;
    _dismissVelocityY = 0;
  }

  void _onDismissPointerDown(PointerDownEvent event) {
    if (_imageZoomed || _askComposerOpen) return;
    _dismissPointer = event.pointer;
    _dismissStart = event.position;
    _dismissArmed = false;
    _pageSwipePreferred = false;
    _dismissVelocityY = 0;
  }

  void _onDismissPointerMove(PointerMoveEvent event) {
    if (_imageZoomed || event.pointer != _dismissPointer) return;
    final delta = event.position - _dismissStart;
    if (!_dismissArmed && !_pageSwipePreferred) {
      final adx = delta.dx.abs();
      final ady = delta.dy.abs();
      if (adx > 10 && adx > ady) {
        // Horizontal intent — leave the pager alone (no arena fight).
        _pageSwipePreferred = true;
        return;
      }
      if (delta.dy > 12 && ady > adx) {
        _dismissArmed = true;
        if (_showInfo) {
          setState(() => _showInfo = false);
        }
      }
    }
    if (!_dismissArmed || _pageSwipePreferred) return;
    final next = delta.dy.clamp(0.0, 280.0);
    _dismissVelocityY = event.delta.dy;
    if (next == _dismissDy) return;
    setState(() => _dismissDy = next);
  }

  void _onDismissPointerEnd(PointerEvent event) {
    if (event.pointer != _dismissPointer) return;
    final shouldPop =
        _dismissArmed && (_dismissDy > 90 || _dismissVelocityY > 18);
    _resetDismissTracking();
    if (shouldPop) {
      _popDetails();
      return;
    }
    if (_dismissDy != 0) {
      setState(() => _dismissDy = 0);
    }
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
      ProductDetailsDeletePressed(imageIndex: _productImageIndex(state)),
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
              (prev, curr) => curr.shouldOpenEdit && !prev.shouldOpenEdit,
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
            // matched liked photo (keeps like filled, avoids flash to photo 0).
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
        // After like/unlike, sync listing likeCount back to store grid (silent).
        BlocListener<ProductDetailsBloc, ProductDetailsState>(
          listenWhen:
              (prev, curr) =>
                  !curr.isLikeBusy &&
                  prev.isLikeBusy &&
                  prev.product.likeCount != curr.product.likeCount,
          listener: (context, state) {
            _popResult = <String, Object?>{
              'updated': true,
              'silent': true,
              ...state.product.toMap(),
              if (state.wishlistedProductIds.isNotEmpty)
                'wishlistCount': state.wishlistedProductIds.length,
            };
          },
        ),
        // After wishlist toggle, sync viewer-private wishlistCount on the card.
        BlocListener<ProductDetailsBloc, ProductDetailsState>(
          listenWhen:
              (prev, curr) =>
                  !curr.isWishlistBusy &&
                  prev.isWishlistBusy &&
                  prev.wishlistedProductIds.length !=
                      curr.wishlistedProductIds.length,
          listener: (context, state) {
            final wish = state.wishlistedProductIds.length;
            _popResult = <String, Object?>{
              'updated': true,
              'silent': true,
              ...state.product.toMap(),
              'wishlistCount': wish,
            };
          },
        ),
      ],
      child: ScreenWrapper(
        backgroundColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        // Full-bleed photo (Telegram flyer lands on contain frame, then chrome).
        // The ask composer lifts itself over the keyboard; the photo stays full-size.
        extendBodyBehindBottom: true,
        resizeToAvoidBottomInset: false,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_askComposerOpen) {
              _closeAskComposer();
              return;
            }
            _popDetails();
          },
          child: BlocBuilder<ProductDetailsBloc, ProductDetailsState>(
            builder: (context, state) {
              if (state.isContentLocked) {
                return ScreenWrapper(
                  backgroundColor: AppColors.background,
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: AppPadding.screen(top: 8, bottom: 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AppBackButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: AppPadding.screenHorizontal,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock_rounded,
                                    size: 48,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Locked product',
                                    style: AppTextStyles.title(fontSize: 20),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Follow this store and get approved to view locked products.',
                                    style: AppTextStyles.bodySecondary(),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final product = state.product;
              final imagePaths = product.imagePaths;
              final feed = state.galleryFeed;
              final useFeed = state.hasGalleryFeed;
              final askTarget = _askTargetFor(state);
              final pageCount =
                  useFeed
                      ? feed!.length
                      : (imagePaths.isEmpty ? 1 : imagePaths.length);
              final photoIndex = _productImageIndex(state);
              final importPending =
                  useFeed &&
                          feed != null &&
                          _pageIndex >= 0 &&
                          _pageIndex < feed.length
                      ? feed[_pageIndex].product.isImportPendingAt(
                        feed[_pageIndex].imageIndex,
                      )
                      : product.isImportPendingAt(photoIndex);
              final importDeclined =
                  useFeed &&
                          feed != null &&
                          _pageIndex >= 0 &&
                          _pageIndex < feed.length
                      ? feed[_pageIndex].product.isImportDeclinedAt(
                        feed[_pageIndex].imageIndex,
                      )
                      : product.isImportDeclinedAt(photoIndex);
              final dismissT = (_dismissDy / 240).clamp(0.0, 1.0);
              final keyboard = MediaQuery.viewInsetsOf(context).bottom;
              final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
              final askPhotoPath = _currentImagePath(state);

              Widget detailsPanel({required double bottom}) {
                return DecoratedBox(
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
                    padding: AppPadding.screen(top: 56, bottom: bottom),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ProductMetaPanel(
                          product: product,
                          specDisplay: state.specDisplayForPhoto(photoIndex),
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
                            onScrollIndex: _onThumbScrollIndex,
                            onScrollEnd: _onThumbScrollEnd,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              return Listener(
                behavior: HitTestBehavior.deferToChild,
                onPointerDown: _onDismissPointerDown,
                onPointerMove: _onDismissPointerMove,
                onPointerUp: _onDismissPointerEnd,
                onPointerCancel: _onDismissPointerEnd,
                child: Opacity(
                  opacity: 1 - dismissT * 0.35,
                  child: Transform.translate(
                    offset: Offset(0, _dismissDy),
                    child: Transform.scale(
                      scale: 1 - dismissT * 0.08,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: PageView.builder(
                              controller: _pageController,
                              allowImplicitScrolling: true,
                              physics:
                                  _imageZoomed ||
                                          _multiTouchLockingPage ||
                                          _dismissArmed
                                      ? const NeverScrollableScrollPhysics()
                                      : const BouncingScrollPhysics(
                                        decelerationRate:
                                            ScrollDecelerationRate.fast,
                                        parent: PageScrollPhysics(),
                                      ),
                              itemCount: pageCount,
                              onPageChanged:
                                  (index) => _onPageChanged(index, state),
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
                                    onTap: () => _onPhotoTap(state),
                                    child: _ImagePlaceholder(tone: tone),
                                  );
                                }

                                return ProductDetailsZoomablePhoto(
                                  key: ValueKey<String>('pd-zoom-$index-$path'),
                                  path: path,
                                  isActive: index == _pageIndex,
                                  onTap: () => _onPhotoTap(state),
                                  onZoomChanged:
                                      (zoomed) =>
                                          _onPhotoZoomChanged(index, zoomed),
                                  onMultiTouchChanged: (multi) {
                                    if (!mounted) return;
                                    if (index != _pageIndex && multi) {
                                      return;
                                    }
                                    if (_multiTouchLockingPage == multi) return;
                                    setState(
                                      () => _multiTouchLockingPage = multi,
                                    );
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            _RoundIconButton(
                                              icon:
                                                  Icons
                                                      .arrow_back_ios_new_rounded,
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
                                                      .titlePartsForPhoto(
                                                        photoIndex,
                                                      )
                                                      .title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: AppTextStyles.body(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppColors.textOnPrimary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (state.isDeleting)
                                              Padding(
                                                padding: EdgeInsets.only(
                                                  right: 8,
                                                ),
                                                child: SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color:
                                                            AppColors
                                                                .textOnPrimary,
                                                      ),
                                                ),
                                              ),
                                            _ViewCountChip(
                                              count: state.viewCountForPhoto(
                                                photoIndex,
                                              ),
                                            ),
                                            _LikeIconButton(
                                              liked: state.isPhotoLiked(
                                                photoIndex,
                                              ),
                                              likeCount: state
                                                  .likeCountForPhoto(
                                                    photoIndex,
                                                  ),
                                              onTap: () {
                                                context
                                                    .read<ProductDetailsBloc>()
                                                    .add(
                                                      ProductDetailsLikePressed(
                                                        imageIndex: photoIndex,
                                                      ),
                                                    );
                                              },
                                            ),
                                            const SizedBox(width: 4),
                                            if (!state.isOwnStore) ...[
                                              _WishlistIconButton(
                                                wishlisted: state
                                                    .isPhotoWishlisted(
                                                      photoIndex,
                                                    ),
                                                busy: state.isWishlistBusy,
                                                onTap: () {
                                                  context
                                                      .read<
                                                        ProductDetailsBloc
                                                      >()
                                                      .add(
                                                        ProductDetailsWishlistPressed(
                                                          imageIndex:
                                                              photoIndex,
                                                        ),
                                                      );
                                                },
                                              ),
                                              const SizedBox(width: 4),
                                            ],
                                            PopupMenuButton<_OverflowAction>(
                                              tooltip: 'More',
                                              color: AppColors.surface,
                                              elevation: 8,
                                              offset: const Offset(0, 40),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              onSelected: (action) {
                                                final prefs =
                                                    ServiceLocator.get<
                                                      ProductDetailsPreferences
                                                    >();
                                                switch (action) {
                                                  case _OverflowAction.edit:
                                                    context
                                                        .read<
                                                          ProductDetailsBloc
                                                        >()
                                                        .add(
                                                          const ProductDetailsEditPressed(),
                                                        );
                                                  case _OverflowAction
                                                      .availability:
                                                    unawaited(
                                                      _editAvailability(state),
                                                    );
                                                  case _OverflowAction.share:
                                                    final path =
                                                        _currentImagePath(
                                                          state,
                                                        );
                                                    context
                                                        .read<
                                                          ProductDetailsBloc
                                                        >()
                                                        .add(
                                                          ProductDetailsSharePressed(
                                                            imagePath:
                                                                path ?? '',
                                                          ),
                                                        );
                                                  case _OverflowAction
                                                      .shareLink:
                                                    final message =
                                                        MerchantProfileLink.productShareMessage(
                                                          storeLinkOrSlug:
                                                              state.storeLink,
                                                          productId:
                                                              state.product.id,
                                                        );
                                                    if (message.isEmpty) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Could not share this product link.',
                                                          ),
                                                        ),
                                                      );
                                                    } else {
                                                      unawaited(
                                                        Share.share(message),
                                                      );
                                                    }
                                                  case _OverflowAction.delete:
                                                    if (!state.isDeleting) {
                                                      _confirmDeletePhoto(
                                                        state,
                                                      );
                                                    }
                                                  case _OverflowAction
                                                      .previewAll:
                                                    setState(
                                                      () =>
                                                          _previewAll =
                                                              !_previewAll,
                                                    );
                                                    prefs.setPreviewAll(
                                                      _previewAll,
                                                    );
                                                    if (_previewAll) {
                                                      _scheduleThumbScroll();
                                                    }
                                                  case _OverflowAction
                                                      .previewDetails:
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
                                                      value:
                                                          _OverflowAction.edit,
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.edit_outlined,
                                                            size: 20,
                                                            color:
                                                                AppColors
                                                                    .textPrimary,
                                                          ),
                                                          const SizedBox(
                                                            width: 12,
                                                          ),
                                                          Text(
                                                            'Edit',
                                                            style:
                                                                AppTextStyles.body(),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  if (state.canEdit)
                                                    PopupMenuItem(
                                                      value:
                                                          _OverflowAction
                                                              .availability,
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .inventory_2_outlined,
                                                            size: 20,
                                                            color:
                                                                AppColors
                                                                    .textPrimary,
                                                          ),
                                                          const SizedBox(
                                                            width: 12,
                                                          ),
                                                          Text(
                                                            'Availability',
                                                            style:
                                                                AppTextStyles.body(),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  PopupMenuItem(
                                                    value:
                                                        _OverflowAction.share,
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.share_rounded,
                                                          size: 20,
                                                          color:
                                                              AppColors
                                                                  .textPrimary,
                                                        ),
                                                        const SizedBox(
                                                          width: 12,
                                                        ),
                                                        Text(
                                                          'Share',
                                                          style:
                                                              AppTextStyles.body(),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    value:
                                                        _OverflowAction
                                                            .shareLink,
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.link_rounded,
                                                          size: 20,
                                                          color:
                                                              AppColors
                                                                  .textPrimary,
                                                        ),
                                                        const SizedBox(
                                                          width: 12,
                                                        ),
                                                        Text(
                                                          'Share link',
                                                          style:
                                                              AppTextStyles.body(),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (state.canEdit)
                                                    PopupMenuItem(
                                                      value:
                                                          _OverflowAction
                                                              .delete,
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .delete_outline_rounded,
                                                            size: 20,
                                                            color:
                                                                AppColors.error,
                                                          ),
                                                          const SizedBox(
                                                            width: 12,
                                                          ),
                                                          Text(
                                                            'Delete',
                                                            style:
                                                                AppTextStyles.body(
                                                                  color:
                                                                      AppColors
                                                                          .error,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  if (pageCount > 1)
                                                    CheckedPopupMenuItem(
                                                      value:
                                                          _OverflowAction
                                                              .previewAll,
                                                      checked: _previewAll,
                                                      child: Text(
                                                        'Preview all',
                                                        style:
                                                            AppTextStyles.body(),
                                                      ),
                                                    ),
                                                  CheckedPopupMenuItem(
                                                    value:
                                                        _OverflowAction
                                                            .previewDetails,
                                                    checked: _previewDetails,
                                                    child: Text(
                                                      'Preview details',
                                                      style:
                                                          AppTextStyles.body(),
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
                                                    color:
                                                        AppColors.textOnPrimary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        // Store name, store-group link, and category/
                                        // title under the toolbar are omitted (owner +
                                        // visitor). Only exceptional lock / stock /
                                        // pending-import chrome.
                                        if (_previewDetails &&
                                            ProductDetailsLockStockRow.shouldShow(
                                              isLocked: product.isLocked,
                                              stockStatus: product.stockStatus,
                                              importPending: importPending,
                                              importDeclined: importDeclined,
                                            ))
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 14,
                                            ),
                                            child: ProductDetailsLockStockRow(
                                              isLocked: product.isLocked,
                                              stockStatus: product.stockStatus,
                                              mtoDays: product.mtoDays,
                                              importPending: importPending,
                                              importDeclined: importDeclined,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (!_askComposerOpen)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: IgnorePointer(
                                ignoring: !_showInfo,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 180),
                                  opacity: _showInfo ? 1 : 0,
                                  child: detailsPanel(bottom: 20 + safeBottom),
                                ),
                              ),
                            ),
                          if (_askComposerOpen && askTarget != null)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom:
                                  _askShowKeyboard && keyboard > 0
                                      ? keyboard + 6
                                      : safeBottom + 8,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!_askShowKeyboard && keyboard == 0)
                                    detailsPanel(bottom: 4),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: _AskPhotoComposer(
                                      controller: _askController,
                                      focusNode: _askFocus,
                                      imagePath: askPhotoPath,
                                      onSend: () => _sendAsk(state),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AskTarget {
  const _AskTarget({
    required this.storeId,
    required this.storeName,
    required this.product,
  });

  final String storeId;
  final String storeName;
  final ChatProductRef product;
}

/// WhatsApp-style reply bar for the photo on screen. No suggestion chips.
class _AskPhotoComposer extends StatefulWidget {
  const _AskPhotoComposer({
    required this.controller,
    required this.focusNode,
    required this.imagePath,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? imagePath;
  final VoidCallback onSend;

  @override
  State<_AskPhotoComposer> createState() => _AskPhotoComposerState();
}

class _AskPhotoComposerState extends State<_AskPhotoComposer> {
  static const _accent = Color(0xFF21C063);
  static const _button = Color(0xFF00A884);
  static const _bar = Color(0xFF1F2C34);
  static const _icon = Color(0xFF8696A0);
  static const _text = Color(0xFFE9EDEF);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant _AskPhotoComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onChanged);
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final canSend = widget.controller.text.trim().isNotEmpty;
    final path = widget.imagePath?.trim() ?? '';
    final showPhoto = path.isNotEmpty && ProductImagePaths.isDisplayable(path);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _bar,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 6, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: _accent, width: 3),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'You',
                                  style: AppTextStyles.label(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _accent,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.photo_outlined,
                                      size: 15,
                                      color: _icon,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Photo',
                                      style: AppTextStyles.body(
                                        fontSize: 14,
                                        color: _icon,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              width: 46,
                              height: 46,
                              child:
                                  showPhoto
                                      ? ProductMediaImage(
                                        path: path,
                                        fit: BoxFit.cover,
                                        width: 46,
                                        height: 46,
                                      )
                                      : const ColoredBox(
                                        color: Color(0xFF111B21),
                                        child: Icon(
                                          Icons.photo_outlined,
                                          color: _icon,
                                          size: 18,
                                        ),
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Smiley — hidden for now.
                      // const Padding(
                      //   padding: EdgeInsets.fromLTRB(2, 0, 2, 8),
                      //   child: Icon(
                      //     Icons.emoji_emotions_outlined,
                      //     color: _icon,
                      //     size: 24,
                      //   ),
                      // ),
                      Expanded(
                        child: TextField(
                          controller: widget.controller,
                          focusNode: widget.focusNode,
                          minLines: 1,
                          maxLines: 4,
                          cursorColor: _accent,
                          textCapitalization: TextCapitalization.sentences,
                          style: AppTextStyles.body(fontSize: 16, color: _text),
                          decoration: const InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      // Attachment — hidden for now.
                      // const Padding(
                      //   padding: EdgeInsets.fromLTRB(2, 0, 2, 8),
                      //   child: Icon(
                      //     Icons.attach_file,
                      //     color: _icon,
                      //     size: 22,
                      //   ),
                      // ),
                      // Camera — hidden for now.
                      // const Padding(
                      //   padding: EdgeInsets.fromLTRB(2, 0, 2, 8),
                      //   child: Icon(
                      //     Icons.photo_camera_outlined,
                      //     color: _icon,
                      //     size: 22,
                      //   ),
                      // ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Material(
          color: canSend ? _button : _button.withValues(alpha: 0.45),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: canSend ? widget.onSend : null,
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
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
                      ? () =>
                          setState(() => _detailsExpanded = !_detailsExpanded)
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
    required this.onTap,
    this.likeCount,
  });

  final bool liked;
  final int? likeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showCount = likeCount != null;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          liked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
          size: 18,
          color: liked ? AppColors.accent : AppColors.textOnPrimary,
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
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(width: 36, height: 36, child: Center(child: child)),
        ),
      );
    }

    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: SizedBox(height: 20, child: child),
        ),
      ),
    );
  }
}

/// Private wishlist (heart) — separate from public like (thumbs up).
class _WishlistIconButton extends StatelessWidget {
  const _WishlistIconButton({
    required this.wishlisted,
    required this.onTap,
    this.busy = false,
  });

  final bool wishlisted;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: busy ? null : onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child:
                busy
                    ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnPrimary,
                      ),
                    )
                    : Icon(
                      wishlisted
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 18,
                      color:
                          wishlisted
                              ? AppColors.error
                              : AppColors.textOnPrimary,
                    ),
          ),
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

enum _OverflowAction {
  edit,
  availability,
  share,
  shareLink,
  delete,
  previewAll,
  previewDetails,
}
