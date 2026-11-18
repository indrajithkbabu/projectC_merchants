import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/store_warm_qa.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/services/store_products_prefetcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final prefetcher = StoreProductsPrefetcher.instance;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// Seed catalog without starting enrich ([setListingCatalog] respects pause).
  void seedCatalogPaused(
    List<({String id, String coverImageUrl})> stores,
  ) {
    prefetcher.pauseListingViewportPrefetch();
    prefetcher.setListingCatalog(stores);
  }

  setUp(() {
    prefetcher.debugResetListingPrefetch();
    StoreWarmQa.enrichInFlight = 0;
    StoreWarmQa.enrichInFlightPeak = 0;
  });

  tearDown(() {
    prefetcher.debugResetListingPrefetch();
  });

  group('selectVisibleStoreEnrichIds', () {
    test('prioritizes actual visible stores over catalog order', () {
      final selected = selectVisibleStoreEnrichIds(
        visibleOrdered: const ['s3', 's4'],
        upcomingOrdered: const ['s5', 's6'],
        lastOpened: null,
        enrichLimit: 3,
      );
      expect(selected, ['s3', 's4', 's5']);
      expect(selected, isNot(contains('s1')));
      expect(selected, isNot(contains('s2')));
    });

    test('includes upcoming after visible within enrichLimit', () {
      final selected = selectVisibleStoreEnrichIds(
        visibleOrdered: const ['s2'],
        upcomingOrdered: const ['s3', 's4'],
        enrichLimit: 3,
      );
      expect(selected, ['s2', 's3', 's4']);
    });

    test('bounds enrichment count', () {
      final selected = selectVisibleStoreEnrichIds(
        visibleOrdered: const ['a', 'b', 'c', 'd'],
        upcomingOrdered: const ['e', 'f'],
        enrichLimit: 3,
      );
      expect(selected.length, 3);
      expect(selected, ['a', 'b', 'c']);
    });

    test('suppresses duplicate ids across visible/upcoming/lastOpened', () {
      final selected = selectVisibleStoreEnrichIds(
        visibleOrdered: const ['a', 'b'],
        upcomingOrdered: const ['b', 'c'],
        lastOpened: 'a',
        enrichLimit: 3,
      );
      expect(selected, ['a', 'b', 'c']);
    });

    test('slots lastOpened when still under enrichLimit', () {
      final selected = selectVisibleStoreEnrichIds(
        visibleOrdered: const ['x'],
        upcomingOrdered: const [],
        lastOpened: 'prior',
        enrichLimit: 3,
      );
      expect(selected, ['x', 'prior']);
    });
  });

  group('selectListingUpcomingIds', () {
    test('selects rows immediately after last visible index', () {
      final upcoming = selectListingUpcomingIds(
        catalogIds: const ['s1', 's2', 's3', 's4', 's5'],
        visibleOrdered: const ['s2', 's3'],
        upcomingCount: 2,
      );
      expect(upcoming, ['s4', 's5']);
    });

    test('returns empty when visible is at end of catalog', () {
      final upcoming = selectListingUpcomingIds(
        catalogIds: const ['s1', 's2'],
        visibleOrdered: const ['s2'],
        upcomingCount: 2,
      );
      expect(upcoming, isEmpty);
    });
  });

  group('viewport queue + concurrency', () {
    test('enriches from viewport visibility, not list head', () async {
      final started = <String>[];
      final gates = <String, Completer<List<StoreProduct>>>{};
      prefetcher.debugListingEnrichOverride = (id) {
        started.add(id);
        final c = Completer<List<StoreProduct>>();
        gates[id] = c;
        return c.future;
      };

      seedCatalogPaused([
        for (var i = 1; i <= 8; i++) (id: 's$i', coverImageUrl: ''),
      ]);
      prefetcher.debugListingEnrichOverride = (id) {
        started.add(id);
        final c = Completer<List<StoreProduct>>();
        gates[id] = c;
        return c.future;
      };
      prefetcher.resumeListingViewportPrefetch();

      prefetcher.noteListingVisibility('s4', visibleFraction: 0.9);
      prefetcher.noteListingVisibility('s5', visibleFraction: 0.8);
      prefetcher.debugFlushListingViewport();

      expect(prefetcher.debugListingEnrichWanted.toList(), ['s4', 's5', 's6']);
      expect(started, isNot(contains('s1')));
      expect(started, isNot(contains('s2')));
      expect(started.first, 's4');

      for (final c in gates.values) {
        if (!c.isCompleted) c.complete(const []);
      }
      await settle();
    });

    test('caps concurrent listing enrich at listingEnrichMaxConcurrent', () async {
      final started = <String>[];
      final gates = <String, Completer<List<StoreProduct>>>{};

      seedCatalogPaused([
        for (var i = 1; i <= 6; i++) (id: 'c$i', coverImageUrl: ''),
      ]);
      prefetcher.debugListingEnrichOverride = (id) {
        started.add(id);
        final c = Completer<List<StoreProduct>>();
        gates[id] = c;
        return c.future;
      };
      prefetcher.resumeListingViewportPrefetch();

      for (final id in ['c1', 'c2', 'c3', 'c4']) {
        prefetcher.noteListingVisibility(id, visibleFraction: 1.0);
      }
      prefetcher.debugFlushListingViewport();

      expect(
        prefetcher.debugListingEnrichRunning,
        lessThanOrEqualTo(
          StoreProductsPrefetcher.listingEnrichMaxConcurrent,
        ),
      );
      expect(
        started.length,
        lessThanOrEqualTo(
          StoreProductsPrefetcher.listingEnrichMaxConcurrent,
        ),
      );
      expect(
        prefetcher.debugListingEnrichWanted.length,
        lessThanOrEqualTo(StoreProductsPrefetcher.listingEnrichLimit),
      );

      final firstWave = List<String>.from(started);
      for (final id in firstWave) {
        gates[id]!.complete(const []);
      }
      await settle();
      expect(
        prefetcher.debugListingEnrichRunning,
        lessThanOrEqualTo(
          StoreProductsPrefetcher.listingEnrichMaxConcurrent,
        ),
      );

      for (final c in gates.values) {
        if (!c.isCompleted) c.complete(const []);
      }
      await settle();
    });

    test('does not re-queue a store already warm / fresh', () async {
      final started = <String>[];
      prefetcher.debugListingEnrichOverride = (id) async {
        started.add(id);
        return const [];
      };

      seedCatalogPaused([
        (id: 'warm1', coverImageUrl: ''),
        (id: 'warm2', coverImageUrl: ''),
      ]);
      prefetcher.debugListingEnrichOverride = (id) async {
        started.add(id);
        return const [];
      };
      prefetcher.resumeListingViewportPrefetch();

      prefetcher.noteListingVisibility('warm1', visibleFraction: 1.0);
      prefetcher.debugFlushListingViewport();
      await settle();
      expect(started.where((e) => e == 'warm1').length, 1);

      started.clear();
      prefetcher.noteListingVisibility('warm1', visibleFraction: 0.95);
      prefetcher.debugFlushListingViewport();
      await settle();
      expect(started.where((e) => e == 'warm1'), isEmpty);
    });

    test('rapid scroll keeps only latest visible wanted set', () async {
      final started = <String>[];
      final gates = <String, Completer<List<StoreProduct>>>{};

      seedCatalogPaused([
        for (var i = 1; i <= 10; i++) (id: 'r$i', coverImageUrl: ''),
      ]);
      prefetcher.debugListingEnrichOverride = (id) {
        started.add(id);
        final c = Completer<List<StoreProduct>>();
        gates[id] = c;
        return c.future;
      };
      prefetcher.resumeListingViewportPrefetch();

      for (var i = 1; i <= 8; i++) {
        prefetcher.noteListingVisibility('r$i', visibleFraction: 0.05);
      }
      prefetcher.noteListingVisibility('r7', visibleFraction: 0.9);
      prefetcher.noteListingVisibility('r8', visibleFraction: 0.85);
      prefetcher.debugFlushListingViewport();

      expect(prefetcher.debugListingEnrichWanted.toList(), ['r7', 'r8', 'r9']);
      expect(started, isNot(contains('r1')));
      expect(started, isNot(contains('r2')));

      for (final c in gates.values) {
        if (!c.isCompleted) c.complete(const []);
      }
      await settle();
    });

    test('leaving Home pauses and clears queue (in-flight may finish)', () async {
      final started = <String>[];
      final gates = <String, Completer<List<StoreProduct>>>{};

      seedCatalogPaused([
        for (var i = 1; i <= 5; i++) (id: 'h$i', coverImageUrl: ''),
      ]);
      prefetcher.debugListingEnrichOverride = (id) {
        started.add(id);
        final c = Completer<List<StoreProduct>>();
        gates[id] = c;
        return c.future;
      };
      prefetcher.resumeListingViewportPrefetch();

      prefetcher.noteListingVisibility('h1', visibleFraction: 1.0);
      prefetcher.noteListingVisibility('h2', visibleFraction: 1.0);
      prefetcher.debugFlushListingViewport();
      expect(prefetcher.debugListingEnrichRunning, greaterThan(0));

      prefetcher.pauseListingViewportPrefetch();
      expect(prefetcher.debugListingPrefetchPaused, isTrue);
      expect(prefetcher.debugListingEnrichQueue, isEmpty);
      expect(prefetcher.debugListingEnrichWanted, isEmpty);

      final inFlight = List<String>.from(started);
      for (final id in inFlight) {
        gates[id]?.complete(const []);
      }
      await settle();
      expect(prefetcher.debugListingEnrichQueue, isEmpty);
      expect(prefetcher.debugListingPrefetchPaused, isTrue);
    });

    test('catalog seed while paused does not start enrich', () async {
      final started = <String>[];
      prefetcher.debugListingEnrichOverride = (id) async {
        started.add(id);
        return const [];
      };
      prefetcher.pauseListingViewportPrefetch();
      prefetcher.setListingCatalog([
        (id: 'p1', coverImageUrl: ''),
        (id: 'p2', coverImageUrl: ''),
      ]);
      await settle();
      expect(started, isEmpty);
      expect(prefetcher.debugListingPrefetchPaused, isTrue);
    });

    test('rapid Store A → Store B keeps listing paused and isolates cancel', () async {
      final started = <String>[];
      final gates = <String, Completer<List<StoreProduct>>>{};

      seedCatalogPaused([
        (id: 'tapA', coverImageUrl: ''),
        (id: 'tapB', coverImageUrl: ''),
      ]);
      prefetcher.debugListingEnrichOverride = (id) {
        started.add(id);
        final c = Completer<List<StoreProduct>>();
        gates[id] = c;
        return c.future;
      };
      prefetcher.resumeListingViewportPrefetch();

      prefetcher.noteListingVisibility('tapA', visibleFraction: 1.0);
      prefetcher.debugFlushListingViewport();
      expect(started, contains('tapA'));

      // Mimic listing route: pause on profile push for A, then B.
      prefetcher.pauseListingViewportPrefetch();
      prefetcher.noteProfileOpened('tapA');
      prefetcher.resumeListingViewportPrefetch();
      prefetcher.pauseListingViewportPrefetch();
      prefetcher.noteProfileOpened('tapB');
      prefetcher.cancelCollageWarmForStore('tapA');

      expect(prefetcher.debugListingPrefetchPaused, isTrue);
      expect(prefetcher.debugListingEnrichWanted, isEmpty);

      for (final c in gates.values) {
        if (!c.isCompleted) c.complete(const []);
      }
      await settle();
    });

    test('owner-scoped collage cancel is isolated from listing pause', () {
      final ownerA = CatalogImageCache.createWarmOwner(debugLabel: 'storeA');
      final ownerB = CatalogImageCache.createWarmOwner(debugLabel: 'storeB');
      expect(ownerA.isCancelled, isFalse);
      expect(ownerB.isCancelled, isFalse);

      prefetcher.noteProfileOpened('storeA');
      prefetcher.cancelCollageWarmForStore('storeA');
      CatalogImageCache.cancelOffscreenWarm(ownerA, reason: 'test');

      prefetcher.pauseListingViewportPrefetch();
      expect(ownerB.isCancelled, isFalse);
      expect(prefetcher.debugListingPrefetchPaused, isTrue);

      CatalogImageCache.cancelOffscreenWarm(ownerB, reason: 'cleanup');
    });

    test('already-fresh store is skipped when a sibling becomes visible', () async {
      final started = <String>[];
      prefetcher.debugListingEnrichOverride = (id) async {
        started.add(id);
        return const [];
      };

      // Warm mem1 alone (no upcoming sibling yet).
      seedCatalogPaused([(id: 'mem1', coverImageUrl: '')]);
      prefetcher.debugListingEnrichOverride = (id) async {
        started.add(id);
        return const [];
      };
      prefetcher.resumeListingViewportPrefetch();
      prefetcher.noteListingVisibility('mem1', visibleFraction: 1.0);
      prefetcher.debugFlushListingViewport();
      await settle();
      expect(started, ['mem1']);
      started.clear();

      // Expand catalog; mem1 stays fresh, mem2 is new.
      prefetcher.setListingCatalog([
        (id: 'mem1', coverImageUrl: ''),
        (id: 'mem2', coverImageUrl: ''),
      ]);
      prefetcher.noteListingVisibility('mem1', visibleFraction: 1.0);
      prefetcher.noteListingVisibility('mem2', visibleFraction: 1.0);
      prefetcher.debugFlushListingViewport();
      await settle();
      expect(started, isNot(contains('mem1')));
      expect(started, contains('mem2'));
    });
  });
}
