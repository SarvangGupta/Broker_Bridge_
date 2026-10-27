# RB-SELLER-AVAILABILITY-RLS-FIX-01 — Test Report

## 1. Automated tests (run)
`flutter test` on these suites: `commodities_repository_test`, `post_commodity_screen_test`, `post_commodity_quantity_price_test`, `post_commodity_product_picker_test`, `post_commodity_ux04_test`, `commodity_details_screen_test`, `lot_location_sheet_test`, `lot_location_test`. Result: **All tests passed (74)**.

New or changed coverage:

| Check (§7) | Test | Result |
|---|---|---|
| 7: RLS rejection shows a clear message, no success | `post_commodity_screen_test`: *an RLS rejection shows a clear message and keeps the form* (no raw "42501" shown; quantity "25" still in the form) | PASS |
| 7: unexpected errors are friendly | `post_commodity_quantity_price_test`: shows "Unable to publish your commodity…", raw text absent | PASS |
| 7: no session means refused; nothing cached as listed | `commodities_repository_test`: *with a backend but no session…* | PASS |
| 8: duplicate submission | existing in-flight lock (`_isSubmissionLocked`) and screen guard, unchanged | covered by existing code |
| 6: fields, location, lab and broker intact | full Post Commodity suites | PASS |

**Static analysis:** `flutter analyze` on the changed areas found 0 errors. Two warnings are pre-existing: `_labReportType`, and an unused import in `seller_profile_menu_test`.

**Build:** `flutter build apk --debug` built. Not installed on the device.

## 2. Live database inspection (read-only, run)
The `BEGIN READ ONLY … ROLLBACK` script confirmed the deployed policies (see the audit report §2). Nothing was written.

## 3. Not run: requires approval of `0044`
§7 checks 1–5 and 9 need the policy applied. **Proposed verification plan** for after approval, on staging first, each step in a transaction that rolls back:

1. As seller S (company C): insert a lot with `company_id = C` → **succeeds**, and RETURNING gives the ID.
2. As S: insert with `company_id = D` (another company) → **42501**.
3. As S: select own `restricted` lot → visible. Select D's restricted lot → not visible.
4. As S: update own lot price → 1 row. Update D's lot → 0 rows. Set own lot's `company_id = D` → rejected.
5. As S: `UPDATE users SET company_id = D WHERE id = auth.uid()` → **rejected** by the part D trigger.
6. As a buyer or anon: insert → rejected. As a broker: insert with `broker_id = self` → succeeds (unchanged).
7. As admin: unchanged.
8. App on device: post a lot → success screen. Home and details show it; a price update persists.

## 4. Migration 0044 applied (after owner approval, 2026-10-27)
- **Scope:** the recommended A + B + C + D set, exactly as in `RB-SELLER-AVAILABILITY-RLS-FIX-01-PROPOSED-SQL.md`.
- **Target:** project `imztlkvkxzeaekxvmcfe`, the only configured database.
- **Script:** `scripts/apply-migration-0044.mjs`, one transaction, following the repo's script-based workflow (there is no migration ledger).
- **Dry run first** (`--dry-run`, always rolls back): 10/10 PASS, database unchanged.
- **Real run:** the same checks passed **10/10 before COMMIT**. They impersonated real roles with `SET LOCAL ROLE` and JWT claims, and the synthetic rows lived in a savepoint that was rolled back:

| # | Check | Result |
|---|---|---|
| 1 | seller inserts own-company restricted lot with RETURNING | PASS |
| 2 | seller insert for another company | PASS (42501) |
| 3 | seller sees own restricted lot, not another company's | PASS |
| 4 | seller updates own lot (1 row), not another company's (0 rows) | PASS |
| 5 | seller moves own lot to another company | PASS (42501) |
| 6 | seller changes own `users.company_id` | PASS (42501, trigger) |
| 7 | buyer insert | PASS (42501) |
| 8 | broker insert with `broker_id = self` | PASS (still allowed) |
| 9 | anon insert / select | PASS (42501 / 42501) |
| 10 | exactly 3 `availabilities` policies + guard trigger | PASS |

- **Independent post-commit check** (new read-only connection):
  - The three policies contain the seller branch exactly as approved.
  - `trg_prevent_self_company_change` is present.
  - `availabilities` still has **3 rows**, so no synthetic data persisted.
- **Files:** `0044_allow_sellers_own_availabilities.sql` and `rollback_0044.sql` moved from `supabase/proposed/` to `supabase/migrations/`, with the header marked APPLIED.
- **App:** the latest debug build is installed on the device (Redmi Note 5 Pro).

## 5. Pending: one real listing from the device
The owner posts one lot from the app. Expected results:
- the success screen
- the lot on Home and in its details (no demo lots once a real lot exists)
- a price update that persists

## Status: **PASS WITH LIMITATIONS**
- Database fix applied and verified (10/10 on live, plus an independent check). App-side fixes tested (74/74).
- **Limitation:** end-to-end posting from the device was not yet observed when this report was written (§5).
- Rollback is available: `supabase/migrations/rollback_0044.sql`.
