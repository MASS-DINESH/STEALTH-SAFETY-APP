import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  static const _steps = [
    'Press Volume Up Button\n3 times quickly',
    'Fake power off screen\nwill appear',
    'Location, audio & photos\nwill be captured',
    'All data will be sent\nto your contacts',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, 
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('How It Works',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_steps.length, (i) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40, 
                            height: 40,
                            decoration: const BoxDecoration(
                              color: AppColors.primary, 
                              shape: BoxShape.circle),
                            child: Center(
                              child: Text('${i + 1}',
                                  style: const TextStyle(color: Colors.white,
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(_steps[i],
                                style: const TextStyle(fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textDark, height: 1.4)),
                          ),
                        ],
                      ),
                      if (i < _steps.length - 1)
                        Padding(
                          padding: const EdgeInsets.only(left: 19, top: 4, bottom: 4),
                          child: Column(
                            children: List.generate(
                              3,
                              (_) => Container(
                                width: 2, 
                                height: 8,
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                color: AppColors.primary.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                }),
              ),
            ),
            FilledButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('onboarding_complete', true);
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
              },
              child: const Text('Got It'),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}