import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';

/// Persistent shell container providing the main bottom navigation across the 5 Seller destinations:
/// 1. Home
/// 2. My Commodities
/// 3. My Brokers (raised centre button)
/// 4. Deals & Documents
/// 5. More (Profile, Settings, Reports, Help & Support)
class NavigationShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const NavigationShell({super.key, required this.navigationShell});

  static const int brokersIndex = 2;

  static const List<({IconData icon, String label})> _items = [
    (icon: LucideIcons.house, label: 'Home'),
    (icon: LucideIcons.package, label: 'Commodities'),
    (icon: LucideIcons.users, label: 'Brokers'),
    (icon: LucideIcons.handshake, label: 'Deals'),
    (icon: LucideIcons.ellipsis, label: 'More'),
  ];

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      backgroundColor: AppColors.backgroundLight,
      bottomNavigationBar: _GlassNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
        items: _items,
        centerIndex: brokersIndex,
      ),
    );
  }
}

class _GlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<({IconData icon, String label})> items;
  final int centerIndex;

  const _GlassNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.items,
    required this.centerIndex,
  });

  /// Space above the bar body reserved for the raised centre button, so the
  /// button never overlaps page content.
  static const double _raise = 14;
  static const double _barHeight = 66;
  static const double _centerSize = 62;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      key: const Key('seller_bottom_nav'),
      color: AppColors.backgroundLight,
      padding: EdgeInsets.fromLTRB(10, 0, 10, bottomInset > 0 ? bottomInset : 8),
      child: SizedBox(
        height: _barHeight + _raise,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Frosted glass body
            Positioned.fill(
              top: _raise,
              child: _glassPanel(borderRadius: BorderRadius.circular(24)),
            ),
            // Hump behind the centre button
            Positioned(
              top: 0,
              child: SizedBox(
                width: _centerSize + 22,
                height: _centerSize + 6,
                child: _glassPanel(
                  borderRadius: BorderRadius.circular(_centerSize),
                  shadow: false,
                ),
              ),
            ),
            // Items
            Positioned.fill(
              top: _raise,
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: i == centerIndex
                          ? const SizedBox.shrink()
                          : _NavItem(
                              key: Key('nav_item_${items[i].label}'),
                              icon: items[i].icon,
                              label: items[i].label,
                              selected: currentIndex == i,
                              onTap: () => onTap(i),
                            ),
                    ),
                ],
              ),
            ),
            // Raised glossy centre button
            Positioned(
              top: 2,
              child: _CenterButton(
                key: Key('nav_item_${items[centerIndex].label}'),
                icon: items[centerIndex].icon,
                label: items[centerIndex].label,
                size: _centerSize,
                selected: currentIndex == centerIndex,
                onTap: () => onTap(centerIndex),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassPanel({required BorderRadius borderRadius, bool shadow = true}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.92),
                  const Color(0xFFF3EEF6).withValues(alpha: 0.85),
                  const Color(0xFFEAF0FA).withValues(alpha: 0.85),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textPrimaryLight;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38,
              height: 30,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: selected ? 1 : 0,
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  const _CenterButton({
    super.key,
    required this.icon,
    required this.label,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.35, -0.45),
              radius: 1.0,
              colors: [
                Color.lerp(AppColors.primary, Colors.white, 0.35)!,
                AppColors.primary,
                Color.lerp(AppColors.primary, Colors.black, 0.25)!,
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.85),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(
                  alpha: selected ? 0.45 : 0.3,
                ),
                blurRadius: selected ? 18 : 12,
                spreadRadius: selected ? 1 : 0,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glossy highlight
              Positioned(
                top: 5,
                child: Container(
                  width: size * 0.55,
                  height: size * 0.24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.45),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 22, color: Colors.white),
                  const SizedBox(height: 1),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
