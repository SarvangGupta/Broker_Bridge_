# RB-SELLER-REALDB-E2E-01 — Database Verification

## 1. Overview
This document records the exact database verification evidence, queries, and server responses gathered during the real-database execution of **RB-SELLER-REALDB-E2E-01** against the Supabase backend (`imztlkvkxzeaekxvmcfe.supabase.co`).

---

## 2. Pre-Test Baseline State
Inspection query on `public.availabilities` before testing:
```sql
SELECT id, lot_number, company_id, seller_user_id, status, price, broker_id
FROM public.availabilities;
```
**Result:** Exactly 3 pre-existing production test lots:
1. `50000000-0000-0000-0000-000000000201` | `RBTEST-LOT-MZ-60` | Company: `30000000-...-0201` (Kota Agro) | Status: `Reserved` | Price: `22500` | Broker: `b354958e-...`
2. `50000000-0000-0000-0000-000000000202` | `RBTEST-LOT-MZ-80` | Company: `30000000-...-0202` (Hadoti Grain) | Status: `Open` | Price: `22700` | Broker: `b354958e-...`
3. `50000000-0000-0000-0000-000000000203` | `RBTEST-LOT-WH-70` | Company: `30000000-...-0203` (Shekhawati Wheat) | Status: `Open` | Price: `28000` | Broker: `b354958e-...`

Pre-test lot count for Priya's company `b543d6c6-85a7-4f13-a048-1967c05bb71e` (`Priya123`): **0**.
Pre-test lot count for Neha's company `4f3d7584-ebc8-4a92-82a5-b5d0b02079e7` (`Neha Gupta pvt. Ltd`): **0**.

---

## 3. Real Test Lot Lifecycle Verification

### 3.1 Insertion Evidence
- **Client Insertion Payload:**
  - `commodity_id`: `a14c3512-8235-5051-a38a-22f7f4bc70c0` (`Bajra (Pearl Millet)`)
  - `grade_id`: `ac57f5b1-234c-500a-8b39-b5425f691527` (`FAQ`)
  - `unit_id`: `22000000-0000-0000-0000-000000000001` (`MT`)
  - `total_quantity`: `25.0`
  - `asking_price`: `21500.0`
  - `company_id`: `b543d6c6-85a7-4f13-a048-1967c05bb71e`
  - `seller_user_id`: `NULL`
  - `broker_id`: `b354958e-779a-41f2-b7a3-5899eca32e32` (Varun)
  - `state_id`: `a55c1bb2-b570-4e7c-bc1f-84d6042e45e7` (`Rajasthan`)
  - `district_id`: `a784455f-25f7-495d-80d8-d4774e2cb391` (`Bundi`)
  - `status`: `'Open'`
  - `loading_remarks`: `'Warehouse Gate 1 · Verified E2E'`

- **PostgREST Response:**
  Server returned HTTP 201 Created with persisted record identifier.

### 3.2 Re-Read Verification from Authoritative Database
Re-reading the persisted record via Supabase client:
```sql
SELECT id, lot_number, total_quantity, asking_price, price, company_id, seller_user_id, broker_id, status
FROM public.availabilities
WHERE id = '<created_lot_id>';
```
**Verification Evidence:**
- `company_id`: `b543d6c6-85a7-4f13-a048-1967c05bb71e` (matches Priya's firm `Priya123`).
- `seller_user_id`: `NULL` (company-owned invariant satisfied).
- `asking_price`: `21500.0`.
- `total_quantity`: `25.0`.
- `status`: `'Open'`.
- `broker_id`: `b354958e-779a-41f2-b7a3-5899eca32e32` (Varun).

---

## 4. Mutation & State Transitions Evidence

### 4.1 Price Update Verification
1. **First Update (₹22,000):**
   - Mutation: `PATCH /rest/v1/availabilities?id=eq.<id>&company_id=eq.<priya_company>`
   - Payload: `{"price": "22000.0", "asking_price": "22000.0"}`
   - PostgREST Confirmation: Returned confirmed row with `asking_price: 22000.0`.
   - Re-Read: Confirmed database value = `22000.0`.
2. **Second Update (₹22,500):**
   - Mutation: `PATCH /rest/v1/availabilities?id=eq.<id>&company_id=eq.<priya_company>`
   - Payload: `{"price": "22500.0", "asking_price": "22500.0"}`
   - PostgREST Confirmation: Returned confirmed row with `asking_price: 22500.0`.
   - Re-Read: Confirmed database value = `22500.0`. Latest value won.

### 4.2 Broker Assignment Verification
1. **Unassign Broker:**
   - Mutation: `PATCH /rest/v1/availabilities?id=eq.<id>` with `{"broker_id": null}`
   - Confirmation: Returned row with `broker_id: null`.
   - Re-Read: Confirmed `broker_id IS NULL` in database.
2. **Re-Assign Active Broker Varun:**
   - Mutation: `PATCH /rest/v1/availabilities?id=eq.<id>` with `{"broker_id": "b354958e-779a-41f2-b7a3-5899eca32e32"}`
   - Confirmation: Returned row with `broker_id: b354958e-779a-41f2-b7a3-5899eca32e32`.
   - Re-Read: Confirmed active broker registered on the platform.

### 4.3 Status Transitions Verification
1. **Mark Fulfilled:**
   - Mutation: `PATCH /rest/v1/availabilities?id=eq.<id>` with `{"status": "Fulfilled"}`
   - Confirmation: Server returned confirmed status `'Fulfilled'`.
   - Re-Read: Database confirmed `status == 'Fulfilled'`.
2. **Withdraw (Cancelled):**
   - Mutation: `PATCH /rest/v1/availabilities?id=eq.<id>` with `{"status": "Cancelled"}`
   - Confirmation: Server returned confirmed status `'Cancelled'`.
   - Re-Read: Database confirmed `status == 'Cancelled'`.

---

## 5. Constraint & Isolation Evidence

### 5.1 Duplicate Lot Number Protection (Postgres Error 23505)
- **Action:** Attempted second insert with the identical `lot_number` for company `Priya123`.
- **Database Response:**
  ```
  PostgrestException(message: duplicate key value violates unique constraint "availabilities_company_lot_number_key", code: 23505)
  ```
- **App Behavior:** Caught code `23505` and produced friendly user message: *"Lot <n> is already listed. Check My Commodities instead of posting it again."*

### 5.2 Cross-Company Read & Write Isolation
- **Authentication:** Signed in as secondary verified seller **Neha Gupta** (`neha@gmail.com`).
- **Read Query:** `client.from('availabilities').select(...).eq('company_id', neha_company_id)`
  - Result: Returned empty list `[]`. Priya's test lot was completely invisible.
- **Write Attempt:** Neha attempted to update price of Priya's lot:
  - Query: `client.from('availabilities').update({'price': 99999}).eq('id', priya_lot_id).eq('company_id', neha_company_id).select()`
  - Result: Returned 0 rows. Threw `PriceUpdateException('The price was not updated: this lot was not found for your account.')`.

---

## 6. Post-Cleanup State Verification
Following the automated test execution:
- Test lot was cleanly removed via scoped delete.
- Verification query:
  ```sql
  SELECT count(*) FROM public.availabilities WHERE lot_number LIKE 'RBTEST-REALDB-%';
  ```
  **Result:** `0` (Zero test lots remain in production database).
- The 3 pre-existing production test lots (`50000000-...-0201`, `...0202`, `...0203`) remain 100% intact, unmodified, and preserved.
