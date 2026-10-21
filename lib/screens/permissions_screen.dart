import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';
import '../services/permission_service.dart';
import '../services/trigger_channel.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});
  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  final Map<String, bool> _granted = {
    'Location': false,
    'Camera': false,
    'Microphone': false,
    'Storage': false,
    'Display Over Other Apps': false,
    'Accessibility Service': false,
  };
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final location = await Permission.location.isGranted || await Permission.locationAlways.isGranted;
    final camera = await Permission.camera.isGranted;
    final mic = await Permission.microphone.isGranted;
    // Storage is simulated as true since it is not requested in standard permission requests
    final storage = true;
    final overlay = await Permission.systemAlertWindow.isGranted;
    final accessibility = await TriggerChannel.isAccessibilityServiceEnabled();

    if (!mounted) return;
    setState(() {
      _granted['Location'] = location;
      _granted['Camera'] = camera;
      _granted['Microphone'] = mic;
      _granted['Storage'] = storage;
      _granted['Display Over Other Apps'] = overlay;
      _granted['Accessibility Service'] = accessibility;
    });
  }

  Future<void> _handleTapPermission(String name) async {
    if (name == 'Location') {
      await Permission.location.request();
      await Permission.locationAlways.request();
    } else if (name == 'Camera') {
      await Permission.camera.request();
    } else if (name == 'Microphone') {
      await Permission.microphone.request();
    } else if (name == 'Storage') {
      await Permission.storage.request();
    } else if (name == 'Display Over Other Apps') {
      await TriggerChannel.openOverlaySettings();
    } else if (name == 'Accessibility Service') {
      await TriggerChannel.openAccessibilitySettings();
    }
    await _checkPermissions();
  }

  Future<void> _allowAll() async {
    setState(() => _loading = true);
    
    // Request basic runtime permissions first
    await PermissionService.requestAll();
    await _checkPermissions();

    // Check display over other apps
    final overlay = await Permission.systemAlertWindow.isGranted;
    if (!overlay) {
      await TriggerChannel.openOverlaySettings();
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    // Check accessibility service
    final accessibility = await TriggerChannel.isAccessibilityServiceEnabled();
    if (!accessibility) {
      await TriggerChannel.openAccessibilitySettings();
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  static const _items = [
    (Icons.location_on,   'Location',                'To share your live location'),
    (Icons.camera_alt,    'Camera',                  'To capture photos'),
    (Icons.mic,           'Microphone',              'To record audio'),
    (Icons.folder,        'Storage',                 'To save and upload files'),
    (Icons.phone_android, 'Display Over Other Apps', 'To show fake power off screen'),
    (Icons.accessibility, 'Accessibility Service',   'To detect volume button press'),
  ];

  @override
  Widget build(BuildContext context) {
    final allGranted = _granted.values.every((v) => v);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Allow Permissions',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                    color: AppColors.textDark)),
            const SizedBox(height: 6),
            const Text('To keep you safe, we need the following permissions.',
                style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final name = _items[i].$2;
                  final ok = _granted[name] ?? false;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    onTap: () => _handleTapPermission(name),
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_items[i].$1, color: AppColors.primary, size: 20),
                    ),
                    title: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(_items[i].$3,
                        style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                    trailing: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: ok
                          ? const Icon(Icons.check_circle, color: AppColors.success, size: 26)
                          : const Icon(Icons.radio_button_unchecked,
                              color: AppColors.textGrey, size: 26),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading
                  ? null
                  : (allGranted
                      ? () => Navigator.pushNamed(context, '/contacts')
                      : _allowAll),
              child: _loading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(allGranted ? 'Continue' : 'Allow All'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
