# RB-SELLER-COMMODITY-BROKER-NOTIFY-01 — Report

**Status:** Code and tests done. **BLOCKED on production approval** of proposed migration 0065. Nothing has been applied to the database.

## Root cause
RMSeller writes `availabilities` directly through PostgREST (create, price, status, broker change in `commodities_repository.dart`). Nothing on the server or client created a broker notification for these writes. The only broker-notifying path was the buyer-side `notify_requirement_brokers` RPC (0040).

## Mechanism
`supabase/proposed/0065_seller_listing_broker_notifications.sql` adds an `AFTER INSERT OR UPDATE OR DELETE` row trigger on `availabilities`. It is `SECURITY DEFINER` and inserts `IN_APP` rows into the existing `notifications` table. The broker Alerts screen already reads that table.

- **Same transaction as the change.** Failed, rejected or rolled-back saves send nothing. A committed save always has its notification, even if the app closes.
- **Recipient** is the row's own `broker_id`, which must be an active broker. The client never names recipients. The helper function is revoked from `anon` and `authenticated`.
- **Seller actions only.** Edits by brokers, admins or the service role (for example deal reservations) do not notify. The acting user is never notified.
- **Duplicates.** A no-op or identical retry produces no column diff, so nothing is sent. A unique `idempotency_key` (`avl:<lot>:<broker>:<event>:<txid>`) stops repeat inserts.
- **Change detection** is a generic JSON diff, so columns added later (payment terms, warehouse) are covered without editing the trigger.
- **Payload.** It never includes `confidential_minimum_price` or any buyer data. The notification's `company_id` is the broker's own firm.
- **Reassignment.** The new broker gets "Commodity listing assigned to you". The previous broker gets nothing.
- **Removal.** The seller app's Cancel sets a status, and sellers have no DELETE policy, so a status of Cancelled or Withdrawn is sent as "Commodity listing removed". A hard DELETE path is also handled using the pre-delete row data. The notification stays readable after the row is gone, and the broker Work screen shows "This seller offer is no longer available…".
- **Deep link.** `payload.availabilityId` is resolved by the existing broker route to `/work?tab=1&offerId=<id>`.

Rollback: `supabase/proposed/rollback_0065.sql`. It drops the trigger and helper functions. A commented-out DELETE removes the delivered rows if needed.

## Files changed
- `supabase/proposed/0065_seller_listing_broker_notifications.sql` (new, not applied)
- `supabase/proposed/rollback_0065.sql` (new)
- `supabase/proposed/0065_tools/listing_broker_notify_offline_test.mjs` (new)
- `apps/rmbroker_mobile/lib/features/notifications/domain/notification_category.dart`: the 10 new `AVAILABILITY_*` event types now map to Requirements & Offers. Before this change they would have fallen into System.
- `apps/rmbroker_mobile/test/features/notifications/seller_listing_notification_test.dart` (new)

RMSeller code needed no change.

## Verification
| Level | Result |
|---|---|
| SQL trigger, offline (PGlite with stub schema and the real 0048 RLS, run as `authenticated` sessions) | **36/36 pass** |
| RMBroker `test/features/notifications/` | **73/73 pass** (11 new) |
| `flutter analyze` on the changed files | No issues |
| Real database | **Not performed.** Requires approval. |
| Push delivery | **Not applicable.** The codebase has no push provider (no FCM or OneSignal), so only in-app rows are created. |
| Device | Not performed |

## Spec tests not met
- **#2 Multiple brokers:** `availabilities` has a single `broker_id`. The seller form collects `selectedBrokerIds` but saves only the first one. Supporting several brokers would need a new assignment table, which is a schema change and needs a decision.
- **#17 Hindi:** the broker app has no localization, and every existing notification is stored in English. Hindi content needs broker-app l10n first.
- **#12 Cancelled edit:** a cancelled edit makes no write, so no notification is sent. The no-op case is tested.

## Remaining limitations
- The test schema is a stub built from the repo migrations, not a production extract. Before applying 0065, run a read-only check that `availabilities`, `notifications.idempotency_key` (unique), `master_units.symbol` and `companies.name` match.
- Individual sellers appear by their user name, and company sellers by their company name.

## Approval needed
Apply 0065 to production. It adds 1 trigger and 3 functions, with no table, RLS or grant changes.
