import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String keyPhotoCount = 'pref_photo_count';
  static const String keyAudioSeconds = 'pref_audio_seconds';
  static const String keyAudioLoops = 'pref_audio_loops';
  static const String keyBackendUrl = 'pref_backend_url';
  static const String keyEmergencyMode = 'pref_emergency_mode';
  static const String keyBatteryAlert = 'pref_battery_alert';

  static const List<int> photoCountOptions = [3, 5, 10];
  static const List<int> audioSecondsOptions = [30, 60, 120, 180, 300];
  static const List<int> audioLoopsOptions = [1, 2, 3, 4, 5];

  static const int defaultPhotoCount = 5;
  static const int defaultAudioSeconds = 60;
  static const int defaultAudioLoops = 1;
  static const String defaultBackendUrl = 'https://safety-app-backend-mmgz.onrender.com';

  static Future<int> getPhotoCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keyPhotoCount) ?? defaultPhotoCount;
  }

  static Future<void> setPhotoCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyPhotoCount, count);
  }

  static Future<int> getAudioSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keyAudioSeconds) ?? defaultAudioSeconds;
  }

  static Future<void> setAudioSeconds(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyAudioSeconds, seconds);
  }

  static Future<int> getAudioLoops() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keyAudioLoops) ?? defaultAudioLoops;
  }

  static Future<void> setAudioLoops(int loops) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyAudioLoops, loops);
  }

  static Future<String> getBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyBackendUrl) ?? defaultBackendUrl;
  }

  static Future<void> setBackendUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    var cleaned = url.trim();
    if (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    await prefs.setString(keyBackendUrl, cleaned);
  }

  static Future<bool> getEmergencyMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyEmergencyMode) ?? true;
  }

  static Future<void> setEmergencyMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyEmergencyMode, enabled);
  }

  static Future<bool> getBatteryAlert() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyBatteryAlert) ?? true;
  }

  static Future<void> setBatteryAlert(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyBatteryAlert, enabled);
  }
}
