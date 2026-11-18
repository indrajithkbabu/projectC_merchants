import 'package:flutter_test/flutter_test.dart';
import 'package:project_c/models/catalog/catalog_product_models.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/services/store_products_prefetcher.dart';

void main() {
  group('storeProductFromEmbeddedSummary', () {
    const cover = CatalogPhoto(
      width: 100,
      height: 100,
      url: 'https://cdn.example/cover.jpg',
    );

    test('returns collage card when embed has displayable URLs', () {
      final summary = CollectionSummary(
        id: 'col_1',
        name: 'Album',
        revision: 1,
        photoCount: 2,
        cover: cover,
        products: [
          CatalogProduct(
            id: 'p1',
            storeId: 'store_1',
            title: 'Ring',
            imageUrls: const ['https://cdn.example/a.jpg'],
          ),
          CatalogProduct(
            id: 'p2',
            storeId: 'store_1',
            title: 'Band',
            imageUrls: const ['https://cdn.example/b.jpg'],
          ),
        ],
      );

      final card = storeProductFromEmbeddedSummary(summary);
      expect(card, isNotNull);
      expect(card!.id, 'col_1');
      expect(card.imagePaths, contains('https://cdn.example/a.jpg'));
      expect(card.imagePaths, contains('https://cdn.example/b.jpg'));
    });

    test('returns null when embed is empty (legacy path required)', () {
      final summary = CollectionSummary(
        id: 'col_2',
        name: 'Empty embed',
        revision: 1,
        photoCount: 3,
        cover: cover,
        products: const [],
      );
      expect(storeProductFromEmbeddedSummary(summary), isNull);
    });

    test('falls back to cover when embed product URLs are empty', () {
      final summary = CollectionSummary(
        id: 'col_3',
        name: 'Bad urls',
        revision: 1,
        photoCount: 1,
        cover: cover,
        products: [
          CatalogProduct(
            id: 'p1',
            storeId: 'store_1',
            title: 'Broken',
            imageUrls: const [''],
          ),
        ],
      );
      // Mapper keeps a displayable cover — still a valid BE-2 card (no legacy).
      final card = storeProductFromEmbeddedSummary(summary);
      expect(card, isNotNull);
      expect(card!.imagePaths, contains('https://cdn.example/cover.jpg'));
    });

    test('caps embedded products to productsLimit', () {
      final summary = CollectionSummary(
        id: 'col_4',
        name: 'Many',
        revision: 1,
        photoCount: 20,
        cover: cover,
        products: [
          for (var i = 0; i < 12; i++)
            CatalogProduct(
              id: 'p$i',
              storeId: 'store_1',
              title: 'Item $i',
              imageUrls: ['https://cdn.example/$i.jpg'],
            ),
        ],
      );
      final card = storeProductFromEmbeddedSummary(summary, productsLimit: 9);
      expect(card, isNotNull);
      expect(card!.imagePaths.length, lessThanOrEqualTo(9));
    });
  });
}
