import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/product_details/product_details_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';

class ProductDetailsRoute extends StatefulWidget {
  const ProductDetailsRoute({super.key});

  @override
  State<ProductDetailsRoute> createState() => _ProductDetailsRouteState();
}

class _ProductDetailsRouteState extends State<ProductDetailsRoute> {
  late final PageController _pageController;
  late final ScrollController _thumbController;

  int _currentIndex = 0;
  bool _showInfo = false;
  Map<String, Object?>? _popResult;

  @override
  void initState() {
    super.initState();
    final initialIndex =
        context.read<ProductDetailsBloc>().state.initialImageIndex;
    _currentIndex = initialIndex;
    _pageController = PageController(initialPage: initialIndex);
    _thumbController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollThumbTo(_currentIndex);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _scrollThumbTo(index);
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

  List<String> _editTags(ProductDetailsState state) {
    final raw = state.apiTag.trim();
    if (raw.isEmpty) return const [];
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

  void _popDetails() {
    Navigator.of(context).pop(_popResult);
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
      ProductDetailsDeletePressed(imageIndex: _currentIndex),
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
          listenWhen: (prev, curr) => curr.shouldOpenEdit && !prev.shouldOpenEdit,
          listener: (context, state) => _openEdit(state),
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
            final last =
                state.product.imagePaths.isEmpty
                    ? 0
                    : state.product.imagePaths.length - 1;
            final nextIndex = _currentIndex > last ? last : _currentIndex;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (_pageController.hasClients) {
                _pageController.jumpToPage(nextIndex);
              }
              if (nextIndex != _currentIndex) {
                setState(() => _currentIndex = nextIndex);
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
            final pageCount = imagePaths.isEmpty ? 1 : imagePaths.length;

            return Stack(
              children: [
                Positioned.fill(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: pageCount,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, index) {
                      if (imagePaths.isEmpty) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _showInfo = !_showInfo),
                          child: _ImagePlaceholder(tone: product.toneIndex),
                        );
                      }

                      final path = imagePaths[index];
                      if (!ProductImagePaths.isDisplayable(path)) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _showInfo = !_showInfo),
                          child: _ImagePlaceholder(tone: product.toneIndex),
                        );
                      }

                      return GestureDetector(
                        onTap: () => setState(() => _showInfo = !_showInfo),
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: Center(
                            child: ProductMediaImage(
                              path: path,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
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
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          state.storeName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.body(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textOnPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          state.storeLink,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.caption(
                                            color: AppColors.textOnPrimary
                                                .withValues(alpha: 0.88),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (state.isDeleting)
                                    const Padding(
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
                                  _RoundIconButton(
                                    icon: Icons.share_rounded,
                                    onTap:
                                        () => context
                                            .read<ProductDetailsBloc>()
                                            .add(
                                              const ProductDetailsSharePressed(),
                                            ),
                                  ),
                                  if (state.canEdit) ...[
                                    const SizedBox(width: 8),
                                    _RoundIconButton(
                                      icon: Icons.edit_rounded,
                                      onTap:
                                          () => context
                                              .read<ProductDetailsBloc>()
                                              .add(
                                                const ProductDetailsEditPressed(),
                                              ),
                                    ),
                                  ],
                                  if (state.canEdit) ...[
                                    const SizedBox(width: 8),
                                    _RoundIconButton(
                                      icon: Icons.delete_outline_rounded,
                                      onTap:
                                          state.isDeleting
                                              ? null
                                              : () =>
                                                  _confirmDeletePhoto(state),
                                    ),
                                  ],
                                ],
                              ),
                              if (product.title.trim().isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Text(
                                  product.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.title(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textOnPrimary,
                                  ),
                                ),
                              ],
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
                                showSharedMetaHint:
                                    state.canEdit &&
                                    product.imagePaths.length > 1,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 72,
                                child: Center(
                                  child: ListView.separated(
                                    controller: _thumbController,
                                    shrinkWrap: true,
                                    scrollDirection: Axis.horizontal,
                                    itemCount: pageCount,
                                    separatorBuilder:
                                        (_, __) => const SizedBox(width: 8),
                                    itemBuilder: (context, index) {
                                      final isActive = index == _currentIndex;
                                      final thumbPath =
                                          imagePaths.isEmpty
                                              ? null
                                              : imagePaths[index];
                                      return GestureDetector(
                                        onTap: () {
                                          _pageController.animateToPage(
                                            index,
                                            duration: const Duration(
                                              milliseconds: 220,
                                            ),
                                            curve: Curves.easeOut,
                                          );
                                        },
                                        child: Container(
                                          width: 64,
                                          clipBehavior: Clip.antiAlias,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color:
                                                  isActive
                                                      ? AppColors.primary
                                                      : Colors.white.withValues(
                                                        alpha: 0.28,
                                                      ),
                                              width: isActive ? 2 : 1,
                                            ),
                                          ),
                                          child:
                                              thumbPath == null
                                                  ? _ImagePlaceholder(
                                                    tone: product.toneIndex,
                                                  )
                                                  : _ThumbnailImage(
                                                    path: thumbPath,
                                                  ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
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

class _ProductMetaPanel extends StatelessWidget {
  const _ProductMetaPanel({
    required this.product,
    this.showSharedMetaHint = false,
  });

  final StoreProduct product;
  final bool showSharedMetaHint;

  @override
  Widget build(BuildContext context) {
    final hasTags = product.tags.isNotEmpty;
    final hasDescription = product.description.trim().isNotEmpty;
    if (!hasTags && !hasDescription && !showSharedMetaHint) {
      return const SizedBox.shrink();
    }

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
          if (hasTags)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in product.tags) _TagChip(label: tag),
              ],
            ),
          if (hasDescription) ...[
            if (hasTags) const SizedBox(height: 10),
            Text(
              product.description,
              style: AppTextStyles.body(
                fontSize: 14,
                color: AppColors.textOnPrimary.withValues(alpha: 0.92),
              ),
            ),
          ],
          if (showSharedMetaHint) ...[
            if (hasTags || hasDescription) const SizedBox(height: 10),
            Text(
              'Title, tags, and description are shared by every photo in this product.',
              style: AppTextStyles.caption(
                color: AppColors.textOnPrimary.withValues(alpha: 0.78),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final display = label.startsWith('#') ? label : '#$label';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Text(
        display,
        style: AppTextStyles.caption(
          fontWeight: FontWeight.w600,
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}

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

class _ThumbnailImage extends StatelessWidget {
  const _ThumbnailImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return ProductMediaImage(path: path);
  }
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
      child: const Center(
        child: Icon(
          Icons.diamond_outlined,
          size: 48,
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}
