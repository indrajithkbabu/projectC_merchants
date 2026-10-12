import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/store_gallery/store_gallery_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/store_product.dart';

class StoreGalleryBody extends StatefulWidget {
  const StoreGalleryBody({
    super.key,
    required this.onImageTap,
    this.focusProductId,
  });

  final void Function(StoreProduct product, int imageIndex) onImageTap;
  final String? focusProductId;

  @override
  State<StoreGalleryBody> createState() => _StoreGalleryBodyState();
}

class _StoreGalleryBodyState extends State<StoreGalleryBody> {
  double _pinchStartColumns = StoreGalleryState.minColumns.toDouble();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _productKeys = {};
  bool _didScrollToFocus = false;
  int? _lastDiskWarmCount;
  int _lastDecodeKey = -1;
  DateTime? _lastDecodeAt;
  List<String> _flatUrls = const [];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<String> _collectUrls(StoreGalleryState state) {
    return [
      for (final day in state.sections)
        for (final section in day.products)
          ...ProductImagePaths.displayable(section.imagePaths),
    ];
  }

  void _warmDisk(StoreGalleryState state) {
    final urls = _collectUrls(state);
    _flatUrls = urls;
    if (_lastDiskWarmCount == urls.length) return;
    _lastDiskWarmCount = urls.length;
    // Disk only — decode is viewport-scoped via scroll.
    // ignore: unawaited_futures
    CatalogImageCache.precacheUrls(urls);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _warmDecodeWindow();
    });
  }

  void _warmDecodeWindow([ScrollMetrics? metrics]) {
    if (_flatUrls.isEmpty) return;
    final now = DateTime.now();
    final lastAt = _lastDecodeAt;
    final m = metrics ??
        (_scrollController.hasClients ? _scrollController.position : null);
    final pixels = m?.pixels.round() ?? 0;
    final key = pixels ~/ 120;
    if (key == _lastDecodeKey &&
        lastAt != null &&
        now.difference(lastAt).inMilliseconds < 80) {
      return;
    }
    _lastDecodeKey = key;
    _lastDecodeAt = now;
    if (m == null) {
      // ignore: unawaited_futures
      CatalogImageCache.warmWindow(
        urls: _flatUrls,
        firstIndex: 0,
        lastIndex: CatalogImageCache.defaultMaxDecode - 1,
        cacheWidth: CatalogImageCache.gridCacheWidth(),
      );
      return;
    }
    // ignore: unawaited_futures
    CatalogImageCache.warmAroundScroll(
      urls: _flatUrls,
      metrics: m,
      cacheWidth: CatalogImageCache.gridCacheWidth(),
    );
  }

  GlobalKey _keyFor(String productId) {
    return _productKeys.putIfAbsent(productId, GlobalKey.new);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _pinchStartColumns =
        context.read<StoreGalleryBloc>().state.crossAxisCount.toDouble();
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2) return;
    // Pinch in (scale < 1) zooms out → more columns. Pinch out zooms in → fewer.
    final width = MediaQuery.sizeOf(context).width;
    final maxColumns = (width / 20).floor();
    final next = (_pinchStartColumns / details.scale).round().clamp(
      StoreGalleryState.minColumns,
      maxColumns < StoreGalleryState.minColumns
          ? StoreGalleryState.minColumns
          : maxColumns,
    );
    final bloc = context.read<StoreGalleryBloc>();
    if (next != bloc.state.crossAxisCount) {
      bloc.add(StoreGalleryColumnsChanged(next));
    }
  }

  void _scheduleScrollToFocus() {
    final focusId = widget.focusProductId?.trim() ?? '';
    if (focusId.isEmpty || _didScrollToFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didScrollToFocus) return;
      final key = _productKeys[focusId];
      final ctx = key?.currentContext;
      if (ctx == null) return;
      _didScrollToFocus = true;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        alignment: 0.12,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StoreGalleryBloc, StoreGalleryState>(
      builder: (context, state) {
        if (state.sections.isEmpty) {
          return Center(
            child: Text(
              'No photos yet',
              style: AppTextStyles.bodySecondary(color: AppColors.textOnPrimary),
            ),
          );
        }

        _warmDisk(state);
        _scheduleScrollToFocus();

        return RawGestureDetector(
          gestures: {
            ScaleGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
                  () => ScaleGestureRecognizer(),
                  (instance) {
                    instance
                      ..onStart = _onScaleStart
                      ..onUpdate = (details) {
                        final before =
                            context
                                .read<StoreGalleryBloc>()
                                .state
                                .crossAxisCount;
                        _onScaleUpdate(details);
                        final after =
                            context
                                .read<StoreGalleryBloc>()
                                .state
                                .crossAxisCount;
                        if (after != before) {
                          _lastDecodeKey = -1;
                          _warmDecodeWindow();
                        }
                      };
                  },
                ),
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification ||
                  notification is ScrollEndNotification) {
                _warmDecodeWindow(notification.metrics);
              }
              return false;
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                for (var dayIndex = 0;
                    dayIndex < state.sections.length;
                    dayIndex++)
                  ..._daySlivers(
                    state.sections[dayIndex],
                    state.crossAxisCount,
                    isLastDay: dayIndex == state.sections.length - 1,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _daySlivers(
    StoreGalleryDaySection day,
    int columns, {
    required bool isLastDay,
  }) {
    final focusId = widget.focusProductId?.trim() ?? '';
    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: AppPadding.screen(top: 14, bottom: 8),
          child: Text(
            day.isSingleProduct
                ? '${day.label}  |  ${day.products.first.product.title}'
                : day.label,
            style: AppTextStyles.headline(
              fontSize: 18,
              color: AppColors.textOnPrimary,
            ),
          ),
        ),
      ),
    ];

    for (var i = 0; i < day.products.length; i++) {
      final section = day.products[i];
      final productId = section.product.id;
      final isFocused = focusId.isNotEmpty && productId == focusId;
      final sectionKey = _keyFor(productId);

      if (!day.isSingleProduct) {
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              key: sectionKey,
              padding: AppPadding.screen(top: i == 0 ? 0 : 18, bottom: 8),
              child: Text(
                section.product.title,
                style: AppTextStyles.body(
                  fontWeight: FontWeight.w600,
                  color:
                      isFocused
                          ? AppColors.primary
                          : AppColors.textOnPrimary,
                ),
              ),
            ),
          ),
        );
      }

      slivers.add(
        SliverToBoxAdapter(
          child: KeyedSubtree(
            key: day.isSingleProduct ? sectionKey : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border:
                    isFocused
                        ? Border.all(color: AppColors.primary, width: 2)
                        : null,
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 1.5,
                  crossAxisSpacing: 1.5,
                ),
                itemCount: section.tileCount,
                itemBuilder: (context, index) {
                  final path =
                      section.imagePaths.isEmpty
                          ? null
                          : section.imagePaths[index];
                  return _GalleryTile(
                    path: path,
                    tone: section.product.toneIndex,
                    onTap: () => widget.onImageTap(section.product, index),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    if (!isLastDay) {
      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 8)));
    } else {
      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));
    }

    return slivers;
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.path,
    required this.tone,
    required this.onTap,
  });

  final String? path;
  final int tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ColoredBox(
        color: AppColors.surfaceSecondary,
        child: _tileImage(),
      ),
    );
  }

  Widget _tileImage() {
    final value = path?.trim() ?? '';
    if (value.isEmpty || !ProductImagePaths.isDisplayable(value)) {
      return ColoredBox(
        color: AppColors.surfaceSecondary,
        child: Icon(
          Icons.diamond_outlined,
          color: AppColors.textSecondary.withValues(alpha: 0.5),
        ),
      );
    }
    return ProductMediaImage(path: value, fit: BoxFit.cover);
  }
}
