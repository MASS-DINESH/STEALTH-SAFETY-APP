import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/trigger_channel.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import '../services/theme_service.dart';
import 'logs_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _emergencyMode = true;
  bool _accessOk = false;
  int _contactCount = 0;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('trusted_numbers');
    final list = raw != null ? (jsonDecode(raw) as List) : [];
    final access = await TriggerChannel.isAccessibilityServiceEnabled();
    final eMode = await SettingsService.getEmergencyMode();

    if (!mounted) return;
    setState(() {
      _contactCount = list.length;
      _accessOk = access;
      _emergencyMode = eMode;
    });
  }

  Future<void> _showTestDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        title: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryLight, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              'Test Alert System',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? AppColors.textLight : AppColors.textDark,
              ),
            ),
          ],
        ),
        content: const Text(
          'Send an instant test alert notification to all your saved trusted WhatsApp contacts?\n\n(No live tracking coordinates or emergency sirens will be shared).',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textGrey, fontSize: 13, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Send Alert'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text('Sending test alert to WhatsApp contacts...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
      await ApiService.sendTestAlert();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Test alert dispatched to WhatsApp!'),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabs = [
      _buildDashboard(isDark),
      const LogsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: tabs[_currentTab],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.border.withValues(alpha: 0.5),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavBarItem(
                  icon: Icons.shield_outlined,
                  activeIcon: Icons.shield_rounded,
                  label: 'Protection',
                  isSelected: _currentTab == 0,
                  onTap: () {
                    setState(() => _currentTab = 0);
                    _loadState();
                  },
                ),
                _NavBarItem(
                  icon: Icons.folder_open_outlined,
                  activeIcon: Icons.folder_rounded,
                  label: 'Activity Logs',
                  isSelected: _currentTab == 1,
                  onTap: () {
                    setState(() => _currentTab = 1);
                    _loadState();
                  },
                ),
                _NavBarItem(
                  icon: Icons.tune_outlined,
                  activeIcon: Icons.tune_rounded,
                  label: 'Settings',
                  isSelected: _currentTab == 2,
                  onTap: () {
                    setState(() => _currentTab = 2);
                    _loadState();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Premium Gradient Header ──────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF030712), const Color(0xFF0F172A), const Color(0xFF1E1B4B)]
                    : [const Color(0xFF0F172A), const Color(0xFF1E1B4B), const Color(0xFF312E81)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 24,
              right: 24,
              bottom: 28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal Safety',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Triple Volume-Up Panic Guard',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Quick Theme Toggle Icon Button
                        GestureDetector(
                          onTap: () => ThemeService.toggleTheme(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: Icon(
                              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!_accessOk)
                          GestureDetector(
                            onTap: () async {
                              await TriggerChannel.openAccessibilitySettings();
                              await _loadState();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Enable Service',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Hero Status Shield Card ────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.success.withValues(alpha: 0.2),
                          border: Border.all(color: AppColors.success, width: 2),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: AppColors.success,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'ACTIVE & MONITORING',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Instant SOS Trigger Armed',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Press Volume UP 3× to stream Live Location, Photos & Audio',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Quick Controls & Shortcuts ───────────────────────────
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PROTECTION CONTROLS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AppColors.textGrey,
                  ),
                ),
                const SizedBox(height: 12),

                // Emergency Mode Card
                _ActionCard(
                  isDark: isDark,
                  icon: Icons.bolt_rounded,
                  iconColor: AppColors.primary,
                  iconBg: AppColors.primary.withValues(alpha: 0.1),
                  title: 'Emergency SOS Guard',
                  subtitle: 'Press Volume UP 3× anytime to activate emergency',
                  trailing: Switch(
                    value: _emergencyMode,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) async {
                      setState(() => _emergencyMode = v);
                      await SettingsService.setEmergencyMode(v);
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Trusted Contacts Card
                _ActionCard(
                  isDark: isDark,
                  icon: Icons.contact_phone_rounded,
                  iconColor: const Color(0xFF0EA5E9),
                  iconBg: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                  title: 'Trusted WhatsApp Contacts',
                  subtitle: '$_contactCount recipient${_contactCount == 1 ? "" : "s"} linked for live tracking',
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textLight),
                  onTap: () => Navigator.pushNamed(context, '/contacts').then((_) => _loadState()),
                ),
                const SizedBox(height: 12),

                // Test Alert Card
                _ActionCard(
                  isDark: isDark,
                  icon: Icons.send_rounded,
                  iconColor: AppColors.success,
                  iconBg: AppColors.success.withValues(alpha: 0.1),
                  title: 'Test WhatsApp Dispatch',
                  subtitle: 'Send a safe test message to verify WhatsApp linkage',
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textLight),
                  onTap: _showTestDialog,
                ),
                const SizedBox(height: 12),

                // App Settings Card
                _ActionCard(
                  isDark: isDark,
                  icon: Icons.tune_rounded,
                  iconColor: AppColors.accent,
                  iconBg: AppColors.accent.withValues(alpha: 0.1),
                  title: 'Evidence Capture Settings',
                  subtitle: 'Configure photo count, audio clips & server link',
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textLight),
                  onTap: () => setState(() => _currentTab = 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? AppColors.cardDark : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.border.withValues(alpha: 0.7),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? AppColors.textLight : AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.primary : AppColors.textGrey,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}