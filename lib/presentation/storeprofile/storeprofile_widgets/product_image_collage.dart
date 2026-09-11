import 'dart:math' as math;

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
/// - 10: 3 / 4 / 3
class ProductImageCollage extends StatelessWidget {
  const ProductImageCollage({
    super.key,
    required this.imagePaths,
    this.gap = 1.5,
  });

  final List<String> imagePaths;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (imagePaths.isEmpty) {
      return const ColoredBox(color: AppColors.surfaceSecondary);
    }

    final paths = imagePaths;
    return switch (paths.length) {
      1 => _ImageCell(path: paths[0]),
      2 => _EqualRow(paths: paths, gap: gap),
      3 => _LargeLeftStack(
        largePath: paths[0],
        stackedPaths: paths.sublist(1),
        gap: gap,
      ),
      4 => _LargeLeftStack(
        largePath: paths[0],
        stackedPaths: paths.sublist(1),
        gap: gap,
      ),
      _ => _RowAlbum(
        paths: paths,
        gap: gap,
        rowSizes: _rowPlan(paths.length),
      ),
    };
  }
}

List<int> _rowPlan(int count) {
  return switch (count) {
    5 => const [2, 3],
    6 => const [3, 3],
    7 => const [2, 2, 3],
    8 => const [2, 3, 3],
    9 => const [3, 3, 3],
    10 => const [3, 4, 3],
    _ => _distributeRows(count),
  };
}

List<int> _distributeRows(int count) {
  final rows = <int>[];
  var remaining = count;
  while (remaining > 0) {
    if (remaining == 5) {
      rows.addAll([2, 3]);
      break;
    }
    if (remaining == 7) {
      rows.addAll([3, 4]);
      break;
    }
    final take = math.min(4, remaining);
    if (remaining - take == 1) {
      rows.add(take - 1);
      remaining -= take - 1;
    } else {
      rows.add(take);
      remaining -= take;
    }
  }
  return rows;
}

class _LargeLeftStack extends StatelessWidget {
  const _LargeLeftStack({
    required this.largePath,
    required this.stackedPaths,
    required this.gap,
  });

  final String largePath;
  final List<String> stackedPaths;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 2, child: _ImageCell(path: largePath)),
        SizedBox(width: gap),
        Expanded(
          flex: 1,
          child: Column(
            children: [
              for (var i = 0; i < stackedPaths.length; i++) ...[
                if (i > 0) SizedBox(height: gap),
                Expanded(child: _ImageCell(path: stackedPaths[i])),
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
  });

  final List<String> paths;
  final double gap;
  final List<int> rowSizes;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    var offset = 0;
    for (var r = 0; r < rowSizes.length; r++) {
      if (r > 0) children.add(SizedBox(height: gap));
      final count = rowSizes[r];
      final slice = paths.sublist(offset, offset + count);
      offset += count;
      children.add(Expanded(child: _EqualRow(paths: slice, gap: gap)));
    }
    return Column(children: children);
  }
}

class _EqualRow extends StatelessWidget {
  const _EqualRow({required this.paths, required this.gap});

  final List<String> paths;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < paths.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(child: _ImageCell(path: paths[i])),
        ],
      ],
    );
  }
}

class _ImageCell extends StatelessWidget {
  const _ImageCell({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return ProductMediaImage(path: path);
  }
}
