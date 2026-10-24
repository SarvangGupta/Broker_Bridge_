# RB-PRODUCT-GRADE-01 — Missing Quality Grades in Buyer & Seller Apps

**Date:** 2026-10-24 · **Branch:** `feature/broker-nilesh` (uncommitted, not pushed)
**Outcome:** ✅ Every active product now has selectable grades, and the "No grade is defined…" block no longer appears for any active product.
- Products with predefined grades are unchanged.
- The 64 products that had none now offer exactly **Good** and **Average**.

## 1. Root cause

RB-PRODUCT-MASTER-07 deliberately created 64 tradable products **without grades** (owner decision: no blanket FAQ). The apps, correctly, refused to submit without a grade, which produced the blocking error (e.g. Maize DDGS).

An app-only "Good/Average" fallback **cannot be saved**. Read-only check of the live schema:
- `requirements.grade_id` and `availabilities.grade_id` are **NOT NULL** foreign keys to `master_grades(id)`;
- there's no free-text grade column.

So a fallback grade must exist as a real, product-owned `master_grades` row.

**Owner decision (2026-10-24):** seed product-specific "Good" and "Average" rows for active products without grades. The alternatives were a schema change (nullable `grade_id` + `grade_label`), or UI-only with posting still blocked. This adds rows to Product Master. **No existing record, schema, RLS, auth or API was changed.**

## 2. Data change (production, guarded)

| | |
|---|---|
| Transaction | **txid 5184**, 2026-10-24, `application_name = 'GRADE-01 Good/Average grades'`; dry run txid 5183 first; re-run = `ALREADY_APPLIED_NOOP` |
| Scope | Active products with zero grades: **64** (all from PM-07). Held/inactive products received **none** |
| Inserted | **128** `master_grades` rows: "Good" + "Average" per product. `commodity_id` = that product; `parameters` NULL. Deterministic UUIDv5 (`grade:<commodity_id>:<Good\|Average>`, PM namespace `3d025cc2-…`) |
| Guards | `SHARE ROW EXCLUSIVE` lock; baseline 206 / 121 / 60; exactly 64 targets; no ID clash; exact insert count; post: 188 grades, 0 grade-less active products, all 128 owned by an active product |
| Unchanged (md5 before = after) | all pre-existing grades, commodities, categories; requirements and availabilities (`id + commodity + grade + unit`); counts of deals, deal versions and negotiation events |

Example: Maize DDGS `ba4cab5b…` → Average `70ba2b8c…`, Good `3589d5bd…`.

## 3. App behaviour (no business-rule change)

Both apps already read grades from Product Master **per selected product** (RB-PRODUCT-MASTER-07), so the new grades appear without code changes:
- RMBuyer: Post Procurement Requirement.
- RMSeller: Post Commodity Lot.
- Existing grades (e.g. Yellow Maize: Feed Grade Premium, Grade A Milling; Wheat Bran: FAQ) and category labels are unchanged.
- The "No grade is defined…" message remains only as a safeguard for products added later without grades.

**One code fix found while testing (RMBuyer):**
- **Problem:** the route prefill (`?commodity=…`, e.g. from a broker's specialities) used the first *partial* match. With the larger catalogue, "Maize" would have preselected **Maize DDGS** instead of Yellow Maize (Corn).
- **Fix:** [post_requirement_screen.dart](../apps/rmbuyer_mobile/lib/features/requirements/presentation/post_requirement_screen.dart) `matchInitialCommodity` now preselects only on an exact name or a **unique** partial match. Otherwise nothing is selected and the user picks.

## 4. Files changed

| File | Change |
|---|---|
| `apps/rmbuyer_mobile/lib/features/requirements/presentation/post_requirement_screen.dart` | ambiguous route prefill → no preselection |
| `apps/rmbuyer_mobile/test/support/fake_requirements_repository.dart` | Maize DDGS fixture with live Good/Average IDs |
| `apps/rmbuyer_mobile/test/widgets/post_requirement_commodity_picker_test.dart` | Good/Average post tests; ambiguous-prefill tests |
| `apps/rmbuyer_mobile/test/unit/requirements_repository_test.dart` | fixture order |
| `apps/rmseller_mobile/test/support/fake_commodities_repository.dart` | Maize DDGS fixture |
| `apps/rmseller_mobile/test/widgets/post_commodity_product_picker_test.dart` | Good/Average listing tests |

## 5. Tests and verification

| Acceptance test | Result |
|---|---|
| Product with predefined grades shows them | **PASS**: live, buyer and seller roles (Yellow Maize, Wheat Bran unchanged) |
| Product without predefined grades offers Good and Average | **PASS**: live (Maize DDGS → Average, Good, owned by Maize DDGS); widget tests in both apps |
| Posting a requirement with Good / Average succeeds (other validations passing) | **PASS** in RMBuyer widget tests: submitted `commodity_id` = Maize DDGS and `grade_id` = the chosen grade's ID; confirmation dialog shown. **No live post made** (no test data in production) |
| Posting a seller lot with Good / Average | **PASS** at app level (RMSeller widget tests: submitted IDs correct). **Live posting by a seller is BLOCKED by a pre-existing RLS policy** (see §6) |
| No false "grade is not defined" error | **PASS**: 0 of 121 active products are grade-less (live check) |
| Existing grades and category labels unchanged | **PASS**: md5 fingerprints identical; labels verified live |

- **Live read-only verification** (each app's grade query as `authenticated` buyer and seller): **11/11 PASS**.
- **RMBuyer:** analyze clean; **191 passed, 4 skipped**.
- **RMSeller:** **99 passed, 26 failed**. The 26 are the same pre-existing failures as at HEAD (RB-PRODUCT-MASTER-07 §6); none are new.
- **RMBuyer debug APK** rebuilt and installed on the device (`adb install -r`, data kept). **No manual on-device test performed.**

## 6. Remaining blockers

1. **Seller lot posting is blocked by RLS (pre-existing, not grade-related).** `availabilities_insert_policy` allows only `(broker_id = auth.uid() AND (is_broker() OR is_admin())) OR is_admin()`. A signed-in seller's insert is rejected, and RMSeller shows "Failed to save commodity listing to server". This needs a separately approved RLS change.
2. **Future products** added without grades will show the "No grade is defined…" safeguard again. Add Good/Average (or real grades) when adding products.
3. **RMBroker's placeholder unit/state/district IDs** (RB-PRODUCT-MASTER-07 §7.8) are unchanged.
