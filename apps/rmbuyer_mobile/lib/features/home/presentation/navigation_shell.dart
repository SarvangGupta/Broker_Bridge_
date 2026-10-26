import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Navigation shell hosting the persistent bottom navigation bar for RMBuyer.
/// Branch order: Home, Requirements, Brokers (central floating button), Deals, More.
class NavigationShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  static const int brokersIndex = 2;
  static const double _barHeight = 64;
  static const double _centerSize = 64;

  const NavigationShell({
    super.key,
    required this.navigationShell,
  });

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = navigationShell.currentIndex;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SizedBox(
        // Extra headroom lets the central button rise above the bar without
        // overlapping scrollable content (the body ends above this box).
        height: _barHeight + bottomInset + 18,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: _barHeight + bottomInset,
                padding: EdgeInsets.only(bottom: bottomInset),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  border: const Border(
                    top: BorderSide(color: AppColors.borderLight),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _NavItem(
                      icon: LucideIcons.home,
                      label: context.tr(Tr.navHome),
                      selected: current == 0,
                      onTap: () => _onTap(0),
                    ),
                    _NavItem(
                      icon: LucideIcons.clipboardList,
                      label: context.tr(Tr.navRequirements),
                      selected: current == 1,
                      onTap: () => _onTap(1),
                    ),
                    const Expanded(child: SizedBox()),
                    _NavItem(
                      icon: LucideIcons.handshake,
                      label: context.tr(Tr.navDeals),
                      selected: current == 3,
                      onTap: () => _onTap(3),
                    ),
                    _NavItem(
                      icon: LucideIcons.ellipsis,
                      label: 'More',
                      selected: current == 4,
                      onTap: () => _onTap(4),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              child: _CenterBrokersButton(
                size: _centerSize,
                selected: current == brokersIndex,
                onTap: () => _onTap(brokersIndex),
              ),
            ),
          ],
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
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.success : AppColors.textSecondaryLight;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Elevated circular Brokers button with a soft glass highlight and green accent.
class _CenterBrokersButton extends StatelessWidget {
  final double size;
  final bool selected;
  final VoidCallback onTap;

  const _CenterBrokersButton({
    required this.size,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Brokers',
      child: GestureDetector(
        key: const Key('nav-brokers'),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surfaceLight, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: selected ? 0.45 : 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.success.withValues(alpha: 0.92),
                      AppColors.primaryLight.withValues(alpha: 0.96),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Glass highlight
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: size / 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.28),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.users, size: 22, color: Colors.white),
                          SizedBox(height: 2),
                          Text(
                            'Brokers',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
