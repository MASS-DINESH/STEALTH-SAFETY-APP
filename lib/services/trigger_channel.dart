import 'package:flutter/services.dart';

/// Bridges the native Android side (AccessibilityService + foreground
/// service) to the Flutter/Dart side.
///
/// Native -> Dart: the AccessibilityService detects a volume-up x3 pattern
/// and fires an event on `safety_app/trigger_events`. Dart listens and
/// starts the capture pipeline (see capture_service.dart).
///
/// Dart -> Native: used during onboarding to send the user to the two
/// system settings screens that can't be requested via normal runtime
/// permission dialogs (Accessibility, and "draw over other apps").
class TriggerChannel {
  static const _methodChannel = MethodChannel('safety_app/native');
  static const _eventChannel = EventChannel('safety_app/trigger_events');

  static final Stream<String> _broadcastStream = _eventChannel
      .receiveBroadcastStream()
      .map((event) => event.toString())
      .asBroadcastStream();

  /// Stream of trigger events from native code. Emits the string
  /// "panic_trigger" when volume-up is pressed 3x, and "panic_cancel" when
  /// it's pressed 3x again while the fake-shutdown overlay is showing.
  static Stream<String> get triggerStream => _broadcastStream;

  static Future<void> openAccessibilitySettings() async {
    await _methodChannel.invokeMethod('openAccessibilitySettings');
  }

  static Future<void> openOverlaySettings() async {
    await _methodChannel.invokeMethod('openOverlaySettings');
  }

  static Future<void> requestIgnoreBatteryOptimizations() async {
    await _methodChannel.invokeMethod('requestIgnoreBatteryOptimizations');
  }

  static Future<bool> isAccessibilityServiceEnabled() async {
    final result = await _methodChannel.invokeMethod<bool>('isAccessibilityServiceEnabled');
    return result ?? false;
  }

  /// Tells the native side to show/hide the fake power-off overlay.
  static Future<void> showFakeShutdownOverlay() async {
    await _methodChannel.invokeMethod('showFakeShutdownOverlay');
  }

  static Future<void> hideFakeShutdownOverlay() async {
    await _methodChannel.invokeMethod('hideFakeShutdownOverlay');
  }

  static Future<void> takeNativePhotos({
    required String sessionDirPath,
    required String sessionId,
    required int count,
  }) async {
    try {
      await _methodChannel.invokeMethod('takeNativePhotos', {
        'sessionDirPath': sessionDirPath,
        'sessionId': sessionId,
        'count': count,
      });
    } catch (_) {}
  }

  static Future<void> startNativeAudio({
    required String sessionDirPath,
    required String sessionId,
    required int clipSeconds,
    required int totalLoops,
  }) async {
    try {
      await _methodChannel.invokeMethod('startNativeAudio', {
        'sessionDirPath': sessionDirPath,
        'sessionId': sessionId,
        'clipSeconds': clipSeconds,
        'totalLoops': totalLoops,
      });
    } catch (_) {}
  }

  static Future<void> stopNativeAudio() async {
    try {
      await _methodChannel.invokeMethod('stopNativeAudio');
    } catch (_) {}
  }

  static Future<bool> playNativeAudio(String filePath) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('playNativeAudio', {
        'filePath': filePath,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stopNativeAudioPlayback() async {
    try {
      await _methodChannel.invokeMethod('stopNativeAudioPlayback');
    } catch (_) {}
  }
}
