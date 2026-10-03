import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/store_setup/store_setup_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/webservice/store/store_request.dart';

/// Scrollable preview of picked store photos with delete (+ add when under max).
Future<void> showStoreSetupPhotosPreviewSheet(BuildContext context) {
  final bloc = context.read<StoreSetupBloc>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return BlocProvider.value(
        value: bloc,
        child: const _StoreSetupPhotosPreviewSheet(),
      );
    },
  );
}

class _StoreSetupPhotosPreviewSheet extends StatefulWidget {
  const _StoreSetupPhotosPreviewSheet();

  @override
  State<_StoreSetupPhotosPreviewSheet> createState() =>
      _StoreSetupPhotosPreviewSheetState();
}

class _StoreSetupPhotosPreviewSheetState
    extends State<_StoreSetupPhotosPreviewSheet> {
  late final PageController _pageController;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _clampPage(int length) {
    if (length == 0) {
      _page = 0;
      return;
    }
    if (_page >= length) {
      _page = length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_pageController.hasClients) return;
        _pageController.jumpToPage(_page);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: AppPadding.screen(top: 12, bottom: 20 + bottomInset),
        child: BlocConsumer<StoreSetupBloc, StoreSetupState>(
          listenWhen:
              (prev, curr) => prev.imagePaths.length != curr.imagePaths.length,
          listener: (context, state) {
            _clampPage(state.imagePaths.length);
            if (state.imagePaths.isEmpty && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          builder: (context, state) {
            final paths = state.imagePaths;
            final canAdd =
                paths.length < StoreRequest.maxStoreImages &&
                !state.isPickingImages &&
                !state.isSubmitting;
            final canDelete = paths.isNotEmpty && !state.isSubmitting;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        paths.isEmpty
                            ? 'Store photos'
                            : 'Photos · ${paths.length}/${StoreRequest.maxStoreImages}',
                        style: AppTextStyles.headline(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (canAdd)
                      TextButton(
                        onPressed:
                            () => context.read<StoreSetupBloc>().add(
                              const StoreImagesPickRequested(),
                            ),
                        child: Text(
                          'Add',
                          style: AppTextStyles.body(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ColoredBox(
                      color: AppColors.surfaceSecondary,
                      child:
                          paths.isEmpty
                              ? Center(
                                child: Text(
                                  'No photos yet',
                                  style: AppTextStyles.bodySecondary(),
                                ),
                              )
                              : Stack(
                                fit: StackFit.expand,
                                children: [
                                  PageView.builder(
                                    controller: _pageController,
                                    itemCount: paths.length,
                                    onPageChanged: (index) {
                                      setState(() => _page = index);
                                    },
                                    itemBuilder: (context, index) {
                                      return Image.file(
                                        File(paths[index]),
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  ),
                                  if (canDelete)
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: Material(
                                        color: Colors.black.withValues(
                                          alpha: 0.55,
                                        ),
                                        shape: const CircleBorder(),
                                        child: InkWell(
                                          customBorder: const CircleBorder(),
                                          onTap: () {
                                            final index = _page.clamp(
                                              0,
                                              paths.length - 1,
                                            );
                                            context.read<StoreSetupBloc>().add(
                                              StoreImageRemoved(index),
                                            );
                                          },
                                          child: const SizedBox(
                                            width: 36,
                                            height: 36,
                                            child: Icon(
                                              Icons.delete_outline_rounded,
                                              color: AppColors.textOnPrimary,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (paths.length > 1)
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 12,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          for (var i = 0; i < paths.length; i++)
                                            Container(
                                              width: i == _page ? 8 : 6,
                                              height: i == _page ? 8 : 6,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color:
                                                    i == _page
                                                        ? AppColors
                                                            .textOnPrimary
                                                        : AppColors
                                                            .textOnPrimary
                                                            .withValues(
                                                              alpha: 0.45,
                                                            ),
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
                if (paths.length > 1) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Swipe to see all photos',
                    style: AppTextStyles.caption(),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
