import 'package:flutter/material.dart';

import 'widgets/app_settings_section.dart';

/// Dedicated Application Settings screen for Seller App.
/// Hosts Theme, Language, Font Size, and Accessibility preferences.
class SellerSettingsScreen extends StatelessWidget {
  const SellerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Application Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: const [AppSettingsSection(), SizedBox(height: 24)],
      ),
    );
  }
}
