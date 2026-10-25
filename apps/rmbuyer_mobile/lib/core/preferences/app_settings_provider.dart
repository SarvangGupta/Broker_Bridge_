import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/secure_storage_service.dart';

/// Available theme modes for the application.
enum AppThemeModePreference {
  system,
  light,
  dark;

  ThemeMode toThemeMode() {
    switch (this) {
      case AppThemeModePreference.system:
        return ThemeMode.system;
      case AppThemeModePreference.light:
        return ThemeMode.light;
      case AppThemeModePreference.dark:
        return ThemeMode.dark;
    }
  }

  String get label {
    switch (this) {
      case AppThemeModePreference.system:
        return 'System Default';
      case AppThemeModePreference.light:
        return 'Light';
      case AppThemeModePreference.dark:
        return 'Dark';
    }
  }

  static AppThemeModePreference fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'light':
        return AppThemeModePreference.light;
      case 'dark':
        return AppThemeModePreference.dark;
      case 'system':
      default:
        return AppThemeModePreference.system;
    }
  }
}

/// Accessible font scaling tiers.
enum AppFontSizePreference {
  small(0.85, 'Small', '0.85x compact density'),
  normal(1.0, 'Default', '1.0x standard scale'),
  large(1.15, 'Large', '1.15x enhanced reading'),
  extraLarge(1.30, 'Extra Large', '1.30x accessible scale');

  final double scaleFactor;
  final String label;
  final String description;

  const AppFontSizePreference(this.scaleFactor, this.label, this.description);

  static AppFontSizePreference fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'small':
        return AppFontSizePreference.small;
      case 'large':
        return AppFontSizePreference.large;
      case 'extralarge':
      case 'extra_large':
        return AppFontSizePreference.extraLarge;
      case 'normal':
      case 'default':
      default:
        return AppFontSizePreference.normal;
    }
  }
}

/// Supported application languages. [label] is the language's own name in its
/// own script; [englishName] is shown alongside it so every option is findable.
enum AppLanguagePreference {
  en('en', 'English', 'English'),
  hi('hi', 'हिन्दी', 'Hindi'),
  pa('pa', 'ਪੰਜਾਬੀ', 'Punjabi'),
  ta('ta', 'தமிழ்', 'Tamil'),
  te('te', 'తెలుగు', 'Telugu'),
  kn('kn', 'ಕನ್ನಡ', 'Kannada'),
  ml('ml', 'മലയാളം', 'Malayalam');

  final String code;
  final String label;
  final String englishName;

  const AppLanguagePreference(this.code, this.label, this.englishName);

  String get displayName => code == 'en' ? label : '$label ($englishName)';

  Locale toLocale() => Locale(code);

  /// Accepts a stored language code or English name; anything else is English.
  static AppLanguagePreference fromString(String? value) {
    final v = value?.trim().toLowerCase();
    for (final lang in AppLanguagePreference.values) {
      if (lang.code == v || lang.englishName.toLowerCase() == v) return lang;
    }
    return AppLanguagePreference.en;
  }
}

/// Immutable state containing user preferences.
class AppSettingsState {
  final AppThemeModePreference themeModePref;
  final AppFontSizePreference fontSizePref;
  final AppLanguagePreference languagePref;
  final bool highContrast;

  const AppSettingsState({
    this.themeModePref = AppThemeModePreference.system,
    this.fontSizePref = AppFontSizePreference.normal,
    this.languagePref = AppLanguagePreference.en,
    this.highContrast = false,
  });

  ThemeMode get themeMode => themeModePref.toThemeMode();
  double get fontScale => fontSizePref.scaleFactor;
  Locale get locale => languagePref.toLocale();

  AppSettingsState copyWith({
    AppThemeModePreference? themeModePref,
    AppFontSizePreference? fontSizePref,
    AppLanguagePreference? languagePref,
    bool? highContrast,
  }) {
    return AppSettingsState(
      themeModePref: themeModePref ?? this.themeModePref,
      fontSizePref: fontSizePref ?? this.fontSizePref,
      languagePref: languagePref ?? this.languagePref,
      highContrast: highContrast ?? this.highContrast,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsState &&
          runtimeType == other.runtimeType &&
          themeModePref == other.themeModePref &&
          fontSizePref == other.fontSizePref &&
          languagePref == other.languagePref &&
          highContrast == other.highContrast;

  @override
  int get hashCode =>
      themeModePref.hashCode ^
      fontSizePref.hashCode ^
      languagePref.hashCode ^
      highContrast.hashCode;
}

/// Riverpod provider for application settings.
final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettingsState>(
      AppSettingsNotifier.new,
    );

/// Notifier handling preference state changes and encrypted local persistence.
class AppSettingsNotifier extends Notifier<AppSettingsState> {
  static const String _keyTheme = 'rb_pref_theme_mode';
  static const String _keyFontSize = 'rb_pref_font_size';
  static const String _keyLanguage = 'rb_pref_language';
  static const String _keyHighContrast = 'rb_pref_high_contrast';

  late final SecureStorageService _storage;

  @override
  AppSettingsState build() {
    _storage = SecureStorageService();
    _loadPersistedPreferences();
    return const AppSettingsState();
  }

  Future<void> _loadPersistedPreferences() async {
    try {
      final themeStr = await _storage.getPreference(_keyTheme);
      final fontStr = await _storage.getPreference(_keyFontSize);
      final langStr = await _storage.getPreference(_keyLanguage);
      final contrastStr = await _storage.getPreference(_keyHighContrast);

      final loaded = AppSettingsState(
        themeModePref: AppThemeModePreference.fromString(themeStr),
        fontSizePref: AppFontSizePreference.fromString(fontStr),
        languagePref: AppLanguagePreference.fromString(langStr),
        highContrast: contrastStr == 'true',
      );

      state = loaded;
    } catch (_) {
      // Fallback safely to defaults on read errors
    }
  }

  Future<void> setThemeMode(AppThemeModePreference mode) async {
    state = state.copyWith(themeModePref: mode);
    await _storage.savePreference(_keyTheme, mode.name);
  }

  Future<void> setFontSize(AppFontSizePreference size) async {
    state = state.copyWith(fontSizePref: size);
    await _storage.savePreference(_keyFontSize, size.name);
  }

  Future<void> setLanguage(AppLanguagePreference lang) async {
    state = state.copyWith(languagePref: lang);
    await _storage.savePreference(_keyLanguage, lang.code);
  }

  Future<void> setHighContrast(bool enabled) async {
    state = state.copyWith(highContrast: enabled);
    await _storage.savePreference(_keyHighContrast, enabled ? 'true' : 'false');
  }
}
