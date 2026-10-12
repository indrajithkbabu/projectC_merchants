import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Day (Telegram light) vs Night (Graphite dark). Persisted in Settings.
enum AppAppearance { day, night }

extension AppAppearanceX on AppAppearance {
  String get storageValue => name;

  String get label => switch (this) {
    AppAppearance.day => 'Day mode',
    AppAppearance.night => 'Night mode',
  };

  String get subtitle => switch (this) {
    AppAppearance.day => 'Light Telegram-style colours',
    AppAppearance.night => 'Graphite dark catalogue theme',
  };

  bool get isNight => this == AppAppearance.night;

  ThemeMode get themeMode =>
      isNight ? ThemeMode.dark : ThemeMode.light;

  static AppAppearance fromStorage(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    return AppAppearance.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => AppAppearance.day,
    );
  }
}

/// Immutable palette for one appearance.
class AppColorPalette {
  const AppColorPalette({
    required this.primary,
    required this.primaryDark,
    required this.appBar,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceSecondary,
    required this.scaffold,
    required this.divider,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.textOnPrimary,
    required this.error,
    required this.success,
    required this.warning,
    required this.warningSoft,
    required this.galleryBackground,
    required this.navBar,
    required this.navBarActivePill,
    required this.navBarInactive,
    required this.navBarBorder,
    required this.navBarShadow,
    required this.backIcon,
    required this.navBarActive,
  });

  final Color primary;
  final Color primaryDark;
  final Color appBar;
  final Color accent;
  final Color background;
  final Color surface;
  final Color surfaceSecondary;
  final Color scaffold;
  final Color divider;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color textOnPrimary;
  final Color error;
  final Color success;
  final Color warning;
  final Color warningSoft;
  final Color galleryBackground;
  final Color navBar;
  final Color navBarActivePill;
  final Color navBarInactive;
  final Color navBarBorder;
  final Color navBarShadow;
  final Color backIcon;
  final Color navBarActive;

  /// Telegram-inspired light theme (white + blue).
  static const day = AppColorPalette(
    primary: Color(0xFF2AABEE),
    primaryDark: Color(0xFF229ED9),
    appBar: Color(0xFF517DA2),
    accent: Color(0xFF2481CC),
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceSecondary: Color(0xFFEFEFF4),
    scaffold: Color(0xFFF4F4F5),
    divider: Color(0xFFD7D7D7),
    border: Color(0xFFE5E7EB),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF8E8E93),
    textHint: Color(0xFF999999),
    textOnPrimary: Color(0xFFFFFFFF),
    error: Color(0xFFFF3B30),
    success: Color(0xFF4FAE4E),
    warning: Color(0xFFE67E22),
    warningSoft: Color(0xFFFFF0E0),
    galleryBackground: Color(0xFF000000),
    navBar: Color(0xFFFFFFFF),
    navBarActivePill: Color(0x1A2AABEE),
    navBarInactive: Color(0xFF8E8E93),
    navBarBorder: Color(0xFFE5E7EB),
    navBarShadow: Color(0x1A000000),
    backIcon: Color(0xFF2481CC),
    navBarActive: Color(0xFF2AABEE),
  );

  /// Graphite Dark Theme — Colour Spec (Gold Pay, Oct 2026).
  ///
  /// 11-step neutral grey ramp. No gold, no brand accent, no pure white.
  /// Colour only for product photos and functional status.
  static const night = AppColorPalette(
    // Grey ramp roles mapped to existing AppColors names:
    // fill.selected → primary, link → accent, bg.app → background/scaffold, …
    primary: Color(0xFF3A3A3D), // fill.selected / grey700
    primaryDark: Color(0xFF2D2E30), // border / grey750
    appBar: Color(0xFF131416), // bg.surface / grey900
    accent: Color(0xFF6DA9E7), // link
    background: Color(0xFF0A0A0C), // bg.app / grey950
    surface: Color(0xFF131416), // bg.surface
    surfaceSecondary: Color(0xFF1B1B1E), // bg.elevated / grey850
    scaffold: Color(0xFF0A0A0C), // bg.app
    divider: Color(0xFF2D2E30), // border / grey750
    border: Color(0xFF2D2E30),
    textPrimary: Color(0xFFD7D7DB), // text.title / grey100
    textSecondary: Color(0xFF8C8C90), // text.tertiary / grey400
    textHint: Color(0xFF8C8C90),
    textOnPrimary: Color(0xFFD7D7DB), // never #FFFFFF
    error: Color(0xFFEF6461), // danger
    success: Color(0xFF4CC38A),
    warning: Color(0xFFEF6461),
    warningSoft: Color(0xFF242426), // bg.chip / grey800
    galleryBackground: Color(0xFF0A0A0C),
    navBar: Color(0xFF131416),
    navBarActivePill: Color(0xFF3A3A3D),
    navBarInactive: Color(0xFF8C8C90),
    navBarBorder: Color(0xFF2D2E30),
    navBarShadow: Color(0x00000000), // no shadows in Graphite
    backIcon: Color(0xFFA4A4A8), // icon.active / grey300
    navBarActive: Color(0xFFD7D7DB), // text.title
  );
}

/// Active appearance colours. Call [bind] when the user switches Day/Night.
///
/// Prefer role getters (`primary`, `surface`, …) so feature code stays theme-agnostic.
abstract final class AppColors {
  static AppAppearance _appearance = AppAppearance.day;
  static AppColorPalette _palette = AppColorPalette.day;

  static AppAppearance get appearance => _appearance;
  static bool get isNight => _appearance.isNight;
  static AppColorPalette get palette => _palette;

  /// Sync getters with the persisted appearance (call before first frame + on change).
  static void bind(AppAppearance appearance) {
    _appearance = appearance;
    _palette =
        appearance == AppAppearance.night
            ? AppColorPalette.night
            : AppColorPalette.day;
  }

  // --- Semantic tokens (resolve from bound palette) ---

  static Color get primary => _palette.primary;
  static Color get primaryDark => _palette.primaryDark;
  static Color get appBar => _palette.appBar;
  static Color get accent => _palette.accent;
  static Color get background => _palette.background;
  static Color get surface => _palette.surface;
  static Color get surfaceSecondary => _palette.surfaceSecondary;
  static Color get scaffold => _palette.scaffold;
  static Color get divider => _palette.divider;
  static Color get border => _palette.border;
  static Color get textPrimary => _palette.textPrimary;
  static Color get textSecondary => _palette.textSecondary;
  static Color get textHint => _palette.textHint;
  static Color get textOnPrimary => _palette.textOnPrimary;
  static Color get error => _palette.error;
  static Color get success => _palette.success;
  static Color get warning => _palette.warning;
  static Color get warningSoft => _palette.warningSoft;
  static Color get galleryBackground => _palette.galleryBackground;
  static Color get navBar => _palette.navBar;
  static Color get navBarActivePill => _palette.navBarActivePill;
  static Color get navBarInactive => _palette.navBarInactive;
  static Color get navBarBorder => _palette.navBarBorder;
  static Color get navBarShadow => _palette.navBarShadow;
  static Color get backIcon => _palette.backIcon;
  static Color get navBarActive => _palette.navBarActive;

  /// Status-bar icon brightness for normal app chrome.
  static Brightness get statusBarIconBrightness =>
      isNight ? Brightness.light : Brightness.dark;

  static Brightness get systemNavIconBrightness =>
      isNight ? Brightness.light : Brightness.dark;

  static SystemUiOverlayStyle get systemOverlayStyle => SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: statusBarIconBrightness,
    statusBarBrightness: isNight ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: scaffold,
    systemNavigationBarIconBrightness: systemNavIconBrightness,
  );

  // --- Graphite ramp (night reference; also usable in day for rare cases) ---

  static const Color grey950 = Color(0xFF0A0A0C);
  static const Color grey900 = Color(0xFF131416);
  static const Color grey850 = Color(0xFF1B1B1E);
  static const Color grey800 = Color(0xFF242426);
  static const Color grey750 = Color(0xFF2D2E30);
  static const Color grey700 = Color(0xFF3A3A3D);
  static const Color grey500 = Color(0xFF68686C);
  static const Color grey400 = Color(0xFF8C8C90);
  static const Color grey300 = Color(0xFFA4A4A8);
  static const Color grey200 = Color(0xFFC0C0C5);
  static const Color grey100 = Color(0xFFD7D7DB);

  static const Color link = Color(0xFF6DA9E7);
  static const Color danger = Color(0xFFEF6461);
  static const Color overlayBadge = Color(0xB80A0A0C);
}
