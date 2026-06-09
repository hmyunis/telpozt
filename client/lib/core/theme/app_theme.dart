import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.appBackground,
        primaryColor: AppColors.brandOrange,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.brandOrange,
          secondary: AppColors.brandOrangeDark,
          surface: AppColors.surfaceDark,
          error: AppColors.danger,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.appBackground,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.borderSubtle,
          thickness: 1,
          space: 1,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: AppColors.surfaceDark,
        ),
        cardTheme: const CardThemeData(
          color: AppColors.surfaceDark,
          surfaceTintColor: Colors.transparent,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surfaceDark,
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: AppColors.appBackground,
          surfaceTintColor: Colors.transparent,
        ),
        extensions: const [AppColorsExtension.dark],
      );

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF6F1EA),
        primaryColor: AppColors.brandOrange,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        colorScheme: const ColorScheme.light(
          primary: AppColors.brandOrange,
          secondary: AppColors.brandOrangeDark,
          surface: Color(0xFFF8F4EE),
          error: AppColors.danger,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF6F1EA),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: AppColors.black),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFD8CEC1),
          thickness: 1,
          space: 1,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFFF8F4EE),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFFF8F4EE),
          surfaceTintColor: Colors.transparent,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFFF8F4EE),
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFFF6F1EA),
          surfaceTintColor: Colors.transparent,
        ),
        extensions: const [AppColorsExtension.light],
      );
}
