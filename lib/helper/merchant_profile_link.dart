/// Public merchant profile URL: `https://catly.in/store/{publicId}`.
///
/// [publicId] is the store slug. Callers may pass either the slug or the
/// legacy `{slug}.jewelflow.app` store link still used inside navigation.
abstract final class MerchantProfileLink {
  static const String host = 'catly.in';

  static String httpsUrl(String storeLinkOrSlug) {
    final id = publicId(storeLinkOrSlug);
    if (id.isEmpty) return '';
    return 'https://$host/store/$id';
  }

  static final RegExp _slugPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

  /// Website paths that must not be treated as store slugs.
  static const Set<String> reservedPaths = {'about', 'login', 'privacy', 'api'};

  /// Slug from an incoming app link, or null when the URI is not a store.
  ///
  /// `https://catly.in/store/jewel-house` and `catly://store/jewel-house`
  /// both yield `jewel-house`. Query and fragment are ignored.
  static String? slugFromUri(Uri uri) {
    if (uri.userInfo.isNotEmpty || uri.hasPort) return null;
    final scheme = uri.scheme.toLowerCase();
    final segments = uri.pathSegments;
    final String slug;
    if (scheme == 'https' && uri.host.toLowerCase() == host) {
      if (segments.length != 2 || segments[0] != 'store') return null;
      slug = segments[1];
    } else if (scheme == 'catly' && uri.host.toLowerCase() == 'store') {
      if (segments.length != 1) return null;
      slug = segments[0];
    } else {
      return null;
    }
    if (!_isStoreSlug(slug)) return null;
    return slug;
  }

  static bool _isStoreSlug(String slug) {
    return slug.length >= 3 &&
        slug.length <= 50 &&
        _slugPattern.hasMatch(slug) &&
        !reservedPaths.contains(slug);
  }

  static String publicId(String storeLinkOrSlug) {
    var raw = storeLinkOrSlug.trim();
    if (raw.isEmpty) return '';
    raw = raw.replaceFirst(RegExp(r'^https?://'), '');
    raw = raw.replaceFirst(RegExp(r'^www\.'), '');
    raw = raw.split('?').first.split('#').first;
    if (raw.endsWith('/')) {
      raw = raw.substring(0, raw.length - 1);
    }

    const legacySuffix = '.jewelflow.app';
    if (raw.endsWith(legacySuffix)) {
      raw = raw.substring(0, raw.length - legacySuffix.length);
    } else if (raw == host) {
      return '';
    } else if (raw.startsWith('$host/')) {
      raw = raw.substring(host.length + 1);
    }

    final parts =
        raw
            .split('/')
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList();
    if (parts.isEmpty) return '';
    final slug =
        parts.first == 'store' && parts.length >= 2 ? parts[1] : parts.first;
    if (slug.isEmpty || slug.contains('.') || slug == 'store') return '';
    return slug;
  }

  static String shareMessage({
    required String storeName,
    required String storeLinkOrSlug,
  }) {
    final name = storeName.trim().isEmpty ? 'this store' : storeName.trim();
    final url = httpsUrl(storeLinkOrSlug);
    if (url.isEmpty) return 'View $name on Catly.';
    return url;
  }

  static final RegExp _productIdPattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$',
  );

  /// `https://catly.in/store/{slug}/p/{productId}` and
  /// `catly://store/{slug}/p/{productId}`.
  static ProductPageLink? productPageFromUri(Uri uri) {
    if (uri.userInfo.isNotEmpty || uri.hasPort) return null;
    final scheme = uri.scheme.toLowerCase();
    final segments = uri.pathSegments;
    final String slug;
    final String productId;
    if (scheme == 'https' && uri.host.toLowerCase() == host) {
      if (segments.length != 4 ||
          segments[0] != 'store' ||
          segments[2] != 'p') {
        return null;
      }
      slug = segments[1];
      productId = segments[3];
    } else if (scheme == 'catly' && uri.host.toLowerCase() == 'store') {
      if (segments.length != 3 || segments[1] != 'p') return null;
      slug = segments[0];
      productId = segments[2];
    } else {
      return null;
    }
    if (!_isStoreSlug(slug) || !_productIdPattern.hasMatch(productId)) {
      return null;
    }
    return ProductPageLink(storeSlug: slug, productId: productId);
  }

  static String productPageUrl({
    required String storeLinkOrSlug,
    required String productId,
  }) {
    final slug = publicId(storeLinkOrSlug);
    final id = productId.trim();
    if (slug.isEmpty ||
        slug.length < 3 ||
        !_slugPattern.hasMatch(slug) ||
        !_productIdPattern.hasMatch(id)) {
      return '';
    }
    return 'https://$host/store/$slug/p/$id';
  }

  static String productShareMessage({
    required String storeLinkOrSlug,
    required String productId,
  }) {
    final url = productPageUrl(
      storeLinkOrSlug: storeLinkOrSlug,
      productId: productId,
    );
    if (url.isEmpty) return '';
    return url;
  }
}

class ProductPageLink {
  const ProductPageLink({required this.storeSlug, required this.productId});

  final String storeSlug;
  final String productId;
}
