import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../work/presentation/widgets/create_offer_sheet.dart';
import '../../../work/presentation/widgets/create_requirement_sheet.dart';

/// Home "+" menu: exactly two actions, each opening the existing Work Desk
/// creation flow. The menu closes before the chosen flow opens.
class HomeAddSheet extends StatelessWidget {
  const HomeAddSheet({super.key});

  static Future<void> show(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const HomeAddSheet(),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'requirement':
        await CreateRequirementSheet.show(context);
      case 'offer':
        await CreateOfferSheet.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _item(
              context,
              key: 'home_add_requirement',
              icon: LucideIcons.fileText,
              color: const Color(0xFF2563EB),
              label: 'Add Requirement',
              value: 'requirement',
            ),
            _item(
              context,
              key: 'home_add_offer',
              icon: LucideIcons.package,
              color: const Color(0xFF7C3AED),
              label: 'Add Offer',
              value: 'offer',
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required String key,
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return ListTile(
      key: ValueKey(key),
      minTileHeight: 56,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primaryNavy),
      ),
      onTap: () => Navigator.pop(context, value),
    );
  }
}
