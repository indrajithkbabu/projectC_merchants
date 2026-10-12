import 'package:flutter/foundation.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/store_privacy_mode.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/storage/app_settings_storage.dart';
import 'package:project_c/webservice/store/store_repository.dart';

/// Store privacy preference: local cache + `PATCH /stores/:id/privacy`.
///
/// Default is [StorePrivacyMode.public] for new stores. Local value survives
/// logout as a cache; [refreshFromServer] / [setMode] keep it aligned with
/// the catalog API when the user owns a store.
class StorePrivacyPreferences extends ChangeNotifier {
  StorePrivacyPreferences({required AppSettingsStorage storage})
    : _storage = storage;

  static const _tag = 'StorePrivacyPreferences';

  final AppSettingsStorage _storage;

  StorePrivacyMode _mode = StorePrivacyMode.public;
  int _pendingFollowRequestCount = 0;
  bool _loaded = false;
  bool _busy = false;

  StorePrivacyMode get mode => _mode;
  bool get isPrivate => _mode.isPrivate;
  bool get isLoaded => _loaded;
  bool get isBusy => _busy;

  /// Pending follow requests (private stores only). Used by the
  /// switch-to-public confirm sheet. Sourced from GET store /
  /// `pendingRequestsCount` when available.
  int get pendingFollowRequestCount =>
      _mode.isPrivate ? _pendingFollowRequestCount : 0;

  Future<void> load() async {
    _mode = await _storage.readStorePrivacyMode();
    _pendingFollowRequestCount =
        await _storage.readPendingFollowRequestCount();
    _loaded = true;
    AppLog.d(
      _tag,
      'loaded mode=${_mode.storageValue} pending=$_pendingFollowRequestCount',
    );
    notifyListeners();
  }

  /// Pull current privacy + pending count from GET store (own store only).
  Future<void> refreshFromServer() async {
    final storeId = _ownStoreId;
    if (storeId == null) return;
    try {
      final store = await _stores.fetchStore(storeId);
      final next = store.privacy ?? StorePrivacyMode.public;
      await applyFromServer(
        next,
        pendingCount: store.pendingRequestsCount,
      );
    } catch (e) {
      AppLog.e(_tag, 'refreshFromServer failed', e);
      rethrow;
    }
  }

  /// Soft sync from a store payload already fetched elsewhere (no network).
  Future<void> applyFromServer(
    StorePrivacyMode mode, {
    int? pendingCount,
  }) async {
    _mode = mode;
    if (mode == StorePrivacyMode.public) {
      _pendingFollowRequestCount = 0;
    } else if (pendingCount != null) {
      _pendingFollowRequestCount = pendingCount < 0 ? 0 : pendingCount;
    }
    _loaded = true;
    notifyListeners();
    await _storage.writeStorePrivacyMode(mode);
    await _storage.writePendingFollowRequestCount(_pendingFollowRequestCount);
    AppLog.d(
      _tag,
      'applyFromServer mode=${mode.storageValue} '
      'pending=$_pendingFollowRequestCount',
    );
  }

  /// Confirmed privacy switch via PATCH. Throws on API failure so the UI can
  /// revert the preview and show [CatalogErrorMapper] copy.
  Future<void> setMode(StorePrivacyMode mode) async {
    if (_mode == mode && _loaded) return;
    final storeId = _ownStoreId;
    if (storeId == null || storeId.isEmpty) {
      throw StateError('No own store to update privacy');
    }

    _busy = true;
    notifyListeners();
    try {
      final updated = await _stores.patchStorePrivacy(
        storeId: storeId,
        privacy: mode,
      );
      final next = updated.privacy ?? mode;
      final pending =
          next == StorePrivacyMode.public
              ? 0
              : (updated.pendingRequestsCount ?? 0);
      await applyFromServer(next, pendingCount: pending);
      AppLog.d(
        _tag,
        'setMode ok=${next.storageValue} '
        'autoApproved=${updated.autoApprovedFollowers}',
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  String? get _ownStoreId {
    final id = ServiceLocator.get<CatalogSession>().ownStoreId?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  StoreRepository get _stores => ServiceLocator.get<StoreRepository>();
}
