import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import '../services/theme_service.dart';
import '../services/trigger_channel.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _photoCount = SettingsService.defaultPhotoCount;
  int _audioSeconds = SettingsService.defaultAudioSeconds;
  int _audioLoops = SettingsService.defaultAudioLoops;
  final TextEditingController _urlController = TextEditingController();
  bool _loading = true;
  bool _testingConnection = false;
  String? _connectionStatus;
  bool? _connectionOk;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final count = await SettingsService.getPhotoCount();
    final secs = await SettingsService.getAudioSeconds();
    final loops = await SettingsService.getAudioLoops();
    final url = await SettingsService.getBackendUrl();

    if (!mounted) return;
    setState(() {
      _photoCount = count;
      _audioSeconds = secs;
      _audioLoops = loops;
      _urlController.text = url;
      _loading = false;
    });
  }

  Future<void> _saveUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    await SettingsService.setBackendUrl(url);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backend Server URL saved!')),
    );
  }

  void _useDefaultPcUrl() {
    setState(() {
      _urlController.text = SettingsService.defaultBackendUrl;
    });
    _saveUrl();
  }

  Future<void> _testConnection() async {
    setState(() {
      _testingConnection = true;
      _connectionStatus = null;
      _connectionOk = null;
    });

    final url = _urlController.text.trim();
    try {
      final res = await http.get(
        Uri.parse('$url/health'),
        headers: ApiService.defaultHeaders,
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final statusRes = await http.get(
          Uri.parse('$url/api/status'),
          headers: ApiService.defaultHeaders,
        ).timeout(const Duration(seconds: 5));
        final data = jsonDecode(statusRes.body);
        final waReady = data['whatsapp'] == true;
        setState(() {
          _connectionOk = true;
          _connectionStatus = waReady
              ? '✅ Connected to PC Server & WhatsApp is Ready!'
              : '⚠️ Connected to PC, but WhatsApp needs QR scan.';
        });
      } else {
        setState(() {
          _connectionOk = false;
          _connectionStatus = '❌ Server returned error code ${res.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _connectionOk = false;
        _connectionStatus = '❌ Connection failed: $e\nCheck Windows Firewall or ensure cloudflare tunnel is active.';
      });
    } finally {
      setState(() => _testingConnection = false);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDark : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : AppColors.border.withValues(alpha: 0.7);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        physics: const BouncingScrollPhysics(),
        children: [
          // ── Appearance & Theme Mode ──────────────────────────────
          _buildSectionHeader('APPEARANCE & THEME'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeService.currentTheme,
              builder: (context, currentMode, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.palette_rounded, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'App Display Theme',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              'Choose your preferred visual style',
                              style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _ThemeOptionChip(
                          icon: Icons.light_mode_rounded,
                          label: 'Light',
                          isSelected: currentMode == ThemeMode.light,
                          onTap: () => ThemeService.setTheme(ThemeMode.light),
                        ),
                        const SizedBox(width: 8),
                        _ThemeOptionChip(
                          icon: Icons.dark_mode_rounded,
                          label: 'Dark',
                          isSelected: currentMode == ThemeMode.dark,
                          onTap: () => ThemeService.setTheme(ThemeMode.dark),
                        ),
                        const SizedBox(width: 8),
                        _ThemeOptionChip(
                          icon: Icons.brightness_auto_rounded,
                          label: 'System',
                          isSelected: currentMode == ThemeMode.system,
                          onTap: () => ThemeService.setTheme(ThemeMode.system),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('EVIDENCE CAPTURE CONFIGURATION'),
          _buildCard(
            cardColor: cardColor,
            borderColor: borderColor,
            children: [
              // Photo Count
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                title: const Text('Number of Photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Photos captured per emergency event', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                trailing: DropdownButton<int>(
                  value: _photoCount,
                  dropdownColor: cardColor,
                  underline: const SizedBox(),
                  borderRadius: BorderRadius.circular(12),
                  items: SettingsService.photoCountOptions.map((c) {
                    return DropdownMenuItem(value: c, child: Text('$c Photos', style: const TextStyle(fontWeight: FontWeight.bold)));
                  }).toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _photoCount = v);
                    await SettingsService.setPhotoCount(v);
                  },
                ),
              ),
              Divider(height: 1, color: borderColor),

              // Audio Duration
              ListTile(
                leading: const Icon(Icons.mic_rounded, color: AppColors.primary),
                title: const Text('Audio Clip Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Length of each recorded voice clip', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                trailing: DropdownButton<int>(
                  value: _audioSeconds,
                  dropdownColor: cardColor,
                  underline: const SizedBox(),
                  borderRadius: BorderRadius.circular(12),
                  items: SettingsService.audioSecondsOptions.map((s) {
                    final label = s >= 60 ? '${s ~/ 60} min' : '${s}s';
                    return DropdownMenuItem(value: s, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)));
                  }).toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _audioSeconds = v);
                    await SettingsService.setAudioSeconds(v);
                  },
                ),
              ),
              Divider(height: 1, color: borderColor),

              // Audio Loops
              ListTile(
                leading: const Icon(Icons.repeat_rounded, color: AppColors.primary),
                title: const Text('Audio Loop Cycles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Repeat audio recording & send N times', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                trailing: DropdownButton<int>(
                  value: _audioLoops,
                  dropdownColor: cardColor,
                  underline: const SizedBox(),
                  borderRadius: BorderRadius.circular(12),
                  items: SettingsService.audioLoopsOptions.map((l) {
                    return DropdownMenuItem(value: l, child: Text('$l ${l == 1 ? "Loop" : "Loops"}', style: const TextStyle(fontWeight: FontWeight.bold)));
                  }).toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _audioLoops = v);
                    await SettingsService.setAudioLoops(v);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('BACKEND SERVER CONNECTION'),
          _buildCard(
            cardColor: cardColor,
            borderColor: borderColor,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Backend PC URL / Cloudflare Tunnel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    const Text('Directs emergency coordinates, photos and audio to WhatsApp server.', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'https://xxx.trycloudflare.com',
                              filled: true,
                              fillColor: isDark ? AppColors.surfaceDark : AppColors.bgLight,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: borderColor),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _saveUrl,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(68, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _useDefaultPcUrl,
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: borderColor),
                            ),
                            icon: const Icon(Icons.cloud_sync_rounded, size: 16),
                            label: const Text('Reset to Active Tunnel URL', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _testingConnection ? null : _testConnection,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              foregroundColor: AppColors.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: _testingConnection
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                                : const Icon(Icons.network_check_rounded, size: 16),
                            label: const Text('Test Connection to Server', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    if (_connectionStatus != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_connectionOk == true ? AppColors.success : AppColors.danger).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _connectionStatus!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _connectionOk == true ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('SYSTEM PERMISSIONS & LOCKDOWN'),
          _buildCard(
            cardColor: cardColor,
            borderColor: borderColor,
            children: [
              ListTile(
                leading: const Icon(Icons.accessibility_new_rounded, color: AppColors.primary),
                title: const Text('Accessibility Service', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Detects Volume UP/DOWN hardware triggers', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textLight),
                onTap: () => TriggerChannel.openAccessibilitySettings(),
              ),
              Divider(height: 1, color: borderColor),
              ListTile(
                leading: const Icon(Icons.battery_saver_rounded, color: AppColors.primary),
                title: const Text('Ignore Battery Optimizations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Keeps emergency listener alive in background', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textLight),
                onTap: () => TriggerChannel.requestIgnoreBatteryOptimizations(),
              ),
              Divider(height: 1, color: borderColor),
              ListTile(
                leading: const Icon(Icons.layers_rounded, color: AppColors.primary),
                title: const Text('Draw Over Other Apps', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Displays fake blackout screen over all apps', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textLight),
                onTap: () => TriggerChannel.openOverlaySettings(),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          color: AppColors.textGrey,
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children, required Color cardColor, required Color borderColor}) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(children: children),
    );
  }
}

class _ThemeOptionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.textGrey),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textGrey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
