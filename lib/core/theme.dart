import 'package:flutter/material.dart';

class AppColors {
  static const backgroundColor = Color(0xFF1e1e1e);
  static const surfaceColor = Color(0xFF252526);
  static const cardColor = Color(0xFF2d2d2d);
  static const borderColor = Color(0xFF3a3a3a);
  static const accentPrimary = Color(0xFF7F77DD);
  static const accentSecondary = Color(0xFFAFA9EC);
  static const accentDim = Color(0xFF2a2740);
  static const textPrimary = Color(0xFFd4d4d4);
  static const textSecondary = Color(0xFF9d9d9d);
  static const textHint = Color(0xFF6a6a6a);
  static const colorGreen = Color(0xFF4ec9b0);
  static const colorRed = Color(0xFFf44747);
  static const colorYellow = Color(0xFFdcdcaa);

  static const userBubbleBg = Color(0xFF2a2740);
  static const userBubbleBorder = Color(0xFF3c3770);
  static const assistantBubbleBg = Color(0xFF2d2d2d);
  static const assistantBubbleBorder = Color(0xFF3a3a3a);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.backgroundColor,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accentPrimary,
      secondary: AppColors.accentSecondary,
      surface: AppColors.surfaceColor,
      error: AppColors.colorRed,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surfaceColor,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.borderColor),
      ),
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceColor,
      hintStyle: const TextStyle(color: AppColors.textHint),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.accentPrimary),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accentPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accentSecondary,
      ),
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      textStyle: TextStyle(color: AppColors.textPrimary),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.borderColor,
      thickness: 1,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.textPrimary),
      bodyMedium: TextStyle(color: AppColors.textPrimary),
      bodySmall: TextStyle(color: AppColors.textSecondary),
      titleLarge: TextStyle(color: AppColors.textPrimary),
      titleMedium: TextStyle(color: AppColors.textPrimary),
      titleSmall: TextStyle(color: AppColors.textSecondary),
    ),
  );
}
