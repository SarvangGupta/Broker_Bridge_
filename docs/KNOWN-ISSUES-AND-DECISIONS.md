# RMBroker — Known Issues and Decisions

Baseline: HEAD `390fd84`, 2026-10-24. IDs are stable; reference them in future sprint reports. Severity: **S1** = data integrity, security, or a core workflow is broken · **S2** = wrong or misleading numbers · **S3** = quality.

## 1. Confirmed current issues (verified in code at the baseline)

### Fabricated / demo data on live paths
| ID | Sev | Issue | Evidence |
|---|---|---|---|
| KI-01 | ~~S1~~ **Fixed in RMBROKER-REQ-LIFECYCLE-E2E-01 (uncommitted)**: seed removed; only backend rows are shown | 7 demo notifications are seeded into the cache and merged with real rows for **every** user | `notification_repository.dart` `_seedDefaultNotifications`, `_filterAndSort` returns the whole cache |
| KI-02 | S1 | 6 demo tasks are merged into every user's task list; the create fallback uses `brokerId 'broker-demo-user'` | `task_repository.dart`, `task_controller.dart:214` |
| KI-03 | ~~S1~~ **Fixed in RMBROKER-REQ-LIFECYCLE-E2E-01 (uncommitted)**: fallback removed; a missing deal returns NOT_FOUND | Deal detail returns a hardcoded fake deal (Mustard, ₹5,450, both parties confirmed) for any id containing `0042` or `0891`; the seeded notification links to `DL-2026-0891` | `deal_repository.dart:279-307` |
| KI-04 | S1 | Commission: 6 static demo records are returned when there is no Supabase user, and `getDealCommission` checks the demo cache **first**; payments and adjustments are stored only in memory but reported as `Confirmed` | `commission_repository.dart:17-300, 502-618` |
| KI-05 | S1 | Invoices module is entirely in-memory demo data (no table, no Supabase path) | `invoice_repository.dart` |
| KI-06 | S1 | Broadcast: the notification insert is invalid (non-UUID id, no INSERT grant), the failure is swallowed, and every recipient is counted as "sent"; broadcast history auto-generates "realistic historical records" | `market_broadcast_repository.dart:216-287`, `broadcast_history_repository.dart:62-66` |
| KI-07 | S2 | Dashboard trend badges (`↑ +1/+2/+3`) are derived from the count itself; `LIVE` badge is constant | `dashboard_models.dart:110-219`, `dashboard_header.dart:463` |

### Broken write paths (repo schema vs. code)
| ID | Sev | Issue | Evidence |
|---|---|---|---|
| KI-10 | ~~S1~~ **Fixed in RMBROKER-REQ-LIFECYCLE-E2E-01 (uncommitted)**: uses `availabilities.company_id` (deal creation and allocation list). Live evidence: all 5 allocations stuck at `CONFIRMED` with no deal | Deal creation selects `availabilities.seller_id` (no such column); `deals.seller_id` would be empty | `deal_repository.dart:612-629` |
| KI-11 | ~~S1~~ **Fixed in RMBROKER-REQ-LIFECYCLE-E2E-01 (uncommitted)**: the reason goes in the snapshot; history no longer selects the column | Deal terms: inserts `deal_versions.change_reason` (no column) after already superseding the prior version | `deal_repository.dart:938-956` |
| KI-12 | ~~S1~~ **Fixed in RMBROKER-REQ-LIFECYCLE-E2E-01 (uncommitted)**: progress is written to `deals.status` (`Awaiting Seller/Buyer Confirmation`, `Ready to Finalize`); reads combine the deal status, version status and snapshot (`DealVersionConfirmation`). Verified live: no UPDATE policy on deal_versions | Party confirmation updates `deal_versions.snapshot_payload`, which the 0034 trigger forbids; 0038 has no UPDATE policy on deal_versions | `deal_repository.dart:1100`, `0034`, `0038` |
| KI-13 | ~~S1~~ **Fixed in RMBROKER-REQ-LIFECYCLE-E2E-01 (uncommitted)**: `locked_version_id` is set and `broker_id` dropped; `bookings_deal_id_unique` (23505) makes retries reuse the booking; 6-digit reference | Finalize inserts `bookings.broker_id` (no column) and omits NOT NULL `locked_version_id`; booking ref uses 4 ms digits | `deal_repository.dart:1249-1259`, `0028` |
| KI-14 | S2 · **Partly addressed in RMBROKER-REQ-LIFECYCLE-E2E-01**: the broken inserts were removed from terms, confirm and finalize. There is still no audit trail from mobile: `authenticated` has no INSERT on `negotiation_events` | `negotiation_events` inserts in DealRepository use non-existent columns (failure swallowed), so there is no audit trail | `deal_repository.dart:969, 1112, 1274` |
| KI-15 | S1 · **Partly addressed in RMBROKER-REQ-LIFECYCLE-E2E-01**: idempotency added (allocation reuse, quotation reuse, deal already linked, unique booking) and failures compensated. Still not a transaction; needs an RPC or a served route (approval A5) | Multi-step writes (quotation → deal → version → allocation) are sequential client calls with no transaction or idempotency | `createDealFromAllocation` |
| KI-16 | ~~S2~~ **Fixed in RMBROKER-REQ-LIFECYCLE-E2E-01 (uncommitted)**: web propose+confirm order; stock is reserved with a version lock; fulfilled is updated by compare-and-set; units are converted; product, assignment and lot ownership are guarded | Allocation is inserted as `CONFIRMED`; no reservation on availabilities, no `fulfilled_quantity` update | `proposeAllocation` |
| KI-17 | S2 · **Partly addressed in RMBROKER-REQ-LIFECYCLE-E2E-01**: `cancelDeal` now checks the deal, owner and status first. `cancelRequirement` and `confirmAllocation` are unchanged | Updates (`cancelRequirement`, `cancelDeal`, `confirmAllocation`) report success even when RLS matches 0 rows | `work_repository.dart:238`, `deal_repository.dart:533, 745` |
| KI-18 | S2 | Work Desk proposal Supabase fallback writes `deal_versions.request_id` = quotation/requirement id; RLS requires a deal id | `work_repository.dart:603, 729-752` |

### Dashboard / list consistency
| ID | Sev | Issue |
|---|---|---|
| KI-20 | S2 | Dashboard counts and drill-down lists use different predicates for 6 of 8 cards (see FEATURE-STATUS-REGISTER §A) |
| KI-21 | S2 · **Partly addressed in RMBROKER-REQ-LIFECYCLE-E2E-01**: the live requirement status `Allocated` now maps to Fully Allocated, and `Open` rows show Partially/Fully Allocated from their remaining quantity. Unknown strings still default | `DealStatus.fromString` / `RequirementStatus.fromString` / `OfferStatus.fromString` map unknown strings to `draft`/`open` |
| KI-22 | S2 | Deals list and commission queries include `broker_id IS NULL`; the dashboard does not |
| KI-23 | S2 | Open Disputes: query failure is swallowed and shown as 0; the destination uses a different source (deal status) |
| KI-24 | S2 | Commission tile labelled monthly/"Estimated earnings" is all-time `qty × ₹50`; the rate ignores deal terms |

### Security / auth (no changes made; controlled sprint required)
| ID | Sev | Issue |
|---|---|---|
| KI-30 | S2 | `users.full_name` select fails silently, so the client role comes from editable JWT `user_metadata`. Server-side RLS uses `app_metadata` (safe *if* 0036–0038 are applied) |
| KI-31 | S2 | No GoRouter auth guard; `onSessionExpired` is never wired; `checkSession` accepts any stored token with a broker role, without checking expiry |
| KI-32 | S2 | `confidential_minimum_price` is fetched for every global offer visible to any authenticated broker; the business rule for who may see it is unverified |
| KI-33 | S3 | Raw Postgrest/exception text is shown in the UI |
| KI-34 | S3 | Release build signed with the debug key; release `API_BASE_URL` is the placeholder `rmbroker.example.com` |
| KI-35 | S3 | Supabase URL and anon key are compiled in as defaults. The anon key is public by design, so this is acceptable; no service-role key is in the app |

### Backend contract gaps
| ID | Sev | Issue |
|---|---|---|
| KI-40 | S2 | ~28 of ~30 `/api/v1/broker/*` endpoints called by the app don't exist; every call costs a failed request before the fallback |
| KI-41 | ~~S3~~ **Fixed in RMBROKER-DIRECTORY-SCALE-01 (uncommitted)**: the app now calls `PATCH /directory/[id]/status` | Directory status: app `POST /directory/:id/toggle-status` vs server `PATCH /directory/[id]/status` |
| KI-42 | S2 | `requirements.broker_id` / `availabilities.broker_id` exist only in Drizzle; numbered migrations can't rebuild the DB that RLS 0038 expects |
| KI-43 | ~~S1~~ **Fixed in RB-PRODUCT-MASTER-07 (uncommitted)**: grades filtered by product in both sheets, active-only products, and a DB-side `validateProductGrade()` before every requirement/offer insert | RMBroker master data (`getMasterData()` Supabase fallback; `/broker/master-data` doesn't exist) loads **all** commodities (incl. inactive) and **all** grades; `create_requirement_sheet.dart` / `create_offer_sheet.dart` don't filter grades by the selected commodity. Since RB-PRODUCT-MASTER-06 (2026-10-24) there are 53 grades named "FAQ (Fair Average Quality)", so a broker can submit a grade belonging to another product (no DB constraint ties `grade_id` to `commodity_id`) | `work_repository.dart:479-480`, `create_requirement_sheet.dart:265`, `create_offer_sheet.dart:272` |
| KI-44 | ~~S2~~ **Fixed in RMBROKER-DIRECTORY-SCALE-01 (uncommitted)**: the four directory routes were moved to `app/api/v1/broker/directory/` and verified to answer JSON. The other `src/app/` routes (`api/cron/monitor-dispatches`, `api/v1/requirements/sync`, `api/v1/broker/requirements/[id]/proposal`, `(buyer)/buyer/proposals`) are still unserved | The `/api/v1/broker/directory*` routes live in `src/app/`, which Next ignores because a root `app/` exists. Every directory REST call gets Next's **HTML** 404. Before RMBROKER-DIRECTORY-FIX-01 that HTML body crashed Add Buyer/Add Seller/Edit (see that report); the app now falls back to Supabase. The routes are still unserved |
| KI-45 | ~~S3~~ **Fixed in RMBROKER-DIRECTORY-SCALE-01 (test-only)**: the new send is stamped after the latest seeded record | `broadcast_history_test.dart` "Recording a newly sent broadcast prepends it…" fails before 14:45 local time: the seeded fixture has a broadcast at 14:45 *today*, which sorts ahead of the new one. Pre-existing, test-only; found in RMBROKER-DIRECTORY-FIX-01 |

### Requirement → deal lifecycle (RMBROKER-REQ-LIFECYCLE-E2E-01, 2026-10-25; live checks read-only)
| ID | Sev | Issue | Evidence / status |
|---|---|---|---|
| KI-46 | S1 · **App fix done; RLS decision open (A1)** | `companies` RLS shows a broker only companies in their CRM directory. The broker requirement query used `companies!inner`, so every assigned requirement whose buyer was not a CRM contact disappeared: Varun saw 5 of 15, and neither of Rohan's latest two | Now a left embed. The buyer shows as "Buyer company not in your directory", not verified and with no trust chip. Showing the real name needs a broker-scoped SELECT or an RPC |
| KI-47 | ~~S1~~ **Fixed (uncommitted)** | Requirement notifications opened the generic Work list (`/work?tab=0`), ignoring `payload.requirementId`. The detail screen only read the loaded list, and `WorkScreen` ignored `reqId` | Routes by record id (deal, requirement, offer). The detail screen loads by id with not-found, not-assigned and closed states. Match Center pre-selects |
| KI-48 | S2 · decision (A3) | `notify_requirement_brokers` notifies any active broker, whether or not `requirements.broker_id` is set. 2 live notifications point to unassigned requirements (`0459a227…`, `eed5c51a…`) | They open read-only as "Not assigned to your desk" |
| KI-49 | S2 · schema (A4) | Buyer payment terms, packaging and notes are never stored: `requirements` has no columns for them and the Buyer insert drops them, so the broker cannot see them | Live columns verified |
| KI-50 | S1 · data decision (A2) | 5 live allocations are `CONFIRMED` with no deal. 3 came from the old mobile path (2026-10-19) with no reservation: lot `…202` has 40 available but 90 allocated, and requirement `…105` (Soybean Seed) is allocated against lot `…203` (Sharbati Wheat) | Not changed. The new path never reuses these rows (`confirmed_at` is null) |
| KI-51 | S1 · web, unverified live | Web `recordPartyConfirmationAction` rewrites `snapshot_payload`, which the trigger rejects. `createDealFromAllocationAction` writes user ids into `deals.buyer_id/seller_id`, whose FKs reference `companies` | Code plus live FK and trigger source; not executed |
| KI-52 | S2 | No producer creates seller-offer → broker notifications (0 live rows), so the reverse flow cannot start from a notification | The receiving side routes `availabilityId` to Offers |
| KI-53 | S3 | The requirement notification payload has no buyer name, so with KI-46 the broker cannot tell which buyer sent it | Payload built by the RPC |
| KI-54 | S2 | `quotations(requirement_id, seller_availability_id)` and `deals(quotation_id)` have no unique constraint. Duplicate prevention relies on the app (reuse and idempotency guards) | Live constraints verified |

## 2. Historical issues — status at baseline

| Historical claim | Current status | Evidence |
|---|---|---|
| Dashboard showed `—` / "Pending API" | **Resolved in code** (Supabase direct queries; Error/Unauthorized/Unavailable states). Live data depends on remote grants | `dashboard_repository.dart` |
| PostgreSQL 42501 / missing grants & RLS on remote | **Unverified now.** Migration 0038 prepared; RB-DB-SEC-01 says not applied. Later RB-DRILL-01 claims live verification with seeded data, which conflicts | reports, commits `088b2d1`, `6c35cfa` |
| Active Deals opened unfiltered Deals | **Fixed** (`/deals?filter=active`), but predicates still differ (KI-20) | `dashboard_models.dart` |
| Open Requirements unfiltered | **Fixed** route; predicate mismatch remains | — |
| Available Offers wrong tab | **Fixed** (`tab=1`) | — |
| Awaiting Sign-off missing filter | **Fixed** (`filter=signoff`); bucket mismatch remains | — |
| Dispatch Due → placeholder | **Changed** to `/deals?filter=dispatch_due` (dispatch module itself is still a placeholder) | — |
| Open Disputes → placeholder | **Changed** to `/deals?filter=disputed` (different data source; KI-23) | — |
| Commission queried `booking_reference`/`total_valuation` on deals | **Fixed** (embeds `bookings`, computes value). The embed needs an FK not in the repo | `commission_repository.dart:400` |
| Commission mock fallback after query error | **Partly fixed**: Supabase error now returns an error. Mock is still used when there is no session/client, and in `getDealCommission` (KI-04) | — |
| Dashboard redesign (RB-UI-DASH-01) | **Implemented** in commit `390fd84` (header, banner, 8 KPI cards, 6 quick actions, 5-tab nav). Not visually verified in this discovery | `features/dashboard/presentation/widgets/*` |
| Requirement card freeze, notification nav (RB-REQ-FREEZE-01, RB-NOTIF-KEY-01) | Regression tests present and passing | `work_desk_freeze_repro_test`, `notification_navigation_crash_test` |

## 3. Unverified historical claims

- RB-DRILL-01's per-metric "VERIFIED" records (`DL-0001…`, `REQ-102…`, `OFF-202…`) against a remote DB that RB-DB-SEC-01 says was empty and permissionless.
- "Physical device verification" claims in RB-DASH-FIX-01 / RB-DRILL-01 (screenshots exist in `docs/`; not reproduced).
- Whether `supabase/seed_broker_demo_dataset.sql` was applied remotely.

## 4. Architectural decisions (observed, not necessarily endorsed)

- D-01: Broker identity = `auth.uid()`; `public.users.id = auth.users.id`.
- D-02: Trusted role in `app_metadata`, synced by the `trg_sync_privileged_role` trigger; self-role change blocked by RLS `WITH CHECK`.
- D-03: Flutter talks to Supabase directly with the anon key + user JWT; RLS is the authorization boundary. Next.js REST is an optional authoritative layer (mostly unbuilt).
- D-04: `deal_versions` and `negotiation_events` are append-only legal records (0034).
- D-05: Matching is recommendation-only; it never reserves stock.
- D-06: Roadmap modules use `ModulePlaceholderScreen` rather than fake screens (dispatch, disputes).

## 5. Security constraints

Never bypass RLS, never ship a service-role key, never add broad grants, never use another broker's data to make screens look populated. Any change to auth, RLS, grants, schema, or deal/booking write semantics is a **controlled audit sprint** with an approval gate.

## 6. Outstanding approval gates

| Gate | Needed for | Owner |
|---|---|---|
| G-1 Read-only remote DB inspection (schema, policies, grants, FKs, counts) with an approved credential | verifying KI-10…18, KI-30, KI-42, and historical claims | Admin |
| G-2 Apply 0036–0041 (if not applied) | any live data | Admin |
| G-3 Deal write-path redesign (server RPC/transaction, bookings, confirmations) | KI-10…16 | Product + Admin |
| G-4 Decide confidential-price visibility and confirmation semantics (does the broker attest, or do the parties sign off in their own apps?) | KI-32, KI-12 | Product |
| G-5 Remove or label demo data modules (invoices, commission payments, broadcast) | KI-01…06 | Product |
