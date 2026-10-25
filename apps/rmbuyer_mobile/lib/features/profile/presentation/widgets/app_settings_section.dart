import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/preferences/app_settings_provider.dart';
import '../../../../l10n/app_localizations.dart';

/// Common accessible application settings section for RMBuyer.
/// Provides real-time reactive controls for:
/// - Theme Mode (Light, Dark, System Default)
/// - Accessible Font Scaling (Small, Default, Large, Extra Large)
/// - Accessibility Features (High Contrast UI Outlines, Semantic Readability)
///
/// Language has its own screen (Profile & Settings → Language).
class AppSettingsSection extends ConsumerWidget {
  const AppSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final borderColor = settings.highContrast
        ? (isDark ? Colors.white70 : Colors.black87)
        : (isDark ? AppColors.borderDark : AppColors.borderLight);
    final borderWidth = settings.highContrast ? 2.0 : 1.0;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    LucideIcons.settings,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(Tr.dispHeader),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr(Tr.dispHeaderSub),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 18),

            // 1. THEME MODE SELECTION
            _buildSubHeader(
              context,
              icon: LucideIcons.palette,
              title: context.tr(Tr.dispTheme),
              description: context.tr(Tr.dispThemeSub),
            ),
            const SizedBox(height: 12),
            _buildThemeSelector(context, settings, notifier, isDark),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 18),

            // 2. ACCESSIBLE FONT SCALING
            _buildSubHeader(
              context,
              icon: LucideIcons.type,
              title: context.tr(Tr.dispFontSize),
              description: context.tr(Tr.dispFontSizeSub),
            ),
            const SizedBox(height: 12),
            _buildFontSizeSelector(context, settings, notifier, isDark),
            const SizedBox(height: 12),
            _buildFontPreviewBox(context, settings, isDark),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 18),

            // 3. ACCESSIBILITY CONTROLS
            _buildSubHeader(
              context,
              icon: LucideIcons.contrast,
              title: context.tr(Tr.dispAccessibility),
              description: context.tr(Tr.dispAccessibilitySub),
            ),
            const SizedBox(height: 10),
            _buildAccessibilityToggles(context, settings, notifier, isDark),
          ],
        ),
      ),
    );
  }

  static Tr _fontLabel(AppFontSizePreference size) => switch (size) {
    AppFontSizePreference.small => Tr.dispFontSmall,
    AppFontSizePreference.normal => Tr.dispFontDefault,
    AppFontSizePreference.large => Tr.dispFontLarge,
    AppFontSizePreference.extraLarge => Tr.dispFontXL,
  };

  Widget _buildSubHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark ? AppColors.secondaryLight : AppColors.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeSelector(
    BuildContext context,
    AppSettingsState settings,
    AppSettingsNotifier notifier,
    bool isDark,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AppThemeModePreference.values.map((mode) {
        final isSelected = settings.themeModePref == mode;
        final (IconData modeIcon, String modeLabel) = switch (mode) {
          AppThemeModePreference.light => (
            LucideIcons.sun,
            context.tr(Tr.dispLight),
          ),
          AppThemeModePreference.dark => (
            LucideIcons.moon,
            context.tr(Tr.dispDark),
          ),
          AppThemeModePreference.system => (
            LucideIcons.laptop,
            context.tr(Tr.dispSystem),
          ),
        };

        return Semantics(
          button: true,
          selected: isSelected,
          label: modeLabel,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => notifier.setThemeMode(mode),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark
                            ? AppColors.surfaceDark
                            : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      modeIcon,
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : (isDark
                                ? Colors.white70
                                : AppColors.textPrimaryLight),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      modeLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                  ? Colors.white
                                  : AppColors.textPrimaryLight),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFontSizeSelector(
    BuildContext context,
    AppSettingsState settings,
    AppSettingsNotifier notifier,
    bool isDark,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AppFontSizePreference.values.map((size) {
        final isSelected = settings.fontSizePref == size;
        final label = context.tr(_fontLabel(size));

        return Semantics(
          button: true,
          selected: isSelected,
          label: '$label ${(size.scaleFactor * 100).toInt()}%',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => notifier.setFontSize(size),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark
                            ? AppColors.surfaceDark
                            : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                  ? Colors.white
                                  : AppColors.textPrimaryLight),
                      ),
                    ),
                    Text(
                      '${(size.scaleFactor * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected
                            ? Colors.white70
                            : (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFontPreviewBox(
    BuildContext context,
    AppSettingsState settings,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(Tr.dispPreviewLabel),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr(Tr.dispPreviewText),
            style: TextStyle(
              fontSize: 13 * settings.fontScale,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessibilityToggles(
    BuildContext context,
    AppSettingsState settings,
    AppSettingsNotifier notifier,
    bool isDark,
  ) {
    return Column(
      children: [
        Semantics(
          label: context.tr(Tr.dispHighContrast),
          toggled: settings.highContrast,
          child: InkWell(
            onTap: () => notifier.setHighContrast(!settings.highContrast),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(Tr.dispHighContrast),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr(Tr.dispHighContrastSub),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: settings.highContrast,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => notifier.setHighContrast(val),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.successBackground.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(
                LucideIcons.shieldCheck,
                size: 16,
                color: AppColors.success,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr(Tr.dispA11yNote),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
