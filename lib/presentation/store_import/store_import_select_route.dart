import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/store_import/store_import_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/primary_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/store_import/store_import_pending_route.dart';

class StoreImportSelectRoute extends StatelessWidget {
  const StoreImportSelectRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<StoreImportBloc, StoreImportState>(
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
            context.read<StoreImportBloc>().add(
              const StoreImportClearMessage(),
            );
          },
        ),
        BlocListener<StoreImportBloc, StoreImportState>(
          listenWhen: (prev, curr) => curr.requestSent && !prev.requestSent,
          listener: (context, state) {
            final bloc = context.read<StoreImportBloc>();
            context.read<StoreImportBloc>().add(
              const StoreImportClearRequestSent(),
            );
            Navigator.of(context).push(
              CupertinoPageRoute<void>(
                settings: const RouteSettings(
                  name: Routes.storeImportPendingRoute,
                ),
                builder:
                    (_) => BlocProvider.value(
                      value: bloc,
                      child: const StoreImportPendingRoute(),
                    ),
              ),
            );
          },
        ),
      ],
      child: ScreenWrapper(
        backgroundColor: AppColors.background,
        statusBarIconBrightness: Brightness.dark,
        child: BlocBuilder<StoreImportBloc, StoreImportState>(
          builder: (context, state) {
            final store = state.sourceStore;
            return Column(
              children: [
                Padding(
                  padding: AppPadding.screen(
                    top: ScreenWrapper.statusBarTop(context),
                    bottom: 8,
                  ),
                  child: Row(
                    children: [
                      AppBackButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(store.avatarColor),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            store.initials,
                            style: AppTextStyles.label(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textOnPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              store.name,
                              style: AppTextStyles.body(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              store.storeLink,
                              style: AppTextStyles.caption(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  margin: AppPadding.screenHorizontal,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.download_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Select products to request an import. On approval they sync into your store — with the same photos, titles and tags.',
                          style: AppTextStyles.caption(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child:
                      state.isLoadingTargets
                          ? const Center(child: CircularProgressIndicator())
                          : GridView.builder(
                            padding: AppPadding.screen(bottom: 8),
                            itemCount: store.products.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 0.86,
                                ),
                            itemBuilder: (context, index) {
                              final product = store.products[index];
                              final selected = state.selectedIds.contains(
                                product.id,
                              );
                              final availability =
                                  state.listingAvailability[product.id];
                              return _ImportProductTile(
                                product: product,
                                selected: selected,
                                availability: availability,
                                onTap:
                                    () => context.read<StoreImportBloc>().add(
                                      StoreImportProductToggled(product.id),
                                    ),
                              );
                            },
                          ),
                ),
                if (state.needsDestinationPicker)
                  Padding(
                    padding: AppPadding.screen(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import into',
                          style: AppTextStyles.label(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final target in state.requestableTargets)
                              ChoiceChip(
                                label: Text(target.name),
                                selected:
                                    state.selectedDestinationId == target.id,
                                onSelected: (_) {
                                  context.read<StoreImportBloc>().add(
                                    StoreImportDestinationSelected(target.id),
                                  );
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: AppPadding.screen(top: 8, bottom: 24),
                  child: PrimaryButton(
                    label: 'Request import · ${state.selectedCount}',
                    enabled: state.canRequestImport,
                    isLoading: state.isSubmitting,
                    onPressed:
                        () => context.read<StoreImportBloc>().add(
                          const StoreImportRequestPressed(),
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

class _ImportProductTile extends StatelessWidget {
  const _ImportProductTile({
    required this.product,
    required this.selected,
    required this.onTap,
    this.availability,
  });

  final StoreProduct product;
  final bool selected;
  final VoidCallback onTap;
  final ListingImportAvailability? availability;

  bool get _blocked =>
      availability == ListingImportAvailability.alreadyAdded ||
      availability == ListingImportAvailability.pending;

  String? get _statusLabel => switch (availability) {
    ListingImportAvailability.alreadyAdded => 'Added',
    ListingImportAvailability.pending => 'Pending',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final imagePath = product.primaryImagePath;
    final hasImage =
        imagePath != null && ProductImagePaths.isDisplayable(imagePath);
    final gradient = switch (product.toneIndex % 4) {
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

    return GestureDetector(
      onTap: _blocked ? null : onTap,
      child: Opacity(
        opacity: _blocked ? 0.55 : 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                ),
              ),
              if (hasImage) ProductMediaImage(path: imagePath),
              if (hasImage)
                ColoredBox(color: Colors.black.withValues(alpha: 0.18)),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Center(
                        child:
                            hasImage
                                ? null
                                : const Icon(
                                  Icons.diamond_outlined,
                                  size: 34,
                                  color: AppColors.textOnPrimary,
                                ),
                      ),
                    ),
                    Text(
                      product.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusLabel ?? product.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption(
                        fontSize: 13,
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child:
                    _blocked
                        ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _statusLabel ?? '',
                            style: AppTextStyles.caption(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textOnPrimary,
                            ),
                          ),
                        )
                        : Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                selected
                                    ? AppColors.primary
                                    : AppColors.background,
                            border: Border.all(
                              color:
                                  selected
                                      ? AppColors.primary
                                      : AppColors.border,
                              width: 1.5,
                            ),
                          ),
                          child:
                              selected
                                  ? const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: AppColors.textOnPrimary,
                                  )
                                  : null,
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
