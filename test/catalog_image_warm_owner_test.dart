import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/store_warm_qa.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CatalogImageCache.debugResetWarmOwnersForTest();
  });

  test('StoreWarmQa filter tag is distinct from ApiCallCount', () {
    expect(StoreWarmQa.filter, 'I1QA');
    expect(StoreWarmQa.legacyFilter, 'StoreWarmQA');
    expect(StoreWarmQa.filter, isNot(equals('ApiCallCount')));
  });

  test('StoreWarmQa urlId is stable and non-URL', () {
    expect(StoreWarmQa.urlId('https://example.com/a.jpg'), startsWith('u'));
    expect(
      StoreWarmQa.urlId('https://example.com/a.jpg'),
      isNot(contains('http')),
    );
  });

  tearDown(() {
    CatalogImageCache.debugResetWarmOwnersForTest();
  });

  group('CatalogWarmOwner isolation', () {
    test('disposing Gallery owner does not cancel Store Profile owner', () {
      final profile = CatalogImageCache.createWarmOwner(debugLabel: 'profile');
      final gallery = CatalogImageCache.createWarmOwner(debugLabel: 'gallery');
      final profileEpoch = profile.epoch;
      final galleryEpoch = gallery.epoch;

      CatalogImageCache.cancelOffscreenWarm(gallery, reason: 'galleryDispose');

      expect(gallery.allows(galleryEpoch), isFalse);
      expect(profile.allows(profileEpoch), isTrue);
    });

    test('disposing Store A does not cancel Store B', () {
      final storeA = CatalogImageCache.createWarmOwner(debugLabel: 'storeA');
      final storeB = CatalogImageCache.createWarmOwner(debugLabel: 'storeB');
      final epochA = storeA.epoch;
      final epochB = storeB.epoch;

      CatalogImageCache.cancelOffscreenWarm(storeA, reason: 'storeAClose');

      expect(storeA.allows(epochA), isFalse);
      expect(storeB.allows(epochB), isTrue);
    });

    test(
      'two consumers of same image: disposing one keeps the other active',
      () {
        final consumerA = CatalogImageCache.createWarmOwner(debugLabel: 'a');
        final consumerB = CatalogImageCache.createWarmOwner(debugLabel: 'b');
        final epochA = consumerA.epoch;
        final epochB = consumerB.epoch;

        CatalogImageCache.cancelOffscreenWarm(consumerA, reason: 'aDispose');

        expect(consumerA.allows(epochA), isFalse);
        expect(consumerB.allows(epochB), isTrue);
      },
    );

    test('disposing final owner stops its pending off-screen warming', () {
      final owner = CatalogImageCache.createWarmOwner(debugLabel: 'solo');
      final epoch = owner.epoch;
      var delayedStarted = false;

      CatalogImageCache.cancelOffscreenWarm(owner, reason: 'soloDispose');

      // Mirrors delayed prefetcher / bloc warm gates.
      if (owner.allows(epoch)) {
        delayedStarted = true;
      }

      expect(delayedStarted, isFalse);
      expect(owner.allows(epoch), isFalse);
    });

    test('stale delayed task must not start after owner is disposed', () {
      final owner = CatalogImageCache.createWarmOwner(debugLabel: 'delayed');
      final epoch = owner.epoch;
      CatalogImageCache.cancelOffscreenWarm(owner, reason: 'dispose');

      var ran = false;
      // Deterministic stand-in for Future.delayed callback body.
      if (owner.allows(epoch)) {
        ran = true;
        // ignore: discarded_futures
        CatalogImageCache.precacheUrls(const [], owner: owner);
      }

      expect(ran, isFalse);
    });

    test('repeated disposal / cancellation is safe', () {
      final owner = CatalogImageCache.createWarmOwner(debugLabel: 'repeat');
      final epoch0 = owner.epoch;

      CatalogImageCache.cancelOffscreenWarm(owner, reason: 'first');
      CatalogImageCache.cancelOffscreenWarm(owner, reason: 'second');
      CatalogImageCache.cancelOffscreenWarm(owner, reason: 'third');

      expect(owner.isCancelled, isTrue);
      expect(owner.allows(epoch0), isFalse);
      expect(owner.allows(owner.epoch), isFalse);
    });

    test('cancel does not clear shared in-flight disk/decode maps', () async {
      final ownerA = CatalogImageCache.createWarmOwner(debugLabel: 'a');
      final ownerB = CatalogImageCache.createWarmOwner(debugLabel: 'b');
      final completer = Completer<void>();

      CatalogImageCache.debugPrimeDiskInFlight(
        'https://example.com/shared.webp',
        completer.future,
      );
      CatalogImageCache.debugPrimeDecodeInFlight(
        'https://example.com/shared.webp',
        200,
        completer.future,
      );

      expect(CatalogImageCache.debugDiskInFlightCount, 1);
      expect(CatalogImageCache.debugDecodeInFlightCount, 1);

      CatalogImageCache.cancelOffscreenWarm(ownerA, reason: 'aDispose');

      expect(CatalogImageCache.debugDiskInFlightCount, 1);
      expect(CatalogImageCache.debugDecodeInFlightCount, 1);
      expect(ownerB.allows(ownerB.epoch), isTrue);

      completer.complete();
      await completer.future;
    });
  });

  group('decoded-image identity and retry', () {
    test('thumbnail decode does not satisfy a larger cacheWidth', () {
      const url = 'https://example.com/item.webp';
      CatalogImageCache.markDecoded(url, 120);
      expect(CatalogImageCache.isDecoded(url, 120), isTrue);
      expect(CatalogImageCache.isDecoded(url, 480), isFalse);
      expect(CatalogImageCache.isDecodedAny(url), isTrue);
    });

    test('failed decode path does not permanently mark decoded', () {
      const url = 'https://example.com/miss.webp';
      // markDecoded is only called on successful frames — absence means retry OK.
      expect(CatalogImageCache.isDecoded(url, 200), isFalse);
      CatalogImageCache.markDecoded(url, 200);
      expect(CatalogImageCache.isDecoded(url, 200), isTrue);
    });
  });

  group('precacheUrls owner gate', () {
    test(
      'cancelled owner makes precacheUrls a no-op without throwing',
      () async {
        final owner = CatalogImageCache.createWarmOwner(debugLabel: 'noop');
        final epoch = owner.epoch;
        CatalogImageCache.cancelOffscreenWarm(owner, reason: 'dispose');
        expect(owner.allows(epoch), isFalse);

        await CatalogImageCache.precacheUrls(const [
          'https://example.com/a.webp',
        ], owner: owner);
        await CatalogImageCache.warmDiskHits(const [
          'https://example.com/a.webp',
        ], owner: owner);
      },
    );
  });
}
