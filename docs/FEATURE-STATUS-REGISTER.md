# RMBroker — Feature Status Register

Baseline: HEAD `390fd84`, 2026-10-24. Test baseline: `flutter test` 295/295 pass, `flutter analyze` 0 issues (run 2026-10-24).
**Test caveat:** automated tests exercise models, widgets, and the REST/Dio path with mocks. **No test exercises any Supabase query**, which is the path production actually uses. "Covered" below means "has unit/widget tests", not "verified against a live backend".

Status legend: **IMPL-UNVERIFIED** = implemented, not verified live · **PARTIAL** · **BROKEN** = write path invalid against repo schema · **DEMO** = presents fabricated data · **PLACEHOLDER** · **BLOCKED** (backend/DB dependency) · **NOT FOUND**.

| # | Feature | Status | Key files (`apps/rmbroker_mobile/lib/…`) | Backend dependency | Tests | Known defects | Next action |
|---|---|---|---|---|---|---|---|
| 1 | Home Dashboard & 8 metrics | IMPL-UNVERIFIED | `features/dashboard/**` | deals, requirements, availabilities, disputes; RLS 0038 | repo (REST only), models, screen, drill-down nav | count ≠ list for most cards (§A); fabricated trend badges; static `LIVE`; disputes error → 0; commission = ₹50×qty all-time | RB-DASH-RECON-01 |
| 2 | Work Desk – buyer requirements | IMPL-UNVERIFIED | `features/work/**`, `requirement_detail_screen.dart` | requirements (+broker_id), companies RLS | models, widgets, freeze repro, tap | errors shown as "pending backend exposure"; `!inner` joins hide rows; cancel reports success on 0-row update | include in recon sprint |
| 3 | Seller offers / lots | IMPL-UNVERIFIED | `work_repository.dart`, `offer_*` | availabilities | models, widgets | `confidential_minimum_price` fetched for all global offers (§Security) | security review |
| 4 | Matching | IMPL (client-only) | `match_model.dart`, `matches_controller.dart` | none | `match_engine_test` | recommendation only, by design | — |
| 5 | Allocations / partial allocation | PARTIAL | `deal_repository.dart` (`proposeAllocation`, `confirmAllocation`), `create_allocation_sheet.dart` | requirement_allocations | `allocation_model_test` | inserted directly as `CONFIRMED`; no inventory reservation; `fulfilled_quantity` never updated, so the dashboard's Partially Allocated card ignores in-app allocations | RB-DEAL-WRITE-01 |
| 6 | Deal creation | BROKEN | `createDealFromAllocation` | quotations, deals, deal_versions | `deal_model_test`, widgets | selects non-existent `availabilities.seller_id`; 4 non-atomic writes; no idempotency | RB-DEAL-WRITE-01 (approval gate) |
| 7 | Negotiation (deal terms) | BROKEN | `updateDealTerms`, `negotiate_terms_sheet.dart` | deal_versions, negotiation_events | `negotiation_widget_test`, `version_engine_test` | `change_reason` column; wrong negotiation_events columns; supersede-before-insert partial state | RB-DEAL-WRITE-01 |
| 7b | Requirement proposal to buyer | PARTIAL | `submitRequirementProposal`, `negotiate_requirement_sheet.dart` | REST `/requirements/:id/proposal` (exists) or deal_versions | `requirement_negotiation_test` | Supabase fallback blocked by deal_versions RLS (request_id ≠ deal) | verify REST path live |
| 8 | Buyer/seller sign-off | BROKEN | `recordPartyConfirmation`, `record_party_confirmation_dialog.dart` | deal_versions | widgets | updates immutable `snapshot_payload` (0034) and has no UPDATE policy; the broker attests on the parties' behalf | product decision + RB-DEAL-WRITE-01 |
| 9 | Deal finalize / booking | BROKEN | `finalizeDeal`, `finalize_deal_dialog.dart` | bookings | widgets | `bookings.broker_id` not a column; `locked_version_id` missing; booking ref from 4 ms digits (collision) | RB-DEAL-WRITE-01 |
| 10 | Deal status transitions | PARTIAL | `deal_model.dart` | deals.status text | `deal_model_test` | no DB constraint; unknown strings → `draft` | recon sprint |
| 11 | Deals list & detail | IMPL-UNVERIFIED + DEMO | `deals_screen.dart`, `deal_detail_screen.dart` | deals, bookings embed | `deals_widget_test` | list includes `broker_id IS NULL`; **hardcoded fake detail for ids containing `0042`/`0891`**; `bookings` embed needs an FK absent from the repo | RB-FAKE-DATA-01 |
| 12 | Dispatch & logistics | PLACEHOLDER | route `/orders` → `ModulePlaceholderScreen` (RB-LOG-01) | dispatches tables exist | — | "Dispatch Due" derived from deal status only | roadmap |
| 13 | Commission ledger & earnings | DEMO / PARTIAL | `features/commission/**` | none (derived from deals) | calculator, model, widgets | ₹50/MT hardcoded; dispatched/delivered/accepted qty = contracted; invoiced = commission; payments only in memory (reported "Confirmed"); 6 static demo records used when there is no Supabase user and checked first by `getDealCommission` | RB-FAKE-DATA-01, then a ledger design sprint |
| 14 | Invoices / statements / reconciliation | DEMO | `features/invoices/**` | no table; `apiClient` null by default | model, reconciliation, widgets | always in-memory demo data | RB-FAKE-DATA-01 (hide or label) |
| 15 | Disputes & mediation | PLACEHOLDER | route `/disputes` (RB-DIS-01); dashboard reads `disputes` | disputes table + RLS | — | Quick Action "New Dispute" opens a deals filter, not a dispute flow | roadmap |
| 16 | Directory / counterparties | IMPL-UNVERIFIED | `features/directory/**` | crm_contacts, users, companies; REST exists | models, repo, screen, phone utils | REST `toggle-status` vs server `status` path mismatch | small fix sprint |
| 17 | Global search / quick dial | IMPL-UNVERIFIED | `features/search/**` | 5 tables | screen, models, repo, sheet | voice search deferred (placeholder dialog) | — |
| 18 | Notifications | IMPL-UNVERIFIED + DEMO | `features/notifications/**` | notifications (S/U only) | model, repo, nav crash, tap, widgets | **7 demo notifications merged into every user's feed** | RB-FAKE-DATA-01 |
| 19 | Tasks | IMPL-UNVERIFIED + DEMO | `features/tasks/**` | crm_tasks (0036) | model, repo, widgets | **6 demo tasks merged in**; fallback `brokerId 'broker-demo-user'` | RB-FAKE-DATA-01 |
| 20 | Market price broadcast | BROKEN + DEMO | `features/broadcast/**` | notifications insert (no grant) | broadcast tests | non-UUID id; failures swallowed; every recipient counted as sent; history auto-generated | RB-FAKE-DATA-01 + backend design |
| 21 | Profile | IMPL-UNVERIFIED | `features/profile/**` | users, companies + local extras | `broker_profile_test` | some fields only stored locally | verify columns |
| 22 | Settings | IMPL | `features/settings`, `more/widgets/app_settings_section.dart`, `core/preferences` | local | settings tests | — | — |
| 23 | Authentication | IMPL-UNVERIFIED | `features/authentication/**` | Supabase Auth, users | auth repo, login, access denied | `users.full_name` query fails silently, so the role comes from editable `user_metadata`; no router guard; 401 handler not wired | RB-AUTH-HARDEN-01 (controlled) |
| 24 | Voice / video calling | NOT FOUND | `phone_utils.dart` (`tel:`, `wa.me`) | — | phone utils | — | — |
| 25 | Reports / history | NOT FOUND (only broadcast history, deal version history) | — | — | — | — | roadmap |

---

## §A. Dashboard metric reconciliation (current code)

The dashboard queries Supabase directly (the REST `/broker/dashboard` route doesn't exist). The destination lists apply **client-side** filters over their own, differently scoped queries.

| Card | Dashboard source & predicate | Route | Destination predicate | Reconcilable? | Discrepancies |
|---|---|---|---|---|---|
| Active Deals | deals `broker_id = uid`; status ∉ {Closed, Cancelled, Completed} | `/deals?filter=active` | deals `broker_id = uid OR NULL`; enum ∉ {cancelled, completed} | **No** | `Closed`→draft (list counts, dashboard doesn't); `Delivered`→completed (dashboard counts, list doesn't); null-broker rows (if RLS not applied) |
| Open Requirements | requirements `broker_id = uid`; status ∈ {Open, Partially Fulfilled, Partially Allocated}; no expiry check | `/work?tab=0&status=open` | `RequirementStatus.open` only; date-expired → Expired; `!inner` company join | **No** | partial statuses counted but not listed; expired counted; unknown statuses (`New`, `Allocated`, `Sourcing`) listed as open; RLS-hidden companies drop rows |
| Partially Allocated | status ∈ {Partially Fulfilled, Partially Allocated} OR 0 < fulfilled < qty | `/work?tab=0&status=partially_allocated` | status enum only | **No** | quantity rule only on dashboard; in-app allocations never update `fulfilled_quantity` |
| Available Offers | availabilities `broker_id = uid OR global`, status = `Open`, available > 0, no expiry check | `/work?tab=1&status=open` | `OfferStatus.open` (unknown→open), date-expired excluded, no qty check, `!inner` company | **No** | expiry, qty, and unknown-status handling differ |
| Awaiting Sign-off | 9 strings: Draft, Proposed, Countered, Seller/Buyer Confirmed, Awaiting Confirmation, Awaiting Buyer/Seller Confirmation, Ready to Finalize | `/deals?filter=signoff` | enum ∈ {draft, awaitingBuyer, awaitingSeller, readyToFinalize} | **Partially** | every unknown status (`Closed`, `Booking Confirmed`, …) → draft lands in the list; `Negotiation` in neither |
| Dispatch Due | Dispatch Pending, Booking Confirmed, Finalized, In Fulfillment | `/deals?filter=dispatch_due` | enum ∈ {finalized, inFulfillment} (Dispatch Pending, In Transit, Active map to inFulfillment) | **Partially** | `Booking Confirmed` → draft in list; `In Transit`/`Active` listed but not counted; dispatches table not consulted |
| Commission Ledger | Σ agreed_qty × ₹50 for broker deals ≠ Cancelled (all-time; field is named `commissionThisMonth`) | `/commission` | same formula over `broker_id = uid OR NULL` | **Mostly** | null-broker deals; period label; not a ledger |
| Open Disputes | `disputes` status = Open AND deal ∈ broker deals; **error → 0** | `/deals?filter=disputed` | deals.status = `Disputed` | **No** | different tables entirely; a query failure looks like a genuine zero |

Additional dashboard issues: trend badges are computed from the count itself (`> 3 ? '+2' : '+1'`) rather than from history; the `LIVE` badge is constant; `dataSourceNotice` claims "verified". `DashboardDataUnauthorized` shows a message but doesn't route to login. Loading, error, and unavailable states are distinguished (RB-DASH-FIX-01), except for disputes.
