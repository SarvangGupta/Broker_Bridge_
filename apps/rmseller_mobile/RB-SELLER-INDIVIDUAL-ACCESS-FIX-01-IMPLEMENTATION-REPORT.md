# RB-SELLER-INDIVIDUAL-ACCESS-FIX-01 — Implementation Report

## A. Completed app fixes (applied in code)
| File | Change |
|---|---|
| `lib/features/commodities/data/commodities_repository.dart` | See below |
| `lib/features/authentication/data/auth_repository.dart` | See below |

**`commodities_repository.dart`:**
- New `_ownCompanyIdOrNull()` for **reads**. It returns `null` when the seller has no `users` row or `company_id` is null. A missing or expired session, or a failed lookup, still **throws**, so errors are never reported as "no data".
- `getCommodities()` (and therefore `getPostingHistory()`, Home and My Commodities) returns **an empty list** for an unlinked seller, without querying `availabilities` (they cannot own lots).
- Writes (`createCommodity`, price, broker, status) still require a company via `_requireOwnCompanyId()`. That is genuinely required by the schema, and they keep their clear "not linked … contact support" messages.

**`auth_repository.dart`:**
- Sign-in no longer invents a company. The hard-coded `'20000000-…-0101'`, the fake firm name `'Bikaner Agro Processing Ltd'` and the fake GST were removed.
- `user_metadata.company_id` (self-editable) is **not** trusted for ownership. The company comes **only** from the server `users` row; `user_metadata.company_name` is used only as a display name.
- An unlinked seller signs in with `companyId == null`.

**Result for the device account:**
- Seller Desk opens.
- The lots metric is a legitimate 0, so the empty state shows with the existing **Post Commodity** action.
- On Post Commodity, the readiness card says the account is not linked to a business, and listing is blocked with a clear message. No fake company is used anywhere in that path.

**Not changed (reported):**
- The deals metric still comes from `seller_deals_repository` demo fallback data (sellers cannot read `deals` under RLS).
- Other repositories still carry the `…0101` fallback (audit §5).

## B. Proposed database change: NOT APPLIED
`supabase/proposed/0047_individual_seller_listings.sql` + `rollback_0047.sql`:
1. Add `availabilities.seller_user_id uuid REFERENCES users(id)`.
2. Make `company_id` nullable, with `CHECK` that exactly one of `company_id` or `seller_user_id` is set. Existing rows stay valid.
3. Add unique `(seller_user_id, lot_number) WHERE company_id IS NULL` (duplicate protection, pairing with 0045).
4. Policies = 0044 text **plus** an individual branch: `company_id IS NULL AND seller_user_id = auth.uid()` **and** the caller has a provisioned active `seller` `users` row.
   - UPDATE WITH CHECK keeps the row owned by the caller, without a company.
   - Company isolation, broker and admin branches are unchanged. No DELETE policy; no new grants; RLS stays on.
5. **Rollback** restores the 0044 policies and NOT NULL. It **aborts** if individual-owned lots exist, so nothing is silently orphaned.

**Prerequisites and app work after approval (not done):**
- **Provision** the metadata-only accounts (`49534f2f-…`, `4e21f195-…`) with `users` rows (role `seller`, `status = true`, `company_id` NULL). This is a **production data change** needing separate approval. Without it, 0047 still denies them by design, because `user_metadata` alone is not trusted.
- **App:** when the seller has no company, insert with `seller_user_id = auth.uid()` and `company_id` null; read own lots with `seller_user_id = eq.<uid>`; and mirror the same in the price, broker and status filters.
- **Merge with 0046** if both are approved.
- **Downstream dependencies:** `deals.seller_id`, negotiations and invoices use company IDs. Individual-seller deals need their own design.

## C. Security
- No company ID is fabricated anywhere in the online paths changed.
- No cross-user or cross-company access was added. The app read path returns nothing rather than querying broadly. The proposal limits individual rows to `seller_user_id = auth.uid()`.
- Self-asserted `user_metadata` grants no ownership.
- No production writes; no schema or RLS changes applied.
