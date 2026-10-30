import 'dart:async';

import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/models/catalog/wishlist_api_models.dart';
import 'package:project_c/webservice/wishlist/wishlist_repository.dart';

/// Warms `GET /wishlist` after auth + home so the shell Wishlist tab paints
/// without a shimmer on first open.
///
/// Call [prefetch] once the user has an own store (post `/me`). [WishlistRoute]
/// joins [ensure] / [peek] instead of cold-fetching with a blocking loader.
class WishlistPrefetcher {
  WishlistPrefetcher._();

  static final WishlistPrefetcher instance = WishlistPrefetcher._();

  static const _tag = 'WishlistPrefetcher';
  static const defaultLimit = 20;

  Future<WishlistPage>? _inFlight;
  WishlistPage? _warm;

  /// Latest warm page without consuming it (safe for UI paint).
  WishlistPage? peek() => _warm;

  /// Fire-and-forget warm (safe to call repeatedly).
  void prefetch({int limit = defaultLimit}) {
    // ignore: unawaited_futures
    ensure(limit: limit);
  }

  /// Returns warm/in-flight first page, or starts a new fetch.
  Future<WishlistPage> ensure({int limit = defaultLimit}) {
    final warm = _warm;
    if (warm != null) {
      return Future<WishlistPage>.value(warm);
    }

    final existing = _inFlight;
    if (existing != null) return existing;

    return _start(limit: limit);
  }

  /// Force a fresh network page (tab re-select / pull-to-refresh).
  Future<WishlistPage> refresh({int limit = defaultLimit}) {
    return _start(limit: limit);
  }

  /// Drop warm/in-flight handles (logout).
  void invalidate() {
    _warm = null;
    _inFlight = null;
  }

  /// Apply a successful fetch into the warm cache (e.g. after tab quiet load).
  void adopt(WishlistPage page) {
    _warm = page;
  }

  /// Best-effort: product/collection id is in the warm wishlist page.
  bool containsTargetId(String targetId) {
    final id = targetId.trim();
    if (id.isEmpty) return false;
    final page = _warm;
    if (page == null) return false;
    for (final item in page.items) {
      if (item.listingId.trim() == id) return true;
      if (item.id.trim() == id) return true;
    }
    return false;
  }

  Future<WishlistPage> _start({required int limit}) {
    final future = _load(limit: limit);
    _inFlight = future;
    future
        .then((page) {
          if (identical(_inFlight, future)) {
            _warm = page;
          }
        })
        .catchError((_) {
          // Leave [_warm] as-is so UI can keep the last good page.
        })
        .whenComplete(() {
          if (identical(_inFlight, future)) {
            _inFlight = null;
          }
        });
    return future;
  }

  Future<WishlistPage> _load({required int limit}) async {
    AppLog.d(_tag, 'fetchWishlist limit=$limit');
    final page = await ServiceLocator.get<WishlistRepository>().fetchWishlist(
      limit: limit,
    );
    final urls = <String>[
      for (final item in page.items)
        if (item.photo.url.trim().isNotEmpty) item.photo.url.trim(),
    ];
    if (urls.isNotEmpty) {
      // ignore: unawaited_futures
      CatalogImageCache.precacheUrls(
        urls,
        cacheWidth: CatalogImageCache.gridCacheWidth(),
      );
    }
    return page;
  }
}
