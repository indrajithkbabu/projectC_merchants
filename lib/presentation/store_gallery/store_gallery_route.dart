import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/store_gallery/store_gallery_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/store_gallery/store_gallery_widgets/store_gallery_body.dart';

class StoreGalleryRoute extends StatelessWidget {
  const StoreGalleryRoute({super.key});

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
    final result = await Navigator.of(context).pushNamed(
      Routes.productDetailsRoute,
      arguments: <String, Object?>{
        'product': product,
        'storeName': state.storeName,
        'storeLink': state.storeLink,
        'storeId': state.storeId,
        'isOwnStore': state.isOwnStore,
        'imageIndex': imageIndex,
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
    return ScreenWrapper(
      backgroundColor: AppColors.galleryBackground,
      statusBarIconBrightness: Brightness.light,
      child: BlocBuilder<StoreGalleryBloc, StoreGalleryState>(
        builder: (context, state) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              _popGallery(context, state);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: AppPadding.screen(
                    top: ScreenWrapper.statusBarTop(context),
                    bottom: 8,
                  ),
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
                Expanded(
                  child: StoreGalleryBody(
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
              ],
            ),
          );
        },
      ),
    );
  }
}
