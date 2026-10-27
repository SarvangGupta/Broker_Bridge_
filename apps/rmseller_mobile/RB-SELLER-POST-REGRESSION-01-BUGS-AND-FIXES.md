# RB-SELLER-POST-REGRESSION-01 — Bugs and Fixes

All bugs below were found in this sprint by reading the current code and confirmed by tests. Fixed bugs have a regression test that would fail without the fix.

## Fixed
| ID | Sev | Bug | Root cause | Fix | Regression test |
|---|---|---|---|---|---|
| BUG-01 | High | Changing the broker on a **demo lot** "succeeded" and stuck until restart | `updateCommodityBroker` wrote into the static `_baselineCommodities` list | Removed that write. Online, non-UUID lot IDs are rejected; offline, only session-cache lots can change | `seller_lot_e2e_test`: zero-row and unregistered-broker cases; `commodities_repository_test` sample-lot pattern |
| BUG-02 | High | A broker change that changed **no row** (RLS, wrong company) reported success | `.update()` without `.select()`; only exceptions were treated as failure | `.select('id, broker_id')`; zero rows throws `BrokerUpdateException`; the screen shows only the confirmed ID | *another company's lot: zero-row update is an error*; *failed broker change keeps the confirmed broker* |
| BUG-03 | High | Picking a broker with a non-UUID ID **cleared** the lot's broker (`broker_id = NULL`) and reported success | `cleanId` fell back to `null` for an invalid ID | Invalid broker IDs are rejected before any request. FK violation 23503 gets a clear message | *unregistered broker id is rejected, never cleared*; *broker FK violation (23503)* |
| BUG-04 | High | With a backend, a **failed read or an empty result showed demo lots** as if they were the seller's | `getCommodities` swallowed fetch errors and fell back to `_baselineCommodities` when empty | Online: a fetch error throws `CommodityListException` (Home and My Commodities show their retry state); empty returns `[]`. Sample lots remain **offline-only** | *empty server result is an empty list*; *a failed read is an error*; *a posted lot replaces the empty state* |
| BUG-05 | Med | Every server-read lot showed the broker as **"Assigned Mandi Broker Desk"**, so after a confirmed change the real name was lost on re-read | Hard-coded placeholder in the list mapping | The broker's `name` and `mobile` are embedded through the existing FK `availabilities_broker_id_fkey` (`broker:users!…(name, mobile)`) | E2E: `brokerName` equals the embedded name before and after the change |
| BUG-06 | Med | The list, price and broker paths used the **cached or hard-coded company** (`…0101`) instead of the caller's own | Company read from storage with a demo fallback | `_requireOwnCompanyId()`: the session user's own `users.company_id`, the value RLS checks. No fallback online; no session or no company gives a clear error | E2E: list filter is `eq.<own company>` although storage held `…0101`; *seller without a company cannot post or list* |
| BUG-07 | Med | Persisted dispatch details (`loading_remarks`) were **lost on reload** | Not in the list `select` | Added `loading_remarks` to the select and mapping | E2E: `loadingRemarks` read back from the server |
| BUG-08 | High | **Cancelling** (or a failing) gallery, camera or document picker **attached a fabricated report** (fake name, fake path, `isUploaded: true`) | Fallback blocks invented an attachment when nothing was picked | Cancel attaches nothing; failure shows "Could not open the …"; real picks are `isUploaded: false` (there is no upload pipeline) | `post_commodity_screen_test`: *lab report picker cancel / failure attaches nothing* |
| BUG-09 | Med | Opening a lot by ID while the read failed left **Commodity Details spinning forever** (or, with BUG-04 fixed, would crash) | `_loadCommodity` had no error handling | Catches `CommodityListException` and shows the message with **Retry** | covered by code path; the screen test keeps passing |

## Files changed (this sprint)
| File | Change |
|---|---|
| `lib/features/commodities/data/commodities_repository.dart` | BUG-01–07: `CommodityListException`, `BrokerUpdateException`, `_requireOwnCompanyId`, `_offlineCompanyId`; rewrote `updateCommodityBroker`; `getCommodities` online path; select/mapping |
| `lib/features/commodities/presentation/commodity_details_screen.dart` | BUG-02 handling (confirmed broker ID, typed error); BUG-09 load error + Retry |
| `lib/features/commodities/presentation/post_commodity_screen.dart` | BUG-08 pickers |
| `test/support/fake_postgrest.dart` (new) | Loopback PostgREST (from RMBroker; UUID IDs) |
| `test/unit/seller_lot_e2e_test.dart` (new) | Server-protocol E2E and negative tests |
| `test/widgets/post_commodity_screen_test.dart` | +2 attachment regression tests |

## Found, not fixed (needs a decision or backend change)
| ID | Issue | Why not fixed here | Proposed action |
|---|---|---|---|
| OPEN-01 | **Retry after an ambiguous response can duplicate a lot.** If the network drops after the server commits, the seller sees an error and may resubmit; nothing prevents a second row. | Needs a DB constraint (protected) | Unique index on `availabilities (company_id, lot_number)`. The lot number is fixed per form, so a retry would hit 23505; map 23505 to "already listed". Requires approval. |
| OPEN-02 | **Server does not validate the broker relationship.** RLS lets a seller set `broker_id` to *any* user ID; the app only offers trusted brokers. | RLS change (protected) | Extend the 0044 seller WITH CHECK with `broker_id IS NULL OR` (broker role, and in the seller's trusted list). Needs approval and a decision on the trusted-broker table. |
| OPEN-03 | `updateCommodityStatus` (Fulfil/Withdraw) still reports success without server confirmation | Outside this sprint's price/broker scope | Same pattern as BUG-02 |
| OPEN-04 | Payment terms, warehouse text, office location, mandi and lab attachment are **not persisted** (no columns); they live in the session cache only | Schema change (protected) | Columns or a JSON column, plus API mapping |
| OPEN-05 | No validation that **Valid Until ≥ Available From** | No existing business rule found; not invented | Product decision |
| OPEN-06 | No **file size** limit for lab attachments | No existing rule; there is no upload | Define with the upload pipeline |
