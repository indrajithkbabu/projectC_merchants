import 'package:flutter/material.dart';

/// Telegram-inspired light theme colors (white + blue).
abstract final class AppColors {
  /// Telegram brand blue.
  static const Color primary = Color(0xFF2AABEE);

  /// Slightly darker blue for pressed / emphasis states.
  static const Color primaryDark = Color(0xFF229ED9);

  /// Classic Telegram action-bar blue.
  static const Color appBar = Color(0xFF517DA2);

  /// Links and interactive accents.
  static const Color accent = Color(0xFF2481CC);

  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFEFEFF4);
  static const Color scaffold = Color(0xFFF4F4F5);

  static const Color divider = Color(0xFFD7D7D7);
  static const Color border = Color(0xFFE5E7EB);

  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textHint = Color(0xFF999999);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  static const Color error = Color(0xFFFF3B30);
  static const Color success = Color(0xFF4FAE4E);
  static const Color warning = Color(0xFFE67E22);
  static const Color warningSoft = Color(0xFFFFF0E0);

  /// iOS Photos-style gallery backdrop.
  static const Color galleryBackground = Color(0xFF000000);

  /// Floating bottom nav — light theme (matches app white + blue).
  static const Color navBar = Color(0xFFFFFFFF);
  static const Color navBarActivePill = Color(0x1A2AABEE); // primary @ 10%
  static const Color navBarInactive = Color(0xFF8E8E93);
  static const Color navBarBorder = Color(0xFFE5E7EB);
  static const Color navBarShadow = Color(0x1A000000);
}
