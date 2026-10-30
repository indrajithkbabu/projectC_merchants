import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/store_gallery/store_gallery_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/catalog_media_debug.dart';
import 'package:project_c/helper/catalog_responsive_image.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/catalog_image_edge_fades.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/store_gallery/store_gallery_widgets/store_gallery_body.dart';

class StoreGalleryRoute extends StatelessWidget {
  const StoreGalleryRoute({super.key, this.focusProductId});

  /// When set (e.g. from search → store group), scroll to and highlight that listing.
  final String? focusProductId;

  void _popGallery(BuildContext context, StoreGalleryState state) {
    Navigator.of(context).pop(<String, Object?>{
      'products': state.products,
    });
  }

  Future<void> _openProductDetails(
    BuildContext context,
    StoreGalleryState state,
    StoreProduct product,
    int imageIndex,
  ) async {
    final feed = state.buildPhotoFeed();
    final feedIndex = state.feedIndexFor(
      productId: product.id,
      imageIndex: imageIndex,
    );
    final paintRole = CatalogResponsiveImage.roleForMediaColumns(
      state.crossAxisCount,
    );
    final paintPath = product.urlForRole(imageIndex, paintRole);
    final masterPath = product.urlForRole(imageIndex, CatalogImageRole.zoom);
    CatalogMediaDebug.qualityTapOpen(
      from: 'store_gallery cols=${state.crossAxisCount}',
      role: CatalogImageRole.zoom,
      url: masterPath,
      paintedUrl: paintPath,
    );
    final result = await Navigator.of(context).pushNamed(
      Routes.productDetailsRoute,
      arguments: <String, Object?>{
        'product': product,
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
      context.read<StoreGalleryBloc>().add(
        StoreGalleryProductDeleted(productId),
      );
      return;
    }

    if (payload['updated'] == true) {
      context.read<StoreGalleryBloc>().add(
        StoreGalleryProductUpdated(
          StoreProduct.fromMap(payload),
          replacedListingId: payload['replacedListingId'] as String?,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = ScreenWrapper.statusBarTop(context);
    const toolbarH = 52.0;
    final headerExtent = topPad + toolbarH;

    return ScreenWrapper(
      backgroundColor: AppColors.galleryBackground,
      statusBarIconBrightness: Brightness.light,
      extendBodyBehindBottom: true,
      child: BlocBuilder<StoreGalleryBloc, StoreGalleryState>(
        builder: (context, state) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              _popGallery(context, state);
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: StoreGalleryBody(
                    focusProductId: focusProductId,
                    topInset: headerExtent,
                    onImageTap: (product, imageIndex) {
                      _openProductDetails(
                        context,
                        state,
                        product,
                        imageIndex,
                      );
                    },
                  ),
                ),
                const CatalogImageEdgeFades(),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: EdgeInsets.only(top: topPad),
                    child: SizedBox(
                      height: toolbarH,
                      child: Padding(
                        padding: AppPadding.screenHorizontal,
                        child: Row(
                          children: [
                            AppBackButton(
                              color: AppColors.textOnPrimary,
                              onPressed: () => _popGallery(context, state),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Photos',
                                style: AppTextStyles.title(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textOnPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
