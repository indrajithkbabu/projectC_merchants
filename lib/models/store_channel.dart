import 'package:equatable/equatable.dart';
import 'package:project_c/models/store_product.dart';

class StoreChannel extends Equatable {
  const StoreChannel({
    required this.id,
    required this.name,
    required this.handle,
    required this.avatarColor,
    required this.products,
    this.isOwn = false,
  });

  final String id;
  final String name;
  final String handle;
  final int avatarColor;
  final List<StoreProduct> products;
  final bool isOwn;

  String get storeLink => '$handle.jewelflow.app';

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  StoreChannel copyWith({
    String? id,
    String? name,
    String? handle,
    int? avatarColor,
    List<StoreProduct>? products,
    bool? isOwn,
  }) {
    return StoreChannel(
      id: id ?? this.id,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      avatarColor: avatarColor ?? this.avatarColor,
      products: products ?? this.products,
      isOwn: isOwn ?? this.isOwn,
    );
  }

  static List<StoreProduct> _veronaProducts() {
    final now = DateTime.now();
    return [
      StoreProduct(
        id: 'verona_1',
        title: 'Tennis bracelet',
        description: 'Diamond tennis bracelet in white gold.',
        tags: ['bracelet', 'diamond'],
        imagePaths: [],
        toneIndex: 0,
        createdAt: now,
      ),
      StoreProduct(
        id: 'verona_2',
        title: 'Halo studs',
        description: 'Halo diamond stud earrings.',
        tags: ['earrings', 'studs'],
        imagePaths: [],
        toneIndex: 1,
        createdAt: now,
      ),
      StoreProduct(
        id: 'verona_3',
        title: 'Gold chain 22k',
        description: 'Classic 22k gold chain.',
        tags: ['chain', 'gold'],
        imagePaths: [],
        toneIndex: 2,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      StoreProduct(
        id: 'verona_4',
        title: 'Ruby cocktail ring',
        description: 'Statement ruby cocktail ring.',
        tags: ['ring', 'ruby'],
        imagePaths: [],
        toneIndex: 3,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      StoreProduct(
        id: 'verona_5',
        title: 'Sapphire pendant',
        description: 'Blue sapphire pendant on gold chain.',
        tags: ['pendant', 'sapphire'],
        imagePaths: [],
        toneIndex: 0,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      StoreProduct(
        id: 'verona_6',
        title: 'Silver anklet',
        description: 'Handcrafted silver anklet.',
        tags: ['anklet', 'silver'],
        imagePaths: [],
        toneIndex: 1,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ];
  }

  static List<StoreProduct> _navaratnaProducts() {
    final now = DateTime.now();
    return [
      StoreProduct(
        id: 'nava_1',
        title: 'Navaratna necklace',
        description: 'Traditional nine-gem necklace setting.',
        tags: ['necklace', 'navaratna'],
        imagePaths: [],
        toneIndex: 2,
        createdAt: now,
      ),
      StoreProduct(
        id: 'nava_2',
        title: 'Temple jhumkas',
        description: 'Antique-finish temple jhumkas.',
        tags: ['earrings', 'temple'],
        imagePaths: [],
        toneIndex: 3,
        createdAt: now,
      ),
      StoreProduct(
        id: 'nava_3',
        title: 'Kundan choker',
        description: 'Bridal kundan choker set.',
        tags: ['choker', 'kundan'],
        imagePaths: [],
        toneIndex: 0,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      StoreProduct(
        id: 'nava_4',
        title: 'Polki bangles',
        description: 'Pair of polki stone bangles.',
        tags: ['bangle', 'polki'],
        imagePaths: [],
        toneIndex: 1,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }

  static List<StoreChannel> dummyOtherStores() {
    return [
      StoreChannel(
        id: 'store_verona',
        name: 'Verona Fine Jewels',
        handle: 'verona',
        avatarColor: 0xFF8E44AD,
        products: _veronaProducts(),
      ),
      StoreChannel(
        id: 'store_navaratna',
        name: 'Navaratna Jewellers',
        handle: 'navaratna',
        avatarColor: 0xFF2980B9,
        products: _navaratnaProducts(),
      ),
      StoreChannel(
        id: 'store_aisha',
        name: 'Aisha Fine Jewels',
        handle: 'aisha-fine-jewels',
        avatarColor: 0xFF16A085,
        products: StoreProduct.demoCatalog(),
      ),
      StoreChannel(
        id: 'store_lotus',
        name: 'Lotus Gold House',
        handle: 'lotus-gold',
        avatarColor: 0xFFE67E22,
        products: StoreProduct.demoCatalog().reversed.toList(),
      ),
    ];
  }

  @override
  List<Object?> get props => [id, name, handle, avatarColor, products, isOwn];
}
