**BrokerBridge Enterprise — Broker Sprint Plan**

*Sprint 21–30 | Broker-only implementation plan*

**Revised sequence: Audit → Build Core Broker → Harden → End-to-End UAT**

Scope rule: Sprints 1–20 are treated as completed work. Sprint 21 is a mandatory audit gate covering Sprints 1–20 before any Broker feature implementation proceeds. The Broker build then runs from Sprint 22 through Sprint 28, followed by hardening in Sprint 29 and full end-to-end UAT/release in Sprint 30.

Product principle: Simple outside. Complex inside. The Broker should see what happened, what needs action, and what to do next; technical complexity remains in the backend.

# 1. Broker Role Model

- Broker Admin: organization-level control plus all normal Broker operational capabilities.
- Broker: day-to-day brokerage operations; no separate Manager/User/Viewer/Finance subtype.
- Permissions are enforced server-side. The UI must not expose technical authorization concepts.

# 2. Sprint Map

| Sprint | Focus | Outcome |
| --- | --- | --- |
| 21 | Audit Sprints 1–20 | Formal regression, integration, security and data/state audit; release gate for Broker work. (COMPLETED ✅) |
| 22 | Broker Shell + Home | Simple mobile-first Broker shell, navigation and action-first Home. (COMPLETED ✅) |
| 23 | Requirements + Seller Supply | Buyer requirement processing and Seller inventory discovery. (COMPLETED ✅) |
| 24 | Matching + Quality | Explainable matching, lot comparison and quality verification. |
| 25 | Negotiation | Separate Buyer-Broker and Seller-Broker negotiation workflows. |
| 26 | Deal + Confirmation | Final Deal, immutable versions and separate confirmations. |
| 27 | Booking + Orders | Booking, dispatch, delivery and operational exceptions. |
| 28 | Finance + CRM | Payments, settlement, commission, lightweight CRM and disputes. |
| 29 | Hardening | Security, concurrency, low-bandwidth, mobile and regression hardening. |
| 30 | End-to-End UAT + Release | Full workflow validation, blocker resolution and production release gate. |

# 3. Sprint 21 — Audit of Sprints 1–20

Purpose: Sprint 21 is an audit sprint, not a feature sprint. It follows the same principle as the earlier audit checkpoint in the completed plan: verify that all prior work is actually working together before building on top of it.

## 21.1 — Audit completed Foundation: Sprints 1–12

- Audit authentication, login/session behavior and organization boundaries.
- Audit user, Buyer, Seller, commodity and grade foundations.
- Audit Requirements and Seller Inventory/Lot data and relationships.
- Audit database relationships, required fields, constraints and existing state transitions.
- Audit server-side authorization and organization isolation.
- Audit core create/read/update flows for regression defects.

## 21.2 — Audit completed Seller Dashboard: Sprints 13–20

- Audit the Seller Dashboard and all completed Seller-facing workflows delivered in Sprints 13–20.
- Verify Seller inventory/lot creation, editing, availability and status behavior.
- Verify Seller quality/document flows already delivered in Sprints 13–20.
- Verify Seller-side navigation, notifications, empty/loading/error states and mobile responsiveness.
- Verify that Seller data remains correctly isolated from Buyer and future Broker views.

## 21.3 — Cross-module integration audit

- Trace the shared data path across Buyer → Requirement → Seller → Inventory/Lot.
- Confirm identifiers, relationships and statuses remain consistent across completed modules.
- Confirm no duplicate or conflicting business logic was introduced between Sprints 1–20.
- Confirm existing Buyer and Seller workflows still work after all completed changes.

## 21.4 — Security and authorization audit

- Verify organization isolation and server-side authorization for existing roles.
- Verify private Buyer and Seller data boundaries.
- Verify there is no direct Buyer-Seller communication path.
- Verify sensitive fields and documents are accessible only to authorized users.

## 21.5 — Mobile and low-bandwidth audit

- Test approximately 360px and common Android widths up to 414px+.
- Check for horizontal scrolling, clipped content, weak touch targets and excessive typing.
- Check loading, retry, empty and error states on slow connections.
- Check unnecessary image/payload loading and basic resilience.

## 21.6 — Audit defect handling

- Classify findings as Blocker, High, Medium or Low.
- Blocker and High findings affecting shared foundations, authorization, data integrity or core workflows must be fixed before Sprint 22 feature work depends on them.
- Do not rebuild completed features unless a defect is blocking correctness or the Broker workflow.
- Carry non-blocking findings into the appropriate later sprint backlog.

## 21.7 — Sprint 21 acceptance gate

- Sprints 1–20 pass functional regression at the shared-workflow level.
- Foundation and Seller Dashboard data can be safely consumed by Broker workflows.
- No critical authorization, data-isolation or integrity defect remains open.
- A written audit result identifies all accepted defects and deferred work.
- Sprint 22 may start only after the audit gate is passed.

# 4. Global Definition of Done for Sprints 22–30

- Implemented with the existing project architecture; no unnecessary foundation rebuild.
- Server-side authorization and organization isolation verified.
- Mobile-first UI works without horizontal scrolling.
- Clear loading, empty, error and retry states.
- Primary action is obvious and low-typing.
- Material mutations create the required audit history.
- No Buyer-Seller direct communication path is introduced.

# Sprint 22 — Broker Shell + Home

## 22.1 — Mobile application shell

- Build Broker mobile shell for approximately 360px first.
- Keep navigation minimal and action-oriented.
- Use reusable cards, status chips, loading, empty, error and confirmation patterns.

## 22.2 — Core navigation

- Primary navigation: Home, Work, Deals, Orders, More.
- Place Requirements, Matching, Quality and Negotiation under Work.
- Keep Payments, CRM, Documents, Disputes, Notifications, Users and Settings behind More where appropriate.

## 22.3 — Home

- Show Action Required first.
- Show active work and the next required action.
- Keep KPIs compact; avoid analytics-wall design.
- Notifications deep-link to the relevant work item.

## 22.4 — Acceptance

- Broker can open the product and understand what needs attention without technical training.
- Core navigation is usable one-handed where practical.

# Sprint 23 — Requirements + Seller Supply (COMPLETED ✅)

## 23.1 — Buyer Requirements (COMPLETED ✅)

- [x] Requirement inbox with card-first mobile list.
- [x] Show commodity, grade, quantity, target price, delivery and quality requirements.
- [x] Primary actions: Find Seller or Ask Buyer.
- [x] Use simple Broker-facing status labels.

## 23.2 — Seller Supply (COMPLETED ✅)

- [x] Search active Seller inventory relevant to a requirement.
- [x] Filters: commodity, grade, quantity, location, availability, price, quality status, packaging and payment terms.
- [x] Lot cards show only authorized information (exposes confidential floor to authorized Broker).
- [x] Prevent use of inactive/unavailable lots.

## 23.3 — Acceptance (COMPLETED ✅)

- [x] Broker can understand a requirement quickly and move directly to viable Seller supply via SPA URL parameters.

## 23.4 — Seller-side connection (COMPLETED ✅)

- [x] The Seller Broker Request Inbox, response actions (Accept / Reject / Counter), notifications and deep links are fully production-ready from Seller Sprint 16.
- [x] The broker_requests / quotations database table already exists. Connected the Broker outbound request trigger to write into this table.
- [x] Do not rebuild the Seller inbox or Seller response flow.

# Sprint 24 — Matching + Quality (COMPLETED ✅)

## 24.1 — Matching (COMPLETED ✅)

- [x] Show Buyer Requirement alongside recommended Seller lots.
- [x] Initial weights: Commodity 35%, Grade 25%, Price 20%, Location 10%, Quantity 7%, Delivery date 3%.
- [x] Show 0–100 match score and plain-language Why?.
- [x] Allow manual override with a simple reason.

## 24.2 — Quality (COMPLETED ✅)

- [x] Use the shared commodity-specific Quality Parameter Master.
- [x] Show simple compatibility first; details on demand.
- [x] Support COA/lab documents and states: Required, Received, Verified, Missing.
- [x] Actions: Approve, Reject, Request Correction, Request New COA/Lab Report, Mark Pending.

## 24.3 — Acceptance (COMPLETED ✅)

- [x] Broker can select a commercially usable lot without navigating a complex technical or laboratory interface.

# Sprint 25 — Negotiation

## 25.1 — Seller negotiation

- Seller Broker channel only.
- Negotiate price, quantity, delivery, payment, packaging, freight, inspection and quality/documents.

## 25.2 — Buyer negotiation

- Buyer Broker channel only.
- Broker creates authorized Buyer proposals.

## 25.3 — Privacy + history

- Protect Seller confidential minimum price and Buyer private target price/notes.
- Every proposal creates a new immutable version.
- Separate negotiation streams; no shared Buyer-Seller conversation object.

## 25.4 — Acceptance

- Broker can manage both sides of the negotiation without exposing protected information.

# Sprint 26 — Deal + Confirmation (COMPLETED ✅)

## 26.1 — Deal Builder

- Review product, quality, commercial, delivery, payment and special conditions.

## 26.2 — Final Deal

- Create immutable Deal version with required commercial fields.
- Historical versions cannot be edited or deleted.

## 26.3 — Confirmations

- Record Buyer confirmation separately.
- Record Seller confirmation separately.
- Broker sees whether required confirmations are complete.

## 26.4 — Acceptance

- Booking cannot proceed until required confirmations are complete.
- Post-confirmation commercial changes create a new Deal version and reconfirmation flow.

# Sprint 27 — Booking + Orders (COMPLETED ✅)

## 27.1 — Booking

- Validate Deal, confirmations, expiry/cancellation, conditions, inventory availability and Broker authorization.
- Generate unique Booking ID.
- Persist the booking transaction atomically.

## 27.2 — Order operations

- Stages: Booked → Dispatch Planned → Dispatched → In Transit → Delivered → Completed.
- Exceptions: Delayed, Cancelled, Disputed, Partially Fulfilled.

## 27.3 — Dispatch

- Capture dispatch date, quantity, vehicle, transporter, loading location, destination, LR, e-way bill and ETA.

## 27.4 — Acceptance

- Broker can complete booking and track fulfillment from one operational view.

## 27.5 — Seller-side connection

- The Seller Final Confirmation flow, Visual Diff engine, finalizeDealAction server action and idempotent Booking creation are fully production-ready from Seller Sprint 18.
- The Seller side was tested using a dev-mode simulator (DevFinalizationGateTester) in the absence of the real Broker UI. Connect the Broker Finalization UI to the existing finalizeDealAction.
- Do not rebuild Seller Final Confirmation, Visual Diff, Booking creation, Booking ID generation or inventory lock.

# Sprint 28 — Finance + CRM

## 28.1 — Payments + settlement

- Keep Buyer Payable, Seller Settlement, Broker Commission, Actual Payment and Outstanding distinct.
- Track payment/settlement status without becoming a full accounting replacement.

## 28.2 — Commission

- MVP supports fixed commission per MT.
- Calculate server-side and preserve historical values.

## 28.3 — Lightweight CRM

- Contact cards, call log, meeting note, follow-up task, reminder and relationship history.
- One-tap Follow Up.

## 28.4 — Disputes

- Categories: Quality, Quantity, Delivery, Document, Payment, Commercial, Other.
- Review evidence, add internal notes, request documents and record resolution.

## 28.5 — Acceptance

- Finance and CRM remain operational and minimal rather than becoming separate complex systems.

# Sprint 29 — Hardening

## 29.1 — Security

- RLS/server authorization, organization isolation, confidential pricing and document access.
- Prove Buyer/Seller negotiation channel isolation.

## 29.2 — Integrity + concurrency

- Immutable proposal and Deal versions.
- Safe concurrent confirmation/Booking handling.
- Transactional inventory validation.

## 29.3 — Mobile + connectivity

- 360px and 414px+ Android testing.
- Slow network, retry, skeleton, preserved input and safe offline actions.

## 29.4 — Regression

- Run regression across Sprints 1–28.
- Fix release-blocking defects; do not add unnecessary features.

# Sprint 30 — End-to-End UAT + Release

## 30.1 — Full workflow

- Requirement → Find Seller → Quality → Seller Negotiation → Buyer Negotiation → Deal → Buyer Confirmation → Seller Confirmation → Booking → Dispatch → Delivery → Payment → Closure.

## 30.2 — UAT

- Validate common Broker tasks can be completed without technical training.
- Validate Broker Admin vs Broker permissions.
- Validate mobile and desktop responsive behavior.

## 30.3 — Release gate

- No critical security, data-isolation, transaction-integrity or workflow-blocking defects.
- Document known non-blocking issues.
- Production release only after UAT acceptance.

# 5. Final Sprint Sequence

1. 21 — Audit Sprints 1–20
1. 22 — Broker Shell + Home
1. 23 — Requirements + Seller Supply
1. 24 — Matching + Quality
1. 25 — Negotiation
1. 26 — Deal + Confirmation
1. 27 — Booking + Orders
1. 28 — Finance + CRM
1. 29 — Hardening
1. 30 — End-to-End UAT + Release

# 6. Product Architecture Direction — BrokerBridge Lite

Recommended direction: use a single shared backend/platform with separate, role-specific lightweight interfaces. Do not build three independent backend products.

- Shared platform: authentication, organizations, Buyer/Seller entities, inventory, requirements, matching, quality, proposals, Deals, Bookings, documents, payments, audit and notifications.
- Broker Lite: focused on daily brokerage actions — requirements, supply, matching, quality, negotiation, Deals, booking and follow-up.
- Seller Lite: focused on stock, requests, offers/Deals, documents and order/dispatch actions relevant to Seller.
- Buyer Lite: focused on requirements, offers, confirmations, Deals and order status relevant to Buyer.
- Desktop/Web: richer administration, reports and larger comparison views where required.
- Lite means a focused experience, not a separate or weaker business system.

# 7. Global Broker UI Rules

- Use ordinary operational language: Find Seller, Check Quality, Send Proposal, Review Counter, Create Deal, Finalize Booking.
- Prefer structured selection to typing.
- One primary action per card/screen where practical.
- Cards on mobile; wider comparison/table layouts on desktop where useful.
- No horizontal scrolling.
- Minimum 48×48px touch targets; primary actions approximately 56px.
- Keep technical status codes, RLS, version-table concepts and database terminology out of the Broker UI.
- If the Broker does not need to perform an action, automate it or hide it.
