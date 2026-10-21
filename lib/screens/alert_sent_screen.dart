import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AlertSentScreen extends StatelessWidget {
  const AlertSentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final borderCol = isDark ? AppColors.borderDark : AppColors.border;
    final textHeading = isDark ? AppColors.textLight : AppColors.textDark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),
              // ── Glowing Success Icon ─────────────────────────────
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF34D399), Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.35),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 54),
              ),
              const SizedBox(height: 28),
              Text(
                'Emergency Evidence\nDispatched',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: textHeading,
                  height: 1.25,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your live moving tracking link, captured photos, and recorded audio notes were transmitted to your trusted WhatsApp contacts.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.5),
              ),
              const SizedBox(height: 32),

              // ── Delivery Confirmation Card ───────────────────────
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderCol),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _DeliveryItem(
                      icon: Icons.location_on_rounded,
                      color: AppColors.danger,
                      title: 'Live Tracking Link',
                      subtitle: 'Active moving GPS tracker URL sent',
                    ),
                    Divider(height: 20, color: borderCol),
                    _DeliveryItem(
                      icon: Icons.photo_camera_rounded,
                      color: AppColors.primary,
                      title: 'Evidence Photos',
                      subtitle: 'Multi-shot photos delivered',
                    ),
                    Divider(height: 20, color: borderCol),
                    _DeliveryItem(
                      icon: Icons.mic_rounded,
                      color: const Color(0xFF0EA5E9),
                      title: 'Voice Notes',
                      subtitle: 'Audio recordings delivered as PTT notes',
                    ),
                  ],
                ),
              ),

              const Spacer(),
              FilledButton(
                onPressed: () =>
                    Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false),
                child: const Text('Return to Safety Dashboard'),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveryItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _DeliveryItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? AppColors.textLight : AppColors.textDark,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
              ),
            ],
          ),
        ),
        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
      ],
    );
  }
}
