# RMBUYER-PROFILE-LANGUAGE-01 — Report

Date: 2026-10-25 · Branch: `feature/broker-nilesh` · **Status: PASS WITH LIMITATIONS** · Uncommitted

## 1. What was found

- **No localization existed.** There was no `flutter_localizations` and there were no delegates. The settings screen offered English/Hindi, but `MaterialApp` had no supported locales, so choosing Hindi changed nothing outside a few hardcoded `if hindi` labels in one widget.
- **The profile screen invented data.** Its fallbacks included a made-up name, email, company, GSTIN and "Commodity Processor & Manufacturer", plus a hardcoded **"GST VERIFIED"** badge and **"Trust Score 98 / 100"** regardless of the real record. Nothing was editable.
- **The top-right profile icon only switched to the Profile tab**, which showed that static screen.
- **No Help & Support screen exists** in the Buyer app, so there was nothing to localize there.

## 2. Backend contract (live, read-only)

| Data | Buyer can write? | Decision |
|---|---|---|
| `users.name` | Yes: own row (`users_update_policy`: `id = auth.uid()`, role must equal `get_auth_role()`) | **Editable** |
| `users.mobile` | Yes, same policy (RMSeller already writes it) | **Editable**, validated as an Indian mobile number and stored as `+91XXXXXXXXXX` |
| `users.email` | Policy allows it | **Read-only**: it is the Supabase sign-in identity, and changing only `public.users` would desync auth |
| `users.role` / `status` / `company_id` | Policy allows some of these | **Read-only**, never sent |
| `companies.*` (name, gst, is_verified, trust_score…) | **Policy allows the buyer to update their own company, including `is_verified` and `trust_score`** | **Read-only.** Never written by the app. See §7 for the security finding |

**Enforcement in code:** `BuyerProfileRepository.editableColumns = {name, mobile}` drops every other key before the request is built (unit-tested). The update uses `.select().single()`, so a write that RLS silently matches to 0 rows raises an error instead of a false success.

## 3. Changes

### Profile & Settings

- **Top-right icon:** now pushes `/settings` (back returns home). The Profile tab shows the same hub.
- **`ProfileSettingsScreen` (new):** a profile summary loaded from the backend, with a load error and retry, plus:
  - **Edit Profile** → `/settings/profile`
  - **Language** → `/settings/language`; shows the current language
  - **Display & Accessibility** → `/settings/display`: the existing theme, text-size and high-contrast controls, which already worked end to end
  - **Sign Out**: the existing flow, localized
  - No placeholder destinations.
- **`BuyerProfileScreen` (rewritten as Edit Profile):**
  - Sections: Personal (name and mobile editable, email read-only), Company (name, GSTIN, verification, all read-only from the real record) and Account (role).
  - **Missing values show "Not provided".**
  - **Field validation:** name 2–80 characters; mobile is a valid Indian number or empty.
  - **Saving:** sends only changed fields; Save is disabled and shows a spinner while saving, so a double tap can't submit twice; success shows a snackbar.
  - **Failure:** shows an error banner and keeps the typed values.
  - **Leaving:** a discard dialog appears when there are unsaved changes.
  - **Load failure:** shows retry, never placeholder data.
- **`DisplaySettingsScreen` (new):** hosts `AppSettingsSection`. The language chips moved out of that widget.

### Localization

- **Wiring:** added `flutter_localizations` (SDK; it was already a transitive dependency). `MaterialApp` now sets `supportedLocales` and the `AppLocalizations`, Material, Widgets and Cupertino delegates.
- **Translation table:** `lib/l10n/app_localizations.dart` (typed `Tr` keys, a `context.tr()` helper, and a synchronous delegate) and `lib/l10n/translations.dart`, with **99 keys × 7 languages**.
- **Languages:** English, Hindi (हिन्दी), Punjabi (ਪੰਜਾਬੀ), Tamil (தமிழ்), Telugu (తెలుగు), Kannada (ಕನ್ನಡ) and Malayalam (മലയാളം). Each is shown in its own script with the English name beside it.
- **Persistence:** uses the existing `rb_pref_language` preference in `SecureStorageService`, via the existing `AppSettingsNotifier`. The language applies immediately and is restored at launch.
- **Business data unchanged:** product and company names, prices, quantities, codes, notification titles and messages from the server, and user-entered text are never translated. `GSTIN` and `RMBuyer` stay in Latin script.

### Localized surfaces (100% of in-scope strings, all 7 languages)

- Bottom navigation (5 labels).
- **AppBar titles of every Buyer screen:** Requirements, Post Requirement, Deals, Final Deal Review, Offers, Proposal Details, Broker Profile, Search, Notifications, Nutrition Guide, plus the 4 new settings screens.
- Home header: subtitle, search hint, notification tooltip.
- Profile & Settings, Edit Profile (all labels, validation, save, error and discard dialogs), Language, Display & Accessibility, and the Sign-out dialog.
- Notifications: loading, error, empty title and empty body.
- Shared `AppErrorState` defaults ("Unable to Load Data" / "Try Again").

## 4. Localization coverage — honest status

| Language | In-scope keys | Script check | Native-speaker review |
|---|---|---|---|
| English | 99/99 | n/a | n/a |
| Hindi | 99/99 | Devanagari ✓ | **not done** |
| Punjabi | 99/99 | Gurmukhi ✓ | **not done** |
| Tamil | 99/99 | Tamil ✓ | **not done** |
| Telugu | 99/99 | Telugu ✓ | **not done** |
| Kannada | 99/99 | Kannada ✓ | **not done** |
| Malayalam | 99/99 | Malayalam ✓ | **not done** |

- **Review:** I wrote the translations during this sprint. They are complete and in the correct script (tests enforce both), but **none has been reviewed by a native speaker**, so no language is claimed as production-quality.
- **Screens still in English:** I did not localize the body text of these screens. They show English in every language, and the Language screen says so to the user ("Some screens are still in English"). A single-line scan found these English literals; multi-line strings make the real total higher.
  - Proposal Details: 27
  - Post Requirement form: 20
  - Final Deal Review: 18
  - Requirement Details: 18
  - Requirements list: 12
  - Home dashboard: 11
  - Nutrition Guide and details sheet: 8
  - Search and Broker profile: about 10
  - Login, Splash and Access Denied: 6
  - Commodity picker: 1
- **Dates:** notification dates still use English month names (`DateFormat` without a locale).

## 5. Verification

| Check | Result |
|---|---|
| `dart format` | Applied to new and rewritten files only (package-wide formatting is not the repo convention) |
| `flutter analyze` (whole package) | **No issues** |
| **Full RMBuyer suite** (`test/widget_test.dart`, `test/widgets`, `test/unit`, i.e. every test file) | **244 passed, 4 skipped** (opt-in live tests), 0 failed |

**New and updated tests:**
- `l10n_coverage_test`: the 7 languages; every key present in every language; correct Unicode script per language; Latin identifiers consistent; Flutter Material/Cupertino support for each locale; English fallback; restoring from stored values.
- `buyer_profile_test`: name and mobile rules; **only name/mobile can be written** (email, role, status, company_id, gst, is_verified are dropped); row mapping that invents nothing.
- `profile_screen_test` (8):
  - backend values load, and only 2 editable fields exist;
  - "Not provided" placeholders appear; the fake GST badge and trust score are gone;
  - invalid input is rejected with no request sent;
  - only changed fields are sent, **and they persist on reopen**;
  - no changes means no request;
  - a failed save shows an error, keeps the input and shows no success;
  - a double tap sends one request;
  - a load failure shows retry.
- `settings_language_test` (real `RMBuyerApp` and router):
  - the top-right icon opens the hub and back returns home;
  - every menu item opens its screen;
  - **Tamil applies immediately** (AppBar, confirmation, bottom nav) and is written to storage;
  - **after an app restart** (the whole app unmounted and a fresh ProviderScope mounted), Tamil is restored;
  - Hindi, Punjabi, Telugu, Kannada and Malayalam render the hub and navigation without layout exceptions.
- `app_settings_test` and `navigation_shell_test`: updated for the moved language controls and the new hub title.

**Defect found and fixed:** the smoke test failed because the first frame was held back by an async localization load. The fix was a synchronous delegate.

**Not verified:**
- **Live backend save.** No production write was performed, per sprint rules. Persistence is proven against the repository contract and the policy text, not an end-to-end save.
- **Restart on a real device.** The restart test uses the storage service's in-memory test mode, not the Android keystore.
- **Real Indic fonts on the device.** Tests use the Ahem test font.

## 6. Files

**New:**
- `lib/l10n/app_localizations.dart`, `lib/l10n/translations.dart`
- `lib/features/profile/domain/buyer_profile.dart`, `lib/features/profile/data/buyer_profile_repository.dart`
- `lib/features/profile/presentation/{profile_settings_screen, language_settings_screen, display_settings_screen}.dart`
- `test/unit/{l10n_coverage_test, buyer_profile_test}.dart`, `test/widgets/settings_language_test.dart`, `test/support/fake_buyer_profile_repository.dart`

**Modified:**
- `pubspec.yaml`, `pubspec.lock` (`flutter_localizations` changed from transitive to direct)
- `lib/app/app.dart`, `lib/app/router/app_router.dart`
- `lib/core/preferences/app_settings_provider.dart`, `lib/core/security/secure_storage_service.dart` (`saveUserName`), `lib/core/widgets/app_error_state.dart`
- `lib/features/profile/presentation/{buyer_profile_screen, widgets/app_settings_section}.dart`
- `lib/features/home/presentation/{home_screen, navigation_shell}.dart`, `lib/features/notifications/presentation/buyer_notifications_screen.dart`
- AppBar title only: `deals/…/{buyer_deals_screen, final_deal_review_screen}`, `offers/…/{buyer_offers_screen, offer_details_screen}`, `requirements/…/{post_requirement_screen, requirements_screen}`, `search/…/{broker_profile_screen, buyer_search_screen}`, `nutrition/…/nutrition_guide_screen`
- `test/widgets/{profile_screen_test, app_settings_test, navigation_shell_test}.dart`

**Unchanged:** RMSeller and RMBroker (no changes this sprint), schema, migrations, RLS, auth and live data.

**Incident during the sprint:** a faulty bulk-replace script corrupted 9 screen files. Those files had no prior uncommitted changes, and all 9 were restored from HEAD before the edit was redone safely. The final diff for those files is the title change plus one import each, verified by `git diff --stat`.

## 7. Limitations and dependencies

1. **Security finding, not fixed (needs approval):** `companies` policy "Users can update their own company" lets any user change their own company's `gst`, `is_verified` and `trust_score` through the API. That means a buyer could mark themselves verified. The app never does this, but the boundary allows it. This should join the RB-SEC-PRIV-01 remediation list.
2. **Translation review:** native-speaker review is needed for 6 languages before claiming full support.
3. **Body text of transactional screens:** these remain English (§4); they need follow-up sprints.
4. **Email and company details:** changes need a verified process (auth email change, KYC); there is no existing API for them.
5. **No Help & Support screen** exists in the Buyer app.
6. **Mobile number verification:** there is no OTP verification flow, so the mobile number is saved as entered (format-validated).
