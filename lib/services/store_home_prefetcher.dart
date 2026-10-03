import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/catalog_page.dart';
import 'package:project_c/models/catalog/catalog_store.dart';
import 'package:project_c/webservice/store/store_repository.dart';

/// Warms `GET /home` before the Stores tab mounts (cold start / post-auth).
///
/// Call [prefetch] as soon as auth tokens are ready. [StoreListingBloc]
/// awaits [ensure] so the first paint can use the in-flight or completed page.
class StoreHomePrefetcher {
  StoreHomePrefetcher._();

  static final StoreHomePrefetcher instance = StoreHomePrefetcher._();

  static const _tag = 'StoreHomePrefetcher';
  static const defaultLimit = 40;

  Future<CatalogPage<CatalogStore>>? _inFlight;
  CatalogPage<CatalogStore>? _warm;

  /// Fire-and-forget warm (safe to call repeatedly).
  void prefetch({int limit = defaultLimit}) {
    // ignore: unawaited_futures
    ensure(limit: limit);
  }

  /// Returns warm/in-flight first page, or starts a new fetch.
  ///
  /// A completed warm page is consumed once so a later empty-list refresh
  /// (e.g. pull-to-refresh after a failed paint) still hits the network.
  Future<CatalogPage<CatalogStore>> ensure({int limit = defaultLimit}) {
    final warm = _warm;
    if (warm != null) {
      _warm = null;
      return Future<CatalogPage<CatalogStore>>.value(warm);
    }

    final existing = _inFlight;
    if (existing != null) return existing;

    return _start(limit: limit);
  }

  /// Force a fresh network page (pull-to-refresh / return from store).
  Future<CatalogPage<CatalogStore>> refresh({int limit = defaultLimit}) {
    _warm = null;
    return _start(limit: limit);
  }

  /// Drop warm/in-flight handles (logout / failed session restore).
  void invalidate() {
    _warm = null;
    _inFlight = null;
  }

  Future<CatalogPage<CatalogStore>> _start({required int limit}) {
    final future = _load(limit: limit);
    _inFlight = future;
    future
        .then((page) {
          if (identical(_inFlight, future)) {
            _warm = page;
          }
        })
        .catchError((_) {
          // Leave [_warm] null so a later ensure/refresh can retry.
        })
        .whenComplete(() {
          if (identical(_inFlight, future)) {
            _inFlight = null;
          }
        });
    return future;
  }

  Future<CatalogPage<CatalogStore>> _load({required int limit}) async {
    AppLog.d(_tag, 'fetchHome limit=$limit');
    final page = await ServiceLocator.get<StoreRepository>().fetchHome(
      limit: limit,
    );
    AppLog.d(_tag, 'Prefetched ${page.items.length} stores');
    return page;
  }
}
