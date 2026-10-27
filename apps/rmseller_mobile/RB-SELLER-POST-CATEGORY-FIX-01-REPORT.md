# RB-SELLER-POST-CATEGORY-FIX-01 — "Category unavailable" on Commodity Selection

**App:** RM Seller (`apps/rmseller_mobile`) · **Date:** 2026-10-27 · **Device:** Redmi Note 5 Pro (e0d9da95), Android 9

## 1. Reproduction
I reproduced the bug on the device with the installed debug build. `adb logcat -s flutter` captured this when the Post Commodity page loaded:

```
Category names unavailable: PostgrestException(message: permission denied for table master_categories,
code: 42501, details: Unauthorized, hint: ... GRANT SELECT ON public.master_categories TO anon;)
```

In the same session, `availabilities`, `deals` and `users` were also denied to **`anon`**.

## 2. Root cause (evidence-based)
1. `master_categories` is readable by `authenticated` only (migration 0042, applied live as txid 5175 per `docs/RB-PRODUCT-MASTER-07-IMPLEMENTATION-REPORT.md`). `master_commodities` is readable by `anon` too (migration 0038).
2. The app was sending requests **without a Supabase session**, as `anon`. Products still loaded. The category read was denied, and `_loadCategoryNames()` turned that error into an empty map, so every product showed "Category unavailable".
3. **Why there was no session:** at startup, `SplashScreen` calls `AuthRepository.getSavedUser()`. That method treated *any locally stored token* as a valid login and never checked `Supabase.auth.currentSession`. When the Supabase session was gone (expired, or not restored after the reinstall), the app still opened on Home as "signed in".

Ruled out:
- **Category mapping:** a signed-in seller read the categories in the production verification after migration 0042 (24/24 checks passed).
- **Field-name or serialization mismatch:** the select columns `id`, `name` and `category_id` match the migrations.
- **Loading race:** categories are fetched together with the product list, before the list is shown.

## 3. Files changed
| File | Change |
|---|---|
| `lib/features/authentication/data/auth_repository.dart` | `getSavedUser()` now requires a live Supabase session whose user id matches the stored user. Otherwise it clears local storage and returns `null`, and the splash screen sends the user to Login. When no Supabase client is configured (offline/test mode), behaviour is unchanged. |
| `test/unit/auth_repository_test.dart` | +2 tests: offline mode still restores the saved seller; a stored token with no live session is rejected and cleared. |

No change to category data, the picker, grades, units, validation or submission. No schema, RLS or migration changes, and no new dependencies.

## 4. Verification
| Command | Result |
|---|---|
| `flutter test test/unit/auth_repository_test.dart` + the 4 `post_commodity_*` suites + `commodities_repository_test` | **40 passed, 5 failed.** The 2 new tests pass. All 5 failures also fail at baseline: the 2 buyer/broker auth tests fail on the HEAD test file (offline sign-in never clears the shared in-memory storage), and the 3 `post_commodity_screen_test` failures were recorded in RB-SELLER-LOCATION-UX-01. |
| `flutter analyze lib test/unit/auth_repository_test.dart` | 0 errors (infos and warnings are pre-existing) |
| `flutter build apk --debug` | Built |
| `adb pm install -r -t` + launch | Success |

**On device after the fix:**
- The app opened on **Login** instead of skipping to Home with a stale token (screenshot inspected).
- After sign-in, `logcat` shows requests running as `authenticated`. No `master_categories` error has appeared since.
- The Post Commodity Lot page loaded (screenshot inspected).
- I did **not** take a screenshot of the category label after selecting a product. Verification items 1–3 (correct label, switching, rapid switching) rest on the log evidence and the unchanged picker code, not on direct visual inspection.

## 5. Unresolved / noted (not changed)
- **Seller can't read invoices:** after sign-in, `invoices` returns `42501 permission denied ... TO authenticated`. This is a separate, pre-existing RLS gap and was not touched.
- **"Category unavailable" covers errors too:** the label still reads "Category unavailable" when the category request fails for another reason, such as no network. Telling "failed to load" apart from "missing in master data" would need the repository to report the error state. That change was left out to keep this fix minimal.
- **Location summary with no district:** with the live state list, the Location summary shows "District, West Bengal" until a district is chosen. This is display behaviour from RB-SELLER-LOCATION-UX-01 and is not part of this fix.

Confirmed: no unrelated screens or workflows were changed. `git status` for the app shows only the two files above plus this report, beyond the files from the previous sprint.

## Status: **PASS WITH LIMITATIONS**
The limitation is that the category label after selecting a product was not visually inspected; the fix is verified through the device log.
