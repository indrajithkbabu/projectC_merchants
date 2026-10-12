import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/catalog_page.dart';
import 'package:project_c/models/catalog/catalog_store.dart';

/// Disk + memory cache of the Stores home page (`GET /home` first page).
///
/// Cold reopen paints from here immediately (no shimmer), then soft-refreshes.
class StoreHomeCache {
  StoreHomeCache._();

  static final StoreHomeCache instance = StoreHomeCache._();

  static const _tag = 'StoreHomeCache';
  static const _fileName = 'store_home_cache.json';

  CatalogPage<CatalogStore>? _memory;
  Map<String, String> _contactNames = const {};

  /// Sync hit for the first frame after [preload] / [write].
  CatalogPage<CatalogStore>? readMemory() {
    final mem = _memory;
    if (mem == null || mem.items.isEmpty) return null;
    return mem;
  }

  /// Phone → device contact name from the last enriched paint.
  Map<String, String> contactNamesMemory() =>
      Map<String, String>.from(_contactNames);

  /// Load disk into memory (auth restore / listing mount).
  Future<CatalogPage<CatalogStore>?> read() async {
    final mem = readMemory();
    if (mem != null) return mem;

    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, Object?>.from(decoded);
      final itemsRaw = map['items'];
      if (itemsRaw is! List || itemsRaw.isEmpty) return null;
      final items = <CatalogStore>[];
      for (final item in itemsRaw) {
        if (item is! Map) continue;
        final store = CatalogStore.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (store.id.trim().isEmpty) continue;
        items.add(store);
      }
      if (items.isEmpty) return null;
      final cursor = (map['nextCursor'] as String?)?.trim();
      final namesRaw = map['contactNames'];
      final names = <String, String>{};
      if (namesRaw is Map) {
        for (final e in namesRaw.entries) {
          final phone = '${e.key}'.trim();
          final name = '${e.value}'.trim();
          if (phone.isNotEmpty && name.isNotEmpty) names[phone] = name;
        }
      }
      final page = CatalogPage<CatalogStore>(
        items: items,
        nextCursor: (cursor == null || cursor.isEmpty) ? null : cursor,
      );
      _memory = page;
      _contactNames = names;
      AppLog.d(_tag, 'read items=${items.length} names=${names.length}');
      return page;
    } catch (e) {
      AppLog.e(_tag, 'read failed', e);
      return null;
    }
  }

  Future<void> write(
    CatalogPage<CatalogStore> page, {
    Map<String, String> contactNames = const {},
  }) async {
    if (page.items.isEmpty) return;
    final snapshot = CatalogPage<CatalogStore>(
      items: List<CatalogStore>.from(page.items),
      nextCursor: page.nextCursor,
    );
    final names = <String, String>{
      for (final e in contactNames.entries)
        if (e.key.trim().isNotEmpty && e.value.trim().isNotEmpty)
          e.key.trim(): e.value.trim(),
    };
    _memory = snapshot;
    _contactNames = names;

    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      final payload = jsonEncode({
        'items': [for (final s in snapshot.items) s.toJson()],
        if (snapshot.nextCursor != null) 'nextCursor': snapshot.nextCursor,
        if (names.isNotEmpty) 'contactNames': names,
      });
      await file.writeAsString(payload, flush: true);
      AppLog.d(_tag, 'write items=${snapshot.items.length}');
    } catch (e) {
      AppLog.e(_tag, 'write failed', e);
    }
  }

  Future<void> clearAll() async {
    _memory = null;
    _contactNames = const {};
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
      AppLog.d(_tag, 'clearAll done');
    } catch (e) {
      AppLog.e(_tag, 'clearAll failed', e);
    }
  }

  Future<File> _file() async {
    final root = await getApplicationDocumentsDirectory();
    return File(p.join(root.path, 'store_home_cache', _fileName));
  }
}
