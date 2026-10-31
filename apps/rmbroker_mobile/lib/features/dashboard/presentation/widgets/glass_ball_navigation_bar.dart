import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';

/// Item description for [GlassBallNavigationBar].
class GlassNavItem {
  final String label;
  final IconData icon;
  final String keyName;

  const GlassNavItem({
    required this.label,
    required this.icon,
    required this.keyName,
  });
}

/// Floating translucent frosted-glass bottom navigation bar featuring 3D glass-ball items.
///
/// Order is strictly:
/// 1. Home
/// 2. Work Desk
/// 3. Directory (Centre Item)
/// 4. Deals (Immediately Right of Directory)
/// 5. More
class GlassBallNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const GlassBallNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  static const List<GlassNavItem> items = [
    GlassNavItem(
      label: 'Home',
      icon: LucideIcons.home,
      keyName: 'glass_nav_home',
    ),
    GlassNavItem(
      label: 'Work Desk',
      icon: LucideIcons.layers,
      keyName: 'glass_nav_work',
    ),
    GlassNavItem(
      label: 'Directory',
      icon: LucideIcons.users,
      keyName: 'glass_nav_directory',
    ),
    GlassNavItem(
      label: 'Deals',
      icon: Icons.handshake_outlined,
      keyName: 'glass_nav_deals',
    ),
    GlassNavItem(
      label: 'More',
      icon: LucideIcons.moreHorizontal,
      keyName: 'glass_nav_more',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.90),
                    const Color(0xFFF0FDF4).withValues(alpha: 0.75),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.90),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (int i = 0; i < items.length; i++)
                    Expanded(
                      child: _buildNavItem(
                        context: context,
                        item: items[i],
                        index: i,
                        isSelected: selectedIndex == i,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required GlassNavItem item,
    required int index,
    required bool isSelected,
  }) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: InkResponse(
        key: ValueKey(item.keyName),
        onTap: () => onDestinationSelected(index),
        radius: 28,
        highlightShape: BoxShape.circle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildGlassBall(item.icon, isSelected),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isSelected ? 11 : 10.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFF0F766E)
                      : const Color(0xFF475569),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 18 : 0,
                height: 2.5,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassBall(IconData icon, bool isSelected) {
    final double size = isSelected ? 52.0 : 44.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutBack,
      width: size,
      height: size,
      decoration: isSelected
          ? BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.35, -0.45),
                radius: 0.90,
                colors: [
                  Color(0xFF2DD4BF), // Radiant mint/teal highlight
                  Color(0xFF0D9488), // Medium emerald/teal
                  Color(0xFF0F766E), // Deep teal base
                ],
                stops: [0.0, 0.55, 1.0],
              ),
              border: Border.all(
                color: const Color(0xFF99F6E4).withValues(alpha: 0.90),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.45),
                  blurRadius: 14,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.25),
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: const Offset(0, 7),
                ),
              ],
            )
          : BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.95),
                  Colors.white.withValues(alpha: 0.45),
                  const Color(0xFFE2E8F0).withValues(alpha: 0.60),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.90),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.8),
                  blurRadius: 4,
                  offset: const Offset(-2, -2),
                ),
              ],
            ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 3D Glass Specular Highlight Reflection (Curved gloss bubble)
          Positioned(
            top: isSelected ? 5 : 4,
            left: isSelected ? 10 : 8,
            child: Container(
              width: isSelected ? 18 : 14,
              height: isSelected ? 9 : 7,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isSelected ? 0.65 : 0.70),
                borderRadius: BorderRadius.all(
                  Radius.elliptical(isSelected ? 18 : 14, isSelected ? 9 : 7),
                ),
              ),
            ),
          ),
          // Inner icon
          Icon(
            icon,
            size: isSelected ? 22 : 20,
            color: isSelected ? Colors.white : AppColors.primaryNavy,
          ),
        ],
      ),
    );
  }
}

