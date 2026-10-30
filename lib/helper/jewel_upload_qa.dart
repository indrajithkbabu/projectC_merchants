import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Single Logcat / console filter for jewel upload QA.
///
/// **Filter:** `JewelUploadQA`
///
/// Mirrors [CatalogUploadStory] lines and adds compose / leave / batch-branch
/// checkpoints. Debug-only.
class JewelUploadQa {
  JewelUploadQa._();

  /// Search string for Android Studio Logcat / `flutter logs`.
  static const filter = 'JewelUploadQA';

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
