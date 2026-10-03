/// Normalizes raw phone strings to E.164 (`+…`) for catalog / contact matching.
abstract final class PhoneNormalize {
  /// Digits only (no `+` or formatting).
  static String digitsOnly(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  /// Catalog contacts require international numbers beginning with `+`.
  /// Indian 10-digit mobiles are normalized to `+91…`.
  static String? toE164(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    var digits = trimmed.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.startsWith('00')) {
      digits = '+${digits.substring(2)}';
    }

    if (digits.startsWith('+')) {
      var rest = digits.substring(1).replaceAll(RegExp(r'\D'), '');
      // Common device quirk: `+91 0XXXXXXXXXX` (trunk 0 after country code).
      if (rest.length == 13 && rest.startsWith('910')) {
        final national = rest.substring(3);
        if (_isIndianMobile(national)) {
          return '+91$national';
        }
      }
      if (rest.length < 8 || rest.length > 15) return null;
      return '+$rest';
    }

    final onlyDigits = digits.replaceAll(RegExp(r'\D'), '');
    if (onlyDigits.length == 10 && _isIndianMobile(onlyDigits)) {
      return '+91$onlyDigits';
    }
    if (onlyDigits.length == 12 && onlyDigits.startsWith('91')) {
      final national = onlyDigits.substring(2);
      if (_isIndianMobile(national)) {
        return '+91$national';
      }
      return '+$onlyDigits';
    }
    if (onlyDigits.length == 11 && onlyDigits.startsWith('0')) {
      final national = onlyDigits.substring(1);
      if (_isIndianMobile(national)) {
        return '+91$national';
      }
    }
    // Android NORMALIZED_NUMBER sometimes omits `+` for other countries.
    if (onlyDigits.length >= 11 && onlyDigits.length <= 15) {
      return '+$onlyDigits';
    }
    return null;
  }

  /// Last 10 digits for loose contact matching when E.164 forms differ.
  ///
  /// Returns null when fewer than 10 digits are available (too ambiguous).
  static String? nationalKey(String raw) {
    final e164 = toE164(raw);
    final digits = digitsOnly(e164 ?? raw);
    if (digits.length < 10) return null;
    return digits.substring(digits.length - 10);
  }

  static bool _isIndianMobile(String tenDigits) {
    if (tenDigits.length != 10) return false;
    final first = tenDigits.codeUnitAt(0);
    return first >= 0x36 && first <= 0x39; // 6–9
  }
}
