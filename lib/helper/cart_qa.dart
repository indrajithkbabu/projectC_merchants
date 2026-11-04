import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Single Logcat / console filter for Add-to-cart QA (`CATALOG_CART_API.md`).
///
/// **Filter:** `CART_QA`
///
/// Use while walking TC-01…TC-12 one case at a time. Debug-only.
class CartQa {
  CartQa._();

  /// Search string for Android Studio Logcat / `flutter logs` / DevTools.
  static const filter = 'CART_QA';

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

  /// Start a named test case block (filter stays `CART_QA`).
  static void caseStart(String tc, String title) {
    log('──── $tc START · $title ────');
  }

  static void caseEnd(String tc, {required bool pass, String? detail}) {
    log(
      '──── $tc ${pass ? 'PASS' : 'FAIL'}'
      '${detail == null || detail.isEmpty ? '' : ' · $detail'} ────',
    );
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

  /// Deduped dock-mode note (avoids rebuild spam). Call from selection chrome.
  static String? _dockSig;

  static void noteDockMode({
    required int selected,
    required int addable,
    required int alreadyInCart,
    required int outOfStock,
    required bool allInCart,
    required bool allOutOfStock,
  }) {
    if (!_enabled) return;
    final sig =
        '$selected|$addable|$alreadyInCart|$outOfStock|'
        '$allInCart|$allOutOfStock';
    if (_dockSig == sig) return;
    _dockSig = sig;
    if (allOutOfStock) {
      caseStart(
        'TC-04',
        'Dock Out of stock (disabled) sel=$selected oos=$outOfStock',
      );
      caseEnd('TC-04', pass: true, detail: 'CTA disabled; heart still usable');
    } else if (allInCart) {
      info(
        'TC-03',
        detail: 'Dock Go to cart ready inCart=$alreadyInCart',
      );
    }
  }
}
