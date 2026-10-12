import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project_c/helper/colors.dart';

/// Shared Inter text styles. Override [color], [fontSize], or [fontWeight] per use.
///
/// Colour defaults resolve at call time from the bound [AppColors] appearance
/// (Day / Night), so they are not compile-time constants.
abstract final class AppTextStyles {
  static TextStyle _base({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? AppColors.textPrimary,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle display({
    double fontSize = 34,
    FontWeight fontWeight = FontWeight.w800,
    Color? color,
    double letterSpacing = -0.6,
    double? height,
  }) => _base(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );

  static TextStyle title({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double letterSpacing = -0.4,
    double? height,
  }) => _base(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );

  static TextStyle headline({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double? height,
  }) => _base(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
  );

  static TextStyle body({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
  }) => _base(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
  );

  static TextStyle bodySecondary({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double height = 1.4,
  }) => _base(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.textSecondary,
    height: height,
  );

  static TextStyle label({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double? height,
  }) => _base(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
  );

  static TextStyle button({
    double fontSize = 17,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) => _base(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.textOnPrimary,
  );

  static TextStyle caption({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double height = 1.4,
  }) => _base(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.textSecondary,
    height: height,
  );

  static TextStyle hint({
    double fontSize = 17,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
  }) => _base(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.textHint,
  );

  static TextStyle keypad({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
  }) => _base(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );

  static TextStyle otpDigit({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
  }) => _base(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: 1,
  );
}
