import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/catalog_store.dart';
import 'package:project_c/models/catalog/collection_models.dart';

/// Cached store header / showcase snapshot (display always reads from here).
class StoreMetaSnapshot extends Equatable {
  const StoreMetaSnapshot({
    this.storeName = '',
    this.storeLink = '',
    this.coverImageUrl = '',
    this.storeImages = const [],
  });

  final String storeName;
  final String storeLink;
  final String coverImageUrl;
  final List<CatalogPhoto> storeImages;

  factory StoreMetaSnapshot.fromCatalogStore(CatalogStore store) {
    return StoreMetaSnapshot(
      storeName: store.name.trim(),
      storeLink: store.storeLink,
      coverImageUrl: store.coverImageUrl.trim(),
      storeImages: List<CatalogPhoto>.from(store.images),
    );
  }

  Map<String, Object?> toJson() => {
    'storeName': storeName,
    'storeLink': storeLink,
    'coverImageUrl': coverImageUrl,
    'storeImages': [
      for (final photo in storeImages) photo.toJson(),
    ],
  };

  factory StoreMetaSnapshot.fromJson(Map<String, dynamic> json) {
    final rawImages = json['storeImages'];
    return StoreMetaSnapshot(
      storeName: '${json['storeName'] ?? ''}'.trim(),
      storeLink: '${json['storeLink'] ?? ''}'.trim(),
      coverImageUrl: '${json['coverImageUrl'] ?? ''}'.trim(),
      storeImages:
          rawImages is List
              ? rawImages
                  .whereType<Map>()
                  .map(
                    (e) => CatalogPhoto.fromJson(Map<String, dynamic>.from(e)),
                  )
                  .toList()
              : const [],
    );
  }

  @override
  List<Object?> get props => [storeName, storeLink, coverImageUrl, storeImages];
}

/// Memory + disk cache for store meta. UI paints from cache; API writes cache.
class StoreMetaCache {
  StoreMetaCache._();

  static final StoreMetaCache instance = StoreMetaCache._();

  static const _tag = 'StoreMetaCache';
  static const _dirName = 'store_meta_cache';

  final Map<String, StoreMetaSnapshot> _memory = {};

  StoreMetaSnapshot? readMemory(String storeId) {
    final id = storeId.trim();
    if (id.isEmpty) return null;
    return _memory[id];
  }

  String? readCoverMemory(String storeId) {
    final cover = readMemory(storeId)?.coverImageUrl.trim() ?? '';
    return cover.isEmpty ? null : cover;
  }

  Future<StoreMetaSnapshot?> read(String storeId) async {
    final id = storeId.trim();
    if (id.isEmpty) return null;
    final mem = readMemory(id);
    if (mem != null) return mem;
    try {
      final file = await _fileFor(id);
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final snap = StoreMetaSnapshot.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      _memory[id] = snap;
      return snap;
    } catch (e) {
      AppLog.e(_tag, 'read failed store=$id', e);
      return null;
    }
  }

  Future<void> write(String storeId, StoreMetaSnapshot snapshot) async {
    final id = storeId.trim();
    if (id.isEmpty) return;
    _memory[id] = snapshot;
    try {
      final file = await _fileFor(id);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(snapshot.toJson()), flush: true);
    } catch (e) {
      AppLog.e(_tag, 'write failed store=$id', e);
    }
  }

  /// Convenience when only the cover URL is known (e.g. from listing).
  Future<void> writeCover(String storeId, String coverImageUrl) async {
    final id = storeId.trim();
    final cover = coverImageUrl.trim();
    if (id.isEmpty) return;
    final prev = await read(id);
    await write(
      id,
      StoreMetaSnapshot(
        storeName: prev?.storeName ?? '',
        storeLink: prev?.storeLink ?? '',
        coverImageUrl: cover,
        storeImages: prev?.storeImages ?? const [],
      ),
    );
  }

  /// Clears memory + disk meta caches (logout / delete account).
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
