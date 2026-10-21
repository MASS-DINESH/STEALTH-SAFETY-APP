import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/capture_service.dart';
import '../services/capture_status.dart';
import '../services/trigger_channel.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});
  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  bool _stopped = false;

  @override
  void initState() {
    super.initState();
    CaptureStatus.audioSeconds.addListener(_onUpdate);
    CaptureStatus.photosTaken.addListener(_onUpdate);
    CaptureStatus.locationLive.addListener(_onUpdate);
    CaptureStatus.currentAudioLoop.addListener(_onUpdate);
    CaptureStatus.totalAudioLoops.addListener(_onUpdate);
    CaptureStatus.targetAudioSeconds.addListener(_onUpdate);
    CaptureStatus.totalPhotos.addListener(_onUpdate);
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _stop() async {
    if (_stopped) return;
    setState(() => _stopped = true);

    await TriggerChannel.hideFakeShutdownOverlay();
    await CaptureService.stopCapture();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/alert-sent');
  }

  @override
  void dispose() {
    CaptureStatus.audioSeconds.removeListener(_onUpdate);
    CaptureStatus.photosTaken.removeListener(_onUpdate);
    CaptureStatus.locationLive.removeListener(_onUpdate);
    CaptureStatus.currentAudioLoop.removeListener(_onUpdate);
    CaptureStatus.totalAudioLoops.removeListener(_onUpdate);
    CaptureStatus.targetAudioSeconds.removeListener(_onUpdate);
    CaptureStatus.totalPhotos.removeListener(_onUpdate);
    super.dispose();
  }

  String _formatTime(int totalSecs) {
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final photos = CaptureStatus.photosTaken.value;
    final totalPhotos = CaptureStatus.totalPhotos.value;
    final locLive = CaptureStatus.locationLive.value;
    final audioSecs = CaptureStatus.audioSeconds.value;
    final targetSecs = CaptureStatus.targetAudioSeconds.value;
    final currentLoop = CaptureStatus.currentAudioLoop.value;
    final totalLoops = CaptureStatus.totalAudioLoops.value;
    final audioProgress = targetSecs > 0 ? (audioSecs / targetSecs).clamp(0.0, 1.0) : 0.0;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.emergencyBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield, color: AppColors.danger, size: 52),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Emergency Mode\nActivated',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.danger,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Streaming live moving location, audio & photos...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 24),

                // Location row
                _StatusRow(
                  icon: Icons.location_on,
                  label: 'Live Location Tracking',
                  badge: locLive ? 'LIVE' : 'Acquiring GPS...',
                  badgeColor: locLive ? AppColors.live : Colors.orange,
                ),
                const SizedBox(height: 12),

                // Audio row with progress and loop label
                _AudioRow(
                  currentLoop: currentLoop,
                  totalLoops: totalLoops,
                  audioFmt: _formatTime(audioSecs),
                  targetFmt: _formatTime(targetSecs),
                  progress: audioProgress,
                ),
                const SizedBox(height: 12),

                // Photos row
                _StatusRow(
                  icon: Icons.camera_alt,
                  label: 'Capturing & Sending Photos',
                  badge: '$photos / $totalPhotos',
                  badgeColor: photos >= totalPhotos ? AppColors.success : Colors.white70,
                ),

                const Spacer(),

                const Text(
                  'Press Volume DOWN 3× to stop & unlock',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 10),

                GestureDetector(
                  onTap: _stop,
                  child: Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'STOP EMERGENCY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label, badge;
  final Color badgeColor;
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.badge,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          Text(
            badge,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioRow extends StatelessWidget {
  final int currentLoop;
  final int totalLoops;
  final String audioFmt;
  final String targetFmt;
  final double progress;

  const _AudioRow({
    required this.currentLoop,
    required this.totalLoops,
    required this.audioFmt,
    required this.targetFmt,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final loopLabel = totalLoops > 1 ? 'Loop $currentLoop/$totalLoops' : 'Audio';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.mic, color: Colors.white70, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Recording ($loopLabel)',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              Text(
                '$audioFmt / $targetFmt',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white12,
              color: AppColors.danger,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}