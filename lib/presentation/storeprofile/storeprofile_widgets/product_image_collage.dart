import 'package:flutter/material.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/telegram_collage_geometry.dart';
import 'package:project_c/services/cart_store.dart';
import 'package:project_c/services/product_view_preferences.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/catalog/catalog_stock_status.dart';
import 'package:project_c/models/collage_grid_arrangement.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/visitor_photo_selection_chrome.dart';

/// Group / Single product-card collage.
///
/// **Default (active):** classic Telegram layouts. Landscape-aware variants
/// (full-width top landscape, stacked dual-landscape) use [imageAspectRatios]
/// without reordering cells — tap indexes stay stable.
///
/// **Image arrangement (disabled):** Settings N×N pages — kept behind
/// [kEnableCollageImageArrangement].
///
/// Each photo is clipped with a subtle [tileBorderRadius] and a small [gap]
/// between tiles. When [onImageTap] is set, each cell reports its absolute
/// index in [imagePaths] (0-based, matching product-details / gallery feed).
class ProductImageCollage extends StatelessWidget {
  const ProductImageCollage({
    super.key,
    required this.imagePaths,
    this.imageThumbhashes = const [],
    this.imageAspectRatios = const [],
    this.thumbhashOnly = false,
    this.gap = 1.2,
    this.tileBorderRadius = 3,
    this.layoutIdentity,
    this.cellOverlayBuilder,
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
    this.imageCartProductIds = const <String>[],
  });

  final List<String> imagePaths;

  /// Parallel to [imagePaths] — width/height when known (null = unknown).
  final List<double?> imageAspectRatios;

  /// When set, [AnimatedSwitcher] keys off this instead of path joins so
  /// mid-upload URL/path swaps (local â†’ compressed â†’ CDN) do not remount
  /// the collage and flicker.
  final String? layoutIdentity;

  /// Optional per-cell overlay (e.g. Telegram upload check / loader).
  final Widget Function(int index)? cellOverlayBuilder;

  /// Parallel to [imagePaths] â€” base64 ThumbHash placeholders when present.
  final List<String> imageThumbhashes;

  /// Ignored â€” collage always loads CDN URLs with ThumbHash as placeholder
  /// (frontend guide InstantCatalogPhoto). Kept for call-site compatibility.
  final bool thumbhashOnly;

  /// Spacing between tiles (default 1.5 â€” thin gutter).
  final double gap;

  /// Subtle corner radius on each photo tile (all four corners).
  final double tileBorderRadius;

  /// Absolute index into [imagePaths] for the tapped collage cell.
  /// [sourceRect] is the cell bounds in global coordinates (Telegram open).
  final void Function(int index, {Rect? sourceRect})? onImageTap;

  /// Long-press on a cell (visitor multi-select entry).
  final void Function(int index)? onImageLongPress;

  /// Fired when the collage has multiple NÃ—N pages. [pageIndex] is 0-based;
  /// [pageCount] is total pages.
  final void Function(int pageIndex, int pageCount)? onAlbumPageChanged;

  /// When true, cells show Telegram-style selection rings / checks.
  final bool selectionMode;

  /// Absolute indexes into [imagePaths] that are selected.
  final Set<int> selectedIndexes;

  /// Lock / stock / import marks â€” only while visitor photo selection is on.
  final bool showImportStatus;

  /// Card-level fallbacks when per-cell lists are empty.
  final bool importLocked;
  final CatalogStockStatus? importStock;
  final bool importAlreadyImported;
  final bool importSelectionBlocked;

  /// Parallel to [imagePaths] â€” per-cell lock (Group collage).
  final List<bool> imageImportLocked;

  /// Parallel to [imagePaths] â€” per-cell stock (Group collage).
  final List<CatalogStockStatus?> imageImportStocks;

  /// Parallel to [imagePaths] â€” destination import awaiting approval.
  final List<bool> imageImportPending;

  /// Parallel to [imagePaths] â€” destination import declined by source.
  final List<bool> imageImportDeclined;

  /// Parallel to [imagePaths] â€” catalog product id used for the in-cart mark.
  final List<String> imageCartProductIds;

  @override
  Widget build(BuildContext context) {
    if (imagePaths.isEmpty) {
      return ColoredBox(color: AppColors.surfaceSecondary);
    }

    // ROLLBACK: set kEnableCollageImageArrangement = true to use Settings N×N.
    if (kEnableCollageImageArrangement) {
      final viewPrefs = ServiceLocator.get<ProductViewPreferences>();
      return ListenableBuilder(
        listenable: viewPrefs,
        builder: (context, _) {
          return _buildCollageShell(
            arrangement: viewPrefs.collageGridArrangement,
          );
        },
      );
    }

    return _buildCollageShell(arrangement: null);
  }

  Widget _buildCollageShell({required CollageGridArrangement? arrangement}) {
    final paths = imagePaths;
    final identity = layoutIdentity?.trim() ?? '';
    // Orientation bits remount Telegram variants when ThumbHash aspects arrive.
    final orientKey = [
      for (final r in imageAspectRatios)
        TelegramCollageGeometry.isLandscapeRatio(r)
            ? 'L'
            : (r == null ? 'u' : 'P'),
    ].join();
    final signature =
        identity.isNotEmpty
            ? '$identity|o=$orientKey'
            : '${paths.join('|')}|arr=${arrangement?.side ?? 0}|n=${paths.length}|o=$orientKey';

    return AnimatedSwitcher(
      duration: Duration(milliseconds: identity.isNotEmpty ? 0 : 280),
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
          imageCartProductIds: imageCartProductIds,
          cellOverlayBuilder: cellOverlayBuilder,
          child: _CollageBody(
            paths: paths,
            thumbhashes: imageThumbhashes,
            aspectRatios: imageAspectRatios,
            thumbhashOnly: thumbhashOnly,
            gap: gap,
            tileBorderRadius: tileBorderRadius,
            arrangement: arrangement,
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
    required this.imageCartProductIds,
    this.cellOverlayBuilder,
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
  final List<String> imageCartProductIds;
  final void Function(int index)? onImageLongPress;
  final Widget Function(int index)? cellOverlayBuilder;

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

  String cartProductIdAt(int index) {
    if (index >= 0 && index < imageCartProductIds.length) {
      return imageCartProductIds[index].trim();
    }
    return '';
  }

  static _CollageInteraction? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_CollageInteraction>();
  }

  @override
  bool updateShouldNotify(_CollageInteraction oldWidget) {
    return selectionMode != oldWidget.selectionMode ||
        onImageLongPress != oldWidget.onImageLongPress ||
        cellOverlayBuilder != oldWidget.cellOverlayBuilder ||
        showImportStatus != oldWidget.showImportStatus ||
        importLocked != oldWidget.importLocked ||
        importStock != oldWidget.importStock ||
        importAlreadyImported != oldWidget.importAlreadyImported ||
        importSelectionBlocked != oldWidget.importSelectionBlocked ||
        !_boolListEquals(imageImportLocked, oldWidget.imageImportLocked) ||
        !_stockListEquals(imageImportStocks, oldWidget.imageImportStocks) ||
        !_boolListEquals(imageImportPending, oldWidget.imageImportPending) ||
        !_boolListEquals(imageImportDeclined, oldWidget.imageImportDeclined) ||
        !_stringListEquals(imageCartProductIds, oldWidget.imageCartProductIds) ||
        !_setEquals(selectedIndexes, oldWidget.selectedIndexes);
  }

  static bool _stringListEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
    required this.aspectRatios,
    required this.thumbhashOnly,
    required this.gap,
    required this.tileBorderRadius,
    required this.arrangement,
    this.onImageTap,
    this.onAlbumPageChanged,
  });

  final List<String> paths;
  final List<String> thumbhashes;
  final List<double?> aspectRatios;
  final bool thumbhashOnly;
  final double gap;
  final double tileBorderRadius;

  /// Non-null only when [kEnableCollageImageArrangement] is on.
  final CollageGridArrangement? arrangement;
  final void Function(int index, {Rect? sourceRect})? onImageTap;
  final void Function(int pageIndex, int pageCount)? onAlbumPageChanged;

  String? _hashAt(int index) {
    if (index < 0 || index >= thumbhashes.length) return null;
    final value = thumbhashes[index].trim();
    return value.isEmpty ? null : value;
  }

  Widget _remainingBelow({
    required List<String> rest,
    required int startIndex,
  }) {
    final n = rest.length;
    if (n <= 0) return const SizedBox.expand();
    if (n == 1) {
      return _ImageCell(
        path: rest[0],
        index: startIndex,
        onImageTap: onImageTap,
      );
    }
    if (n == 2) {
      // Mixed / portrait pair → side-by-side; dual landscape → stack.
      return TelegramCollageGeometry.stackRemainingTwoLandscapes(
            aspectRatios,
            startIndex,
          )
          ? _EqualColumn(
            paths: rest,
            gap: gap,
            startIndex: startIndex,
            onImageTap: onImageTap,
          )
          : _EqualRow(
            paths: rest,
            gap: gap,
            startIndex: startIndex,
            onImageTap: onImageTap,
          );
    }
    if (n == 3) {
      return _EqualRow(
        paths: rest,
        gap: gap,
        startIndex: startIndex,
        onImageTap: onImageTap,
      );
    }
    if (n == 4) {
      return _RowAlbum(
        paths: rest,
        gap: gap,
        rowSizes: const [2, 2],
        startIndex: startIndex,
        onImageTap: onImageTap,
      );
    }
    return _RowAlbum(
      paths: rest,
      gap: gap,
      rowSizes: _telegramRowPlan(n.clamp(5, 9)),
      startIndex: startIndex,
      onImageTap: onImageTap,
    );
  }

  Widget _telegramBody() {
    final n = paths.length;
    return switch (n) {
      1 => _ImageCell(path: paths[0], index: 0, onImageTap: onImageTap),
      2 =>
        TelegramCollageGeometry.stackTwoLandscapes(aspectRatios)
            ? _EqualColumn(
              paths: paths,
              gap: gap,
              startIndex: 0,
              onImageTap: onImageTap,
            )
            : _EqualRow(
              paths: paths,
              gap: gap,
              startIndex: 0,
              onImageTap: onImageTap,
            ),
      3 =>
        TelegramCollageGeometry.useTopThenRestForCount(aspectRatios, 3)
            ? _TopThenRest(
              topPath: paths[0],
              topIndex: 0,
              gap: gap,
              onImageTap: onImageTap,
              bottom: _remainingBelow(
                rest: paths.sublist(1),
                startIndex: 1,
              ),
            )
            : _LargeLeftStack(
              largePath: paths[0],
              largeIndex: 0,
              stackedPaths: paths.sublist(1),
              stackedStartIndex: 1,
              gap: gap,
              onImageTap: onImageTap,
            ),
      4 =>
        TelegramCollageGeometry.useGridFourAllLandscape(aspectRatios)
            ? _RowAlbum(
              paths: paths,
              gap: gap,
              rowSizes: const [2, 2],
              onImageTap: onImageTap,
            )
            : TelegramCollageGeometry.useTopThenRestForCount(aspectRatios, 4)
            ? _TopThenRest(
              topPath: paths[0],
              topIndex: 0,
              gap: gap,
              onImageTap: onImageTap,
              bottom: _remainingBelow(
                rest: paths.sublist(1),
                startIndex: 1,
              ),
            )
            : _LargeLeftStack(
              largePath: paths[0],
              largeIndex: 0,
              stackedPaths: paths.sublist(1),
              stackedStartIndex: 1,
              gap: gap,
              onImageTap: onImageTap,
            ),
      _ when n > 9 => _ScrollableAlbum(
        paths: paths,
        columns: 3,
        slices: CollageGridArrangement.threeByThree.pageSlicesFor(n),
        gap: gap,
        onImageTap: onImageTap,
        onPageChanged: onAlbumPageChanged,
      ),
      _ =>
        TelegramCollageGeometry.useTopThenRestForCount(aspectRatios, n)
            ? _TopThenRest(
              topPath: paths[0],
              topIndex: 0,
              gap: gap,
              onImageTap: onImageTap,
              bottom: _remainingBelow(
                rest: paths.sublist(1),
                startIndex: 1,
              ),
            )
            : _RowAlbum(
              paths: paths,
              gap: gap,
              rowSizes: _telegramRowPlan(n),
              onImageTap: onImageTap,
            ),
    };
  }

  Widget _arrangementBody(CollageGridArrangement arrangement) {
    final slices = arrangement.pageSlicesFor(paths.length);
    if (slices.isEmpty) return const SizedBox.expand();
    if (slices.length == 1) {
      return _pageForSlice(
        slice: slices.first,
        paths: paths,
        columns: arrangement.side,
        gap: gap,
        onImageTap: onImageTap,
      );
    }
    return _ScrollableAlbum(
      paths: paths,
      columns: arrangement.side,
      slices: slices,
      gap: gap,
      onImageTap: onImageTap,
      onPageChanged: onAlbumPageChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final body =
        arrangement == null ? _telegramBody() : _arrangementBody(arrangement!);
    return _CollageThumbhashes(
      hashAt: _hashAt,
      thumbhashOnly: thumbhashOnly,
      tileBorderRadius: tileBorderRadius,
      child: body,
    );
  }
}

List<int> _telegramRowPlan(int count) {
  return switch (count) {
    5 => const [2, 3],
    6 => const [3, 3],
    7 => const [2, 2, 3],
    8 => const [2, 3, 3],
    9 => const [3, 3, 3],
    _ => const [3, 3, 3],
  };
}

Widget _pageForSlice({
  required CollagePageSlice slice,
  required List<String> paths,
  required int columns,
  required double gap,
  void Function(int index, {Rect? sourceRect})? onImageTap,
}) {
  final end = slice.start + slice.count;
  final pagePaths = paths.sublist(slice.start, end);
  return switch (slice.kind) {
    CollagePageKind.fullGrid => _UniformGridPage(
      paths: pagePaths,
      startIndex: slice.start,
      columns: columns,
      gap: gap,
      onImageTap: onImageTap,
    ),
    CollagePageKind.rowBlock => _RowBlockPage(
      paths: pagePaths,
      startIndex: slice.start,
      columns: columns,
      gap: gap,
      onImageTap: onImageTap,
    ),
    CollagePageKind.orphan => _CompactPage(
      paths: pagePaths,
      startIndex: slice.start,
      gap: gap,
      onImageTap: onImageTap,
    ),
  };
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

/// Full N×N page — only used when the page has exactly [columns]² images.
class _UniformGridPage extends StatelessWidget {
  const _UniformGridPage({
    required this.paths,
    required this.startIndex,
    required this.columns,
    required this.gap,
    this.onImageTap,
  });

  final List<String> paths;
  final int startIndex;
  final int columns;
  final double gap;
  final void Function(int index, {Rect? sourceRect})? onImageTap;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.expand();
    final cols = columns < 1 ? 1 : columns;
    final rows = <Widget>[];
    for (var offset = 0; offset < paths.length; offset += cols) {
      final end = (offset + cols).clamp(0, paths.length);
      final rowPaths = paths.sublist(offset, end);
      if (rows.isNotEmpty && gap > 0) {
        rows.add(SizedBox(height: gap));
      }
      rows.add(
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < rowPaths.length; i++) ...[
                if (i > 0 && gap > 0) SizedBox(width: gap),
                Expanded(
                  child: _ImageCell(
                    path: rowPaths[i],
                    index: startIndex + offset + i,
                    onImageTap: onImageTap,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

/// Complete rows of N — fills the card without empty cells in those rows.
class _RowBlockPage extends StatelessWidget {
  const _RowBlockPage({
    required this.paths,
    required this.startIndex,
    required this.columns,
    required this.gap,
    this.onImageTap,
  });

  final List<String> paths;
  final int startIndex;
  final int columns;
  final double gap;
  final void Function(int index, {Rect? sourceRect})? onImageTap;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.expand();
    final cols = columns < 1 ? 1 : columns;
    if (paths.length <= cols) {
      return _EqualRow(
        paths: paths,
        gap: gap,
        startIndex: startIndex,
        onImageTap: onImageTap,
      );
    }
    final rowSizes = <int>[
      for (var i = 0; i < paths.length; i += cols)
        (i + cols <= paths.length) ? cols : paths.length - i,
    ];
    return _RowAlbum(
      paths: paths,
      gap: gap,
      rowSizes: rowSizes,
      startIndex: startIndex,
      onImageTap: onImageTap,
    );
  }
}

/// Orphan leftovers (1…N−1) — no N×N grid (full / side-by-side / large-left).
class _CompactPage extends StatelessWidget {
  const _CompactPage({
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
    final n = paths.length;
    if (n <= 0) return const SizedBox.expand();
    return switch (n) {
      1 => _ImageCell(
        path: paths[0],
        index: startIndex,
        onImageTap: onImageTap,
      ),
      2 => _EqualRow(
        paths: paths,
        gap: gap,
        startIndex: startIndex,
        onImageTap: onImageTap,
      ),
      3 || 4 => _LargeLeftStack(
        largePath: paths[0],
        largeIndex: startIndex,
        stackedPaths: paths.sublist(1),
        stackedStartIndex: startIndex + 1,
        gap: gap,
        onImageTap: onImageTap,
      ),
      _ => _RowAlbum(
        paths: paths,
        gap: gap,
        rowSizes: _compactRowPlan(n),
        startIndex: startIndex,
        onImageTap: onImageTap,
      ),
    };
  }
}

List<int> _compactRowPlan(int count) {
  return switch (count) {
    5 => const [2, 3],
    6 => const [3, 3],
    7 => const [2, 2, 3],
    8 => const [2, 3, 3],
    _ => const [3, 3, 3],
  };
}

/// Full-width top photo + remaining collage below (Telegram landscape hero).
class _TopThenRest extends StatelessWidget {
  const _TopThenRest({
    required this.topPath,
    required this.topIndex,
    required this.gap,
    required this.bottom,
    this.onImageTap,
  });

  final String topPath;
  final int topIndex;
  final double gap;
  final Widget bottom;
  final void Function(int index, {Rect? sourceRect})? onImageTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 1,
          child: _ImageCell(
            path: topPath,
            index: topIndex,
            onImageTap: onImageTap,
          ),
        ),
        if (gap > 0) SizedBox(height: gap),
        Expanded(flex: 1, child: bottom),
      ],
    );
  }
}

/// Full-width stacked cells — 2 landscape photos (Telegram).
class _EqualColumn extends StatelessWidget {
  const _EqualColumn({
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
    return Column(
      children: [
        for (var i = 0; i < paths.length; i++) ...[
          if (i > 0 && gap > 0) SizedBox(height: gap),
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
    this.startIndex = 0,
    this.onImageTap,
  });

  final List<String> paths;
  final double gap;
  final List<int> rowSizes;
  final int startIndex;
  final void Function(int index, {Rect? sourceRect})? onImageTap;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    var offset = 0;
    for (var r = 0; r < rowSizes.length; r++) {
      if (r > 0 && gap > 0) children.add(SizedBox(height: gap));
      final count = rowSizes[r];
      final end = (offset + count).clamp(0, paths.length);
      if (offset >= end) break;
      final slice = paths.sublist(offset, end);
      children.add(
        Expanded(
          child: _EqualRow(
            paths: slice,
            gap: gap,
            startIndex: startIndex + offset,
            onImageTap: onImageTap,
          ),
        ),
      );
      offset = end;
    }
    return Column(children: children);
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

class _ScrollableAlbum extends StatefulWidget {
  const _ScrollableAlbum({
    required this.paths,
    required this.columns,
    required this.slices,
    required this.gap,
    this.onImageTap,
    this.onPageChanged,
  });

  final List<String> paths;
  final int columns;
  final List<CollagePageSlice> slices;
  final double gap;
  final void Function(int index, {Rect? sourceRect})? onImageTap;
  final void Function(int pageIndex, int pageCount)? onPageChanged;

  @override
  State<_ScrollableAlbum> createState() => _ScrollableAlbumState();
}

class _ScrollableAlbumState extends State<_ScrollableAlbum> {
  late final PageController _controller;
  int _page = 0;

  int get _pageCount => widget.slices.length;

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
    if (oldWidget.paths.length != widget.paths.length ||
        oldWidget.slices.length != widget.slices.length) {
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
    if (pageCount <= 0) return const SizedBox.expand();
    return PageView.builder(
      controller: _controller,
      physics: const BouncingScrollPhysics(),
      itemCount: pageCount,
      onPageChanged: _emitPage,
      itemBuilder: (context, pageIndex) {
        return _pageForSlice(
          slice: widget.slices[pageIndex],
          paths: widget.paths,
          columns: widget.columns,
          gap: widget.gap,
          onImageTap: widget.onImageTap,
        );
      },
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

    final uploadOverlay = interaction?.cellOverlayBuilder?.call(index);
    final needsStack =
        selectionMode || hasImportTag || uploadOverlay != null;
    if (needsStack) {
      image = Stack(
        fit: StackFit.expand,
        children: [
          image,
          if (uploadOverlay != null) uploadOverlay,
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
              child: ListenableBuilder(
                listenable: ServiceLocator.get<CartStore>(),
                builder: (context, _) {
                  final pid = interaction?.cartProductIdAt(index) ?? '';
                  final inCart =
                      pid.isNotEmpty &&
                      ServiceLocator.get<CartStore>().contains(pid);
                  return VisitorImportStatusMarks(
                    locked: interaction?.isImportLockedAt(index) ?? false,
                    stock: interaction?.importStockAt(index),
                    alreadyImported:
                        interaction?.importAlreadyImported ?? false,
                    selectionBlocked:
                        interaction?.importSelectionBlocked ?? false,
                    inCart: inCart,
                  );
                },
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
