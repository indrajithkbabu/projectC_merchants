import 'package:flutter/foundation.dart';

/// Lightweight debug logging for network and session flows.
class AppLog {
  AppLog._();

  static void d(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[$tag] $message');
    }
  }

  static void e(String tag, String message, [Object? error]) {
    if (kDebugMode) {
      debugPrint('[$tag] ERROR: $message${error != null ? ' | $error' : ''}');
    }
  }
}
