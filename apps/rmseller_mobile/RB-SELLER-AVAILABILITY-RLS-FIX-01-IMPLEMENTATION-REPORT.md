# RB-SELLER-AVAILABILITY-RLS-FIX-01 — Implementation Report

## 1. Application changes (applied)
| File | Change |
|---|---|
| `lib/features/commodities/data/commodities_repository.dart` | See below. |
| `lib/features/commodities/presentation/post_commodity_screen.dart` | Shows `ListingSubmitException.message`; any other error shows the generic friendly text. The raw exception is no longer displayed. Form values are kept, so the seller can retry. |
| `test/support/fake_commodities_repository.dart` | Configurable `submitError`. |
| `test/unit/commodities_repository_test.dart`, `test/widgets/post_commodity_screen_test.dart`, `test/widgets/post_commodity_quantity_price_test.dart` | New and updated tests (see the test report). |

Changes in `commodities_repository.dart`:
- **Online insert path:**
  - Requires a valid session.
  - Resolves `company_id` **only** from the signed-in user's own `users` row (`id = session.user.id`). This is the same source the proposed policy trusts. No stored value and no hard-coded fallback.
  - If the account has no company, it stops with a clear message.
- **New `ListingSubmitException`** with seller-safe messages:
  - 42501: "Your account is not yet allowed to publish listings. Please contact support."
  - Other failures: "Unable to publish your commodity right now. Please try again or contact support if the problem continues."
  - Session expired: unchanged wording.
- **Logs** contain only the Postgres error code or exception type. No row values or tokens.
- **No success without the server-returned ID** (unchanged): the session cache is written only after the insert returns.

Offline and test mode (no Supabase client) is unchanged.

**The app fix alone does not make posting work.** The database still rejects seller inserts until the policy below is approved and applied. The app now explains the failure clearly instead of showing the raw error.

## 2. Proposed database change (NOT applied, awaiting approval)
- `supabase/proposed/0044_allow_sellers_own_availabilities.sql`
- Rollback: `supabase/proposed/rollback_0044.sql`

These are kept outside `supabase/migrations/` on purpose so no runner applies them.

Every new branch uses the same ownership test:

```sql
EXISTS (SELECT 1 FROM public.users u
        WHERE u.id = auth.uid() AND LOWER(u.role) = 'seller'
          AND u.company_id IS NOT NULL
          AND u.company_id = availabilities.company_id)
```

| Part | Change | Why |
|---|---|---|
| A. INSERT | Broker and admin branches kept; **+ seller for own company** | Root-cause fix |
| B. SELECT | **+ seller reads own company's lots** | Needed for `INSERT … RETURNING` and for viewing own restricted lots |
| C. UPDATE | **+ seller updates own company's lots**; WITH CHECK stops moving a lot to another company | Price and status updates (RB-SELLER-PRICE-SYNC-FIX-01) |
| D. Trigger on `users` | Non-admins cannot change their **own** `company_id` | Without it a seller could re-point to another company and post as it |

Security properties:
- **No anon access:** policies apply only `TO authenticated`.
- **No new grants, no DELETE policy, RLS stays enabled.**
- **Sellers can't post for other sellers:** `company_id` must equal the caller's own company. Their `role` is pinned to the trusted JWT role by the existing `users_update_policy`, and their `company_id` is pinned by part D.
- **Admin and broker behaviour unchanged.**
- **Only `availabilities` policies and one guard trigger on `users` change.** No other tables are touched.

Known nuance, unchanged by this proposal: a broker-managed counterparty's `company_id` can still be edited by that broker, under the existing `users_update_policy`.

## 3. To apply (after approval)
1. Apply `0044` in a transaction against staging first, then production.
2. Run the verification plan in the test report (§3).
3. If anything regresses, run `rollback_0044.sql`.
