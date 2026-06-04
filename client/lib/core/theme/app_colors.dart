import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color black = Color(0xFF000000);
  static const Color voidBg = Color(0xFF0A0A0A);
  static const Color obsidian = Color(0xFF111111);
  static const Color graphite = Color(0xFF1A1A1A);
  static const Color iron = Color(0xFF2A2A2A);
  static const Color steelDark = Color(0xFF3D3D3D);
  static const Color steelLight = Color(0xFFBEBBB8);
  static const Color ash = Color(0xFF6B6B6B);
  static const Color silver = Color(0xFFA8A8A8);
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF5F5F0);
  static const Color luxuryOrange = Color(0xFFE8660A);
  static const Color neonOrange = Color(0xFFFF6B00);
  static const Color ember = Color(0xFFC4520A);
  static const Color goldSand = Color(0xFFD4893A);
  static const Color goldPale = Color(0xFFF0C070);
  static const Color danger = Color(0xFFE83A2A);
  static const Color success = Color(0xFF2AE87A);
  static const Color warning = Color(0xFFFFB020);
  static const Color info = Color(0xFF4A9EFF);
  static const Color scheduled = Color(0xFFA855F7);
}

class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color bgApp;
  final Color bgSurface;
  final Color bgElevated;
  final Color bgInput;
  final Color borderDefault;
  final Color borderFocus;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textDisabled;
  final Color textOnBrand;
  final Color accentPrimary;
  final Color accentElectric;
  final Color accentShimmer;

  const AppColorsExtension({
    required this.bgApp,
    required this.bgSurface,
    required this.bgElevated,
    required this.bgInput,
    required this.borderDefault,
    required this.borderFocus,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.textOnBrand,
    required this.accentPrimary,
    required this.accentElectric,
    required this.accentShimmer,
  });

  @override
  AppColorsExtension copyWith({
    Color? bgApp,
    Color? bgSurface,
    Color? bgElevated,
    Color? bgInput,
    Color? borderDefault,
    Color? borderFocus,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textDisabled,
    Color? textOnBrand,
    Color? accentPrimary,
    Color? accentElectric,
    Color? accentShimmer,
  }) {
    return AppColorsExtension(
      bgApp: bgApp ?? this.bgApp,
      bgSurface: bgSurface ?? this.bgSurface,
      bgElevated: bgElevated ?? this.bgElevated,
      bgInput: bgInput ?? this.bgInput,
      borderDefault: borderDefault ?? this.borderDefault,
      borderFocus: borderFocus ?? this.borderFocus,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textDisabled: textDisabled ?? this.textDisabled,
      textOnBrand: textOnBrand ?? this.textOnBrand,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      accentElectric: accentElectric ?? this.accentElectric,
      accentShimmer: accentShimmer ?? this.accentShimmer,
    );
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      bgApp: Color.lerp(bgApp, other.bgApp, t)!,
      bgSurface: Color.lerp(bgSurface, other.bgSurface, t)!,
      bgElevated: Color.lerp(bgElevated, other.bgElevated, t)!,
      bgInput: Color.lerp(bgInput, other.bgInput, t)!,
      borderDefault: Color.lerp(borderDefault, other.borderDefault, t)!,
      borderFocus: Color.lerp(borderFocus, other.borderFocus, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      textOnBrand: Color.lerp(textOnBrand, other.textOnBrand, t)!,
      accentPrimary: Color.lerp(accentPrimary, other.accentPrimary, t)!,
      accentElectric: Color.lerp(accentElectric, other.accentElectric, t)!,
      accentShimmer: Color.lerp(accentShimmer, other.accentShimmer, t)!,
    );
  }

  static const AppColorsExtension dark = AppColorsExtension(
    bgApp: AppColors.voidBg,
    bgSurface: AppColors.obsidian,
    bgElevated: AppColors.graphite,
    bgInput: AppColors.iron,
    borderDefault: AppColors.iron,
    borderFocus: AppColors.neonOrange,
    textPrimary: AppColors.white,
    textSecondary: AppColors.silver,
    textMuted: AppColors.ash,
    textDisabled: AppColors.steelDark,
    textOnBrand: AppColors.white,
    accentPrimary: AppColors.luxuryOrange,
    accentElectric: AppColors.neonOrange,
    accentShimmer: AppColors.goldSand,
  );

  static const AppColorsExtension light = AppColorsExtension(
    bgApp: AppColors.offWhite,
    bgSurface: AppColors.white,
    bgElevated: AppColors.white,
    bgInput: Color(0xFFF0EFED),
    borderDefault: Color(0xFFDDDBD8),
    borderFocus: AppColors.luxuryOrange,
    textPrimary: Color(0xFF0A0A0A),
    textSecondary: Color(0xFF4A4845),
    textMuted: Color(0xFF8A8785),
    textDisabled: Color(0xFFBEBBB8),
    textOnBrand: AppColors.white,
    accentPrimary: AppColors.luxuryOrange,
    accentElectric: AppColors.ember,
    accentShimmer: AppColors.goldSand,
  );
}
