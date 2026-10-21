import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/log_service.dart';
import '../services/trigger_channel.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<AlertLog> _logs = [];
  bool _loading = true;
  String? _currentlyPlayingPath;
  int _currentPosMs = 0;
  int _totalDurationMs = 0;
  StreamSubscription<String>? _streamSub;

  @override
  void initState() {
    super.initState();
    _listenToPlaybackEvents();
    _loadLogs();
  }

  void _listenToPlaybackEvents() {
    _streamSub = TriggerChannel.triggerStream.listen((event) {
      if (!mounted) return;
      if (event.startsWith('playback_progress:')) {
        final parts = event.split(':');
        if (parts.length >= 4) {
          final cur = int.tryParse(parts[1]) ?? 0;
          final total = int.tryParse(parts[2]) ?? 0;
          final path = parts.sublist(3).join(':');
          if (_currentlyPlayingPath == path) {
            setState(() {
              _currentPosMs = cur;
              _totalDurationMs = total;
            });
          }
        }
      } else if (event.startsWith('playback_complete:')) {
        final parts = event.split(':');
        final path = parts.sublist(1).join(':');
        if (_currentlyPlayingPath == path) {
          setState(() {
            _currentlyPlayingPath = null;
            _currentPosMs = 0;
            _totalDurationMs = 0;
          });
        }
      }
    });
  }

  Future<void> _loadLogs() async {
    final logs = await LogService.getLogs();
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _loading = false;
    });
  }

  Future<void> _toggleAudioPlay(String filePath) async {
    if (_currentlyPlayingPath == filePath) {
      await TriggerChannel.stopNativeAudioPlayback();
      setState(() {
        _currentlyPlayingPath = null;
        _currentPosMs = 0;
        _totalDurationMs = 0;
      });
      return;
    }

    if (!File(filePath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio file not found on device.')),
      );
      return;
    }

    setState(() {
      _currentlyPlayingPath = filePath;
      _currentPosMs = 0;
      _totalDurationMs = 0;
    });

    final started = await TriggerChannel.playNativeAudio(filePath);
    if (!started && mounted) {
      setState(() {
        _currentlyPlayingPath = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not play audio clip.')),
      );
    }
  }

  void _showImageDialog(String filePath, int index, int total) {
    if (!File(filePath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo file not found on device.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Image.file(
                  File(filePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  'Evidence Photo $index / $total',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 6,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final url = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open map for $lat, $lng')),
        );
      }
    }
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Clear All Activity Logs?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'This will permanently delete all emergency records, photo links, and audio recordings from this device.',
          style: TextStyle(color: AppColors.textGrey, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await TriggerChannel.stopNativeAudioPlayback();
      await LogService.clearLogs();
      await _loadLogs();
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    TriggerChannel.stopNativeAudioPlayback();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Activity Logs',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          if (_logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Clear Logs',
              onPressed: _clearLogs,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _logs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.history_rounded, size: 40, color: AppColors.primary),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Emergency Logs Yet',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: isDark ? AppColors.textLight : AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'When you trigger an emergency with Volume UP 3×, all captured photos, voice notes, and live GPS tracks will be recorded here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadLogs,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      return _LogCard(
                        log: log,
                        currentlyPlayingPath: _currentlyPlayingPath,
                        currentPosMs: _currentPosMs,
                        totalDurationMs: _totalDurationMs,
                        onToggleAudio: _toggleAudioPlay,
                        onOpenImage: _showImageDialog,
                        onOpenMap: _openGoogleMaps,
                      );
                    },
                  ),
                ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final AlertLog log;
  final String? currentlyPlayingPath;
  final int currentPosMs;
  final int totalDurationMs;
  final Function(String) onToggleAudio;
  final Function(String, int, int) onOpenImage;
  final Function(double, double) onOpenMap;

  const _LogCard({
    required this.log,
    required this.currentlyPlayingPath,
    required this.currentPosMs,
    required this.totalDurationMs,
    required this.onToggleAudio,
    required this.onOpenImage,
    required this.onOpenMap,
  });

  String _formatDateTime(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} • $hour:$minute:$second';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasLocation = (log.startLat != null && log.startLng != null) || (log.lastLat != null && log.lastLng != null);
    final lat = log.lastLat ?? log.startLat;
    final lng = log.lastLng ?? log.startLng;
    final isCompleted = log.status == 'Completed';

    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final innerBg = isDark ? AppColors.surfaceDark : AppColors.bgLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.border.withValues(alpha: 0.8);
    final textHeading = isDark ? AppColors.textLight : AppColors.textDark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Row ──────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (isCompleted ? AppColors.success : AppColors.danger).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_circle_rounded : Icons.shield_rounded,
                    color: isCompleted ? AppColors.success : AppColors.danger,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session #${log.id.length > 8 ? log.id.substring(log.id.length - 8) : log.id}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textHeading),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDateTime(log.timestamp),
                        style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isCompleted ? AppColors.success : AppColors.danger).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    log.status.toUpperCase(),
                    style: TextStyle(
                      color: isCompleted ? AppColors.success : AppColors.danger,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Evidence Chips ───────────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatChip(
                  icon: Icons.camera_alt_rounded,
                  label: '${log.photoPaths.isNotEmpty ? log.photoPaths.length : log.photoCount} Photos',
                  color: AppColors.primary,
                ),
                _StatChip(
                  icon: Icons.mic_rounded,
                  label: '${log.audioPaths.isNotEmpty ? log.audioPaths.length : log.audioLoops} Audio Loops (${log.audioSeconds}s)',
                  color: const Color(0xFF0EA5E9),
                ),
                if (log.recipients.isNotEmpty)
                  _StatChip(
                    icon: Icons.people_alt_rounded,
                    label: '${log.recipients.length} WhatsApp Contacts',
                    color: AppColors.whatsapp,
                  ),
              ],
            ),

            // ── Recorded GPS Location ────────────────────────────────
            if (hasLocation && lat != null && lng != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: innerBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderCol),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.location_on_rounded, size: 18, color: AppColors.danger),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Recorded GPS Coordinates',
                            style: TextStyle(fontSize: 11, color: AppColors.textGrey, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textHeading),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => onOpenMap(lat, lng),
                      icon: const Icon(Icons.map_rounded, size: 14),
                      label: const Text('Map', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(60, 34),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Saved Photos Grid ────────────────────────────────────
            if (log.photoPaths.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.photo_camera_back_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Captured Evidence Photos (${log.photoPaths.length})',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textHeading),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 94,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: log.photoPaths.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final p = log.photoPaths[i];
                    final fileExists = File(p).existsSync();
                    return GestureDetector(
                      onTap: () => onOpenImage(p, i + 1, log.photoPaths.length),
                      child: Container(
                        width: 94,
                        height: 94,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderCol),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              fileExists
                                  ? Image.file(File(p), fit: BoxFit.cover)
                                  : Container(
                                      color: innerBg,
                                      child: const Icon(Icons.broken_image_rounded, color: AppColors.textGrey),
                                    ),
                              Positioned(
                                bottom: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '#${i + 1}',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // ── Recorded Voice Notes Audio Player ────────────────────
            if (log.audioPaths.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.graphic_eq_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Recorded Voice Audio (${log.audioPaths.length})',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textHeading),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Column(
                children: log.audioPaths.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final path = entry.value;
                  final isPlaying = (currentlyPlayingPath == path);
                  final progress = (isPlaying && totalDurationMs > 0)
                      ? (currentPosMs / totalDurationMs).clamp(0.0, 1.0)
                      : 0.0;
                  final curSec = (isPlaying ? currentPosMs ~/ 1000 : 0);
                  final totalSec = (isPlaying && totalDurationMs > 0 ? totalDurationMs ~/ 1000 : log.audioSeconds);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isPlaying ? AppColors.primary.withValues(alpha: 0.08) : innerBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isPlaying ? AppColors.primary : borderCol,
                        width: isPlaying ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => onToggleAudio(path),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isPlaying
                                        ? [AppColors.danger, AppColors.dangerDark]
                                        : [AppColors.primary, AppColors.primaryDark],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isPlaying ? AppColors.danger : AppColors.primary).withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Voice Loop #$idx',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: textHeading,
                                        ),
                                      ),
                                      Text(
                                        isPlaying ? '${curSec}s / ${totalSec}s' : '${log.audioSeconds}s Clip',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isPlaying ? AppColors.primary : AppColors.textGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isPlaying ? 'Playing via hardware speaker...' : 'Tap play to listen',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isPlaying ? AppColors.primary : AppColors.textGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (isPlaying) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                              color: AppColors.primary,
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
