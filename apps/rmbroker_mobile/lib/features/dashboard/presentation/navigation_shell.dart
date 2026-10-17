import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';

/// Bottom navigation shell wrapping the 5 core broker modules.
class NavigationShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const NavigationShell({super.key, required this.navigationShell});

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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.borderLight, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onTap,
          destinations: const [
            NavigationDestination(
              icon: Icon(LucideIcons.home),
              selectedIcon: Icon(LucideIcons.home, color: AppColors.primary),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.layers),
              selectedIcon: Icon(LucideIcons.layers, color: AppColors.primary),
              label: 'Work Desk',
            ),
            NavigationDestination(
              icon: Icon(Icons.handshake_outlined),
              selectedIcon: Icon(
                Icons.handshake_outlined,
                color: AppColors.primary,
              ),
              label: 'Deals',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.users),
              selectedIcon: Icon(LucideIcons.users, color: AppColors.primary),
              label: 'Directory',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.moreHorizontal),
              selectedIcon: Icon(
                LucideIcons.moreHorizontal,
                color: AppColors.primary,
              ),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}
