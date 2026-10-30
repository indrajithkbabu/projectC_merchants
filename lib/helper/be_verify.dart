import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Debug tracer for verifying BE handoff fixes (`BACKEND_HANDOFF.md` /
/// `PRODUCT_DETAILS_BACKEND.md`).
///
/// **Logcat / console filter:** `BeVerify`
///
/// Debug builds only. Paste filtered lines when reporting pass/fail.
class BeVerify {
  BeVerify._();

  /// Search string for Android Studio Logcat / `flutter logs` / DevTools.
  static const filter = 'BeVerify';

  static bool get _enabled => kDebugMode;

  static void log(String message) {
    if (!_enabled) return;
    final line = '[$filter] $message';
    developer.log(line, name: filter);
    // ignore: avoid_print — intentional: survive debugPrint throttling
    print(line);
  }

  static void step(String title, {String? detail}) {
    log('==== $title ====');
    if (detail != null && detail.trim().isNotEmpty) {
      log('  -> ${detail.trim()}');
    }
  }

  static void ok(String check, {String? detail}) {
    log('PASS $check${detail == null || detail.isEmpty ? '' : ' | $detail'}');
  }

  static void fail(String check, {String? detail}) {
    log('FAIL $check${detail == null || detail.isEmpty ? '' : ' | $detail'}');
  }

  static void info(String check, {String? detail}) {
    log('INFO $check${detail == null || detail.isEmpty ? '' : ' | $detail'}');
  }

  static String shortId(String? id) {
    final v = (id ?? '').trim();
    if (v.isEmpty) return '(empty)';
    if (v.length <= 10) return v;
    return '${v.substring(0, 6)}…${v.substring(v.length - 4)}';
  }

  static String flag(String name, bool? value) {
    if (value == null) return '$name=OMITTED';
    return '$name=${value ? 'true' : 'false'}';
  }
}
