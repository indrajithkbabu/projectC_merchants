import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/product_details_feed_item.dart';
import 'package:project_c/models/product_view_mode.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_product_gallery_sliver.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_product_grid.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_profile_header_card.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_visitor_follow_bar.dart';

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
    required this.path,
  });

  final StoreProduct product;
  final int imageIndex;
  final String path;
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
  /// Decode-warm media into [ImageCache] once per route instance.
  bool _mediaWarmed = false;

  List<_ChannelPhoto> get _allPhotos {
    final out = <_ChannelPhoto>[];
    for (final product in widget.products) {
      final paths = ProductImagePaths.displayable(product.imagePaths);
      if (paths.isEmpty) continue;
      for (var i = 0; i < paths.length; i++) {
        out.add(
          _ChannelPhoto(product: product, imageIndex: i, path: paths[i]),
        );
      }
    }
    return out;
  }

  /// Store logos only — never fall back to product photos.
  List<String> get _heroImages =>
      widget.imageUrls
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);

  @override
  void initState() {
    super.initState();
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_mediaWarmed) return;
    _mediaWarmed = true;
    final mediaUrls = [
      for (final photo in _allPhotos) photo.path,
    ];
    // Disk for the whole catalog (1000s OK). Decode only the first viewport.
    // ignore: unawaited_futures
    CatalogImageCache.precacheUrls([
      ..._heroImages,
      ...mediaUrls,
    ]);
    final cols = _mediaColumns.round().clamp(2, 9);
    // ignore: unawaited_futures
    CatalogImageCache.warmWindow(
      urls: mediaUrls,
      firstIndex: 0,
      lastIndex: cols * 12 - 1,
      cacheWidth: CatalogImageCache.gridCacheWidth(),
    );
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

  Future<void> _shareStore() async {
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

  void _stubAction(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label coming soon')),
    );
  }

  Future<void> _openPhoto(_ChannelPhoto photo) async {
    final feed =
        _allPhotos
            .map(
              (p) => ProductDetailsFeedItem(
                product: p.product,
                imageIndex: p.imageIndex,
                path: p.path,
              ),
            )
            .toList(growable: false);
    final index = feed.indexWhere(
      (e) =>
          e.product.id == photo.product.id && e.imageIndex == photo.imageIndex,
    );
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
  }

  void _onPinchEnd() {
    if (!_pinching) return;
    final from = _mediaColumns;
    final to =
        from.round().clamp(_minColumns.toInt(), _maxColumns.toInt()).toDouble();
    setState(() => _pinching = false);
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

    return ScreenWrapper(
      backgroundColor: AppColors.background,
      child: NestedScrollView(
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
              backgroundColor: AppColors.background,
              surfaceTintColor: Colors.transparent,
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
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: ValueListenableBuilder<double>(
                        valueListenable: _expandT,
                        builder: (context, expandT, _) {
                          final show =
                              1.0 -
                              ((expandT - 0.12) / 0.55).clamp(0.0, 1.0);
                          return _CollapsedTitle(
                            storeName: widget.storeName,
                            imageUrl: logoUrl,
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
                  return FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.blurBackground,
                    ],
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
                      followerCount: widget.followerCount,
                      followingCount: widget.followingCount,
                      onFollowers: () => _openFollowers('followers'),
                      onFollowing: () => _openFollowers('following'),
                      onShare: _shareStore,
                      onMute: () => _stubAction('Mute'),
                      onReport: () => _stubAction('Report'),
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
                      onCopy: _shareStore,
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
              onPinchStart: _onPinchStart,
              onPinchUpdate: _onPinchUpdate,
              onPinchEnd: _onPinchEnd,
              onTap: _openPhoto,
            ),
            _GroupTab(
              products: widget.products,
              storeId: widget.storeId,
              storeName: widget.storeName,
              storeLink: widget.storeLink,
              isOwnStore: widget.isOwnStore,
            ),
            _GalleryTab(
              products: widget.products,
              storeId: widget.storeId,
              storeName: widget.storeName,
              storeLink: widget.storeLink,
              isOwnStore: widget.isOwnStore,
            ),
          ],
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
  });

  final String storeName;
  final double opacity;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
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
            child: Text(
              storeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.headline(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
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

class _ActionButtonsRow extends StatelessWidget {
  const _ActionButtonsRow({
    required this.followerCount,
    required this.followingCount,
    required this.onFollowers,
    required this.onFollowing,
    required this.onShare,
    required this.onMute,
    required this.onReport,
  });

  final int followerCount;
  final int followingCount;
  final VoidCallback onFollowers;
  final VoidCallback onFollowing;
  final VoidCallback onShare;
  final VoidCallback onMute;
  final VoidCallback onReport;

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
            icon: Icons.people_alt_outlined,
            label: 'Followers',
            value: _formatCount(followerCount),
            onTap: onFollowers,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _ActionTile(
            icon: Icons.person_outline_rounded,
            label: 'Following',
            value: _formatCount(followingCount),
            onTap: onFollowing,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _ActionTile(
            icon: Icons.ios_share_rounded,
            label: 'Share',
            onTap: onShare,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _ActionTile(
            icon: Icons.notifications_off_outlined,
            label: 'Mute',
            onTap: onMute,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _ActionTile(
            icon: Icons.flag_outlined,
            label: 'Report',
            onTap: onReport,
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          child: Column(
            children: [
              if (value != null)
                Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                Icon(icon, color: AppColors.primary, size: 20),
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
        ),
      ),
    );
  }
}

class _InviteLinkCard extends StatelessWidget {
  const _InviteLinkCard({required this.storeLink, required this.onCopy});

  final String storeLink;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final link = storeLink.trim().isEmpty ? 'jewelflow.app' : storeLink.trim();
    return Material(
      color: AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onCopy,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
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
              Icon(
                Icons.copy_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
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
  });

  final List<_ChannelPhoto> photos;
  /// Continuous 2…9; cell size follows the fraction for smooth pinch.
  final double columns;
  final bool pinching;
  final ValueChanged<double> onPinchStart;
  final ValueChanged<double> onPinchUpdate;
  final VoidCallback onPinchEnd;
  final ValueChanged<_ChannelPhoto> onTap;

  @override
  State<_MediaTab> createState() => _MediaTabState();
}

class _MediaTabState extends State<_MediaTab> {
  final Map<int, Offset> _pointers = <int, Offset>{};
  double? _startDistance;
  int _lastWarmKey = -1;
  DateTime? _lastWarmAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _warmViewport();
    });
  }

  @override
  void didUpdateWidget(covariant _MediaTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final colsChanged =
        oldWidget.columns.round() != widget.columns.round();
    final photosChanged = oldWidget.photos.length != widget.photos.length;
    if (colsChanged || photosChanged) {
      _lastWarmKey = -1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _warmViewport();
      });
    }
  }

  List<String> get _urls => [
    for (final photo in widget.photos) photo.path,
  ];

  void _warmViewport([ScrollMetrics? metrics]) {
    if (widget.photos.isEmpty) return;
    final cols = widget.columns.round().clamp(2, 9);
    final width = MediaQuery.sizeOf(context).width;
    final spacing = cols >= 6 ? 1.0 : 2.0;
    final urls = _urls;

    if (metrics == null) {
      final key = cols * 100000;
      if (key == _lastWarmKey) return;
      _lastWarmKey = key;
      // ignore: unawaited_futures
      CatalogImageCache.warmWindow(
        urls: urls,
        firstIndex: 0,
        lastIndex: cols * 12 - 1,
        cacheWidth: CatalogImageCache.gridCacheWidth(),
      );
      return;
    }

    final cell =
        (width - spacing * (cols - 1)).clamp(1.0, width) / cols;
    final stride = cell + spacing;
    final firstRow =
        ((metrics.pixels - spacing) / stride).floor().clamp(0, 1 << 20);
    final key = cols * 100000 + firstRow;
    final now = DateTime.now();
    final lastAt = _lastWarmAt;
    if (key == _lastWarmKey &&
        lastAt != null &&
        now.difference(lastAt).inMilliseconds < 80) {
      return;
    }
    _lastWarmKey = key;
    _lastWarmAt = now;
    // ignore: unawaited_futures
    CatalogImageCache.warmGridWindow(
      urls: urls,
      metrics: metrics,
      crossAxisCount: cols,
      viewportWidth: width,
      spacing: spacing,
      cacheWidth: CatalogImageCache.gridCacheWidth(),
    );
  }

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
      // Pinch remounts cells — re-warm current viewport at new column count.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _lastWarmKey = -1;
        _warmViewport();
      });
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

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (widget.pinching) return true;
          if (notification is ScrollUpdateNotification ||
              notification is ScrollEndNotification) {
            _warmViewport(notification.metrics);
          }
          return false;
        },
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
            return GestureDetector(
              // Stable identity across pinch column rebuilds.
              key: ValueKey(photo.path),
              onTap: widget.pinching ? null : () => widget.onTap(photo),
              child: ProductMediaImage(
                path: photo.path,
                fit: BoxFit.cover,
                error: ColoredBox(
                  color: AppColors.surfaceSecondary,
                  child: Icon(
                    Icons.diamond_outlined,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GroupTab extends StatelessWidget {
  const _GroupTab({
    required this.products,
    required this.storeId,
    required this.storeName,
    required this.storeLink,
    required this.isOwnStore,
  });

  final List<StoreProduct> products;
  final String storeId;
  final String storeName;
  final String storeLink;
  final bool isOwnStore;

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
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          sliver: StoreProductGrid(
            products: products,
            viewMode: ProductViewMode.group,
            onProductTap: (product, _) {
              Navigator.of(context).pushNamed(
                Routes.collectionBrowseRoute,
                arguments: <String, Object?>{
                  'product': product,
                  'storeId': storeId,
                  'storeName': storeName,
                  'storeLink': storeLink,
                  'isOwnStore': isOwnStore,
                },
              );
            },
          ).buildSliver(),
        ),
      ],
    );
  }
}

class _GalleryTab extends StatelessWidget {
  const _GalleryTab({
    required this.products,
    required this.storeId,
    required this.storeName,
    required this.storeLink,
    required this.isOwnStore,
  });

  final List<StoreProduct> products;
  final String storeId;
  final String storeName;
  final String storeLink;
  final bool isOwnStore;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Text('No photos yet', style: AppTextStyles.bodySecondary()),
      );
    }
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        StoreProductGallerySliver(
          products: products,
          onImageTap: (product, imageIndex) {
            Navigator.of(context).pushNamed(
              Routes.productDetailsRoute,
              arguments: <String, Object?>{
                'product': product,
                'storeId': storeId,
                'storeName': storeName,
                'storeLink': storeLink,
                'isOwnStore': isOwnStore,
                'imageIndex': imageIndex,
              },
            );
          },
        ),
      ],
    );
  }
}
