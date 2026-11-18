import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:project_c/helper/app_log.dart';

/// Debug-only catalog HTTP call counter for store-profile QA.
///
/// Filter logcat / IDE console with tag **`ApiCallCount`**.
///
/// Scopes:
/// - [beginStoreProfileScope] → `STORE_OPEN`
/// - [beginScreenScope] → child screens from store profile
///   (`COLLECTION_BROWSE`, `PRODUCT_DETAILS`, `STORE_CHANNEL`, …)
///
/// While a scope is open, every catalog HTTP call is listed. Scope ends after
/// idle (no new calls). Starting a different screen dumps the previous scope.
///
/// Example:
/// ```text
/// [ApiCallCount] ——— STORE_OPEN START store=abc ———
/// [ApiCallCount] #1 GET /stores/abc
/// [ApiCallCount] ——— STORE_OPEN END store=abc total=2 ———
/// [ApiCallCount] ——— COLLECTION_BROWSE START id=col1 ———
/// [ApiCallCount] #1 GET /stores/abc/products?collectionId=col1
/// [ApiCallCount] ——— COLLECTION_BROWSE END id=col1 total=1 ———
/// ```
class CatalogApiCallLog {
  CatalogApiCallLog._();

  /// Log filter tag — use this string in Logcat / Debug Console filters.
  static const tag = 'ApiCallCount';

  /// Child screens opened from store profile (and related).
  static const kindCollectionBrowse = 'COLLECTION_BROWSE';
  static const kindProductDetails = 'PRODUCT_DETAILS';
  static const kindStoreChannel = 'STORE_CHANNEL';
  static const kindStoreSearch = 'STORE_SEARCH';
  static const kindCart = 'CART';
  static const kindFollowRequests = 'FOLLOW_REQUESTS';
  static const kindFollowersFollowing = 'FOLLOWERS_FOLLOWING';
  static const kindAddProduct = 'ADD_PRODUCT';
  static const kindChatThread = 'CHAT_THREAD';
  static const kindStoreOpen = 'STORE_OPEN';

  static const _duplicateWindow = Duration(seconds: 2);

  /// Idle after the last recorded call before dumping.
  static const _idleAfterCall = Duration(milliseconds: 2000);

  /// Cache paint is not network-done — wait for quiet refresh / expands.
  static const _idleAfterCacheMilestone = Duration(seconds: 5);

  /// Network enrich done — still wait for background album expands.
  static const _idleAfterNetworkEnrich = Duration(milliseconds: 2500);

  /// Meta / members alone — collections may start later.
  static const _idleAfterSoftMilestone = Duration(seconds: 5);

  /// After END, still accept matching calls and amend the total.
  static const _lateGrace = Duration(seconds: 4);

  static String _scopeKind = kindStoreOpen;
  static String? _scopeSubjectId;
  static int _scopeTotal = 0;
  static final Map<String, int> _scopeByEndpoint = {};
  static final Map<String, DateTime> _scopeLastSeenAt = {};
  static Timer? _scopeDumpTimer;
  static Timer? _hardCloseTimer;
  static bool _scopeDumped = false;
  static int _dumpCount = 0;
  static String _pendingDumpReason = '';
  static String? _lastDumpedKind;
  static String? _lastDumpedSubjectId;
  static DateTime? _lastDumpedAt;

  /// Start (or keep) a store-profile open window for [storeId].
  static void beginStoreProfileScope(String storeId) {
    beginScreenScope(kind: kindStoreOpen, subjectId: storeId);
  }

  /// Start a named screen scope (collection browse, product details, …).
  ///
  /// [subjectId] is the store / collection / product / thread id for the log
  /// line and late-call matching. Empty ids are ignored.
  static void beginScreenScope({
    required String kind,
    required String subjectId,
  }) {
    if (!kDebugMode) return;
    final id = subjectId.trim();
    if (id.isEmpty || id == 'my_store' || id == 'other_store') return;
    final k = _normalizeKind(kind);
    if (k.isEmpty) return;

    if (_scopeKind == k && _scopeSubjectId == id && !_scopeDumped) {
      // Same screen already in progress.
      return;
    }

    if (_scopeKind == k && _scopeSubjectId == id && _scopeDumped) {
      _scopeDumped = false;
      _cancelHardClose();
      AppLog.d(tag, '——— $k CONTINUE ${_subjectLabel(k, id)} ———');
      return;
    }

    // Navigating to another screen — close the previous open window first.
    if (_scopeSubjectId != null && !_scopeDumped) {
      _dumpScopeNow(reason: 'navigated_to_$k');
    }

    _cancelDumpTimer();
    _cancelHardClose();
    _scopeKind = k;
    _scopeSubjectId = id;
    _scopeTotal = 0;
    _scopeByEndpoint.clear();
    _scopeLastSeenAt.clear();
    _scopeDumped = false;
    _dumpCount = 0;
    _pendingDumpReason = '';
    _lastDumpedKind = null;
    _lastDumpedSubjectId = null;
    _lastDumpedAt = null;
    AppLog.d(tag, '——— $k START ${_subjectLabel(k, id)} ———');
  }

  /// Record one outbound catalog call (no-op in release).
  static void record({
    required String method,
    required String path,
    Map<String, String>? query,
  }) {
    if (!kDebugMode) return;
    final methodLabel = method.trim().toUpperCase();
    final pathLabel = path.trim().isEmpty ? '/' : path.trim();
    final endpoint = _endpointKey(pathLabel, query);
    final key = '$methodLabel $endpoint';

    if (!_ensureScopeForRecord(pathLabel, endpoint)) return;

    _scopeTotal++;
    final hits = (_scopeByEndpoint[key] ?? 0) + 1;
    _scopeByEndpoint[key] = hits;

    AppLog.d(tag, '#$_scopeTotal $methodLabel $endpoint');

    final now = DateTime.now();
    final last = _scopeLastSeenAt[key];
    if (last != null &&
        now.difference(last) < _duplicateWindow &&
        hits > 1) {
      AppLog.d(
        tag,
        'DUPLICATE within ${_duplicateWindow.inSeconds}s → $methodLabel $endpoint',
      );
    }
    _scopeLastSeenAt[key] = now;

    _scheduleScopeDump(
      reason: _pendingDumpReason.isEmpty ? 'idle' : _pendingDumpReason,
      settle: _idleAfterCall,
    );
  }

  /// Milestone finished — arm idle dump (later [record] calls extend window).
  static void markStoreProfileMilestone({String reason = ''}) {
    markMilestone(reason: reason);
  }

  /// Milestone for the active screen scope.
  static void markMilestone({String reason = ''}) {
    if (!kDebugMode) return;
    if (_scopeSubjectId == null) return;
    if (_scopeDumped) return;
    final r = reason.trim().isEmpty ? 'milestone' : reason.trim();
    final Duration settle;
    if (r.startsWith('store_enrich_cache')) {
      settle = _idleAfterCacheMilestone;
    } else if (r.startsWith('store_enrich')) {
      settle = _idleAfterNetworkEnrich;
    } else {
      settle = _idleAfterSoftMilestone;
    }
    _scheduleScopeDump(reason: r, settle: settle);
  }

  /// Clear scope (logout / session epoch).
  static void reset({String reason = ''}) {
    if (!kDebugMode) return;
    final why = reason.trim().isEmpty ? '' : ' reason=$reason';
    if (_scopeSubjectId != null) {
      AppLog.d(
        tag,
        'RESET$why (scope=$_scopeKind ${_subjectLabel(_scopeKind, _scopeSubjectId!)} total=$_scopeTotal)',
      );
    }
    _cancelDumpTimer();
    _cancelHardClose();
    _scopeSubjectId = null;
    _scopeTotal = 0;
    _scopeByEndpoint.clear();
    _scopeLastSeenAt.clear();
    _scopeDumped = false;
    _dumpCount = 0;
    _pendingDumpReason = '';
    _lastDumpedKind = null;
    _lastDumpedSubjectId = null;
    _lastDumpedAt = null;
  }

  /// @Deprecated kept for call sites — use [markMilestone].
  static void dumpSummary({String reason = ''}) {
    markMilestone(reason: reason);
  }

  static String _normalizeKind(String kind) {
    return kind
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  static String _subjectLabel(String kind, String id) {
    if (kind == kindStoreOpen) return 'store=$id';
    return 'id=$id';
  }

  /// Returns false when the call should be ignored (home bootstrap, etc.).
  static bool _ensureScopeForRecord(String pathLabel, String endpoint) {
    if (_scopeSubjectId != null && !_scopeDumped) {
      return true;
    }

    final subject = _scopeSubjectId;
    if (_scopeDumped &&
        subject != null &&
        _pathBelongsToSubject(pathLabel, endpoint, subject)) {
      _scopeDumped = false;
      _cancelHardClose();
      AppLog.d(
        tag,
        '——— $_scopeKind AMEND ${_subjectLabel(_scopeKind, subject)} (late call) ———',
      );
      return true;
    }

    if (_scopeSubjectId == null &&
        _lastDumpedSubjectId != null &&
        _lastDumpedAt != null &&
        DateTime.now().difference(_lastDumpedAt!) < _lateGrace &&
        _pathBelongsToSubject(
          pathLabel,
          endpoint,
          _lastDumpedSubjectId!,
        )) {
      AppLog.d(
        tag,
        'LATE (after hard close) kind=${_lastDumpedKind ?? '?'} '
        'id=$_lastDumpedSubjectId $pathLabel',
      );
      return false;
    }

    return false;
  }

  static bool _pathBelongsToSubject(
    String path,
    String endpoint,
    String subjectId,
  ) {
    final id = subjectId.trim();
    if (id.isEmpty) return false;
    if (path.contains(id) || endpoint.contains(id)) return true;
    // Cart / me scopes: match common cart paths.
    if (id == 'cart' || id == 'me') {
      return path.contains('/cart') || path.contains('/me/');
    }
    return false;
  }

  static void _scheduleScopeDump({
    required String reason,
    required Duration settle,
  }) {
    _pendingDumpReason = reason;
    _cancelDumpTimer();
    _scopeDumpTimer = Timer(settle, () {
      _scopeDumpTimer = null;
      _dumpScopeNow(reason: reason);
    });
  }

  static void _dumpScopeNow({required String reason}) {
    final id = _scopeSubjectId;
    if (id == null) return;

    final amend = _dumpCount > 0;
    _dumpCount++;
    _scopeDumped = true;
    _lastDumpedKind = _scopeKind;
    _lastDumpedSubjectId = id;
    _lastDumpedAt = DateTime.now();

    final label = amend ? '$_scopeKind END (amended)' : '$_scopeKind END';
    AppLog.d(
      tag,
      '——— $label ${_subjectLabel(_scopeKind, id)} total=$_scopeTotal ———'
      '${reason.isEmpty ? '' : ' ($reason)'}',
    );
    if (_scopeByEndpoint.isEmpty) {
      AppLog.d(tag, '  (no catalog calls in this scope)');
    } else {
      final keys = _scopeByEndpoint.keys.toList()..sort();
      for (final key in keys) {
        AppLog.d(tag, '  ${_scopeByEndpoint[key]}× $key');
      }
    }
    AppLog.d(tag, '——— (other screens use their own scope) ———');

    _cancelHardClose();
    _hardCloseTimer = Timer(_lateGrace, _hardCloseScope);
  }

  static void _hardCloseScope() {
    _hardCloseTimer = null;
    if (!_scopeDumped) return;
    _scopeSubjectId = null;
    _scopeTotal = 0;
    _scopeByEndpoint.clear();
    _scopeLastSeenAt.clear();
    _pendingDumpReason = '';
  }

  static void _cancelDumpTimer() {
    _scopeDumpTimer?.cancel();
    _scopeDumpTimer = null;
  }

  static void _cancelHardClose() {
    _hardCloseTimer?.cancel();
    _hardCloseTimer = null;
  }

  static String _endpointKey(String path, Map<String, String>? query) {
    if (query == null || query.isEmpty) return path;
    final entries =
        query.entries
            .where((e) => e.key.trim().isNotEmpty)
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) return path;
    final q = entries.map((e) => '${e.key}=${e.value}').join('&');
    return '$path?$q';
  }
}
