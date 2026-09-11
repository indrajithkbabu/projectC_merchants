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
  const StoreGalleryBody({super.key, required this.onImageTap});

  final void Function(StoreProduct product, int imageIndex) onImageTap;

  @override
  State<StoreGalleryBody> createState() => _StoreGalleryBodyState();
}

class _StoreGalleryBodyState extends State<StoreGalleryBody> {
  double _pinchStartColumns = StoreGalleryState.minColumns.toDouble();

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

        return RawGestureDetector(
          gestures: {
            ScaleGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
                  () => ScaleGestureRecognizer(),
                  (instance) {
                    instance
                      ..onStart = _onScaleStart
                      ..onUpdate = _onScaleUpdate;
                  },
                ),
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              for (var dayIndex = 0; dayIndex < state.sections.length; dayIndex++)
                ..._daySlivers(
                  state.sections[dayIndex],
                  state.crossAxisCount,
                  isLastDay: dayIndex == state.sections.length - 1,
                ),
            ],
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
      if (!day.isSingleProduct) {
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: AppPadding.screen(top: i == 0 ? 0 : 18, bottom: 8),
              child: Text(
                section.product.title,
                style: AppTextStyles.body(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOnPrimary,
                ),
              ),
            ),
          ),
        );
      }

      slivers.add(
        SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 1.5,
            crossAxisSpacing: 1.5,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final path =
                section.imagePaths.isEmpty ? null : section.imagePaths[index];
            return _GalleryTile(
              path: path,
              tone: section.product.toneIndex,
              onTap: () => widget.onImageTap(section.product, index),
            );
          }, childCount: section.tileCount),
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
    if (path == null || path!.isEmpty) {
      return _placeholder();
    }
    if (!ProductImagePaths.isDisplayable(path!)) {
      return _placeholder();
    }
    return ProductMediaImage(path: path!);
  }

  Widget _placeholder() {
    final colors = switch (tone % 4) {
      0 => [
        AppColors.surfaceSecondary,
        AppColors.primary.withValues(alpha: 0.45),
      ],
      1 => [
        AppColors.surfaceSecondary,
        AppColors.primaryDark.withValues(alpha: 0.42),
      ],
      2 => [AppColors.surfaceSecondary, AppColors.accent.withValues(alpha: 0.35)],
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
      child: const Center(
        child: Icon(
          Icons.diamond_outlined,
          size: 18,
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}
