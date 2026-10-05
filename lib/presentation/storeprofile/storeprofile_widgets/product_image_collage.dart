import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';

/// Telegram-style media album collage (pattern only; tile size/border unchanged).
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
    this.gap = 1.5,
    this.onImageTap,
  });

  final List<String> imagePaths;

  /// Parallel to [imagePaths] — base64 ThumbHash placeholders when present.
  final List<String> imageThumbhashes;
  final double gap;

  /// Absolute index into [imagePaths] for the tapped collage cell.
  final ValueChanged<int>? onImageTap;

  @override
  Widget build(BuildContext context) {
    if (imagePaths.isEmpty) {
      return const ColoredBox(color: AppColors.surfaceSecondary);
    }

    final paths = imagePaths;
    final signature = paths.join('|');

    // Crossfade layout changes (1→N) so the morph is soft, not a hard cut.
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
        child: _CollageBody(
          paths: paths,
          thumbhashes: imageThumbhashes,
          gap: gap,
          onImageTap: onImageTap,
        ),
      ),
    );
  }
}

class _CollageBody extends StatelessWidget {
  const _CollageBody({
    required this.paths,
    required this.thumbhashes,
    required this.gap,
    this.onImageTap,
  });

  final List<String> paths;
  final List<String> thumbhashes;
  final double gap;
  final ValueChanged<int>? onImageTap;

  String? _hashAt(int index) {
    if (index < 0 || index >= thumbhashes.length) return null;
    final value = thumbhashes[index].trim();
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    return _CollageThumbhashes(
      hashAt: _hashAt,
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
  const _CollageThumbhashes({required this.hashAt, required super.child});

  final String? Function(int index) hashAt;

  static String? of(BuildContext context, int index) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_CollageThumbhashes>();
    return scope?.hashAt(index);
  }

  @override
  bool updateShouldNotify(_CollageThumbhashes oldWidget) => true;
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
  final ValueChanged<int>? onImageTap;

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
        SizedBox(width: gap),
        Expanded(
          flex: 1,
          child: Column(
            children: [
              for (var i = 0; i < stackedPaths.length; i++) ...[
                if (i > 0) SizedBox(height: gap),
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
  final ValueChanged<int>? onImageTap;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    var offset = 0;
    for (var r = 0; r < rowSizes.length; r++) {
      if (r > 0) children.add(SizedBox(height: gap));
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

/// 10+ photos: swipe horizontally through 3×3 pages (vertical scroll stays on
/// the outer product list — nested vertical grids steal that gesture).
class _ScrollableAlbum extends StatelessWidget {
  const _ScrollableAlbum({
    required this.paths,
    required this.gap,
    this.onImageTap,
  });

  static const int _pageSize = 9;

  final List<String> paths;
  final double gap;
  final ValueChanged<int>? onImageTap;

  @override
  Widget build(BuildContext context) {
    final pageCount = (paths.length + _pageSize - 1) ~/ _pageSize;
    return PageView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: pageCount,
      itemBuilder: (context, pageIndex) {
        final start = pageIndex * _pageSize;
        final end = (start + _pageSize).clamp(0, paths.length);
        final pagePaths = paths.sublist(start, end);
        return _PageGrid(
          paths: pagePaths,
          startIndex: start,
          gap: gap,
          onImageTap: onImageTap,
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
  final ValueChanged<int>? onImageTap;

  @override
  Widget build(BuildContext context) {
    // Always lay out a full 3×3 slot grid so page height matches the card;
    // unused trailing cells stay empty.
    return Column(
      children: [
        for (var row = 0; row < 3; row++) ...[
          if (row > 0) SizedBox(height: gap),
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < 3; col++) ...[
                  if (col > 0) SizedBox(width: gap),
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
  final ValueChanged<int>? onImageTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < paths.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
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
  final ValueChanged<int>? onImageTap;

  @override
  Widget build(BuildContext context) {
    final image = ProductMediaImage(
      path: path,
      thumbhash: _CollageThumbhashes.of(context, index),
    );
    if (onImageTap == null) return image;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onImageTap!(index),
      child: image,
    );
  }
}
