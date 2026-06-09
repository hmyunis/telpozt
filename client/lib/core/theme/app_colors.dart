import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color pureBlack = Color(0xFF000000);
  static const Color appBackground = Color(0xFF050505);
  static const Color surfaceDark = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFF1E1E1E);
  static const Color borderSubtle = Color(0xFF2A2A2A);
  static const Color borderHighlight = Color(0xFF3D3D3D);
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFA3A3A3);
  static const Color textMuted = Color(0xFF666666);
  static const Color brandOrange = Color(0xFFFF6B00);
  static const Color brandOrangeDark = Color(0xFFCC5500);
  static const Color brandOrangeDim = Color(0x33FF6B00);
  static const Color success = Color(0xFF10B981);
  static const Color successDim = Color(0x2210B981);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerDim = Color(0x22EF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  static const Color scheduled = Color(0xFFA855F7);

  // Backward-compatible aliases used by the existing app.
  static const Color black = pureBlack;
  static const Color voidBg = appBackground;
  static const Color obsidian = surfaceDark;
  static const Color graphite = surfaceLight;
  static const Color iron = borderSubtle;
  static const Color steelDark = Color(0xFF3D3D3D);
  static const Color steelLight = Color(0xFFBEBBB8);
  static const Color ash = Color(0xFF6B6B6B);
  static const Color silver = Color(0xFFA8A8A8);
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF5F5F0);
  static const Color luxuryOrange = Color(0xFFE8660A);
  static const Color neonOrange = brandOrange;
  static const Color ember = Color(0xFFC4520A);
  static const Color goldSand = Color(0xFFD4893A);
  static const Color goldPale = Color(0xFFF0C070);

  static AppColorsExtension schemeOf(BuildContext context) =>
      Theme.of(context).extension<AppColorsExtension>()!;

  static Color appBackgroundOf(BuildContext context) => schemeOf(context).bgApp;
  static Color surfaceOf(BuildContext context) => schemeOf(context).bgSurface;
  static Color elevatedOf(BuildContext context) => schemeOf(context).bgElevated;
  static Color inputOf(BuildContext context) => schemeOf(context).bgInput;
  static Color borderSubtleOf(BuildContext context) =>
      schemeOf(context).borderDefault;
  static Color borderHighlightOf(BuildContext context) =>
      schemeOf(context).textDisabled;
  static Color textPrimaryOf(BuildContext context) =>
      schemeOf(context).textPrimary;
  static Color textSecondaryOf(BuildContext context) =>
      schemeOf(context).textSecondary;
  static Color textMutedOf(BuildContext context) => schemeOf(context).textMuted;
  static Color textOnBrandOf(BuildContext context) =>
      schemeOf(context).textOnBrand;
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
    bgApp: AppColors.appBackground,
    bgSurface: AppColors.surfaceDark,
    bgElevated: AppColors.surfaceLight,
    bgInput: AppColors.surfaceLight,
    borderDefault: AppColors.borderSubtle,
    borderFocus: AppColors.brandOrange,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    textDisabled: AppColors.borderHighlight,
    textOnBrand: AppColors.pureBlack,
    accentPrimary: AppColors.brandOrange,
    accentElectric: AppColors.brandOrange,
    accentShimmer: AppColors.borderHighlight,
  );

  static const AppColorsExtension light = AppColorsExtension(
    bgApp: Color(0xFFF6F1EA),
    bgSurface: Color(0xFFF8F4EE),
    bgElevated: Color(0xFFF1EAE0),
    bgInput: Color(0xFFEEE6DB),
    borderDefault: Color(0xFFD8CEC1),
    borderFocus: AppColors.brandOrange,
    textPrimary: Color(0xFF0A0A0A),
    textSecondary: Color(0xFF4E463D),
    textMuted: Color(0xFF857A6F),
    textDisabled: Color(0xFFB9AD9D),
    textOnBrand: AppColors.pureBlack,
    accentPrimary: AppColors.brandOrange,
    accentElectric: AppColors.brandOrangeDark,
    accentShimmer: AppColors.goldSand,
  );
}
