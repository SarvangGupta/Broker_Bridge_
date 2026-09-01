**BROKERBRIDGE ENTERPRISE**

# Seller Implementation Sprint Plan

**Sprints 13–20 • Micro-Sprint Breakdown 13.1 → 20.5**

*Production Seller Scope • Implementation Reference • August 2026*

# 1. Planning Decision

Sprints 1–12 remain the completed shared foundation. Seller development continues at Sprint 13; the sprint numbers are intentionally not reset. Sprint 13–20 are Seller-focused implementation sprints, and each sprint is divided into small, independently executable micro-sprints.

This plan is based on the completed Sprints document, BrokerBridge PRD v4.0, BrokerBridge TRD, and the current Seller PRD v3.0. The Seller PRD identifies authentication, master data, onboarding/KYC, Seller availability, AI matching foundation, quotation/deal foundation, dispatch/files, payments/disputes, notifications, analytics and partial fulfillment as established foundation; remaining work is primarily production hardening plus the new Seller confirmation/versioning/finalization flow.

# 2. Sprint Structure

| **Sprint** | **Primary outcome** | **Micro-sprints** | **Status after completion** |
| --- | --- | --- | --- |
| 13 | Seller Command Center + foundation audit | 13.1–13.5 | Seller workspace is production-ready baseline |
| 14 | Inventory / Availability 2.0 | 14.1–14.5 | Lot-level supply record is complete and safe |
| 15 | Quality + Lab + evidence | 15.1–15.5 | Quality is dynamic, validated and lot-scoped |
| 16 | Loading Readiness + Broker Requests | 16.1–16.5 | Seller can operationally respond to broker-originated demand |
| 17 | Negotiation + Deal Versioning | 17.1–17.5 | Commercial history is versioned and immutable |
| 18 | Final Confirmation + Finalization + Booking | 18.1–18.5 | Booking is a controlled, idempotent system outcome |
| 19 | Dispatch + Documents + Settlement | 19.1–19.5 | Booked transactions can be fulfilled and financially tracked |
| 20 | Notifications + Reports + Security + UAT | 20.1–20.5 | Seller MVP is production-validated |

# 3. Non-Negotiable Rules Carried Through Sprints 13–20

- Seller is a broker-controlled supply workspace; it is not a public marketplace.
- No direct Buyer contact, Buyer directory, Buyer phone/email/WhatsApp, or direct communication path.
- AI is recommendation-only. It cannot independently select, negotiate, finalize or create a Booking.
- Seller explicitly confirms the exact final Deal Version before Broker finalization.
- Confirmed commercial terms are immutable; amendments create a new version and audit event.
- Broker Finalization and Booking creation are separate. Successful finalization causes the system to create the unique Booking ID.
- WhatsApp is notification-only and must not drive quotation, negotiation, confirmation, finalization or Booking state transitions.
- Commodity, grade, unit, location, packaging, payment and delivery values use master data wherever structured data exists.
- Inventory truth is lot/batch based so quantity, price, quality, documents and reservations remain traceable.
- Confidential minimum price is Broker/Admin-only and must never leak through Seller/Broker/Buyer-inappropriate APIs.
- Every sensitive mutation requires server-side authorization, validation, auditability and safe retry/idempotency behavior.
- The same Seller product must work mobile-first at 360px and reflow to desktop without separate business logic.

# SPRINT 13 — Seller Command Center & Foundation Audit (COMPLETED ✅)

Goal: Establish the Seller workspace as a task-first operational command center and audit the existing foundation before adding new business logic.

### 13.1 — Existing Seller Foundation Audit (COMPLETED ✅)

**Objective:** Map what already exists against Seller PRD v3.0 so completed Sprint 1–12 functionality is regression-protected rather than rebuilt.

**Implementation:**

- [x] Audit Seller routes, components, Server Actions, database entities, RLS policies and notification hooks.
- [x] Map existing functionality to authentication/KYC, availability, AI matching, quotation/deal, dispatch/files, payments/disputes and notifications.
- [x] Record gaps, partial implementations, stale assumptions and duplicate logic in `seller-foundation-audit-13.1.md`.
- [x] Identify any old quotation/WhatsApp flow that conflicts with the new Seller rules.

**Done when:**

- [x] A written gap list exists with Existing / Needs hardening / Missing classifications.
- [x] No existing completed foundation feature is redesigned without a documented reason.
- [x] Conflicting old flow is explicitly marked for removal or migration.

### 13.2 — Seller Workspace Shell & Navigation (COMPLETED ✅)

**Objective:** Create the stable Seller application shell that all later Seller modules use.

**Implementation:**

- [x] Seller dashboard route and responsive navigation (`seller-workspace-shell.tsx`).
- [x] Mobile-first layout at 360–414px; desktop reflows from the same routes/components.
- [x] Seller role-aware navigation for SELLER_ADMIN, SELLER_USER and SELLER_VIEWER (`seller-nav.tsx`).
- [x] Profile/KYC state visible in the header (`seller-header.tsx`).
- [x] Notification entry point (`<NotificationBell />`) and persistent action context.

**Done when:**

- [x] Seller can enter the protected workspace and reach all Seller modules without dead ends.
- [x] No Seller screen exposes Buyer private contact information.
- [x] Navigation is usable on mobile and desktop.

### 13.3 — Operational Dashboard & Action Required (COMPLETED ✅)

**Objective:** Turn the dashboard into a command center rather than a KPI-only page.

**Implementation:**

- [x] P0 Action Required: broker requests, final confirmation, quality correction, dispatch due, missing document, loading delay and payment exception (`action-required-banner.tsx`).
- [x] Active Inventory with active quantities and expiry.
- [x] Broker Requests, Confirmed Bookings, Dispatch Pending, Payments and Notifications.
- [x] Quick Actions: Add Availability (`<PostAvailabilityDialog />`), Manage All Inventory, View Booked Deals.
- [x] Every action card deep-links to the exact resolving screen.

**Done when:**

- [x] Time-sensitive actions appear above informational metrics.
- [x] Every actionable card has one useful next action.
- [x] Expired availability and invalid/expired lab evidence are distinguishable.

### 13.4 — Seller Authorization & Privacy Hardening (COMPLETED ✅)

**Objective:** Enforce Seller organization and role boundaries at API/database level.

**Implementation:**

- [x] Verify organization-level tenant boundaries for Seller data (`seller-auth.ts`).
- [x] Verify Seller APIs never return Buyer private contact data (`deal-actions.ts`).
- [x] Verify confidential minimum price is excluded from unauthorized responses (`availability-actions.ts`).
- [x] Verify Seller roles: SELLER_ADMIN, SELLER_USER, SELLER_VIEWER (`seller-auth.ts`).
- [x] Verify file downloads require authorization at request time (`logistics-actions.ts` - `getTransactionDocumentSignedUrlAction`).

**Done when:**

- [x] Cross-organization reads/writes fail at the server/database layer.
- [x] Unauthorized Seller roles cannot perform restricted mutations.
- [x] URL guessing cannot retrieve protected files.

### 13.5 — Shared UX / Resilience Baseline (COMPLETED ✅)

**Objective:** Apply the production UX rules before feature expansion.

**Implementation:**

- [x] Skeleton, empty, error and retry states for Seller cards/lists (`dashboard-skeleton.tsx`, `empty-state.tsx`).
- [x] Large touch targets (48px+ on mobile), clear status labels and thumb-zone primary actions.
- [x] Server-side validation with Zod; business errors return actionable messages.
- [x] Retry-safe forms and uploads; stale-data indicators where cached data is used (`data-freshness.tsx`).
- [x] Confirm no false-success states when a mutation or upload fails.

**Done when:**

- [x] Seller screens have explicit loading/empty/error states.
- [x] Failure can be retried without silent data loss.
- [x] The mobile layout remains operational on low bandwidth.

# SPRINT 14 — Inventory & Availability 2.0

Goal: Upgrade the existing Sprint-6 availability foundation into the complete lot-level Seller supply contract defined by Seller PRD v3.0.

### 14.1 — Lot / Batch Data Model

**Objective:** Make the lot/batch the traceable inventory unit.

**Implementation:**

- [x] Add or verify lot/batch reference and relationship to availability.
- [x] Track total, available and reserved quantity.
- [x] Preserve history for inactive/expired records.
- [x] Define quantity/version fields needed for stale-data detection.
**Done when:**

- [x] A lot can be traced through quantity, price, quality and documents.
- [x] Historical records are preserved.
- [x] Quantity constraints are represented server-side.

### 14.2 — Complete Availability Form

**Objective:** Expose the full Seller availability contract through structured fields.

**Implementation:**

- [x] Commodity and Grade from master data.
- [x] Lot/Batch, quantity, unit and location using State → District → City → Warehouse.
- [x] Asking price and confidential minimum price.
- [x] Price validity, Availability From and Valid Until.
- [x] Packaging, delivery terms and loading readiness linkage.
- [x] Quality/COA/Lab linkage.
**Done when:**

- [x] Seller can create an availability containing the required commercial, inventory and operational fields.
- [x] Structured fields use master data; free text is limited to permitted remarks.
- [x] Confidential minimum price is not exposed to Buyer-facing paths.

### 14.3 — Availability State Machine & Expiry

**Objective:** Make availability lifecycle deterministic and server-enforced.

**Implementation:**

- [x] Implement/verify Draft → Pending Approval → Active.
- [x] Handle Reserved, Sold/Exhausted, Expired, Deactivated as applicable.
- [x] Server-side Valid Until enforcement.
- [x] Prevent expired/inactive records from entering new deal matching.
- [x] Audit status changes.
**Done when:**

- [x] Expired availability is automatically excluded from new commercial use.
- [x] Invalid transitions are rejected server-side.
- [x] Historical availability remains visible where authorized.

### 14.4 — Quick Renew / Duplicate

**Objective:** Implement the v3.0 1-click availability renewal enhancement.

**Implementation:**

- [x] Quick Renew is available only for Expired records.
- [x] Pre-fill commodity, grade, lot, quantity, price, location, quality and loading settings.
- [x] Surface price for explicit review; do not silently reuse it.
- [x] Seller changes fields such as dates/price and creates a new availability record.
- [x] New record re-enters Draft → Pending Approval → Active.
**Done when:**

- [x] Renewal does not mutate the expired record.
- [x] Quick Renew is unavailable on Active or Reserved records.
- [x] A normal renewal can be completed within the intended under-60-second UX target.

### 14.5 — Quantity Concurrency & Inventory Integrity

**Objective:** Prevent overselling and stale edits.

**Implementation:**

- [x] Transactional available/reserved quantity updates.
- [x] Stale version detection on concurrent edits.
- [x] Reject quantity changes that violate total/reserved/available relationships.
- [x] Audit material quantity changes.
**Done when:**

- [x] Concurrent updates cannot create negative or oversold inventory.
- [x] Stale Seller updates return a clear recovery path.
- [x] The final persisted quantity is authoritative.

# SPRINT 15 — Quality, Lab Testing & Evidence

Goal: Make quality a structured, commodity-specific, lot-scoped system rather than a collection of static fields and files.

### 15.1 — Quality Parameter Master Integration

**Objective:** Connect Seller quality forms to the configured commodity template.

**Implementation:**

- Load the authoritative quality template for the selected commodity.
- Support parameter name, unit, min, max, target/guaranteed value and required flag as configured.
- Use commodity-specific examples such as Moisture, Protein, Broken %, Foreign Matter, Damage %, Aflatoxin and Test Weight where configured.
**Done when:**

- Changing commodity changes the quality parameter set dynamically.
- No hard-coded commodity-specific form is required for normal configuration.
- Required parameters are enforced.

### 15.2 — Seller Quality Entry & Validation

**Objective:** Capture and validate actual Seller quality values.

**Implementation:**

- Render dynamic input controls based on parameter type.
- Validate numeric ranges and required values.
- Show human-readable field errors.
- Store the submitted quality snapshot against the exact lot.
**Done when:**

- Invalid values cannot be persisted.
- The Seller can see exactly which quality field needs correction.
- Persisted values can be reproduced later in a deal snapshot.

### 15.3 — Lab Test Record

**Objective:** Create structured lab testing data independent of the document file itself.

**Implementation:**

- Lab/Test ID, lot reference, test date, source/lab, results and status.
- Validity/freshness and expiry.
- Link test results to the exact lot.
- Track requested/uploaded/reviewed/verified/expired states as applicable.
**Done when:**

- Lab information is queryable without parsing a PDF.
- A lab record cannot point to the wrong lot.
- Expired evidence is excluded from verified evidence display.

### 15.4 — COA / Lab / Quality Documents

**Objective:** Securely attach evidence to the exact lot.

**Implementation:**

- COA, laboratory report, quality certificate, batch report and specification sheet.
- Private storage with authorization at download time.
- File type/size validation.
- Document verification and expiry status.
- Replace/update flow that preserves audit history.
**Done when:**

- A Seller can upload and later retrieve only authorized documents.
- Expired/rejected documents are clearly marked.
- No direct URL access bypasses authorization.

### 15.5 — Quality Readiness & Broker Visibility

**Objective:** Make quality state operationally useful to the Broker without exposing Seller-private data.

**Implementation:**

- Show verified/pending/correction-required status on Seller dashboard.
- Expose only authorized quality evidence through Broker-facing workflow.
- Prevent invalid/expired quality evidence from being treated as verified.
- Audit quality and document state changes.
**Done when:**

- Broker-facing match/request workflows receive correct quality state.
- Seller can immediately see missing or expiring quality actions.

# SPRINT 16 — Loading Readiness & Broker Request Inbox

Goal: Connect Seller supply readiness to Broker-originated commercial requests without creating a direct Buyer communication channel.

### 16.1 — Loading Readiness Model

**Objective:** Make loading readiness a pre-deal operational attribute.

**Implementation:**

- Statuses: Ready, Scheduled, Loading, Delayed, Blocked as applicable.
- Loading duration, readiness date/time and remarks.
- Associate readiness with the relevant lot/availability.
**Done when:**

- Seller can state whether stock is operationally ready.
- Status is queryable and auditable.
- Loading readiness is available before Booking.

### 16.2 — Loading Readiness UI & Updates

**Objective:** Give Seller a fast workflow to update readiness.

**Implementation:**

- Update state from inventory/lot context.
- Show current readiness prominently on lot cards.
- Validate permitted transitions.
- Provide clear failure/retry states.
**Done when:**

- Seller can update readiness from mobile with minimal steps.
- Invalid transitions are rejected.
- Dashboard reflects the latest persisted state.

### 16.3 — Broker Request Inbox

**Objective:** Present broker-originated commercial requests as Seller actions.

**Implementation:**

- Request ID, commodity, grade, requested quantity, quality requirements, delivery and response deadline.
- Broker message/context where permitted.
- Accept / Reject / Counter actions.
- Never expose Buyer phone/email/WhatsApp or direct contact.
**Done when:**

- Seller receives requests only through Broker-controlled workflows.
- The request contains enough information to make a commercial decision.
- No direct Buyer discovery mechanism exists.

### 16.4 — Request Notifications & Deep Links

**Objective:** Connect request events to the Seller Action Center.

**Implementation:**

- New Broker request notification.
- Deadline/reminder notification where configured.
- Deep link directly to request detail.
- Notification payload contains no prohibited Buyer information.
**Done when:**

- Notification opens the exact action screen.
- Retry does not duplicate notifications.
- Notification delivery failure is visible to operations.

### 16.5 — AI Recommendation Decision Gate

**Objective:** Ensure AI remains recommendation-only while Seller request flow is deterministic.

**Implementation:**

- Verify AI ranks/recommends availability but cannot independently select, negotiate, finalize or book.
- Broker remains the explicit decision-maker.
- Audit manual Broker overrides where applicable.
- Ensure Seller sees only the Broker-originated commercial request, not an AI autonomous action.
**Done when:**

- No AI path can create a Booking.
- No AI path can bypass Broker decision-making.

# SPRINT 17 — Negotiation & Immutable Deal Versioning

Goal: Replace overwrite-style commercial updates with controlled, immutable Deal Versions.

### 17.1 — Negotiation Action Model

**Objective:** Implement Seller-side Accept / Reject / Counter within permitted fields.

**Implementation:**

- Accept a Broker request/proposal.
- Reject with a reason where required.
- Counter only permitted commercial fields such as price, quantity, delivery, payment or quality terms.
- Keep the negotiation Broker-mediated; no shared Buyer-Seller chat.
**Done when:**

- Every Seller commercial response is authorized server-side.
- Rejected/countered states are explicit.
- Seller cannot communicate directly with Buyer through the product.

### 17.2 — Deal Version Entity & Snapshot

**Objective:** Persist every material commercial revision as an immutable snapshot.

**Implementation:**

- Version number, deal reference, actor, timestamp and supersession relationship.
- Snapshot commodity, grade, lot/batch, quantity, rate, quality, delivery, payment, packaging, freight/transport, taxes/charges and special conditions as applicable.
- Store version status and confirmation references.
**Done when:**

- Version 1, 2, 3... remain independently readable.
- Historical versions cannot be edited.
- Current version is explicitly identifiable.

### 17.3 — Version Creation Rules

**Objective:** Guarantee that material commercial changes create a new version.

**Implementation:**

- Detect material field changes.
- Create a new version instead of mutating the previous snapshot.
- Preserve the previous version as historical.
- Audit the actor, old version, new version and reason where required.
**Done when:**

- No material change overwrites a prior version.
- Version numbering is deterministic and concurrency-safe.

### 17.4 — Stale-Version Protection

**Objective:** Prevent Seller actions against an outdated deal version.

**Implementation:**

- Compare the Seller's version reference with the current version.
- Reject stale confirmation/counter actions.
- Show a clear stale-version warning and the latest version.
- Do not silently merge stale edits.
**Done when:**

- A Seller cannot confirm an outdated version.
- The recovery path opens the current version.

### 17.5 — Negotiation Timeline & Audit

**Objective:** Make commercial history reviewable without exposing private data.

**Implementation:**

- Chronological negotiation/version timeline.
- Actor and timestamp for each event.
- Read-only historical snapshots.
- Audit events for material changes and decisions.
**Done when:**

- Seller can understand how the current terms were reached.
- History cannot be rewritten from Seller UI/API.

# SPRINT 18 — Final Deal Confirmation, Finalization & Booking

Goal: Implement the critical new commercial boundary: Seller Confirmation ≠ Booking; Broker Finalization → System Booking.

### 18.1 — Final Deal Snapshot

**Objective:** Create the exact final commercial snapshot that the Seller must review.

**Implementation:**

- Show exact Deal Version.
- Commodity, grade, lot/batch, final quantity/unit, final rate.
- Quality specification snapshot and authorized evidence status.
- Delivery location/date/window, payment terms, packaging, freight/transport, taxes/charges and special conditions.
- Confirmation status and timestamps.
**Done when:**

- Seller can see exactly what is being confirmed.
- The displayed snapshot is generated from the immutable version, not editable fields.

### 18.2 — Visual Diff Confirmation Screen

**Objective:** Implement the v3.0 Visual Diff enhancement.

**Implementation:**

- Show Version X of Y.
- Server-compute changes from the previous immutable version.
- Changed fields: favorable/new in green; reduced/removed in red.
- Unchanged fields have no change indicator.
- Version 1 shows First Version instead of a diff.
- Actions only: Confirm Final Terms or Request Broker Correction.
**Done when:**

- Seller can identify changed terms at a glance.
- Seller cannot edit commercial terms from the confirmation screen.
- Diff cannot be manipulated by the client.

### 18.3 — Seller Final Confirmation

**Objective:** Record an explicit Seller confirmation against the exact version.

**Implementation:**

- Confirm Final Terms action.
- Request Broker Correction action creates/requires a new version.
- Store Seller actor, timestamp and Deal Version reference.
- Create immutable audit event.
- Block Broker finalization if Seller confirmation is missing.
**Done when:**

- Only the exact confirmed version is eligible for finalization.
- Seller confirmation is distinct from Booking.
- A correction request never silently edits the current version.

### 18.4 — Broker Finalization Gate

**Objective:** Create the explicit system gate before Booking.

**Implementation:**

- Validate required Seller confirmation.
- Validate required Buyer-side confirmation through the Broker-controlled workflow.
- Validate current version validity.
- Reject finalization when any required condition is missing.
- Audit the Broker finalization action.
**Done when:**

- Broker cannot finalize an unconfirmed version.
- Finalization is a separate state/action from Booking creation.

### 18.5 — Idempotent Booking Creation

**Objective:** Make Booking a single transactional system outcome.

**Implementation:**

- On successful Broker Finalization, create unique Booking ID.
- Lock the final commercial snapshot.
- Reserve/lock applicable inventory quantities transactionally.
- Prevent repeated finalization requests from creating duplicate bookings.
- Return the existing Booking ID for a repeated idempotent request.
**Done when:**

- One finalized transaction produces one Booking ID.
- Historical Deal Versions remain immutable.
- Booking is the locked operational transaction record.
- Seller can proceed to Dispatch only after Booking exists.

# SPRINT 19 — Dispatch, Documents & Seller Settlement

Goal: Harden the established Sprint-10/11 operational foundation so fulfillment begins only from a valid Booking and quantity/payment data remain trustworthy.

### 19.1 — Booked Order / Dispatch Entry Gate

**Objective:** Prevent unbooked transactions from entering dispatch.

**Implementation:**

- Show Seller confirmed bookings with Booking ID and locked terms.
- Dispatch action is available only for booked transactions.
- Carry forward booked quantity, lot and delivery information.
**Done when:**

- No dispatch can be created for an unbooked transaction.
- Seller sees locked commercial terms as reference.

### 19.2 — Dispatch & Partial Fulfillment

**Objective:** Harden dispatch quantity and status transitions.

**Implementation:**

- Dispatch date, quantity, vehicle type, vehicle number, driver, driver mobile, transport company, loading location and ETA.
- Validate quantity against remaining booked quantity transactionally.
- Support partial fulfillment where the existing platform policy permits it.
- Prevent duplicate dispatch submissions.
**Done when:**

- Dispatch quantity cannot exceed remaining booked quantity.
- Concurrent dispatch updates are safe.
- Dispatch state is auditable.

### 19.3 — Fulfilment Documents

**Objective:** Secure Seller document handling for booked transactions.

**Implementation:**

- Invoice, LR, e-way bill, weighment slip, loading photos and other configured fulfilment documents.
- Private storage and request-time authorization.
- MIME/size validation and retry-safe uploads.
- Attach documents to the correct booking/dispatch.
**Done when:**

- Only authorized Seller users can upload/view permitted files.
- A document cannot be attached to the wrong transaction through client manipulation.

### 19.4 — Payment & Settlement View

**Objective:** Provide a trustworthy Seller-side settlement view without becoming a full accounting ERP.

**Implementation:**

- Gross sale value.
- Broker commission captured per booked rule.
- Other configured charges.
- Net receivable, paid amount, outstanding amount, due date and status.
- Pending / Part Paid / Paid / Overdue / Disputed states as applicable.
**Done when:**

- Amounts are calculated/validated server-side.
- Seller sees only its own settlement information.
- Commission and settlement data are traceable to the booking/deal.

### 19.5 — Delivery / Completion State Integration

**Objective:** Connect dispatch completion, delivery and settlement to the established transaction lifecycle.

**Implementation:**

- Dispatched → In Transit → Delivered/Delayed as applicable.
- Delivery confirmation and quality/dispute paths remain Broker/Admin controlled where required.
- Payment status updates flow to Seller dashboard.
- Audit all sensitive state changes.
**Done when:**

- Seller sees the current operational and payment state without stale UI.
- Exceptions have a clear next action.

# SPRINT 20 — Notifications, Reports, Security & End-to-End UAT

Goal: Close the Seller MVP by validating the complete workflow, removing legacy conflicts and proving production behavior.

### 20.1 — Seller Notification & Action Center

**Objective:** Complete Seller-specific operational notifications.

**Implementation:**

- KYC change, availability approval/rejection/expiry, quality/lab updates.
- New Broker request, Broker counter-proposal, deal version update.
- Final confirmation required, confirmation outcome, Broker finalization/Booking.
- Loading reminder, dispatch reminder, document issue, delivery update and payment update.
- Use queue/outbox-style dispatch, retries with backoff and duplicate suppression.
- Deep-link every actionable event to the exact Seller screen.
**Done when:**

- Notifications explain what happened, why it matters and the next action.
- No notification leaks Buyer private data.
- Retries do not create duplicate notifications.

### 20.2 — Seller Reports & Visibility

**Objective:** Expose Seller-owned operational reporting.

**Implementation:**

- Sales by date/commodity.
- Quantity available/reserved/sold.
- Average selling rate.
- Broker commission and net receivables.
- Outstanding payments and overdue tracking.
- Inventory by state.
- Quality verification, lab status/expiry, loading readiness/delays.
- Dispatch status, completed transactions, deal version history and negotiation timeline.
**Done when:**

- Reports are Seller-scoped.
- Reports cannot become a hidden Buyer-private data channel.
- Exported data respects Seller permissions.

### 20.3 — Security / Audit Regression Suite

**Objective:** Prove the new Seller workflow cannot bypass the platform's security model.

**Implementation:**

- RLS tests for organization isolation.
- API tests for Buyer-contact leakage and confidential minimum price leakage.
- Immutability tests for Deal Versions and audit logs.
- Finalization/Booking authorization tests.
- Idempotency tests for repeated confirmation/finalization/dispatch/upload operations.
- File authorization tests.
- State-transition authorization tests.
**Done when:**

- Unauthorized operations fail at server/database boundaries.
- Sensitive events create immutable audit records.
- Legacy routes cannot bypass the new confirmation → finalization → Booking rules.

### 20.4 — Performance, Mobile & Resilience Validation

**Objective:** Verify Seller usability under the target operating conditions.

**Implementation:**

- 360px-first testing and desktop reflow.
- 2G/3G throttling for lists, forms, uploads and dashboard.
- Skeleton, empty, error and retry behavior.
- Offline-safe behavior only for operations that are safe to queue; avoid unsafe offline commercial state transitions.
- P95 API/performance checks and dashboard loading checks.
- Verify no false-success UI.
**Done when:**

- Seller can complete critical actions on mobile.
- Slow network does not silently lose input.
- Desktop uses the same business logic and permissions.

### 20.5 — End-to-End Seller UAT & Release Gate

**Objective:** Validate the canonical Seller journey from KYC to settlement.

**Implementation:**

- KYC verification.
- Create availability with commodity/grade/lot, quantity, location, price, validity, loading, quality and COA/lab.
- Quick Renew from expired availability.
- Broker-originated request → Accept/Reject/Counter.
- Deal Versioning → Final Deal Snapshot → Visual Diff → Seller Confirmation.
- Required Buyer-side confirmation → Broker Finalization → unique Booking ID.
- Dispatch → documents → delivery → payment/settlement.
- Run all negative cases: stale version, invalid quantity, expired availability/lab, unauthorized access, duplicate submission, duplicate finalization.
**Done when:**

- All Seller MVP acceptance criteria pass.
- No direct Buyer communication path exists.
- No WhatsApp action is required for deal progression.
- Booking is created only after required confirmations and Broker finalization.
- Production release is blocked if a security, data-integrity or state-machine test fails.

# 4. Sprint Exit Gates

| **Sprint** | **Exit gate** | **Evidence** |
| --- | --- | --- |
| 13 | Seller workspace + existing foundation audited and protected | Gap report, route/RLS checks, dashboard walkthrough |
| 14 | Lot-level availability is production-safe | Availability tests, expiry tests, Quick Renew test, concurrency test |
| 15 | Quality/lab evidence is structured and lot-scoped | Dynamic template test, validation test, document authorization test |
| 16 | Seller can receive and act on Broker requests | Request lifecycle, notification/deep-link, privacy test |
| 17 | Negotiation history is immutable | Version creation and stale-version tests |
| 18 | Finalization creates exactly one Booking | Confirmation gate, finalization gate, idempotency/concurrency tests |
| 19 | Booked transactions can be fulfilled and settled | Dispatch quantity, document security, settlement tests |
| 20 | Seller MVP passes production UAT | E2E suite, security regression, mobile/low-bandwidth test, release checklist |

# 5. What Is Explicitly NOT Being Rebuilt

- Sprint 1–2 authentication and role routing are foundation features; Sprint 13 only audits/hardens them.
- Sprint 3 master data remains centralized and Admin-controlled; Seller consumes it.
- Sprint 4 Seller onboarding/KYC remains established; only validation/recovery gaps are hardened.
- Sprint 6 availability is upgraded, not recreated from zero.
- Sprint 7 AI matching remains Broker-side and recommendation-only.
- Sprint 8 quotation/PDF infrastructure remains shared; Seller work changes the commercial state model where required.
- Sprint 10 dispatch/storage and Sprint 11 payment/dispute foundations remain regression-protected; Seller work hardens them around Booking.
- Sprint 12 notifications/analytics remain shared infrastructure; Seller work adds Seller-specific events, deep links and reports.

# 6. Canonical Seller Flow After Sprint 20

**KYC → Availability/Lot → Quantity/Location → Price/Validity → Loading Readiness → Dynamic Quality → COA/Lab → Active Availability → Broker Recommendation/Decision → Broker Request → Seller Accept/Reject/Counter → Immutable Deal Versions → Final Deal Snapshot + Visual Diff → Seller Final Confirmation → Buyer-side confirmation → Broker Finalization → System Booking ID → Locked Booking → Dispatch → Documents → In Transit → Delivered → Payment/Settlement → Completed or Dispute.**

# 7. Source Basis

The completed Sprints document establishes Sprints 1–12 as the original platform roadmap, including Seller Availability in Sprint 6, AI/CRM in Sprint 7, quotation/deal in Sprints 8–9, dispatch in Sprint 10, payments/disputes in Sprint 11 and notifications/analytics in Sprint 12. filecite references are supplied in the chat response, not embedded as Word hyperlinks.

Seller PRD v3.0 identifies the established foundation and remaining production work, including complete availability contract, Quick Renew, dynamic quality, structured lab testing, loading readiness, Broker-mediated negotiation, immutable Deal Versions, mandatory Seller Final Confirmation, Visual Diff, Broker Finalization → Booking separation, removal of WhatsApp from state progression, dispatch hardening, payment verification, notification reliability and security/audit regression.

The TRD supplies the implementation constraints: Next.js Server Actions, Drizzle transactions, Supabase RLS/Storage/Realtime, Zod validation, idempotency, secure files, background jobs, monitoring and testing.
