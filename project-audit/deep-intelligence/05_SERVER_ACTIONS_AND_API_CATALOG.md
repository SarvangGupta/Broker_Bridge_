# 05 — SERVER ACTIONS AND API CONTRACTS CATALOG

**Document Reference:** `project-audit/deep-intelligence/05_SERVER_ACTIONS_AND_API_CATALOG.md`  
**Investigation Date:** October 17, 2026  
**Auditor:** Principal Backend Architect & Application Security Auditor  
**Project:** BrokerBridge Enterprise + VetKind Animal Health India  

---

## 1. Inventory Summary

The backend exposes **68 dedicated Server Action modules** in `src/server/actions/` containing over 140 exported functions, plus 4 API route endpoints.

Every action module was audited for client-side parameter tampering defense ("F12 Inspect defense"). The audit confirms that **zero Server Actions trust client-supplied `user_id`, `role`, or `company_id`**. All identities and organizations are derived from verified server sessions via `@supabase/ssr` or `verifyBuyerSession()`.

---

## 2. Server Action Catalog by Functional Suite

### 2.1 Buyer Procurement & Post-Deal Actions

#### `src/server/actions/buyer-requirement-actions.ts`
- **Exported Functions:** `getBuyerRequirementsListAction(filters?)`, `getBuyerRequirementDetailAction(id)`, `cancelRequirementAction(id, reason)`, `updateRequirementAction(id, payload)`.
- **Intended Role:** `BUYER_ADMIN` (Buyer).
- **Authentication Enforcement:** Invokes `verifyBuyerSession()`. Derives `session.companyId`. Rejects unauthenticated callers with `{ success: false, error: 'Unauthorized' }`.
- **Database Reads/Writes:** Reads `requirements` joined with `masterCommodities`, `masterGrades`, `masterUnits`. Updates `requirements.status = 'Cancelled'`.
- **Concurrency & State Gates:** `cancelRequirementAction` enforces state machine guard: only requirements in `'Draft'` or `'Open'` status may be cancelled. Throws error if already booked or negotiating.
- **UI Consumers:** `/buyer/requirements`, `/buyer/requirements/[id]`.

#### `src/server/actions/buyer-proposal-actions.ts`
- **Exported Functions:** `getBuyerProposalsInboxAction()`, `getBuyerProposalDetailAction(id)`, `acceptBuyerProposalAction(proposalId, expectedVersion)`, `rejectBuyerProposalAction(proposalId, reason)`.
- **Intended Role:** `BUYER_ADMIN`.
- **Authentication & Privacy:** Derives `session.companyId`. Filters out any proposals where `requirements.companyId !== session.companyId`.
- **Zero-Seller-PII Sanitization:** Invokes `sanitizeBuyerNegotiationPayload()` stripping seller phone, email, WhatsApp, and floor prices.
- **Database Reads/Writes:** Reads `quotations`, `deals`, `deal_versions`. Writes `deal_versions.status = 'Buyer Confirmed'`.
- **Optimistic Concurrency:** Compares `expectedVersion` against latest version; throws `STALE_VERSION_DETECTED` on mismatch.
- **UI Consumers:** `/buyer/proposals`, `/buyer/proposals/[id]`.

#### `src/server/actions/buyer-deal-actions.ts`
- **Exported Functions:** `getFinalDealReviewAction(dealId)`, `confirmFinalDealAction(dealId, expectedVersion)`, `requestDealAmendmentAction(dealId, expectedVersion, reason)`.
- **Intended Role:** `BUYER_ADMIN`.
- **Business Logic:**
  - `confirmFinalDealAction` operates inside a Drizzle `db.transaction()` wrapper.
  - Verifies counterparty status and version concurrency.
  - Logs immutable audit signature into `negotiation_events` (`actionType: 'BUYER_FINAL_CONFIRMATION'`).
  - Decoupled Invariant: Does NOT generate booking ID.
- **UI Consumers:** `/buyer/deals/[id]`.

#### `src/server/actions/buyer-order-actions.ts`
- **Exported Functions:** `getBuyerOrdersListAction()`, `getBuyerBookingVisibilityAction(bookingId)`, `getBuyerDispatchDocumentSignedUrlAction(path)`.
- **Intended Role:** `BUYER_ADMIN`.
- **Read-Only Invariant:** Strictly read-only; zero mutation exports.
- **Fulfillment Math:** Computes `originalQuantity`, `bookedQuantity`, `remainingQuantity`, and `fulfillmentPercentage`.
- **Security:** Validates path traversal on signed URL generation.
- **UI Consumers:** `/buyer/orders`, `/buyer/orders/[id]`.

#### `src/server/actions/buyer-quality-tracking-actions.ts`
- **Exported Functions:** `getBuyerTransactionQualityAction(bookingId)`, `getBuyerLabReportSignedUrlAction(bookingId)`, `getBuyerWeighmentSlipSignedUrlAction(bookingId)`.
- **Intended Role:** `BUYER_ADMIN`.
- **Data Shape:** Returns `BuyerTransactionQualityData` (accredited lab details, parameter comparison grid comparing target vs measured values, and gross/tare/net weighment).
- **UI Consumers:** `/buyer/orders/[id]` (Module 5).

#### `src/server/actions/buyer-document-actions.ts`
- **Exported Functions:** `getBuyerDocumentMatrixAction(bookingId)`, `getBuyerDocumentSignedUrlAction(bookingId, documentType)`.
- **Intended Role:** `BUYER_ADMIN`.
- **Data Shape:** Unified 4-state document matrix (`Verified`, `Received`, `Missing`, `Required`) comparing original checklist against dispatch uploads.
- **UI Consumers:** `/buyer/orders/[id]` (Module 6).

#### `src/server/actions/buyer-payment-actions.ts`
- **Exported Functions:** `getBuyerPayableLedgerAction(bookingId?)`.
- **Intended Role:** `BUYER_ADMIN`.
- **Server-Side Financial Math:** Computes Base Amount (`Quantity * Locked Rate`), Mandi Cess (2.5%), Total Paid, and Outstanding Balance server-side.
- **Nodal Escrow Redaction:** Replaces seller bank account numbers with `BrokerBridge Trade Settlement Escrow (HDFC Bank Nodal Account)` and virtual reference `BB-NODAL-${ref}`.
- **UI Consumers:** `/buyer/orders/[id]` (Module 7), `/buyer/more`.

#### `src/server/actions/buyer-dispute-actions.ts`
- **Exported Functions:** `getBuyerActiveDisputesAction()`, `createBuyerDisputeAction(payload)`, `uploadBuyerDisputeEvidenceAction(formData)`.
- **Intended Role:** `BUYER_ADMIN`.
- **Input Validation:** Enforces 7 strict categories and 50-character minimum explanation length.
- **Mediation Firewall Invariant:** Routes dispute to neutral Broker Desk; strictly suppresses all Seller contact info and internal Broker notes from Buyer view.
- **UI Consumers:** `/buyer/orders/[id]` (Module 8), `/buyer/more/disputes`.

---

### 2.2 Seller Trading & Fulfillment Actions

#### `src/server/actions/availability-actions.ts`
- **Exported Functions:** `createAvailabilityAction(data)`, `getMyAvailabilitiesAction()`, `updateAvailabilityAction(id, data)`, `cancelAvailabilityAction(id)`.
- **Intended Role:** `SELLER_ADMIN`.
- **Concurrency Control:** `updateAvailabilityAction` enforces optimistic locking check on `availabilities.version`.
- **UI Consumers:** `/seller`, `PostAvailabilityDialog`.

#### `src/server/actions/broker-request-actions.ts`
- **Exported Functions:** `getSellerBrokerRequestsAction()`, `respondToBrokerRequestAction(payload)`.
- **Intended Role:** `SELLER_ADMIN`.
- **Response Triad:** Supports `ACCEPT`, `REJECT` (mandatory reason $\ge 5$ chars), and `COUNTER` (rate, quantity, dispatch window).
- **Zero-Buyer-PII:** Strips Buyer contact info, email, and GSTIN from request payloads.
- **UI Consumers:** `/seller/requests`.

#### `src/server/actions/booking-actions.ts`
- **Exported Functions:** `createIdempotentBookingAction(dealId)`, `getSellerBookedOrdersAction()`, `getBookingForDispatchAction(bookingId)`.
- **Intended Role:** `BROKER` / `ADMIN` (Creation); `SELLER` (Read/Dispatch).
- **Idempotency Guarantee:** Database `UNIQUE` constraint on `deal_id`. If booking already exists, returns existing reference immediately without re-processing.
- **UI Consumers:** `/broker/deals`, `/seller/dispatch`.

#### `src/server/actions/dispatch-actions.ts`
- **Exported Functions:** `submitDispatchAction(payload)`, `getBookingRemainingQuantityAction(bookingId)`, `getDispatchTrackingAction(dispatchId)`.
- **Intended Role:** `SELLER_ADMIN`.
- **Partial Shipment Math:** Atomically validates that `dispatchedQuantity <= remainingQuantity` inside `db.transaction()`. Updates booking status to `Partially Dispatched` or `Fully Dispatched`.
- **UI Consumers:** `/seller/dispatch/[bookingId]`.

---

### 2.3 Broker Trading Desk & Mediation Actions

#### `src/server/actions/broker-match-actions.ts`
- **Exported Functions:** `getRankedMatchesForRequirementAction(requirementId)`, `logMatchOverrideAction(payload)`.
- **Intended Role:** `BROKER`.
- **Algorithm:** Deterministic 6-Factor AI scoring (Commodity 35%, Grade 25%, Price 20%, Location 10%, Quantity 7%, Date 3%).
- **Decision Gate Audit:** Logs manual broker overrides into `audit_logs`.
- **UI Consumers:** `/broker/deals`, `MatchesView`.

#### `src/server/actions/broker-negotiation-actions.ts`
- **Exported Functions:** `sendProposalToSellerAction(payload)`, `sendProposalToBuyerAction(payload)`.
- **Intended Role:** `BROKER`.
- **Dual-Channel Isolation:** Keeps Buyer and Seller negotiation streams completely separate. Calculates margin spread strictly on server.
- **UI Consumers:** `/broker/deals`.

#### `src/server/actions/broker-dispute-actions.ts`
- **Exported Functions:** `getBrokerActiveDisputesAction()`, `resolveDisputeAction(disputeId, resolutionNotes, adjustedAmount)`.
- **Intended Role:** `BROKER`.
- **Mediation Fiduciary:** Broker reviews evidence (COA, weighbridge slips) and records official resolution notes.
- **UI Consumers:** `/broker/more/disputes`.

---

### 2.4 API Route Endpoints

1. **`GET /api/quotations/[id]/pdf`:** Streams official branded PDF quotation document generated on the server using `@react-pdf/renderer`.
2. **`POST /api/webhooks/whatsapp`:** Receives incoming delivery status receipts and incoming WhatsApp messages from Meta Cloud API. Validates `hub.verify_token` on challenge.
3. **`GET /api/cron/process-notifications`:** Background scheduled worker claiming pending notifications (`FOR UPDATE SKIP LOCKED`) and dispatching via in-app/WhatsApp/email adapters. Gated by `Authorization: Bearer ${CRON_SECRET}`.
4. **`GET /api/cron/monitor-dispatches`:** Background scheduled worker scanning active dispatches against estimated delivery dates to flag transit delays.
