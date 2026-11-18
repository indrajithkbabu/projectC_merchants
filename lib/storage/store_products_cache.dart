import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/store_warm_qa.dart';
import 'package:project_c/models/store_product.dart';

/// Disk + memory cache of enriched store product grids.
///
/// Cache-first: API writes here; UI paints only from cache. First open of a
/// store shows shimmer while networking; later opens paint from cache
/// immediately, then quiet GET refresh rewrites the cache.
///
/// Disk JSON is decoded **inline** for normal grid sizes. Spawning
/// [compute] per read (old 32 KiB threshold) cost ~1–2 s after process
/// kill on device — that stalled I3 early disk and Home `ensure` cache
/// hits alike. Isolate decode is reserved for pathological payloads only.
class StoreProductsCache {
  StoreProductsCache._();

  static final StoreProductsCache instance = StoreProductsCache._();

  static const _tag = 'StoreProductsCache';
  static const _dirName = 'store_products_cache';

  /// Only extreme grids use [compute] — isolate spawn + message copy was the
  /// post-kill stall (I3). Typical 6–20 listing caches stay on the UI isolate.
  static const isolateJsonBytes = 512 * 1024;

  /// Prefer isolate encode only for very large grids (same rationale as decode).
  static const isolateEncodeMinProducts = 48;

  final Map<String, List<StoreProduct>> _memory = {};

  /// Coalesce concurrent disk reads for the same store.
  final Map<String, Future<List<StoreProduct>?>> _readsInFlight = {};

  /// Serialize disk writes per store (memory stays sync / memory-first).
  final Map<String, Future<void>> _writesInFlight = {};

  /// Cached documents root — first [getApplicationDocumentsDirectory] after
  /// process start can be tens of ms; avoid repeating the platform channel.
  Future<Directory>? _docsDirFuture;

  @visibleForTesting
  int debugDocsPathResolves = 0;

  @visibleForTesting
  int debugComputeDecodeCalls = 0;

  @visibleForTesting
  int debugInlineDecodeCalls = 0;

  Future<Directory> _docsDir() {
    final existing = _docsDirFuture;
    if (existing != null) return existing;
    debugDocsPathResolves++;
    final future = getApplicationDocumentsDirectory();
    _docsDirFuture = future;
    return future;
  }

  /// Drop cached docs path (tests that swap [PathProviderPlatform]).
  @visibleForTesting
  void debugResetDocsDirCache() {
    _docsDirFuture = null;
  }

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

    final existing = _readsInFlight[id];
    if (existing != null) return existing;

    final future = _readDisk(id);
    _readsInFlight[id] = future;
    try {
      return await future;
    } finally {
      if (identical(_readsInFlight[id], future)) {
        _readsInFlight.remove(id);
      }
    }
  }

  Future<List<StoreProduct>?> _readDisk(String id) async {
    final total = Stopwatch()..start();
    var pathMs = 0;
    var existsMs = 0;
    var readMs = 0;
    var decodeMs = 0;
    var mapMs = 0;
    var bytes = 0;
    var usedCompute = false;
    try {
      final pathSw = Stopwatch()..start();
      final file = await _fileFor(id);
      pathSw.stop();
      pathMs = pathSw.elapsedMilliseconds;

      final existsSw = Stopwatch()..start();
      final exists = await file.exists();
      existsSw.stop();
      existsMs = existsSw.elapsedMilliseconds;
      if (!exists) {
        _logDiskStages(
          id: id,
          hit: false,
          pathMs: pathMs,
          existsMs: existsMs,
          readMs: 0,
          decodeMs: 0,
          mapMs: 0,
          bytes: 0,
          products: 0,
          usedCompute: false,
          totalMs: total.elapsedMilliseconds,
        );
        return null;
      }

      final readSw = Stopwatch()..start();
      final raw = await file.readAsString();
      readSw.stop();
      readMs = readSw.elapsedMilliseconds;
      bytes = raw.length;
      if (raw.trim().isEmpty) {
        _logDiskStages(
          id: id,
          hit: false,
          pathMs: pathMs,
          existsMs: existsMs,
          readMs: readMs,
          decodeMs: 0,
          mapMs: 0,
          bytes: bytes,
          products: 0,
          usedCompute: false,
          totalMs: total.elapsedMilliseconds,
        );
        return null;
      }

      final decodeSw = Stopwatch()..start();
      usedCompute = raw.length >= isolateJsonBytes;
      final maps = await _decodeProductMaps(raw);
      decodeSw.stop();
      decodeMs = decodeSw.elapsedMilliseconds;
      if (maps.isEmpty) {
        _logDiskStages(
          id: id,
          hit: false,
          pathMs: pathMs,
          existsMs: existsMs,
          readMs: readMs,
          decodeMs: decodeMs,
          mapMs: 0,
          bytes: bytes,
          products: 0,
          usedCompute: usedCompute,
          totalMs: total.elapsedMilliseconds,
        );
        return null;
      }

      final mapSw = Stopwatch()..start();
      final products = <StoreProduct>[
        for (final map in maps) StoreProduct.fromMap(map),
      ];
      mapSw.stop();
      mapMs = mapSw.elapsedMilliseconds;
      if (products.isEmpty) {
        _logDiskStages(
          id: id,
          hit: false,
          pathMs: pathMs,
          existsMs: existsMs,
          readMs: readMs,
          decodeMs: decodeMs,
          mapMs: mapMs,
          bytes: bytes,
          products: 0,
          usedCompute: usedCompute,
          totalMs: total.elapsedMilliseconds,
        );
        return null;
      }

      // A write may have filled memory while we were on disk/isolate — keep it.
      final newer = _memory[id];
      if (newer != null && newer.isNotEmpty) {
        _logDiskStages(
          id: id,
          hit: true,
          pathMs: pathMs,
          existsMs: existsMs,
          readMs: readMs,
          decodeMs: decodeMs,
          mapMs: mapMs,
          bytes: bytes,
          products: newer.length,
          usedCompute: usedCompute,
          totalMs: total.elapsedMilliseconds,
          note: 'memoryWon',
        );
        return List<StoreProduct>.from(newer);
      }
      _memory[id] = products;
      _logDiskStages(
        id: id,
        hit: true,
        pathMs: pathMs,
        existsMs: existsMs,
        readMs: readMs,
        decodeMs: decodeMs,
        mapMs: mapMs,
        bytes: bytes,
        products: products.length,
        usedCompute: usedCompute,
        totalMs: total.elapsedMilliseconds,
      );
      return List<StoreProduct>.from(products);
    } catch (e) {
      AppLog.e(_tag, 'read failed store=$id', e);
      _logDiskStages(
        id: id,
        hit: false,
        pathMs: pathMs,
        existsMs: existsMs,
        readMs: readMs,
        decodeMs: decodeMs,
        mapMs: mapMs,
        bytes: bytes,
        products: 0,
        usedCompute: usedCompute,
        totalMs: total.elapsedMilliseconds,
        note: 'error',
      );
      return null;
    }
  }

  void _logDiskStages({
    required String id,
    required bool hit,
    required int pathMs,
    required int existsMs,
    required int readMs,
    required int decodeMs,
    required int mapMs,
    required int bytes,
    required int products,
    required bool usedCompute,
    required int totalMs,
    String? note,
  }) {
    StoreWarmQa.event('CACHE_DISK_READ', {
      'store': id,
      'hit': hit,
      'pathMs': pathMs,
      'existsMs': existsMs,
      'readMs': readMs,
      'decodeMs': decodeMs,
      'mapMs': mapMs,
      'bytes': bytes,
      'products': products,
      'compute': usedCompute,
      'totalMs': totalMs,
      if (note != null) 'note': note,
    });
    AppLog.d(
      _tag,
      'diskRead store=$id hit=$hit path=${pathMs}ms exists=${existsMs}ms '
      'read=${readMs}ms decode=${decodeMs}ms map=${mapMs}ms '
      'bytes=$bytes products=$products compute=$usedCompute '
      'total=${totalMs}ms${note != null ? ' note=$note' : ''}',
    );
  }

  Future<void> write(String storeId, List<StoreProduct> products) async {
    final id = storeId.trim();
    if (id.isEmpty) return;

    final snapshot = List<StoreProduct>.from(products);
    _memory[id] = snapshot;

    final prev = _writesInFlight[id] ?? Future<void>.value();
    late final Future<void> chained;
    chained = () async {
      try {
        await prev;
      } catch (_) {}
      await _persistDisk(id, snapshot);
    }();
    _writesInFlight[id] = chained;
    try {
      await chained;
    } finally {
      if (identical(_writesInFlight[id], chained)) {
        _writesInFlight.remove(id);
      }
    }
  }

  Future<void> _persistDisk(String id, List<StoreProduct> snapshot) async {
    try {
      // Only persist if this snapshot is still the live memory value.
      if (!identical(_memory[id], snapshot)) return;

      final maps = <Map<String, Object?>>[
        for (final product in snapshot) product.toMap(),
      ];
      final payload = await _encodeProductMaps(maps);

      // Re-check after encode — a newer write may have landed.
      if (!identical(_memory[id], snapshot)) return;

      final file = await _fileFor(id);
      await file.parent.create(recursive: true);
      await _atomicWriteString(file, payload);
    } catch (e) {
      AppLog.e(_tag, 'write failed store=$id', e);
    }
  }

  Future<void> invalidate(String storeId) async {
    final id = storeId.trim();
    if (id.isEmpty) return;
    _memory.remove(id);
    try {
      final pending = _writesInFlight[id];
      if (pending != null) {
        try {
          await pending;
        } catch (_) {}
      }
      final file = await _fileFor(id);
      if (await file.exists()) await file.delete();
    } catch (e) {
      AppLog.e(_tag, 'invalidate failed store=$id', e);
    }
  }

  /// After wishlist unlike: nudge listing badge so cache-first paint is not stale
  /// until quiet enrich lands. [delta] is usually `-1` per photo unlike.
  Future<void> adjustListingLikeCount({
    required String storeId,
    required String listingId,
    int delta = -1,
  }) async {
    final sid = storeId.trim();
    final lid = listingId.trim();
    if (sid.isEmpty || lid.isEmpty || delta == 0) return;
    final current = await read(sid);
    if (current == null || current.isEmpty) return;
    var changed = false;
    final next = <StoreProduct>[];
    for (final p in current) {
      if (p.id != lid) {
        next.add(p);
        continue;
      }
      changed = true;
      final n = (p.likeCount ?? 0) + delta;
      next.add(
        n <= 0 ? p.copyWith(clearLikeCount: true) : p.copyWith(likeCount: n),
      );
    }
    if (changed) await write(sid, next);
  }

  /// Drop in-memory entry so the next [read] hits disk (process-restart sim).
  void evictMemory(String storeId) {
    final id = storeId.trim();
    if (id.isEmpty) return;
    _memory.remove(id);
  }

  /// Clears memory + disk product caches (logout / delete account).
  Future<void> clearAll() async {
    _memory.clear();
    _readsInFlight.clear();
    try {
      final pending = List<Future<void>>.from(_writesInFlight.values);
      _writesInFlight.clear();
      if (pending.isNotEmpty) {
        await Future.wait(pending.map((f) => f.catchError((_) {})));
      }
      final root = await _docsDir();
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
    final root = await _docsDir();
    final safe = storeId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return File(p.join(root.path, _dirName, '$safe.json'));
  }

  Future<List<Map<String, Object?>>> _decodeProductMaps(String raw) async {
    if (raw.length < isolateJsonBytes) {
      debugInlineDecodeCalls++;
      return decodeStoreProductsJson(raw);
    }
    debugComputeDecodeCalls++;
    AppLog.d(_tag, 'Large products JSON (${raw.length} bytes) — compute()');
    return compute(decodeStoreProductsJson, raw);
  }

  Future<String> _encodeProductMaps(List<Map<String, Object?>> maps) async {
    if (maps.length < isolateEncodeMinProducts) {
      return encodeStoreProductsJson(maps);
    }
    AppLog.d(_tag, 'Large products encode (n=${maps.length}) — compute()');
    return compute(encodeStoreProductsJson, maps);
  }
}

/// Top-level for [compute] — decode cache JSON to product maps.
List<Map<String, Object?>> decodeStoreProductsJson(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final out = <Map<String, Object?>>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      out.add(Map<String, Object?>.from(item));
    }
    return out;
  } catch (_) {
    return const [];
  }
}

/// Top-level for [compute] — encode product maps to cache JSON.
String encodeStoreProductsJson(List<Map<String, Object?>> maps) {
  return jsonEncode(maps);
}

Future<void> _atomicWriteString(File file, String payload) async {
  final tmp = File('${file.path}.tmp');
  await tmp.writeAsString(payload, flush: true);
  if (await file.exists()) {
    await file.delete();
  }
  await tmp.rename(file.path);
}
