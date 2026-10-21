import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import 'app_card.dart';

/// Standard, honest placeholder screen for modules scheduled for upcoming micro-sprints.
/// Clearly informs the user about feature readiness without fabricating records.
class ModulePlaceholderScreen extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String scheduledSprint;

  const ModulePlaceholderScreen({
    super.key,
    required this.title,
    required this.description,
    this.icon = LucideIcons.construction,
    this.scheduledSprint = 'RB-SELLER Upcoming Sprint',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 56, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: AppTypography.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondaryLight),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              AppCard(
                backgroundColor: AppColors.backgroundLight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.calendarClock, size: 18, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    Text(
                      'Target Release: $scheduledSprint',
                      style: AppTypography.labelMedium.copyWith(color: AppColors.secondaryDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
