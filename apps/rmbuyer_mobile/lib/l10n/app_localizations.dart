import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'translations.dart';

/// Translation keys for user-facing interface strings.
///
/// Business data (product and company names, prices, quantities, codes,
/// notification text from the server, user-entered text) is never passed
/// through this table; it is shown exactly as stored.
enum Tr {
  // Bottom navigation
  navHome,
  navRequirements,
  navDeals,
  navNutrition,
  navProfile,

  // Screen titles
  titleRequirements,
  titleDeals,
  titleNutrition,
  titleNotifications,
  titleOffers,
  titleProposalDetails,
  titleFinalDealReview,
  titlePostRequirement,
  titleBrokerProfile,
  titleSearch,
  titleProfileSettings,
  titleEditProfile,
  titleLanguage,
  titleDisplay,

  // Home header
  homeSubtitle,
  homeSearchHint,
  tooltipNotifications,
  tooltipProfileSettings,

  // Common
  commonRetry,
  commonErrorTitle,
  commonCancel,
  commonSave,
  commonSaving,
  commonNotProvided,
  commonDiscard,
  commonKeepEditing,

  // Notifications
  notifLoading,
  notifError,
  notifEmptyTitle,
  notifEmptyBody,
  notifUnreadCount,
  notifFilterAll,
  notifFilterUnread,
  notifMarkAllRead,
  notifMarkReadFailed,
  notifLatestNote,
  notifUnreadEmpty,
  notifOpen,
  notifTargetUnavailable,
  notifTargetNotSupported,
  notifOpenFailed,
  notifDetailTitle,
  evtProposal,
  evtConfirmation,
  evtDeal,
  evtFulfilment,
  evtDocument,
  evtPayment,
  evtRequirement,
  evtUpdate,
  commonClose,

  // Profile & Settings hub
  hubEditProfile,
  hubEditProfileSub,
  hubLanguage,
  hubDisplay,
  hubDisplaySub,
  hubSignOut,
  signOutTitle,
  signOutBody,
  signOutConfirm,

  // Profile
  profileLoadError,
  profPersonal,
  profCompany,
  profAccount,
  profName,
  profMobile,
  profMobileHint,
  profEmail,
  profRole,
  profRoleBuyer,
  profRoleAdmin,
  profCompanyName,
  profGstin,
  profVerification,
  profVerified,
  profNotVerified,
  profProtectedNote,
  profSaveSuccess,
  profSaveError,
  profNoChanges,
  valNameRequired,
  valNameLength,
  valMobileInvalid,
  profUnsavedTitle,
  profUnsavedBody,

  // Language
  langSelect,
  langCoverageNote,
  langChanged,

  // Display & accessibility
  dispHeader,
  dispHeaderSub,
  dispTheme,
  dispThemeSub,
  dispLight,
  dispDark,
  dispSystem,
  dispFontSize,
  dispFontSizeSub,
  dispFontSmall,
  dispFontDefault,
  dispFontLarge,
  dispFontXL,
  dispPreviewLabel,
  dispPreviewText,
  dispAccessibility,
  dispAccessibilitySub,
  dispHighContrast,
  dispHighContrastSub,
  dispA11yNote,
}

/// Interface strings for one locale, falling back to English per key.
class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('hi'),
    Locale('pa'),
    Locale('ta'),
    Locale('te'),
    Locale('kn'),
    Locale('ml'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const AppLocalizations english = AppLocalizations(Locale('en'));

  /// The current localizations, or English when no delegate is installed
  /// (for example a bare `MaterialApp` in a widget test).
  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ?? english;

  String t(Tr key) =>
      appTranslations[locale.languageCode]?[key] ??
      appTranslations['en']![key]!;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (l) => l.languageCode == locale.languageCode,
  );

  /// Synchronous so the first frame is not held back while strings "load".
  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(Locale(locale.languageCode)));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsContext on BuildContext {
  String tr(Tr key) => AppLocalizations.of(this).t(key);

  /// [key] with its `{n}` placeholder replaced by [n].
  String trN(Tr key, int n) => tr(key).replaceAll('{n}', '$n');
}
