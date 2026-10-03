import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/store_product.dart';

/// Disk + memory cache of enriched store product grids.
///
/// Cache-first: API writes here; UI paints only from cache. First open of a
/// store shows shimmer while networking; later opens paint from cache
/// immediately, then quiet GET refresh rewrites the cache.
class StoreProductsCache {
  StoreProductsCache._();

  static final StoreProductsCache instance = StoreProductsCache._();

  static const _tag = 'StoreProductsCache';
  static const _dirName = 'store_products_cache';

  final Map<String, List<StoreProduct>> _memory = {};

  /// Sync hit for instant first frame (no await).
  List<StoreProduct>? readMemory(String storeId) {
    final id = storeId.trim();
    if (id.isEmpty) return null;
    final mem = _memory[id];
    if (mem == null || mem.isEmpty) return null;
    return List<StoreProduct>.from(mem);
  }

  Future<List<StoreProduct>?> read(String storeId) async {
    final id = storeId.trim();
    if (id.isEmpty) return null;

    final mem = readMemory(id);
    if (mem != null) return mem;

    try {
      final file = await _fileFor(id);
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final products = <StoreProduct>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        products.add(
          StoreProduct.fromMap(Map<String, Object?>.from(item)),
        );
      }
      if (products.isEmpty) return null;
      _memory[id] = products;
      return List<StoreProduct>.from(products);
    } catch (e) {
      AppLog.e(_tag, 'read failed store=$id', e);
      return null;
    }
  }

  Future<void> write(String storeId, List<StoreProduct> products) async {
    final id = storeId.trim();
    if (id.isEmpty) return;

    final snapshot = List<StoreProduct>.from(products);
    _memory[id] = snapshot;

    try {
      final file = await _fileFor(id);
      await file.parent.create(recursive: true);
      final payload = jsonEncode([
        for (final product in snapshot) product.toMap(),
      ]);
      await file.writeAsString(payload, flush: true);
    } catch (e) {
      AppLog.e(_tag, 'write failed store=$id', e);
    }
  }

  Future<void> invalidate(String storeId) async {
    final id = storeId.trim();
    if (id.isEmpty) return;
    _memory.remove(id);
    try {
      final file = await _fileFor(id);
      if (await file.exists()) await file.delete();
    } catch (e) {
      AppLog.e(_tag, 'invalidate failed store=$id', e);
    }
  }

  /// Clears memory + disk product caches (logout / delete account).
  Future<void> clearAll() async {
    _memory.clear();
    try {
      final root = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(root.path, _dirName));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      AppLog.d(_tag, 'clearAll done');
    } catch (e) {
      AppLog.e(_tag, 'clearAll failed', e);
    }
  }

  Future<File> _fileFor(String storeId) async {
    final root = await getApplicationDocumentsDirectory();
    final safe = storeId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return File(p.join(root.path, _dirName, '$safe.json'));
  }
}
