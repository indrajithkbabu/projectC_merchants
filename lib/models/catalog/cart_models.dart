import 'package:equatable/equatable.dart';
import 'package:project_c/models/catalog/catalog_stock_status.dart';

/// One cart line for UI. Unique per [productId] (no quantity).
class CartItem extends Equatable {
  const CartItem({
    required this.productId,
    required this.storeId,
    required this.storeName,
    required this.title,
    required this.addedAt,
    this.cartItemId = '',
    this.listingId = '',
    this.imageIndex = 0,
    this.storeAvatarUrl = '',
    this.storeSlug = '',
    this.storeCity = '',
    this.imageUrl = '',
    this.thumbhash = '',
    this.detailLine = '',
    this.metal = '',
    this.purity = '',
    this.netWeight,
    this.fineWeightGrams,
    this.stockStatus,
    this.mtoDays,
  });

  final String cartItemId;
  final String productId;
  final String listingId;
  final int imageIndex;
  final String storeId;
  final String storeName;
  final String storeAvatarUrl;
  final String storeSlug;
  final String storeCity;
  final String title;
  final String imageUrl;
  final String thumbhash;
  /// e.g. "Free size · Gold 91.6"
  final String detailLine;
  final String metal;
  final String purity;
  final double? netWeight;
  final double? fineWeightGrams;
  final CatalogStockStatus? stockStatus;
  final int? mtoDays;
  final DateTime addedAt;

  bool get isOutOfStock => stockStatus == CatalogStockStatus.outOfStock;
  bool get isMto => stockStatus == CatalogStockStatus.mto;
  bool get isGold {
    final m = metal.trim().toLowerCase();
    return m == 'gold' || m == 'au';
  }

  bool get isSilver {
    final m = metal.trim().toLowerCase();
    return m == 'silver' || m == 'ag';
  }

  CartItem copyWith({
    String? cartItemId,
    String? productId,
    String? listingId,
    int? imageIndex,
    String? storeId,
    String? storeName,
    String? storeAvatarUrl,
    String? storeSlug,
    String? storeCity,
    String? title,
    String? imageUrl,
    String? thumbhash,
    String? detailLine,
    String? metal,
    String? purity,
    double? netWeight,
    double? fineWeightGrams,
    CatalogStockStatus? stockStatus,
    int? mtoDays,
    DateTime? addedAt,
  }) {
    return CartItem(
      cartItemId: cartItemId ?? this.cartItemId,
      productId: productId ?? this.productId,
      listingId: listingId ?? this.listingId,
      imageIndex: imageIndex ?? this.imageIndex,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      storeAvatarUrl: storeAvatarUrl ?? this.storeAvatarUrl,
      storeSlug: storeSlug ?? this.storeSlug,
      storeCity: storeCity ?? this.storeCity,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbhash: thumbhash ?? this.thumbhash,
      detailLine: detailLine ?? this.detailLine,
      metal: metal ?? this.metal,
      purity: purity ?? this.purity,
      netWeight: netWeight ?? this.netWeight,
      fineWeightGrams: fineWeightGrams ?? this.fineWeightGrams,
      stockStatus: stockStatus ?? this.stockStatus,
      mtoDays: mtoDays ?? this.mtoDays,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  factory CartItem.fromApiJson(
    Map<String, dynamic> json, {
    required String storeId,
    required String storeName,
    String storeAvatarUrl = '',
    String storeSlug = '',
    String storeCity = '',
  }) {
    final inStock = json['inStock'];
    final isOut = json['isOutOfStock'] == true || inStock == false;
    CatalogStockStatus? stock;
    if (isOut) {
      stock = CatalogStockStatus.outOfStock;
    } else if (inStock == true) {
      stock = CatalogStockStatus.inStock;
    } else {
      stock = CatalogStockStatus.tryParse(json['stockStatus']?.toString());
    }

    final sizePurity =
        (json['sizePurity'] as String?)?.trim() ??
        (json['detailLine'] as String?)?.trim() ??
        '';

    return CartItem(
      cartItemId: (json['cartItemId'] as String?)?.trim() ?? '',
      productId: (json['productId'] as String?)?.trim() ?? '',
      listingId: (json['listingId'] as String?)?.trim() ?? '',
      imageIndex: (json['imageIndex'] as num?)?.toInt() ?? 0,
      storeId: storeId,
      storeName: storeName,
      storeAvatarUrl: storeAvatarUrl,
      storeSlug: storeSlug,
      storeCity: storeCity,
      title: (json['title'] as String?)?.trim() ?? 'Product',
      imageUrl: (json['imageUrl'] as String?)?.trim() ?? '',
      thumbhash: (json['thumbhash'] as String?)?.trim() ?? '',
      detailLine: sizePurity,
      metal: (json['metal'] as String?)?.trim() ?? '',
      purity: (json['purity'] as String?)?.trim() ?? '',
      netWeight: (json['netWeight'] as num?)?.toDouble(),
      fineWeightGrams: (json['fineWeight'] as num?)?.toDouble() ??
          (json['fineWeightGrams'] as num?)?.toDouble(),
      stockStatus: stock,
      mtoDays: (json['mtoDays'] as num?)?.toInt(),
      addedAt:
          DateTime.tryParse((json['addedAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        cartItemId,
        productId,
        listingId,
        imageIndex,
        storeId,
        storeName,
        storeAvatarUrl,
        storeSlug,
        storeCity,
        title,
        imageUrl,
        thumbhash,
        detailLine,
        metal,
        purity,
        netWeight,
        fineWeightGrams,
        stockStatus,
        mtoDays,
        addedAt,
      ];
}

/// Result of `POST /me/cart`.
class CartAddResult extends Equatable {
  const CartAddResult({
    this.added = const [],
    this.alreadyInCart = const [],
    this.outOfStock = const [],
    this.toastMessage = '',
    this.storeCount,
    this.totalCount,
    this.cartFull = false,
  });

  final List<String> added;
  final List<String> alreadyInCart;
  final List<String> outOfStock;
  final String toastMessage;
  final int? storeCount;
  final int? totalCount;

  /// Legacy FE-only flag (BE has no cart cap).
  final bool cartFull;

  int get addedCount => added.length;
  int get alreadyInCartCount => alreadyInCart.length;
  int get outOfStockCount => outOfStock.length;

  factory CartAddResult.fromJson(Map<String, dynamic> json) {
    List<String> ids(dynamic raw) {
      if (raw is! List) return const [];
      return [
        for (final e in raw)
          if (e != null && e.toString().trim().isNotEmpty) e.toString().trim(),
      ];
    }

    final skipped = json['skipped'];
    final skippedMap =
        skipped is Map ? Map<String, dynamic>.from(skipped) : const {};

    return CartAddResult(
      added: ids(json['added']),
      alreadyInCart: ids(skippedMap['in_cart'] ?? skippedMap['inCart']),
      outOfStock: ids(
        skippedMap['out_of_stock'] ?? skippedMap['outOfStock'],
      ),
      toastMessage: (json['toastMessage'] as String?)?.trim() ?? '',
      storeCount: (json['storeCount'] as num?)?.toInt(),
      totalCount: (json['totalCount'] as num?)?.toInt(),
    );
  }

  @override
  List<Object?> get props => [
        added,
        alreadyInCart,
        outOfStock,
        toastMessage,
        storeCount,
        totalCount,
        cartFull,
      ];
}

/// `GET /me/cart` summary (gold vs silver fine).
class CartSummary extends Equatable {
  const CartSummary({
    this.totalFineGold = 0,
    this.totalFineSilver = 0,
    this.displayTotalFine = '',
    this.inStockCount = 0,
    this.outOfStockCount = 0,
  });

  final double totalFineGold;
  final double totalFineSilver;
  final String displayTotalFine;
  final int inStockCount;
  final int outOfStockCount;

  factory CartSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CartSummary();
    return CartSummary(
      totalFineGold: (json['totalFineGold'] as num?)?.toDouble() ?? 0,
      totalFineSilver: (json['totalFineSilver'] as num?)?.toDouble() ?? 0,
      displayTotalFine: (json['displayTotalFine'] as String?)?.trim() ?? '',
      inStockCount: (json['inStockCount'] as num?)?.toInt() ?? 0,
      outOfStockCount: (json['outOfStockCount'] as num?)?.toInt() ?? 0,
    );
  }

  String get displayLabel {
    final raw = displayTotalFine.trim();
    if (raw.isNotEmpty) return raw;
    final parts = <String>[];
    if (totalFineGold > 0) {
      parts.add('${totalFineGold.toStringAsFixed(2)} g Au');
    }
    if (totalFineSilver > 0) {
      parts.add('${totalFineSilver.toStringAsFixed(2)} g Ag');
    }
    if (parts.isEmpty) return '0.00 g';
    return parts.join(' · ');
  }

  @override
  List<Object?> get props => [
        totalFineGold,
        totalFineSilver,
        displayTotalFine,
        inStockCount,
        outOfStockCount,
      ];
}

/// Cart items for one store, in first-added store order.
class CartStoreGroup extends Equatable {
  const CartStoreGroup({
    required this.storeId,
    required this.storeName,
    required this.items,
    this.storeAvatarUrl = '',
    this.storeSlug = '',
    this.storeCity = '',
  });

  final String storeId;
  final String storeName;
  final String storeAvatarUrl;
  final String storeSlug;
  final String storeCity;
  final List<CartItem> items;

  int get itemCount => items.length;

  factory CartStoreGroup.fromJson(Map<String, dynamic> json) {
    final storeId = (json['storeId'] as String?)?.trim() ?? '';
    final storeName = (json['storeName'] as String?)?.trim() ?? 'Store';
    final logo =
        (json['logoUrl'] as String?)?.trim() ??
        (json['storeAvatarUrl'] as String?)?.trim() ??
        '';
    final slug = (json['slug'] as String?)?.trim() ?? '';
    final city = (json['city'] as String?)?.trim() ?? '';
    final rawItems = json['items'];
    final items = <CartItem>[];
    if (rawItems is List) {
      for (final row in rawItems) {
        if (row is! Map) continue;
        final item = CartItem.fromApiJson(
          Map<String, dynamic>.from(row),
          storeId: storeId,
          storeName: storeName,
          storeAvatarUrl: logo,
          storeSlug: slug,
          storeCity: city,
        );
        if (item.productId.isNotEmpty) items.add(item);
      }
    }
    return CartStoreGroup(
      storeId: storeId,
      storeName: storeName,
      storeAvatarUrl: logo,
      storeSlug: slug,
      storeCity: city,
      items: List.unmodifiable(items),
    );
  }

  @override
  List<Object?> get props =>
      [storeId, storeName, storeAvatarUrl, storeSlug, storeCity, items];
}

/// Full `GET /me/cart` payload.
class CartPage extends Equatable {
  const CartPage({
    this.totalItems = 0,
    this.totalStores = 0,
    this.summary = const CartSummary(),
    this.stores = const [],
  });

  final int totalItems;
  final int totalStores;
  final CartSummary summary;
  final List<CartStoreGroup> stores;

  List<CartItem> get flatItems => [
        for (final g in stores) ...g.items,
      ];

  factory CartPage.fromJson(Map<String, dynamic> json) {
    final rawStores = json['stores'];
    final stores = <CartStoreGroup>[];
    if (rawStores is List) {
      for (final row in rawStores) {
        if (row is! Map) continue;
        stores.add(CartStoreGroup.fromJson(Map<String, dynamic>.from(row)));
      }
    }
    final summaryRaw = json['summary'];
    return CartPage(
      totalItems: (json['totalItems'] as num?)?.toInt() ??
          stores.fold<int>(0, (n, g) => n + g.items.length),
      totalStores: (json['totalStores'] as num?)?.toInt() ?? stores.length,
      summary: CartSummary.fromJson(
        summaryRaw is Map ? Map<String, dynamic>.from(summaryRaw) : null,
      ),
      stores: List.unmodifiable(stores),
    );
  }

  @override
  List<Object?> get props => [totalItems, totalStores, summary, stores];
}

/// Lightweight `GET /me/cart/count`.
class CartCount extends Equatable {
  const CartCount({this.totalItems = 0, this.totalStores = 0});

  final int totalItems;
  final int totalStores;

  factory CartCount.fromJson(Map<String, dynamic> json) {
    return CartCount(
      totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
      totalStores: (json['totalStores'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [totalItems, totalStores];
}

class CartRemoveResult extends Equatable {
  const CartRemoveResult({
    this.success = true,
    this.removedProductId = '',
    this.remainingItems = 0,
    this.remainingStores = 0,
  });

  final bool success;
  final String removedProductId;
  final int remainingItems;
  final int remainingStores;

  factory CartRemoveResult.fromJson(Map<String, dynamic> json) {
    return CartRemoveResult(
      success: json['success'] != false,
      removedProductId: (json['removedProductId'] as String?)?.trim() ?? '',
      remainingItems: (json['remainingItems'] as num?)?.toInt() ?? 0,
      remainingStores: (json['remainingStores'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props =>
      [success, removedProductId, remainingItems, remainingStores];
}

class CartMoveToWishlistResult extends Equatable {
  const CartMoveToWishlistResult({
    this.success = true,
    this.movedProductId = '',
    this.wishlisted = true,
    this.wishlistId = '',
    this.remainingItems = 0,
  });

  final bool success;
  final String movedProductId;
  final bool wishlisted;
  final String wishlistId;
  final int remainingItems;

  factory CartMoveToWishlistResult.fromJson(Map<String, dynamic> json) {
    final wishlist = json['wishlist'];
    final cart = json['cart'];
    final wMap =
        wishlist is Map ? Map<String, dynamic>.from(wishlist) : const {};
    final cMap = cart is Map ? Map<String, dynamic>.from(cart) : const {};
    return CartMoveToWishlistResult(
      success: json['success'] != false,
      movedProductId: (json['movedProductId'] as String?)?.trim() ?? '',
      wishlisted: wMap['wishlisted'] != false,
      wishlistId: (wMap['wishlistId'] as String?)?.trim() ?? '',
      remainingItems: (cMap['remainingItems'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props =>
      [success, movedProductId, wishlisted, wishlistId, remainingItems];
}

class CartUndoWishlistResult extends Equatable {
  const CartUndoWishlistResult({
    this.success = true,
    this.restoredProductId = '',
    this.cartItemId = '',
  });

  final bool success;
  final String restoredProductId;
  final String cartItemId;

  factory CartUndoWishlistResult.fromJson(Map<String, dynamic> json) {
    final cart = json['cart'];
    final cMap = cart is Map ? Map<String, dynamic>.from(cart) : const {};
    return CartUndoWishlistResult(
      success: json['success'] != false,
      restoredProductId: (json['restoredProductId'] as String?)?.trim() ?? '',
      cartItemId: (cMap['cartItemId'] as String?)?.trim() ?? '',
    );
  }

  @override
  List<Object?> get props => [success, restoredProductId, cartItemId];
}
