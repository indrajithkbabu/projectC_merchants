import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/catalog_store.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/models/store_privacy_mode.dart';

/// Cached store header / showcase snapshot (display always reads from here).
class StoreMetaSnapshot extends Equatable {
  const StoreMetaSnapshot({
    this.storeName = '',
    this.storeLink = '',
    this.coverImageUrl = '',
    this.storeImages = const [],
    this.city = '',
    this.privacy = StorePrivacyMode.public,
    this.followerCount = 0,
    this.followingCount = 0,
    this.productCount,
    this.pendingRequestsCount,
    this.canViewContent = true,
    this.followStatus = StoreFollowStatus.none,
  });

  final String storeName;
  final String storeLink;
  final String coverImageUrl;
  final List<CatalogPhoto> storeImages;
  final String city;
  final StorePrivacyMode privacy;
  final int followerCount;
  final int followingCount;
  final int? productCount;
  final int? pendingRequestsCount;
  final bool canViewContent;
  final StoreFollowStatus followStatus;

  factory StoreMetaSnapshot.fromCatalogStore(CatalogStore store) {
    final follow = storeFollowStatusFromString(store.followStatusRaw);
    final isOwnerOrMember =
        store.relationship == StoreRelationship.owner ||
        store.relationship == StoreRelationship.member ||
        follow == StoreFollowStatus.self ||
        follow == StoreFollowStatus.member;
    return StoreMetaSnapshot(
      storeName: store.name.trim(),
      storeLink: store.storeLink,
      coverImageUrl: store.coverImageUrl.trim(),
      storeImages: List<CatalogPhoto>.from(store.images),
      city: store.city.trim(),
      privacy: store.privacy ?? StorePrivacyMode.public,
      followerCount: store.followerCount,
      followingCount: store.followingCount,
      productCount: store.productCount,
      pendingRequestsCount: store.pendingRequestsCount,
      canViewContent: isOwnerOrMember ? true : store.resolvedCanViewContent,
      followStatus: follow,
    );
  }

  Map<String, Object?> toJson() => {
    'storeName': storeName,
    'storeLink': storeLink,
    'coverImageUrl': coverImageUrl,
    'storeImages': [for (final photo in storeImages) photo.toJson()],
    'city': city,
    'privacy': privacy.apiValue,
    'followerCount': followerCount,
    'followingCount': followingCount,
    if (productCount != null) 'productCount': productCount,
    if (pendingRequestsCount != null)
      'pendingRequestsCount': pendingRequestsCount,
    'canViewContent': canViewContent,
    'followStatus': followStatus.apiValue,
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
      city: '${json['city'] ?? ''}'.trim(),
      privacy: StorePrivacyModeX.fromApi(json['privacy'] as String?),
      followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
      followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
      productCount: (json['productCount'] as num?)?.toInt(),
      pendingRequestsCount: (json['pendingRequestsCount'] as num?)?.toInt(),
      canViewContent: json['canViewContent'] as bool? ?? true,
      followStatus: storeFollowStatusFromString(
        json['followStatus'] as String?,
      ),
    );
  }

  StoreMetaSnapshot copyWith({
    String? storeName,
    String? storeLink,
    String? coverImageUrl,
    List<CatalogPhoto>? storeImages,
    String? city,
    StorePrivacyMode? privacy,
    int? followerCount,
    int? followingCount,
    int? productCount,
    int? pendingRequestsCount,
    bool? canViewContent,
    StoreFollowStatus? followStatus,
  }) {
    return StoreMetaSnapshot(
      storeName: storeName ?? this.storeName,
      storeLink: storeLink ?? this.storeLink,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      storeImages: storeImages ?? this.storeImages,
      city: city ?? this.city,
      privacy: privacy ?? this.privacy,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      productCount: productCount ?? this.productCount,
      pendingRequestsCount: pendingRequestsCount ?? this.pendingRequestsCount,
      canViewContent: canViewContent ?? this.canViewContent,
      followStatus: followStatus ?? this.followStatus,
    );
  }

  @override
  List<Object?> get props => [
    storeName,
    storeLink,
    coverImageUrl,
    storeImages,
    city,
    privacy,
    followerCount,
    followingCount,
    productCount,
    pendingRequestsCount,
    canViewContent,
    followStatus,
  ];
}

/// Memory + disk cache for store meta. UI paints from cache; API writes cache.
///
/// Batch 3: large showcase JSON uses [compute]; writes are chained per store
/// and written atomically (temp → rename).
class StoreMetaCache {
  StoreMetaCache._();

  static final StoreMetaCache instance = StoreMetaCache._();

  static const _tag = 'StoreMetaCache';
  static const _dirName = 'store_meta_cache';

  /// Match products / API client large-body isolate threshold.
  static const isolateJsonBytes = 32 * 1024;

  final Map<String, StoreMetaSnapshot> _memory = {};
  final Map<String, Future<StoreMetaSnapshot?>> _readsInFlight = {};
  final Map<String, Future<void>> _writesInFlight = {};

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

  Future<StoreMetaSnapshot?> _readDisk(String id) async {
    try {
      final file = await _fileFor(id);
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      final map = await _decodeMetaMap(raw);
      if (map == null) return null;
      final snap = StoreMetaSnapshot.fromJson(map);
      final newer = _memory[id];
      if (newer != null) return newer;
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

  Future<void> _persistDisk(String id, StoreMetaSnapshot snapshot) async {
    try {
      if (!identical(_memory[id], snapshot)) return;
      final payload = await _encodeMetaJson(snapshot.toJson());
      if (!identical(_memory[id], snapshot)) return;
      final file = await _fileFor(id);
      await file.parent.create(recursive: true);
      await _atomicWriteMetaString(file, payload);
    } catch (e) {
      AppLog.e(_tag, 'write failed store=$id', e);
    }
  }

  /// Convenience when only the cover URL is known (e.g. from listing).
  ///
  /// Cover-only stubs must not claim [StoreMetaSnapshot.canViewContent] —
  /// default `true` would unlock private stores before GET store / home meta.
  Future<void> writeCover(String storeId, String coverImageUrl) async {
    final id = storeId.trim();
    final cover = coverImageUrl.trim();
    if (id.isEmpty) return;
    final prev = await read(id);
    if (prev != null) {
      await write(id, prev.copyWith(coverImageUrl: cover));
      return;
    }
    await write(
      id,
      StoreMetaSnapshot(coverImageUrl: cover, canViewContent: false),
    );
  }

  /// Clears memory + disk meta caches (logout / delete account).
  Future<void> clearAll() async {
    _memory.clear();
    _readsInFlight.clear();
    try {
      final pending = List<Future<void>>.from(_writesInFlight.values);
      _writesInFlight.clear();
      if (pending.isNotEmpty) {
        await Future.wait(pending.map((f) => f.catchError((_) {})));
      }
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

  static Future<Map<String, dynamic>?> _decodeMetaMap(String raw) async {
    if (raw.length < isolateJsonBytes) {
      return decodeStoreMetaJson(raw);
    }
    AppLog.d(_tag, 'Large meta JSON (${raw.length} bytes) — compute()');
    return compute(decodeStoreMetaJson, raw);
  }

  static Future<String> _encodeMetaJson(Map<String, Object?> json) async {
    // Showcase image lists can be large; isolate when map is heavy.
    final imageCount =
        (json['storeImages'] is List)
            ? (json['storeImages'] as List).length
            : 0;
    if (imageCount < 24) {
      return encodeStoreMetaJson(json);
    }
    AppLog.d(_tag, 'Large meta encode (images=$imageCount) — compute()');
    return compute(encodeStoreMetaJson, json);
  }
}

/// Top-level for [compute] — decode meta JSON map (null if invalid).
Map<String, dynamic>? decodeStoreMetaJson(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  } catch (_) {
    return null;
  }
}

/// Top-level for [compute] — encode meta JSON.
String encodeStoreMetaJson(Map<String, Object?> json) {
  return jsonEncode(json);
}

Future<void> _atomicWriteMetaString(File file, String payload) async {
  final tmp = File('${file.path}.tmp');
  await tmp.writeAsString(payload, flush: true);
  if (await file.exists()) {
    await file.delete();
  }
  await tmp.rename(file.path);
}
