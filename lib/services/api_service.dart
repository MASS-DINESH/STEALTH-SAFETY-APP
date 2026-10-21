import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_service.dart';

class ApiService {
  static Future<String> get baseUrl async => await SettingsService.getBackendUrl();

  static const Map<String, String> defaultHeaders = {
    'Bypass-Tunnel-Reminder': 'true',
    'User-Agent': 'SafetyApp/1.0',
  };

  static Future<String> _parentNumbersCsv() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('trusted_numbers');
    if (raw != null) {
      final list = (jsonDecode(raw) as List).cast<String>();
      return list.join(',');
    }
    final single = prefs.getString('parent_whatsapp_number');
    return single ?? '';
  }

  // ----------------------------------------------------------------
  // Fires immediately on triple-press — sends the initial alert
  // message + first known location to all contacts.
  // ----------------------------------------------------------------
  static Future<void> sendAlertStart({
    required String sessionId,
    double? lat,
    double? lng,
  }) async {
    final numbers = await _parentNumbersCsv();
    if (numbers.isEmpty) return;
    final url = await baseUrl;
    await http.post(
      Uri.parse('$url/api/alert-start'),
      headers: defaultHeaders,
      body: {
        'parent_number': numbers,
        'session_id': sessionId,
        if (lat != null) 'lat': lat.toString(),
        if (lng != null) 'lng': lng.toString(),
      },
    ).timeout(const Duration(seconds: 10)).catchError((_) => http.Response('Error', 500));
  }

  // ----------------------------------------------------------------
  // Periodic live moving location updates (throttled to 10s server-side)
  // ----------------------------------------------------------------
  static Future<void> sendLocationUpdate(
      double lat, double lng, String sessionId) async {
    final numbers = await _parentNumbersCsv();
    if (numbers.isEmpty) return;
    final url = await baseUrl;
    await http.post(
      Uri.parse('$url/api/location'),
      headers: defaultHeaders,
      body: {
        'parent_number': numbers,
        'session_id': sessionId,
        'lat': lat.toString(),
        'lng': lng.toString(),
      },
    ).timeout(const Duration(seconds: 8)).catchError((_) => http.Response('Error', 500));
  }

  // ----------------------------------------------------------------
  // Upload a captured photo with index and total
  // ----------------------------------------------------------------
  static Future<void> uploadPhoto(
      String path, String sessionId, int index, int total) async {
    final numbers = await _parentNumbersCsv();
    if (numbers.isEmpty) return;
    final url = await baseUrl;
    final req =
        http.MultipartRequest('POST', Uri.parse('$url/api/photo'))
          ..headers.addAll(defaultHeaders)
          ..fields['parent_number'] = numbers
          ..fields['session_id'] = sessionId
          ..fields['index'] = index.toString()
          ..fields['total'] = total.toString()
          ..files.add(await http.MultipartFile.fromPath('file', path));
    await req
        .send()
        .timeout(const Duration(seconds: 20))
        .catchError((_) => http.StreamedResponse(const Stream.empty(), 500));
  }

  // ----------------------------------------------------------------
  // Upload an audio clip recording with loop count and duration
  // ----------------------------------------------------------------
  static Future<void> uploadAudio(
      String path, {int loop = 1, int totalLoops = 1, int duration = 60}) async {
    final numbers = await _parentNumbersCsv();
    if (numbers.isEmpty) return;
    final url = await baseUrl;
    final req =
        http.MultipartRequest('POST', Uri.parse('$url/api/audio'))
          ..headers.addAll(defaultHeaders)
          ..fields['parent_number'] = numbers
          ..fields['loop'] = loop.toString()
          ..fields['total_loops'] = totalLoops.toString()
          ..fields['duration'] = duration.toString()
          ..files.add(await http.MultipartFile.fromPath('file', path));
    await req
        .send()
        .timeout(const Duration(seconds: 25))
        .catchError((_) => http.StreamedResponse(const Stream.empty(), 500));
  }

  // ----------------------------------------------------------------
  // Remember the latest recorded voice note path (for battery alert)
  // ----------------------------------------------------------------
  static Future<void> rememberLatestVoiceNotePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('latest_voice_note_path', path);
  }

  // ----------------------------------------------------------------
  // Low-battery: send last saved voice note
  // ----------------------------------------------------------------
  static Future<void> sendStoredVoiceNoteForLowBattery() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('latest_voice_note_path');
    final numbers = await _parentNumbersCsv();
    if (path == null || !File(path).existsSync() || numbers.isEmpty) return;
    final url = await baseUrl;
    final req = http.MultipartRequest(
        'POST', Uri.parse('$url/api/low-battery-audio'))
      ..headers.addAll(defaultHeaders)
      ..fields['parent_number'] = numbers
      ..files.add(await http.MultipartFile.fromPath('file', path));
    await req
        .send()
        .timeout(const Duration(seconds: 20))
        .catchError((_) => http.StreamedResponse(const Stream.empty(), 500));
  }

  // ----------------------------------------------------------------
  // Test alert
  // ----------------------------------------------------------------
  static Future<void> sendTestAlert() async {
    final numbers = await _parentNumbersCsv();
    if (numbers.isEmpty) return;
    final url = await baseUrl;
    await http.post(
      Uri.parse('$url/api/test'),
      headers: defaultHeaders,
      body: {'parent_number': numbers},
    ).timeout(const Duration(seconds: 10)).catchError((_) => http.Response('Error', 500));
  }
}