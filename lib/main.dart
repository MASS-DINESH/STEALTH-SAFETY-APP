import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/permissions_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/how_it_works_screen.dart';
import 'screens/home_screen.dart';
import 'screens/emergency_screen.dart';
import 'screens/alert_sent_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/settings_screen.dart';
import 'services/capture_service.dart';
import 'services/theme_service.dart';

/// Global navigator key — allows CaptureService to navigate from anywhere
final _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeService.init();
  // Start listening to native volume-button triggers immediately at app boot
  CaptureService.init(_navigatorKey);
  runApp(const PersonalSafetyApp());
}

class PersonalSafetyApp extends StatelessWidget {
  const PersonalSafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.currentTheme,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Personal Safety',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          navigatorKey: _navigatorKey,
          initialRoute: '/splash',
          routes: {
            '/splash':       (_) => const SplashScreen(),
            '/welcome':      (_) => const WelcomeScreen(),
            '/permissions':  (_) => const PermissionsScreen(),
            '/contacts':     (_) => const ContactsScreen(),
            '/how-it-works': (_) => const HowItWorksScreen(),
            '/home':         (_) => const HomeScreen(),
            '/emergency':    (_) => const EmergencyScreen(),
            '/alert-sent':   (_) => const AlertSentScreen(),
            '/logs':         (_) => const LogsScreen(),
            '/settings':     (_) => const SettingsScreen(),
          },
        );
      },
    );
  }
}