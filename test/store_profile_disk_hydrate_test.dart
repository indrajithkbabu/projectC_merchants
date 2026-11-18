import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/services/catalog_direct_upload_service.dart';
import 'package:project_c/services/product_upload_coordinator.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/storage/session_storage.dart';
import 'package:project_c/services/store_products_prefetcher.dart';
import 'package:project_c/storage/store_products_cache.dart';
import 'package:project_c/webservice/catalog_api_client.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';
import 'package:project_c/webservice/store/store_repository.dart';

/// Batch I3 — early disk hydrate vs deferred Ensure.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _FakePathProvider pathProvider;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('i3_disk_hydrate_');
    pathProvider = _FakePathProvider(tempDir.path);
    PathProviderPlatform.instance = pathProvider;
    StoreProductsCache.instance.debugResetDocsDirCache();
    StoreProfileBloc.debugBeforeDiskHydrateRead = null;
    StoreProductsPrefetcher.instance.debugNetworkEnrichOverride = null;
    await StoreProductsCache.instance.clearAll();
  });

  tearDown(() async {
    StoreProfileBloc.debugBeforeDiskHydrateRead = null;
    StoreProductsPrefetcher.instance.debugNetworkEnrichOverride = null;
    await StoreProductsCache.instance.clearAll();
    StoreProductsCache.instance.debugResetDocsDirCache();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  StoreProduct product(String id) => StoreProduct(
    id: id,
    title: 'Product $id',
    description: '',
    tags: const [],
    imagePaths: const ['https://cdn.example/p.jpg'],
  );

  /// Concurrent hydrate may finish after [pumpEventQueue]; poll briefly.
  Future<void> waitUntil(
    bool Function() predicate, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final sw = Stopwatch()..start();
    while (!predicate()) {
      if (sw.elapsed > timeout) {
        fail('Condition not met within $timeout');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  StoreProfileBloc buildBloc({
    required String storeId,
    bool isOwnStore = true,
    bool? initialCanViewContent,
    List<StoreProduct>? products,
  }) {
    final collections = _FakeCollectionRepository();
    final stores = _FakeStoreRepository();
    final session = CatalogSession(
      storage: SessionStorage(),
      apiClient: CatalogApiClient(sessionStorage: SessionStorage()),
    );
    final uploads = ProductUploadCoordinator(
      collectionRepository: collections,
      directUploadService: CatalogDirectUploadService(
        collectionRepository: collections,
      ),
    );
    return StoreProfileBloc(
      storeName: 'Test Store',
      members: const [],
      products: products,
      isOwnStore: isOwnStore,
      storeId: storeId,
      initialCanViewContent: initialCanViewContent,
      deferInitialCatalogLoads: true,
      collectionRepository: collections,
      storeRepository: stores,
      session: session,
      uploadCoordinator: uploads,
    );
  }

  group('Batch I3 disk hydrate', () {
    test('memory cache hit skips unnecessary disk hydration', () async {
      const storeId = 'store_mem_hit';
      final seeded = [product('p_mem')];
      await StoreProductsCache.instance.write(storeId, seeded);

      final bloc = buildBloc(storeId: storeId);
      addTearDown(bloc.close);

      expect(bloc.state.products, isNotEmpty);
      expect(bloc.state.productsResolved, isTrue);
      expect(bloc.state.showProductGridShimmer, isFalse);

      bloc.add(const StoreProfileHydrateDiskCache());
      await pumpEventQueue();

      expect(bloc.state.products.map((p) => p.id), ['p_mem']);
      expect(bloc.state.productsResolved, isTrue);
      expect(bloc.state.showProductGridShimmer, isFalse);
    });

    test('memory miss + disk hit paints before Ensure', () async {
      const storeId = 'store_disk_hit';
      await StoreProductsCache.instance.write(storeId, [product('p_disk')]);
      StoreProductsCache.instance.evictMemory(storeId);
      expect(StoreProductsCache.instance.readMemory(storeId), isNull);

      final bloc = buildBloc(storeId: storeId);
      addTearDown(bloc.close);

      expect(bloc.state.products, isEmpty);
      expect(bloc.state.productsResolved, isFalse);
      expect(bloc.state.showProductGridShimmer, isTrue);

      bloc.add(const StoreProfileHydrateDiskCache());
      await waitUntil(() => bloc.state.products.isNotEmpty);

      expect(bloc.state.products.map((p) => p.id), ['p_disk']);
      expect(bloc.state.productsResolved, isTrue);
      expect(bloc.state.isLoadingProducts, isFalse);
      expect(bloc.state.showProductGridShimmer, isFalse);

      // Ensure / LoadCollections must not wipe the early grid.
      bloc.add(const StoreProfileLoadCollections());
      await pumpEventQueue();
      expect(bloc.state.products.map((p) => p.id), ['p_disk']);
      expect(bloc.state.showProductGridShimmer, isFalse);
    });

    test('memory miss + disk miss keeps honest shimmer', () async {
      const storeId = 'store_disk_miss';
      // Hang network so I5 early collections kick stays in loading (honest).
      final networkGate = Completer<List<StoreProduct>>();
      StoreProductsPrefetcher.instance.debugNetworkEnrichOverride =
          (_) => networkGate.future;
      addTearDown(() {
        if (!networkGate.isCompleted) {
          networkGate.complete(const []);
        }
      });

      final bloc = buildBloc(storeId: storeId);
      addTearDown(bloc.close);

      expect(bloc.state.showProductGridShimmer, isTrue);

      bloc.add(const StoreProfileHydrateDiskCache());
      await waitUntil(() {
        // Miss leaves unresolved; wait until hydrate started then settled.
        return !bloc.state.productsResolved && bloc.state.products.isEmpty;
      });
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(bloc.state.products, isEmpty);
      expect(bloc.state.productsResolved, isFalse);
      expect(bloc.state.showProductGridShimmer, isTrue);
    });

    test('empty disk does not mark products resolved', () async {
      const storeId = 'store_empty_disk';
      // Write then clear so any empty file path is a true miss.
      await StoreProductsCache.instance.write(storeId, [product('gone')]);
      await StoreProductsCache.instance.invalidate(storeId);

      final networkGate = Completer<List<StoreProduct>>();
      StoreProductsPrefetcher.instance.debugNetworkEnrichOverride =
          (_) => networkGate.future;
      addTearDown(() {
        if (!networkGate.isCompleted) {
          networkGate.complete(const []);
        }
      });

      final bloc = buildBloc(storeId: storeId);
      addTearDown(bloc.close);

      var hydrateEntered = false;
      StoreProfileBloc.debugBeforeDiskHydrateRead = () async {
        hydrateEntered = true;
      };
      bloc.add(const StoreProfileHydrateDiskCache());
      await waitUntil(() => hydrateEntered);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(bloc.state.productsResolved, isFalse);
      expect(bloc.state.products, isEmpty);
      expect(bloc.state.showProductGridShimmer, isTrue);
    });

    test('API response before disk is not overwritten by stale disk', () async {
      const storeId = 'store_race_network';
      await StoreProductsCache.instance.write(storeId, [product('p_stale')]);
      StoreProductsCache.instance.evictMemory(storeId);

      final gate = Completer<void>();
      var hydrateAtGate = false;
      StoreProfileBloc.debugBeforeDiskHydrateRead = () async {
        hydrateAtGate = true;
        await gate.future;
      };

      final bloc = buildBloc(storeId: storeId);
      addTearDown(bloc.close);

      bloc.add(const StoreProfileHydrateDiskCache());
      await waitUntil(() => hydrateAtGate);

      bloc.add(
        StoreProfileProductsReplaced([product('p_network')], silent: true),
      );
      await waitUntil(
        () => bloc.state.products.any((p) => p.id == 'p_network'),
      );
      expect(bloc.state.productsResolved, isTrue);

      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(bloc.state.products.map((p) => p.id), ['p_network']);
      expect(bloc.state.showProductGridShimmer, isFalse);
    });

    test(
      'disk response first stays visible during refresh short-circuit',
      () async {
        const storeId = 'store_disk_then_refresh';
        await StoreProductsCache.instance.write(storeId, [product('p_disk')]);
        StoreProductsCache.instance.evictMemory(storeId);

        final bloc = buildBloc(storeId: storeId);
        addTearDown(bloc.close);

        bloc.add(const StoreProfileHydrateDiskCache());
        await waitUntil(() => bloc.state.products.isNotEmpty);
        expect(bloc.state.products.map((p) => p.id), ['p_disk']);

        bloc.add(const StoreProfileLoadCollections());
        await pumpEventQueue();

        expect(bloc.state.products.map((p) => p.id), ['p_disk']);
        expect(bloc.state.productsResolved, isTrue);
        expect(bloc.state.showProductGridShimmer, isFalse);
      },
    );

    test('bloc closing during disk hydrate does not emit afterward', () async {
      const storeId = 'store_close_mid_hydrate';
      await StoreProductsCache.instance.write(storeId, [product('p_disk')]);
      StoreProductsCache.instance.evictMemory(storeId);

      final gate = Completer<void>();
      var atGate = false;
      StoreProfileBloc.debugBeforeDiskHydrateRead = () async {
        atGate = true;
        await gate.future;
      };

      final bloc = buildBloc(storeId: storeId);
      bloc.add(const StoreProfileHydrateDiskCache());
      await waitUntil(() => atGate);

      await bloc.close();
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      // Closed bloc keeps last state; hydrate must not throw / reopen emit.
      expect(bloc.isClosed, isTrue);
      expect(bloc.state.products, isEmpty);
    });

    test('private visitor lock skips disk hydrate', () async {
      const storeId = 'store_private_lock';
      await StoreProductsCache.instance.write(storeId, [product('p_secret')]);
      StoreProductsCache.instance.evictMemory(storeId);

      final bloc = buildBloc(
        storeId: storeId,
        isOwnStore: false,
        initialCanViewContent: false,
      );
      addTearDown(bloc.close);

      expect(bloc.state.canViewContent, isFalse);
      expect(bloc.state.products, isEmpty);

      var probe = false;
      StoreProfileBloc.debugBeforeDiskHydrateRead = () async {
        probe = true;
      };
      bloc.add(const StoreProfileHydrateDiskCache());
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(probe, isFalse);
      expect(bloc.state.products, isEmpty);
      expect(bloc.state.productsResolved, isFalse);
    });

    test('duplicate HydrateDiskCache events only start once', () async {
      const storeId = 'store_dedupe_hydrate';
      await StoreProductsCache.instance.write(storeId, [product('p1')]);
      StoreProductsCache.instance.evictMemory(storeId);

      var probeCount = 0;
      StoreProfileBloc.debugBeforeDiskHydrateRead = () async {
        probeCount++;
      };

      final bloc = buildBloc(storeId: storeId);
      addTearDown(bloc.close);

      bloc.add(const StoreProfileHydrateDiskCache());
      bloc.add(const StoreProfileHydrateDiskCache());
      await waitUntil(() => bloc.state.products.isNotEmpty);

      expect(probeCount, 1);
      expect(bloc.state.products.map((p) => p.id), ['p1']);
    });

    test(
      'cache ordering newest-id-first preserved after early hydrate',
      () async {
        const storeId = 'store_order';
        await StoreProductsCache.instance.write(storeId, [
          product('a'),
          product('z'),
          product('m'),
        ]);
        StoreProductsCache.instance.evictMemory(storeId);
        expect(StoreProductsCache.instance.readMemory(storeId), isNull);
        // Confirm disk round-trip before exercising the bloc.
        final fromDisk = await StoreProductsCache.instance.read(storeId);
        expect(fromDisk?.map((p) => p.id).toSet(), {'a', 'z', 'm'});
        StoreProductsCache.instance.evictMemory(storeId);

        final bloc = buildBloc(storeId: storeId);
        addTearDown(bloc.close);

        bloc.add(const StoreProfileHydrateDiskCache());
        await waitUntil(() => bloc.state.products.length == 3);

        expect(bloc.state.products.map((p) => p.id).toList(), ['z', 'm', 'a']);
      },
    );
  });
}

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

class _FakeCollectionRepository extends Fake implements CollectionRepository {}

class _FakeStoreRepository extends Fake implements StoreRepository {}
