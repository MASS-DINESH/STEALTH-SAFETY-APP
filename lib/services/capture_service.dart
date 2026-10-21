import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'capture_status.dart';
import 'log_service.dart';
import 'settings_service.dart';
import 'trigger_channel.dart';

class CaptureService {
  static StreamSubscription<Position>? _positionSub;
  static StreamSubscription<String>? _nativeEventSub;
  static GlobalKey<NavigatorState>? _navigatorKey;
  static bool _isCapturing = false;
  static String? _currentSessionId;
  static int _totalLoops = 1;
  static int _clipSeconds = 60;
  static int _photoTarget = 5;
  static bool _isProcessingTrigger = false;

  /// Initialize the global trigger listener once at app startup
  static void init(GlobalKey<NavigatorState> navKey) {
    _navigatorKey = navKey;
    _nativeEventSub?.cancel();
    _nativeEventSub = TriggerChannel.triggerStream.listen(_handleNativeEvent);
  }

  static void _handleNativeEvent(String event) async {
    try {
      if (event == 'panic_trigger') {
        if (_isProcessingTrigger) return;
        _isProcessingTrigger = true;
        try {
          await TriggerChannel.showFakeShutdownOverlay();
          await startCapture();
          _navigatorKey?.currentState?.pushNamedAndRemoveUntil(
            '/emergency',
            (route) => route.settings.name == '/home',
          );
        } finally {
          _isProcessingTrigger = false;
        }
      } else if (event == 'panic_cancel') {
        await TriggerChannel.hideFakeShutdownOverlay();
        await stopCapture();
        _navigatorKey?.currentState?.pushNamedAndRemoveUntil(
          '/alert-sent',
          (route) => route.settings.name == '/home',
        );
      } else if (event.startsWith('photo_captured:')) {
        final parts = event.split(':');
        if (parts.length >= 4) {
          final index = int.tryParse(parts[1]) ?? 1;
          final total = int.tryParse(parts[2]) ?? _photoTarget;
          final path = parts.sublist(3).join(':');

          CaptureStatus.photosTaken.value = index;
          final sId = _currentSessionId ?? '';
          unawaited(ApiService.uploadPhoto(path, sId, index, total));
          await LogService.updateLatestLog(photoCount: index, addPhotoPath: path);
        }
      } else if (event.startsWith('audio_progress:')) {
        final parts = event.split(':');
        if (parts.length >= 2) {
          final seconds = int.tryParse(parts[1]) ?? 0;
          CaptureStatus.audioSeconds.value = seconds;
        }
      } else if (event.startsWith('audio_captured:')) {
        final parts = event.split(':');
        if (parts.length >= 4) {
          final loop = int.tryParse(parts[1]) ?? 1;
          final total = int.tryParse(parts[2]) ?? _totalLoops;
          final path = parts.sublist(3).join(':');

          CaptureStatus.currentAudioLoop.value = loop;
          await ApiService.rememberLatestVoiceNotePath(path);
          await ApiService.uploadAudio(
            path,
            loop: loop,
            totalLoops: total,
            duration: _clipSeconds,
          );
          await LogService.updateLatestLog(audioLoops: loop, addAudioPath: path);
        }
      } else if (event == 'audio_all_complete') {
        CaptureStatus.statusMessage.value = 'All evidence captured and sent';
        await LogService.updateLatestLog(status: 'Completed');
        _isCapturing = false;
      }
    } catch (e) {
      debugPrint('Error handling native trigger event ($event): $e');
    }
  }

  static Future<void> startCapture() async {
    // If already capturing, cleanly reset previous session first
    if (_isCapturing) {
      await stopCapture();
    }
    _isCapturing = true;

    // Load user configurations
    _photoTarget = await SettingsService.getPhotoCount();
    _clipSeconds = await SettingsService.getAudioSeconds();
    _totalLoops = await SettingsService.getAudioLoops();

    CaptureStatus.reset(
      photoCount: _photoTarget,
      audioSecs: _clipSeconds,
      audioLoops: _totalLoops,
    );

    final dir = await getApplicationDocumentsDirectory();
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _currentSessionId = sessionId;
    final sessionDir = '${dir.path}/session_$sessionId';
    try {
      Directory(sessionDir).createSync(recursive: true);
    } catch (_) {}

    // ── 1. Start Native Hardware Photo & Audio Captures IMMEDIATELY ───
    unawaited(TriggerChannel.takeNativePhotos(
      sessionDirPath: sessionDir,
      sessionId: sessionId,
      count: _photoTarget,
    ));

    unawaited(TriggerChannel.startNativeAudio(
      sessionDirPath: sessionDir,
      sessionId: sessionId,
      clipSeconds: _clipSeconds,
      totalLoops: _totalLoops,
    ));

    // ── 2. Run Location & SOS Alert In Parallel ───────────────────────
    unawaited(_initLocationAndAlert(sessionId, sessionDir));
  }

  static Future<void> _initLocationAndAlert(String sessionId, String sessionDir) async {
    Position? firstPosition;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        firstPosition = await Geolocator.getLastKnownPosition();
        firstPosition ??= await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        ).timeout(const Duration(seconds: 3));
      }
    } catch (_) {}

    CaptureStatus.locationLive.value = firstPosition != null;

    final prefs = await SharedPreferences.getInstance();
    final rawRecipients = prefs.getString('trusted_numbers');
    final recipients = rawRecipients != null
        ? (jsonDecode(rawRecipients) as List).cast<String>()
        : <String>[];

    await LogService.addLog(AlertLog(
      id: sessionId,
      timestamp: DateTime.now(),
      photoCount: 0,
      audioLoops: 0,
      audioSeconds: _clipSeconds,
      startLat: firstPosition?.latitude,
      startLng: firstPosition?.longitude,
      lastLat: firstPosition?.latitude,
      lastLng: firstPosition?.longitude,
      recipients: recipients,
      status: 'In Progress',
    ));

    // Send initial alert with Live Tracker Link to WhatsApp immediately
    unawaited(ApiService.sendAlertStart(
      sessionId: sessionId,
      lat: firstPosition?.latitude,
      lng: firstPosition?.longitude,
    ));

    // Background live location updates
    try {
      await _positionSub?.cancel();
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((pos) {
        CaptureStatus.locationLive.value = true;
        ApiService.sendLocationUpdate(pos.latitude, pos.longitude, sessionId);
        LogService.updateLatestLog(
          lastLat: pos.latitude,
          lastLng: pos.longitude,
        );
      });
    } catch (_) {}
  }

  /// Stops capture immediately on Volume DOWN x 3 or STOP button
  static Future<void> stopCapture() async {
    _isCapturing = false;

    await _positionSub?.cancel();
    _positionSub = null;

    await TriggerChannel.stopNativeAudio();
    await LogService.updateLatestLog(status: 'Stopped');
  }
}