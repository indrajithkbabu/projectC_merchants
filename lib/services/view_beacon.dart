import 'dart:async';

import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/view_api_models.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/webservice/views/views_repository.dart';

/// Client-side batch buffer for `POST /v1/catalog/views`.
///
/// Dedupes per app session, flushes every [flushInterval] or when the buffer
/// hits [maxBatchSize], and on [flush] (app background / screen dispose).
class ViewBeacon {
  ViewBeacon._();

  static final ViewBeacon instance = ViewBeacon._();

  static const _tag = 'ViewBeacon';
  static const Duration flushInterval = Duration(seconds: 4);
  static const int maxBatchSize = 50;

  final Map<String, ViewBeaconItem> _buffer = {};
  final Set<String> _sessionSeen = {};
  Timer? _flushTimer;
  bool _flushing = false;

  /// Queue a qualified view (caller enforces 1s dwell).
  void enqueue({required String type, required String id}) {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) return;
    final normalizedType = type.trim().isEmpty ? 'photo' : type.trim();
    final item = ViewBeaconItem(type: normalizedType, id: trimmedId);
    final key = item.sessionKey;
    if (_sessionSeen.contains(key)) return;
    _sessionSeen.add(key);
    _buffer[key] = item;

    if (_buffer.length >= maxBatchSize) {
      // ignore: unawaited_futures
      flush();
    } else {
      _flushTimer ??= Timer(flushInterval, () {
        // ignore: unawaited_futures
        flush();
      });
    }
  }

  void enqueuePhoto(String photoId) => enqueue(type: 'photo', id: photoId);

  void enqueueCollection(String listingId) =>
      enqueue(type: 'collection', id: listingId);

  void enqueueSubgroup(String subGroupId) =>
      enqueue(type: 'subgroup', id: subGroupId);

  /// Send buffered items (fire-and-forget). Safe to call repeatedly.
  Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_flushing || _buffer.isEmpty) return;

    CatalogSession session;
    try {
      session = ServiceLocator.get<CatalogSession>();
    } catch (_) {
      return;
    }
    if (!session.isSignedIn) {
      _buffer.clear();
      return;
    }

    ViewsRepository repo;
    try {
      repo = ServiceLocator.get<ViewsRepository>();
    } catch (_) {
      return;
    }

    final batch = _buffer.values.take(maxBatchSize).toList(growable: false);
    for (final item in batch) {
      _buffer.remove(item.sessionKey);
    }
    if (batch.isEmpty) return;

    _flushing = true;
    try {
      await repo.recordViews(batch);
    } catch (e) {
      // Fire-and-forget: do not re-queue (avoids reconnect storms).
      AppLog.e(_tag, 'Beacon flush failed', e);
    } finally {
      _flushing = false;
      if (_buffer.isNotEmpty) {
        _flushTimer ??= Timer(flushInterval, () {
          // ignore: unawaited_futures
          flush();
        });
      }
    }
  }

  /// Drop session state (logout).
  void reset() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _buffer.clear();
    _sessionSeen.clear();
  }
}
