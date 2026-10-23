import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/preferences/app_settings_provider.dart';

/// Common accessible application settings section for RMBroker.
/// Provides real-time reactive controls for:
/// - Theme Mode (Light, Dark, System Default)
/// - Language Selection (English, Hindi)
/// - Accessible Font Scaling (Small, Default, Large, Extra Large)
/// - Accessibility Features (High Contrast UI Outlines, Semantic Readability)
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
                        settings.languagePref == AppLanguagePreference.hi
                            ? 'एप्लिकेशन प्राथमिकताएं'
                            : 'Application Preferences',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        settings.languagePref == AppLanguagePreference.hi
                            ? 'थीम, भाषा, फ़ॉन्ट आकार और एक्सेसिबिलिटी'
                            : 'Theme, Language, Font Scaling & Accessibility',
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
              title: settings.languagePref == AppLanguagePreference.hi
                  ? 'थीम (रंग मोड)'
                  : 'Appearance & Theme',
              description: settings.languagePref == AppLanguagePreference.hi
                  ? 'लाइट, डार्क या सिस्टम के अनुसार स्वचालित'
                  : 'Choose light, dark, or follow device system settings',
            ),
            const SizedBox(height: 12),
            _buildThemeSelector(context, settings, notifier, isDark),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 18),

            // 2. LANGUAGE SELECTION
            _buildSubHeader(
              context,
              icon: LucideIcons.globe,
              title: settings.languagePref == AppLanguagePreference.hi
                  ? 'भाषा चयन (Language Selection)'
                  : 'Language Selection',
              description: settings.languagePref == AppLanguagePreference.hi
                  ? 'प्रमाणित समर्थित भाषा चुनें'
                  : 'Select from genuinely supported application languages',
            ),
            const SizedBox(height: 12),
            _buildLanguageSelector(context, settings, notifier, isDark),
            const SizedBox(height: 8),
            _buildLanguageDisclosure(context, settings, isDark),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 18),

            // 3. ACCESSIBLE FONT SCALING
            _buildSubHeader(
              context,
              icon: LucideIcons.type,
              title: settings.languagePref == AppLanguagePreference.hi
                  ? 'फ़ॉन्ट आकार (टेक्स्ट स्केलिंग)'
                  : 'Font Size & Text Scaling',
              description: settings.languagePref == AppLanguagePreference.hi
                  ? 'सुलभ पठन के लिए आकार समायोजित करें'
                  : 'Adjust typography scale for optimal legibility across all screens',
            ),
            const SizedBox(height: 12),
            _buildFontSizeSelector(context, settings, notifier, isDark),
            const SizedBox(height: 12),
            _buildFontPreviewBox(context, settings, isDark),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 18),

            // 4. ACCESSIBILITY CONTROLS
            _buildSubHeader(
              context,
              icon: LucideIcons.contrast,
              title: settings.languagePref == AppLanguagePreference.hi
                  ? 'अभिगम्यता और उच्च कंट्रास्ट'
                  : 'Accessibility & Contrast',
              description: settings.languagePref == AppLanguagePreference.hi
                  ? 'दृश्य स्पष्टता और स्क्रीन रीडर अनुकूलन'
                  : 'Enhanced borders, minimum 48px touch targets & screen reader semantics',
            ),
            const SizedBox(height: 10),
            _buildAccessibilityToggles(context, settings, notifier, isDark),
          ],
        ),
      ),
    );
  }

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
          color: isDark ? AppColors.primaryLight : AppColors.primary,
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
        IconData modeIcon;
        String modeLabel;

        switch (mode) {
          case AppThemeModePreference.light:
            modeIcon = LucideIcons.sun;
            modeLabel = settings.languagePref == AppLanguagePreference.hi
                ? 'लाइट'
                : 'Light';
            break;
          case AppThemeModePreference.dark:
            modeIcon = LucideIcons.moon;
            modeLabel = settings.languagePref == AppLanguagePreference.hi
                ? 'डार्क'
                : 'Dark';
            break;
          case AppThemeModePreference.system:
            modeIcon = LucideIcons.laptop;
            modeLabel = settings.languagePref == AppLanguagePreference.hi
                ? 'सिस्टम डिफ़ॉल्ट'
                : 'System Default';
            break;
        }

        return Semantics(
          button: true,
          selected: isSelected,
          label: 'Set theme mode to $modeLabel',
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

  Widget _buildLanguageSelector(
    BuildContext context,
    AppSettingsState settings,
    AppSettingsNotifier notifier,
    bool isDark,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AppLanguagePreference.values.map((lang) {
        final isSelected = settings.languagePref == lang;

        return Semantics(
          button: true,
          selected: isSelected,
          label: 'Select language ${lang.displayName}',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => notifier.setLanguage(lang),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
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
                      LucideIcons.globe,
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : (isDark
                                ? Colors.white70
                                : AppColors.textPrimaryLight),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      lang.displayName,
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

  Widget _buildLanguageDisclosure(
    BuildContext context,
    AppSettingsState settings,
    bool isDark,
  ) {
    final isHindi = settings.languagePref == AppLanguagePreference.hi;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.surfaceDark : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.info, size: 14, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isHindi
                  ? 'अंग्रेजी पूरी तरह समर्थित है। हिन्दी मुख्य विनियामक प्रकटीकरण, मंडी शब्दावली और संचालन संदेशों के लिए उपलब्ध है।'
                  : 'English is comprehensively supported across transactions. Hindi is supported for regulatory disclosures, mandi terms, and key notices.',
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
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

        return Semantics(
          button: true,
          selected: isSelected,
          label: 'Set font size to ${size.label} (${size.description})',
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
                      size.label,
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
    final isHindi = settings.languagePref == AppLanguagePreference.hi;

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
            isHindi
                ? 'लाइव पूर्वावलोकन (Live Text Preview):'
                : 'Live Text Preview:',
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
            isHindi
                ? 'मंडी सौदे, जिंस भाव और दलाली अनुबंध स्पष्ट रूप से पढ़े जा सकते हैं।'
                : 'Broker mandates, trade matching & commission ledgers render with optimal readability.',
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
    final isHindi = settings.languagePref == AppLanguagePreference.hi;

    return Column(
      children: [
        Semantics(
          label: isHindi ? 'उच्च कंट्रास्ट रूपरेखा' : 'High Contrast Outlines',
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
                          isHindi
                              ? 'उच्च कंट्रास्ट रूपरेखा (High Contrast)'
                              : 'High Contrast Outlines',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isHindi
                              ? 'कार्ड्स, बटन और बॉर्डर्स की दृश्यता बढ़ाएं'
                              : 'Increases border contrast and interactive focus boundaries',
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
        const Divider(height: 12),
        // Eye-Protection Mode Toggle
        Semantics(
          label: isHindi ? 'नेत्र सुरक्षा मोड' : 'Eye-Protection Mode',
          toggled: settings.eyeProtectionMode,
          child: InkWell(
            onTap: () => notifier.setEyeProtectionMode(!settings.eyeProtectionMode),
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
                          isHindi
                              ? 'नेत्र सुरक्षा मोड (Eye-Protection Mode)'
                              : 'Eye-Protection Mode',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isHindi
                              ? 'मंडी भाव और स्थिति की स्पष्टता बनाए रखते हुए कम चमक वाली गर्म डिस्प्ले'
                              : 'Comfortable low-glare warm tint display for extended desk trading sessions',
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
                    value: settings.eyeProtectionMode,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => notifier.setEyeProtectionMode(val),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 12),
        // Asterisk (*) Global Icon-Only Label Toggle
        Semantics(
          label: isHindi ? 'आइकन-ओनली लेबल मोड' : 'Asterisk (*) Icon-Only Mode',
          toggled: settings.iconOnlyMode,
          child: InkWell(
            onTap: () => notifier.toggleIconOnlyMode(),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '*',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isHindi
                                    ? 'आइकन-ओनली लेबल मोड (* Toggle)'
                                    : 'Asterisk (*) Icon-Only Mode',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isHindi
                              ? 'अनिवार्य फॉर्म लेबल्स, त्रुटियों और मंडी भावों को सुरक्षित रखते हुए नेविगेशन लेबल्स छुपाएं'
                              : 'Hides nonessential navigation labels while preserving essential form labels, validation errors & prices',
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
                    value: settings.iconOnlyMode,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => notifier.setIconOnlyMode(val),
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
                  isHindi
                      ? 'सिस्टम सुलभता सेटिंग सक्रिय: 48px टच टारगेट और टॉकबैक समर्थित।'
                      : 'Accessibility Compliant: Minimum 48px touch targets & screen-reader semantics active.',
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
