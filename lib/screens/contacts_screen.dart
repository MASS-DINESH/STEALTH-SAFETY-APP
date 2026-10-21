import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final List<TextEditingController> _controllers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('trusted_numbers');
    if (raw != null) {
      final list = (jsonDecode(raw) as List).cast<String>();
      if (list.isNotEmpty) {
        for (final num in list) {
          _controllers.add(TextEditingController(text: num));
        }
      }
    }
    if (_controllers.isEmpty) {
      _controllers.add(TextEditingController());
    }
    setState(() => _loading = false);
  }

  void _add() {
    if (_controllers.length >= 5) return;
    setState(() => _controllers.add(TextEditingController()));
  }

  void _remove(int i) {
    if (_controllers.length == 1) {
      _controllers[i].clear();
      return;
    }
    setState(() {
      _controllers[i].dispose();
      _controllers.removeAt(i);
    });
  }

  Future<void> _save() async {
    final numbers = _controllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (numbers.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one WhatsApp number.')));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final hadContacts = prefs.containsKey('trusted_numbers');

    await prefs.setString('trusted_numbers', jsonEncode(numbers));
    await prefs.setString('parent_whatsapp_number', numbers.first);

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
            Text('Trusted contacts saved successfully!'),
          ],
        ),
      ),
    );

    if (hadContacts) {
      Navigator.pop(context);
    } else {
      Navigator.pushNamed(context, '/how-it-works');
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textHeading = isDark ? AppColors.textLight : AppColors.textDark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trusted WhatsApp\nContacts',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textHeading,
                      height: 1.25,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Add phone numbers that will automatically receive your live moving location link, captured photos, and recorded audio notes in an emergency.',
                    style: TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _controllers.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _NumberField(
                          isDark: isDark,
                          controller: _controllers[i],
                          onRemove: () => _remove(i),
                        ),
                      ),
                    ),
                  ),
                  if (_controllers.length < 5)
                    Center(
                      child: TextButton.icon(
                        onPressed: _add,
                        icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                        label: const Text(
                          'Add Another WhatsApp Number',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Ensure country code is included (e.g. +91 98765 43210)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Save & Continue'),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final bool isDark;
  final TextEditingController controller;
  final VoidCallback onRemove;
  const _NumberField({required this.isDark, required this.controller, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final borderCol = isDark ? AppColors.borderDark : AppColors.border;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(color: borderCol),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.whatsapp,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: '+91 XXXXX XXXXX',
                hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.danger, size: 22),
            onPressed: onRemove,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
