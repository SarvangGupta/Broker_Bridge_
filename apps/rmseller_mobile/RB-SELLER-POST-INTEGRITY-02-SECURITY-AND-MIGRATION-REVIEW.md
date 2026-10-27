# RB-SELLER-POST-INTEGRITY-02 — Security and Migration Review

Everything here comes from **read-only** inspection (`BEGIN READ ONLY … ROLLBACK`) of project `imztlkvkxzeaekxvmcfe` (production; there is no staging) on 2026-10-27, plus code review. **No database change was made.**

## 1. Live facts used
| Fact | Value |
|---|---|
| `availabilities` rows | 3 (2 Open, 1 Reserved) |
| Indexes on `availabilities` | primary key only |
| Duplicate `(company_id, lot_number)` groups | 0 |
| Lot numbers shared across companies | 0 |
| NULL `lot_number` | 0 |
| Status check constraint | none |
| Seller↔broker relationship table | **none** (tables: `crm_contacts`, `crm_activities`, `crm_tasks`, `profiles_broker`) |
| `crm_contacts` | `broker_id, user_id, company_id` (broker-side CRM link) |
| Storage buckets | `brokerbridge_lab_evidence`, `brokerbridge_documents`: private, **no size or MIME limit** |
| Columns for payment terms / warehouse / office / report file on lots | **none** |

## 2. Duplicate protection: proposed 0045 (OPEN-01)
- **Trace:**
  1. `createCommodity` inserts with `RETURNING`.
  2. If the server commits but the response is lost, the app throws `ListingSubmitException` (generic) and keeps the form, **with the same lot number**.
  3. A retry inserts **a second row**. Reproduced in `seller_lot_integrity_test`: 2 rows.
  4. There is no idempotency key and no uniqueness.
- **Uniqueness scope:** `(company_id, lot_number)`.
  - Lot numbers are generated client-side (`LOT-` + timestamp digits), so they are not globally unique.
  - Live data has no cross-company reuse today, but nothing guarantees it, and a global key would let one company block another.
- **SQL:** `supabase/proposed/0045_unique_company_lot_number.sql`.
  - A guard aborts if duplicates exist.
  - Then: `CREATE UNIQUE INDEX … ON availabilities (company_id, lot_number) WHERE lot_number IS NOT NULL`.
  - Rollback: `rollback_0045.sql` (drops the index only).
- **App readiness:** already implemented and tested. 23505 becomes "Lot `<n>` is already listed…", and only one row results.
- **Risk:** very low. 3 rows, the index build is instant, no policy change.

## 3. Broker assignment: proposed 0046 (OPEN-02)
- **Verified:**
  - The 0044 seller INSERT and UPDATE branches check only company ownership.
  - `broker_id` is an FK to `users(id)`, so **a seller can assign any user ID**: a buyer, another seller, or a deactivated broker.
  - The assigned user then gets the existing `broker_id = auth.uid()` SELECT and UPDATE rights on that lot.
  - This is a real escalation path *for the chosen user*. It **does not** let the seller reach other companies' lots.
- **Can a trusted relationship be verified with existing schema?** Only partly:
  - There is no seller↔broker table.
  - `crm_contacts` records the broker's contacts, but the Seller App does not use it to build "My Trusted Brokers" (it lists all brokers).
  - Requiring a CRM link would block brokers the app currently offers.
- **SQL:** `supabase/proposed/0046_seller_broker_assignment_check.sql`.
  - The seller branch additionally requires `broker_id IS NULL OR` an **active** `users.role = 'broker'`.
  - INSERT and UPDATE WITH CHECK only. Broker and admin branches are unchanged.
  - Rollback: `rollback_0046.sql` restores the 0044 text exactly.
  - The file includes a validation plan and a pre-check for existing lots with invalid brokers.
- **Stricter option (needs a product decision):** add a seller↔broker relationship table and require membership.

## 4. Migration 0044: decision support (unchanged)
- **State:** **applied to production only** (since 2026-10-27, FIX-01). 3 policies and the guard trigger are present (re-verified today). Neither applied nor rolled back in this sprint.
- **Staging readiness:** there is no staging project or branch. `scripts/apply-migration-0044.mjs` (with `--dry-run`) is ready to point at one.
- **Production risk if kept:** validated by 10/10 in-transaction impersonated checks on production. Residual gaps:
  - OPEN-02 (broker choice, proposed 0046);
  - broker-managed edits of seller `company_id` (existing broker trust).
- **Risk if rolled back:** sellers again cannot insert, read their own restricted lots, or update price, status or broker. The rollback itself is clean; no seller lots exist yet that depend on it.
- **Seller accounts lacking a company:** 4 (`00000000-…-0201` to `…0204`), all placeholder CRM contacts **without a login**. Both real seller logins are linked. Nothing was assigned or modified.

## 5. Other security-relevant findings
| Finding | Severity | Status |
|---|---|---|
| Lab-test UPI payment is marked "Paid — Payment Verified" via `simulateSandboxVerification: true` on every build | **Critical (false payment confirmation)** | Reported, not changed (protected payment logic). Needs approval |
| Lab-testing card falls back to `'RSL-REPORT-VERIFIED'` | Medium | Reported (same protected flow) |
| `brokerbridge_lab_evidence` INSERT policy allows **any** authenticated user to upload to any path | Medium | Reported (storage RLS; protected). The path should be tied to the caller's company's `availability_id` |
| Payment terms, warehouse and office text, lab attachment are session-only | Data integrity | Documented; needs schema approval |

## 6. Approvals needed (none applied)
1. 0045 (duplicate protection): low risk, recommended.
2. 0046 (broker must be an active broker): recommended; decide whether a stricter relationship table is wanted.
3. The lab payment simulation flag: urgent.
4. 0044: keep or roll back (pending since FIX-02); a staging target, if one will be provided.
5. Lab-report upload: size and MIME limit decision, plus storage INSERT policy tightening.
