# RB-APP-SETTINGS-01: Baseline Audit Report
## Common Theme, Language, Font Size & Accessibility Preferences

**Audit Date:** 2026-10-21  
**Sprint Identifier:** `RB-APP-SETTINGS-01`  
**Apps Audited:**
1. RMBuyer Mobile (`apps/rmbuyer_mobile`)
2. RMSeller Mobile (`apps/rmseller_mobile`)
3. RMBroker Mobile (`apps/rmbroker_mobile`)

---

## 1. Executive Summary

This audit establishes the baseline across all three RMBroker mobile applications regarding theme management, localization, typography/font scaling, and accessibility controls. 

All three applications exist within the same monorepo (`apps/`), share the same Flutter/Dart SDK runtime (Flutter 3.47.6 / Dart 3.13.5), and utilize identical foundational packages (`flutter_riverpod: ^3.4.3`, `go_router: ^18.1.0`, `flutter_secure_storage: ^11.2.0`, `lucide_icons_flutter: ^4.0.0`, `intl: ^0.20.3`). 

However, user preference persistence and dynamic theme/font/language controls are currently fragmented:
- **Theme:** Hardcoded to `ThemeMode.light` in `rmseller_mobile` and `rmbroker_mobile` despite `AppTheme.darkTheme` / `AppTheme.dark` already existing in their theme definitions. `rmbuyer_mobile` lacks a dark `ThemeData` definition in `app_theme.dart` although dark palette tokens exist in `app_colors.dart`.
- **Language:** English (`en`) is the primary interface language. Bilingual notices (English + Hindi) exist in `AppConfig` (`fiduciaryNoticeEn` and `fiduciaryNoticeHi`), but no reactive locale switching or locale persistence exists in any of the three apps.
- **Font Scaling:** None of the apps provide dynamic user-controlled font scaling. The apps rely on default system typography without bounded accessible scaling tiers.
- **Accessibility:** Touch targets generally meet or exceed 48px, but dark mode contrast has not been connected to reactive state, and semantic labeling on settings controls is missing.

---

## 2. Per-Application Architectural Audit

### 2.1 RMBuyer Mobile (`apps/rmbuyer_mobile`)
- **Root Entry Point:** `lib/app/app.dart` (`RMBuyerApp` extends `ConsumerWidget`). Hardcoded `theme: AppTheme.lightTheme`. No `darkTheme` or `themeMode` configured.
- **Color Tokens:** `lib/app/theme/app_colors.dart` contains complete light and dark tokens (`backgroundDark = Color(0xFF1A2327)`, `surfaceDark = Color(0xFF263238)`, `cardDark = Color(0xFF1E282D)`, `borderDark = Color(0xFF37474F)`, `textPrimaryDark = Color(0xFFF6F8F7)`).
- **Theme Definition:** `lib/app/theme/app_theme.dart` defines only `AppTheme.lightTheme`. Missing `AppTheme.darkTheme`.
- **Navigation & Settings Location:** `lib/app/router/app_router.dart` uses `StatefulShellRoute.indexedStack` with 4 tabs: `/home`, `/requirements`, `/deals`, and `/profile`. The `/profile` route loads `BuyerProfileScreen` (`lib/features/profile/presentation/buyer_profile_screen.dart`), which is titled "Buyer Profile & Settings" but currently lacks application preferences.
- **Persistence:** `SecureStorageService` exists in `lib/core/security/secure_storage_service.dart` wrapping `FlutterSecureStorage` with in-memory fallback for testing.

### 2.2 RMSeller Mobile (`apps/rmseller_mobile`)
- **Root Entry Point:** `lib/app/app.dart` (`RMSellerApp` extends `ConsumerWidget`). Configures `theme: AppTheme.lightTheme`, `darkTheme: AppTheme.darkTheme`, but hardcodes `themeMode: ThemeMode.light`.
- **Color Tokens:** `lib/app/theme/app_colors.dart` defines light and dark tokens.
- **Theme Definition:** `lib/app/theme/app_theme.dart` provides both `lightTheme` and `darkTheme`.
- **Navigation & Settings Location:** `lib/app/router/app_router.dart` contains bottom navigation tabs (`/home`, `/commodities`, `/deals`, `/profile`). The `/profile` route loads `SellerProfileScreen` (`lib/features/profile/presentation/seller_profile_screen.dart`), titled "Seller Profile & Mandi Desk".
- **Persistence:** `SecureStorageService` exists in `lib/core/security/secure_storage_service.dart` wrapping `FlutterSecureStorage`.

### 2.3 RMBroker Mobile (`apps/rmbroker_mobile`)
- **Root Entry Point:** `lib/app/app.dart` (`RMBrokerApp` extends `ConsumerWidget`). Configures `theme: AppTheme.light`, `darkTheme: AppTheme.dark`, but hardcodes `themeMode: ThemeMode.light`.
- **Color Tokens:** `lib/app/theme/app_colors.dart` defines comprehensive primary and dark palette tokens.
- **Theme Definition:** `lib/app/theme/app_theme.dart` provides both `light` and `dark` ThemeData with typography integration.
- **Navigation & Settings Location:** `lib/app/router/app_router.dart` contains 5 tabs (`/dashboard`, `/work`, `/deals`, `/directory`, `/more`). The `/more` tab loads `MoreScreen` (`lib/features/more/presentation/more_screen.dart`). It has a placeholder tile for "Language / भाषा", but tapping it merely shows a snackbar.
- **Persistence:** `SecureStorageService` exists in `lib/core/security/secure_storage_service.dart` wrapping `FlutterSecureStorage`.

---

## 3. Localization Baseline & Honesty Statement

- **Framework:** `intl: ^0.20.3` is installed in all three applications and is actively utilized for number formatting and date formatting.
- **Translation Status:**
  - Full application localization files (`.arb` or generated message classes) are **not present**.
  - All apps natively display English UI strings.
  - Partial Hindi (`hi`) content exists in `AppConfig` (`fiduciaryNoticeHi`) and Mandi terminology across screens.
  - **Policy for this sprint:** We will support selecting `en` (English) and `hi` (Hindi) via `Locale('en')` and `Locale('hi')`. Disclaimers and bilingual cards will dynamically adapt to the selected locale. Per sprint instructions, we will **not** fabricate fake automated translations for untranslated enterprise screens, and will honestly document incomplete translation coverage in our reports.

---

## 4. Font Scaling Baseline & Architecture

- **Engine:** Flutter 3.47.6 introduces `TextScaler` replacing deprecated `textScaleFactor`.
- **Proposed Scaling Tiers:**
  1. **Small:** `0.85x` (Compact, high information density)
  2. **Default:** `1.0x` (Standard system scale)
  3. **Large:** `1.15x` (Enhanced readability)
  4. **Extra Large:** `1.30x` (Maximum accessible scaling without layout clipping)
- **Injection Point:** In each app's `MaterialApp.router`, wrap the root child using `builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(settings.fontScale)), child: child!)`. This ensures all screens, dialogs, bottom sheets, cards, and text fields scale proportionally without requiring fragile per-widget changes.

---

## 5. Implementation Strategy

1. **Preference State & Persistence Layer (`core/preferences`):**
   - Implement `AppSettingsModel` (theme mode, font scale, locale, high-contrast).
   - Implement `AppSettingsNotifier` backed by `flutter_secure_storage` with immediate in-memory state updates.
   - Keys: `pref_theme_mode`, `pref_font_scale`, `pref_locale`, `pref_high_contrast`.
2. **Root Application Integration (`app/app.dart`):**
   - RMBuyer: Add `AppTheme.darkTheme` to `app_theme.dart`.
   - In all three apps, bind `themeMode`, `locale`, and `TextScaler` to `appSettingsProvider`.
3. **Application Settings UI:**
   - Create a clean, accessible `AppSettingsSection` widget in each app's profile/settings view (`BuyerProfileScreen`, `SellerProfileScreen`, `MoreScreen`).
   - Include:
     - Theme selector: Light, Dark, System Default.
     - Language selector: English, हिन्दी.
     - Font Size selector: Small (0.85x), Default (1.0x), Large (1.15x), Extra Large (1.30x).
     - Accessibility toggle: Enhanced Contrast / Semantics.
4. **Verification & Tests:**
   - Unit and widget tests across all three applications.
   - Static analysis (`flutter analyze`) and automated validation.
