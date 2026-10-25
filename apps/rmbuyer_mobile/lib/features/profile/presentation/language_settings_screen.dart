import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/preferences/app_settings_provider.dart';
import '../../../core/widgets/app_card.dart';
import '../../../l10n/app_localizations.dart';

/// Language selection. The choice applies at once and is saved with the other
/// app preferences, so it is restored on the next launch.
class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(appSettingsProvider).languagePref;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr(Tr.titleLanguage))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                context.tr(Tr.langSelect),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ),
            AppCard(
              padding: EdgeInsets.zero,
              child: Material(
                type: MaterialType.transparency,
                child: RadioGroup<AppLanguagePreference>(
                  groupValue: selected,
                  onChanged: (lang) => _select(context, ref, lang),
                  child: Column(
                    children: [
                      for (final lang in AppLanguagePreference.values) ...[
                        if (lang != AppLanguagePreference.values.first)
                          const Divider(height: 1),
                        RadioListTile<AppLanguagePreference>(
                          key: Key('language-${lang.code}'),
                          value: lang,
                          title: Text(
                            lang.label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: lang == AppLanguagePreference.en
                              ? null
                              : Text(lang.englishName),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  LucideIcons.info,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.tr(Tr.langCoverageNote),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    AppLanguagePreference? lang,
  ) async {
    if (lang == null) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(appSettingsProvider.notifier).setLanguage(lang);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations(lang.toLocale()).t(Tr.langChanged)),
        ),
      );
  }
}
