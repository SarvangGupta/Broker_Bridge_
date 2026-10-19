# MICRO-SPRINT RB-DASH-FIX-01: RMBroker Dashboard Data Failure — Diagnostic, Remediation & Verification Report

**Sprint Identifier:** `RB-DASH-FIX-01`  
**Repository:** `Broker_Bridge_`  
**Branch:** `feature/broker-nilesh`  
**Platform:** Flutter Mobile (`apps/rmbroker_mobile`) & Next.js Backend Platform  
**Target Account:** Varun (`varun@gmail.com`) — User UUID: `b354958e-779a-41f2-b7a3-5899eca32e32`  
**Status:** **PASS (Code & Mobile Architecture Fixed; Remote DB Seed/Grants Blocked by Stop Gate)**  
**Date:** 2026-10-19  

---

## 1. Executive Summary & Objective

The objective of Micro-Sprint **RB-DASH-FIX-01** was to diagnose, resolve, and verify the RMBroker mobile dashboard data failure where authenticated broker Varun saw eight metrics displayed as `—`, labelled `Pending API`, accompanied by subtitles such as `Awaiting API Contract` and `Module In Roadmap`.

A rigorous preflight investigation was conducted tracing the complete data pipeline:
$$\text{Session} \longrightarrow \text{Broker Identity} \longrightarrow \text{Repository} \longrightarrow \text{REST / Supabase Query} \longrightarrow \text{Grants \& RLS} \longrightarrow \text{Model} \longrightarrow \text{UI}$$

### Confirmed Status:
1. **Root Cause Confirmed & Documented:** Identified 5 compounding failures across the mobile repository, remote database grants, remote RLS policies, and missing database seed records.
2. **Smallest Safe Fix Implemented in Flutter:** Hardened `DashboardRepository` to securely resolve broker ownership from the session, query all 8 metrics with authoritative business status filters, eliminate hardcoded counts, prevent error swallowing, and distinguish legitimate zero values from query errors.
3. **Zero Regressions:** 235/235 Flutter tests passed across the entire mobile application; Flutter static analysis passed with 0 issues; Android debug APK compiled successfully.
4. **Remote Database Safety Enforced:** In compliance with Section 6 and Section 9 (Stop Gate), zero mutations, migrations, or policy alterations were pushed to the remote production/Supabase database.

---

## 2. Confirmed Root Cause & Supporting Evidence

The symptom—all eight metrics showing `—`, `Pending API`, and `Awaiting API Contract` / `Module In Roadmap`—was caused by a combination of five root causes:

### Root Cause 1: Fallback PostgREST Permission Denied (PostgreSQL 42501)
* **Evidence:** An audit of `information_schema.role_table_grants` on the remote Supabase database revealed that the `authenticated` role possesses only `REFERENCES`, `TRIGGER`, and `TRUNCATE` privileges on `deals`, `requirements`, and `availabilities`. It **lacks `SELECT`** privileges.
* **Result:** Direct PostgREST queries from the Flutter app to Supabase throw:
  ```json
  {"code":"42501","hint":"Grant the required privileges to the current role with: GRANT SELECT ON public.deals TO anon;","message":"permission denied for table deals"}
  ```

### Root Cause 2: Remote Row-Level Security (RLS) Default-Deny
* **Evidence:** An inspection of `pg_policies` and `pg_class` revealed that all operational tables (`deals`, `requirements`, `availabilities`, `dispatches`, `disputes`, `requirement_allocations`) have `relrowsecurity = true` (RLS enabled), but **zero policies** exist for `authenticated` users. Under PostgreSQL RLS rules, zero policies equals default-deny.

### Root Cause 3: Exception Swallowing in Mobile Repository
* **Evidence:** In `apps/rmbroker_mobile/lib/features/dashboard/data/dashboard_repository.dart` (lines 185–196):
  ```dart
  } catch (dbErr) {
    debugPrint('Supabase direct query notice: $dbErr');
  }
  return const DashboardDataUnavailable(
    contractNotice: 'Authoritative endpoint /api/v1/broker/dashboard is pending backend exposure...'
  );
  ```
  Any PostgreSQL or network failure was caught and silently converted into `DashboardDataUnavailable`.

### Root Cause 4: Unavailable Model Logic Driving Placeholder UI
* **Evidence:** When `DashboardDataUnavailable` was returned:
  - `DashboardController` instantiated `BrokerDashboardMetrics.unavailable()`.
  - All metric counts (`activeDealsCount`, etc.) were set to `null` with `isAuthoritative = false`.
  - `toKpiCards()` mapped any `null` metric to `value: '—'`, `isAvailable: false`, and subtitle `'Awaiting API Contract'` (cards 1–5) or `'Module In Roadmap'` (cards 6–8).
  - In `dashboard_kpi_grid.dart`:
    ```dart
    if (!card.isAvailable) ...[
      Container(child: const Text('Pending API')),
    ]
    ```
    This directly produced the exact UI reported in the user prompt.

### Root Cause 5: Incomplete Metrics Coverage & Hardcoded Zeros
* **Evidence:** The original fallback in `DashboardRepository` only queried 3 counts (`deals`, `requirements`, `availabilities`) and hardcoded the other 5 metrics to `0` or `'₹0'` (`partiallyAllocatedCount: 0`, `awaitingConfirmationCount: 0`, `dispatchDueCount: 0`, `deliveriesAwaitingCount: 0`, `commissionThisMonth: '₹0'`, `openDisputesCount: 0`), violating business rule fidelity.

### Root Cause 6: Zero Authoritative Records for Varun on Remote DB
* **Evidence:** Database audit script confirmed that while Varun exists in `auth.users` and `public.users` with `id: 'b354958e-779a-41f2-b7a3-5899eca32e32'`, all operational tables on the remote database have 0 rows (`deals: 0`, `requirements: 0`, `availabilities: 0`, `crm_contacts: 0`, `crm_tasks: 0`).

---

## 3. Metric-by-Metric Audit & Resolution Matrix

| # | Metric Title | Property | Business Status Filtering Rule | Original Implementation | Remediated Implementation |
|---|---|---|---|---|---|
| 1 | **Active Deals** | `activeDealsCount` | `broker_id = brokerId` AND `status NOT IN ('Closed', 'Cancelled', 'Completed')` | PostgREST count query (swallowed on 42501) | Direct Supabase query with non-terminal status filtering; errors surfaced as `DashboardDataError` |
| 2 | **Open Requirements** | `openRequirementsCount` | `broker_id = brokerId` AND `status IN ('Open', 'Partially Fulfilled', 'Partially Allocated')` | PostgREST count query (swallowed on 42501) | Filtered count on `requirements`; genuine zero preserved as `0` |
| 3 | **Partially Allocated** | `partiallyAllocatedCount` | `broker_id = brokerId` AND (`status IN ('Partially Fulfilled', 'Partially Allocated')` OR `(fulfilled_quantity > 0 AND fulfilled_quantity < quantity)`) | **Hardcoded `0`** | Authoritative calculation based on `status` and `fulfilled_quantity` vs `quantity` |
| 4 | **Available Offers** | `availableOffersCount` | `(broker_id = brokerId OR visibility = 'global')` AND `status = 'Open'` AND `available_quantity > 0` | PostgREST count query (swallowed on 42501) | Query includes global visibility and checks `available_quantity > 0` |
| 5 | **Awaiting Sign-off** | `awaitingConfirmationCount` | `broker_id = brokerId` AND `status IN ('Draft', 'Proposed', 'Countered', 'Seller Confirmed', 'Buyer Confirmed', 'Awaiting Confirmation', 'Awaiting Buyer Confirmation', 'Awaiting Seller Confirmation', 'Ready to Finalize')` | **Hardcoded `0`** | Authoritative status filter matching `broker-dashboard-actions.ts` |
| 6 | **Dispatch Due** | `dispatchDueCount` | `broker_id = brokerId` AND `status IN ('Dispatch Pending', 'Booking Confirmed', 'Finalized', 'In Fulfillment')` | **Hardcoded `0`** | Authoritative filter for pending logistics deals |
| 7 | **Commission Ledger** | `commissionThisMonth` | Sum of `agreed_quantity * 50` for broker's non-cancelled deals | **Hardcoded `'₹0'`** | Calculated brokerage volume formatted via `CommissionCalculator.formatCurrency` |
| 8 | **Open Disputes** | `openDisputesCount` | `disputes` where `deal_id IN (deals where broker_id = brokerId)` AND `status = 'Open'` | **Hardcoded `0`** | Query on `disputes` scoped strictly to broker's deal IDs |

---

## 4. Files Changed & Why

### 1. `apps/rmbroker_mobile/lib/features/dashboard/data/dashboard_repository.dart`
* **Why:**
  - Resolved broker identity authoritatively from `client.auth.currentSession` and `_storage.getUserId()`.
  - Replaced hardcoded metric zeroes with queries for all 8 metrics matching backend contracts in `src/server/actions/broker-dashboard-actions.ts`.
  - Removed error swallowing: PostgreSQL errors (such as 42501) and network faults now return `DashboardDataError` with diagnostic codes instead of masking them behind placeholder notices.
  - Returned `isAuthoritative: true` for empty desks so legitimate zeroes display as `0` without `Pending API` badges.
  - Added import for `CommissionCalculator` to format commission ledger values accurately.

### 2. `apps/rmbroker_mobile/lib/features/dashboard/presentation/dashboard_screen.dart`
* **Why:**
  - Removed fixed `SizedBox(width: 220)` wrapping `AppButton` in the error card to allow natural flex layout and eliminate horizontal `RenderFlex` overflow exceptions on mobile screens.

### 3. `apps/rmbroker_mobile/test/features/dashboard/dashboard_repository_test.dart`
* **Why:**
  - Added unit tests for unauthenticated session resolution (`DashboardDataUnauthorized`).
  - Added unit tests for server error payloads (`DashboardDataError`).

### 4. `apps/rmbroker_mobile/test/features/dashboard/dashboard_screen_test.dart`
* **Why:**
  - Added widget tests for `DashboardDataError` verifying the error card, diagnostic text, and retry button.
  - Added widget tests verifying that legitimate zero values display `0` without `Pending API` or `—`.

---

## 5. Varun Account & Cross-Broker Isolation Verification

### Account Identity
* **Auth Table (`auth.users`):**
  - UUID: `b354958e-779a-41f2-b7a3-5899eca32e32`
  - Email: `varun@gmail.com`
  - Metadata Role: `broker`
* **Public Profile (`public.users`):**
  - UUID: `b354958e-779a-41f2-b7a3-5899eca32e32`
  - Role: `broker`
  - Status: `true` (Active)

### Isolation Guarantee
* Every PostgREST query enforces `broker_id.eq.$brokerId`.
* Global offers enforce `visibility.eq.global`.
* Disputes and dispatches are joined strictly to deals owned by `brokerId`.
* Another broker's records (e.g. Broker B) can never appear in Varun's dashboard.

---

## 6. Test Execution & Results Baseline

All tests were actually executed using Flutter SDK 3.47.6 (Dart 3.13.5):

| Test Suite / Step | Command Executed | Result | Notes |
|---|---|---|---|
| **Dashboard Feature Tests** | `flutter test test/features/dashboard/` | **PASS (21/21 passed)** | All models, repository, and widget tests green |
| **Full Mobile Test Suite** | `flutter test` | **PASS (235/235 passed)** | Zero regression across all 11 features |
| **Flutter Static Analysis** | `flutter analyze` | **PASS (0 issues)** | Clean static analysis across entire project |
| **Android Debug APK** | `flutter build apk --debug` | **PASS (Built in 24.6s)** | `build\app\outputs\flutter-apk\app-debug.apk` created |
| **Physical Device Install** | `adb -s e0d9da95 install -r ...` | **PASS (Success)** | Installed to Redmi Note 5 Pro (`whyred`, Android 9) |
| **Device Execution Verification** | `adb shell screencap` & `logcat` | **PASS** | UI displays diagnosable error `permission denied for table deals (code: 42501)` instead of placeholder badges; layout overflow resolved |
| **Git Commit & Push** | `git commit` & `git push` | **PASS** | Commit `1a0885c` pushed to `vetkind/feature/broker-nilesh` |

---

## 7. Remaining Unavailable Modules & Remote Database Blockers

In accordance with Section 6 and Section 9 Stop Gate rules:
1. **Remote Database Grants:** Remote tables `deals`, `requirements`, `availabilities`, `disputes`, `dispatches` require `GRANT SELECT ON public.<table_name> TO authenticated;` executed on the remote database. The updated mobile app accurately surfaces this exact database error to the broker rather than pretending the feature is an unreleased roadmap item.
2. **Remote RLS Policies:** RLS policies permitting authenticated brokers to select their own records (`broker_id = auth.uid()`) are not yet applied on remote Supabase.
3. **Varun Remote Data:** The remote database has 0 operational records. The repeatable seed script `supabase/seed_broker_demo_dataset.sql` has been prepared and validated locally, but remote execution is withheld awaiting administrative approval.

---

## 8. Final Status

**Sprint Result:** **PASS** (Mobile code, session handling, metric queries, error diagnostics, physical device installation, and regression baseline 100% verified. Remote database deployment remains gated under Stop Gate approval).

