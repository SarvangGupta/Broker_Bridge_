# RMBUYER-NOTIFICATION-CENTER-01 — Report

Date: 2026-10-25 · Branch: `feature/broker-nilesh` · **Status: PASS WITH LIMITATIONS** · Uncommitted

The Notification Center now shows only real backend rows, persists read state and routes safely. **However, no live Broker action currently delivers a notification that a Buyer can open in-app, and the end-to-end Broker→Buyer verification is BLOCKED** (§6, §9). Backend fixes are required and listed in §11.

## 1. Root cause of the original behaviour

`BuyerNotificationsRepository.getNotifications` (before):
- caught every error, and returned **three hardcoded rows** ("Counterparty Quote Received", "Requirement Allocated", "Shipment Dispatched") whenever the query failed **or returned nothing**;
- because no Buyer has any notification row in production (§4), every Buyer saw only those fabricated rows;
- had no read-state writes, no targets and no routing;
- had a widget test that *asserted* the mock rows.

## 2. Files changed

| File | Change |
|---|---|
| `lib/features/notifications/domain/buyer_notification_model.dart` | Maps the real columns (`context_reason`, `read_at`, `action_url`, `payload`) without inventing values; `createdAt` is nullable. Adds `NotificationTarget.resolve` (strict URL and payload allowlist, UUID validation, no text parsing) |
| `lib/features/notifications/data/buyer_notifications_repository.dart` | **Removed the mock fallback.** The fetch throws on failure; latest 50, newest first, deduplicated by ID. Adds `markAsRead` (confirmed by the returned row), `markAllAsRead` (returns the confirmed IDs) and `isOwnRequirement` (company-ownership check) |
| `lib/features/notifications/presentation/buyer_notifications_screen.dart` | Rewritten Notification Center (§5) |
| `lib/l10n/app_localizations.dart`, `lib/l10n/translations.dart` | 21 new interface keys × 7 languages; a `trN` helper for counts |
| `test/support/fake_notifications_repository.dart` (new) | Fake repository; test-only rows shaped like the real server writers |
| `test/unit/buyer_notification_model_test.dart` (new) | Mapping, resolver, dedupe and labels |
| `test/widgets/notifications_screen_test.dart` | Rewritten: it previously asserted the mock rows |

No Broker, Seller, web, database, RLS, grant, RPC or trigger changes.

## 3. Verified backend contract (live, read-only)

- **Table:** `public.notifications`. Fields used: `id, user_id, title (NOT NULL), message, context_reason, event_type, is_read (default false), read_at, created_at, action_url (NOT NULL, default '/seller'), payload jsonb`.
- **RLS:** `notifications_select_policy` and `notifications_update_policy` are both `user_id = auth.uid() OR is_admin()`. `authenticated` has SELECT and UPDATE, but **no INSERT**.
- **Buyer isolation (simulated buyer session):** visible rows 0, other users' rows visible 0.
- **Read semantics:** the same as the web Action Center (`is_read OR read_at`); writes set both.

## 4. Live notification inventory (counts only)

| event_type | Recipient role | action_url root | Rows |
|---|---|---|---|
| `REQUIREMENT_CREATED` | broker | `work?tab=0` | 5 |
| `DEAL_VERSION_UPDATE` | **broker** | **`/buyer/requirements`** (a Buyer URL) | 2 |

**No Buyer has any notification.**

## 5. Notification Center (implemented and tested)

- **Rows:** real rows only, with a title (or the event label if the title is empty), message, event-category chip and timestamp.
- **Read/unread:** an unread dot plus bold title and tinted card, and an "N unread" count derived from the fetched set.
- **All / Unread filter:** the data supports read state, so this filter is real.
- **Mark all read:** shown only when there are unread rows. It updates only the IDs the server returned.
- **Tap a row:**
  1. If unread, `markAsRead`. The local state changes only after the server returns the updated row. On failure the row stays unread and a message is shown.
  2. Repeated taps are ignored while the server call is in flight.
  3. The target resolves and opens (§7).
- **States:** loading, empty ("No Notifications"; never sample data), error with retry, pull-to-refresh (a failed refresh keeps the shown rows and reports the error), and "Showing your latest 50" when the page limit is reached.
- **Long text:** titles clamp to 2 lines and messages to 3; the full text is in the detail sheet.
- **Unknown or missing fields:** unknown event types show as "Update"; a missing timestamp is hidden; missing targets open the detail sheet.
- **Badge:** the app shows no notification badge anywhere today (the Home bell has none), so per the sprint rule none was added. The unread count is shown in the Notification Center.

## 6. Broker-action event matrix

Broker actions that notify Buyers exist only in the **web Broker portal** (Next.js server actions, inserting through `queueNotificationAction` with the bypass-RLS connection). **RMBroker mobile creates no notification that can succeed:** its only insert (`market_broadcast_repository.dart:254`) is denied, because `authenticated` has no INSERT.

| # | Broker action (source) | Notification produced | Intended Buyer recipient? | Visible to Buyer? | Destination in RMBuyer | Status |
|---|---|---|---|---|---|---|
| 1 | Send landed proposal to Buyer (`broker-buyer-actions.ts:264`) | `DEAL_VERSION_UPDATE`, `/buyer/requirements`, payload `requirementId` | **No: `userId: brokerId`** (company = buyer's) | **No** (RLS `user_id = auth.uid()`). Confirmed live: 2 such rows owned by a broker | Would open the requirement after the ownership check (implemented) | **BLOCKED: backend recipient bug** |
| 2 | Create deal draft (`broker-deal-actions.ts:623`) | `DEAL_VERSION_UPDATE`, `/broker/deals/<dealId>` | Yes (first user of the requirement's company) | Yes, if generated (0 live rows) | Detail sheet: "can't be opened in the app yet". Buyers have no SELECT on `deals` | **Displayed; route BLOCKED (RLS)** |
| 3 | Dispatch contract for signatures (`broker-confirmation-actions.ts:150`) | `FINAL_CONFIRMATION_REQUIRED`, `/buyer/confirmations?requestId=<quotationId>` | Yes | Yes, if generated (0 live rows) | Detail sheet. Buyers have no SELECT on `quotations` | **Displayed; route BLOCKED (RLS)** |
| 4 | Finalize deal / booking (`broker-deal-actions.ts:1183`) | `BOOKING_CREATED`, `/broker/deals/<id>` | **No: `userId: deal.buyerId`, which is a company ID** (9/9 deals) | No | Detail sheet if it ever arrived | **BLOCKED: backend recipient bug** |
| 5 | Broker counter / negotiation (`broker-negotiation-actions.ts:223`, `broker-request-actions.ts:570`, `broker-outbound-actions.ts:202`) | `BROKER_COUNTER` / `NEGOTIATION_RECEIVED` / `NEW_BROKER_REQUEST` | No: Seller-side or broker | — | — | Not a Buyer event |
| 6 | Requirement acknowledgement / acceptance | none exists | — | — | — | **No backend event** |
| 7 | Order, dispatch and delivery updates (`dispatch-actions.ts:296,315`) | `DEAL_UPDATED` | Seller and broker only | — | — | **No Buyer event** |
| 8 | Document uploads, payment events | none generated | — | — | — | **No backend event** |
| 9 | Proposal updated or withdrawn | none generated | — | — | — | **No backend event** |

**Recipient isolation** is enforced by RLS (verified). The app adds no client-side recipient logic, and requirement targets get an extra company-ownership check, because `requirements_select_policy` also exposes other companies' open global requirements.

## 7. Routes implemented

| Target | Resolution (backend references only) | Behaviour |
|---|---|---|
| Requirement | `/buyer/requirements/<uuid>`, or `/buyer/requirements` with `payload.requirementId` (uuid), or `payload.requirementId` | `isOwnRequirement`. If true, push `/requirements/<id>`; if false, detail sheet "unavailable or no access"; if the check fails, a message |
| Requirements list | `/buyer/requirements` without an ID | `go('/requirements')` |
| Deal | `/(buyer\|broker)/deals/<uuid>` or `payload.dealId` | Detail sheet "can't be opened in the app yet". The Buyer deal screen would fall back to a **demo deal**, because buyers can't read `deals` |
| Broker proposal | `/buyer/confirmations?requestId=<uuid>` or `payload.quotationId` | Detail sheet (same reason: the offer screen falls back to session/sample offers) |
| Order, dispatch, document, payment, support ticket | no Buyer-facing producer or destination | Detail sheet |

**Refused references:** malformed IDs, Seller/Broker-only URLs, `../` paths and IDs found only in message text resolve to "no target" (unit-tested).

## 8. Tests and checks (exact results)

| Check | Result |
|---|---|
| `dart format` (notification files and new tests) | applied |
| `flutter analyze` (whole RMBuyer package) | **No issues found** |
| Focused tests (`buyer_notification_model_test`, `notifications_screen_test`, `l10n_coverage_test`) | **38 passed** |
| **Full RMBuyer suite** (`test/widget_test.dart`, `test/widgets`, `test/unit`) | **263 passed, 4 skipped** (opt-in live tests), 0 failed |
| `flutter build apk --debug` | **Built** `app-debug.apk` |

**What the widget tests cover (13):**
- real rows render, with no mock rows;
- empty and error states, and retry;
- deduplication;
- an owned-requirement tap navigates to `/requirements/<id>`;
- an unowned requirement shows the unavailable detail;
- a deal tap marks read, then shows a detail sheet with no navigation;
- a failed mark-as-read keeps the row unread and shows a message;
- a rapid double tap sends 1 request;
- mark-all-read updates the count;
- the Unread filter;
- an unknown type or empty title gets the label and detail sheet;
- pull-to-refresh reloads.

**Unit tests (7):** mapping, the read rule, resolver accept/refuse cases, dedupe and labels.

Two defects in my own code were found by the tests and fixed: a locale-data crash in date formatting, and a spinner that kept animating while the detail sheet was open.

## 9. End-to-end verification

**BLOCKED.**
- **No safe environment:** there is no separate test or staging Supabase project; the apps and tests point at production.
- **Prohibited:** generating a Broker action would write production data.
- **No real rows to observe:** no live Buyer notification exists, and the main proposal path addresses the broker, not the buyer.

Verification therefore covers the repository contract (live RLS and grants, read-only), code tracing of every producer, and automated tests with fakes. **No Broker→Buyer delivery was demonstrated end to end.**

## 10. Limitations

- **Unread count:** derived from the latest 50 rows. The screen says when the limit is reached, and there is no unread-count endpoint.
- **Timestamps:** use the English date format, for all languages.
- **Deal and offer destinations:** blocked by RLS. The Buyer deal and offer screens themselves still contain demo fallbacks (out of scope here; flagged).
- **No Home badge:** none existed before, and none was added.

## 11. Required follow-up micro-sprints (each needs approval)

1. **RB-NOTIF-RECIPIENT-01 (web backend, small):**
   - `broker-buyer-actions.ts:264`: send the proposal notification to the Buyer user (resolved from `req.companyId`), not `brokerId`;
   - `broker-deal-actions.ts:1183`: resolve the Buyer **user** from `deal.buyerId` (a company ID);
   - use Buyer URLs and payload IDs (`dealId`, `quotationId`) instead of `/broker/deals/...`.
2. **RB-BUYER-DEAL-ACCESS-01 (RLS, security review):** a Buyer-scoped SELECT on `deals`/`quotations`, or Buyer-safe RPCs, for the Buyer's own company only, excluding Seller-confidential fields. After that, remove the demo fallbacks in `buyer_deals_repository.getFinalDealReview` and `offers_repository.getOfferById`, then enable the deal and offer routes.
3. **RB-NOTIF-EVENTS-01 (product + backend):** define the Buyer events that don't exist yet: requirement acknowledgement, proposal withdrawn/updated, dispatch/delivery/document/payment to the Buyer.
4. **RB-BROKER-MOBILE-NOTIF-01:** RMBroker mobile notification inserts are denied (no INSERT grant). Move them to a server-side RPC instead of granting INSERT.
5. **Staging environment:** to enable a real end-to-end Broker→Buyer test without production writes.

## 12. Preservation statement

All existing uncommitted work (RMBuyer profile/language, RMSeller quantity/price, and earlier reports) was preserved; changes in this sprint are limited to the files in §2 and this report. No database, schema, RLS, grant, auth, trigger or RPC changes were made, and no production data was written. No commits, pushes or deployments.
