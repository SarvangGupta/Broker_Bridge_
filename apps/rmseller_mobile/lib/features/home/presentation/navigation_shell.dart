import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';

/// Persistent shell container providing the main bottom navigation across the 6 Seller destinations:
/// 1. Home / Dashboard
/// 2. My Commodities
/// 3. My Brokers
/// 4. Deals & Documents
/// 5. Sales History & Reports
/// 6. My Profile
class NavigationShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

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
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.borderLight)),
        ),
        child: BottomNavigationBar(
          currentIndex: navigationShell.currentIndex,
          onTap: _onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textMutedLight,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 10),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.layoutDashboard, size: 20),
              activeIcon: Icon(LucideIcons.layoutDashboard, size: 20, color: AppColors.primary),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.packageCheck, size: 20),
              activeIcon: Icon(LucideIcons.packageCheck, size: 20, color: AppColors.primary),
              label: 'Commodities',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.users, size: 20),
              activeIcon: Icon(LucideIcons.users, size: 20, color: AppColors.primary),
              label: 'Brokers',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.handshake, size: 20),
              activeIcon: Icon(LucideIcons.handshake, size: 20, color: AppColors.primary),
              label: 'Deals',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.barChart3, size: 20),
              activeIcon: Icon(LucideIcons.barChart3, size: 20, color: AppColors.primary),
              label: 'Reports',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.user, size: 20),
              activeIcon: Icon(LucideIcons.user, size: 20, color: AppColors.primary),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
