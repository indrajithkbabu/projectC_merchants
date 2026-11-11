/// Flip to `true` (+ uncomment Settings UI) to restore Settings-driven N×N
/// collage pages. Keep `false` for classic Telegram collage layouts.
const bool kEnableCollageImageArrangement = false;

/// Inside-card image arrangement for Group / Single product collages.
///
/// **Currently disabled** — set [kEnableCollageImageArrangement] to `true`
/// and uncomment Settings → Image arrangement to roll this back on.
///
/// Each page is an N×N photo grid. Leftover images continue on the next
/// horizontal page (swipe).
enum CollageGridArrangement {
  twoByTwo,
  threeByThree,
  fourByFour,
}

extension CollageGridArrangementX on CollageGridArrangement {
  /// Columns (and rows) per collage page.
  int get side => switch (this) {
    CollageGridArrangement.twoByTwo => 2,
    CollageGridArrangement.threeByThree => 3,
    CollageGridArrangement.fourByFour => 4,
  };

  /// Max images on one collage page.
  int get pageSize => side * side;

  String get storageValue => '$side';

  String get label => '$side×$side';

  String get subtitle => switch (this) {
    CollageGridArrangement.twoByTwo =>
      'Up to 4 photos per page, then swipe',
    CollageGridArrangement.threeByThree =>
      'Up to 9 photos per page, then swipe',
    CollageGridArrangement.fourByFour =>
      'Up to 16 photos per page, then swipe',
  };

  static const int defaultSide = 2;

  static CollageGridArrangement get defaultArrangement =>
      CollageGridArrangement.twoByTwo;

  static CollageGridArrangement fromSide(int side) {
    return CollageGridArrangement.values.firstWhere(
      (a) => a.side == side,
      orElse: () => CollageGridArrangement.twoByTwo,
    );
  }

  static CollageGridArrangement fromStorage(String? raw) {
    final parsed = int.tryParse(raw?.trim() ?? '');
    if (parsed == null) return defaultArrangement;
    return fromSide(parsed);
  }

  /// How many horizontal collage pages [imageCount] needs for this arrangement.
  int pageCountFor(int imageCount) => pageSlicesFor(imageCount).length;

  /// Build page slices so N×N never shows empty cells.
  ///
  /// 1. Full N×N grid pages
  /// 2. Complete rows of N (no empty slots in those rows)
  /// 3. Leftover 1…N−1 photos on a final slide **without** the N×N grid
  ///    (e.g. 3 photos + 2×2 → page of 2, then 1 alone)
  List<CollagePageSlice> pageSlicesFor(int imageCount) {
    if (imageCount <= 0) return const [];
    final size = pageSize;
    final s = side;
    final out = <CollagePageSlice>[];
    var offset = 0;
    final full = imageCount ~/ size;
    for (var i = 0; i < full; i++) {
      out.add(
        CollagePageSlice(
          start: offset,
          count: size,
          kind: CollagePageKind.fullGrid,
        ),
      );
      offset += size;
    }
    var rem = imageCount - offset;
    if (rem <= 0) return out;
    final rowChunk = (rem ~/ s) * s;
    if (rowChunk > 0) {
      out.add(
        CollagePageSlice(
          start: offset,
          count: rowChunk,
          kind: CollagePageKind.rowBlock,
        ),
      );
      offset += rowChunk;
      rem -= rowChunk;
    }
    if (rem > 0) {
      out.add(
        CollagePageSlice(
          start: offset,
          count: rem,
          kind: CollagePageKind.orphan,
        ),
      );
    }
    return out;
  }
}

/// One horizontal collage page produced by [CollageGridArrangementX.pageSlicesFor].
class CollagePageSlice {
  const CollagePageSlice({
    required this.start,
    required this.count,
    required this.kind,
  });

  final int start;
  final int count;
  final CollagePageKind kind;
}

enum CollagePageKind {
  /// Exactly N×N photos in the Settings grid.
  fullGrid,

  /// One or more complete rows of N (no empty cells).
  rowBlock,

  /// 1…N−1 leftovers — shown without the N×N grid.
  orphan,
}
