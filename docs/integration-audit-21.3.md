# Cross-Module Integration Audit: Micro-Sprint 21.3
**BrokerBridge Enterprise — End-to-End Buyer-to-Seller Pipeline Verification**  
**Audit Date:** September 2026  
**Auditor:** Antigravity AI Pair Programmer & Lead System Architect  
**Document Status:** Complete & Architecture-Approved  
**Audit Scope:** Cross-Module Integration between Sprints 1–12 (Core Foundation & Buyer Demand) and Sprints 13–20 (Seller Command Center & Operations)  
**Target Milestone:** Sprint 22 (Broker Command Center Shell & Execution Workflows)

---

## 1. Executive Summary: Buyer-to-Seller Data Path Health

Following the foundation audit in [docs/platform-audit-21.md](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/docs/platform-audit-21.md), Micro-Sprint 21.3 executed an in-depth cross-module integration audit. The focus was to trace the complete commercial and transactional data pipeline from Buyer demand origination through Broker mediation to Seller inventory fulfillment.

### Overall Pipeline Health: **SOUND WITH TARGETED ALIGNMENTS**
The core transactional pipeline connects demand to supply reliably at the application layer. Multi-tenant company boundaries are strictly enforced, optimistic locking prevents double-allocation, and private buyer identities remain 100% sanitized across all Seller projections.

However, because the platform evolved through distinct evolutionary phases:
- **Phase 1 (Sprints 1–8):** Simple two-sided bilateral trade (`Buyer Requirement` -> `Broker Quote` -> `Direct Buyer Acceptance` -> `Deal`).
- **Phase 2 (Sprints 13–20):** Three-sided enterprise broker mediation (`Dynamic EAV Lot Creation` -> `Broker Negotiation` -> `Seller Confirmation` -> `Pre-Flight Broker Finalization` -> `Atomic Booking` -> `Partial Dispatch Ledgers`).

This architectural evolution produced a small number of **dual-path redundancies** and **schema-level asymmetries** (e.g., missing database-level foreign key constraints in Drizzle schemas, un-synchronized demand-side fulfillment quantities during bookings, and event-ledger-based dispatch quantities). None of these represent runtime blockers, but they must be formally recognized and aligned as the Broker Command Center is implemented in Sprints 22–30.

---

## 2. Shared Data Path Trace: Demand to Supply

```
[Buyer Entity] 
      │ (owns)
      ▼
[requirements] ──────────────┐
  - company_id (FK)           │
  - commodity_id (FK)         │
  - grade_id (FK)             │
  - quantity                  │
  - fulfilled_quantity        │
  - target_price              ▼
                       [quotations / broker_requests] ◄────── [deal_versions]
                         - requirement_id (UUID)                - request_id (UUID)
                         - seller_availability_id (UUID)        - version_number (Int)
                         - broker_id (UUID)                     - snapshot_payload (JSONB)
                         - offered_price (Numeric)              - status (Enum)
                         - status (Enum)                        ▲
                              │                                 │ (confirms)
                              ▼                                 │
[Seller Entity]        [deals] ─────────────────────────────────┤
      │ (owns)           - requirement_id (UUID)                │
      ▼                  - quotation_id (FK)                    ▼
[availabilities] ◄────── - buyer_id (UUID -> companies)       [finalization_gate]
  - company_id (FK)      - seller_id (UUID -> companies)        - validates preconditions
  - total_quantity       - agreed_price (Numeric)               - locks version terms
  - available_quantity   - agreed_quantity (Float)              │
  - reserved_quantity         │                                 ▼
  - sold_quantity             ▼                               [bookings]
  - version (OCC)      [dispatches]                             - booking_reference (Unique)
                         - deal_id (FK)                         - locked_version_id (FK)
                         - seller_id (FK -> users)              - deal_id (Unique)
```

### 2.1 Entity & Relational Trace Analysis
1. **Demand Side ([requirements](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/db/schema.ts#L119)):**
   - Linked strictly via `companyId` referencing `companies.id`.
   - References `masterCommodities`, `masterGrades`, and `masterUnits` via explicit database foreign keys.
2. **Supply Side ([availabilities](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/db/schema.ts#L136)):**
   - Linked strictly via `companyId` referencing `companies.id`.
   - Contains dynamic EAV parameter relations through [availabilityQualityValues](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/db/schema.ts#L171) (`onDelete: 'cascade'`).
3. **The Commercial Intermediary ([quotations](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/db/schema.ts#L213)):**
   - Connects `requirementId` (Demand) and `sellerAvailabilityId` (Supply).
   - Serves as the base entity for Broker commercial proposals and inquiries in [broker-request-actions.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/actions/broker-request-actions.ts).
4. **Execution & Settlement ([deals](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/db/schema.ts#L227), [bookings](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/db/schema.ts#L403), [dispatches](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/db/schema.ts#L247)):**
   - `deals.quotationId` references `quotations.id`.
   - `bookings.lockedVersionId` references `dealVersions.id` and enforces `UNIQUE(deal_id)`.
   - `dispatches.dealId` references `deals.id`.

### 2.2 Database Constraint vs Application Join Finding
* **Finding:** While all Drizzle relational queries join correctly (`innerJoin(availabilities, eq(quotations.sellerAvailabilityId, availabilities.id))` and `innerJoin(requirements, eq(quotations.requirementId, requirements.id))`), several relational columns in [schema.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/db/schema.ts) (`quotations.requirementId`, `quotations.sellerAvailabilityId`, `deals.requirementId`, `deals.buyerId`, `deals.sellerId`, `bookings.dealId`) omit explicit `.references(...)` declarations at the Drizzle schema level.
* **Impact:** Application queries are completely safe and tested, but PostgreSQL does not enforce foreign key cascade checks on those specific links.
* **Tag:** `[Needs Alignment]` — Add formal Drizzle `.references(...)` annotations during schema cleanup before production release.

---

## 3. Categorized Cross-Module Relationships

| Cross-Module Relationship | Primary Components & Actions | Status | Architectural Assessment |
| :--- | :--- | :--- | :--- |
| **AI Match Engine (Demand to Supply)** | [match-actions.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/actions/match-actions.ts), [ui-match-actions.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/actions/ui-match-actions.ts), [match-engine.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/utils/match-engine.ts) | `[Needs Alignment]` | Read-only recommendation engine matches Buyer requirements against Seller lots safely. However, [match-actions.ts#L60](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/actions/match-actions.ts#L60) filters strictly by `eq(availabilities.status, 'Active')`. Legacy lots created with `'Open'` status are omitted from matching unless updated. |
| **Commodity & Grade Foundations** | [master-data-actions.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/actions/master-data-actions.ts), [schema.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/db/schema.ts#L65-L100) | `[Consistent]` | Commodities, units, and grades are strictly shared across both Buyer requirements and Seller lots. Referential integrity checks block accidental deletions of in-use master records. |
| **Quotation Acceptance vs Deal Version Handshake** | [deal-actions.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/actions/deal-actions.ts#L10), [confirmation-actions.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/actions/confirmation-actions.ts#L28), [finalization-gate.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/utils/finalization-gate.ts) | `[Needs Alignment]` | Sprint 8 legacy action `acceptQuotationAction` allows direct Buyer acceptance into `'Dispatch Pending'`. Sprint 18/19 enterprise flow enforces multi-version `Seller Confirmed` -> `Broker Finalized` -> `Booking Confirmed`. `acceptQuotationAction` should be deprecated or redirected through the finalization gate in Sprint 22. |
| **Booking Creation & Inventory Allocation** | [booking-actions.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/actions/booking-actions.ts#L199), [availabilities](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/db/schema.ts#L152), [requirements](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/db/schema.ts#L132) | `[Needs Alignment]` | When a booking is confirmed, [booking-actions.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/actions/booking-actions.ts) atomically decrements `availabilities.availableQuantity` and increments `reservedQuantity`. However, it does NOT decrement `requirements.quantity` or increment `requirements.fulfilledQuantity`. Supply is locked, but demand fulfillment is not recorded in the booking action. |
| **Logistics & Dispatch Tracking** | [logistics-actions.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/actions/logistics-actions.ts), [dispatch-actions.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/actions/dispatch-actions.ts), [schema.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/db/schema.ts#L247) | `[Consistent]` | [dispatch-actions.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/actions/dispatch-actions.ts) supports partial dispatches (`dispatch_quantity <= remaining_quantity`). Dispatches transition bookings to `'Partially Dispatched'` or `'Fully Dispatched'` and deals to `'In Transit'`. |
| **Financial Settlement & Payouts** | [settlement-actions.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/actions/settlement-actions.ts), [transaction-actions.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/actions/transaction-actions.ts) | `[Consistent]` | Accurate net payable calculation (agreed price * received weight minus quality deductions). Buyer bank details remain hidden; Seller sees only their verified payout amounts. |
| **Document Vault & Anti-Tamper Isolation** | [document-actions.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/actions/document-actions.ts), [lab-actions.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/actions/lab-actions.ts) | `[Consistent]` | Time-limited (300s TTL) pre-signed URLs. Path traversal strings (`..`, `\`, `\0`) rejected across both Seller COA uploads and Buyer invoice downloads. |

---

## 4. Specific Analysis: Mismatched Status Variables & Duplicate Logic

### 4.1 Status Enum Alignment Matrix

| Table / Entity | Schema Default | Legacy Sprint 1–12 Values | Modern Sprint 13–20 Values | Observed Discrepancy & Remediation |
| :--- | :--- | :--- | :--- | :--- |
| **`availabilities.status`** | `'Open'` | `'Open'`, `'Draft'` | `'Active'`, `'Reserved'`, `'Sold'`, `'Expired'`, `'Cancelled'` | **Discrepancy:** `availability-actions.ts` inserts `'Active'`, while `schema.ts` defaults to `'Open'`. [match-actions.ts#L60](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/actions/match-actions.ts#L60) only queries `'Active'`.<br>**Remediation:** Update match filter to `inArray(availabilities.status, ['Active', 'Open'])`. |
| **`requirements.status`** | `'Open'` | `'Open'`, `'Draft'`, `'Accepted (Booked)'`, `'Partially Fulfilled'` | Unchanged | **Discrepancy:** `booking-actions.ts` does not update `requirements.status` when a Booking is generated.<br>**Remediation:** Add `update(requirements)` step inside `createBookingAction` transaction. |
| **`quotations.status`** | `'Sent'` | `'Sent'`, `'Revised Sent'`, `'Accepted'`, `'Rejected'`, `'Countered'` | `'Proposed'`, `'Seller Confirmed'`, `'Broker Finalized'`, `'Accepted'` | **Discrepancy:** Dual vocabulary between early buyer quoting (`'Sent'`) and multi-version negotiation (`'Proposed'`).<br>**Remediation:** Handled cleanly via `verifyLatestVersion` and `isBrokerFinalized` check in booking engine. |
| **`deals.status`** | `'Dispatch Pending'` | `'Dispatch Pending'`, `'In Transit'`, `'Delivered'`, `'Closed'`, `'Cancelled'` | `'Quotation Proposed'`, `'Counter Offered'`, `'Seller Confirmed'`, `'Broker Finalized'`, `'Partially Dispatched'`, `'Fully Dispatched'` | **Discrepancy:** String casing is consistent, but status lifecycle has been extended from 4 states to 9 states.<br>**Remediation:** Standardize via a unified `DealStatus` type in `src/types/deal-schema.ts`. |
| **`bookings.status`** | `'Confirmed'` | N/A (Sprint 18 new entity) | `'Confirmed'`, `'Partially Dispatched'`, `'Fully Dispatched'`, `'Cancelled'` | **Consistent:** Transitions correctly from confirmed booking through partial dispatches. |

### 4.2 Duplicate & Overlapping Business Logic Scan

#### 1. Inventory Math Logic
- **Location 1:** [src/server/actions/inventory-math-actions.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/actions/inventory-math-actions.ts) exposes standalone helpers:
  - `reserveQuantity(availabilityId, quantity, currentVersion)`
  - `releaseReservedQuantity(availabilityId, quantity, currentVersion)`
  - `consumeReservedQuantity(availabilityId, quantity, currentVersion)`
- **Location 2:** [src/server/actions/booking-actions.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/actions/booking-actions.ts#L218-L238) implements identical quantity reservation logic inline inside its multi-entity transaction.
- **Architectural Assessment:** Inline execution inside `booking-actions.ts` is required for atomic ACID guarantees across deals, bookings, and inventory within a single PostgreSQL transaction. However, `releaseReservedQuantity` from `inventory-math-actions.ts` should be reused when building the Broker Booking Cancellation action in Sprint 27.

#### 2. Dispatch Creation Logic
- **Location 1:** [src/server/actions/logistics-actions.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/actions/logistics-actions.ts#L48) provides `createDispatchAction` (legacy single-deal dispatch).
- **Location 2:** [src/server/actions/dispatch-actions.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/actions/dispatch-actions.ts#L80) provides `createSellerDispatchAction` (Sprint 19.2 booking-centric partial dispatch with validation against remaining balance).
- **Architectural Assessment:** `dispatch-actions.ts` is the superset and production standard. `logistics-actions.ts` should remain as a fallback wrapper or be phased out during logistics consolidation.

#### 3. Zod Vehicle Number Validation Differences
- [src/types/logistics-schema.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/types/logistics-schema.ts#L8):
  `regex(/^[A-Z]{2}[0-9]{2}[A-Z]{1,2}[0-9]{4}$/)` — Strictly requires 2-digit district codes (rejects plates like `DL1A1234`).
- [src/types/dispatch-schema.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/types/dispatch-schema.ts#L23):
  `regex(/^[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{4}$/i)` — Correctly accommodates 1-digit and 2-digit RTO district codes and transforms to uppercase.
- **Remediation:** Standardize all logistics inputs on the more permissive, realistic regex from `dispatch-schema.ts`.

---

## 5. Architectural Recommendations for Sprint 22 Broker Construction

Before and during the implementation of **Sprint 22 (Broker Command Center Shell & Cockpit)**, the following alignments are recommended:

1. **Unify Match Engine Query:** In [src/server/actions/match-actions.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/actions/match-actions.ts#L60), broaden the status filter from `eq(availabilities.status, 'Active')` to `inArray(availabilities.status, ['Active', 'Open'])` so that all unbooked supply is visible to Brokers.
2. **Synchronize Requirement Fulfillment in Bookings:** In [src/server/actions/booking-actions.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/actions/booking-actions.ts#L265), add an update to `requirements`:
   ```typescript
   await tx.update(requirements).set({
     fulfilledQuantity: sql`${requirements.fulfilledQuantity} + ${dealQuantity}`,
     status: sql`CASE WHEN (${requirements.fulfilledQuantity} + ${dealQuantity}) >= ${requirements.quantity} THEN 'Accepted (Booked)' ELSE 'Partially Fulfilled' END`
   }).where(eq(requirements.id, quotationRecord.requirementId));
   ```
3. **Broker Session Guard:** Create `verifyBrokerSession` in `src/server/utils/broker-auth.ts`, mirroring the proven architecture of [seller-auth.ts](file:///c:/Users/user/Desktop/BrokerBridge/brokerbridge-enterprise/src/server/utils/seller-auth.ts).
4. **Wire Broker Inquiries to Quotations:** When building Sprint 23 Broker Inquiry features, write directly to the `quotations` table and record state in `dealVersions`, preserving seamless compatibility with Seller requests at `/seller/requests`.

---

## 6. Integration Audit Conclusion

### Verdict: **CLEARED FOR SPRINT 22 IMPLEMENTATION**
The cross-module integration across Buyer, Seller, and shared data foundations is **mathematically sound and structurally consistent**. The identified alignments are non-breaking, well-understood, and cleanly addressable as native integration tasks during the upcoming Broker Command Center Sprints.
