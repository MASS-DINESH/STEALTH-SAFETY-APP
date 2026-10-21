import 'package:permission_handler/permission_handler.dart';

/// Requests every runtime permission the app needs. Accessibility-service
/// and "draw over other apps" permissions aren't part of the standard
/// Android runtime-permission model, so those are requested separately via
/// native intents (see NativePermissions in trigger_channel.dart).
class PermissionService {
  static Future<bool> requestAll() async {
    final statuses = await [
      Permission.locationWhenInUse,
      Permission.locationAlways,
      Permission.camera,
      Permission.microphone,
      Permission.notification,
    ].request();

    final coreGranted = statuses.values.every(
      (s) => s.isGranted || s.isLimited,
    );

    // These two require sending the user to a system settings screen;
    // handled on the native side via TriggerChannel.openOverlaySettings()
    // and TriggerChannel.openAccessibilitySettings().
    return coreGranted;
  }
}
