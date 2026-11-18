import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Store Profile loading metrics (Batch I1) + warm ownership QA.
///
/// **Debug Console filter:** `I1QA`
///
/// **Enabled when:**
/// - Debug builds (always — use F5 / Run), or
/// - Profile/release with `--dart-define=STORE_WARM_QA=true`
///
/// Uses [debugPrint] so lines show in Cursor/VS Code Debug Console.
/// Silent in release unless the dart-define is set. No tokens/PII/full URLs.
class StoreWarmQa {
  StoreWarmQa._();

  /// Type this in Debug Console / Logcat filter.
  static const filter = 'I1QA';

  /// Legacy alias still present in each line for older paste habits.
  static const legacyFilter = 'StoreWarmQA';

  static const _flag = bool.fromEnvironment(
    'STORE_WARM_QA',
    defaultValue: false,
  );

  /// On in debug; profile needs `--dart-define=STORE_WARM_QA=true`.
  static bool get enabled => kDebugMode || _flag;

  static int _sessionSeq = 0;
  static String? openSessionId;
  static String? openStoreId;
  static Stopwatch? _tapWatch;
  static bool firstFrameSeen = false;
  static bool firstProductsReady = false;
  static bool firstImageDecodeComplete = false;
  static bool firstHeaderReady = false;
  static bool firstGridPaint = false;

  static bool _shimmerActive = false;
  static String? _shimmerReason;
  static Stopwatch? _shimmerWatch;

  static int _imageMetricCount = 0;
  static final Set<int> _imageTracked = <int>{};
  static final Set<int> _imagePlaceholderLogged = <int>{};
  static final Set<int> _imageDecodeStartLogged = <int>{};
  static final Set<int> _imageDecodeDoneLogged = <int>{};
  static const maxImageMetrics = 9;

  /// In-flight listing soft-enrich count (for concurrency observation).
  static int enrichInFlight = 0;
  static int enrichInFlightPeak = 0;

  static bool get hasOpenSession =>
      openSessionId != null && openSessionId!.isNotEmpty;

  static int? get msSinceTap => _tapWatch?.elapsedMilliseconds;

  static void log(String message) {
    if (!enabled) return;
    // Both tags on one line so Debug Console filter `I1QA` or `StoreWarmQA` works.
    final line = '[$filter] [$legacyFilter] $message';
    developer.log(line, name: filter);
    debugPrint(line);
  }

  static void step(String title, {String? detail}) {
    log('==== $title ====');
    if (detail != null && detail.trim().isNotEmpty) {
      log('  -> ${detail.trim()}');
    }
  }

  static bool _attachOpenStore(String name) {
    return name.startsWith('PROFILE') ||
        name.startsWith('GRID') ||
        name.startsWith('COLLECTION') ||
        name.startsWith('PRODUCTS') ||
        name.startsWith('QUIET') ||
        name.startsWith('IMAGE') ||
        name.startsWith('LEGACY') ||
        name.startsWith('CACHE');
  }

  /// Structured metric line: `EVENT key=value …`.
  static void event(String name, [Map<String, Object?> fields = const {}]) {
    if (!enabled) return;
    final buf = StringBuffer(name);
    final sid = openSessionId;
    if (sid != null && sid.isNotEmpty && !fields.containsKey('session')) {
      buf.write(' session=$sid');
    }
    final store = openStoreId;
    if (store != null &&
        store.isNotEmpty &&
        !fields.containsKey('store') &&
        _attachOpenStore(name)) {
      buf.write(' store=$store');
    }
    final tapMs = msSinceTap;
    if (tapMs != null && !fields.containsKey('t_ms')) {
      buf.write(' t_ms=$tapMs');
    }
    for (final e in fields.entries) {
      final v = e.value;
      if (v == null) continue;
      buf.write(' ${e.key}=$v');
    }
    log(buf.toString());
  }

  /// Stable non-PII id for a URL (hash only — never the URL).
  static String urlId(String url) {
    final t = url.trim();
    if (t.isEmpty) return 'empty';
    return 'u${t.hashCode.toRadixString(16)}';
  }

  /// Begin a tap→profile correlation session. Returns session id.
  static String beginOpenSession(String storeId) {
    if (!enabled) return '';
    final id = storeId.trim();
    _sessionSeq++;
    openSessionId = 's$_sessionSeq';
    openStoreId = id;
    _tapWatch = Stopwatch()..start();
    firstFrameSeen = false;
    firstProductsReady = false;
    firstImageDecodeComplete = false;
    firstHeaderReady = false;
    firstGridPaint = false;
    _shimmerActive = false;
    _shimmerReason = null;
    _shimmerWatch = null;
    _imageMetricCount = 0;
    _imageTracked.clear();
    _imagePlaceholderLogged.clear();
    _imageDecodeStartLogged.clear();
    _imageDecodeDoneLogged.clear();
    return openSessionId!;
  }

  static void endOpenSession({String reason = 'close'}) {
    if (!enabled) return;
    if (!hasOpenSession) return;
    event('PROFILE_SESSION_END', {'reason': reason});
    openSessionId = null;
    openStoreId = null;
    _tapWatch?.stop();
    _tapWatch = null;
    firstFrameSeen = false;
    firstProductsReady = false;
    firstImageDecodeComplete = false;
    firstHeaderReady = false;
    firstGridPaint = false;
    _shimmerActive = false;
    _shimmerReason = null;
    _shimmerWatch = null;
    _imageMetricCount = 0;
    _imageTracked.clear();
    _imagePlaceholderLogged.clear();
    _imageDecodeStartLogged.clear();
    _imageDecodeDoneLogged.clear();
  }

  static void markFirstFrame() {
    if (!enabled || firstFrameSeen) return;
    firstFrameSeen = true;
    event('PROFILE_FIRST_FRAME');
  }

  /// Batch I5 — header can paint from listing/meta seed (independent of API).
  static void markHeaderReady({required String storeName, bool seeded = true}) {
    if (!enabled || firstHeaderReady) return;
    firstHeaderReady = true;
    event('HEADER_READY', {
      'seeded': seeded,
      'hasName': storeName.trim().isNotEmpty,
    });
  }

  /// Batch I5 — first non-empty product grid commit after open.
  static void markFirstGridPaint({
    required int products,
    required String source,
  }) {
    if (!enabled || firstGridPaint) return;
    firstGridPaint = true;
    event('GRID_FIRST_PAINT', {'products': products, 'source': source});
  }

  /// Transition-only shimmer observer (safe to call from builds).
  ///
  /// [reason]: `unresolved` | `loading` | `metaLock` | `cachedProducts` | `none`
  static void observeShimmer({required bool show, required String reason}) {
    if (!enabled) return;
    if (show == _shimmerActive && reason == _shimmerReason) return;

    if (show && !_shimmerActive) {
      _shimmerActive = true;
      _shimmerReason = reason;
      _shimmerWatch = Stopwatch()..start();
      event('GRID_SHIMMER_START', {'reason': reason});
      return;
    }

    if (!show && _shimmerActive) {
      final ms = _shimmerWatch?.elapsedMilliseconds ?? 0;
      final prev = _shimmerReason ?? 'unknown';
      _shimmerActive = false;
      _shimmerWatch?.stop();
      event('GRID_SHIMMER_END', {'reason': prev, 'next': reason});
      event('GRID_SHIMMER_DURATION', {'ms': ms, 'reason': prev});
      _shimmerReason = reason;
      _shimmerWatch = null;
      return;
    }

    if (show && _shimmerActive && reason != _shimmerReason) {
      event('GRID_SHIMMER_REASON', {
        'from': _shimmerReason ?? 'unknown',
        'to': reason,
      });
    }
    _shimmerReason = reason;
  }

  static void noteFirstProductsReady({
    required int count,
    required String source,
  }) {
    if (!enabled) return;
    if (!firstProductsReady) {
      firstProductsReady = true;
      event('GRID_FIRST_PRODUCTS_READY', {'products': count, 'source': source});
      markFirstGridPaint(products: count, source: source);
    }
    event('PRODUCTS_READY', {'products': count, 'source': source});
  }

  static void noteEmptyResolved({required String source}) {
    event('GRID_EMPTY_RESOLVED', {'source': source});
  }

  static bool _trackImage(String url) {
    if (!enabled || !hasOpenSession) return false;
    final key = url.trim().hashCode;
    if (_imageTracked.contains(key)) return true;
    if (_imageMetricCount >= maxImageMetrics) return false;
    _imageTracked.add(key);
    _imageMetricCount++;
    return true;
  }

  static void imagePlaceholder(String url, {int? cacheWidth}) {
    if (!_trackImage(url)) return;
    final key = url.trim().hashCode;
    if (!_imagePlaceholderLogged.add(key)) return;
    event('IMAGE_PLACEHOLDER', {
      'id': urlId(url),
      if (cacheWidth != null) 'cacheW': cacheWidth,
    });
  }

  static void imageDecodeStart(String url, {int? cacheWidth}) {
    if (!_trackImage(url)) return;
    final key = url.trim().hashCode;
    if (!_imageDecodeStartLogged.add(key)) return;
    event('IMAGE_DECODE_START', {
      'id': urlId(url),
      if (cacheWidth != null) 'cacheW': cacheWidth,
      'note': 'warmOrPaint',
    });
  }

  static void imageDecodeComplete(
    String url, {
    int? cacheWidth,
    int? durationMs,
    String via = 'frame',
  }) {
    if (!_trackImage(url)) return;
    final key = url.trim().hashCode;
    if (!_imageDecodeDoneLogged.add(key)) return;
    event('IMAGE_DECODE_COMPLETE', {
      'id': urlId(url),
      if (cacheWidth != null) 'cacheW': cacheWidth,
      if (durationMs != null) 'ms': durationMs,
      'via': via,
      'note': 'notPaintGuarantee',
    });
    if (!firstImageDecodeComplete) {
      firstImageDecodeComplete = true;
      event('IMAGE_FIRST_DECODE_COMPLETE', {
        'id': urlId(url),
        if (cacheWidth != null) 'cacheW': cacheWidth,
        'via': via,
      });
    }
  }

  static void imageDecodeFailed(String url, {int? cacheWidth}) {
    if (!_trackImage(url)) return;
    event('IMAGE_DECODE_FAILED', {
      'id': urlId(url),
      if (cacheWidth != null) 'cacheW': cacheWidth,
    });
  }

  static void trackEnrichStart() {
    if (!enabled) return;
    enrichInFlight++;
    if (enrichInFlight > enrichInFlightPeak) {
      enrichInFlightPeak = enrichInFlight;
    }
  }

  static void trackEnrichEnd() {
    if (!enabled) return;
    if (enrichInFlight > 0) enrichInFlight--;
  }
}
