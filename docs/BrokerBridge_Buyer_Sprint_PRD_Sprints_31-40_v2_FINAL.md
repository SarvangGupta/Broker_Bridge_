**BROKERBRIDGE ENTERPRISE**

**Buyer Sprint Product Requirements Document**

**Sprints 31–40 — Final Locked Edition**

| Product | BrokerBridge Enterprise |
| --- | --- |
| Module | Buyer |
| Role | BUYER_ADMIN only |
| Sprint Range | 31–40 |
| Status | FINAL / LOCKED |

**Purpose.** This document converts the locked Buyer PRD v1.2 into exactly ten implementation sprints, numbered 31 through 40. It is the execution plan for the Buyer module and preserves the Buyer PRD's role model, navigation, Broker-mediated workflow, mobile-first UX and security boundaries.

# 1. Source, Scope & Precedence

- Primary product source: BrokerBridge Buyer PRD v1.2 FINAL.
- Supporting alignment: BrokerBridge Broker PRD and shared BrokerBridge TRD/foundation.
- Existing BrokerBridge foundation is considered complete through Sprint 30.
- This document covers only Buyer Sprints 31–40.
- This document does not create new Buyer roles, Reports, Buyer User Management or direct Buyer–Seller communication.
- Where a feature is grouped into one sprint, the sub-sprints are implementation work packages, not additional numbered sprints.

# 2. Final Buyer Product Definition

BrokerBridge Buyer is a minimal, mobile-first procurement workspace for one role: BUYER_ADMIN. The Buyer defines what is needed, receives Broker-mediated options, negotiates only with the Broker, confirms final terms, tracks the resulting order, reviews quality/documents, monitors Buyer-side payments and handles disputes. The same product expands to laptop/desktop without changing workflow, permissions or business rules.

# 3. Non-Negotiable Rules

- Only one Buyer role exists: BUYER_ADMIN.
- Buyer navigation contains no Reports module.
- Broker is the controlled intermediary: Buyer ↔ Broker ↔ Seller.
- There is never a Buyer ↔ Seller communication path through BrokerBridge.
- Buyer must not receive Seller phone, email, WhatsApp, private contact data, confidential minimum price or private notes.
- Historical proposals and negotiation events are immutable.
- Commercial Deal changes create new Deal versions and require controlled reconfirmation.
- Buyer confirms the Final Deal; Buyer does not finalize Booking.
- Booking is finalized by the Broker after the required Buyer and Seller confirmations.
- Quality uses the shared commodity-specific Quality Parameter Master.
- Financial calculations and state transitions are server-side validated.
- Buyer organization data is isolated using authorization/RLS.
- Material commercial and security actions are auditable.
- Mobile is first-class at 360px; desktop is the same product expanded.
- The UX follows 'simple outside, complex inside'.

# 4. Final Buyer Navigation

1. Dashboard
2. My Requirements
3. Broker Proposals
4. Negotiations
5. Orders
6. Quality & Documents
7. Payments
8. Disputes
9. Notifications
10. Profile

Reports are intentionally absent. Buyer history is accessed contextually through Requirements, Orders, Payments and Profile.

# 5. Sprint Overview

| **Sprint** | **Name** | **Primary Outcome** |
| --- | --- | --- |
| 31 | Buyer Foundation & Access | Secure BUYER_ADMIN access, organization isolation and Buyer profile/KYC foundation. |
| 32 | Buyer Shell, Navigation & Dashboard | Mobile-first Buyer shell, final navigation and action-first dashboard. |
| 33 | Requirements: Create & Manage | Buyer can create, edit, submit and manage procurement requirements. |
| 34 | Quality Requirements & Documents | Commodity-specific quality criteria and requirement documents. |
| 35 | Broker Proposals | Buyer receives, reviews and responds to Broker proposals. |
| 36 | Buyer ↔ Broker Negotiation | Controlled Buyer-Broker negotiation with immutable event history. |
| 37 | Final Deal & Buyer Confirmation | Final commercial Deal snapshot and Buyer confirmation. |
| 38 | Orders, Booking & Delivery | Booking visibility, order lifecycle and dispatch/delivery tracking. |
| 39 | Quality, Documents, Payments & Disputes | Post-deal operational records, Buyer-side payment visibility and disputes. |
| 40 | Notifications, Security, Mobile Polish & UAT | Production-readiness, security, responsive/low-bandwidth polish and end-to-end UAT. |

# Sprint 31 — Buyer Foundation & Access

**Sprint Goal:** Verify existing Buyer organization/entity structure.

## 31.1 — Buyer Integration Verification

- Verify existing Buyer organization/entity structure.
- Verify shared Requirement, Deal, Order, Payment and Document entities.
- Verify Broker ↔ Buyer relationship and shared architecture.
- Verify existing Buyer routes and integration points.

## 31.2 — BUYER_ADMIN Authentication

- Implement/verify Buyer login and authentication.
- Protect Buyer routes and sessions.
- Enforce BUYER_ADMIN as the only Buyer role.

## 31.3 — Buyer Organization Isolation

- Enforce organization-level access.
- Verify RLS and server-side authorization.
- Prevent cross-organization Buyer access.

## 31.4 — Buyer Profile & KYC Foundation

- Company profile.
- KYC information and documents.
- KYC verification status.

**Sprint Result:** A verified BUYER_ADMIN can securely enter BrokerBridge and access only its own Buyer organization.

# Sprint 32 — Buyer Shell, Navigation & Dashboard

**Sprint Goal:** Build 360px-first Buyer layout.

## 32.1 — Mobile-First Buyer Shell

- Build 360px-first Buyer layout.
- Header and mobile navigation.
- Responsive desktop shell.
- Primary actions positioned for practical thumb use.
- Header Profile Dropdown must include the Trader Workspace Toggle to seamlessly route the user to the /seller dashboard.

## 32.2 — Buyer Navigation

- Implement final ten-item Buyer navigation.
- Do not add Reports.
- Keep Profile and Notifications after Disputes.

## 32.3 — Buyer Dashboard

- Active Requirements.
- Pending Proposals.
- Active Orders.
- In Transit.
- Payment Pending.
- Deals Closed.
- Action Required and recent activity.

## 32.4 — Dashboard States

- Loading/skeleton.
- Empty states.
- Error and retry states.
- Useful no-data messaging.

**Sprint Result:** The Buyer has a clean application shell and an action-first dashboard.

# Sprint 33 — Requirements: Create & Manage

**Sprint Goal:** Commodity and Grade.

## 33.1 — Requirement Data Structure

- Commodity and Grade.
- Quantity and Unit.
- Target/indicative price.
- Delivery location and delivery date/window.
- Payment terms, packaging and freight/logistics.
- Inspection requirements and validity.

## 33.2 — Create Requirement

- Guardrail: Do not rebuild the Requirement engine from scratch. Upgrade and extend the existing Sprint 5 Requirement form and offline-queue architecture.
- Mobile-first flow: What → How Much → Where → When → Commercial Terms → Review.
- Use master data for commodity, grade, unit and location.

## 33.3 — Edit Requirement

- Save draft.
- Edit permitted fields.
- Validation.
- Submit.
- Withdraw/cancel where allowed.

## 33.4 — Requirement List

- Mobile cards.
- Desktop table/grid enhancement.
- Search and filters.
- Human-readable statuses.

## 33.5 — Requirement Detail

- Requirement summary.
- Current status.
- Broker.
- Quality and commercial terms.
- Documents.
- Next action.
- Explicitly visualize 'Original Quantity', 'Booked Quantity', and 'Remaining Unfulfilled Quantity' based on partial fulfillment logic.

**Sprint Result:** Buyer can create, edit, submit and manage procurement requirements.

# Sprint 34 — Quality Requirements & Documents

**Sprint Goal:** Commodity-specific parameters.

## 34.1 — Quality Parameter Master

- Commodity-specific parameters.
- Grade-specific parameters.
- Master-driven fields.
- No arbitrary quality fields.

## 34.2 — Buyer Quality Requirement

- Support minimum, maximum, range and target values.
- Validate parameter values and units.

## 34.3 — Requirement Documents

- Specification and supporting documents.
- Upload.
- Authorized preview/download.
- Replace/delete where permitted.

## 34.4 — Quality Validation

- Required parameter validation.
- Numeric validation.
- Unit validation.
- Server-side validation.

## 34.5 — Mobile Quality UX

- Simple quality forms.
- One logical section at a time.
- Clear progress and save state.

**Sprint Result:** A Buyer can submit a complete commodity + quality requirement to the Broker.

# Sprint 35 — Broker Proposals

**Sprint Goal:** New, pending response, accepted, rejected, countered and expired states.

## 35.1 — Proposal Inbox

- New, pending response, accepted, rejected, countered and expired states.
- Clear next action.

## 35.2 — Proposal Detail

- Commodity, grade, quantity and price/unit.
- Quality, delivery, payment, packaging, freight and inspection terms.
- Applicable Buyer-side charges.
- Broker message.

## 35.3 — Proposal Versions

- Version history V1, V2, V3 and later.
- Historical versions are immutable.

## 35.4 — Proposal Actions

- Accept.
- Reject with reason.
- Counter.

## 35.5 — Proposal Security

- Never expose Seller phone, email, WhatsApp or private contact information.
- Never expose Seller confidential minimum price or private notes.
- Never expose Broker private CRM information.

**Sprint Result:** Buyer can receive, understand and respond to Broker proposals without discovering the Seller.

# Sprint 36 — Buyer ↔ Broker Negotiation

**Sprint Goal:** Only Buyer ↔ Broker communication/workflow.

## 36.1 — Buyer-Broker Negotiation

- Only Buyer ↔ Broker communication/workflow.
- Seller-side negotiation remains isolated.

## 36.2 — Negotiation Timeline

- Chronological proposal, counter, response, revision and clarification events.

## 36.3 — Counter Offer

- Permitted fields may include price, quantity, delivery date, payment terms, packaging, freight, inspection and quality/document requirements.

## 36.4 — Immutable Negotiation History

- Old events cannot be edited or overwritten.

## 36.5 — Negotiation States

- Open.
- Waiting for Broker.
- Waiting for Buyer.
- Agreed.
- Closed.
- Expired.

**Sprint Result:** Buyer can negotiate commercially with the Broker while Seller-side negotiation remains completely isolated.

# Sprint 37 — Final Deal & Buyer Confirmation

**Sprint Goal:** Commodity, quantity and price.

## 37.1 — Final Deal Review

- Commodity, quantity and price.
- Quality.
- Delivery.
- Payment.
- Packaging, freight and inspection.
- Documents and applicable charges.
- Display Visual Diff engine: changed fields must be highlighted (green/red) from the previous proposal version prior to Buyer confirmation.

## 37.2 — Immutable Deal Snapshot

- Create Deal Version.
- Store timestamp and commercial terms snapshot.
- Maintain audit reference.

## 37.3 — Buyer Confirmation

- Buyer reviews and confirms the Final Deal.
- Display Visual Diff engine: changed fields must be highlighted (green/red) from the previous proposal version prior to Buyer confirmation.

## 37.4 — Confirmation Protection

- Buyer cannot directly edit finalized commercial terms.
- Amendments create a new Deal version and controlled reconfirmation.

## 37.5 — Confirmation Status

- Awaiting Buyer Confirmation.
- Buyer Confirmed.
- Awaiting Seller Confirmation.
- Confirmed.
- Amendment Required.

**Sprint Result:** Buyer can officially confirm the commercial Deal. Buyer confirmation does not finalize Booking.

# Sprint 38 — Orders, Booking & Delivery

**Sprint Goal:** Booking ID.

## 38.1 — Booking Visibility

- Booking ID.
- Deal reference.
- Booking status and order information.
- Broker remains responsible for final Booking.

## 38.2 — My Orders

- Order ID, commodity, quantity, status, delivery and payment state.

## 38.3 — Order Detail

- Complete order timeline and current next action.
- Explicitly visualize 'Original Quantity', 'Booked Quantity', and 'Remaining Unfulfilled Quantity' based on partial fulfillment logic.

## 38.4 — Dispatch Tracking

- Booked → Dispatch Planned → Dispatched → In Transit → Delivered → Completed.
- Exceptions: Delayed, Cancelled, Disputed and Partially Fulfilled.

## 38.5 — Delivery Information

- Dispatch date.
- Quantity.
- ETA.
- Authorized logistics information.
- Delivery status.

**Sprint Result:** Buyer can track the transaction from Booking through delivery.

# Sprint 39 — Quality, Documents, Payments & Disputes

**Sprint Goal:** Quality records.

## 39.1 — Transaction Quality

- Quality records.
- COA.
- Lab reports.
- Quality certificates.
- Weighment.
- Verification status.

## 39.2 — Transaction Documents

- Invoice, LR, e-way bill, COA, specification, weighment slip and dispatch documents.
- Document states: Required, Received, Verified or Missing.

## 39.3 — Buyer Payments

- Total payable, paid, outstanding and due date.
- Pending, Part Paid, Paid, Overdue and Disputed.
- Only Buyer-facing financial information.

## 39.4 — Buyer Disputes

- Categories: Quality, Quantity, Delivery, Document, Payment, Commercial, Other.
- Flow: Create Dispute → Add Evidence → Broker Review → Resolution → Close.

## 39.5 — Dispute Security

- Disputes must never create a direct Buyer-Seller communication channel.

**Sprint Result:** Buyer can manage post-deal operational information, financial status and issues.

# Sprint 40 — Notifications, Security, Mobile Polish & UAT

**Sprint Goal:** Requirement submission and Broker acknowledgement.

## 40.1 — Notifications

- Requirement submission and Broker acknowledgement.
- Proposal/counter/action-required notifications.
- Deal confirmation and Booking.
- Dispatch, delay and document notifications.
- Payment and dispute updates.
- Actionable notifications deep-link to the relevant object/action.

## 40.2 — Security & Audit

- RLS and server authorization.
- Seller data protection.
- File authorization.
- Server-side state-transition validation.
- Server-side financial calculations.
- Audit events.
- No direct Buyer-Seller communication path.

## 40.3 — Mobile & Desktop Final Polish

- Test 360px, 375px, 390px and 414px+ Android layouts.
- Test laptop and desktop.
- No horizontal scrolling on operational mobile screens.

## 40.4 — Low-Bandwidth & Offline Safety

- Cache master data.
- Lazy-load non-critical content.
- Minimize payloads.
- Support safe drafts and retry states.
- Commitment actions such as Deal confirmation require live server validation.

## 40.5 — End-to-End Buyer UAT

- Login → Requirement → Quality → Submit → Broker Proposal → Negotiation → Final Deal → Confirmation → Booking → Dispatch → Delivery → Documents → Payment → Dispute.
- Validate complete Buyer workflow and critical security boundaries.

**Sprint Result:** The complete Buyer module is tested and ready for production integration.

# 6. Cross-Sprint Implementation Rules

## 6.1 Mobile-First

- Design and test at 360px first; support 414px+ Android devices.
- Minimum 48×48px touch targets; primary actions approximately 56px.
- No horizontal scrolling on operational mobile screens.
- Use cards, compact rows and timelines instead of dense tables on mobile.
- Primary actions remain within practical thumb reach.
- Search must be accessible without excessive navigation.

## 6.2 Desktop

- Desktop is the same Buyer product expanded, not a separate application.
- Use the same routes, data, permissions, states and business rules.
- Desktop may use wider tables, comparisons and larger timelines where useful.

## 6.3 Simple Outside, Complex Inside

- Do not expose database concepts, raw state codes, RLS concepts or technical terminology to Buyers.
- Use human-readable statuses and one clear primary action per important card.
- Every loading, empty, error and retry state must be intentional.

## 6.4 Security

- Authorization is enforced server-side and at the database layer where applicable.
- Buyer-facing APIs must not return Seller private contact information or confidential minimum pricing.
- Files require organization and transaction authorization.
- All price, quantity and commission calculations are server-side.
- Every state transition is validated server-side.
- Material commercial/security actions are audited.

## 6.5 Offline and Low Bandwidth

- Cache reference/master data.
- Lazy-load non-critical files and images.
- Minimize API payloads and paginate lists.
- Safe drafts may queue/sync where supported.
- Deal confirmation and other commercial commitment actions require live validation.
- Idempotency should prevent duplicate commitment submissions.

# 7. Buyer End-to-End Journey

1. Login as BUYER_ADMIN.
1. Open Dashboard and review Action Required.
1. Create a Requirement.
1. Define commodity-specific Quality Requirements.
1. Attach supporting documents.
1. Submit Requirement to Broker.
1. Receive Broker Proposal.
1. Review proposal or compare proposals.
1. Negotiate with Broker if required.
1. Review Final Deal.
1. Confirm Final Deal.
1. Broker obtains Seller confirmation and finalizes Booking.
1. Buyer tracks Order and Dispatch.
1. Buyer reviews Quality and Transaction Documents.
1. Buyer monitors Buyer-side Payments.
1. Buyer raises a Dispute if required.
1. Buyer receives actionable Notifications throughout the lifecycle.

# 8. Sprint 31–40 Definition of Done

- Feature behavior matches the locked Buyer PRD v1.2.
- Only BUYER_ADMIN exists in the Buyer module.
- Reports are not implemented in Buyer scope.
- No direct Buyer-Seller communication path exists.
- Seller private/confidential information is protected at API and database authorization layers.
- Mobile UX works from 360px upward without operational horizontal scrolling.
- Desktop uses the same product, state and permission model.
- Loading, empty, error and retry states exist for relevant screens.
- Server-side validation protects commercial actions.
- Audit events exist for material Buyer actions.
- Relevant unit/integration/security/UI tests pass.
- End-to-end Buyer UAT completes the intended transaction journey.

# 9. Explicit Buyer Out of Scope

- Buyer User or Buyer Viewer roles.
- Buyer User Management.
- Reports module.
- Seller directory/search for Buyer.
- Direct Buyer-Seller chat, calling, email or WhatsApp.
- Seller contact discovery.
- Seller confidential minimum price.
- Broker internal CRM or internal notes.
- Broker AI Match Center.
- Autonomous AI negotiation.
- Public marketplace browsing.
- Full procurement ERP replacement.
- Advanced laboratory management.
- Automated logistics marketplace.
- Crypto/wallet functionality.

# 10. Final Locked Sprint Map

| **Sprint** | **Focus** |
| --- | --- |
| 31 | Buyer Foundation & Access |
| 32 | Buyer Shell, Navigation & Dashboard |
| 33 | Requirements: Create & Manage |
| 34 | Quality Requirements & Documents |
| 35 | Broker Proposals |
| 36 | Buyer ↔ Broker Negotiation |
| 37 | Final Deal & Buyer Confirmation |
| 38 | Orders, Booking & Delivery |
| 39 | Quality, Documents, Payments & Disputes |
| 40 | Notifications, Security, Mobile Polish & UAT |

**FINAL LOCKED — BUYER SPRINTS 31–40**
