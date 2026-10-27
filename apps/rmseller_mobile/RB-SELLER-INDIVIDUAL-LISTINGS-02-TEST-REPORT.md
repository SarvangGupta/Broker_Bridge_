# RB-SELLER-INDIVIDUAL-LISTINGS-02 — Test Report

## 1. Overview
This test report summarizes the verification of **RB-SELLER-INDIVIDUAL-LISTINGS-02**, covering unit test suites, static code analysis, debug APK compilation, and live PostgreSQL validation under a transaction rollback.

---

## 2. Unit Test Results

### 2.1 Focused Individual Seller Suite (`individual_seller_listings_test.dart`)
**File:** [individual_seller_listings_test.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/test/unit/individual_seller_listings_test.dart)
**Command:** `flutter test test/unit/individual_seller_listings_test.dart`
**Status:** **19 Passed / 0 Failed** (100% pass)

| Test Group | Test Case | Status | Verified Behavior |
|---|---|---|---|
| **Trusted Identity & Profile Readiness** | Company seller readiness complete | PASS | Carries firm name and regional IDs |
| | Individual seller readiness complete | PASS | Uses seller name without requiring firm |
| | Unprovisioned user rejected | PASS | Rejects missing `public.users` record |
| | Self-asserted role rejected | PASS | Untrusted metadata rejected |
| **Ownership Invariant** | Neither ownership ID rejected | PASS | `toSupabaseInsert` throws `ArgumentError` |
| | Both ownership IDs rejected | PASS | `toSupabaseInsert` throws `ArgumentError` |
| | Individual seller lot creation | PASS | Sets `seller_user_id`, `company_id = null` |
| | Company seller lot creation | PASS | Sets `company_id`, `seller_user_id = null` |
| **Isolation & Cross-Seller Access** | Individual seller reads only own lots | PASS | Never sees other sellers or foreign companies |
| | Cross-seller price update rejected | PASS | Throws `PriceUpdateException` |
| | Individual cannot edit company lot | PASS | Throws `PriceUpdateException` |
| | Company cannot edit individual lot | PASS | Throws `PriceUpdateException` |
| **Lifecycle Operations** | Price update with server confirmation | PASS | Returns confirmed price, updates cache |
| | Fulfilled and Cancelled (Withdraw) | PASS | Server confirmed status transitions |
| | Active broker assignment & change | PASS | Assigns and clears active broker |
| | Unregistered broker ID rejected | PASS | Rejects invalid broker UUID before write |
| **Duplicate & Network Resiliency** | Duplicate lot number (23505) | PASS | Returns clear friendly error message |
| | Network retry preserves cache integrity | PASS | Failed insert does not corrupt cache |
| | Empty list distinct from 500 error | PASS | Network 500 throws `CommodityListException` |

### 2.2 Profile Readiness Suite (`listing_readiness_test.dart`)
**File:** [listing_readiness_test.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/test/unit/listing_readiness_test.dart)
**Status:** **7 Passed / 0 Failed** (100% pass)
- Verified individual seller readiness without firm.
- Verified unprovisioned user handling.
- Verified unauthorized role handling.
- Verified company firm missing / unverified handling.

### 2.3 End-to-End Seller Lot Lifecycle (`seller_lot_e2e_test.dart`)
**File:** [seller_lot_e2e_test.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/test/unit/seller_lot_e2e_test.dart)
**Status:** **14 Passed / 0 Failed** (100% pass)
- Verified full post → price → broker lifecycle with PostgREST RETURNING confirmation.
- Verified individual seller without company successfully posts, lists, and isolates from foreign company lots.
- Verified unprovisioned seller receives empty list on read and clear error on update.

### 2.4 Integrity & Uniqueness (`seller_lot_integrity_test.dart`)
**File:** [seller_lot_integrity_test.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/test/unit/seller_lot_integrity_test.dart)
**Status:** **11 Passed / 0 Failed** (100% pass)
- Verified Fulfilled and Cancelled state updates.
- Verified 23505 duplicate lot rejection on retry.
- Verified listing date window rules.

### 2.5 Full Unit Test Suite Summary
**Command:** `flutter test test/unit/`
- **Total Passing:** 115 tests
- **Total Failing:** 7 tests
- **Baseline Comparison:** The 7 failures (`auth_repository_test.dart` (2), `counterparty_shield_test.dart` (1 compilation), `negotiation_repository_test.dart` (4)) were all confirmed pre-existing baseline failures prior to this sprint. All in-scope test suites passed with zero regressions.

---

## 3. Static Code Analysis (`flutter analyze`)
**Commands:**
- `flutter analyze lib/features/commodities/ lib/features/profile/`
- `flutter analyze lib/`

**Results:**
- `lib/features/commodities/`: **0 errors, 0 warnings**
- `lib/features/profile/`: **0 errors, 0 warnings**
- Zero regressions introduced into the codebase. All existing analysis warnings in `apps/rmseller_mobile` stem from pre-existing widget test mock signatures (`route_guard_test.dart`).

---

## 4. Debug Build Verification
**Command:** `flutter build apk --debug`
**Result:**
```
√ Built build\app\outputs\flutter-apk\app-debug.apk (in 96.2s)
```
Compilation succeeded with zero syntax errors or build failures.

---

## 5. Real PostgreSQL Database Validation (Rolled-Back Transaction)
**Script:** `scripts/validate-real-db-rollback.mjs`
**Target:** Live PostgreSQL Database via `DATABASE_URL` from `.env.local`
**Execution Mode:** Wrapped in a single `BEGIN; ... ROLLBACK;` block with savepoints.

### Results:
1. **Schema & Policy Application:**
   Proposed `0048_reconciled_seller_listings_and_broker_check.sql` applied cleanly within transaction.
2. **Mutual Exclusivity Invariant (`availabilities_owner_check`):**
   - Attempted insert with both `company_id` and `seller_user_id`: **Rejected** (Postgres error `23514`).
   - Attempted insert with neither `company_id` nor `seller_user_id`: **Rejected** (Postgres error `23514`).
3. **Authenticated Individual Seller Insert:**
   - Authenticated as `sub = '00000000-0000-4000-8000-000000000001'`.
   - Inserted lot `LOT-INDIV-001` with `seller_user_id`: **Success** (`id = be30cd36-2181-4b18-a4d9-c8e32ee7b929`).
4. **Cross-Seller Spoofing Prevention:**
   - Attempted insert with `seller_user_id = '00000000-0000-4000-8000-000000000002'`: **Rejected by RLS** (Postgres error `42501`).
5. **Cross-Seller Read Isolation:**
   - Seller 1 queries `public.availabilities`: Only saw own lots and global company lots; Seller 2 lots remained completely invisible.
6. **Asking Price Update:**
   - Seller 1 updated own lot price to 2700: **Success**.
7. **Duplicate Lot Number Protection:**
   - Attempted second insert of `LOT-INDIV-001` for Seller 1: **Rejected by Unique Index** (Postgres error `23505`).
8. **Rollback & Zero Production Writes:**
   - Forced `ROLLBACK;`.
   - Post-check verification confirmed `LOT-INDIV-001` does **NOT** exist in the database (`count = 0`).
   - Zero production data modified.
