import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/config/app_config.dart';
import 'widgets/app_settings_section.dart';
import 'widgets/more_menu_tile.dart';

/// More > Tools. Items open their existing routes.
class ToolsMenuScreen extends StatelessWidget {
  const ToolsMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MoreSectionPage(
      title: 'Tools',
      subtitle: 'Daily tools to manage your business',
      icon: LucideIcons.briefcase,
      tint: MoreTint.green,
      items: [
        MoreSectionItem('broadcast', LucideIcons.megaphone, 'Market Price Broadcast',
            'Send verified prices to buyers', (c) => c.push('/broadcast/market-price')),
        MoreSectionItem('broadcast_history', LucideIcons.history, 'Broadcast Price History',
            'Review sent prices, recipients & audit trail', (c) => c.push('/broadcast/history')),
        MoreSectionItem('tasks', LucideIcons.squareCheck, 'My Tasks',
            'Track action items, priorities & business follow-ups', (c) => c.push('/tasks')),
        MoreSectionItem('notifications', LucideIcons.bell, 'Notifications & Activity Center',
            'Operational alerts, mandates, deals & invoices', (c) => c.push('/notifications')),
      ],
    );
  }
}

/// More > Finance. Items open the existing commission and invoice screens.
class FinanceMenuScreen extends StatelessWidget {
  const FinanceMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MoreSectionPage(
      title: 'Finance',
      subtitle: 'Track your earnings, invoicing and payments',
      icon: LucideIcons.coins,
      tint: MoreTint.orange,
      items: [
        MoreSectionItem('commission', LucideIcons.indianRupee, 'Brokerage & Commission Ledger',
            'Track earnings, invoicing & payments', (c) => c.push('/commission')),
        MoreSectionItem('invoices', LucideIcons.fileSpreadsheet, 'Commission Invoices & Statements',
            'Issue invoices, statements & reconciliation', (c) => c.push('/invoices')),
      ],
    );
  }
}

/// More > Settings. Preference items open one group of the existing settings
/// controls; Security and Audit have no screen yet and say so.
class SettingsMenuScreen extends StatelessWidget {
  const SettingsMenuScreen({super.key});

  static void _notAvailable(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what is not available yet.')),
    );
  }

  static void _showFiduciary(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Broker Fiduciary Boundary'),
        content: const Text('${AppConfig.fiduciaryNoticeEn}\n\n${AppConfig.fiduciaryNoticeHi}'),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Understood'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MoreSectionPage(
      title: 'Settings',
      subtitle: 'App preferences, security and system settings',
      icon: LucideIcons.settings,
      tint: MoreTint.purple,
      items: [
        MoreSectionItem('language', LucideIcons.globe, 'Language', 'English & हिन्दी',
            (c) => c.go('/more/settings/language')),
        MoreSectionItem('theme', LucideIcons.palette, 'Appearance & Theme', 'Light, Dark or System Default',
            (c) => c.go('/more/settings/theme')),
        MoreSectionItem('font', LucideIcons.type, 'Font Size & Text Scaling',
            'Adjust text size for better readability', (c) => c.go('/more/settings/font')),
        MoreSectionItem('accessibility', LucideIcons.accessibility, 'Accessibility & Contrast',
            'High contrast, eye-protection & touch targets', (c) => c.go('/more/settings/accessibility')),
        MoreSectionItem('security', LucideIcons.shieldCheck, 'Security & Access Logs', 'Not available yet',
            (c) => _notAvailable(c, 'Security & Access Logs')),
        MoreSectionItem('audit', LucideIcons.fileText, 'Audit Trails & Reports', 'Not available yet',
            (c) => _notAvailable(c, 'Audit Trails & Reports')),
        MoreSectionItem('fiduciary', LucideIcons.info, 'Fiduciary Disclaimer',
            'View fiduciary and regulatory information', _showFiduciary),
      ],
    );
  }
}

/// More > Settings > one preference group, using the existing controls.
class PreferenceGroupScreen extends StatelessWidget {
  final AppSettingsGroup group;

  const PreferenceGroupScreen({super.key, required this.group});

  static AppSettingsGroup? fromSlug(String? slug) => switch (slug) {
        'theme' => AppSettingsGroup.theme,
        'language' => AppSettingsGroup.language,
        'font' => AppSettingsGroup.fontSize,
        'accessibility' => AppSettingsGroup.accessibility,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        foregroundColor: AppColors.primaryNavy,
        elevation: 0,
        titleSpacing: 0,
        title: const Text('Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [AppSettingsSection(group: group)],
      ),
    );
  }
}
