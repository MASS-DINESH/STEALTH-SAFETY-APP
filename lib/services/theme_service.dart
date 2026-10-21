import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const String _keyThemeMode = 'pref_app_theme_mode';
  static final ValueNotifier<ThemeMode> currentTheme = ValueNotifier(ThemeMode.system);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyThemeMode);
    if (saved == 'dark') {
      currentTheme.value = ThemeMode.dark;
    } else if (saved == 'light') {
      currentTheme.value = ThemeMode.light;
    } else {
      currentTheme.value = ThemeMode.system;
    }
  }

  static Future<void> setTheme(ThemeMode mode) async {
    currentTheme.value = mode;
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.dark) {
      await prefs.setString(_keyThemeMode, 'dark');
    } else if (mode == ThemeMode.light) {
      await prefs.setString(_keyThemeMode, 'light');
    } else {
      await prefs.setString(_keyThemeMode, 'system');
    }
  }

  static Future<void> toggleTheme(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await setTheme(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}
