/// Normalizes raw phone strings to E.164 (`+…`) for catalog / contact matching.
abstract final class PhoneNormalize {
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
      final rest = digits.substring(1).replaceAll(RegExp(r'\D'), '');
      if (rest.length < 8 || rest.length > 15) return null;
      return '+$rest';
    }

    final onlyDigits = digits.replaceAll(RegExp(r'\D'), '');
    if (onlyDigits.length == 10 &&
        onlyDigits.codeUnitAt(0) >= 0x36 &&
        onlyDigits.codeUnitAt(0) <= 0x39) {
      return '+91$onlyDigits';
    }
    if (onlyDigits.length == 12 && onlyDigits.startsWith('91')) {
      return '+$onlyDigits';
    }
    if (onlyDigits.length == 11 && onlyDigits.startsWith('0')) {
      final national = onlyDigits.substring(1);
      if (national.length == 10 &&
          national.codeUnitAt(0) >= 0x36 &&
          national.codeUnitAt(0) <= 0x39) {
        return '+91$national';
      }
    }
    return null;
  }
}
