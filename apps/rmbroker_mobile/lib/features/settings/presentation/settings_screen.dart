import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/preferences/app_settings_provider.dart';
import '../../more/presentation/widgets/app_settings_section.dart';

/// Dedicated application settings screen accessible from anywhere in RMBroker.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final isIconOnly = settings.iconOnlyMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Preferences'),
        actions: [
          // Asterisk icon-only toggle button
          IconButton(
            tooltip: isIconOnly ? 'Show labels (*)' : 'Hide labels (*)',
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isIconOnly
                    ? AppColors.primary
                    : AppColors.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '*',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isIconOnly ? Colors.white : AppColors.primary,
                ),
              ),
            ),
            onPressed: () =>
                ref.read(appSettingsProvider.notifier).toggleIconOnlyMode(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: const [
          AppSettingsSection(),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}
