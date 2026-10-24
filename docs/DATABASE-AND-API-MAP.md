# RMBroker — Database and API Map

Baseline: HEAD `390fd84`, 2026-10-24.
**Evidence sources:** `supabase/migrations/*.sql`, `src/server/db/schema.ts` (Drizzle), Flutter repositories. **The remote database was not inspected in this discovery.** Remote state is known only from sprint reports (RB-DASH-FIX-01, RB-DB-SEC-01), which conflict with each other in places.

---

## 1. Verified tables (repo definitions) and relationships

| Table | Key columns used by RMBroker | Defined in | FKs (repo) |
|---|---|---|---|
| `users` | id, **name** (not `full_name`), mobile, email, role, status(bool), company_id, created_by | 0001, 0037 | company_id→companies |
| `companies` | id, name, gst, status, is_verified, trust_score, created_by | 0001, 0015, 0037 | — |
| `requirements` | id, company_id, commodity_id, grade_id, unit_id, quantity, fulfilled_quantity, target_price, delivery_terms_id, target_date, status (default `Open`), visibility, **broker_id** | 0003, 0010, 0016; **broker_id only in Drizzle** | company, commodity, grade, unit |
| `availabilities` | id, company_id, commodity_id, grade_id, unit_id, state_id, district_id, total/available/reserved/sold_quantity, asking_price, confidential_minimum_price, valid_until, status, visibility, **broker_id**, loading_* | 0004, 0009, 0020, 0024; **broker_id only in Drizzle**; **no `seller_id`** | company, commodity, grade, unit, state, district |
| `quotations` | id, requirement_id, broker_id, seller_availability_id, offered_price, status, valid_until | 0005, 0007 | none |
| `deals` | id, requirement_id, quotation_id, buyer_id, seller_id, broker_id (nullable), agreed_price, agreed_quantity, status (default **`Dispatch Pending`**), created_at, closed_at | 0006 | quotation (0006); requirement, broker→users, buyer→companies, seller→companies (**0038**) |
| `requirement_allocations` | id, allocation_reference, requirement_id, availability_id, broker_id, deal_id, allocated_quantity, unit_id, allocated_price, status CHECK (`PROPOSED`,`CONFIRMED`,`COMMITTED_TO_DEAL`,`RELEASED`,`CANCELLED`), version | 0035 | requirement, availability, broker→users, deal, unit |
| `deal_versions` | id, request_id (=deal id), version_number, actor_id, status, snapshot_payload | 0027; immutability trigger 0034 | actor→users only (**no FK request_id→deals**) |
| `bookings` | id, booking_reference (unique), deal_id (unique), **locked_version_id NOT NULL**, status | 0028 | locked_version→deal_versions (**no FK deal_id→deals**) |
| `negotiation_events` | id, **request_id, company_id, actor_id, action_type, payload** | 0026; append-only trigger 0034 | company, actor |
| `dispatches` / `dispatch_documents` | deal_id, seller_id(→users), vehicle, driver, dates, status | 0011, 0029 | deal, seller, vehicle type |
| `disputes` | deal_id, filed_by, reason, status (default `Open`) | 0013 | deal, filed_by |
| `payments` | deal_id, amount, reference_number, status | 0013 | deal |
| `invoices` | deal_id, **seller_id**, invoice_no, amount, file_url | 0011 | deal, seller→users (seller invoices, not broker commission invoices) |
| `notifications` | user_id, company_id, channel, event_type, title, message, payload, delivery_status, is_read, action_url, idempotency_key (unique) | 0017, 0025, 0030 | user, company |
| `crm_contacts` / `crm_activities` / `crm_tasks` | broker_id, user_id, company_id / contact_id, type, notes / title, due_date, priority, status | 0019 | users / contacts |
| `master_*` | commodities, grades, units, states, districts, vehicle_types, quality params, labs | 0002, 0018, 0021, 0031 | — |

**Tables that do not exist** but features imply them: commission ledger, commission payments, commission invoices, broadcasts / broadcast recipients, broker profile extras.

## 2. Functions, triggers, RPCs

| Object | Migration | Purpose |
|---|---|---|
| `get_auth_role()` | 0036/0038 | SECURITY DEFINER; returns `app_metadata.role`, else `user_metadata.role` only if buyer/seller |
| `is_admin()`, `is_broker()` | 0036–0038 | role helpers |
| `sync_privileged_role_to_auth()` + trigger on `users.role` | 0037 | copies `public.users.role` into `auth.users.raw_app_meta_data` |
| `prevent_negotiation_events_mutation` | 0034 | blocks UPDATE/DELETE on negotiation_events |
| `prevent_deal_version_snapshot_tampering` | 0034 | blocks changes to `snapshot_payload`, version_number, ids; allows **status only** |
| `notify_requirement_brokers(uuid, uuid[])` | 0040 | buyer → broker notifications (SECURITY DEFINER) |

## 3. Authorization boundaries (RLS as written in repo)

| Table | SELECT | INSERT | UPDATE | Grants to `authenticated` |
|---|---|---|---|---|
| deals | broker_id = uid OR admin | broker_id = uid AND broker/admin | broker_id = uid | S/I/U |
| requirements (0039) | broker_id = uid OR own company OR (global AND status IN Open/Partially Fulfilled/Allocated) OR admin | broker or buyer-company | broker_id = uid OR own company | S/I/U |
| availabilities | broker_id = uid OR visibility = global OR admin | broker_id = uid | broker_id = uid | S/I/U |
| quotations, requirement_allocations | broker_id = uid | broker_id = uid | broker_id = uid | S/I/U |
| deal_versions | via parent deal broker | via parent deal broker | **no policy (updates hit 0 rows)** | S/I/U |
| bookings | via parent deal | via parent deal | — | S/I |
| dispatches, disputes | via parent deal OR seller/filed_by | same | same | S/I/U |
| notifications | user_id = uid | **no grant** | user_id = uid | S/U |
| negotiation_events | **no RLS/grant defined in repo** | — | — | unknown |
| users / companies (0037, 0041) | self, admin, active brokers, counterparties created by or linked to the broker | broker may create buyer/seller only | self (role locked to `get_auth_role()`) or own counterparties | S/I/U |
| crm_* (0036/0037) | broker_id = uid | broker_id = uid | broker_id = uid | S/I/U |

Identity mapping: `public.users.id = auth.users.id`; `broker_id` columns store `auth.uid()`. This is consistent across the repo, and RB-DB-SEC-01 reports it holds for test broker "Varun". **Whether 0036–0041 are applied remotely is unverified.** RB-DB-SEC-01 (10-19) states 0038 was *not* applied and the remote DB had 0 policies, no SELECT grants, and 0 operational rows.

## 4. Screen → repository → query map

| Screen | Repository method | REST tried first | Supabase fallback (table / filter) | Schema validity |
|---|---|---|---|---|
| Dashboard | `DashboardRepository.fetchDashboardData` | `GET /broker/dashboard` (missing) | deals `eq broker_id`; requirements `eq broker_id`; availabilities `or(broker_id.eq, visibility.eq.global)` + `status=Open`; disputes `status=Open`; recent deals | valid if Drizzle `broker_id` columns exist remotely |
| Work Desk – Requirements | `WorkRepository.getRequirements` | `GET /broker/requirements` (missing) | requirements `eq broker_id` + `companies!inner`, `master_commodities!inner`, grades, units | valid; inner joins drop rows when the company isn't visible under companies RLS |
| Work Desk – Offers | `getOffers` | `GET /broker/offers` (missing) | availabilities `or(broker_id, global)` + `companies!inner`… | valid; **returns `confidential_minimum_price` for all global offers** |
| Create requirement / offer | `createRequirement` / `createOffer` | POST (missing) | insert with broker_id = uid | valid |
| Requirement detail / proposal | `WorkRepository.getRequirementNegotiationDetails` / `submitRequirementProposal` | `GET/POST /broker/requirements/:id/proposal` (**exists**; Drizzle, code-level ownership check) | requirements, quotations, deal_versions (`request_id` = quotation id or requirement id), negotiation_events (correct columns); sets requirement status `Proposed to Buyer` | **deal_versions RLS (0038) only admits `request_id` = an owned deal id, so the Supabase-path proposal insert/read is denied** |
| Deals list | `DealRepository.getDeals` | `GET /broker/deals` (missing) | deals `or(broker_id.eq.uid, broker_id.is.null)` + requirements, buyer/seller companies, `bookings(booking_reference)` | `bookings` embed needs FK bookings.deal_id→deals (**absent in repo**) |
| Deal detail | `getDealDetail` | `GET /broker/deals/:id` (missing) | same select + latest deal_versions | same; **hardcoded fake fallback for ids containing `0042`/`0891`** |
| Allocations | `getAllocationsForRequirement`, `proposeAllocation`, `confirmAllocation` | `/broker/allocations*` (missing) | requirement_allocations | valid columns |
| Create deal | `createDealFromAllocation` | `POST /broker/deals/create-from-allocation` (missing) | select `availabilities(id, seller_id, companies!seller_id(name))` | **INVALID: no `availabilities.seller_id`** |
| Negotiate terms | `updateDealTerms` | `POST /broker/deals/:id/terms` (missing) | prior version → `Superseded`; insert new deal_version **with `change_reason` (not a column)**; deals update; negotiation_events insert | **INVALID: `change_reason`; negotiation_events columns invalid; supersede runs before the failing insert (partial state)** |
| Party confirmation | `recordPartyConfirmation` | `POST …/confirm-party` (missing) | **updates `deal_versions.snapshot_payload`** | **Blocked by 0034 trigger / no UPDATE policy** |
| Finalize | `finalizeDeal` | `POST …/finalize` (missing) | insert bookings `{deal_id, booking_reference, status, broker_id, created_at}` | **INVALID: `broker_id` not a column; `locked_version_id` NOT NULL missing** |
| Cancel deal | `cancelDeal` | `POST …/cancel` (missing) | deals update, allocations release | valid; success reported even if RLS matches 0 rows |
| Commission | `CommissionRepository.getCommissionRecords` | `/broker/commission/*` (missing) | deals `or(broker_id.eq, is.null)` → computed ×₹50 | valid query; values are derived, not ledgered |
| Invoices | `InvoiceRepository` | `/broker/invoices` (missing; and `apiClient` is null by default) | **none** → in-memory demo | n/a |
| Tasks | `TaskRepository` | `/broker/tasks*` (missing) | crm_tasks `eq broker_id` | valid; demo tasks merged in |
| Notifications | `NotificationRepository` | `/broker/notifications*` (missing) | notifications `eq user_id` | valid; demo notifications merged in |
| Directory | `DirectoryRepository` | `/broker/directory*` (**exists**; toggle-status path mismatch) | crm_contacts + users + companies; crm_activities | valid |
| Search | `SearchRepository` | `/broker/search`, `/broker/search/quick-dial` (missing) | crm_contacts, master_commodities, requirements, availabilities, deals | not individually verified |
| Profile | `ProfileRepository` | — | users, companies (+ local extras) | not individually verified |
| Market broadcast | `MarketBroadcastRepository` | — | insert notifications `{id:'notif-bc-…'}` | **INVALID: non-UUID id into uuid; no INSERT grant** |
| Broadcast history | `BroadcastHistoryRepository` | — | local storage; notifications read (result unused) | demo history generated |

## 5. Known schema discrepancies

1. `requirements.broker_id` and `availabilities.broker_id` exist only in Drizzle `schema.ts`, though RLS 0038 depends on them. A clean migration replay of 0001→0038 would fail at 0038.
2. `users.full_name` is queried by auth; the column is `name`.
3. `availabilities.seller_id` is queried by deal creation; it does not exist.
4. `bookings` insert uses `broker_id` and omits `locked_version_id`.
5. `negotiation_events` inserts in `DealRepository` use `deal_id/event_type/version_number/notes`; the schema has `request_id/company_id/action_type/payload`. The insert in `WorkRepository` is correct. `deal_versions` inserts in `updateDealTerms` include the non-existent `change_reason`.
5a. `deal_versions.request_id` is overloaded (deal id in the Deals flow, quotation/requirement id in the Work Desk proposal flow), while RLS assumes a deal id.
6. Embedding `bookings` from `deals` needs an FK that isn't in the repo.
7. `deal_versions` confirmation updates conflict with the 0034 immutability trigger.
8. Deal status vocabulary: the DB default is `Dispatch Pending`; the web platform uses `Proposed/Countered/Seller Confirmed/…`; the Dart `DealStatus.fromString` maps unknown strings (`Closed`, `Booking Confirmed`, `Proposed`, …) to `draft`.

## 6. Unknown / unverified contracts

- Actual remote schema, grants, policies, FKs, and row counts.
- Whether `negotiation_events` has RLS remotely.
- Response contracts of the ~28 REST endpoints RMBroker calls that don't exist (shapes in the Dart parsers are assumptions).
- RMBuyer/RMSeller write paths that create the deals and confirmations RMBroker reads.
