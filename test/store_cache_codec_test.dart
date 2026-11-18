import 'package:flutter_test/flutter_test.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/storage/store_meta_cache.dart';
import 'package:project_c/storage/store_products_cache.dart';

void main() {
  group('store products cache codec', () {
    test('round-trips product maps with stable fields', () {
      final product = StoreProduct(
        id: 'listing_1',
        title: 'Gold ring',
        description: 'desc',
        tags: const ['wedding', 'gold'],
        imagePaths: const [
          'https://cdn.example/a.jpg',
          'https://cdn.example/b.jpg',
        ],
        imageThumbhashes: const ['hashA', 'hashB'],
        imageThumbnailUrls: const [
          'https://cdn.example/a_t.jpg',
          'https://cdn.example/b_t.jpg',
        ],
        likeCount: 3,
        albumItemCount: 12,
        createdAt: DateTime.utc(2024, 1, 2, 3, 4, 5),
      );

      final encoded = encodeStoreProductsJson([product.toMap()]);
      final maps = decodeStoreProductsJson(encoded);
      expect(maps, hasLength(1));

      final restored = StoreProduct.fromMap(maps.single);
      expect(restored.id, product.id);
      expect(restored.title, product.title);
      expect(restored.tags, product.tags);
      expect(restored.imagePaths, product.imagePaths);
      expect(restored.imageThumbhashes, product.imageThumbhashes);
      expect(restored.imageThumbnailUrls, product.imageThumbnailUrls);
      expect(restored.likeCount, product.likeCount);
      expect(restored.albumItemCount, product.albumItemCount);
      expect(
        restored.createdAt.millisecondsSinceEpoch,
        product.createdAt.millisecondsSinceEpoch,
      );
    });

    test('skips non-map entries and returns empty for invalid JSON list', () {
      expect(decodeStoreProductsJson('[]'), isEmpty);
      expect(decodeStoreProductsJson('{"a":1}'), isEmpty);
      final mixed = encodeStoreProductsJson([
        {
          'id': 'ok',
          'title': 't',
          'description': '',
          'tags': [],
          'imagePaths': [],
        },
      ]);
      // Inject a null sibling by hand.
      final corrupted = mixed.replaceFirst('[', '[null,');
      final maps = decodeStoreProductsJson(corrupted);
      expect(maps, hasLength(1));
      expect(maps.single['id'], 'ok');
    });

    test('large list encode/decode preserves ordering', () {
      final products = [
        for (var i = 0; i < 20; i++)
          StoreProduct(
            id: 'id_$i',
            title: 'Item $i',
            description: '',
            tags: const [],
            imagePaths: [
              for (var j = 0; j < 9; j++) 'https://cdn.example/$i/$j.jpg',
            ],
            createdAt: DateTime.utc(2024, 1, 1).add(Duration(minutes: i)),
          ),
      ];
      final maps = [for (final p in products) p.toMap()];
      final encoded = encodeStoreProductsJson(maps);
      expect(encoded.length, greaterThan(1024));
      final decoded = decodeStoreProductsJson(encoded);
      expect(decoded.map((m) => m['id']), [
        for (var i = 0; i < 20; i++) 'id_$i',
      ]);
    });
  });

  group('store meta cache codec', () {
    test('round-trips meta JSON including privacy and cover', () {
      const snap = StoreMetaSnapshot(
        storeName: 'Demo',
        storeLink: '@demo',
        coverImageUrl: 'https://cdn.example/cover.jpg',
        city: 'Mumbai',
        followerCount: 10,
        followingCount: 2,
        productCount: 40,
        canViewContent: false,
      );
      final encoded = encodeStoreMetaJson(snap.toJson());
      final map = decodeStoreMetaJson(encoded);
      expect(map, isNotNull);
      final restored = StoreMetaSnapshot.fromJson(map!);
      expect(restored.storeName, snap.storeName);
      expect(restored.coverImageUrl, snap.coverImageUrl);
      expect(restored.city, snap.city);
      expect(restored.followerCount, 10);
      expect(restored.productCount, 40);
      expect(restored.canViewContent, isFalse);
    });

    test('corrupted meta JSON returns null', () {
      expect(decodeStoreMetaJson('[]'), isNull);
      expect(decodeStoreMetaJson('not-json'), isNull);
    });
  });
}
