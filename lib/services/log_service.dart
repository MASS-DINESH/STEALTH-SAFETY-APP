import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AlertLog {
  final String id;
  final DateTime timestamp;
  final int photoCount;
  final List<String> photoPaths;
  final int audioLoops;
  final List<String> audioPaths;
  final int audioSeconds;
  final double? startLat;
  final double? startLng;
  final double? lastLat;
  final double? lastLng;
  final List<String> recipients;
  final String status;

  AlertLog({
    required this.id,
    required this.timestamp,
    required this.photoCount,
    this.photoPaths = const [],
    required this.audioLoops,
    this.audioPaths = const [],
    required this.audioSeconds,
    this.startLat,
    this.startLng,
    this.lastLat,
    this.lastLng,
    required this.recipients,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'photoCount': photoCount,
    'photoPaths': photoPaths,
    'audioLoops': audioLoops,
    'audioPaths': audioPaths,
    'audioSeconds': audioSeconds,
    'startLat': startLat,
    'startLng': startLng,
    'lastLat': lastLat,
    'lastLng': lastLng,
    'recipients': recipients,
    'status': status,
  };

  factory AlertLog.fromJson(Map<String, dynamic> json) => AlertLog(
    id: json['id'] as String? ?? '',
    timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    photoCount: (json['photoCount'] as num?)?.toInt() ?? 0,
    photoPaths: (json['photoPaths'] as List?)?.cast<String>() ?? [],
    audioLoops: (json['audioLoops'] as num?)?.toInt() ?? 0,
    audioPaths: (json['audioPaths'] as List?)?.cast<String>() ?? [],
    audioSeconds: (json['audioSeconds'] as num?)?.toInt() ?? 0,
    startLat: (json['startLat'] as num?)?.toDouble(),
    startLng: (json['startLng'] as num?)?.toDouble(),
    lastLat: (json['lastLat'] as num?)?.toDouble(),
    lastLng: (json['lastLng'] as num?)?.toDouble(),
    recipients: (json['recipients'] as List?)?.cast<String>() ?? [],
    status: json['status'] as String? ?? 'Completed',
  );
}

class LogService {
  static const String keyLogs = 'safety_alert_logs_v1';

  static Future<List<AlertLog>> getLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyLogs);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      final parsed = list.map((item) => AlertLog.fromJson(item as Map<String, dynamic>)).toList();
      
      // Deduplicate by session ID
      final seenIds = <String>{};
      final uniqueLogs = <AlertLog>[];
      for (final log in parsed) {
        if (log.id.isNotEmpty && !seenIds.contains(log.id)) {
          seenIds.add(log.id);
          uniqueLogs.add(log);
        }
      }
      return uniqueLogs;
    } catch (_) {
      return [];
    }
  }

  static Future<void> addLog(AlertLog log) async {
    final logs = await getLogs();
    
    // Remove any existing log with the same session id or ghost logs with 0 photos/audio created in the last 3 seconds
    final now = log.timestamp;
    logs.removeWhere((l) =>
        l.id == log.id ||
        (l.photoPaths.isEmpty &&
            l.audioPaths.isEmpty &&
            l.photoCount == 0 &&
            l.audioLoops == 0 &&
            now.difference(l.timestamp).inSeconds.abs() < 4));

    logs.insert(0, log);
    if (logs.length > 50) {
      logs.removeRange(50, logs.length);
    }
    final prefs = await SharedPreferences.getInstance();
    final jsonList = logs.map((l) => l.toJson()).toList();
    await prefs.setString(keyLogs, jsonEncode(jsonList));
  }

  static Future<void> updateLatestLog({
    int? photoCount,
    String? addPhotoPath,
    int? audioLoops,
    String? addAudioPath,
    double? lastLat,
    double? lastLng,
    String? status,
  }) async {
    final logs = await getLogs();
    if (logs.isEmpty) return;
    final latest = logs.first;

    final updatedPhotos = List<String>.from(latest.photoPaths);
    if (addPhotoPath != null && !updatedPhotos.contains(addPhotoPath)) {
      updatedPhotos.add(addPhotoPath);
    }

    final updatedAudios = List<String>.from(latest.audioPaths);
    if (addAudioPath != null && !updatedAudios.contains(addAudioPath)) {
      updatedAudios.add(addAudioPath);
    }

    final updated = AlertLog(
      id: latest.id,
      timestamp: latest.timestamp,
      photoCount: photoCount ?? (updatedPhotos.isNotEmpty ? updatedPhotos.length : latest.photoCount),
      photoPaths: updatedPhotos,
      audioLoops: audioLoops ?? (updatedAudios.isNotEmpty ? updatedAudios.length : latest.audioLoops),
      audioPaths: updatedAudios,
      audioSeconds: latest.audioSeconds,
      startLat: latest.startLat,
      startLng: latest.startLng,
      lastLat: lastLat ?? latest.lastLat,
      lastLng: lastLng ?? latest.lastLng,
      recipients: latest.recipients,
      status: status ?? latest.status,
    );

    logs[0] = updated;
    final prefs = await SharedPreferences.getInstance();
    final jsonList = logs.map((l) => l.toJson()).toList();
    await prefs.setString(keyLogs, jsonEncode(jsonList));
  }

  static Future<void> clearLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyLogs);
  }
}
