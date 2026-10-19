# AUDIT & ROOT CAUSE REPORT: MICRO-SPRINT RB-DIR-FIX-01
## Counterparty Directory Data Recovery

**Document Reference:** `RB-DIR-FIX-01-AUDIT-REPORT`  
**Date:** 2026-10-19  
**Branch:** `feature/broker-nilesh`  
**Target User:** Varun (`varun@gmail.com` / UUID `b354958e-779a-41f2-b7a3-5899eca32e32`)  
**Target Screen:** Counterparty Directory (`DirectoryScreen`)  
**Status:** Audit Complete — Awaiting Approval Gate (Phase C)  

---

## 1. Executive Summary

| Item | Finding | Status |
| :--- | :--- | :---: |
| **Backend Environment** | `https://imztlkvkxzeaekxvmcfe.supabase.co` | **Verified** |
| **Session Identity** | Varun (`varun@gmail.com` / `b354958e-779a-41f2-b7a3-5899eca32e32`, role: `broker`) | **Verified** |
| **Persisted Records in DB** | **9 counterparty contacts** exist in `public.crm_contacts` for Varun (6 Buyers, 3 Sellers) | **Verified Live** |
| **Add Seller / Contact Write** | **Genuinely persists.** Test record `hari shanker` / `shiv shanker` created today was saved to `crm_contacts`, `users`, and `companies` | **Verified Live** |
| **Next.js Route Status** | `/api/v1/broker/directory` has **NEVER been mounted/registered** in Next.js App Router | **Identified** |
| **Supabase Fallback Status** | PostgREST fails with **`PGRST201: Could not embed because more than one relationship was found for 'crm_contacts' and 'users'`** | **Identified** |
| **Database Migrations** | Migrations `0036` and `0037` **are already fully applied** to the remote database with active RLS and grants | **Verified** |
| **Database Changes Needed** | **None.** Schema, RLS policies, and grants are healthy and fully authorized | **Zero DB Changes** |

---

## 2. Environment and Architecture Verification

1. **Configured Backend Environment:**
   - Both `apps/rmbroker_mobile/lib/core/config/app_config.dart` and workspace `.env` point to:
     - URL: `https://imztlkvkxzeaekxvmcfe.supabase.co`
     - Reference ID: `imztlkvkxzeaekxvmcfe`
   - Mobile app and local development scripts connect to the exact same backend database.

2. **Session Identity:**
   - Authenticated User: `b354958e-779a-41f2-b7a3-5899eca32e32`
   - Email: `varun@gmail.com`
   - Role in `public.users`: `broker`

---

## 3. Authoritative Data Reconciliation (Live Database Truth)

Using direct SQL via Drizzle and authenticated PostgREST queries with Varun's JWT, table row counts and ownership were verified:

### A. Table Row Inventory

| Table Name | Total Rows | Rows Belonging to Varun | Verification Notes |
| :--- | :---: | :---: | :--- |
| `public.crm_contacts` | **9** | **9** | 100% owned by Varun (`broker_id = b354958e-779a-41f2-b7a3-5899eca32e32`) |
| `public.companies` | **17** | **9 linked** | Buyer and seller enterprise entities |
| `public.users` | **18** | **9 linked** | Contact representatives |
| `public.crm_activities` | **0** | **0** | Communication logs |

### B. Varun's 9 Authoritative Counterparty Contacts

| # | Contact ID Prefix | Name | Role | Mobile | Company Name | State / City | Created At |
| :-: | :--- | :--- | :---: | :---: | :--- | :--- | :--- |
| 1 | `d6f00dfc...` | **hari shanker** | **Buyer** | `+919828400780` | **shiv shanker** | Rajasthan / Jaipur | `2026-10-19 10:16` *(Persisted via Add Contact today)* |
| 2 | `40000000...0105` | **Ritu Singhania** | **Buyer** | `+919876500105` | **RBTEST Malwa Solvent Extractions** | Madhya Pradesh / Ujjain | Seed dataset |
| 3 | `40000000...0104` | **Deepak Jain** | **Buyer** | `+919876500104` | **RBTEST Frontier Starch Processing** | Rajasthan / Kota | Seed dataset |
| 4 | `40000000...0103` | **Pooja Agarwal** | **Buyer** | `+919876500103` | **RBTEST Golden Harvest Flour Mills** | Rajasthan / Bundi | Seed dataset |
| 5 | `40000000...0102` | **Vikas Verma** | **Buyer** | `+919876500102` | **RBTEST North Dairy Feed Corp** | Rajasthan / Baran | Seed dataset |
| 6 | `40000000...0101` | **Aman Sharma** | **Buyer** | `+919876500101` | **RBTEST AgrInnovate Feeds Pvt Ltd** | Rajasthan / Kota | Seed dataset |
| 7 | `40000000...0203` | **Suresh Meena** | **Seller** | `+919876500203` | **RBTEST Shekhawati Wheat Traders** | Rajasthan / Bundi | Seed dataset |
| 8 | `40000000...0202` | **Mahesh Choudhary** | **Seller** | `+919876500202` | **RBTEST Hadoti Grain Producers Co** | Rajasthan / Baran | Seed dataset |
| 9 | `40000000...0201` | **Rajesh Patidar** | **Seller** | `+919876500201` | **RBTEST Kota Agro Warehousing LLP** | Rajasthan / Kota | Seed dataset |

- **Total Contacts:** **9**
- **Active Buyers:** **6**
- **Active Sellers:** **3**
- **Active Mandates:** **16** (associated open requirements, open offers, and active deals)

---

## 4. Add Seller / Contact Persistence Trace

`Add Contact UI → ContactFormController.submitForm → DirectoryRepository.createContact`

1. **Client-side Validation:** Validates contact name, company name, and phone normalization (`PhoneUtils.validateAndNormalize`).
2. **Duplicate Check:** Checks for duplicate normalized mobile under Varun.
3. **REST POST:** Attempts `POST /broker/directory`. Route is unmounted, so it catches 404/Connection error.
4. **Direct Supabase Insert Fallback (lines 337–377):**
   - Inserts into `public.companies` (returned company ID `55fffeff-c4eb-4785-8506-e66a692d13b1`).
   - Inserts into `public.users` with `role = 'buyer'` (returned user ID `b1e86af0-24ab-468c-8a57-a74353ccda63`).
   - Inserts into `public.crm_contacts` with `broker_id = varunId` (returned contact ID `d6f00dfc-ab7b-408a-8b74-2ebe6b605bb1`).
5. **Conclusion:** **The write operation genuinely succeeds and persists.** The record is physically present in PostgreSQL.

---

## 5. Root Cause Analysis: Why Directory Displays Zero & Pending

The failure occurs in the **read path** due to two cascading defects:

### Defect 1: Primary REST Route Missing in Next.js
The mobile app's primary strategy calls `_apiClient.get('/broker/directory')`.
- In Next.js App Router, all directory logic was written as Server Actions in `src/server/actions/broker-directory-actions.ts` for web SSR.
- No HTTP route handler was ever registered under `src/app/api/v1/broker/directory/route.ts` or `app/api/`.
- Every HTTP request to `/api/v1/broker/directory` fails with 404 Not Found.

### Defect 2: Fallback PostgREST Query Ambiguity (`PGRST201`)
When the REST route fails, `directory_repository.dart` falls back to direct Supabase PostgREST sync (lines 144–152):
```dart
final response = await client
    .from('crm_contacts')
    .select(
      'id, broker_id, user_id, company_id, last_activity_at, created_at, '
      'users(id, name, mobile, email, role, status), '
      'companies(id, name, status, is_verified, trust_score, district_id, state_id)',
    )
    .eq('broker_id', brokerId)
    .order('created_at', ascending: false);
```

#### Why PostgREST Fails:
In PostgreSQL table `crm_contacts`, there are **two foreign keys** referencing `public.users(id)`:
1. `crm_contacts.broker_id REFERENCES users(id)` (`crm_contacts_broker_id_fkey`)
2. `crm_contacts.user_id REFERENCES users(id)` (`crm_contacts_user_id_fkey`)

Because two foreign keys exist between the same pair of tables, PostgREST cannot determine which column to embed when asked for `users(...)`. PostgREST returns:
```json
{
  "code": "PGRST201",
  "message": "Could not embed because more than one relationship was found for 'crm_contacts' and 'users'",
  "hint": "Try changing 'users' to one of the following: 'users!crm_contacts_user_id_fkey', 'users!user_id'."
}
```

### Defect 3: Silent Conversion to Unavailable Notice
In `directory_repository.dart` line 190:
```dart
    } catch (dbErr) {
      debugPrint('Supabase direct directory query notice: $dbErr');
    }

    // 3. Honest Unavailable State (when REST route is not mounted and DB is unreachable)
    return const DirectoryUnavailable(
      contractNotice:
          'Authoritative endpoint /api/v1/broker/directory is pending backend exposure. '
          'Contact data is not shown to prevent presenting fabricated or unverified counterparty records.',
    );
```
The repository catches `PGRST201`, assumes the database is offline/unreachable, and returns `DirectoryUnavailable`.
`DirectoryController` sets `contacts: []` and `stats: empty()`.
`DirectoryScreen` renders `0 Buyers`, `0 Sellers`, `0 Mandates`, and the notice `Directory Contract Pending`.

### Proof of Fix:
When `users(...)` is replaced with `users!user_id(...)` in an authenticated PostgREST call:
- Status: **HTTP 200 OK**
- Rows returned: **9 contacts** (all 9 belong to Varun, exactly matching database truth).

---

## 6. Database Migrations, RLS & Privileges Audit

- **Applied Migrations:** `0036_add_crm_tasks_rls_and_grants.sql` and `0037_add_broker_directory_rls_and_grants.sql` are **fully applied and active** on the target database.
- **Grants:** `authenticated` role has explicit `SELECT, INSERT, UPDATE` on `crm_contacts`, `companies`, `users`, and `crm_activities`.
- **RLS Policies:**
  - `crm_contacts_select_policy: ((broker_id = auth.uid()) OR is_admin())` — **PASS**
  - `crm_contacts_insert_policy: (((broker_id = auth.uid()) AND (is_broker() OR is_admin())) OR is_admin())` — **PASS**
  - `crm_companies_select_policy: (is_admin() OR (created_by = auth.uid()) OR (EXISTS (SELECT 1 FROM crm_contacts WHERE crm_contacts.company_id = companies.id AND crm_contacts.broker_id = auth.uid())))` — **PASS**
  - `users_select_policy` — **PASS**
- **Isolation Guarantee:** Another broker (e.g. Ramesh or Nilesh) cannot view Varun's contacts or companies; RLS enforces `broker_id = auth.uid()` at the PostgreSQL engine level.
- **No database migrations, DDL changes, RLS modifications, or privilege grants are needed.**

---

## 7. Proposed Smallest Safe Corrective Plan

### Component 1: Fix PostgREST Fallback in Flutter Client
In [`apps/rmbroker_mobile/lib/features/directory/data/directory_repository.dart`](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmbroker_mobile/lib/features/directory/data/directory_repository.dart):
1. Line 148: Replace ambiguous `users(...)` with explicit relationship: `users!user_id(id, name, mobile, email, role, status)`.
2. Line 237 (in `checkDuplicate`): Replace ambiguous `users!inner(...)` with `users!user_id!inner(...)`.
3. Line 552 (in `getContactDetails`): Replace ambiguous `users(...)` with `users!user_id(...)`.
4. Hardened Error Propagation: If an unexpected PostgREST error occurs, return `DirectoryError` rather than silently converting to `DirectoryUnavailable`.

### Component 2: Mount Authoritative Next.js API Route
Create [`src/app/api/v1/broker/directory/route.ts`](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/src/app/api/v1/broker/directory/route.ts):
- Implements `GET`:
  - Parses query parameters: `role`, `search`, `status`.
  - Calls existing server action `getBrokerDirectoryContactsAction(filter)` from `src/server/actions/broker-directory-actions.ts`.
  - Returns `{ success: true, data: { contacts, stats } }`.
- Implements `POST`:
  - Parses request body (`CreateContactInput`).
  - Calls existing server action `createBrokerContactAction(body)`.
  - Returns `{ success: true, contactId }`.
- Authenticates session via `createClient()` from `@/lib/supabase/server`.
- Derives broker identity securely on the server via `getAuthenticatedBroker()`.

---

## 8. Regression Risks & Safety

| Risk Factor | Assessment | Mitigation |
| :--- | :--- | :--- |
| **Database Migration Risk** | **Zero** | No database changes, grants, or DDL modifications required. |
| **Cross-Broker Isolation Risk** | **Zero** | PostgreSQL RLS enforces `broker_id = auth.uid()`; server action enforces `eq(crmContacts.brokerId, brokerId)`. |
| **API Contract Drift Risk** | **Zero** | Next.js API route reuses the exact domain action `getBrokerDirectoryContactsAction` already consumed by the web UI. |
| **Dual-Path Redundancy** | **High Reliability** | If Next.js REST API is active, it serves rich metrics; if REST is offline, direct PostgREST fallback displays all contacts without failing. |

---

## 9. Approval Gate

**STOP GATE:** In accordance with sprint guidelines, no code edits, route implementations, or database mutations have been performed.  
Awaiting explicit approval of this audit report and proposed two-component scope before proceeding with Phase D (Implementation) and Phase E/F (Testing & Verification).
