import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';

enum MoreTint {
  green(Color(0xFF0F766E), Color(0xFFE6F6F1)),
  orange(Color(0xFFC2410C), Color(0xFFFFF4E8)),
  purple(Color(0xFF6D28D9), Color(0xFFF2ECFD));

  final Color fg;
  final Color bg;
  const MoreTint(this.fg, this.bg);
}

/// Large title + subtitle used at the top of More and its section pages.
class MoreSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData? icon;
  final MoreTint tint;

  const MoreSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.tint = MoreTint.green,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          CircleAvatar(
            radius: 30,
            backgroundColor: tint.bg,
            child: Icon(icon, size: 28, color: tint.fg),
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.primaryNavy),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondaryLight)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Rounded menu card: tinted circular icon (or initial), title, subtitle, chevron.
class MoreMenuTile extends StatelessWidget {
  final IconData icon;
  final String? leadingText;
  final MoreTint tint;
  final bool filled;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const MoreMenuTile({
    super.key,
    required this.icon,
    this.leadingText,
    this.tint = MoreTint.green,
    this.filled = false,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: filled ? tint.bg.withValues(alpha: 0.6) : AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderLight),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: MoreItemRow(
              icon: icon,
              leadingText: leadingText,
              tint: tint,
              title: title,
              subtitle: subtitle,
              titleSize: 17,
            ),
          ),
        ),
      ),
    );
  }
}

/// Row content shared by menu cards and section list items.
class MoreItemRow extends StatelessWidget {
  final IconData icon;
  final String? leadingText;
  final MoreTint tint;
  final String title;
  final String subtitle;
  final double titleSize;

  const MoreItemRow({
    super.key,
    required this.icon,
    this.leadingText,
    required this.tint,
    required this.title,
    required this.subtitle,
    this.titleSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: tint.bg,
          child: leadingText != null
              ? Text(leadingText!, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tint.fg))
              : Icon(icon, size: 22, color: tint.fg),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w700, color: AppColors.primaryNavy),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondaryLight)),
            ],
          ),
        ),
        const SizedBox(width: 6),
        const Icon(LucideIcons.chevronRight, size: 20, color: AppColors.textSecondaryLight),
      ],
    );
  }
}

/// One entry of a section page.
class MoreSectionItem {
  final String keyName;
  final IconData icon;
  final String title;
  final String subtitle;
  final void Function(BuildContext context) onTap;

  const MoreSectionItem(this.keyName, this.icon, this.title, this.subtitle, this.onTap);
}

/// Section page (Tools / Finance / Settings) under the More tab: back to More,
/// header, then one card listing its items.
class MoreSectionPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final MoreTint tint;
  final List<MoreSectionItem> items;

  const MoreSectionPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        foregroundColor: AppColors.primaryNavy,
        elevation: 0,
        titleSpacing: 0,
        title: const Text('More', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          MoreSectionHeader(title: title, subtitle: subtitle, icon: icon, tint: tint),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 76, endIndent: 14),
                    Semantics(
                      button: true,
                      label: items[i].title,
                      child: InkWell(
                        key: Key('more_item_${items[i].keyName}'),
                        onTap: () => items[i].onTap(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: MoreItemRow(
                            icon: items[i].icon,
                            tint: tint,
                            title: items[i].title,
                            subtitle: items[i].subtitle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
