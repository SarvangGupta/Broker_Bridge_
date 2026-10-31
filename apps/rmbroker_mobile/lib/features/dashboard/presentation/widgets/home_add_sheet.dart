import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/widgets/glass_fab_menu.dart';
import '../../../work/presentation/widgets/create_offer_sheet.dart';
import '../../../work/presentation/widgets/create_requirement_sheet.dart';

/// Home "+" menu: two labelled actions, each opening the existing Work Desk
/// creation flow. The menu closes before the chosen flow opens.
class HomeAddSheet extends StatelessWidget {
  /// The "+" button's rect on screen; the close button sits exactly over it.
  final Rect fabRect;
  final Animation<double> animation;

  const HomeAddSheet({super.key, required this.fabRect, required this.animation});

  /// [context] must be the "+" button's own context, which gives the menu its anchor.
  static Future<void> show(BuildContext context) {
    return GlassFabMenu.guarded(context, (navigator, fabRect) async {
      final choice = await GlassFabMenu.present<String>(
        navigator,
        (animation) => HomeAddSheet(fabRect: fabRect, animation: animation),
      );
      if (!context.mounted) return;
      switch (choice) {
        case 'requirement':
          await CreateRequirementSheet.show(context);
        case 'offer':
          await CreateOfferSheet.show(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassFabMenu<String>(
      fabRect: fabRect,
      animation: animation,
      closeKey: const ValueKey('home_add_close'),
      backdropKey: const ValueKey('home_add_backdrop'),
      actions: const [
        GlassFabAction(
          key: ValueKey('home_add_requirement'),
          value: 'requirement',
          icon: LucideIcons.fileText,
          color: Color(0xFF0F9F7F),
          label: 'Add Buyer Requirement',
        ),
        GlassFabAction(
          key: ValueKey('home_add_offer'),
          value: 'offer',
          icon: LucideIcons.package,
          color: Color(0xFF7C3AED),
          label: 'Add Seller Offer',
        ),
      ],
    );
  }
}