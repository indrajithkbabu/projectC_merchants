import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:project_c/helper/catalog_media_debug.dart';
import 'package:project_c/helper/catalog_responsive_image.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/appearance_scope.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/models/catalog/import_models.dart';
import 'package:project_c/models/product_view_mode.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/product_image_collage.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_product_grid_shimmer.dart';

class StoreProductGrid extends StatelessWidget {
  const StoreProductGrid({
    super.key,
    required this.products,
    required this.onProductTap,
    this.onProductLongPress,
    this.onImageLongPress,
    this.viewMode = ProductViewMode.group,
    this.selectionMode = false,
    this.photoSelectionMode = false,
    this.selectedIds = const {},
    this.selectedPhotoKeys = const {},
    this.deletingProductIds = const {},
    this.listingAvailability = const {},
    this.focusProductId,
    this.focusKey,
    this.onRemoveSourceDeleted,
  });

  final List<StoreProduct> products;

  /// Own-store ghost shelf: remove a copy whose locked source was deleted.
  final ValueChanged<StoreProduct>? onRemoveSourceDeleted;

  /// Second arg is the tapped collage photo index (0 when the card has no
  /// images or the tap was outside a collage cell).
  /// [sourceRect] is the tapped cell in global coords (Telegram photo open).
  final void Function(
    StoreProduct product,
    int imageIndex, {
    Rect? sourceRect,
  })
  onProductTap;
  final ValueChanged<StoreProduct>? onProductLongPress;

  /// Visitor multi-select: long-press a collage photo.
  final void Function(StoreProduct product, int imageIndex)? onImageLongPress;
  final ProductViewMode viewMode;

  /// Own-store whole-product selection.
  final bool selectionMode;

  /// Visitor photo multi-select (Telegram checks on collage cells).
  final bool photoSelectionMode;
  final Set<String> selectedIds;

  /// Keys `"productId|imageIndex"` for visitor photo selection.
  final Set<String> selectedPhotoKeys;
  final Set<String> deletingProductIds;
  final Map<String, ListingImportAvailability> listingAvailability;

  /// Listing id to draw a primary border around (e.g. search → store chevron).
  final String? focusProductId;

  /// Optional key attached to the focused card for scroll-into-view.
  final GlobalKey? focusKey;

  static String photoKey(String productId, int imageIndex) =>
      '$productId|$imageIndex';

  static const groupDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    childAspectRatio: 0.86,
  );

  static const singleDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 1,
    crossAxisSpacing: 10,
    mainAxisSpacing: 12,
    // width/height — lower = taller portrait card (full-width rectangle).
    childAspectRatio: 0.8,
  );

  SliverGridDelegate get _delegate =>
      viewMode == ProductViewMode.single ? singleDelegate : groupDelegate;

  Widget _card(StoreProduct product) {
    // Visitors never see source-deleted / declined copies (owner-only).
    final shelfGhost =
        product.isSourceDeleted || product.isImportDeclined;
    if (shelfGhost && onRemoveSourceDeleted == null) {
      return const SizedBox.shrink();
    }
    final selected = selectedIds.contains(product.id);
    final focused =
        focusProductId != null &&
        focusProductId!.isNotEmpty &&
        product.id == focusProductId;
    final selectedPhotos = <int>{
      for (final key in selectedPhotoKeys)
        if (key.startsWith('${product.id}|'))
          int.tryParse(key.substring(product.id.length + 1)) ?? -1,
    }..removeWhere((i) => i < 0);
    return GestureDetector(
      // Fallback when there are no collage cells (empty product) or the tap
      // lands on chrome overlays; collage cells report their own index.
      onTap:
          shelfGhost
              ? () {}
              : () => onProductTap(product, 0),
      onLongPress:
          shelfGhost || onProductLongPress == null
              ? null
              : () => onProductLongPress!(product),
      child: KeyedSubtree(
        key: focused ? focusKey : null,
        child: _ProductCard(
          key: ValueKey(product.id),
          product: product,
          selectionMode: selectionMode,
          photoSelectionMode: photoSelectionMode,
          selectedPhotoIndexes: selectedPhotos,
          isSelected: selected,
          isFocused: focused,
          isDeleting: deletingProductIds.contains(product.id),
          availability: listingAvailability[product.id],
          large: viewMode == ProductViewMode.single,
          onRemoveSourceDeleted:
              onRemoveSourceDeleted == null
                  ? null
                  : () => onRemoveSourceDeleted!(product),
          onImageLongPress:
              shelfGhost || onImageLongPress == null
                  ? null
                  : (imageIndex) => onImageLongPress!(product, imageIndex),
          onImageTap:
              // Own-store product select: taps go to card GestureDetector.
              // Visitor photo select / normal browse: collage cells win.
              shelfGhost ||
                      (selectionMode && !photoSelectionMode)
                  ? null
                  : (imageIndex, {Rect? sourceRect}) => onProductTap(
                    product,
                    imageIndex,
                    sourceRect: sourceRect,
                  ),
        ),
      ),
    );
  }

  Widget buildSliver({bool isLoading = false}) {
    if (products.isEmpty) {
      if (isLoading) {
        return const StoreProductGridShimmer();
      }
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            'No products yet',
            style: AppTextStyles.bodySecondary(),
          ),
        ),
      );
    }

    // Telegram-style single feed: date pills + full-width cards.
    if (viewMode == ProductViewMode.single) {
      final items = _buildSingleFeedItems(products);
      return SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = items[index];
          if (item is _SingleDateHeader) {
            return _TelegramDatePill(label: item.label);
          }
          final product = (item as _SingleProductItem).product;
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == items.length - 1 ? 0 : 12,
            ),
            child: AspectRatio(
              aspectRatio: singleDelegate.childAspectRatio,
              child: _card(product),
            ),
          );
        }, childCount: items.length),
      );
    }

    return SliverGrid(
      gridDelegate: _delegate,
      delegate: SliverChildBuilderDelegate(
        (context, index) => _card(products[index]),
        childCount: products.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Text(
          'No products yet',
          style: AppTextStyles.bodySecondary(),
        ),
      );
    }

    if (viewMode == ProductViewMode.single) {
      final items = _buildSingleFeedItems(products);
      return ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          if (item is _SingleDateHeader) {
            return _TelegramDatePill(label: item.label);
          }
          final product = (item as _SingleProductItem).product;
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == items.length - 1 ? 0 : 12,
            ),
            child: AspectRatio(
              aspectRatio: singleDelegate.childAspectRatio,
              child: _card(product),
            ),
          );
        },
      );
    }

    return GridView.builder(
      shrinkWrap: false,
      physics: const BouncingScrollPhysics(),
      itemCount: products.length,
      gridDelegate: _delegate,
      itemBuilder: (context, index) => _card(products[index]),
    );
  }
}

/// Flat single-view feed: date header then products for that day.
List<Object> _buildSingleFeedItems(List<StoreProduct> products) {
  final grouped = <DateTime, List<StoreProduct>>{};
  final dateOrder = <DateTime>[];
  for (final product in products) {
    final day = product.addedDate;
    if (!grouped.containsKey(day)) {
      dateOrder.add(day);
      grouped[day] = [];
    }
    grouped[day]!.add(product);
  }

  final items = <Object>[];
  for (final date in dateOrder) {
    items.add(_SingleDateHeader(label: _telegramDayLabel(date)));
    for (final product in grouped[date]!) {
      items.add(_SingleProductItem(product: product));
    }
  }
  return items;
}

class _SingleDateHeader {
  const _SingleDateHeader({required this.label});
  final String label;
}

class _SingleProductItem {
  const _SingleProductItem({required this.product});
  final StoreProduct product;
}

String _telegramDayLabel(DateTime date) => formatCatalogDayBucket(date);

/// Centered Telegram-style date pill (Today / Yesterday / October 10).
class _TelegramDatePill extends StatelessWidget {
  const _TelegramDatePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.maybeOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: AppTextStyles.caption(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textOnPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatefulWidget {
  const _ProductCard({
    super.key,
    required this.product,
    this.selectionMode = false,
    this.photoSelectionMode = false,
    this.selectedPhotoIndexes = const {},
    this.isSelected = false,
    this.isFocused = false,
    this.isDeleting = false,
    this.availability,
    this.large = false,
    this.onImageTap,
    this.onImageLongPress,
    this.onRemoveSourceDeleted,
  });

  final StoreProduct product;
  final bool selectionMode;
  final bool photoSelectionMode;
  final Set<int> selectedPhotoIndexes;
  final bool isSelected;
  final bool isFocused;
  final bool isDeleting;
  final ListingImportAvailability? availability;
  final VoidCallback? onRemoveSourceDeleted;
  final bool large;
  final void Function(int imageIndex, {Rect? sourceRect})? onImageTap;
  final void Function(int imageIndex)? onImageLongPress;

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  int _albumPage = 0;
  int _albumPageCount = 0;

  String? get _statusLabel {
    // Visitor import-targets overlay (source store) wins when present.
    switch (widget.availability) {
      case ListingImportAvailability.alreadyAdded:
        return 'Added';
      case ListingImportAvailability.pending:
        return 'Pending';
      case ListingImportAvailability.available:
      case ListingImportAvailability.unavailable:
      case null:
        break;
    }
    // Destination shelf: pending / declined import chrome.
    // Group collage with mixed cells uses per-photo tags instead.
    final product = widget.product;
    if (product.imageImportStatuses.isNotEmpty) {
      final statuses =
          product.imageImportStatuses
              .map((s) => s.trim().toLowerCase())
              .where((s) => s.isNotEmpty)
              .toList();
      if (statuses.isEmpty) return null;
      final allDeclined = statuses.every((s) => s == 'declined');
      if (allDeclined) return 'Declined';
      final allPending = statuses.every((s) => s == 'pending');
      if (allPending) return 'Pending';
      return null;
    }
    if (product.isImportDeclined) return 'Declined';
    if (product.isImportPending) return 'Pending';
    return null;
  }

  @override
  void didUpdateWidget(covariant _ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id ||
        oldWidget.product.imagePaths.length !=
            widget.product.imagePaths.length) {
      _albumPage = 0;
      _albumPageCount = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    AppearanceScope.maybeOf(context);
    final product = widget.product;
    final large = widget.large;
    final selectionMode = widget.selectionMode;
    final onImageTap = widget.onImageTap;
    final gradient = _toneGradient(product.toneIndex);
    final allPaths = product.imagePaths;
    // Collage layout indexes (0..n-1 among displayable) drive large vs small
    // quality; product.index is for urlForRole arrays. Tap still → master.
    final displayableIndexes = <int>[
      for (var i = 0; i < allPaths.length; i++)
        if (ProductImagePaths.isDisplayable(allPaths[i])) i,
    ];
    final collageCount = displayableIndexes.length;
    final displayCells = <({int index, String path, CatalogImageRole role})>[];
    for (var c = 0; c < displayableIndexes.length; c++) {
      final productIndex = displayableIndexes[c];
      final cellRole = CatalogResponsiveImage.roleForCollageCell(
        imageCount: collageCount,
        imageIndex: c,
      );
      displayCells.add((
        index: productIndex,
        role: cellRole,
        path: product.urlForRole(productIndex, cellRole, log: c == 0),
      ));
    }
    final existingPaths =
        displayCells.map((c) => c.path).toList(growable: false);
    final hasImages = existingPaths.isNotEmpty;
    if (hasImages) {
      CatalogMediaDebug.qualityViewPaint(
        view: large ? 'single' : 'group',
        role: displayCells.first.role,
        sampleUrl: existingPaths.first,
      );
    }
    final status = _statusLabel;
    final showPrimaryBorder =
        (selectionMode && widget.isSelected) ||
        (!selectionMode && widget.isFocused);
    final isPagedAlbum = existingPaths.length > 9;
    final albumPageCount =
        isPagedAlbum ? (existingPaths.length + 8) ~/ 9 : 0;
    final albumPage =
        albumPageCount > 0
            ? _albumPage.clamp(0, albumPageCount - 1)
            : 0;
    // Soft always-on outline — Day: light grey, Night: quiet graphite.
    // Selection/focus still uses a stronger primary stroke.
    final outline =
        showPrimaryBorder
            ? Border.all(color: AppColors.primary, width: 2.5)
            : Border.all(
              color:
                  AppColors.isNight
                      ? AppColors.border.withValues(alpha: 0.55)
                      : AppColors.divider.withValues(alpha: 0.7),
              width: 1,
            );
    final titleColor = AppColors.textOnPrimary;
    final imageCount = existingPaths.length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: outline,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(showPrimaryBorder ? 11.5 : 12.25),
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
            if (hasImages)
              ProductImageCollage(
                imagePaths: existingPaths,
                imageThumbhashes: product.imageThumbhashes,
                tileBorderRadius: large ? 3.5 : 2.5,
                selectionMode: widget.photoSelectionMode,
                // Lock / out-of-stock only while long-press selection is on
                // (details show the same chrome). Pending tags stay always-on.
                showImportStatus: widget.photoSelectionMode,
                importLocked: product.isLocked,
                importStock: product.stockStatus,
                importAlreadyImported: product.isAlreadyImported,
                importSelectionBlocked: product.importSelectionBlocked,
                imageImportLocked: [
                  for (var i = 0; i < displayCells.length; i++)
                    product.isLockedAt(displayCells[i].index),
                ],
                imageImportStocks: [
                  for (var i = 0; i < displayCells.length; i++)
                    product.stockStatusAt(displayCells[i].index),
                ],
                imageImportPending: [
                  for (var i = 0; i < displayCells.length; i++)
                    product.isImportPendingAt(displayCells[i].index),
                ],
                imageImportDeclined: [
                  for (var i = 0; i < displayCells.length; i++)
                    product.isImportDeclinedAt(displayCells[i].index),
                ],
                selectedIndexes: {
                  for (var i = 0; i < displayCells.length; i++)
                    if (widget.selectedPhotoIndexes.contains(
                      displayCells[i].index,
                    ))
                      i,
                },
                onAlbumPageChanged:
                    isPagedAlbum
                        ? (page, count) {
                          if (_albumPage == page &&
                              _albumPageCount == count) {
                            return;
                          }
                          setState(() {
                            _albumPage = page;
                            _albumPageCount = count;
                          });
                        }
                        : null,
                onImageLongPress:
                    widget.onImageLongPress == null
                        ? null
                        : (displayIndex) {
                          if (displayIndex < 0 ||
                              displayIndex >= displayCells.length) {
                            widget.onImageLongPress!(0);
                            return;
                          }
                          widget.onImageLongPress!(
                            displayCells[displayIndex].index,
                          );
                        },
                onImageTap:
                    onImageTap == null
                        ? null
                        : (displayIndex, {Rect? sourceRect}) {
                          if (displayIndex < 0 ||
                              displayIndex >= displayCells.length) {
                            onImageTap(0, sourceRect: sourceRect);
                            return;
                          }
                          onImageTap(
                            displayCells[displayIndex].index,
                            sourceRect: sourceRect,
                          );
                        },
              )
            else
              Center(
                child: Icon(
                  Icons.diamond_outlined,
                  size: large ? 48 : 34,
                  color: AppColors.textOnPrimary,
                ),
              ),
            // Let collage cells win hit-testing when per-image taps are wired.
            IgnorePointer(
              ignoring: onImageTap != null,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.4),
                    ],
                    stops: const [0.45, 1],
                  ),
                ),
              ),
            ),
            IgnorePointer(
              ignoring: onImageTap != null,
              child: Padding(
                padding: EdgeInsets.all(large ? 14 : 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((product.likeCount != null &&
                                product.likeCount! > 0) ||
                            (product.viewCount != null &&
                                product.viewCount! > 0) ||
                            (product.wishlistCount != null &&
                                product.wishlistCount! > 0))
                          _LikeViewCountBadges(
                            likeCount: product.likeCount,
                            viewCount: product.viewCount,
                            wishlistCount: product.wishlistCount,
                          ),
                        const Spacer(),
                        if (selectionMode)
                          _SelectionCheck(
                            isSelected: widget.isSelected,
                            isDeleting: widget.isDeleting,
                          )
                        else if (status != null)
                          _ImportStatusChip(label: status),
                      ],
                    ),
                    const Spacer(),
                    if (isPagedAlbum && albumPageCount > 1) ...[
                      _AlbumPageDots(
                        pageIndex: albumPage,
                        // One dot per horizontal collage page (9 images).
                        pageCount: albumPageCount,
                      ),
                      SizedBox(height: large ? 8 : 6),
                    ],
                    // Title + item count glued together. Count shows for
                    // any displayable album size, including a single image.
                    // Upload date is shown as the Telegram day pill above
                    // (Today / Yesterday / October 10) — no per-card time.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            product.title,
                            maxLines: large ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body(
                              fontSize: large ? 20 : 17,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                        ),
                        if (imageCount >= 1) ...[
                          const SizedBox(width: 6),
                          _AlbumImageCount(
                            count: imageCount,
                            large: large,
                          ),
                        ],
                      ],
                    ),
                    // Tags / meta under title intentionally hidden.
                  ],
                ),
              ),
            ),
            if (product.isSourceDeleted &&
                widget.onRemoveSourceDeleted != null)
              Positioned.fill(
                child: _ShelfGhostOverlay(
                  title: 'Source Deleted',
                  actionLabel: 'Remove from Shelf',
                  onRemove: widget.onRemoveSourceDeleted!,
                ),
              )
            else if (product.isImportDeclined &&
                widget.onRemoveSourceDeleted != null)
              Positioned.fill(
                child: _ShelfGhostOverlay(
                  title: 'Declined by Partner',
                  actionLabel: 'Delete',
                  onRemove: widget.onRemoveSourceDeleted!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Own-store ghost when source was deleted or partner declined the import.
class _ShelfGhostOverlay extends StatelessWidget {
  const _ShelfGhostOverlay({
    required this.title,
    required this.actionLabel,
    required this.onRemove,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.45),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: onRemove,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(
                          actionLabel,
                          style: AppTextStyles.caption(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Carousel-style page dots for 10+ image product albums.
/// Renders exactly [pageCount] dots and highlights [pageIndex].
class _AlbumPageDots extends StatelessWidget {
  const _AlbumPageDots({
    required this.pageIndex,
    required this.pageCount,
  });

  final int pageIndex;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) return const SizedBox.shrink();
    final active = pageIndex.clamp(0, pageCount - 1);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        final isActive = index == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 14 : 6,
          height: 6,
          decoration: BoxDecoration(
            color:
                isActive
                    ? AppColors.textOnPrimary
                    : AppColors.textOnPrimary.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}

/// Compact image-count chip beside the product title.
class _AlbumImageCount extends StatelessWidget {
  const _AlbumImageCount({
    required this.count,
    required this.large,
  });

  final int count;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 7 : 6,
        vertical: large ? 3 : 2,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count',
        style: AppTextStyles.caption(
          fontSize: large ? 12 : 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}

/// Compact like + view + private wishlist chips (thumbs · eye · heart).
class _LikeViewCountBadges extends StatelessWidget {
  const _LikeViewCountBadges({
    this.likeCount,
    this.viewCount,
    this.wishlistCount,
  });

  final int? likeCount;
  final int? viewCount;

  /// Viewer-private bookmark count for pieces on this card.
  final int? wishlistCount;

  @override
  Widget build(BuildContext context) {
    final like = likeCount;
    final views = viewCount;
    final wish = wishlistCount;
    final chips = <Widget>[
      if (like != null && like > 0)
        _MetricBadge(
          icon: Icons.thumb_up_rounded,
          count: like,
        ),
      if (views != null && views > 0)
        _MetricBadge(
          icon: Icons.visibility_outlined,
          count: views,
        ),
      if (wish != null && wish > 0)
        _MetricBadge(
          icon: Icons.favorite_rounded,
          count: wish,
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          chips[i],
        ],
      ],
    );
  }
}

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    final label =
        count < 1000
            ? '$count'
            : count < 1000000
            ? '${(count / 1000).floor()}k'
            : '${(count / 1000000).toStringAsFixed(1)}M';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textOnPrimary),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTextStyles.caption(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textOnPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionCheck extends StatelessWidget {
  const _SelectionCheck({
    required this.isSelected,
    required this.isDeleting,
  });

  final bool isSelected;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    if (isDeleting) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.textOnPrimary,
        ),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppColors.primary : Colors.black.withValues(alpha: 0.35),
        border: Border.all(color: AppColors.textOnPrimary, width: 1.5),
      ),
      child:
          isSelected
              ? Icon(
                Icons.check_rounded,
                size: 16,
                color: AppColors.textOnPrimary,
              )
              : null,
    );
  }
}

class _ImportStatusChip extends StatelessWidget {
  const _ImportStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final key = label.trim().toLowerCase();
    final bg = switch (key) {
      'pending' => AppColors.warning.withValues(alpha: 0.92),
      'declined' => AppColors.error.withValues(alpha: 0.92),
      _ => Colors.black.withValues(alpha: 0.45),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}

List<Color> _toneGradient(int tone) {
  return switch (tone % 4) {
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
}
