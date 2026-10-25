import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'widgets/app_settings_section.dart';

/// Theme, text size and contrast preferences (the existing app settings).
class DisplaySettingsScreen extends StatelessWidget {
  const DisplaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr(Tr.titleDisplay))),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: AppSettingsSection(),
        ),
      ),
    );
  }
}
