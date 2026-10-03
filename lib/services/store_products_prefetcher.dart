import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/catalog_ui_mapper.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/services/product_upload_coordinator.dart';
import 'package:project_c/storage/store_meta_cache.dart';
import 'package:project_c/storage/store_products_cache.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';

/// Warms enriched products + collage image files **before** store profile opens.
///
/// Call [prefetch] on store tap (and optionally for visible listing rows).
/// [StoreProfileBloc] awaits [ensure] so the grid can paint with images ready.
class StoreProductsPrefetcher {
  StoreProductsPrefetcher._();

  static final StoreProductsPrefetcher instance = StoreProductsPrefetcher._();

  static const _tag = 'StoreProductsPrefetcher';

  final Map<String, Future<List<StoreProduct>>> _inFlight = {};

  /// Fire-and-forget warm for [storeId] (safe to call on every tap).
  void prefetch(String storeId, {String coverImageUrl = ''}) {
    final id = storeId.trim();
    if (id.isEmpty || id == 'my_store' || id == 'other_store') return;
    final cover = coverImageUrl.trim();
    if (cover.isNotEmpty) {
      // ignore: unawaited_futures
      StoreMetaCache.instance.writeCover(id, cover);
      // ignore: unawaited_futures
      CatalogImageCache.precacheUrls([cover]);
    }
    // ignore: unawaited_futures
    ensure(id);
  }

  /// Soft-prefetch first stores on the listing (covers + details + images).
  void prefetchVisible(
    Iterable<({String id, String coverImageUrl})> stores, {
    int limit = 4,
  }) {
    var n = 0;
    for (final store in stores) {
      if (n >= limit) break;
      final id = store.id.trim();
      if (id.isEmpty || id == 'my_store' || id == 'other_store') continue;
      prefetch(id, coverImageUrl: store.coverImageUrl);
      n++;
    }
  }

  /// Returns enriched products with collage image files on disk.
  Future<List<StoreProduct>> ensure(String storeId) {
    final id = storeId.trim();
    final existing = _inFlight[id];
    if (existing != null) return existing;

    final future = _load(id);
    _inFlight[id] = future;
    future.whenComplete(() {
      if (identical(_inFlight[id], future)) _inFlight.remove(id);
    });
    return future;
  }

  Future<List<StoreProduct>> _load(String storeId) async {
    final cached = await StoreProductsCache.instance.read(storeId);
    if (cached != null && cached.isNotEmpty) {
      final hidden = ServiceLocator.get<ProductUploadCoordinator>()
          .inFlightListingIdsForStore(storeId);
      final visible =
          hidden.isEmpty
              ? List<StoreProduct>.from(cached)
              : [
                for (final p in cached)
                  if (!hidden.contains(p.id)) p,
              ];
      visible.sort((a, b) => b.id.compareTo(a.id));
      await CatalogImageCache.precacheUrls([
        for (final p in visible) ...p.imagePaths,
      ]);
      return visible;
    }

    return _refreshNetwork(storeId);
  }

  Future<List<StoreProduct>> _refreshNetwork(String storeId) async {
    try {
      final repo = ServiceLocator.get<CollectionRepository>();
      final page = await repo.listCollections(storeId: storeId, limit: 50);
      final hidden = ServiceLocator.get<ProductUploadCoordinator>()
          .inFlightListingIdsForStore(storeId);
      final summaries = [
        for (final summary in page.items)
          if (!hidden.contains(summary.id)) summary,
      ];
      final products = await Future.wait([
        for (final summary in summaries)
          _productFromSummary(repo: repo, storeId: storeId, summary: summary),
      ]);
      // Match store profile: newest listing first (API returns oldest-first).
      products.sort((a, b) => b.id.compareTo(a.id));
      await CatalogImageCache.precacheUrls([
        for (final p in products) ...p.imagePaths,
      ]);
      await StoreProductsCache.instance.write(storeId, products);
      AppLog.d(_tag, 'Prefetched store=$storeId products=${products.length}');
      return products;
    } catch (e) {
      AppLog.e(_tag, 'Prefetch failed store=$storeId', e);
      final cached = await StoreProductsCache.instance.read(storeId);
      return cached ?? const [];
    }
  }

  Future<StoreProduct> _productFromSummary({
    required CollectionRepository repo,
    required String storeId,
    required CollectionSummary summary,
  }) async {
    final cover = CatalogUiMapper.summaryToProduct(summary);
    if (summary.photoCount <= 1) return cover;
    try {
      final detail = await repo.fetchCollection(
        storeId: storeId,
        listingId: summary.id,
      );
      final detailed = CatalogUiMapper.detailToProduct(detail);
      final coverUrl = cover.primaryImagePath?.trim() ?? '';
      if (coverUrl.isEmpty) return detailed;
      final rest =
          detailed.imagePaths.where((p) => p.trim() != coverUrl).toList();
      return detailed.copyWith(imagePaths: [coverUrl, ...rest]);
    } catch (_) {
      return cover;
    }
  }
}
