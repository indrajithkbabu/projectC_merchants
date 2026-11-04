import 'package:flutter/foundation.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/cart_models.dart';

/// In-memory cart cache for badges / selection marks.
/// Source of truth is BE (`CartRepository`); this only mirrors it.
class CartStore extends ChangeNotifier {
  CartStore();

  static const _tag = 'CartStore';

  final Set<String> _productIds = {};
  List<CartStoreGroup> _groups = const [];
  CartSummary _summary = const CartSummary();
  int _count = 0;
  int _storeCount = 0;
  bool _hydrated = false;

  bool get isHydrated => _hydrated;
  int get count => _count;
  int get storeCount => _storeCount;
  bool get isEmpty => _count <= 0;
  /// BE has no hard cap — kept false for dock compatibility.
  bool get isFull => false;
  CartSummary get summary => _summary;
  List<CartStoreGroup> get groups => List.unmodifiable(_groups);
  Set<String> get productIds => Set.unmodifiable(_productIds);
  List<CartItem> get items => [
        for (final g in _groups) ...g.items,
      ];

  bool contains(String productId) {
    final id = productId.trim();
    if (id.isEmpty) return false;
    return _productIds.contains(id);
  }

  void applyCount(CartCount count) {
    _count = count.totalItems < 0 ? 0 : count.totalItems;
    _storeCount = count.totalStores < 0 ? 0 : count.totalStores;
    _hydrated = true;
    AppLog.d(_tag, 'applyCount items=$_count stores=$_storeCount');
    notifyListeners();
  }

  void applyPage(CartPage page) {
    _groups = List.unmodifiable(page.stores);
    _summary = page.summary;
    _count = page.totalItems;
    _storeCount = page.totalStores;
    _productIds
      ..clear()
      ..addAll({for (final i in page.flatItems) i.productId});
    _hydrated = true;
    AppLog.d(
      _tag,
      'applyPage items=$_count stores=$_storeCount ids=${_productIds.length}',
    );
    notifyListeners();
  }

  /// After a successful add — mark ids + optional totals from response.
  void applyAddResult(CartAddResult result) {
    var changed = false;
    for (final id in result.added) {
      if (_productIds.add(id.trim())) changed = true;
    }
    if (result.totalCount != null) {
      _count = result.totalCount!;
      changed = true;
    } else if (result.added.isNotEmpty) {
      _count = _productIds.length;
      changed = true;
    }
    if (result.storeCount != null) {
      _storeCount = result.storeCount!;
      changed = true;
    }
    if (changed) {
      _hydrated = true;
      notifyListeners();
    }
  }

  void applyRemove({
    required String productId,
    int? remainingItems,
    int? remainingStores,
  }) {
    final id = productId.trim();
    _productIds.remove(id);
    if (_groups.isNotEmpty) {
      final next = <CartStoreGroup>[];
      for (final g in _groups) {
        final kept =
            g.items.where((e) => e.productId != id).toList(growable: false);
        if (kept.isEmpty) continue;
        next.add(
          CartStoreGroup(
            storeId: g.storeId,
            storeName: g.storeName,
            storeAvatarUrl: g.storeAvatarUrl,
            storeSlug: g.storeSlug,
            storeCity: g.storeCity,
            items: kept,
          ),
        );
      }
      _groups = List.unmodifiable(next);
    }
    _count = remainingItems ?? _productIds.length;
    _storeCount = remainingStores ?? _groups.length;
    notifyListeners();
  }

  void clear() {
    if (_productIds.isEmpty && _groups.isEmpty && _count == 0) return;
    _productIds.clear();
    _groups = const [];
    _summary = const CartSummary();
    _count = 0;
    _storeCount = 0;
    _hydrated = false;
    notifyListeners();
  }

  /// Best-effort fine sum from cached groups (fallback if summary empty).
  double get totalFineGrams {
    if (_summary.totalFineGold > 0 || _summary.totalFineSilver > 0) {
      return double.parse(
        (_summary.totalFineGold + _summary.totalFineSilver).toStringAsFixed(2),
      );
    }
    var sum = 0.0;
    for (final item in items) {
      if (item.isOutOfStock) continue;
      final w = item.fineWeightGrams;
      if (w != null && w > 0) sum += w;
    }
    return double.parse(sum.toStringAsFixed(2));
  }
}
