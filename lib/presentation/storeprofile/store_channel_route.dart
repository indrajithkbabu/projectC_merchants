import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/presentation/store_import/quick_import_flow.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/catalog_media_debug.dart';
import 'package:project_c/helper/catalog_responsive_image.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/visitor_wishlist_batch.dart';
import 'package:project_c/helper/whatsapp_invite.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/appearance_scope.dart';
import 'package:project_c/helper/widgets/catalog_image_edge_fades.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/product_details_feed_item.dart';
import 'package:project_c/models/product_view_mode.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/navigation/smooth_fade_page_route.dart';
import 'package:project_c/navigation/telegram_photo_page_route.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/gallery_pinch_host.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_product_gallery_sliver.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_product_grid.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_profile_header_card.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_visitor_follow_bar.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/visitor_photo_selection_chrome.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/wishlist/wishlist_repository.dart';

/// Telegram-style store channel screen (Discover / visitor header destination).
class StoreChannelRoute extends StatefulWidget {
  const StoreChannelRoute({
    super.key,
    required this.storeId,
    required this.storeName,
    required this.storeLink,
    required this.imageUrls,
    required this.products,
    this.followerCount = 0,
    this.followingCount = 0,
    this.productCount = 0,
    this.isOwnStore = false,
    this.enableFollowChrome = false,
  });

  final String storeId;
  final String storeName;
  final String storeLink;
  final List<String> imageUrls;
  final List<StoreProduct> products;
  final int followerCount;
  final int followingCount;
  final int productCount;
  final bool isOwnStore;

  /// When true, a [StoreProfileBloc] is provided above this route for Follow.
  final bool enableFollowChrome;

  @override
  State<StoreChannelRoute> createState() => _StoreChannelRouteState();
}

class _ChannelPhoto {
  const _ChannelPhoto({
    required this.product,
    required this.imageIndex,
  });

  final StoreProduct product;
  final int imageIndex;

  String urlFor(CatalogImageRole role, {bool log = false}) =>
      product.urlForRole(imageIndex, role, log: log);
}

class _StoreChannelRouteState extends State<StoreChannelRoute>
    with TickerProviderStateMixin {
  static const _expandedHeight = 320.0;
  /// Pinch zoom-in → fewer cells (min 2). Zoom-out → denser grid (max 9).
  static const _minColumns = 2.0;
  static const _maxColumns = 9.0;

  late final TabController _tabs;
  late final PageController _logoPager;
  late final AnimationController _columnSnap;
  final ScrollController _scroll = ScrollController();
  /// 1 = hero fully expanded; 0 = collapsed app bar. Drives title visibility.
  final ValueNotifier<double> _expandT = ValueNotifier<double>(1);

  int _logoPage = 0;
  /// Continuous column count while pinching (snaps to int on release).
  double _mediaColumns = 4;
  double _pinchBaseColumns = 4;
  bool _pinching = false;
  /// Gallery tab pinch columns (independent of Media).
  double _galleryColumns = 4;
  /// Decode-warm media into [ImageCache] once per route instance.
  bool _mediaWarmed = false;
  /// Last densest column count warmed at [CatalogImageRole.grid].
  int _lastWarmedGridColumns = 0;
  /// Last densest column count warmed at [CatalogImageRole.detail].
  int _lastWarmedDetailColumns = 0;
  int _lastWarmedGalleryGridColumns = 0;
  int _lastWarmedGalleryDetailColumns = 0;

  /// Visitor photo multi-select: `"productId|imageIndex"`.
  final Set<String> _selectedPhotoKeys = {};
  bool _visitorPhotoSelecting = false;
  bool _visitorWishlistBusy = false;

  /// Local product list so wishlist like-count bumps paint without rebuild args.
  late List<StoreProduct> _products;

  bool get _canVisitorPhotoSelect => !widget.isOwnStore;

  void _exitVisitorPhotoSelection() {
    if (!_visitorPhotoSelecting && _selectedPhotoKeys.isEmpty) return;
    setState(() {
      _visitorPhotoSelecting = false;
      _selectedPhotoKeys.clear();
    });
  }

  void _enterVisitorPhotoSelection(StoreProduct product, int imageIndex) {
    if (product.importSelectionBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exclusive piece — cannot be re-imported'),
        ),
      );
      return;
    }
    setState(() {
      _visitorPhotoSelecting = true;
      _selectedPhotoKeys
        ..clear()
        ..add(StoreProductGrid.photoKey(product.id, imageIndex));
    });
  }

  void _toggleVisitorPhoto(StoreProduct product, int imageIndex) {
    final key = StoreProductGrid.photoKey(product.id, imageIndex);
    if (!_selectedPhotoKeys.contains(key) &&
        product.importSelectionBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exclusive piece — cannot be re-imported'),
        ),
      );
      return;
    }
    setState(() {
      if (_selectedPhotoKeys.contains(key)) {
        _selectedPhotoKeys.remove(key);
        if (_selectedPhotoKeys.isEmpty) {
          _visitorPhotoSelecting = false;
        }
      } else {
        _selectedPhotoKeys.add(key);
      }
    });
  }

  void _onVisitorPhotoLongPress(StoreProduct product, int imageIndex) {
    if (!_canVisitorPhotoSelect) return;
    if (_visitorPhotoSelecting) {
      _toggleVisitorPhoto(product, imageIndex);
    } else {
      _enterVisitorPhotoSelection(product, imageIndex);
    }
  }

  void _onVisitorPhotoTap(StoreProduct product, int imageIndex) {
    if (_visitorPhotoSelecting) {
      _toggleVisitorPhoto(product, imageIndex);
    }
  }

  void _handleBack() {
    if (_visitorPhotoSelecting) {
      _exitVisitorPhotoSelection();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop();
    }
  }

  bool get _viewerCanImport {
    if (widget.isOwnStore) return false;
    try {
      return context.read<StoreProfileBloc>().state.canImport;
    } catch (_) {
      final id = ServiceLocator.get<CatalogSession>().ownStoreId?.trim() ?? '';
      return id.isNotEmpty;
    }
  }

  /// Selection Import opens the Quick upload review, prefilled from the source.
  Future<void> _onVisitorSelectionImport() async {
    final opened = await QuickImportFlow.openFromSelection(
      context: context,
      photoKeys: Set<String>.from(_selectedPhotoKeys),
      products: _products,
      sourceStoreId: widget.storeId,
      sourceStoreName: widget.storeName,
      canImport: _viewerCanImport,
    );
    if (!mounted || !opened) return;
    setState(() {
      _selectedPhotoKeys.clear();
      _visitorPhotoSelecting = false;
    });
  }

  /// Private wishlist bookmark for selected cards.
  Future<void> _onVisitorSelectionWishlist() async {
    if (_visitorWishlistBusy || _selectedPhotoKeys.isEmpty) return;

    setState(() => _visitorWishlistBusy = true);
    try {
      final outcome = await VisitorWishlistBatch.wishlistSelected(
        wishlist: ServiceLocator.get<WishlistRepository>(),
        photoKeys: _selectedPhotoKeys,
        products: _products,
        storeId: widget.storeId,
      );
      if (!mounted) return;

      setState(() {
        _products = VisitorWishlistBatch.applyWishlistCounts(
          products: _products,
          newlyAddedProductIds: outcome.newlyAddedProductIds,
        );
        _selectedPhotoKeys.clear();
        _visitorPhotoSelecting = false;
        _visitorWishlistBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _visitorWishlistBusy = false);
      final msg = CatalogErrorMapper.toUserMessage(e).trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg.isEmpty
                ? 'Could not update wishlist. Please try again.'
                : msg,
          ),
        ),
      );
    }
  }

  List<_ChannelPhoto> get _allPhotos {
    final out = <_ChannelPhoto>[];
    for (final product in _products) {
      for (var i = 0; i < product.imagePaths.length; i++) {
        final master = product.imagePaths[i];
        if (!ProductImagePaths.isDisplayable(master)) continue;
        out.add(_ChannelPhoto(product: product, imageIndex: i));
      }
    }
    return out;
  }

  CatalogImageRole get _mediaPaintRole =>
      CatalogResponsiveImage.roleForMediaColumns(_mediaColumns.round());

  /// Store logos only — never fall back to product photos.
  List<String> get _heroImages =>
      widget.imageUrls
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _products = List<StoreProduct>.from(widget.products);
    _tabs = TabController(length: 3, vsync: this);
    _logoPager = PageController();
    _columnSnap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant StoreChannelRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.products, widget.products)) {
      _products = List<StoreProduct>.from(widget.products);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_mediaWarmed) return;
    _mediaWarmed = true;
    final photos = _allPhotos;
    final gridUrls = [
      for (final photo in photos) photo.urlFor(CatalogImageRole.grid),
    ];
    // InstantCatalogPhoto: disk-warm thumbs; decode densest grid (9) + current
    // paint tier so land + pinch zoom-out/in paint without staggered loading.
    CatalogMediaDebug.render(
      'store_channel land heroes=${_heroImages.length} '
      'media=${photos.length} products=${widget.products.length} '
      'paintRole=${_mediaPaintRole.name} cols=${_mediaColumns.round()}',
    );
    CatalogMediaDebug.quality(
      'QA checklist filter=CatalogMediaDBG+QUALITY | '
      'Media+Gallery pinch 6-9→thumbnail 2-5→detail tap→master | '
      'Group→thumbnail Single→detail tap→master',
    );
    _warmGalleryForColumns(_galleryColumns.round());
    var hashNull = 0;
    for (final photo in photos) {
      if ((photo.product.thumbhashAt(photo.imageIndex) ?? '').isEmpty) {
        hashNull++;
      }
    }
    if (hashNull > 0) {
      CatalogMediaDebug.gap(
        'store_channel Media thumbhashNULL=$hashNull / ${photos.length}',
      );
    } else {
      CatalogMediaDebug.render(
        'store_channel Media thumbhashYES=all (${photos.length})',
      );
    }
    // ignore: unawaited_futures
    CatalogImageCache.precacheUrls([
      ..._heroImages,
      ...gridUrls,
    ]);
    _warmMediaTier(CatalogImageRole.grid, columns: _maxColumns.toInt());
    _warmMediaTier(_mediaPaintRole, columns: _mediaColumns.round());
    if (_heroImages.isNotEmpty) {
      // ignore: unawaited_futures
      CatalogImageCache.precacheUrls(
        _heroImages,
        decode: true,
        maxDecode: 4,
        cacheWidth: CatalogImageCache.fullCacheWidth(),
      );
    }
  }

  void _warmMediaTier(CatalogImageRole role, {required int columns}) {
    final photos = _allPhotos;
    if (photos.isEmpty) return;
    final cols = columns.clamp(2, 9);
    if (role == CatalogImageRole.grid) {
      if (cols <= _lastWarmedGridColumns && _lastWarmedGridColumns > 0) return;
      _lastWarmedGridColumns = cols;
    } else if (role == CatalogImageRole.detail) {
      if (cols <= _lastWarmedDetailColumns && _lastWarmedDetailColumns > 0) {
        return;
      }
      _lastWarmedDetailColumns = cols;
    } else {
      return;
    }
    final urls = [for (final photo in photos) photo.urlFor(role)];
    final last = CatalogImageCache.mediaGridWarmCount(columns: cols) - 1;
    CatalogMediaDebug.render(
      'store_channel warm role=${role.name} cols=$cols '
      'decode=0..$last cacheW=${CatalogImageCache.cacheWidthForRole(role)}',
    );
    // ignore: unawaited_futures
    CatalogImageCache.warmWindow(
      urls: urls,
      firstIndex: 0,
      lastIndex: last,
      cacheWidth: CatalogImageCache.cacheWidthForRole(role),
      concurrency: 12,
    );
  }

  void _warmMediaForColumns(int columns) {
    final cols = columns.clamp(2, 9);
    final role = CatalogResponsiveImage.roleForMediaColumns(cols);
    // Densifying toward 9 always needs more grid tiles.
    if (cols > _lastWarmedGridColumns) {
      _warmMediaTier(CatalogImageRole.grid, columns: cols);
    }
    if (role == CatalogImageRole.detail) {
      _warmMediaTier(CatalogImageRole.detail, columns: cols);
    }
  }

  void _warmGalleryTier(CatalogImageRole role, {required int columns}) {
    final photos = _allPhotos;
    if (photos.isEmpty) return;
    final cols = columns.clamp(2, 9);
    if (role == CatalogImageRole.grid) {
      if (cols <= _lastWarmedGalleryGridColumns &&
          _lastWarmedGalleryGridColumns > 0) {
        return;
      }
      _lastWarmedGalleryGridColumns = cols;
    } else if (role == CatalogImageRole.detail) {
      if (cols <= _lastWarmedGalleryDetailColumns &&
          _lastWarmedGalleryDetailColumns > 0) {
        return;
      }
      _lastWarmedGalleryDetailColumns = cols;
    } else {
      return;
    }
    final urls = [for (final photo in photos) photo.urlFor(role)];
    final last = CatalogImageCache.mediaGridWarmCount(columns: cols) - 1;
    CatalogMediaDebug.render(
      'store_channel galleryWarm role=${role.name} cols=$cols '
      'decode=0..$last cacheW=${CatalogImageCache.cacheWidthForRole(role)}',
    );
    // ignore: unawaited_futures
    CatalogImageCache.warmWindow(
      urls: urls,
      firstIndex: 0,
      lastIndex: last,
      cacheWidth: CatalogImageCache.cacheWidthForRole(role),
      concurrency: 12,
    );
  }

  void _warmGalleryForColumns(int columns) {
    final cols = columns.clamp(2, 9);
    final role = CatalogResponsiveImage.roleForMediaColumns(cols);
    if (cols > _lastWarmedGalleryGridColumns) {
      _warmGalleryTier(CatalogImageRole.grid, columns: cols);
    }
    if (role == CatalogImageRole.detail) {
      _warmGalleryTier(CatalogImageRole.detail, columns: cols);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _logoPager.dispose();
    _columnSnap.dispose();
    _scroll.dispose();
    _expandT.dispose();
    super.dispose();
  }

  Future<void> _openFollowers(String tab) async {
    if (!widget.isOwnStore) return;
    await Navigator.of(context).pushNamed(
      Routes.followersFollowingRoute,
      arguments: <String, Object?>{
        'storeId': widget.storeId,
        'storeName': widget.storeName,
        'initialTab': tab,
        'followerCount': widget.followerCount,
        'followingCount': widget.followingCount,
      },
    );
  }

  Future<void> _copyStoreLink() async {
    final link = widget.storeLink.trim();
    final text =
        link.isEmpty
            ? widget.storeName
            : '${widget.storeName}\n$link';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Store link copied')),
    );
  }

  Future<void> _shareStoreViaWhatsApp() async {
    final link = widget.storeLink.trim();
    final name =
        widget.storeName.trim().isEmpty ? 'this store' : widget.storeName.trim();
    final url =
        link.isEmpty
            ? WhatsAppInvite.defaultAppUrl
            : (link.startsWith('http://') || link.startsWith('https://')
                ? link
                : 'https://$link');
    final message = 'Check out $name on JewelFlow: $url';
    final ok = await WhatsAppInvite.shareText(message);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open WhatsApp')),
    );
  }

  Future<void> _openPhoto(_ChannelPhoto photo, {Rect? sourceRect}) async {
    if (_visitorPhotoSelecting) {
      _toggleVisitorPhoto(photo.product, photo.imageIndex);
      return;
    }
    // Tap → master `url` (high). Media tiles use grid/detail by columns.
    final feed =
        _allPhotos
            .map(
              (p) => ProductDetailsFeedItem(
                product: p.product,
                imageIndex: p.imageIndex,
                path: p.urlFor(CatalogImageRole.zoom),
              ),
            )
            .toList(growable: false);
    final index = feed.indexWhere(
      (e) =>
          e.product.id == photo.product.id && e.imageIndex == photo.imageIndex,
    );
    final masterPath = photo.urlFor(CatalogImageRole.zoom, log: true);
    final paintPath = photo.urlFor(_mediaPaintRole);
    CatalogMediaDebug.qualityTapOpen(
      from: 'channel_media cols=${_mediaColumns.round()}',
      role: CatalogImageRole.zoom,
      url: masterPath,
      paintedUrl: paintPath,
    );
    // Med/High: disk + decode master at fullCacheWidth so details pinch hits
    // the same ImageCache key (grids use half-width — different key).
    // ignore: unawaited_futures
    CatalogImageCache.precacheUrls(
      [masterPath],
      decode: true,
      maxDecode: 1,
      cacheWidth: CatalogImageCache.fullCacheWidth(),
    );
    final thumb = photo.product.thumbhashAt(photo.imageIndex);
    await Navigator.of(context).pushNamed(
      Routes.productDetailsRoute,
      arguments: <String, Object?>{
        'product': photo.product,
        'storeId': widget.storeId,
        'storeName': widget.storeName,
        'storeLink': widget.storeLink,
        'isOwnStore': widget.isOwnStore,
        'imageIndex': photo.imageIndex,
        'galleryFeed': feed,
        'galleryFeedIndex': index < 0 ? 0 : index,
        if (sourceRect != null && paintPath.trim().isNotEmpty) ...{
          'photoSourceRect': rectToArgs(sourceRect),
          // Flyer starts from the painted grid/detail tile.
          'photoPath': paintPath,
          if (thumb != null && thumb.isNotEmpty) 'photoThumbhash': thumb,
        },
      },
    );
  }

  void _onPinchStart(double baseColumns) {
    _columnSnap.stop();
    setState(() {
      _pinching = true;
      _pinchBaseColumns = baseColumns;
    });
  }

  void _onPinchUpdate(double scale) {
    if (!_pinching || !scale.isFinite || scale <= 0) return;
    // Pinch out (scale > 1) → fewer columns (zoom in). Pinch in → more columns.
    final next = (_pinchBaseColumns / scale).clamp(_minColumns, _maxColumns);
    if ((next - _mediaColumns).abs() < 0.008) return;
    setState(() => _mediaColumns = next);
    // Densifying → more thumbs; enlarging → detailUrl tier.
    _warmMediaForColumns(next.round());
  }

  void _onPinchEnd() {
    if (!_pinching) return;
    final from = _mediaColumns;
    final to =
        from.round().clamp(_minColumns.toInt(), _maxColumns.toInt()).toDouble();
    setState(() => _pinching = false);
    _warmMediaForColumns(to.toInt());
    if ((from - to).abs() < 0.02) {
      if (from != to) setState(() => _mediaColumns = to);
      return;
    }
    final anim = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(parent: _columnSnap, curve: Curves.easeOutCubic),
    );
    void tick() {
      if (!mounted) return;
      setState(() => _mediaColumns = anim.value);
    }

    anim.addListener(tick);
    _columnSnap.forward(from: 0).whenComplete(() {
      anim.removeListener(tick);
      if (!mounted) return;
      setState(() => _mediaColumns = to);
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPad = ScreenWrapper.statusBarTop(context);
    final heroes = _heroImages;
    final logoUrl = heroes.isNotEmpty ? heroes.first : null;

    return PopScope(
      canPop: !_visitorPhotoSelecting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_visitorPhotoSelecting) _exitVisitorPhotoSelection();
      },
      child: EdgeBackSwipe(
      onBack: () async => _handleBack(),
      child: ScreenWrapper(
      backgroundColor: AppColors.background,
      extendBodyBehindBottom: true,
      child: Stack(
        children: [
          NestedScrollView(
        controller: _scroll,
        // Lock outer scroll while pinching so vertical pinch doesn't collapse
        // the header / shove the media grid upward.
        physics:
            _pinching
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
        headerSliverBuilder: (context, _) {
          return [
            SliverAppBar(
              pinned: true,
              stretch: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              // Transparent so collapsing hero / content show through frosted bar.
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              forceMaterialTransparency: true,
              automaticallyImplyLeading: false,
              // Match other screens: custom toolbar row with AppPadding (no
              // Material leading inset / titleSpacing pushing content away).
              leadingWidth: 0,
              titleSpacing: 0,
              toolbarHeight: 52,
              expandedHeight: _expandedHeight + topPad * 0.35,
              title: Padding(
                padding: AppPadding.screenHorizontal,
                child: Row(
                  children: [
                    AppBackButton(
                      close: _visitorPhotoSelecting,
                      onPressed: _handleBack,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: ValueListenableBuilder<double>(
                        valueListenable: _expandT,
                        builder: (context, expandT, _) {
                          // Keep identity visible while selecting photos.
                          final show =
                              _visitorPhotoSelecting
                                  ? 1.0
                                  : 1.0 -
                                      ((expandT - 0.12) / 0.55).clamp(
                                        0.0,
                                        1.0,
                                      );
                          return _CollapsedTitle(
                            storeName: widget.storeName,
                            imageUrl: logoUrl,
                            followerCount: widget.followerCount,
                            selectedCount:
                                _visitorPhotoSelecting
                                    ? _selectedPhotoKeys.length
                                    : null,
                            onForward:
                                _visitorPhotoSelecting && _viewerCanImport
                                    ? _onVisitorSelectionImport
                                    : null,
                            opacity: Curves.easeOutCubic.transform(show),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) {
                  final max = _expandedHeight + topPad * 0.35 + 52;
                  final min = 52.0 + topPad;
                  final t = ((constraints.maxHeight - min) / (max - min))
                      .clamp(0.0, 1.0);
                  if (_expandT.value != t) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _expandT.value != t) {
                        _expandT.value = t;
                      }
                    });
                  }
                  // Glass only when collapsed. Expanded = full clear hero
                  // (no BackdropFilter / border band — that looked like a seam).
                  final frostT =
                      _visitorPhotoSelecting
                          ? 1.0
                          : (1.0 - ((t - 0.05) / 0.42).clamp(0.0, 1.0));
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      FlexibleSpaceBar(
                        collapseMode: CollapseMode.parallax,
                        // No blurBackground — it paints a hard band on the hero.
                        stretchModes: const [StretchMode.zoomBackground],
                        background: _HeroHeader(
                          topPad: topPad,
                          storeName: widget.storeName,
                          followerCount: widget.followerCount,
                          heroes: heroes,
                          logoPager: _logoPager,
                          logoPage: _logoPage,
                          expandT: t,
                          onPageChanged: (i) => setState(() => _logoPage = i),
                        ),
                      ),
                      if (frostT > 0.02)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: topPad + 52,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: Curves.easeOutCubic.transform(frostT),
                              child: const _ChannelGlassBar(),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Padding(
                    padding: AppPadding.screenHorizontal,
                    child: _ActionButtonsRow(
                      productCount:
                          widget.productCount > 0
                              ? widget.productCount
                              : _products.length,
                      followerCount: widget.followerCount,
                      followingCount: widget.followingCount,
                      onFollowers:
                          widget.isOwnStore
                              ? () => _openFollowers('followers')
                              : null,
                      onFollowing:
                          widget.isOwnStore
                              ? () => _openFollowers('following')
                              : null,
                    ),
                  ),
                  if (widget.enableFollowChrome) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: AppPadding.screenHorizontal,
                      child: const _ChannelFollowSection(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Padding(
                    padding: AppPadding.screenHorizontal,
                    child: _InviteLinkCard(
                      storeLink: widget.storeLink,
                      onCopy: _copyStoreLink,
                      onShare: _shareStoreViaWhatsApp,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: AppPadding.screenHorizontal,
                    child: _ChannelTabBar(controller: _tabs),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ];
        },
        // Tabs switch via the pill bar only — swipe would steal horizontal pinch.
        body: TabBarView(
          controller: _tabs,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _MediaTab(
              photos: _allPhotos,
              columns: _mediaColumns,
              pinching: _pinching,
              photoSelectionMode: _visitorPhotoSelecting,
              selectedPhotoKeys: _selectedPhotoKeys,
              onPinchStart: _onPinchStart,
              onPinchUpdate: _onPinchUpdate,
              onPinchEnd: _onPinchEnd,
              onTap: _openPhoto,
              onLongPress:
                  _canVisitorPhotoSelect
                      ? (photo) => _onVisitorPhotoLongPress(
                        photo.product,
                        photo.imageIndex,
                      )
                      : null,
            ),
            _GroupTab(
              products: _products,
              photoSelectionMode: _visitorPhotoSelecting,
              selectedPhotoKeys: _selectedPhotoKeys,
              onImageLongPress:
                  _canVisitorPhotoSelect ? _onVisitorPhotoLongPress : null,
              onProductTap:
                  (product, imageIndex, {Rect? sourceRect}) {
                    if (_visitorPhotoSelecting) {
                      _onVisitorPhotoTap(product, imageIndex);
                      return;
                    }
                    Navigator.of(context).pushNamed(
                      Routes.collectionBrowseRoute,
                      arguments: <String, Object?>{
                        'product': product,
                        'storeId': widget.storeId,
                        'storeName': widget.storeName,
                        'storeLink': widget.storeLink,
                        'isOwnStore': widget.isOwnStore,
                      },
                    );
                  },
            ),
            _GalleryTab(
              products: _products,
              columns: _galleryColumns,
              photoSelectionMode: _visitorPhotoSelecting,
              selectedPhotoKeys: _selectedPhotoKeys,
              onColumnsChanged: (cols) {
                _galleryColumns = cols.toDouble();
                _warmGalleryForColumns(cols);
              },
              onImageLongPress:
                  _canVisitorPhotoSelect ? _onVisitorPhotoLongPress : null,
              onImageTap: (product, imageIndex, {Rect? sourceRect}) {
                if (_visitorPhotoSelecting) {
                  _onVisitorPhotoTap(product, imageIndex);
                  return;
                }
                final paintRole = CatalogResponsiveImage.roleForMediaColumns(
                  _galleryColumns.round(),
                );
                // Flyer matches painted Gallery tile; details use master.
                final paintPath = product.urlForRole(imageIndex, paintRole);
                final masterPath = product.urlForRole(
                  imageIndex,
                  CatalogImageRole.zoom,
                );
                CatalogMediaDebug.qualityTapOpen(
                  from: 'channel_gallery cols=${_galleryColumns.round()}',
                  role: CatalogImageRole.zoom,
                  url: masterPath,
                  paintedUrl: paintPath,
                );
                final thumb = product.thumbhashAt(imageIndex);
                // ignore: unawaited_futures
                CatalogImageCache.precacheUrls(
                  [masterPath],
                  decode: true,
                  maxDecode: 1,
                  cacheWidth: CatalogImageCache.fullCacheWidth(),
                );
                Navigator.of(context).pushNamed(
                  Routes.productDetailsRoute,
                  arguments: <String, Object?>{
                    'product': product,
                    'storeId': widget.storeId,
                    'storeName': widget.storeName,
                    'storeLink': widget.storeLink,
                    'isOwnStore': widget.isOwnStore,
                    'imageIndex': imageIndex,
                    if (sourceRect != null &&
                        paintPath.trim().isNotEmpty) ...{
                      'photoSourceRect': rectToArgs(sourceRect),
                      'photoPath': paintPath,
                      if (thumb != null && thumb.isNotEmpty)
                        'photoThumbhash': thumb,
                    },
                  },
                );
              },
            ),
          ],
        ),
      ),
          // Edge wash only when the hero is collapsed — when expanded it sat
          // on the store photo and drew the visible horizontal separation.
          Positioned(
            top: topPad + 52,
            left: 0,
            right: 0,
            bottom: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _expandT,
              builder: (context, expandT, child) {
                final show =
                    _visitorPhotoSelecting
                        ? 1.0
                        : (1.0 - ((expandT - 0.08) / 0.35).clamp(0.0, 1.0));
                if (show <= 0.02) return const SizedBox.shrink();
                return Opacity(
                  opacity: Curves.easeOutCubic.transform(show),
                  child: child,
                );
              },
              child: const CatalogImageEdgeFades(topHeight: 28),
            ),
          ),
          if (_visitorPhotoSelecting)
            Builder(
              builder: (context) {
                final split = visitorImportSelectionSplit(
                  photoKeys: _selectedPhotoKeys,
                  products: widget.products,
                );
                return VisitorPhotoSelectionOverlay(
                  onImport:
                      _viewerCanImport ? _onVisitorSelectionImport : null,
                  onWishlist: _onVisitorSelectionWishlist,
                  wishlistBusy: _visitorWishlistBusy,
                  showImport: _viewerCanImport,
                  importCount: _selectedPhotoKeys.length,
                  importInstantCount: split.instant,
                  importPendingCount: split.pending,
                );
              },
            ),
        ],
      ),
      ),
      ),
    );
  }
}

/// Visitor Follow chrome — requires [StoreProfileBloc] from route args wrap.
class _ChannelFollowSection extends StatelessWidget {
  const _ChannelFollowSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StoreProfileBloc, StoreProfileState>(
      buildWhen:
          (prev, next) =>
              prev.followStatus != next.followStatus ||
              prev.isFollowBusy != next.isFollowBusy ||
              prev.notifyUploads != next.notifyUploads ||
              prev.showVisitorFollowChrome != next.showVisitorFollowChrome ||
              prev.storeName != next.storeName,
      builder: (context, state) {
        if (!state.showVisitorFollowChrome) return const SizedBox.shrink();
        return StoreVisitorFollowBar(
          followStatus: state.followStatus,
          isBusy: state.isFollowBusy,
          notifyUploads: state.notifyUploads,
          storeName: state.storeName,
          onFollow:
              () => context.read<StoreProfileBloc>().add(
                const StoreProfileFollowPressed(),
              ),
          onUnfollow:
              () => context.read<StoreProfileBloc>().add(
                const StoreProfileUnfollowPressed(),
              ),
          onToggleNotify:
              () => context.read<StoreProfileBloc>().add(
                const StoreProfileToggleNotifyUploads(),
              ),
        );
      },
    );
  }
}

class _CollapsedTitle extends StatelessWidget {
  const _CollapsedTitle({
    required this.storeName,
    required this.opacity,
    this.imageUrl,
    this.followerCount = 0,
    this.selectedCount,
    this.onForward,
  });

  final String storeName;
  final double opacity;
  final String? imageUrl;
  final int followerCount;
  final int? selectedCount;
  final VoidCallback? onForward;

  static String _followerLabel(int count) {
    final n = count < 0 ? 0 : count;
    if (n == 1) return '1 follower';
    return '$n followers';
  }

  static String _subtitle({
    required int followerCount,
    int? selectedCount,
  }) {
    final followers = _followerLabel(followerCount);
    if (selectedCount == null) return followers;
    final n = selectedCount < 0 ? 0 : selectedCount;
    final selected = n == 1 ? '1 selected' : '$n selected';
    return '$followers · $selected';
  }

  @override
  Widget build(BuildContext context) {
    final selecting = selectedCount != null;
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Row(
        children: [
          StoreProfileLogo(
            size: 28,
            imageUrl: imageUrl,
            storeName: storeName,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headline(
                    fontSize: selecting ? 15 : 16,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                if (selecting)
                  Text(
                    _subtitle(
                      followerCount: followerCount,
                      selectedCount: selectedCount,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.15,
                    ),
                  ),
              ],
            ),
          ),
          if (onForward != null)
            IconButton(
              onPressed: onForward,
              tooltip: 'Import',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(
                width: 36,
                height: 40,
              ),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              icon: WhatsAppForwardIcon(
                color: AppColors.backIcon,
                size: 22,
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.topPad,
    required this.storeName,
    required this.followerCount,
    required this.heroes,
    required this.logoPager,
    required this.logoPage,
    required this.expandT,
    required this.onPageChanged,
  });

  final double topPad;
  final String storeName;
  final int followerCount;
  final List<String> heroes;
  final PageController logoPager;
  final int logoPage;
  final double expandT;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final t = expandT.clamp(0.0, 1.0);
    final hasImages = heroes.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: AppColors.surfaceSecondary),
        if (hasImages)
          // Store photos: edge-to-edge, no radius / inset padding.
          Positioned.fill(
            child: PageView.builder(
              controller: logoPager,
              itemCount: heroes.length,
              onPageChanged: onPageChanged,
              itemBuilder: (context, index) {
                return ProductMediaImage(
                  path: heroes[index],
                  fit: BoxFit.cover,
                  error: ColoredBox(
                    color: AppColors.surfaceSecondary,
                    child: Center(
                      child: StoreProfileLogo(
                        size: 86,
                        storeName: storeName,
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        else
          // Initials only: stay centered in the hero (expanded + collapsing).
          Center(
            child: StoreProfileLogo(
              size: lerpDouble(72, width * 0.42, t)!,
              storeName: storeName,
            ),
          ),
        // Bottom gradient + title (visible when expanded).
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: t < 0.15,
            child: Opacity(
              opacity: t,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppPadding.horizontal,
                    48,
                    AppPadding.horizontal,
                    14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        storeName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.headline(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$followerCount followers',
                        style: AppTextStyles.caption(
                          fontSize: 13,
                          color: AppColors.textOnPrimary.withValues(
                            alpha: 0.85,
                          ),
                        ),
                      ),
                      if (heroes.length > 1) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(heroes.length, (i) {
                            final on = i == logoPage;
                            return Container(
                              width: on ? 14 : 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color:
                                    on
                                        ? AppColors.textOnPrimary
                                        : AppColors.textOnPrimary.withValues(
                                          alpha: 0.35,
                                        ),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            );
                          }),
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
  }
}

double? lerpDouble(num a, num b, double t) => a + (b - a) * t;

/// Frosted strip matching store-profile glass (blur + translucent fill).
class _ChannelGlassBar extends StatelessWidget {
  const _ChannelGlassBar();

  @override
  Widget build(BuildContext context) {
    AppearanceScope.maybeOf(context);
    final night = AppColors.isNight;
    final fill =
        night
            ? AppColors.appBar.withValues(alpha: 0.42)
            : AppColors.surface.withValues(alpha: 0.55);
    // No hard bottom border — a 0.6px rule read as a “separation” on the hero
    // while the bar was fading in/out during collapse.
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: ColoredBox(color: fill, child: const SizedBox.expand()),
      ),
    );
  }
}

class _ActionButtonsRow extends StatelessWidget {
  const _ActionButtonsRow({
    required this.productCount,
    required this.followerCount,
    required this.followingCount,
    this.onFollowers,
    this.onFollowing,
  });

  final int productCount;
  final int followerCount;
  final int followingCount;
  final VoidCallback? onFollowers;
  final VoidCallback? onFollowing;

  static String _formatCount(int n) {
    if (n >= 1000000) {
      final v = n / 1000000;
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}M';
    }
    if (n >= 1000) {
      final v = n / 1000;
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}K';
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            label: 'Products',
            value: _formatCount(productCount),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionTile(
            label: 'Followers',
            value: _formatCount(followerCount),
            onTap: onFollowers,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionTile(
            label: 'Following',
            value: _formatCount(followingCount),
            onTap: onFollowing,
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption(
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    return Material(
      color: AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(14),
      child:
          onTap == null
              ? child
              : InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: child,
              ),
    );
  }
}

class _InviteLinkCard extends StatelessWidget {
  const _InviteLinkCard({
    required this.storeLink,
    required this.onCopy,
    required this.onShare,
  });

  final String storeLink;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final link = storeLink.trim().isEmpty ? 'jewelflow.app' : storeLink.trim();
    return Material(
      color: AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Store link',
                      style: AppTextStyles.caption(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Copy',
              onPressed: onCopy,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              icon: Icon(
                Icons.copy_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
            IconButton(
              tooltip: 'Share on WhatsApp',
              onPressed: onShare,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              icon: Icon(
                Icons.ios_share_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelTabBar extends StatelessWidget {
  const _ChannelTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: TabBar(
        controller: controller,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        labelColor: AppColors.textOnPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: AppTextStyles.caption(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: AppTextStyles.caption(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(text: 'Media'),
          Tab(text: 'Group'),
          Tab(text: 'Gallery'),
        ],
      ),
    );
  }
}

/// Media grid with pointer-tracked pinch (avoids TabBarView / scroll stealing
/// [ScaleGestureRecognizer] in the gesture arena).
class _MediaTab extends StatefulWidget {
  const _MediaTab({
    required this.photos,
    required this.columns,
    required this.pinching,
    required this.onPinchStart,
    required this.onPinchUpdate,
    required this.onPinchEnd,
    required this.onTap,
    this.onLongPress,
    this.photoSelectionMode = false,
    this.selectedPhotoKeys = const {},
  });

  final List<_ChannelPhoto> photos;
  /// Continuous 2…9; cell size follows the fraction for smooth pinch.
  final double columns;
  final bool pinching;
  final ValueChanged<double> onPinchStart;
  final ValueChanged<double> onPinchUpdate;
  final VoidCallback onPinchEnd;
  final void Function(_ChannelPhoto photo, {Rect? sourceRect}) onTap;
  final ValueChanged<_ChannelPhoto>? onLongPress;
  final bool photoSelectionMode;
  final Set<String> selectedPhotoKeys;

  @override
  State<_MediaTab> createState() => _MediaTabState();
}

class _MediaTabState extends State<_MediaTab> {
  final Map<int, Offset> _pointers = <int, Offset>{};
  double? _startDistance;

  double? _fingerDistance() {
    if (_pointers.length < 2) return null;
    final pts = _pointers.values.toList(growable: false);
    return (pts[0] - pts[1]).distance;
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 2 && !widget.pinching) {
      _startDistance = _fingerDistance();
      if (_startDistance != null && _startDistance! >= 12) {
        widget.onPinchStart(widget.columns);
      }
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    if (!widget.pinching || _pointers.length < 2) return;
    final start = _startDistance;
    final now = _fingerDistance();
    if (start == null || now == null || start < 12) return;
    widget.onPinchUpdate(now / start);
  }

  void _onPointerEnd(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (widget.pinching && _pointers.length < 2) {
      _startDistance = null;
      widget.onPinchEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return Center(
        child: Text(
          'No photos yet',
          style: AppTextStyles.bodySecondary(),
        ),
      );
    }
    final cols = widget.columns.clamp(
      _StoreChannelRouteState._minColumns,
      _StoreChannelRouteState._maxColumns,
    );
    final spacing = cols >= 6 ? 1.0 : 2.0;
    // Integer columns avoid NestedScrollView extent thrash; cell size still
    // steps smoothly because we update on every pinch frame via round().
    final crossAxisCount = cols.round().clamp(2, 9);
    final paintRole =
        CatalogResponsiveImage.roleForMediaColumns(crossAxisCount);
    final decodeWidth = CatalogImageCache.cacheWidthForRole(paintRole);
    if (widget.photos.isNotEmpty) {
      CatalogMediaDebug.qualityMediaPaint(
        columns: crossAxisCount,
        role: paintRole,
        sampleUrl: widget.photos.first.urlFor(paintRole),
      );
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: GridView.builder(
          padding: EdgeInsets.zero,
          physics:
              widget.pinching
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: widget.photos.length,
          itemBuilder: (context, index) {
            final photo = widget.photos[index];
            final photoKey = StoreProductGrid.photoKey(
              photo.product.id,
              photo.imageIndex,
            );
            final selected = widget.selectedPhotoKeys.contains(photoKey);
            final paintPath = photo.urlFor(paintRole);
            return Builder(
              builder: (cellContext) {
                return GestureDetector(
                  // Stable identity across pinch column / quality rebuilds.
                  key: ValueKey(photoKey),
                  onTap:
                      widget.pinching
                          ? null
                          : () {
                            Rect? sourceRect;
                            final box = cellContext.findRenderObject();
                            if (box is RenderBox && box.hasSize) {
                              sourceRect =
                                  box.localToGlobal(Offset.zero) & box.size;
                            }
                            widget.onTap(photo, sourceRect: sourceRect);
                          },
                  onLongPress:
                      widget.pinching || widget.onLongPress == null
                          ? null
                          : () => widget.onLongPress!(photo),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ProductMediaImage(
                        path: paintPath,
                        thumbhash: photo.product.thumbhashAt(photo.imageIndex),
                        fit: BoxFit.cover,
                        decodeCacheWidth: decodeWidth,
                        error: ColoredBox(
                          color: AppColors.surfaceSecondary,
                          child: Icon(
                            Icons.diamond_outlined,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                      if (photo.product.isImportDeclinedAt(photo.imageIndex) ||
                          photo.product.isImportPendingAt(photo.imageIndex))
                        Positioned(
                          top: 5,
                          left: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  photo.product.isImportDeclinedAt(
                                        photo.imageIndex,
                                      )
                                      ? AppColors.error.withValues(alpha: 0.92)
                                      : AppColors.warning.withValues(
                                        alpha: 0.92,
                                      ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              photo.product.isImportDeclinedAt(photo.imageIndex)
                                  ? 'Declined'
                                  : 'Pending',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      if (widget.photoSelectionMode)
                        Positioned(
                          top: 5,
                          right: 5,
                          child: TelegramPhotoSelectBadge(selected: selected),
                        ),
                      if (widget.photoSelectionMode)
                        Positioned(
                          top:
                              photo.product.isImportDeclinedAt(
                                        photo.imageIndex,
                                      ) ||
                                      photo.product.isImportPendingAt(
                                        photo.imageIndex,
                                      )
                                  ? 28
                                  : 5,
                          left: 5,
                          right: 28,
                          child: VisitorImportStatusMarks(
                            locked: photo.product.isLockedAt(photo.imageIndex),
                            stock: photo.product.stockStatusAt(photo.imageIndex),
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

class _GroupTab extends StatelessWidget {
  const _GroupTab({
    required this.products,
    required this.onProductTap,
    this.onImageLongPress,
    this.photoSelectionMode = false,
    this.selectedPhotoKeys = const {},
  });

  final List<StoreProduct> products;
  final void Function(
    StoreProduct product,
    int imageIndex, {
    Rect? sourceRect,
  })
  onProductTap;
  final void Function(StoreProduct product, int imageIndex)? onImageLongPress;
  final bool photoSelectionMode;
  final Set<String> selectedPhotoKeys;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Text('No products yet', style: AppTextStyles.bodySecondary()),
      );
    }
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Edge-to-edge tiles — no list insets (fades live on the route Stack).
        StoreProductGrid(
          products: products,
          viewMode: ProductViewMode.group,
          // Photo-level select only — not whole-product owner selection.
          selectionMode: false,
          photoSelectionMode: photoSelectionMode,
          selectedPhotoKeys: selectedPhotoKeys,
          onProductTap: onProductTap,
          onImageLongPress: onImageLongPress,
        ).buildSliver(),
      ],
    );
  }
}

class _GalleryTab extends StatelessWidget {
  const _GalleryTab({
    required this.products,
    required this.onImageTap,
    required this.columns,
    this.onColumnsChanged,
    this.onImageLongPress,
    this.photoSelectionMode = false,
    this.selectedPhotoKeys = const {},
  });

  final List<StoreProduct> products;
  final double columns;
  final ValueChanged<int>? onColumnsChanged;
  final void Function(
    StoreProduct product,
    int imageIndex, {
    Rect? sourceRect,
  })
  onImageTap;
  final void Function(StoreProduct product, int imageIndex)? onImageLongPress;
  final bool photoSelectionMode;
  final Set<String> selectedPhotoKeys;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Text('No photos yet', style: AppTextStyles.bodySecondary()),
      );
    }
    return GalleryPinchHost(
      initialColumns: columns,
      onColumnsChanged: onColumnsChanged,
      builder: (context, cols, pinching) {
        return CustomScrollView(
          physics:
              pinching
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
          slivers: [
            StoreProductGallerySliver(
              products: products,
              columns: cols,
              pinching: pinching,
              photoSelectionMode: photoSelectionMode,
              selectedPhotoKeys: selectedPhotoKeys,
              onImageTap: onImageTap,
              onImageLongPress: onImageLongPress,
            ),
          ],
        );
      },
    );
  }
}
