import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/phone_normalize.dart';
import 'package:project_c/models/catalog/catalog_page.dart';
import 'package:project_c/models/catalog/catalog_store.dart';

/// Disk + memory cache of the Stores home page (`GET /home` first page).
///
/// Cold reopen paints from here immediately (no shimmer), then soft-refreshes.
/// Contact-name sidecar survives home rewrites until an enriched map is merged.
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

  /// True when at least one phone→name pair is cached for kill+reopen subtitles.
  bool get hasContactNames => _contactNames.isNotEmpty;

  /// Resolve a stored contact name for [phone] (raw or E.164 key).
  String? contactNameFor(String phone) {
    final key = phone.trim();
    if (key.isEmpty || _contactNames.isEmpty) return null;
    final direct = _contactNames[key]?.trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final e164 = PhoneNormalize.toE164(key);
    if (e164 != null && e164 != key) {
      final hit = _contactNames[e164]?.trim() ?? '';
      if (hit.isNotEmpty) return hit;
    }
    return null;
  }

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
          if (phone.isEmpty || name.isEmpty) continue;
          _putName(names, phone, name);
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

  /// Write home rows. Pass [contactNames] to merge enriched names; omit it to
  /// keep the existing sidecar (prefetch must not wipe names with `{}`).
  Future<void> write(
    CatalogPage<CatalogStore> page, {
    Map<String, String>? contactNames,
  }) async {
    if (page.items.isEmpty) return;
    final snapshot = CatalogPage<CatalogStore>(
      items: List<CatalogStore>.from(page.items),
      nextCursor: page.nextCursor,
    );
    _memory = snapshot;
    if (contactNames != null) {
      final merged = Map<String, String>.from(_contactNames);
      for (final e in contactNames.entries) {
        final phone = e.key.trim();
        final name = e.value.trim();
        if (phone.isEmpty || name.isEmpty) continue;
        _putName(merged, phone, name);
      }
      _contactNames = merged;
    }

    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      final payload = jsonEncode({
        'items': [for (final s in snapshot.items) s.toJson()],
        if (snapshot.nextCursor != null) 'nextCursor': snapshot.nextCursor,
        if (_contactNames.isNotEmpty) 'contactNames': _contactNames,
      });
      await file.writeAsString(payload, flush: true);
      AppLog.d(
        _tag,
        'write items=${snapshot.items.length} names=${_contactNames.length}',
      );
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

  static void _putName(Map<String, String> names, String phone, String name) {
    names[phone] = name;
    final e164 = PhoneNormalize.toE164(phone);
    if (e164 != null && e164 != phone) {
      names[e164] = name;
    }
  }

  Future<File> _file() async {
    final root = await getApplicationDocumentsDirectory();
    return File(p.join(root.path, 'store_home_cache', _fileName));
  }
}
