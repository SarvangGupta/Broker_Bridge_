import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/core/preferences/app_settings_provider.dart';
import 'package:rmbuyer_mobile/l10n/app_localizations.dart';
import 'package:rmbuyer_mobile/l10n/translations.dart';

/// Unicode block each language must be written in.
const _scripts = {
  'hi': (0x0900, 0x097F), // Devanagari
  'pa': (0x0A00, 0x0A7F), // Gurmukhi
  'ta': (0x0B80, 0x0BFF), // Tamil
  'te': (0x0C00, 0x0C7F), // Telugu
  'kn': (0x0C80, 0x0CFF), // Kannada
  'ml': (0x0D00, 0x0D7F), // Malayalam
};

/// Keys that are identifiers and stay in Latin script in every language.
const _latinByDesign = {Tr.profGstin};

bool _usesScript(String s, (int, int) range) =>
    s.runes.any((r) => r >= range.$1 && r <= range.$2);

void main() {
  test('the seven requested languages are offered, in order', () {
    expect(AppLanguagePreference.values.map((l) => l.code), [
      'en',
      'hi',
      'pa',
      'ta',
      'te',
      'kn',
      'ml',
    ]);
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode),
      AppLanguagePreference.values.map((l) => l.code),
    );
  });

  for (final lang in AppLanguagePreference.values) {
    test('${lang.englishName}: every interface key is translated', () {
      final table = appTranslations[lang.code]!;
      final missing = Tr.values
          .where((k) => (table[k] ?? '').trim().isEmpty)
          .toList();
      expect(missing, isEmpty, reason: 'missing keys: $missing');
    });
  }

  for (final entry in _scripts.entries) {
    test(
      '${entry.key}: translations are written in the language\'s own script',
      () {
        final table = appTranslations[entry.key]!;
        final wrongScript = [
          for (final k in Tr.values)
            if (!_latinByDesign.contains(k) &&
                !_usesScript(table[k]!, entry.value))
              k,
        ];
        expect(
          wrongScript,
          isEmpty,
          reason: 'not in expected script: $wrongScript',
        );
        // The language's own name is in its script too.
        final lang = AppLanguagePreference.fromString(entry.key);
        expect(_usesScript(lang.label, entry.value), isTrue);
      },
    );
  }

  test('identifiers kept in Latin are identical across languages', () {
    for (final code in appTranslations.keys) {
      expect(appTranslations[code]![Tr.profGstin], 'GSTIN');
    }
  });

  test('Flutter ships Material and Cupertino localizations for every offered language', () {
    for (final locale in AppLocalizations.supportedLocales) {
      expect(
        GlobalMaterialLocalizations.delegate.isSupported(locale),
        isTrue,
        reason: '$locale',
      );
      expect(
        GlobalCupertinoLocalizations.delegate.isSupported(locale),
        isTrue,
        reason: '$locale',
      );
    }
  });

  test('lookup falls back to English for an unsupported locale', () {
    expect(const AppLocalizations(Locale('fr')).t(Tr.navHome), 'Home');
    expect(const AppLocalizations(Locale('ta')).t(Tr.navHome), 'முகப்பு');
  });

  test('stored language codes and names restore the right language; unknown values are English', () {
    expect(AppLanguagePreference.fromString('ml'), AppLanguagePreference.ml);
    expect(
      AppLanguagePreference.fromString('Punjabi'),
      AppLanguagePreference.pa,
    );
    expect(AppLanguagePreference.fromString('xx'), AppLanguagePreference.en);
    expect(AppLanguagePreference.fromString(null), AppLanguagePreference.en);
  });
}
