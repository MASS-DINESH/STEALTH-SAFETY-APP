import 'package:flutter/material.dart';

class AppColors {
  // Brand & Primaries
  static const Color primary       = Color(0xFF6366F1); // Modern Indigo
  static const Color primaryDark   = Color(0xFF4338CA); // Deep Royal
  static const Color primaryLight  = Color(0xFF818CF8); // Vivid Lavender
  static const Color accent        = Color(0xFF8B5CF6); // Electric Violet
  
  // Light Backgrounds
  static const Color bgLight       = Color(0xFFF8FAFC); // Clean slate tint
  static const Color surfaceLight  = Color(0xFFFFFFFF); // Pure White
  static const Color borderLight   = Color(0xFFE2E8F0); // Light Border
  static const Color textDark      = Color(0xFF0F172A); // Slate 900
  static const Color textMid       = Color(0xFF475569); // Slate 600
  static const Color textGrey      = Color(0xFF64748B); // Slate 500

  // Dark Backgrounds
  static const Color bgDark        = Color(0xFF090D16); // Deep Obsidian
  static const Color surfaceDark   = Color(0xFF111827); // Dark Surface Slate
  static const Color cardDark      = Color(0xFF161F30); // Card Slate
  static const Color borderDark    = Color(0xFF1F293D); // Dark Border
  static const Color textLight     = Color(0xFFF8FAFC); // White Text
  static const Color textMidDark   = Color(0xFF94A3B8); // Muted Light Text

  // General & Emergency
  static const Color splashBg      = Color(0xFF0B0A1A); // Deep Night
  static const Color splashBgEnd   = Color(0xFF1E1B4B); // Rich Purple Night
  static const Color emergencyBg   = Color(0xFF09090B); // Pure AMOLED Black
  
  // Status Accents
  static const Color success       = Color(0xFF10B981); // Emerald Green
  static const Color live          = Color(0xFF10B981);
  static const Color danger        = Color(0xFFEF4444); // Bright Crimson
  static const Color dangerDark    = Color(0xFFDC2626);
  static const Color warning       = Color(0xFFF59E0B); // Amber
  static const Color whatsapp      = Color(0xFF22C55E); // WhatsApp Green

  // Aliases
  static const Color bg            = bgLight;
  static const Color surface       = surfaceLight;
  static const Color border        = borderLight;
}

class AppTheme {
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      surface: AppColors.surfaceLight,
    ),
    scaffoldBackgroundColor: AppColors.bgLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surfaceLight,
      foregroundColor: AppColors.textDark,
      elevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3),
      ),
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primary,
      surface: AppColors.surfaceDark,
    ),
    scaffoldBackgroundColor: AppColors.bgDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surfaceDark,
      foregroundColor: AppColors.textLight,
      elevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3),
      ),
    ),
  );

  static ThemeData get theme => lightTheme;
}
