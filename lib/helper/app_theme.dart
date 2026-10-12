import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';

abstract final class AppTheme {
  /// Telegram light (Day mode).
  static ThemeData get light => _build(
    palette: AppColorPalette.day,
    brightness: Brightness.light,
  );

  /// Graphite dark (Night mode).
  static ThemeData get dark => _build(
    palette: AppColorPalette.night,
    brightness: Brightness.dark,
  );

  static ThemeData _build({
    required AppColorPalette palette,
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;
    final textTheme = GoogleFonts.interTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
    );

    final colorScheme =
        isDark
            ? ColorScheme.dark(
              primary: palette.primary,
              onPrimary: palette.textOnPrimary,
              primaryContainer: palette.surfaceSecondary,
              onPrimaryContainer: palette.textPrimary,
              secondary: palette.accent,
              onSecondary: palette.textOnPrimary,
              surface: palette.surface,
              onSurface: palette.textPrimary,
              surfaceContainerHighest: palette.surfaceSecondary,
              error: palette.error,
              onError: palette.textOnPrimary,
              outline: palette.divider,
            )
            : ColorScheme.light(
              primary: palette.primary,
              onPrimary: palette.textOnPrimary,
              primaryContainer: palette.primary.withValues(alpha: 0.12),
              onPrimaryContainer: palette.primaryDark,
              secondary: palette.accent,
              onSecondary: palette.textOnPrimary,
              surface: palette.surface,
              onSurface: palette.textPrimary,
              surfaceContainerHighest: palette.surfaceSecondary,
              error: palette.error,
              onError: palette.textOnPrimary,
              outline: palette.divider,
            );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      fontFamily: GoogleFonts.inter().fontFamily,
      scaffoldBackgroundColor: palette.scaffold,
      primaryColor: palette.primary,
      dividerColor: palette.divider,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: palette.appBar,
        foregroundColor:
            isDark ? palette.textPrimary : palette.textOnPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTextStyles.headline(
          fontSize: 18,
          color: isDark ? palette.textPrimary : palette.textOnPrimary,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              isDark ? Brightness.light : Brightness.light,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.dark,
          systemNavigationBarColor: palette.scaffold,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.primary,
        foregroundColor: palette.textOnPrimary,
        elevation: isDark ? 0 : 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.textOnPrimary,
          textStyle: AppTextStyles.button(color: palette.textOnPrimary),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accent,
          textStyle: AppTextStyles.label(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: palette.accent,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? palette.surfaceSecondary : palette.surface,
        hintStyle: AppTextStyles.hint(
          fontSize: 15,
          color: palette.textHint,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.primary, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? palette.surfaceSecondary : palette.appBar,
        contentTextStyle: AppTextStyles.body(
          color: isDark ? palette.textPrimary : palette.textOnPrimary,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isDark ? palette.backIcon : palette.primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? palette.textPrimary : palette.primary;
          }
          return palette.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark
                ? palette.primary
                : palette.primary.withValues(alpha: 0.45);
          }
          return palette.surfaceSecondary;
        }),
      ),
    );
  }
}
