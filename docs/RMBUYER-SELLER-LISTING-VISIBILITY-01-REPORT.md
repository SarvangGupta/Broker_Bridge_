# RMBUYER-SELLER-LISTING-VISIBILITY-01 — Report

Date: 2026-10-25 · Branch: `feature/broker-nilesh` · **Status: BLOCKED** · No code changed

## 1. Summary

I didn't build Buyer visibility of Seller listings, for three reasons:

1. **It conflicts with the approved product rules.** The Buyer PRD forbids Buyers from seeing Seller supply directly.
2. **No safe backend contract exists.** The only path a Buyer can use today returns confidential Seller fields, so showing listings would require hiding fields in the UI. The sprint itself says that isn't acceptable (§5).
3. **Lab data is not available to Buyers.** Access is denied at the database and storage level, and there's no lab data to show yet.

The sprint's own rules apply: never invent a new visibility rule, enforce authorization at the data boundary, and change no RLS or schema. Under those rules, any implementation would have broken at least one of them.

## 2. Evidence

### 2.1 Approved business rule

`docs/BrokerBridge_Buyer_PRD_v1.3_FINAL.md`, §4 "Non-Negotiable Business Rules":
- "Buyer receives Seller-side commercial supply **only through Broker Proposals**."
- "Buyer cannot browse/search a Seller directory."
- "Seller confidential minimum price and private Seller negotiation notes never reach Buyer."
- "Buyer can access only its own organization data and authorized transaction documents."

§2 lists supply discovery as a **Broker ↔ Seller** activity only. §7 says quality certificates reach the Buyer as transaction documents, inside Quality & Documents for their deals.

No existing rule authorizes a Buyer to browse Seller listings. The Buyer web app (`src/server/actions/buyer-*`) never reads `availabilities` either, which is consistent with the PRD.

### 2.2 How Seller listings are created (RMSeller → `availabilities`)

- **Write path:** `apps/rmseller_mobile/lib/features/commodities/data/commodities_repository.dart` inserts into `availabilities` with `visibility: 'global'` (the default) and `status: 'Open'`.
- **Insert policy:** the live `availabilities_insert_policy` allows only `(broker_id = auth.uid() AND (is_broker() OR is_admin())) OR is_admin()`.
- **Result:** **Seller inserts are rejected by RLS.** A signed-in Seller gets "Failed to save commodity listing to server". This was also recorded in RB-PRODUCT-GRADE-01.
- **Live data:** all 3 `availabilities` rows have a `broker_id` and `visibility = 'global'` (2 Open, 1 Reserved). None was Seller-posted.

**Root cause of "Seller-posted listings are not visible":** Sellers can't post listings at all today. Separately, the Buyer app has no listing feature, which is correct under the PRD.

### 2.3 What a Buyer can read today (live, read-only)

I simulated a buyer session (`SET LOCAL ROLE authenticated` plus buyer JWT claims) inside a read-only transaction.

| Object | Buyer access | Notes |
|---|---|---|
| `availabilities` | **SELECT on all 3 rows, all columns** | Policy: `broker_id = auth.uid() OR visibility = 'global' OR is_admin()`. Table-level SELECT grant, no column restriction. |
| `availabilities.confidential_minimum_price` | **readable: 3 of 3 rows return a value** | Contradicts PRD §4. Pre-existing **security defect** at the data boundary. |
| `availabilities.company_id`, `broker_id` | readable | Identifies the Seller organization, against PRD §2 and §4. |
| `lab_tests` | **permission denied** | No SELECT grant for `authenticated`. 0 rows. |
| `lab_test_results` | **permission denied** | No grant, no policies. 0 rows. |
| `availability_quality_values` | **permission denied** | No grant, no policies. 0 rows. |
| Storage `brokerbridge_lab_evidence` (private) | **denied to buyers** | SELECT is limited to admin/broker or a user in the availability's own company. |

Because a Buyer can technically query `availabilities` directly, the "smallest" UI change would have been to select only safe columns in the app. But the data boundary would still give any Buyer the confidential price and the Seller's identity through the API. Sprint §5 says hiding fields in the UI is not sufficient, so I didn't build it.

### 2.4 Lab reports and parameters

- **No lab data exists:** 0 lab tests, 0 results and 0 quality values in production.
- **Access is denied:** Buyers can't read the lab tables (permission denied) or the lab-evidence bucket.
- **Contract missing:** there is no Buyer-authorized lab-document contract outside the deal-document flow (`brokerbridge_documents`, which is scoped to the deal's buyer, seller and broker).

## 3. What would be needed (approval-gated; not done)

This needs an owner decision first. Only after that are the backend items possible.

1. **Product decision:** amend PRD §4 to allow Buyer discovery of Seller supply, or confirm the current rule (supply only via Broker Proposals). If the rule stands, this sprint should close and nothing should be built.
2. **If amended, a Buyer-safe read contract.** For example, a `SECURITY DEFINER` RPC or view returning only approved fields:
   - fields: product, grade, quantity and unit, asking price, state/district, available-from and valid-until, status;
   - filtered to the agreed eligibility rule (e.g. visibility `global`, status `Open`, not expired);
   - never returning `confidential_minimum_price`, `company_id`, `broker_id` or contact data.

   This is a schema/RLS change under approval gate G-x.
3. **Fix the existing column exposure regardless of the decision.** Any authenticated user can read `confidential_minimum_price` and the Seller company on global rows today. Options are to restrict the `availabilities` SELECT policy or grants to brokers/admins and the owning company, or to move Buyer reads to the safe contract. This should be added to the SEC-PRIV-01 findings.
4. **Let Sellers post listings.** The insert policy currently rejects Seller inserts, so no Seller-posted listing can exist. Fixing it needs an RLS change.
5. **Lab data for Buyers, if wanted:**
   - SELECT access to `lab_tests`, `lab_test_results` and `availability_quality_values` through the same safe contract, filtered to verified results;
   - a signed-URL path for authorized lab evidence;
   - real lab data, since all three tables are empty.

## 4. Verification

| Check | Result |
|---|---|
| 1. An eligible Seller listing appears in Buyer discovery | **Not implemented.** No existing rule makes any listing Buyer-eligible (§2.1), and Sellers can't post (§2.2). |
| 2. Restricted listings stay hidden | Buyer app reads no listings, so nothing is shown. At the data boundary, though, every global row is readable (§2.3 defect). |
| 3. Stock and demand stay separate | Unchanged. No listing code was added, and the requirement flow is untouched. |
| 4–7. Listing details, lab report open, lab parameters, honest missing states | **Blocked:** no authorized contract, and no lab data. |
| 8. Unauthorized documents and Seller contacts not exposed | The Buyer app exposes none. A data-boundary exposure of the confidential price and Seller company exists outside the app (§2.3). |
| 9. Existing search, categories, requirements, navigation | No code changed, so nothing could regress. Not re-tested this sprint. |
| Formatter / analyze / tests | **Not run:** no code changes. |

**How this was checked:** read-only inspection only, inside `BEGIN READ ONLY` transactions with the buyer simulation rolled back. No rows were created or modified, and no test listings were made.

## 5. Git diff

No source changes. The only new file is this report, `docs/RMBUYER-SELLER-LISTING-VISIBILITY-01-REPORT.md`, which is uncommitted. The inspection scripts live in the session scratchpad, not the repo.
