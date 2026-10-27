# RB-SELLER-INDIVIDUAL-LISTINGS-02 — Audit Report

## 1. Executive Summary & Business Decision Alignment
Under the approved business decision **RB-SELLER-INDIVIDUAL-LISTINGS-02**:
- **Sellers without a company** may post and manage individual commodity supply lots.
- Each individual lot is owned by the authenticated seller's trusted database identity (`seller_user_id = auth.uid()`).
- **Company-linked sellers** preserve their existing company-owned listing workflows (`company_id`).
- Company linkage is **optional** for seller access and individual lot ownership, but a **trusted seller database identity** is mandatory.
- Zero client-supplied company IDs, mock companies, or self-asserted roles are trusted.

---

## 2. Phase 1 — Trusted Seller Identity Audit

### 2.1 Live Account Inspection
The live database was inspected (read-only) for the two accounts identified in the previous sprint:
1. `seller.bikaner@gmail.com` (`4e21f195-2f3b-465d-94cc-e47eebd92800`)
2. `seller@demo.com` (`49534f2f-ec4e-445f-84e8-7d09c7056b6a`)

**Findings:**
| Field | `seller.bikaner@gmail.com` | `seller@demo.com` |
|---|---|---|
| Exists in `auth.users`? | Yes | Yes |
| `raw_user_meta_data->>'role'` | `'seller'` (self-asserted) | `'seller'` (self-asserted) |
| `raw_app_meta_data->>'role'` | Missing (`{}`) | Missing (`{}`) |
| Exists in `public.users`? | **No** (missing record) | **No** (missing record) |
| Provisioned Company? | None | None |

### 2.2 Root Cause: Why These Accounts Lack Trusted User Records
1. **Separation of Auth and App Data:** Supabase Auth registers users into `auth.users`. In this repository, `public.users` is populated explicitly during web registration via Drizzle ORM in `signUpAction`.
2. **Missing Auth Trigger:** The database lacks an automatic `ON INSERT` trigger on `auth.users` to provision `public.users`.
3. **Client-Editable Metadata:** `raw_user_meta_data` can be edited by any authenticated client via `supabase.auth.updateUser()`. Therefore, `raw_user_meta_data` is untrusted and rejected by Row Level Security (RLS) policies.
4. **Trusted Role Sync:** The database trigger `trg_sync_privileged_role` on `public.users` calls `sync_privileged_role_to_auth()`, which copies the trusted `public.users.role` to `auth.users.raw_app_meta_data->>'role'`. Because the accounts never had a row in `public.users`, their `raw_app_meta_data` remained empty, leaving them unprovisioned.

### 2.3 Safe, Repeatable Identity-Provisioning Solution
We prepared `supabase/proposed/provision_individual_seller_identity.sql`:
- **Function:** `public.provision_individual_seller(p_email text, p_full_name text, p_mobile text DEFAULT NULL)`
- **Security:** `SECURITY DEFINER` with explicit `search_path = public, auth`, restricted to `service_role` and `postgres`.
- **Idempotency:** Looks up `auth.users` by email. If a `public.users` record exists, it updates `role = 'seller'`; if missing, it inserts the record with `company_id = NULL`.
- **Preserves Existing Accounts:** Does not re-create or delete auth credentials.
- **Synchronizes App Metadata:** Triggers `sync_privileged_role_to_auth()` to update `raw_app_meta_data->>'role' = 'seller'`.
- **Status:** Stored as an unapplied proposed script pending production administrative approval.

---

## 3. Phase 2 — Individual Listing Data Model Audit

### 3.1 Review of `supabase/proposed/0047_individual_seller_listings.sql`
The proposed `0047` migration introduced `seller_user_id uuid REFERENCES public.users(id)` and dropped `NOT NULL` on `company_id`.

**Key Observations:**
1. **Ownership Invariant:** Every lot must be either company-owned or individual-owned, never both and never neither:
   ```sql
   CONSTRAINT availabilities_owner_check CHECK (
     (company_id IS NOT NULL AND seller_user_id IS NULL)
     OR (company_id IS NULL AND seller_user_id IS NOT NULL)
   )
   ```
2. **Derivation of Ownership:** For individual listings, RLS `WITH CHECK` enforces `seller_user_id = auth.uid()`. Client-supplied owner IDs cannot override authentication.
3. **Cross-Seller Isolation:**
   - Company sellers only see and edit lots belonging to their verified company (`u.company_id = availabilities.company_id`).
   - Individual sellers only see and edit lots where `availabilities.seller_user_id = auth.uid()`.
   - Global listings (`visibility = 'global'`) remain readable by all authenticated parties for trading discovery.
4. **Duplicate Lot Number Protection:**
   - Company lots: `UNIQUE (company_id, lot_number)`
   - Individual lots: `UNIQUE (seller_user_id, lot_number)`

---

## 4. Phase 3 — Migration Reconciliation (0044, 0045, 0046, 0047 → 0048)

### 4.1 Migration Analysis Matrix
| Migration | Scope | Conflict / Overlap | Resolution in 0048 |
|---|---|---|---|
| **0044** | Baseline RLS on `availabilities` | Required `company_id NOT NULL` and company-only seller policies. | Replaced by reconciled policies in 0048 supporting dual ownership. |
| **0045** | Unique `(company_id, lot_number)` | Unique constraint failed if `company_id` is null or if duplicates existed. | Converted to partial unique index `WHERE company_id IS NOT NULL AND lot_number IS NOT NULL`. |
| **0046** | Active Broker Validation in RLS | Enforced `broker_id` must reference an active broker with `role = 'broker'` and `status = true`. | Preserved in 0048 for both company-owned and individual-owned listings. |
| **0047** | `seller_user_id` and dual ownership | Proposed dual ownership without 0046's active-broker validation. | Unified with 0046 in 0048. |

### 4.2 Preflight Integrity Check on Live Database
Before creating the proposed migration, a read-only preflight check was run on the live database:
- Duplicate `(company_id, lot_number)`: **0**
- Duplicate `(seller_user_id, lot_number)`: **0**
- Owner check violations (`both null` or `both set`): **0**
- Active broker violations (assigned broker not active): **0**
- Total live lots: **3** (all company-owned, with broker `b354958e-779a-41f2-b7a3-5899eca32e32`).

### 4.3 Proposed Reconciled Migration
- Created `supabase/proposed/0048_reconciled_seller_listings_and_broker_check.sql` which combines 0045, 0046, and 0047 with preflight data checks.
- Created `supabase/proposed/rollback_0048.sql` with an abort check preventing rollback if any individual listings have been created.
- **Safety Policy Compliance:** Neither migration was applied to production; both remain proposals for formal approval.
