import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.voidBg,
        primaryColor: AppColors.luxuryOrange,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.luxuryOrange,
          secondary: AppColors.neonOrange,
          surface: AppColors.obsidian,
          error: AppColors.danger,
        ),
        extensions: const [AppColorsExtension.dark],
      );

  static ThemeData get lightTheme => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.offWhite,
        primaryColor: AppColors.luxuryOrange,
        colorScheme: const ColorScheme.light(
          primary: AppColors.luxuryOrange,
          secondary: AppColors.ember,
          surface: AppColors.white,
          error: AppColors.danger,
        ),
        extensions: const [AppColorsExtension.light],
      );
}
