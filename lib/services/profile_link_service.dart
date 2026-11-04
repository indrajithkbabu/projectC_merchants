import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/catalog_ui_mapper.dart';
import 'package:project_c/helper/merchant_profile_link.dart';
import 'package:project_c/main/app.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';
import 'package:project_c/webservice/store/store_repository.dart';

/// Opens a shared Catly link on the matching screen.
///
/// Store: `https://catly.in/store/{slug}` → store channel.
/// Product: `https://catly.in/store/{slug}/p/{productId}` → product details.
class ProfileLinkService {
  ProfileLinkService({
    required CatalogSession session,
    required StoreRepository storeRepository,
    required CollectionRepository collectionRepository,
  }) : _session = session,
       _stores = storeRepository,
       _collections = collectionRepository;

  static const _tag = 'ProfileLink';

  final CatalogSession _session;
  final StoreRepository _stores;
  final CollectionRepository _collections;
  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _subscription;
  _PendingLink? _pending;
  bool _opening = false;
  String? _lastUri;
  DateTime? _lastAt;

  Future<void> start() async {
    _subscription ??= _appLinks.uriLinkStream.listen(
      (uri) {
        unawaited(openUri(uri));
      },
      onError: (Object error, StackTrace _) {
        AppLog.e(_tag, 'link stream failed', error);
      },
    );
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) await openUri(initial);
    } catch (error) {
      AppLog.e(_tag, 'initial link failed', error);
    }
  }

  /// Opens a link that arrived before login or before the navigator existed.
  Future<void> flushPending() async {
    final pending = _pending;
    if (pending == null) return;
    await _openPending(pending);
  }

  Future<void> openUri(Uri uri) async {
    final product = MerchantProfileLink.productPageFromUri(uri);
    final slug = product == null ? MerchantProfileLink.slugFromUri(uri) : null;
    final pending =
        product != null
            ? _PendingLink.product(product)
            : (slug == null || slug.isEmpty)
            ? null
            : _PendingLink.store(slug);
    if (pending == null) return;
    final key = uri.toString();
    final now = DateTime.now();
    if (_lastUri == key &&
        _lastAt != null &&
        now.difference(_lastAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastUri = key;
    _lastAt = now;
    AppLog.d(_tag, 'open $pending uri=$uri');
    await _openPending(pending);
  }

  Future<void> _openPending(_PendingLink link) async {
    if (!_session.isSignedIn || navigatorKey.currentState == null) {
      _pending = link;
      AppLog.d(_tag, 'defer $link signedIn=${_session.isSignedIn}');
      return;
    }
    if (_opening) {
      _pending = link;
      return;
    }
    _opening = true;
    if (_pending == link) _pending = null;
    try {
      if (link.product != null) {
        await _openProduct(link.product!);
      } else {
        await _openStore(link.slug!);
      }
    } catch (error) {
      AppLog.e(_tag, 'open $link failed', error);
      _showRetry(link, CatalogErrorMapper.toUserMessage(error));
    } finally {
      _opening = false;
      final next = _pending;
      if (next != null && next != link) {
        _pending = null;
        unawaited(_openPending(next));
      }
    }
  }

  Future<void> _openStore(String slug) async {
    final store = await _stores.fetchStoreBySlug(slug);
    if (store.id.trim().isEmpty) {
      _showMessage('Could not open that store profile.');
      return;
    }
    if (!_ready) {
      _pending = _PendingLink.store(slug);
      return;
    }
    final ownId = _session.ownStoreId?.trim() ?? '';
    final isOwn = store.isOwn || (ownId.isNotEmpty && ownId == store.id);
    var products = const <StoreProduct>[];
    try {
      final page = await _collections.listCollections(
        storeId: store.id,
        limit: 50,
      );
      products = [
        for (final summary in page.items)
          CatalogUiMapper.summaryToProduct(summary),
      ]..sort((a, b) => b.id.compareTo(a.id));
    } catch (error) {
      AppLog.e(_tag, 'channel products failed slug=$slug', error);
    }
    if (!_ready) {
      _pending = _PendingLink.store(slug);
      return;
    }
    navigatorKey.currentState!.pushNamed(
      Routes.storeChannelRoute,
      arguments: <String, Object?>{
        'storeId': store.id,
        'storeName': store.name,
        'storeLink': store.storeLink,
        'imageUrls': store.showcaseImageUrls,
        'products': products,
        'followerCount': store.followerCount,
        'followingCount': store.followingCount,
        'productCount': store.productCount ?? products.length,
        'isOwnStore': isOwn,
      },
    );
  }

  Future<void> _openProduct(ProductPageLink page) async {
    final store = await _stores.fetchStoreBySlug(page.storeSlug);
    if (store.id.trim().isEmpty) {
      _showMessage('Could not open that product.');
      return;
    }
    if (!_ready) {
      _pending = _PendingLink.product(page);
      return;
    }
    final ownId = _session.ownStoreId?.trim() ?? '';
    navigatorKey.currentState!.pushNamed(
      Routes.productDetailsRoute,
      arguments: <String, Object?>{
        'product': StoreProduct(
          id: page.productId,
          title: 'Item',
          description: '',
          tags: const [],
          imagePaths: const [],
        ),
        'storeId': store.id,
        'storeName': store.name,
        'storeLink': store.storeLink,
        'isOwnStore': store.isOwn || (ownId.isNotEmpty && ownId == store.id),
      },
    );
  }

  bool get _ready => _session.isSignedIn && navigatorKey.currentState != null;

  void _showMessage(String message) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showRetry(_PendingLink link, String message) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () {
            unawaited(_openPending(link));
          },
        ),
      ),
    );
  }
}

class _PendingLink {
  const _PendingLink.store(this.slug) : product = null;

  const _PendingLink.product(ProductPageLink page)
    : slug = null,
      product = page;

  final String? slug;
  final ProductPageLink? product;

  @override
  bool operator ==(Object other) {
    return other is _PendingLink &&
        other.slug == slug &&
        other.product?.storeSlug == product?.storeSlug &&
        other.product?.productId == product?.productId;
  }

  @override
  int get hashCode => Object.hash(slug, product?.storeSlug, product?.productId);

  @override
  String toString() =>
      product == null
          ? 'store:$slug'
          : 'product:${product!.storeSlug}/${product!.productId}';
}
