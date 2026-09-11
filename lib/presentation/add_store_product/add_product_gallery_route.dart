import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/add_store_product/add_store_product_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/primary_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/add_store_product/add_store_product_widgets/gallery_image_tile.dart';

class AddProductGalleryRoute extends StatelessWidget {
  const AddProductGalleryRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AddStoreProductBloc, AddStoreProductState>(
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
            context.read<AddStoreProductBloc>().add(
              const AddStoreProductClearMessage(),
            );
          },
        ),
        BlocListener<AddStoreProductBloc, AddStoreProductState>(
          listenWhen:
              (prev, curr) =>
                  curr.shouldOpenProductForm && !prev.shouldOpenProductForm,
          listener: (context, state) {
            context.read<AddStoreProductBloc>().add(
              const AddStoreProductClearGalleryContinue(),
            );
            final selectedItems =
                state.selectedImageIds
                    .map(
                      (id) => state.galleryItems.firstWhere(
                        (item) => item.id == id,
                        orElse: () => GalleryImageItem.placeholder(0),
                      ),
                    )
                    .toList();
            Navigator.of(context).pushNamed(
              Routes.addProductFormRoute,
              arguments: <String, Object?>{
                'selectedItems': selectedItems,
                'storeId': state.storeId,
              },
            );
          },
        ),
      ],
      child: ScreenWrapper(
        backgroundColor: AppColors.background,
        statusBarIconBrightness: Brightness.dark,
        child: BlocBuilder<AddStoreProductBloc, AddStoreProductState>(
          builder: (context, state) {
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    top: ScreenWrapper.statusBarTop(context) + 8,
                    left: AppPadding.horizontal,
                    right: AppPadding.horizontal,
                    bottom: 8,
                  ),
                  child: Row(
                    children: [
                      AppBackButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Gallery',
                              style: AppTextStyles.label(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: AppColors.textPrimary,
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap:
                            state.isPickingImages
                                ? null
                                : () => context.read<AddStoreProductBloc>().add(
                                  const AddStoreProductPickFromDevicePressed(),
                                ),
                        child: Text(
                          'Import',
                          style: AppTextStyles.body(
                            fontSize: 17,
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: state.galleryItems.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 1.5,
                          mainAxisSpacing: 1.5,
                        ),
                    itemBuilder: (context, index) {
                      final item = state.galleryItems[index];
                      final isSelected = state.selectedImageIds.contains(
                        item.id,
                      );
                      return GalleryImageTile(
                        item: item,
                        isSelected: isSelected,
                        selectionOrder: state.selectionOrderOf(item.id),
                        onTap:
                            () => context.read<AddStoreProductBloc>().add(
                              AddStoreProductGalleryItemToggled(item.id),
                            ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: AppPadding.screen(top: 12, bottom: 24),
                  child: PrimaryButton(
                    label:
                        state.selectedImageIds.isEmpty
                            ? 'Select photos to upload'
                            : 'Continue · ${state.selectedImageIds.length} selected',
                    enabled: state.canContinueFromGallery,
                    isLoading: state.isPickingImages,
                    onPressed:
                        () => context.read<AddStoreProductBloc>().add(
                          const AddStoreProductContinueFromGalleryPressed(),
                        ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
