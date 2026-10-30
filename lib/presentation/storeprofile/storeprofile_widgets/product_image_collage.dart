import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/catalog/catalog_stock_status.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/visitor_photo_selection_chrome.dart';

/// Telegram-style media album collage — layout unchanged; each photo is clipped
/// with a subtle [tileBorderRadius] on every corner and a small [gap] between
/// tiles (card backing shows through, Telegram-style).
///
/// - 1: full cover
/// - 2: equal side-by-side
/// - 3: large left (~2/3) + 2 stacked right
/// - 4: large left (~2/3) + 3 stacked right
/// - 5: 2 / 3
/// - 6: 3 / 3
/// - 7: 2 / 2 / 3
/// - 8: 2 / 3 / 3
/// - 9: 3 / 3 / 3
/// - 10+: horizontal pages of 3×3 (9 per page) so vertical profile scroll stays free
///
/// When [onImageTap] is set, each cell reports its absolute index in
/// [imagePaths] (0-based, matching product-details / gallery feed).
class ProductImageCollage extends StatelessWidget {
  const ProductImageCollage({
    super.key,
    required this.imagePaths,
    this.imageThumbhashes = const [],
    this.thumbhashOnly = false,
    this.gap = 1.2,
    this.tileBorderRadius = 3,
    this.onImageTap,
    this.onImageLongPress,
    this.onAlbumPageChanged,
    this.selectionMode = false,
    this.selectedIndexes = const <int>{},
    this.showImportStatus = false,
    this.importLocked = false,
    this.importStock,
    this.importAlreadyImported = false,
    this.importSelectionBlocked = false,
    this.imageImportLocked = const <bool>[],
    this.imageImportStocks = const <CatalogStockStatus?>[],
    this.imageImportPending = const <bool>[],
    this.imageImportDeclined = const <bool>[],
  });

  final List<String> imagePaths;

  /// Parallel to [imagePaths] — base64 ThumbHash placeholders when present.
  final List<String> imageThumbhashes;

  /// Ignored — collage always loads CDN URLs with ThumbHash as placeholder
  /// (frontend guide InstantCatalogPhoto). Kept for call-site compatibility.
  final bool thumbhashOnly;

  /// Spacing between tiles (default 1.5 — thin gutter).
  final double gap;

  /// Subtle corner radius on each photo tile (all four corners).
  final double tileBorderRadius;

  /// Absolute index into [imagePaths] for the tapped collage cell.
  /// [sourceRect] is the cell bounds in global coordinates (Telegram open).
  final void Function(int index, {Rect? sourceRect})? onImageTap;

  /// Long-press on a cell (visitor multi-select entry).
  final void Function(int index)? onImageLongPress;

  /// Fired for 10+ image albums (horizontal 3×3 pages). [pageIndex] is
  /// 0-based; [pageCount] is total pages.
  final void Function(int pageIndex, int pageCount)? onAlbumPageChanged;

  /// When true, cells show Telegram-style selection rings / checks.
  final bool selectionMode;

  /// Absolute indexes into [imagePaths] that are selected.
  final Set<int> selectedIndexes;

  /// Lock / stock / import marks — only while visitor photo selection is on.
  final bool showImportStatus;

  /// Card-level fallbacks when per-cell lists are empty.
  final bool importLocked;
  final CatalogStockStatus? importStock;
  final bool importAlreadyImported;
  final bool importSelectionBlocked;

  /// Parallel to [imagePaths] — per-cell lock (Group collage).
  final List<bool> imageImportLocked;

  /// Parallel to [imagePaths] — per-cell stock (Group collage).
  final List<CatalogStockStatus?> imageImportStocks;

  /// Parallel to [imagePaths] — destination import awaiting approval.
  final List<bool> imageImportPending;

  /// Parallel to [imagePaths] — destination import declined by source.
  final List<bool> imageImportDeclined;

  @override
  Widget build(BuildContext context) {
    if (imagePaths.isEmpty) {
      return ColoredBox(color: AppColors.surfaceSecondary);
    }

    final paths = imagePaths;
    final signature = paths.join('|');

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: KeyedSubtree(
        key: ValueKey(signature),
        child: _CollageInteraction(
          selectionMode: selectionMode,
          selectedIndexes: selectedIndexes,
          onImageLongPress: onImageLongPress,
          showImportStatus: showImportStatus,
          importLocked: importLocked,
          importStock: importStock,
          importAlreadyImported: importAlreadyImported,
          importSelectionBlocked: importSelectionBlocked,
          imageImportLocked: imageImportLocked,
          imageImportStocks: imageImportStocks,
          imageImportPending: imageImportPending,
          imageImportDeclined: imageImportDeclined,
          child: _CollageBody(
            paths: paths,
            thumbhashes: imageThumbhashes,
            thumbhashOnly: thumbhashOnly,
            gap: gap,
            tileBorderRadius: tileBorderRadius,
            onImageTap: onImageTap,
            onAlbumPageChanged: onAlbumPageChanged,
          ),
        ),
      ),
    );
  }
}

class _CollageInteraction extends InheritedWidget {
  const _CollageInteraction({
    required this.selectionMode,
    required this.selectedIndexes,
    required this.onImageLongPress,
    required this.showImportStatus,
    required this.importLocked,
    required this.importStock,
    required this.importAlreadyImported,
    required this.importSelectionBlocked,
    required this.imageImportLocked,
    required this.imageImportStocks,
    required this.imageImportPending,
    required this.imageImportDeclined,
    required super.child,
  });

  final bool selectionMode;
  final Set<int> selectedIndexes;

  /// Lock / stock marks on each photo while visitor import selection is on.
  final bool showImportStatus;
  final bool importLocked;
  final CatalogStockStatus? importStock;
  final bool importAlreadyImported;
  final bool importSelectionBlocked;
  final List<bool> imageImportLocked;
  final List<CatalogStockStatus?> imageImportStocks;
  final List<bool> imageImportPending;
  final List<bool> imageImportDeclined;
  final void Function(int index)? onImageLongPress;

  bool isImportPendingAt(int index) {
    if (index < 0 || index >= imageImportPending.length) return false;
    return imageImportPending[index];
  }

  bool isImportDeclinedAt(int index) {
    if (index < 0 || index >= imageImportDeclined.length) return false;
    return imageImportDeclined[index];
  }

  bool isImportLockedAt(int index) {
    if (index >= 0 && index < imageImportLocked.length) {
      return imageImportLocked[index];
    }
    return importLocked;
  }

  CatalogStockStatus? importStockAt(int index) {
    if (index >= 0 && index < imageImportStocks.length) {
      return imageImportStocks[index];
    }
    return importStock;
  }

  static _CollageInteraction? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_CollageInteraction>();
  }

  @override
  bool updateShouldNotify(_CollageInteraction oldWidget) {
    return selectionMode != oldWidget.selectionMode ||
        onImageLongPress != oldWidget.onImageLongPress ||
        showImportStatus != oldWidget.showImportStatus ||
        importLocked != oldWidget.importLocked ||
        importStock != oldWidget.importStock ||
        importAlreadyImported != oldWidget.importAlreadyImported ||
        importSelectionBlocked != oldWidget.importSelectionBlocked ||
        !_boolListEquals(imageImportLocked, oldWidget.imageImportLocked) ||
        !_stockListEquals(imageImportStocks, oldWidget.imageImportStocks) ||
        !_boolListEquals(imageImportPending, oldWidget.imageImportPending) ||
        !_boolListEquals(imageImportDeclined, oldWidget.imageImportDeclined) ||
        !_setEquals(selectedIndexes, oldWidget.selectedIndexes);
  }

  static bool _setEquals(Set<int> a, Set<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  static bool _boolListEquals(List<bool> a, List<bool> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _stockListEquals(
    List<CatalogStockStatus?> a,
    List<CatalogStockStatus?> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _CollageBody extends StatelessWidget {
  const _CollageBody({
    required this.paths,
    required this.thumbhashes,
    required this.thumbhashOnly,
    required this.gap,
    required this.tileBorderRadius,
    this.onImageTap,
    this.onAlbumPageChanged,
  });

  final List<String> paths;
  final List<String> thumbhashes;
  final bool thumbhashOnly;
  final double gap;
  final double tileBorderRadius;
  final void Function(int index, {Rect? sourceRect})? onImageTap;
  final void Function(int pageIndex, int pageCount)? onAlbumPageChanged;

  String? _hashAt(int index) {
    if (index < 0 || index >= thumbhashes.length) return null;
    final value = thumbhashes[index].trim();
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    return _CollageThumbhashes(
      hashAt: _hashAt,
      thumbhashOnly: thumbhashOnly,
      tileBorderRadius: tileBorderRadius,
      child: switch (paths.length) {
        1 => _ImageCell(path: paths[0], index: 0, onImageTap: onImageTap),
        2 => _EqualRow(
          paths: paths,
          gap: gap,
          startIndex: 0,
          onImageTap: onImageTap,
        ),
        3 => _LargeLeftStack(
          largePath: paths[0],
          largeIndex: 0,
          stackedPaths: paths.sublist(1),
          stackedStartIndex: 1,
          gap: gap,
          onImageTap: onImageTap,
        ),
        4 => _LargeLeftStack(
          largePath: paths[0],
          largeIndex: 0,
          stackedPaths: paths.sublist(1),
          stackedStartIndex: 1,
          gap: gap,
          onImageTap: onImageTap,
        ),
        _ when paths.length > 9 => _ScrollableAlbum(
          paths: paths,
          gap: gap,
          onImageTap: onImageTap,
          onPageChanged: onAlbumPageChanged,
        ),
        _ => _RowAlbum(
          paths: paths,
          gap: gap,
          rowSizes: _rowPlan(paths.length),
          onImageTap: onImageTap,
        ),
      },
    );
  }
}

class _CollageThumbhashes extends InheritedWidget {
  const _CollageThumbhashes({
    required this.hashAt,
    required this.thumbhashOnly,
    required this.tileBorderRadius,
    required super.child,
  });

  final String? Function(int index) hashAt;
  final bool thumbhashOnly;
  final double tileBorderRadius;

  static String? hashAtIndex(BuildContext context, int index) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_CollageThumbhashes>();
    return scope?.hashAt(index);
  }

  static bool thumbhashOnlyOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_CollageThumbhashes>();
    return scope?.thumbhashOnly ?? false;
  }

  static double tileRadiusOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_CollageThumbhashes>();
    return scope?.tileBorderRadius ?? 2.5;
  }

  @override
  bool updateShouldNotify(_CollageThumbhashes oldWidget) =>
      oldWidget.tileBorderRadius != tileBorderRadius ||
      oldWidget.thumbhashOnly != thumbhashOnly;
}

List<int> _rowPlan(int count) {
  return switch (count) {
    5 => const [2, 3],
    6 => const [3, 3],
    7 => const [2, 2, 3],
    8 => const [2, 3, 3],
    9 => const [3, 3, 3],
    _ => const [3, 3, 3],
  };
}

class _LargeLeftStack extends StatelessWidget {
  const _LargeLeftStack({
    required this.largePath,
    required this.largeIndex,
    required this.stackedPaths,
    required this.stackedStartIndex,
    required this.gap,
    this.onImageTap,
  });

  final String largePath;
  final int largeIndex;
  final List<String> stackedPaths;
  final int stackedStartIndex;
  final double gap;
  final void Function(int index, {Rect? sourceRect})? onImageTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _ImageCell(
            path: largePath,
            index: largeIndex,
            onImageTap: onImageTap,
          ),
        ),
        if (gap > 0) SizedBox(width: gap),
        Expanded(
          flex: 1,
          child: Column(
            children: [
              for (var i = 0; i < stackedPaths.length; i++) ...[
                if (i > 0 && gap > 0) SizedBox(height: gap),
                Expanded(
                  child: _ImageCell(
                    path: stackedPaths[i],
                    index: stackedStartIndex + i,
                    onImageTap: onImageTap,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RowAlbum extends StatelessWidget {
  const _RowAlbum({
    required this.paths,
    required this.gap,
    required this.rowSizes,
    this.onImageTap,
  });

  final List<String> paths;
  final double gap;
  final List<int> rowSizes;
  final void Function(int index, {Rect? sourceRect})? onImageTap;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    var offset = 0;
    for (var r = 0; r < rowSizes.length; r++) {
      if (r > 0 && gap > 0) children.add(SizedBox(height: gap));
      final count = rowSizes[r];
      final slice = paths.sublist(offset, offset + count);
      children.add(
        Expanded(
          child: _EqualRow(
            paths: slice,
            gap: gap,
            startIndex: offset,
            onImageTap: onImageTap,
          ),
        ),
      );
      offset += count;
    }
    return Column(children: children);
  }
}

class _ScrollableAlbum extends StatefulWidget {
  const _ScrollableAlbum({
    required this.paths,
    required this.gap,
    this.onImageTap,
    this.onPageChanged,
  });

  static const int pageSize = 9;

  final List<String> paths;
  final double gap;
  final void Function(int index, {Rect? sourceRect})? onImageTap;
  final void Function(int pageIndex, int pageCount)? onPageChanged;

  @override
  State<_ScrollableAlbum> createState() => _ScrollableAlbumState();
}

class _ScrollableAlbumState extends State<_ScrollableAlbum> {
  late final PageController _controller;
  int _page = 0;

  int get _pageCount {
    final n = widget.paths.length;
    if (n <= 0) return 0;
    return (n + _ScrollableAlbum.pageSize - 1) ~/ _ScrollableAlbum.pageSize;
  }

  void _emitPage(int pageIndex) {
    final count = _pageCount;
    if (count <= 0) return;
    final next = pageIndex.clamp(0, count - 1);
    _page = next;
    widget.onPageChanged?.call(next, count);
  }

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _emitPage(0);
    });
  }

  @override
  void didUpdateWidget(covariant _ScrollableAlbum oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paths.length != widget.paths.length) {
      final count = _pageCount;
      final next = count > 0 ? _page.clamp(0, count - 1) : 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_controller.hasClients &&
            count > 0 &&
            (_controller.page?.round() ?? _page) != next) {
          _controller.jumpToPage(next);
        }
        _emitPage(next);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = _pageCount;
    if (pageCount <= 0) {
      return const SizedBox.expand();
    }
    return PageView.builder(
      controller: _controller,
      physics: const BouncingScrollPhysics(),
      itemCount: pageCount,
      onPageChanged: _emitPage,
      itemBuilder: (context, pageIndex) {
        final start = pageIndex * _ScrollableAlbum.pageSize;
        final end =
            (start + _ScrollableAlbum.pageSize).clamp(0, widget.paths.length);
        final pagePaths = widget.paths.sublist(start, end);
        return _PageGrid(
          paths: pagePaths,
          startIndex: start,
          gap: widget.gap,
          onImageTap: widget.onImageTap,
        );
      },
    );
  }
}

class _PageGrid extends StatelessWidget {
  const _PageGrid({
    required this.paths,
    required this.startIndex,
    required this.gap,
    this.onImageTap,
  });

  final List<String> paths;
  final int startIndex;
  final double gap;
  final void Function(int index, {Rect? sourceRect})? onImageTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < 3; row++) ...[
          if (row > 0 && gap > 0) SizedBox(height: gap),
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < 3; col++) ...[
                  if (col > 0 && gap > 0) SizedBox(width: gap),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final i = row * 3 + col;
                        if (i >= paths.length) {
                          return const SizedBox.expand();
                        }
                        return _ImageCell(
                          path: paths[i],
                          index: startIndex + i,
                          onImageTap: onImageTap,
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _EqualRow extends StatelessWidget {
  const _EqualRow({
    required this.paths,
    required this.gap,
    required this.startIndex,
    this.onImageTap,
  });

  final List<String> paths;
  final double gap;
  final int startIndex;
  final void Function(int index, {Rect? sourceRect})? onImageTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < paths.length; i++) ...[
          if (i > 0 && gap > 0) SizedBox(width: gap),
          Expanded(
            child: _ImageCell(
              path: paths[i],
              index: startIndex + i,
              onImageTap: onImageTap,
            ),
          ),
        ],
      ],
    );
  }
}

class _ImageCell extends StatelessWidget {
  const _ImageCell({
    required this.path,
    required this.index,
    this.onImageTap,
  });

  final String path;
  final int index;
  final void Function(int index, {Rect? sourceRect})? onImageTap;

  @override
  Widget build(BuildContext context) {
    final radius = _CollageThumbhashes.tileRadiusOf(context);
    final interaction = _CollageInteraction.maybeOf(context);
    final selectionMode = interaction?.selectionMode ?? false;
    final selected = interaction?.selectedIndexes.contains(index) ?? false;
    final onLongPress = interaction?.onImageLongPress;
    final importPending = interaction?.isImportPendingAt(index) ?? false;
    final importDeclined = interaction?.isImportDeclinedAt(index) ?? false;
    final hasImportTag = importPending || importDeclined;

    Widget image = ProductMediaImage(
      path: path,
      thumbhash: _CollageThumbhashes.hashAtIndex(context, index),
      thumbhashOnly: _CollageThumbhashes.thumbhashOnlyOf(context),
    );
    if (radius > 0) {
      image = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: SizedBox.expand(child: image),
      );
    }

    if (selectionMode || hasImportTag) {
      image = Stack(
        fit: StackFit.expand,
        children: [
          image,
          if (importDeclined)
            const Positioned(
              top: 6,
              left: 6,
              child: _ImportDeclinedPill(),
            )
          else if (importPending)
            const Positioned(
              top: 6,
              left: 6,
              child: _ImportPendingPill(),
            ),
          if (selectionMode)
            Positioned(
              top: 6,
              right: 6,
              child: _TelegramSelectBadge(selected: selected),
            ),
          if (selectionMode && (interaction?.showImportStatus ?? false))
            Positioned(
              top: hasImportTag ? 30 : 6,
              left: 6,
              right: 28,
              child: VisitorImportStatusMarks(
                locked: interaction?.isImportLockedAt(index) ?? false,
                stock: interaction?.importStockAt(index),
                alreadyImported:
                    interaction?.importAlreadyImported ?? false,
                selectionBlocked:
                    interaction?.importSelectionBlocked ?? false,
              ),
            ),
        ],
      );
    }

    if (onImageTap == null && onLongPress == null) return image;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap:
          onImageTap == null
              ? null
              : () {
                Rect? sourceRect;
                final box = context.findRenderObject();
                if (box is RenderBox && box.hasSize) {
                  sourceRect = box.localToGlobal(Offset.zero) & box.size;
                }
                onImageTap!(index, sourceRect: sourceRect);
              },
      onLongPress:
          onLongPress == null ? null : () => onLongPress(index),
      child: image,
    );
  }
}

/// Destination copy awaiting source-owner approval.
class _ImportPendingPill extends StatelessWidget {
  const _ImportPendingPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Pending',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Destination copy declined by source partner.
class _ImportDeclinedPill extends StatelessWidget {
  const _ImportDeclinedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Declined',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Telegram-style selection badge (ring / green check).
class _TelegramSelectBadge extends StatelessWidget {
  const _TelegramSelectBadge({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? const Color(0xFF4FAE4E) : Colors.black26,
        border: Border.all(color: Colors.white, width: 1.6),
      ),
      child:
          selected
              ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
              : null,
    );
  }
}
