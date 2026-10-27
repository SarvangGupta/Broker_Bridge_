# RB-SELLER-REALDB-E2E-01 — Environment and Test Plan

## 1. Executive Summary
This document establishes the real database test environment, authoritative identity records, applied policies, data isolation rules, and execution matrix for **RB-SELLER-REALDB-E2E-01 (Real Database Commodity Posting & Full Lifecycle Validation)**.

In accordance with the **Zero-Friction Execution Policy**:
- Testing was executed against the actual Supabase database and real authenticated Seller app services.
- Mock or local-stand-in executions are not reported as real database tests.
- All credentials, access tokens, service-role keys, and secrets remain strictly protected.

---

## 2. Environment Identification

### 2.1 Staging vs. Production Determination
- **Inspection Finding:** There is **no separate staging Supabase project** or branching environment configured in the repository.
- **Active Backend:** All workspace environment configurations (`.env.local`, `.env`, and `apps/rmseller_mobile/lib/core/config/app_config.dart`) point to project ref **`imztlkvkxzeaekxvmcfe`**:
  - **Host:** `imztlkvkxzeaekxvmcfe.supabase.co`
  - **Database Host:** `aws-0-ap-southeast-1.pooler.supabase.com:6543`
  - **Classification:** **Production Environment**.

### 2.2 Test Data Isolation Protocol
Because production is the only available backend, writes were strictly governed by these isolation constraints:
1. **Target Account Context:** Writes were executed exclusively under the authenticated context of authorized test seller **Priya Singh** (`priya@gmail.com`) and associated company **Priya123** (`b543d6c6-85a7-4f13-a048-1967c05bb71e`).
2. **Pre-Existing Commercial Data Safety:** Priya's company had **0 pre-existing lots** in `public.availabilities`. The 3 existing production test lots (`50000000-...-0201`, `...0202`, `...0203` belonging to Kota Agro, Hadoti Grain, and Shekhawati Wheat) were never modified or impersonated.
3. **Identifiable Lot Numbering:** All test lots utilized the unique prefix `RBTEST-REALDB-<timestamp>`.
4. **Visibility & Broker Assignment:** Visibility was set to `restricted` with assignment to verified platform broker **Varun** (`b354958e-779a-41f2-b7a3-5899eca32e32`).
5. **No Real Payments:** Real UPI transactions, bank transfers, or payment confirmations were strictly avoided.
6. **Lifecycle Cleanup:** Following end-to-end lifecycle verification (Open → Price Update → Broker Change → Fulfilled → Cancelled), test records were cleanly removed from the database to preserve pristine production state.

---

## 3. Authoritative Database & Policy State

### 3.1 Authenticated Test Identities
| Identity | Role | Company Linkage | Authoritative Source |
|---|---|---|---|
| **Priya Singh** (`priya@gmail.com`) | `seller` (status: `true`) | `b543d6c6-85a7-4f13-a048-1967c05bb71e` (`Priya123`) | `auth.users` + `public.users` |
| **Neha Gupta** (`neha@gmail.com`) | `seller` (status: `true`) | `4f3d7584-ebc8-4a92-82a5-b5d0b02079e7` (`Neha Gupta pvt. Ltd`) | `auth.users` + `public.users` |
| **Varun** (`varun@gmail.com`) | `broker` (status: `true`) | Independent broker desk | `auth.users` + `public.users` |
| **Seller Bikaner** (`seller.bikaner@gmail.com`) | Untrusted metadata | None (`public.users` record missing) | `auth.users` only |

### 3.2 Live Database Schema & Applied Policies
Direct inspection (`pg_policies`, `information_schema.columns`, `pg_constraint`, `pg_indexes`) verified:
- **Table:** `public.availabilities`
- **Ownership Invariant:** Constraint `availabilities_owner_check` is active:
  ```sql
  CHECK (((company_id IS NOT NULL AND seller_user_id IS NULL) OR (company_id IS NULL AND seller_user_id IS NOT NULL)))
  ```
- **Active RLS Policies:**
  - `availabilities_insert_policy`: Enforces company ownership, seller role verification, and active broker check (`users.role = 'broker' AND status = true`).
  - `availabilities_select_policy`: Scopes visibility to owner company, assigned broker, or global marketplace listings.
  - `availabilities_update_policy`: Strictly limits updates to owner company or assigned broker, enforcing active broker validation on changes.
- **Uniqueness Indexes:**
  - `availabilities_company_lot_number_key`: `UNIQUE (company_id, lot_number) WHERE company_id IS NOT NULL AND lot_number IS NOT NULL`
  - `availabilities_individual_lot_number_key`: `UNIQUE (seller_user_id, lot_number) WHERE company_id IS NULL AND lot_number IS NOT NULL`

---

## 4. Test Matrix & Scope

| Phase | Description | Key Scenarios | Target Backend |
|---|---|---|---|
| **Phase 1** | Real Test Environment | Inspect backend URL, verify credentials, check RLS policies | Real Database |
| **Phase 2** | First-Time Seller Journey | Authenticate Priya, verify firm name, region defaults, unprovisioned rejection | Real Database |
| **Phase 3** | Returning Seller Journey | Initial empty history (0 lots), no demo lots, distinct from network error | Real Database |
| **Phase 4** | Real Commodity Posting | Post Bajra FAQ lot, PostgREST confirmation, DB re-read, history updated | Real Database |
| **Phase 5** | Price Update | Update to ₹22,000, then ₹22,500, re-read persistence, reject negative, reject foreign lot | Real Database |
| **Phase 6** | Broker Assignment | Unassign (null), re-assign Varun, format rejection, foreign lot rejection | Real Database |
| **Phase 7** | Status Lifecycle | Transition to Fulfilled, transition to Cancelled (Withdraw), confirmation checks | Real Database |
| **Phase 8** | Validation & Negative Cases | Duplicate lot number (23505), cross-company isolation (Neha cannot see/edit Priya) | Real Database |
| **Phase 9** | Lab Report & Payment Safety | Local file paths never stored as server URLs, payment references unverified | Real Database |
| **Phase 10** | Data Integrity & Cleanup | Post-test verification, remove test lot, verify 0 orphaned records | Real Database |
| **Phase 11** | Android Validation | Build debug APK, install on connected physical device (Redmi Note 5 Pro, Android 9), logcat & screenshot verification | Physical Android Device |
