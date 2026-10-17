# 03 — END-TO-END BUSINESS WORKFLOW MAPPING

**Document Reference:** `project-audit/deep-intelligence/03_END_TO_END_WORKFLOW_MAP.md`  
**Investigation Date:** October 17, 2026  
**Auditor:** Principal Enterprise Solutions Architect & Systems Engineer  
**Project:** BrokerBridge Enterprise + VetKind Animal Health India  

---

## 1. Traceability Standard

This document maps all 17 canonical operational workflows from UI entry point down through Zod validation, `@supabase/ssr` server authorization, Drizzle ORM mutations, database transaction boundaries, side effects, and final UI presentation.

---

## 2. Granular Workflow Tracing (17 Workflows)

### Workflow 1: Registration, Login, Session Management & Onboarding
- **UI Entry Point:** `app/login/page.tsx` & `app/register/page.tsx`
- **UI Component:** `src/components/forms/login-form.tsx` & `register-form.tsx`
- **Server Action / API:** `loginUserAction`, `registerUserAction` in `src/server/actions/auth-actions.ts`
- **Validation:** Zod schemas in `src/lib/validations/auth-schema.ts` validating mobile/email and password length ($\ge 6$).
- **Authorization:** `@supabase/ssr` creates session with `httpOnly: true`, `secure: true`, `sameSite: 'lax'` cookie storage. `middleware.ts` inspects JWT claims and enforces role paths (`/(admin)`, `/(broker)`, `/(buyer)`, `/(seller)`).
- **Database Tables:** `users`, `companies`, `profiles_buyer`, `profiles_seller`, `profiles_broker`.
- **Transaction / Side Effects:** User inserted; if company does not exist, redirects to onboarding form.
- **UI Response:** `router.push('/buyer')` (or role-appropriate root) with session established.

---

### Workflow 2: Buyer KYC & Organization Isolation
- **UI Entry Point:** `/buyer` (onboarding gate) or `/buyer/profile`
- **UI Component:** `CompanyOnboardingForm` (`src/components/forms/company-onboarding-form.tsx`)
- **Server Action / API:** `createCompanyAction` in `src/server/actions/company-actions.ts`
- **Validation:** Zod schema `companyOnboardingSchema` validating 15-character Indian GST format (`/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/`).
- **Authorization:** `verifyBuyerSession()` enforces `BUYER_ADMIN` role and scopes actions to authenticated `session.companyId`.
- **Database Tables:** `companies` (`status: true, is_verified: false`), `users` (`company_id: new_company.id`).
- **Transaction / Side Effects:** Links user to company; places company in Tier-0 Admin Approval Queue (`getPendingCompaniesAction`).
- **UI Response:** Success toast: *"Company registration submitted for Admin verification."*

---

### Workflow 3: Buyer Requirement Creation & Partial Fulfillment
- **UI Entry Point:** `/buyer/requirements/new`
- **UI Component:** `RequirementWizard` (`src/components/buyer/requirements/requirement-wizard.tsx`) — 6-Step Flow
- **Server Action / API:** `createRequirementAction` in `src/server/actions/requirement-actions.ts`
- **Validation:** Multi-step Zod validator `requirementWizardSchema` in `src/lib/validations/requirement-schema.ts`. Validates quantity $> 0$, target price $> 0$, delivery end date $\ge$ delivery start date.
- **Authorization:** Derives `company_id` from authenticated session; rejects client-supplied company spoofing.
- **Database Tables:** `requirements` (`status: 'Open', fulfilled_quantity: 0`).
- **Transaction / Side Effects:** Inserts requirement record; triggers TanStack query invalidation on `['buyer-requirements']`.
- **UI Response:** Success toast and redirect to `/buyer/requirements` displaying new demand card.

---

### Workflow 4: Dynamic Commodity Quality Specifications & Tolerance Validation
- **UI Entry Point:** `/buyer/requirements/new` (Step 1)
- **UI Component:** `QualityParametersForm` (`src/components/buyer/requirements/quality-parameters-form.tsx`)
- **Server Action / API:** `getCommodityQualityParametersAction` & `saveRequirementQualitySpecsAction` in `src/server/actions/buyer-quality-actions.ts`
- **Validation:** Dynamic Zod validator `createDynamicQualitySchema()` in `src/lib/validations/buyer-quality-schema.ts` comparing target values against `master_quality_parameters` min/max bounds.
- **Authorization:** `verifyBuyerSession()` with tenant company ownership check.
- **Database Tables:** `master_quality_parameters`, `requirement_quality_specs`.
- **Transaction / Side Effects:** Atomic Drizzle `db.transaction()` deletes previous specs and bulk-inserts new parameters referencing `requirement_id`.
- **UI Response:** Live inline green/red indicators; persistent Quality Card rendered in `/buyer/requirements/[id]`.

---

### Workflow 5: Seller Availability & Supply Listing
- **UI Entry Point:** `/seller` (Command Center)
- **UI Component:** `AvailabilityForm` in `PostAvailabilityDialog` (`src/components/forms/availability-form.tsx`)
- **Server Action / API:** `createAvailabilityAction` in `src/server/actions/availability-actions.ts`
- **Validation:** Zod schema `availabilitySchema` with `z.preprocess()` sanitization for empty strings and numbers.
- **Authorization:** Derives `company_id` from seller session; rejects unauthenticated requests.
- **Database Tables:** `availabilities` (`total_quantity`, `available_quantity`, `reserved_quantity: 0`, `sold_quantity: 0`, `asking_price`, `confidential_minimum_price`, `version: 1`, `status: 'Active'`).
- **Transaction / Side Effects:** Inserts traceable lot record; auto-resolves `effectiveGradeId` from matching `masterGrades`.
- **UI Response:** Modal closes, inventory card rendered in Open Inventory table, toast notification displayed.

---

### Workflow 6: Broker Deterministic AI Matching & Proposal Delivery
- **UI Entry Point:** `/broker/deals` & `/broker/work`
- **UI Component:** `MatchesView` (`src/components/dashboard/matches-view.tsx`) & `SendRequestDialog`
- **Server Action / API:** `getRankedMatchesForRequirementAction` in `src/server/actions/broker-match-actions.ts` & `createBrokerRequestToSellerAction` in `src/server/actions/broker-outbound-actions.ts`
- **Validation:** Evaluates `calculateMatchScore()` strictly: Commodity 35%, Grade 25%, Price 20%, Location 10%, Quantity 7%, Date 3%.
- **Authorization:** Enforces human broker session (`role === 'broker'`).
- **Database Tables:** `requirements`, `availabilities`, `quotations`, `deal_versions` (Initializes v1 `status: 'Proposed'`), `audit_logs`.
- **Transaction / Side Effects:** Inserts `quotations` row; inserts `deal_versions` baseline snapshot; dispatches Seller in-app notification via `queueNotificationAction`.
- **UI Response:** Proposal card appears in Seller Inbox (`/seller/requests?requestId=[id]`) with countdown timer.

---

### Workflow 7: Buyer & Seller Counteroffers
- **UI Entry Point:** `/seller/requests` (Seller) or `/buyer/proposals/[id]` (Buyer)
- **UI Component:** `CounterOfferModal` (`src/components/dashboard/counter-modal.tsx`) or `CounterOfferForm` (`src/components/buyer/proposals/counter-offer-form.tsx`)
- **Server Action / API:** `respondToBrokerRequestAction` (Seller) & `submitBuyerCounterOfferAction` (Buyer)
- **Validation:** Zod schemas validating counter rate $> 0$, counter quantity, dispatch window, and mandatory note ($\ge 5$ chars).
- **Authorization:** Strict channel isolation: Buyer action routes only to Broker; Seller action routes only to Broker.
- **Database Tables:** `quotations` (`counter_price`, `counter_notes`), `negotiation_events` (`action_type: 'COUNTER'`), `deal_versions`.
- **Transaction / Side Effects:** Atomically updates previous deal version to `'Superseded'` and creates incremental row (`v1` → `v2`).
- **UI Response:** Master timeline updates; counteroffer alert displayed on Broker Trading Desk.

---

### Workflow 8: Optimistic Locking & Stale-Version Rejection
- **UI Entry Point:** Any negotiation submission button.
- **Server Action / API:** `createDealVersionInTransaction` in `src/server/actions/version-actions.ts`
- **Validation:** Compares client-submitted `expectedVersionNumber` against `MAX(version_number)` in `deal_versions`.
- **Authorization:** Verified server-side inside `db.transaction()`.
- **Database Tables:** `deal_versions`.
- **Transaction / Side Effects:** If `latestVersion.versionNumber !== expectedVersionNumber`, transaction executes immediate ROLLBACK and throws `STALE_VERSION_DETECTED`.
- **UI Response:** Destructive conflict alert with "Refresh Deal" button to pull newest terms.

---

### Workflow 9: Immutable Negotiation Snapshots & Audit History
- **Server Action / API:** `getNegotiationTimelineAction` & `getBuyerNegotiationTimelineAction`
- **Validation:** Verifies PostgreSQL trigger `prevent_negotiation_events_mutation()` and `prevent_deal_version_snapshot_tampering()`.
- **Authorization:** Filtered through `buyer-privacy-scrubber.ts` (scrubs all counterparty PII, actor masked as `"Broker Desk"`).
- **Database Tables:** `negotiation_events`, `deal_versions`.
- **Transaction / Side Effects:** Read-only chronological query ordered by `created_at ASC`.
- **UI Response:** Renders visual timeline rail (`<NegotiationTimeline />`) showing immutable back-and-forth rounds.

---

### Workflow 10: Buyer & Seller Final Deal Review & Confirmation
- **UI Entry Point:** `/seller/deals/[id]/confirm` (Seller) & `/buyer/deals/[id]` (Buyer)
- **UI Component:** `FinalDealReview` (`src/components/buyer/deals/final-deal-review.tsx`) & `FinalConfirmationActions`
- **Server Action / API:** `confirmFinalDealTermsAction` (Seller) & `confirmFinalDealAction` (Buyer) in `src/server/actions/buyer-deal-actions.ts`
- **Validation:** Red/Green Visual Diff Engine (`visual-diff-engine.ts`) computes term differences between `v{current}` and `v{predecessor}`.
- **Authorization:** Verifies role and tenant ownership; requires `expectedVersion`.
- **Database Tables:** `deal_versions` (`status: 'Buyer Confirmed'` / `'Seller Confirmed'`), `negotiation_events` (`action_type: 'BUYER_FINAL_CONFIRMATION'`).
- **Transaction / Side Effects:** Logs digital confirmation signature. Does NOT generate booking ID.
- **UI Response:** UI replaces action buttons with green audit banner: *"Terms Confirmed — Awaiting Broker Finalization."*

---

### Workflow 11: Broker-Controlled Deal Finalization & Idempotent Booking Creation
- **UI Entry Point:** `/broker/deals`
- **UI Component:** `BookingGate` (`src/components/dashboard/booking-gate.tsx`)
- **Server Action / API:** `finalizeDealAction` & `createIdempotentBookingAction` in `src/server/actions/booking-actions.ts`
- **Validation:** Validates 3 preconditions: Seller Confirmed, Buyer Confirmed, Version Concurrency Match.
- **Authorization:** Role strictly restricted to `broker` or `admin`.
- **Database Tables:** `deals` (`status: 'Dispatch Pending'`), `deal_versions` (`status: 'Broker Finalized'`), `bookings` (`booking_reference: 'BKG-YYYY-XXXX'`, `deal_id: UNIQUE`), `availabilities` (`reserved_quantity += quantity`).
- **Transaction / Side Effects:**
  - Idempotency check: if booking for `deal_id` already exists, returns existing record immediately.
  - Generates unique reference `BKG-YYYY-XXXX`.
  - Atomically reserves inventory on Seller's lot.
  - Queues in-app notifications for Buyer and Seller.
- **UI Response:** Locked Booking ID displayed with prominent copy trigger; unlocks "Proceed to Dispatch" for Seller.

---

### Workflow 12: Order Tracking & Partial Fulfillment Math
- **UI Entry Point:** `/buyer/orders` & `/buyer/orders/[id]`
- **UI Component:** `OrderFulfillmentCard` (`src/components/buyer/orders/order-fulfillment-card.tsx`) & `LogisticsTimeline`
- **Server Action / API:** `getBuyerOrdersListAction` & `getBuyerBookingVisibilityAction` in `src/server/actions/buyer-order-actions.ts`
- **Validation:** Validates booking identifier; scopes query to `buyer_id === sessionCompanyId`.
- **Authorization:** Strictly read-only; zero mutation controls available to Buyer.
- **Database Tables:** `bookings`, `deals`, `requirements`, `dispatches`.
- **Transaction / Side Effects:** Server computes fulfillment math:
  - `originalQuantity`, `bookedQuantity`, `remainingQuantity = Math.max(0, original - booked)`, `progress = (booked / original) * 100`.
- **UI Response:** 3-column financial math grid and Ocean Blue progress bar rendered with 6-stage logistics stepper.

---

### Workflow 13: COA, Dispatch, Weighbridge & Supporting Documents
- **UI Entry Point:** `/seller/dispatch/[bookingId]` (Upload) & `/buyer/orders/[id]` (Inspection)
- **UI Component:** `FulfillmentDocumentUpload` & `TransactionDocumentVault` (`src/components/buyer/orders/transaction-document-vault.tsx`)
- **Server Action / API:** `attachDispatchDocumentAction`, `getBuyerDocumentMatrixAction`, `getBuyerDocumentSignedUrlAction`
- **Validation:** Validates standardized document whitelist (COA, LR, Weighment Slip, Invoice, E-Way Bill). Path traversal defense (`..`, `\`, `\0`).
- **Authorization:** 15-minute time-limited signed URLs generated from private Supabase storage bucket.
- **Database Tables:** `dispatch_documents`, `requirement_documents`.
- **Transaction / Side Effects:** Evaluates 4-state matrix: `Verified`, `Received`, `Missing`, `Required`.
- **UI Response:** Interactive document checklist with progress bar and signed preview triggers.

---

### Workflow 14: Payable, Brokerage, Cess, Payment & Nodal Escrow Calculations
- **UI Entry Point:** `/buyer/more` & `/buyer/orders/[id]` (Module 7)
- **UI Component:** `BuyerPaymentCard` (`src/components/buyer/orders/buyer-payment-card.tsx`) & `GlobalPayablesHub`
- **Server Action / API:** `getBuyerPayableLedgerAction` in `src/server/actions/buyer-payment-actions.ts`
- **Validation:** Server-side math calculation:
  - `Base Amount = Final Quantity * Locked Rate`
  - `Gross Payable = Base Amount + Platform Charges & Mandi Cess (2.5%)`
  - `Total Paid = SUM(payments.amount WHERE status = 'Confirmed')`
  - `Outstanding Balance = Math.max(0, Gross Payable - Total Paid)`
- **Authorization:** Redacts Seller bank details; provides platform virtual nodal account (`BB-NODAL-${bookingReference}`).
- **Database Tables:** `bookings`, `deals`, `deal_versions`, `payments`.
- **Transaction / Side Effects:** Returns read-only numbers preventing client-side F12 DOM manipulation.
- **UI Response:** 3 prominent metric blocks (Gross Payable, Amount Paid in Emerald, Outstanding Balance) with 1-click escrow copy trigger.

---

### Workflow 15: Dispute Creation, Validation & Broker Mediation Firewall
- **UI Entry Point:** `/buyer/orders/[id]` (Module 8)
- **UI Component:** `RaiseDisputeModal` (`src/components/buyer/orders/raise-dispute-modal.tsx`)
- **Server Action / API:** `createBuyerDisputeAction` & `getBuyerActiveDisputesAction` in `src/server/actions/buyer-dispute-actions.ts`
- **Validation:** Validates 7 strict categories (`Quality`, `Quantity`, `Delivery`, `Document`, `Payment`, `Commercial`, `Other`) and enforces minimum 50-character detailed explanation.
- **Authorization:** `verifyBuyerSession()` with booking ownership validation. Strips all Seller identities and Broker internal notes.
- **Database Tables:** `disputes` (`status: 'Open'`, `filed_by: user.id`).
- **Transaction / Side Effects:** Inserts dispute record; routes exclusively to Broker Desk for neutral mediation. Zero direct counterparty chat created.
- **UI Response:** Dispute tracker card rendered with status `"Under Broker Review"`.

---

### Workflow 16: Multi-Channel Notifications, Retries & WhatsApp Integration
- **Server Action / API:** `queueNotificationAction` in `src/server/actions/notification-actions.ts` & `app/api/cron/process-notifications/route.ts`
- **Validation:** Requires `idempotency_key` and channel (`IN_APP`, `WHATSAPP`, `EMAIL`).
- **Authorization:** Cron worker authenticated via `Bearer ${CRON_SECRET}` header.
- **Database Tables:** `notifications`.
- **Transaction / Side Effects:** Worker executes `FOR UPDATE SKIP LOCKED` atomic claiming; dispatches via channel adapter; applies exponential retry backoff on failure (`attempt_count`, `next_retry_at`).
- **UI Response:** Header notification bell unread badge updates instantly via TanStack Query invalidation.

---

### Workflow 17: VetKind Products, Dealers, Inquiries & Farm Advisory
- **UI Entry Point:** `/vetkind`, `/vetkind/dealers`, `/vetkind/products/[slug]`
- **UI Component:** `ProductCatalogGrid`, `DealerLocator`, `InquiryDialog`
- **Server Action / API:** `getVetKindProductsAction`, `getVetKindProductBySlugAction`, `getVetKindDealersAction`, `submitVetKindInquiryAction` in `src/server/actions/vetkind-actions.ts`
- **Validation:** Zod schema validating inquiry name, mobile number format, inquiry type, and message length ($\ge 15$ chars).
- **Authorization:** Public inquiry submission; dealer management gated to Admin.
- **Database Tables:** `vetkind_categories`, `vetkind_products`, `vetkind_dealers`, `vetkind_inquiries`.
- **Transaction / Side Effects:** Inserts inquiry record with generated tracking reference (`VK-INQ-XXXXXX`).
- **UI Response:** Success confirmation with reference number; inquiry queued for veterinary advisory response.
