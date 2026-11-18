import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/storage/store_products_cache.dart';

/// Fix I3 — disk/cache stall after process kill (compute() spawn).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('i3_cache_stall_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    StoreProductsCache.instance.debugResetDocsDirCache();
    StoreProductsCache.instance.debugComputeDecodeCalls = 0;
    StoreProductsCache.instance.debugInlineDecodeCalls = 0;
    StoreProductsCache.instance.debugDocsPathResolves = 0;
    await StoreProductsCache.instance.clearAll();
  });

  tearDown(() async {
    await StoreProductsCache.instance.clearAll();
    StoreProductsCache.instance.debugResetDocsDirCache();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Collage-like product — many URLs so JSON exceeds the old 32 KiB threshold.
  StoreProduct heavyProduct(String id) {
    final urls = [
      for (var i = 0; i < 9; i++)
        'https://cdn.example.com/stores/abc123/products/$id/frame_$i/'
            'master_very_long_path_segment_for_cache_size.jpg?w=1200&q=85&sig=$i',
    ];
    return StoreProduct(
      id: id,
      title: 'Heavy album $id with a longer title for JSON bulk',
      description: 'desc ' * 20,
      tags: const ['bridal', 'gold', 'festive'],
      imagePaths: urls,
      imageThumbnailUrls: urls,
      imageDetailUrls: urls,
      imageThumbhashes: List.filled(9, 'base64thumbhashpadding=='),
      photoAssetIds: [for (var i = 0; i < 9; i++) 'prod_${id}_$i'],
      albumItemCount: 20,
    );
  }

  test(
    'moderate grid exceeds old 32KiB threshold but stays inline decode',
    () async {
      const storeId = 'store_heavy_inline';
      final products = [for (var i = 0; i < 15; i++) heavyProduct('p$i')];
      await StoreProductsCache.instance.write(storeId, products);

      // Confirm payload would have triggered the old 32 KiB compute() path.
      final file = File(
        '${tempDir.path}/store_products_cache/'
        '${storeId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.json',
      );
      expect(await file.exists(), isTrue);
      final bytes = await file.length();
      expect(bytes, greaterThan(32 * 1024));
      expect(bytes, lessThan(StoreProductsCache.isolateJsonBytes));

      StoreProductsCache.instance.evictMemory(storeId);
      StoreProductsCache.instance.debugComputeDecodeCalls = 0;
      StoreProductsCache.instance.debugInlineDecodeCalls = 0;

      final sw = Stopwatch()..start();
      final loaded = await StoreProductsCache.instance.read(storeId);
      sw.stop();

      expect(loaded, isNotNull);
      expect(loaded!.length, 15);
      expect(StoreProductsCache.instance.debugInlineDecodeCalls, 1);
      expect(StoreProductsCache.instance.debugComputeDecodeCalls, 0);
      // Local file + inline JSON must stay well under the old ~1–2 s stall.
      expect(sw.elapsedMilliseconds, lessThan(250));
    },
  );

  test('docs directory path is resolved once and reused', () async {
    const a = 'store_path_a';
    const b = 'store_path_b';
    await StoreProductsCache.instance.write(a, [heavyProduct('a1')]);
    await StoreProductsCache.instance.write(b, [heavyProduct('b1')]);
    StoreProductsCache.instance.evictMemory(a);
    StoreProductsCache.instance.evictMemory(b);
    StoreProductsCache.instance.debugResetDocsDirCache();
    StoreProductsCache.instance.debugDocsPathResolves = 0;

    await StoreProductsCache.instance.read(a);
    await StoreProductsCache.instance.read(b);

    expect(StoreProductsCache.instance.debugDocsPathResolves, 1);
  });

  test(
    'second disk read after warm memory is sync-fast via readMemory',
    () async {
      const storeId = 'store_second_hit';
      await StoreProductsCache.instance.write(storeId, [
        for (var i = 0; i < 12; i++) heavyProduct('s$i'),
      ]);
      StoreProductsCache.instance.evictMemory(storeId);

      final first = await StoreProductsCache.instance.read(storeId);
      expect(first!.length, 12);

      final sw = Stopwatch()..start();
      final second = StoreProductsCache.instance.readMemory(storeId);
      sw.stop();
      expect(second!.length, 12);
      expect(sw.elapsedMilliseconds, lessThan(20));
    },
  );

  test('empty / missing file is a fast miss without compute', () async {
    StoreProductsCache.instance.debugComputeDecodeCalls = 0;
    final sw = Stopwatch()..start();
    final miss = await StoreProductsCache.instance.read('missing_store');
    sw.stop();
    expect(miss, isNull);
    expect(StoreProductsCache.instance.debugComputeDecodeCalls, 0);
    expect(sw.elapsedMilliseconds, lessThan(100));
  });

  test('decodeStoreProductsJson round-trips product maps', () {
    final maps = [for (var i = 0; i < 15; i++) heavyProduct('p$i').toMap()];
    final raw = jsonEncode(maps);
    expect(raw.length, greaterThan(32 * 1024));
    final decoded = decodeStoreProductsJson(raw);
    expect(decoded.length, 15);
    expect(decoded.first['id'], 'p0');
  });
}

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}
