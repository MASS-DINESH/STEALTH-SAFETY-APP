import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 220, height: 220,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 160, height: 160,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.security, size: 80, color: AppColors.primary),
                  ),
                  Positioned(
                    bottom: 16, right: 20,
                    child: Container(
                      width: 50, height: 50,
                      decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.check, color: Colors.white, size: 28),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              const Text(
                'Stay Safe,\nWe\'re Always\nWith You',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30, fontWeight: FontWeight.bold,
                  color: AppColors.textDark, height: 1.25),
              ),
              const SizedBox(height: 16),
              const Text(
                'This app helps you silently alert\nyour trusted contacts in an\nemergency.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppColors.textGrey, height: 1.6),
              ),
              const Spacer(flex: 2),
              FilledButton(
                onPressed: () => Navigator.pushNamed(context, '/permissions'),
                child: const Text('Next'),
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}
