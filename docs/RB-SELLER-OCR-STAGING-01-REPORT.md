# RB-SELLER-OCR-STAGING-01 — Staging Readiness, Migration 0052 Validation, Seller Profile E2E

**Date:** 2026-10-28 · **App:** RMSeller · **Branch:** `feature/broker-nilesh` (uncommitted)

**Production statement:** no production schema or data was changed. No production credentials or personal data were copied. The `harishanker` account was not used. Migration 0052 was not applied anywhere except in-memory test databases.

| Phase | Result |
|---|---|
| 1. Staging readiness | ⛔ **No staging project exists.** Creating one needs your Supabase account. Exact steps are below. A local staging-equivalent was built instead. |
| 2. Migration 0052 validation | ✅ 13/13 on the local staging-equivalent (full repo schema + RLS). Not applied to any real database. |
| 3. Seller profile E2E | ✅ Offline app-level save/reopen/cancel/failure, 4/4. ⛔ Server-side save/reopen is blocked (needs a real staging project). |
| 4. Android device | ⛔ ADB input is still disabled on the device. No screenshots were taken. |

## Phase 1 — Staging readiness

### Findings

- **Only one project:** `imztlkvkxzeaekxvmcfe`, used by all apps and by `.env` / `.env.local`. Repo documents call it production. There is no staging URL, branch configuration, `supabase/config.toml`, or CI workflow.
- **Pointing the app elsewhere:** the mobile apps read `SUPABASE_URL` / `SUPABASE_ANON_KEY` via `--dart-define`, so a staging build needs no code change.
- **Previous attempts:** the same blocker was recorded in `apps/rmseller_mobile/RB-SELLER-AVAILABILITY-RLS-FIX-02-STAGING-REPORT.md`.

### New finding: repo migrations do not reproduce production

A clean replay of `supabase/migrations` (0001–0044 + seeds + manual RLS) fails in 0038, 0039 and 0044 with 12 statements, all `column "broker_id" does not exist`.

Production has **`requirements.broker_id`** and **`availabilities.broker_id`**, but no migration in the repo creates them. A staging project built only from repo migrations would therefore not match production.

The replay tool applies an explicit, logged drift patch (`ADD COLUMN IF NOT EXISTS broker_id uuid` on both tables) before 0038. After the patch, drift = 0.

### Steps to create a real staging project (needs your action and approval)

1. **Create the project.** In the Supabase dashboard (your account), create a **new project** (e.g. `brokerbridge-staging`), preferably in the same region. *Cost:* the free plan allows a limited number of free projects; on a paid organisation an extra project may add compute charges. Check the billing page before creating it. I have not created anything.
2. **Load the schema, with no data.** Choose one:
   - **Recommended:** `supabase db dump --schema-only` from production, restored into staging. This captures drift like `broker_id`. It needs the production DB password, used by you or with your explicit approval.
   - **Alternative:** replay `supabase/migrations` 0001–0044 + `seed_states_rajasthan_districts.sql` + the drift patch + `manual_*.sql`. The order is encoded in `supabase/proposed/0052_tools/staging_replay.mjs`.
3. **Add synthetic reference data only:** the states seed and the master rows from `seed_broker_demo_dataset.sql`. Do not copy users, companies, profiles or bank details.
4. **Create a test seller.** In staging Auth, create a dedicated seller with a synthetic email (e.g. `seller.staging@example.test`), then provision it with `supabase/proposed/provision_individual_seller_identity.sql`.
5. **Apply 0052 to staging only:** `supabase/proposed/0052_seed_national_districts.sql`. Check the target project ref first.
6. **Build the app against staging:** `flutter build apk --debug --dart-define=SUPABASE_URL=https://<staging-ref>.supabase.co --dart-define=SUPABASE_ANON_KEY=<staging anon key>`.
7. **On the phone:** enable *Developer options → USB debugging (Security settings)* (see Phase 4), then run the device flow.

## Phase 2 — Migration 0052 validation (local staging-equivalent)

**Environment:**
- **Database:** PGlite 0.2.17, in-memory Postgres, no network, no production connection.
- **Platform stubs:** Supabase objects stubbed (`anon` / `authenticated` / `service_role` roles, `auth.uid()` / `auth.users`, `storage.*`, `supabase_realtime`).
- **Schema:** the full applied migration history plus the drift patch; the RLS policies are the real ones.
- **Reference data:** the synthetic demo seed, which reproduces the live duplicate Rajasthan / Madhya Pradesh state rows.
- **Baseline shape:** 38 states / 54 districts, matching live.

**Result: 13 passed, 0 failed** (`supabase/proposed/0052_tools/staging_replay_result.txt`).

| Check | Result |
|---|---|
| master_states / master_districts RLS from 0038 present | PASS |
| Baseline mirrors live (38 states / 54 districts) | PASS |
| 0052 inserts exactly 703 districts (54 → 757) | PASS |
| Pre-existing districts unchanged | PASS |
| Re-run is a no-op | PASS |
| No duplicate district within a state | PASS |
| Alias: no "Ganganagar" next to "Sri Ganganagar" | PASS |
| All 737 districts the app derives from a PIN exist in the master | PASS |
| Representative district for every one of 36 states/UTs | PASS |
| `authenticated` role reads all 757 districts under RLS | PASS |
| Rollback refuses (FK) while a new district is referenced | PASS |
| Rollback restores the exact pre-0052 master | PASS |
| Rollback is idempotent | PASS |

## Phase 3 — Seller profile E2E

### Offline app-level E2E (executed)

New file: `test/widgets/seller_profile_address_e2e_test.dart`, **4/4 passed**.

- **Setup:** the real `SellerProfileScreen` and confirmation sheet, with the app's `SellerProfileRepository` running **without** a Supabase client (local secure-storage persistence, no network). The master is shaped like staging after 0052.
- **Coverage:** OCR text → apply suggestions → confirmation sheet → save → a **fresh screen instance reopens** from storage, with the view-mode sections expanded.

| Test | Verified |
|---|---|
| English invoice with PIN 302019 | Persisted: name / business / location name = BINA ENTERPRISES; GSTIN; mobile 8094689777; login email unchanged; HQ = street = full address; PIN 302019; Rajasthan / Jaipur (`districtId` from the master). Reopened profile map is identical to the saved one; values are shown in view mode. |
| Hindi invoice with UP PIN 212201 | Persisted `मे० सियाराम ट्रेडिंग कम्पनी`, the Devanagari address unchanged, Uttar Pradesh / Kaushambi. Shown after reopen. |
| Cancel on confirmation | Stored profile byte-identical. |
| Server rejects save | Stored profile unchanged; still in edit mode, with no success shown. |

**UI defect found and fixed:** the confirmation sheet's "N field(s) modified / Current vs Proposed" banner overflowed by 5.8 px, clipping text. Both labels are now `Flexible` and wrap (`profile_review_confirmation_sheet.dart`).

### Server-side save/reopen: BLOCKED

This needs the real staging project (Phase 1, steps 1–6). PGlite has no Auth or PostgREST layer, so the app cannot log in or save to it.

### Regression

Full RMSeller `test/unit` + `test/widgets` (`test/realdb` excluded):

| Run | Passed | Failed |
|---|---|---|
| This branch | **483** | **16** |
| HEAD | 399 | 16 |

The 16 failures are identical to HEAD's pre-existing set, so there are **0 new regressions**. `flutter analyze`: no issues.

## Phase 4 — Android device: BLOCKED

| Item | Evidence |
|---|---|
| Device | `e0d9da95`, Redmi Note 5 Pro, MIUI V11, authorised (`adb devices`). |
| ADB input | **Disabled:** `persist.security.adbinput = 0`. Earlier sessions confirmed every `input tap` is silently ignored. Only the phone's owner can enable *Developer options → USB debugging (Security settings)*. That needs a Mi account and SIM on the device; it can't be set over ADB without root. |
| Device state at check | Idle for about 125 s, on the MIUI launcher. No test tap was sent, to avoid launching anything on the home screen. |
| Screenshots | None captured. No UI state was reached by automation. |
| Debug APK | Builds (previous sprint). It would need rebuilding with `--dart-define` pointing at staging once that exists. |

## Files

| Change | File |
|---|---|
| Added | `supabase/proposed/0052_tools/staging_replay.mjs` (replay + drift patch + 0052 validation) |
| Added | `supabase/proposed/0052_tools/staging_replay_result.txt` |
| Added | `apps/rmseller_mobile/test/widgets/seller_profile_address_e2e_test.dart` |
| Changed | `apps/rmseller_mobile/lib/features/profile/presentation/widgets/profile_review_confirmation_sheet.dart` (overflow fix) |

## Decisions needed

1. Create the staging Supabase project (cost implications to be checked by you), and choose the schema source: a schema-only dump of production (recommended) or a repo replay plus drift patch.
2. Record the `broker_id` drift as a proper repo migration so the repo matches production.
3. Enable ADB input on the phone (*USB debugging (Security settings)*).
4. After staging validation, decide separately whether to apply 0052 to production.
