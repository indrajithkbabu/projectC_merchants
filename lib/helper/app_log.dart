import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Lightweight debug logging for network and session flows.
class AppLog {
  AppLog._();

  static void d(String tag, String message) {
    if (!kDebugMode) return;
    debugPrint('[$tag] $message');
  }

  static void e(String tag, String message, [Object? error]) {
    if (!kDebugMode) return;
    debugPrint(
      '[$tag] ERROR: $message${error != null ? ' | $error' : ''}',
    );
  }

  /// Full payload on one stream (no pretty multi-line). Uses [developer.log]
  /// so DevTools keeps the complete body, and [print] for the console.
  static void full(String tag, String label, Object? value) {
    if (!kDebugMode) return;
    final text =
        value is String
            ? value
            : () {
              try {
                return jsonEncode(value);
              } catch (_) {
                return '$value';
              }
            }();
    final line = '[$tag] $label=$text';
    developer.log(line, name: tag);
    // ignore: avoid_print
    print(line);
  }
}
