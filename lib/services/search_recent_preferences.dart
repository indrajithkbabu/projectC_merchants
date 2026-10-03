import 'dart:convert';

import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/search_models.dart';
import 'package:project_c/storage/app_settings_storage.dart';

/// Device-local recent searches for Discover (survives route pops).
///
/// Backend `/search/meta` currently returns stub recents; until a real
/// per-user recent API exists, the UI uses this list only.
class SearchRecentPreferences {
  SearchRecentPreferences({required AppSettingsStorage storage})
    : _storage = storage;

  static const _tag = 'SearchRecentPreferences';
  /// Discover shows only the latest few; keep storage in sync with UI.
  static const _maxItems = 3;

  final AppSettingsStorage _storage;

  Future<List<SearchRecentEntry>> read() async {
    final raw = await _storage.readSearchRecentsJson();
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final items = decoded
          .whereType<Map>()
          .map((e) => SearchRecentEntry.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.displayText.trim().isNotEmpty)
          .take(_maxItems)
          .toList();
      // Trim legacy lists that were stored with a higher cap.
      if (decoded.length > _maxItems) {
        await _storage.writeSearchRecentsJson(
          jsonEncode(items.map(_toJson).toList()),
        );
      }
      return items;
    } catch (e) {
      AppLog.d(_tag, 'read failed: $e');
      return const [];
    }
  }

  Future<List<SearchRecentEntry>> addQuery({
    required String text,
    String label = '',
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return read();
    return _push(
      SearchRecentEntry(
        type: 'query',
        text: trimmed,
        label: label,
      ),
    );
  }

  Future<List<SearchRecentEntry>> addStore({
    required String name,
    String? storeId,
    String? slug,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return read();
    return _push(
      SearchRecentEntry(
        type: 'store',
        name: trimmed,
        label: 'store',
        storeId: storeId,
        slug: slug,
      ),
    );
  }

  Future<List<SearchRecentEntry>> clear() async {
    await _storage.writeSearchRecentsJson('[]');
    AppLog.d(_tag, 'cleared');
    return const [];
  }

  Future<List<SearchRecentEntry>> _push(SearchRecentEntry entry) async {
    final current = await read();
    final next = <SearchRecentEntry>[
      entry,
      ...current.where((e) {
        if (entry.isStore) {
          if (!e.isStore) return true;
          if (entry.storeId != null &&
              entry.storeId!.isNotEmpty &&
              e.storeId == entry.storeId) {
            return false;
          }
          return e.name.toLowerCase() != entry.name.toLowerCase();
        }
        if (e.isStore) return true;
        return e.text.toLowerCase() != entry.text.toLowerCase();
      }),
    ].take(_maxItems).toList();

    await _storage.writeSearchRecentsJson(
      jsonEncode(next.map(_toJson).toList()),
    );
    return next;
  }

  Map<String, dynamic> _toJson(SearchRecentEntry e) => {
        'type': e.type,
        'text': e.text,
        'name': e.name,
        'label': e.label,
        if (e.storeId != null) 'id': e.storeId,
        if (e.slug != null) 'slug': e.slug,
      };
}
