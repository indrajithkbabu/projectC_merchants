import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/presentation/storeprofile/store_profile_rebuild_when.dart';
import 'package:project_c/services/catalog_direct_upload_service.dart';
import 'package:project_c/services/product_upload_coordinator.dart';
import 'package:project_c/services/store_products_prefetcher.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/storage/session_storage.dart';
import 'package:project_c/storage/store_products_cache.dart';
import 'package:project_c/webservice/catalog_api_client.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';
import 'package:project_c/webservice/store/store_repository.dart';

/// Batch I5 — cold Store Profile loading states (no ServiceLocator network).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _FakePathProvider pathProvider;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('i5_cold_load_');
    pathProvider = _FakePathProvider(tempDir.path);
    PathProviderPlatform.instance = pathProvider;
    StoreProductsCache.instance.debugResetDocsDirCache();
    StoreProfileBloc.debugBeforeDiskHydrateRead = null;
    StoreProductsPrefetcher.instance.debugNetworkEnrichOverride = null;
    StoreProductsPrefetcher.instance.debugResetListingPrefetch();
    await StoreProductsCache.instance.clearAll();
  });

  tearDown(() async {
    StoreProfileBloc.debugBeforeDiskHydrateRead = null;
    StoreProductsPrefetcher.instance.debugNetworkEnrichOverride = null;
    StoreProductsPrefetcher.instance.debugResetListingPrefetch();
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
    String storeName = 'Njw Cold',
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
      storeName: storeName,
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

  group('Batch I5 cold first frame', () {
    test('cold first-frame keeps header seed + honest loading state', () {
      final bloc = buildBloc(storeId: 'cold_first_frame');
      addTearDown(bloc.close);

      expect(bloc.state.storeName, 'Njw Cold');
      expect(bloc.state.products, isEmpty);
      expect(bloc.state.productsResolved, isFalse);
      expect(bloc.state.showProductGridShimmer, isTrue);
      expect(bloc.state.showProductGridEmpty, isFalse);
    });

    test('header rebuild predicate ignores product loading flips', () {
      final bloc = buildBloc(storeId: 'cold_header_pred');
      addTearDown(bloc.close);
      final prev = bloc.state;
      final loading = prev.copyWith(
        isLoadingProducts: true,
        productsResolved: false,
      );
      expect(storeProfileHeaderBuildWhen(prev, loading), isFalse);
      expect(storeProfileGridBuildWhen(prev, loading), isTrue);
    });

    test('disk miss kicks collections without waiting for Ensure', () async {
      const storeId = 'cold_kick';
      final gate = Completer<List<StoreProduct>>();
      var enrichCalls = 0;
      StoreProductsPrefetcher.instance.debugNetworkEnrichOverride = (id) async {
        expect(id, storeId);
        enrichCalls++;
        return gate.future;
      };

      final bloc = buildBloc(storeId: storeId);
      addTearDown(bloc.close);

      bloc.add(const StoreProfileHydrateDiskCache());
      await waitUntil(() => enrichCalls >= 1);

      expect(bloc.state.showProductGridShimmer, isTrue);
      expect(bloc.state.productsResolved, isFalse);

      // Ensure later must not double-fetch (coalesced / in-flight).
      bloc.add(const StoreProfileEnsureInitialCatalogLoads());
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(enrichCalls, 1);

      gate.complete([product('p1'), product('p0')]);
      await waitUntil(() => bloc.state.products.isNotEmpty);

      expect(bloc.state.products.map((p) => p.id), ['p1', 'p0']);
      expect(bloc.state.showProductGridShimmer, isFalse);
      expect(bloc.state.isLoadingProducts, isFalse);
      expect(bloc.state.productsResolved, isTrue);
    });
  });

  group('Batch I5 cold API outcomes', () {
    test('successful API paints products and clears loading', () async {
      const storeId = 'cold_ok';
      StoreProductsPrefetcher.instance.debugNetworkEnrichOverride =
          (_) async => [product('z'), product('a')];

      final bloc = buildBloc(storeId: storeId);
      addTearDown(bloc.close);

      bloc.add(const StoreProfileHydrateDiskCache());
      await waitUntil(() => bloc.state.productsResolved && !bloc.state.isLoadingProducts);

      expect(bloc.state.products.map((p) => p.id), ['z', 'a']);
      expect(bloc.state.showProductGridShimmer, isFalse);
      expect(bloc.state.showProductGridEmpty, isFalse);
    });

    test('empty API resolves honest empty (no shimmer, no fake cards)', () async {
      const storeId = 'cold_empty';
      StoreProductsPrefetcher.instance.debugNetworkEnrichOverride =
          (_) async => const [];

      final bloc = buildBloc(storeId: storeId);
      addTearDown(bloc.close);

      bloc.add(const StoreProfileHydrateDiskCache());
      await waitUntil(() => bloc.state.productsResolved);

      expect(bloc.state.products, isEmpty);
      expect(bloc.state.showProductGridShimmer, isFalse);
      expect(bloc.state.showProductGridEmpty, isTrue);
    });

    test('API failure via prefetcher resolves empty without stuck shimmer', () async {
      const storeId = 'cold_fail';
      // Prefetcher swallows network errors into [] (existing architecture).
      StoreProductsPrefetcher.instance.debugNetworkEnrichOverride =
          (_) async => throw CatalogApiException(
            statusCode: 500,
            code: 'NETWORK_ERROR',
            message: 'boom',
          );

      final bloc = buildBloc(storeId: storeId);
      addTearDown(bloc.close);

      bloc.add(const StoreProfileHydrateDiskCache());
      await waitUntil(() => bloc.state.productsResolved);

      expect(bloc.state.products, isEmpty);
      expect(bloc.state.isLoadingProducts, isFalse);
      expect(bloc.state.showProductGridShimmer, isFalse);
      expect(bloc.state.showProductGridEmpty, isTrue);
    });

    test('private visitor lock keeps products gated (no cold unlock)', () async {
      const storeId = 'cold_private_seed';
      await StoreProductsCache.instance.write(storeId, [product('secret')]);
      StoreProductsCache.instance.evictMemory(storeId);

      final bloc = buildBloc(
        storeId: storeId,
        isOwnStore: false,
        initialCanViewContent: false,
      );
      addTearDown(bloc.close);

      bloc.add(const StoreProfileHydrateDiskCache());
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(bloc.state.canViewContent, isFalse);
      expect(bloc.state.isContentLocked, isTrue);
      expect(bloc.state.products, isEmpty);
      // Locked visitors do not use the product-grid shimmer path.
      expect(bloc.state.showProductGridShimmer, isFalse);
    });
  });

  group('Batch I5 cache / quiet refresh / dispose', () {
    test('memory cache hit paints without cold loading', () async {
      const storeId = 'cold_mem';
      await StoreProductsCache.instance.write(storeId, [product('m1')]);

      final bloc = buildBloc(storeId: storeId);
      addTearDown(bloc.close);

      expect(bloc.state.products.map((p) => p.id), ['m1']);
      expect(bloc.state.productsResolved, isTrue);
      expect(bloc.state.showProductGridShimmer, isFalse);
    });

    test('disk cache hit paints without waiting network', () async {
      const storeId = 'cold_disk';
      await StoreProductsCache.instance.write(storeId, [product('d1')]);
      StoreProductsCache.instance.evictMemory(storeId);

      var networkHits = 0;
      StoreProductsPrefetcher.instance.debugNetworkEnrichOverride = (_) async {
        networkHits++;
        return [product('net')];
      };

      final bloc = buildBloc(storeId: storeId);
      addTearDown(bloc.close);

      bloc.add(const StoreProfileHydrateDiskCache());
      await waitUntil(() => bloc.state.products.isNotEmpty);

      expect(bloc.state.products.map((p) => p.id), ['d1']);
      expect(bloc.state.showProductGridShimmer, isFalse);
      // Early disk hit must not kick cold network.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(networkHits, 0);
    });

    test('prefetched ensure hit paints without cold shimmer', () async {
      const storeId = 'cold_prefetch';
      StoreProductsPrefetcher.instance.debugNetworkEnrichOverride =
          (_) async => [product('w1')];

      // Prime via ensure so LoadCollections takes warm path.
      final warm = await StoreProductsPrefetcher.instance.ensure(storeId);
      expect(warm.map((p) => p.id), ['w1']);

      final bloc = buildBloc(storeId: storeId);
      addTearDown(bloc.close);

      // Memory already has warm write from override.
      expect(bloc.state.products.map((p) => p.id), ['w1']);
      expect(bloc.state.showProductGridShimmer, isFalse);
    });

    test('quiet refresh never clears existing products for loading', () async {
      const storeId = 'cold_quiet';
      await StoreProductsCache.instance.write(storeId, [
        product('keep'),
      ]);

      final gate = Completer<List<StoreProduct>>();
      StoreProductsPrefetcher.instance.debugNetworkEnrichOverride =
          (_) => gate.future;

      final bloc = buildBloc(storeId: storeId);
      addTearDown(bloc.close);

      expect(bloc.state.products.map((p) => p.id), ['keep']);
      expect(bloc.state.showProductGridShimmer, isFalse);

      bloc.add(const StoreProfileQuietRefreshCollections(force: true));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Still painted while refresh in flight.
      expect(bloc.state.products.map((p) => p.id), ['keep']);
      expect(bloc.state.showProductGridShimmer, isFalse);
      expect(bloc.state.isLoadingProducts, isFalse);

      gate.complete([product('keep'), product('new')]);
      await waitUntil(() => bloc.state.products.length == 2);
      expect(bloc.state.products.map((p) => p.id).toSet(), {'keep', 'new'});
      expect(bloc.state.showProductGridShimmer, isFalse);
    });

    test('leaving mid-cold-load does not throw after close', () async {
      const storeId = 'cold_leave';
      final gate = Completer<List<StoreProduct>>();
      StoreProductsPrefetcher.instance.debugNetworkEnrichOverride =
          (_) => gate.future;

      final bloc = buildBloc(storeId: storeId);
      bloc.add(const StoreProfileHydrateDiskCache());
      await waitUntil(() => bloc.state.showProductGridShimmer);

      await bloc.close();
      gate.complete([product('late')]);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(bloc.isClosed, isTrue);
    });

    test('private visitor never starts cold collections kick', () async {
      const storeId = 'cold_locked';
      var networkHits = 0;
      StoreProductsPrefetcher.instance.debugNetworkEnrichOverride = (_) async {
        networkHits++;
        return [product('secret')];
      };

      final bloc = buildBloc(
        storeId: storeId,
        isOwnStore: false,
        initialCanViewContent: false,
      );
      addTearDown(bloc.close);

      bloc.add(const StoreProfileHydrateDiskCache());
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(networkHits, 0);
      expect(bloc.state.products, isEmpty);
      expect(bloc.state.isContentLocked, isTrue);
    });

    test('multi-album order preserved after cold commit', () async {
      const storeId = 'cold_order';
      StoreProductsPrefetcher.instance.debugNetworkEnrichOverride =
          (_) async => [product('c'), product('b'), product('a')];

      final bloc = buildBloc(storeId: storeId);
      addTearDown(bloc.close);

      bloc.add(const StoreProfileHydrateDiskCache());
      await waitUntil(() => bloc.state.products.length == 3);

      // Prefetcher / cache sorts newest-id-first.
      expect(bloc.state.products.map((p) => p.id), ['c', 'b', 'a']);
    });
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
