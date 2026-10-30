import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:project_c/models/product_view_mode.dart';

/// In-memory scroll offsets for store profile (Telegram-style leave/return).
///
/// Keyed by store id + product view mode so Group / Single / Gallery resume
/// independently. Cleared on process death (session memory only).
///
/// Debug filter: `StoreScrollCache`
class StoreProfileScrollCache {
  StoreProfileScrollCache._();

  static final StoreProfileScrollCache instance = StoreProfileScrollCache._();

  /// Logcat / Run console filter string.
  static const filter = 'StoreScrollCache';

  final Map<String, double> _offsets = {};

  static String _key(String storeId, ProductViewMode mode) =>
      '${storeId.trim()}|${mode.name}';

  /// Debug-only. Filter console with [filter].
  static void log(String message) {
    if (!kDebugMode) return;
    final line = '[$filter] $message';
    developer.log(message, name: filter);
    // ignore: avoid_print — survive debugPrint throttling under heavy API logs
    print(line);
  }

  double? read(String storeId, ProductViewMode mode) {
    final id = storeId.trim();
    if (id.isEmpty) return null;
    final key = _key(id, mode);
    final value = _offsets[key];
    log('read key=$key → ${value?.toStringAsFixed(1) ?? 'null'} map=$_offsets');
    return value;
  }

  void write(String storeId, ProductViewMode mode, double offset) {
    final id = storeId.trim();
    if (id.isEmpty) return;
    // Do not treat <= 0 as clear — callers must use [clearMode]. A spurious
    // 0 from route teardown used to wipe resume-on-reopen.
    if (offset <= 0) {
      log('write IGNORED offset<=0 store=$id mode=${mode.name}');
      return;
    }
    final key = _key(id, mode);
    final prev = _offsets[key];
    _offsets[key] = offset;
    // Throttle scroll spam — log on first write or meaningful moves.
    if (prev == null || (prev - offset).abs() >= 80) {
      log('write key=$key offset=${offset.toStringAsFixed(1)}');
    }
  }

  void clearMode(String storeId, ProductViewMode? mode) {
    final id = storeId.trim();
    if (id.isEmpty || mode == null) return;
    final key = _key(id, mode);
    _offsets.remove(key);
    log('clearMode key=$key');
  }

  void clearStore(String storeId) {
    final id = storeId.trim();
    if (id.isEmpty) return;
    final prefix = '$id|';
    _offsets.removeWhere((k, _) => k.startsWith(prefix));
    log('clearStore store=$id');
  }
}
