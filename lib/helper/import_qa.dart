import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Single Logcat / console filter for Quick Import + stock/lock matrix QA.
///
/// **Filter:** `ImportQA`
///
/// Device B (importer) / Device A (approver) checkpoints for follow → select →
/// Send → approve/decline. Debug-only.
class ImportQa {
  ImportQa._();

  /// Search string for Android Studio Logcat / `flutter logs`.
  static const filter = 'ImportQA';

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
}
