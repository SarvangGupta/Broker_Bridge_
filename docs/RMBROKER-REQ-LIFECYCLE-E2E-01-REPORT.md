# RMBROKER-REQ-LIFECYCLE-E2E-01 — Report

Date: 2026-10-25 · Branch: `feature/broker-nilesh` · **Status: PASS WITH LIMITATIONS** · Uncommitted

**Scenario:** Rohan (buyer) creates a requirement and assigns it to Varun (broker). Varun then:
1. opens the notification;
2. reaches the requirement;
3. matches seller lots;
4. allocates and creates a deal;
5. records confirmations;
6. finalizes or cancels.

**What works now in RMBroker mobile:** that whole path works against the live schema and RLS rules. It is covered by automated tests that use fakes.

**What was not verified live:** no step was executed against production. Writes were deliberately not performed (§8).

## 1. Root causes found

| # | Root cause | Effect for Varun | Evidence |
|---|---|---|---|
| R1 | The requirement query embedded `companies!inner(...)`. `companies` RLS shows a broker only the companies in their CRM directory, so the inner join dropped every assigned requirement whose buyer was not a CRM contact. | Live: Varun is assigned **15** requirements, but only **5** appeared, and **neither** of Rohan's latest two (Maize DDGS, Broken Rice) was among them. The broker could not find the requirement at all. | Read-only RLS simulation as Varun: 15 assigned rows are visible, but only 5 have a visible buyer company. Rohan's company is not in Varun's `crm_contacts`. |
| R2 | The `notify_requirement_brokers` RPC writes `action_url = '/work?tab=0'`. `resolvedRoute` returned that URL unchanged and ignored `payload.requirementId`. | Tapping the notification opened the generic Requirements list. | All 7 live `REQUIREMENT_CREATED` rows have `/work?tab=0` plus a `requirementId` in the payload. |
| R3 | `RequirementDetailScreen` only looked the id up in the already-loaded list. It never fetched or refreshed the record. | With R1, a deep link always showed "not found in the active broker portfolio". There was no refresh, and no state for not-assigned or closed records. | Code |
| R4 | `WorkScreen` ignored `initialRequirementId`. | "Find Matching Offers" (`/work?tab=2&reqId=…`) opened an empty Match Center. | Code |
| R5 | Deal creation and the allocation list embedded `availabilities.seller_id`, a column that does not exist (it is `company_id`). | Every deal creation failed after the allocation had already been written. Each retry wrote another allocation. | Live: all 5 allocations are `CONFIRMED` with `deal_id = null`. Three were created by the mobile app on 2026-10-19. |
| R6 | The allocation fallback inserted a `CONFIRMED` row with no reservation and no `fulfilled_quantity` change. It compared quantities in different units without converting. The matcher offered lots of **other products**, scoring up to 65 = "Good Match". | Over-allocation and wrong-product allocations. | Live: lot `…202` has 40 available but 90 allocated. Requirement `…105` (Soybean Seed) was allocated against lot `…203` (Sharbati Wheat). The web engine treats a commodity mismatch as a hard filter (`match-engine.ts:107`). |
| R7 | The deal lifecycle writes did not fit the live schema (details below). | Amend, confirm and finalize all failed on mobile; cancel left quantities reserved. | Live schema, policies and trigger source (§5) |
| R8 | The deal detail screen read confirmations only from version-status substrings, so the live status `Confirmed` counted as neither party. A hard-coded demo deal was returned for any id containing `0042`. | Wrong confirmation state; fabricated deal shown. | `deal_repository.dart` (KI-03) |
| R9 | The notification feed merged 7 hard-coded demo notifications (KI-01). The card showed `context_reason` instead of `message`, so live rows read "Direct mandate notification from verified buyer" with no quantity or commodity. | Unreadable and fabricated alerts. | Code; live row shape |
| R10 | The requirement detail screen showed `fulfillmentPercentage × 100` (the value is already 0–100). | 50% showed as "5000% Fulfilled". | Code |

**R7 — deal lifecycle writes that did not fit the live schema:**
- Terms amendment inserted a `change_reason` column that does not exist.
- Version history also selected `change_reason`.
- Confirmation rewrote `snapshot_payload`, which trigger `prevent_deal_version_snapshot_tampering` rejects. `deal_versions` also has **no UPDATE policy** for `authenticated`.
- Finalize inserted a `broker_id` column that does not exist into `bookings`, and omitted the NOT NULL `locked_version_id`.
- Cancel had no status guard, set no `closed_at`, and released allocations without restoring stock.

## 2. Fixes (smallest safe changes; no schema, RLS, auth, RPC or backend changes)

### Notifications and deep links
- **Routing by record id:** `resolvedRoute` now uses record ids from the payload or URL before the generic `action_url`:
  - deal → `/deals/<id>`;
  - requirement → `/requirements/<id>`;
  - seller offer → `/work?tab=1&offerId=<id>`.
- **Unsafe ids:** ids are path-checked; unsafe values fall back to the section.
- **Card content:** the card shows:
  - the message;
  - a reference line built from the payload, e.g. `#REQ-107DF7 · 35 MT · ₹28,000/MT · FOR Mill Delivery, Kota Mandi`;
  - the context/sender line.
- **Narrow phones:** the header and action rows no longer overflow.
- **Demo data:** the demo notifications (KI-01) were removed. An empty feed shows the empty state.

### Requirement detail
- **Fresh load:** the screen loads the requirement by id from the database (new `WorkRepository.getRequirementById`) and refreshes on open and on pull-to-refresh.
- **States:** the screen distinguishes:
  - not found (deleted or not visible);
  - not assigned to this desk (read-only);
  - closed (Cancelled, Expired, Fulfilled, Fully Allocated: no actions);
  - load error with retry.
- **Linked records:** a new section lists the allocations and deals for the requirement, and each deal opens directly, so the requirement link is never lost.
- **Fulfilled %:** now shown correctly.
- **Buyer company (R1 fix):** the embed is now a plain (left) embed. When RLS hides the buyer company, the screen shows "Buyer company not in your directory", is not marked verified, and shows no trust chip, instead of the previous invented "Verified Buyer · 90% Trust".

### Matching
- **Product filter:** lots of another product are excluded, matching the web engine.
- **Pending deep links:** `WorkScreen` acts on `reqId`: tab 2 selects the requirement in the Match Center; otherwise it opens the detail screen. It also acts on `offerId` by opening that offer.
- **Fresh balances:** the Match Center re-selects with fresh balances whenever requirements or offers reload.

### Allocation (seller lot ↔ requirement)
The direct-database fallback now follows the web `proposeAllocationAction` + `confirmAllocationAction` rules:
1. Re-read the requirement and the lot. Check that the requirement is assigned to this broker, the status is eligible, the product is the same, and the lot is active and still valid. Check the remaining balance, with lot stock **converted to the requirement unit**. Check that this broker manages the lot (RLS would otherwise silently skip the update).
2. Reuse a reserved allocation of the same lot and quantity that never reached a deal, instead of writing a duplicate. Legacy rows without `confirmed_at` are never reused.
3. Insert `PROPOSED`. Reserve stock with an optimistic lock on `availabilities.version`. Raise `fulfilled_quantity` with compare-and-set. Then mark `CONFIRMED`. If any step fails, the earlier steps are compensated (released or cancelled).

The allocation sheet works in the requirement's unit and guards against double taps. If the deal step fails, it keeps the allocation and offers **Retry Deal Creation**, which reuses it rather than allocating again.

### Deal creation
- **Columns:** uses `availabilities.company_id` for the seller.
- **Guards:** web-style guards: the allocation must be `CONFIRMED` and owned by this broker, and neither linked record may be inactive.
- **Quotations:** reuses an existing quotation for the same requirement and lot.
- **Idempotent:** if the allocation already has a deal, that deal is returned and nothing is written.
- **Snapshot:** the version-1 snapshot carries the requirement, allocation and quotation links, both company ids, and `buyerConfirmed/sellerConfirmed = false`.

### Confirmation, amendment, finalization, cancellation
Version rows are immutable from the app (trigger plus no UPDATE policy). Confirmation progress is therefore written to `deals.status` using the existing lifecycle values:
- `Awaiting Seller Confirmation` = buyer confirmed;
- `Awaiting Buyer Confirmation` = seller confirmed;
- `Ready to Finalize` = both.

This matches the seeded live data (deal 3 `Awaiting Buyer Confirmation` / version `Seller Confirmed`; deal 4 the reverse). A terms amendment resets the deal to `Negotiation`, which clears confirmations, as on the web. Reads combine the deal status, the version status and snapshot flags (`DealVersionConfirmation`).

| Action | Change |
|---|---|
| Confirm | Ownership and closed-status guards, plus the stale-version guard. A repeated confirmation writes nothing. Compare-and-set on the previous deal status. |
| Amend | Closed-deal guard. Inserts the new version with the reason inside the snapshot, and carries the record links forward. No longer writes a column that does not exist. |
| Finalize | Both confirmations required. One booking per deal: `bookings_deal_id_unique` makes a retry or double tap reuse the existing booking. Sets `locked_version_id`. Deal → `Finalized` + `closed_at`; quotation → `Broker Finalized`. A late repeat on a finalized deal returns its booking. |
| Cancel | Web rules: Finalized, fulfilment and Completed deals cannot be cancelled; `closed_at` is set; linked allocations are `RELEASED`, and lot stock and requirement balance are restored. |

### Status display
- **`Allocated`:** the live requirement status `Allocated` is now Fully Allocated (it previously fell through to "Open").
- **Allocated `Open` rows:** shown as Partially or Fully Allocated from their remaining quantity, so a fully allocated requirement is not presented as an active opportunity.

## 3. Files changed

**RMBroker (13 lib files)**

| File | What changed |
|---|---|
| `app/router/app_router.dart` | `offerId` |
| `features/notifications/data/notification_repository.dart` | Demo seed removed |
| `features/notifications/domain/notification_model.dart` | Id routing, reference/detail line |
| `features/notifications/presentation/widgets/notification_card.dart` | Content and narrow-width layout |
| `features/work/data/work_repository.dart` | `getRequirementById`, left company embed, product hard filter, `activeBrokerId` |
| `features/work/domain/match_model.dart` | `isSameCommodity` |
| `features/work/domain/requirement_model.dart` | Status mapping and derivation |
| `features/work/domain/unit_utils.dart` | `tryParse`, `convertBetween` |
| `features/work/presentation/screens/requirement_detail_screen.dart` | — |
| `features/work/presentation/work_screen.dart` | — |
| `features/deals/data/deal_repository.dart` | — |
| `features/deals/domain/deal_model.dart` | `DealVersionConfirmation` |
| `features/deals/presentation/widgets/create_allocation_sheet.dart` | — |

**Tests**

| File | Status |
|---|---|
| `test/support/fake_postgrest.dart` | New: loopback in-memory PostgREST |
| `test/features/deals/deal_lifecycle_repository_test.dart` | New: 31 tests |
| `test/features/work/requirement_lifecycle_unit_test.dart` | New: 16 tests |
| `test/features/notifications/notification_lifecycle_routing_test.dart` | New: 5 widget flows |
| `notification_repository_test.dart` | Rewritten: it asserted the demo seed |
| `notification_navigation_crash_test.dart` | Fixture: the shell-route case now has no record id |
| `notification_widgets_test.dart` | Phone viewport |

**Docs:** this report and `KNOWN-ISSUES-AND-DECISIONS.md`.

No changes were made to the web app, Supabase migrations, RLS, grants, RPCs, auth or the RMBuyer/RMSeller apps. Existing uncommitted work (directory, broadcast and earlier reports) was not touched.

## 4. Tests and checks (exact results)

| Check | Result |
|---|---|
| Baseline before changes (full RMBroker suite) | 357 / 357 passed |
| `flutter analyze` (whole package) | **No issues found** |
| Full RMBroker suite after changes | **408 / 408 passed** |
| `flutter build apk --release` | **Built** `app-release.apk` (63.3 MB) |

**What the new tests cover:**
- **Notification payloads:** the live `REQUIREMENT_CREATED` row resolves to `/requirements/<id>`. Formatting is checked, and so are a broker `DEAL_VERSION_UPDATE` with a Buyer URL, deal and offer routing, deal-over-requirement precedence, and unsafe ids.
- **Deep-link flow (widget, real router), notification → detail → Match Center → allocation → deal:**
  1. opens the right requirement and marks it read once;
  2. shows buyer, price, delivery and 0% fulfilled;
  3. the Match Center pre-selects the requirement, with the other-product lot excluded;
  4. the allocation sheet's first deal step fails, and the retry creates the deal with **one** allocation call;
  5. the deal opens.
- **Other detail states:** not assigned (read-only), deleted (not found), closed (no actions, linked deal opens), and a double tap opens once and marks read once.
- **Record retrieval:** by id without the broker filter; NOT_FOUND for missing rows; no query for malformed ids. Assigned requirements whose buyer company is hidden are still listed.
- **Allocation, through the fake PostgREST:**
  - write order and the version lock;
  - kg→MT conversion;
  - 9 guards that write nothing: other broker, unassigned, cancelled, fully allocated, over-remaining, other product, lot of another desk, inactive lot, over-lot;
  - a concurrent lot change and a requirement race, both compensated;
  - idempotent reuse.
- **Deal creation:** company ids, snapshot links, quotation reuse, idempotent repeat, unconfirmed allocation refused.
- **State transitions:** buyer → seller confirmation leading to Ready to Finalize with no version updates; repeat confirmation is a no-op; stale version rejected; closed deal rejected. Finalize is checked for locked version, no `broker_id`, quotation status, the not-confirmed block, duplicate booking reuse, and a late repeat. Cancel restores both balances, and a finalized deal cannot be cancelled. Amendment creates a new version and resets confirmations. Reads select only existing columns. Deal detail reads confirmations from the deal status, returns NOT_FOUND for a missing deal, and the demo fallback is gone.

## 5. Read-only live verification (production, `BEGIN READ ONLY`, rolled back; no personal data printed)

**Users and assignment**
- Rohan is `buyer`. Varun's live account is **`varun@gmail.com`**: no `varun@gmaill.com` account exists. Varun is an active `broker`.
- Rohan's two most recent requirements (Maize DDGS 35 MT ₹28,000; Broken Rice 35 MT ₹16,000) have `broker_id` = Varun.
- Their notifications exist with `requirementId` in the payload.

**Simulated as Varun (`role authenticated` + JWT `sub`)**
- 15 assigned requirements are visible, but only 5 of their buyer companies.
- Commodity, grade and unit masters are visible for all 15.
- All 3 seller lots are Varun's, with their seller companies visible.
- Allocations 5, deals 9, versions 9, bookings 2 and quotations 9 are visible.
- All 9 of his notifications carry a `requirementId`.

**Policies the new writes depend on**
- UPDATE exists on `deals`, `availabilities`, `requirements`, `requirement_allocations` and `quotations`.
- INSERT exists on `bookings`, `deal_versions`, `deals`, `quotations` and `requirement_allocations`.
- There is **no UPDATE on `deal_versions`**.
- The trigger blocks snapshot edits.
- There is no unique constraint on `quotations(requirement_id, seller_availability_id)` or `deals(quotation_id)`, so duplicate prevention is done in the app (§2).

**Statuses in live data**
- Requirements: `Open`, `Proposed to Buyer`, `Expired`, `Allocated`.
- Lots: `Open`, `Reserved`.
- Quotations: `Accepted`, `Sent`, `Rejected`.
- Deals: Draft, Negotiation, Awaiting Buyer/Seller Confirmation, Finalized, Dispatch Pending, Completed, Cancelled, Disputed.
- Units: `kg`, `MT`, `Qtl`.

## 6. Not verified end to end (honest list)

1. **No live write was executed.** Creating, allocating, confirming, finalizing or cancelling on production was prohibited, and there is no staging project. Every write path is verified only against the fake PostgREST with the live column names, policies and statuses (§5).
2. **No device run:** the APK was built but not driven on a phone in this sprint.
3. **Buyer response:** RMBuyer cannot read deals or quotations (RLS, see the RMBUYER-NOTIFICATION-CENTER-01 report). The buyer's acceptance is recorded by the broker ("Record Buyer Confirmation"), as designed in RMBroker. Buyer-side review was not tested.
4. **Seller offer → broker notification (reverse flow):**
   - No producer exists in any app or backend: there are zero live offer notifications.
   - Seller lot inserts are blocked by RLS (RB-PRODUCT-GRADE-01).
   - Only the receiving side was built and unit-tested: offer payload routing and opening the offer in the Work Desk.
5. **Post-finalization operations:** dispatch, delivery and "Completed" are placeholder modules in RMBroker (`/orders`). The deal stops at Finalized in mobile.
6. **Proposal to buyer:** the Work Desk "submit proposal" fallback (KI-18) was not changed or tested in this sprint.

## 7. Approvals needed (not done; each needs owner approval)

| Item | Why | Proposal |
|---|---|---|
| A1 (RLS) | Varun cannot see the name of the buyer company on 10 of his 15 assigned requirements (KI-46). | A broker-scoped `companies` SELECT for companies of requirements or lots assigned to that broker (name and verification only), or a SECURITY DEFINER RPC returning the buyer name. |
| A2 (data) | Legacy allocations (KI-50): 5 `CONFIRMED` rows with no deal, 3 of them from the old mobile path with no reservation. Lot `…202` is over-allocated; requirement `…105` holds a wrong-product allocation. | Owner decides whether to release or cancel them. |
| A3 (RPC/product) | Notifications were sent for 2 requirements that have no `broker_id` (`0459a227…`, `eed5c51a…`). They now open read-only as "not assigned". | Decide whether the notify RPC should require or set the assignment. |
| A4 (schema) | Buyer payment terms, packaging and notes are not stored: `requirements` has no columns for them, and the Buyer insert drops them (KI-49). | Add columns, or store them in a related table. |
| A5 (backend) | The mobile allocation and deal steps are compensated client sequences, not a transaction (KI-15). | A SECURITY DEFINER RPC or a served REST route under root `app/` (KI-40/44). |
| A6 (web) | Web `recordPartyConfirmationAction` rewrites `snapshot_payload` (rejected by the trigger), and `createDealFromAllocationAction` writes **user** ids into `deals.buyer_id/seller_id` (the FKs reference `companies`) (KI-51). | Fix in a web micro-sprint. |

## 8. Safety statement

- **No production writes:** no production requirements, offers, allocations, deals, bookings or notifications were created, changed or closed.
- **Live access:** all live access was `BEGIN READ ONLY` with rollback, using scripts kept in the session scratchpad.
- **No sensitive output:** no credentials, emails or phone numbers were printed.
- **No commits or pushes.**
