import 'package:characters/characters.dart';

/// Helpers for strings that reach Flutter [Text] / [TextSpan].
///
/// Device contact names can contain unpaired UTF-16 surrogates. Taking
/// `string[0]` on an emoji also yields a lone surrogate. Both crash painting.
abstract final class SafeDisplayText {
  /// Replace unpaired surrogates with U+FFFD so layout never throws.
  static String sanitize(String input) {
    if (input.isEmpty) return input;
    final out = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final cu = input.codeUnitAt(i);
      if (_isHighSurrogate(cu)) {
        if (i + 1 < input.length && _isLowSurrogate(input.codeUnitAt(i + 1))) {
          out.writeCharCode(cu);
          out.writeCharCode(input.codeUnitAt(i + 1));
          i++;
        } else {
          out.writeCharCode(0xFFFD);
        }
      } else if (_isLowSurrogate(cu)) {
        out.writeCharCode(0xFFFD);
      } else {
        out.writeCharCode(cu);
      }
    }
    return out.toString();
  }

  /// First extended grapheme cluster (emoji-safe), or empty.
  static String firstGrapheme(String input) {
    final cleaned = sanitize(input).trim();
    if (cleaned.isEmpty) return '';
    return Characters(cleaned).take(1).toString();
  }

  /// Up to [count] grapheme clusters.
  static String takeGraphemes(String input, int count) {
    final cleaned = sanitize(input).trim();
    if (cleaned.isEmpty || count <= 0) return '';
    return Characters(cleaned).take(count).toString();
  }

  /// Initials for avatars — grapheme-safe, never unpaired surrogates.
  static String initials({
    String? firstName,
    String? lastName,
    String? displayName,
    String? phone,
    String fallback = '?',
  }) {
    final first = sanitize(firstName?.trim() ?? '');
    final last = sanitize(lastName?.trim() ?? '');
    if (first.isNotEmpty && last.isNotEmpty) {
      final a = firstGrapheme(first);
      final b = firstGrapheme(last);
      if (a.isNotEmpty && b.isNotEmpty) {
        return '$a$b'.toUpperCase();
      }
    }
    if (first.isNotEmpty) {
      final chunk = takeGraphemes(first, 2);
      if (chunk.isNotEmpty) return chunk.toUpperCase();
    }

    final name = sanitize(displayName?.trim() ?? '');
    final phoneTrim = sanitize(phone?.trim() ?? '');
    if (name.isNotEmpty &&
        name != phoneTrim &&
        !name.startsWith('+') &&
        !RegExp(r'^\d+$').hasMatch(name)) {
      final parts = name.split(RegExp(r'\s+'));
      if (parts.length >= 2 &&
          parts.first.isNotEmpty &&
          parts.last.isNotEmpty) {
        final a = firstGrapheme(parts.first);
        final b = firstGrapheme(parts.last);
        if (a.isNotEmpty && b.isNotEmpty) {
          return '$a$b'.toUpperCase();
        }
      }
      final chunk = takeGraphemes(name, 2);
      if (chunk.isNotEmpty) return chunk.toUpperCase();
    }

    if (phoneTrim.length >= 2) {
      return phoneTrim.substring(phoneTrim.length - 2);
    }
    return fallback;
  }

  static bool _isHighSurrogate(int cu) => cu >= 0xD800 && cu <= 0xDBFF;
  static bool _isLowSurrogate(int cu) => cu >= 0xDC00 && cu <= 0xDFFF;
}
