import 'package:flutter/foundation.dart';

/// Holds the current state of evidence capture for the Emergency screen UI.
/// All values are ValueNotifiers so the UI can listen to changes in real-time.
class CaptureStatus {
  static final ValueNotifier<bool> locationLive = ValueNotifier<bool>(false);
  static final ValueNotifier<int> audioSeconds = ValueNotifier<int>(0);
  static final ValueNotifier<int> targetAudioSeconds = ValueNotifier<int>(60);
  static final ValueNotifier<int> currentAudioLoop = ValueNotifier<int>(1);
  static final ValueNotifier<int> totalAudioLoops = ValueNotifier<int>(1);
  static final ValueNotifier<int> photosTaken = ValueNotifier<int>(0);
  static final ValueNotifier<int> totalPhotos = ValueNotifier<int>(5);
  static final ValueNotifier<String> statusMessage = ValueNotifier<String>('Starting emergency capture...');

  static void reset({int photoCount = 5, int audioSecs = 60, int audioLoops = 1}) {
    locationLive.value = false;
    audioSeconds.value = 0;
    targetAudioSeconds.value = audioSecs;
    currentAudioLoop.value = 1;
    totalAudioLoops.value = audioLoops;
    photosTaken.value = 0;
    totalPhotos.value = photoCount;
    statusMessage.value = 'Emergency protocol activated';
  }

  static void dispose() {
    locationLive.dispose();
    audioSeconds.dispose();
    targetAudioSeconds.dispose();
    currentAudioLoop.dispose();
    totalAudioLoops.dispose();
    photosTaken.dispose();
    totalPhotos.dispose();
    statusMessage.dispose();
  }
}