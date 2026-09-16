**BrokerBridge Enterprise — Broker Product Requirements Document**

*Version 2.2 — Broker Lite*

# Document Status

- This document updates the Broker role model in the working Broker PRD.
- It does not modify the completed Sprints 1–20 foundation.

# 1. Product Definition

BrokerBridge Broker is the operational control center for a Broker. The Broker receives Buyer requirements, identifies suitable Seller inventory, verifies quality, negotiates separately with Buyer and Seller, creates the final commercial Deal, obtains both confirmations, finalizes Booking, coordinates dispatch and documents, tracks settlement, manages disputes and records brokerage.

- Primary market: Tier-2/Tier-3 India, initially Jaipur and similar environments.
- Primary device: Android mobile.
- Secondary device: Laptop/Desktop.
- Primary design objective: operational simplicity.
- Backend objective: enterprise-grade integrity, authorization, versioning, auditability and transactional safety.

# 2. Core Product Principle

Simple outside. Complex inside.

The Broker should see what happened, what needs action and what to do next. The UI must not require the Broker to understand database concepts, API concepts, versioning architecture, RLS, event sourcing or technical status codes.

# 5. Broker Core Workflow

1. Receive Buyer demand.
1. Understand the requirement.
1. Find Seller supply.
1. Verify quality and documents.
1. Negotiate with Seller.
1. Negotiate with Buyer.
1. Create the Final Deal.
1. Obtain Buyer confirmation.
1. Obtain Seller confirmation.
1. Finalize Booking.
1. Coordinate dispatch and delivery.
1. Track payment and settlement.
1. Resolve issues/disputes.
1. Close the transaction and retain history.

# 6. Non-Negotiable Business Rules

- Broker is the controlled intermediary.
- Buyer ↔ Broker and Seller ↔ Broker are separate channels.
- There is never a Buyer ↔ Seller communication channel through BrokerBridge.
- No direct Buyer-Seller chat, calling, email, WhatsApp, contact exchange or private document exchange.
- Seller confidential minimum price is never exposed to Buyer.
- Buyer private target price and private notes remain protected.
- Historical proposals and negotiation events are immutable.
- Commercial Deal changes create a new Deal version and require appropriate reconfirmation.
- Final Deal and Booking are separate steps.
- Booking requires the required Buyer and Seller confirmations.
- Quality uses the shared commodity-specific Quality Parameter Master.
- Commission is calculated server-side and historical values remain unchanged.

# 7. Broker Information Architecture

- Home
- Requirements
- Matching
- Deals
- Orders
- CRM
- Payments
- More: Quality, Documents, Commission, Disputes, Reports, Notifications, Settings

# 8. Broker Dashboard

- Header: company/Broker name, notifications, profile and optional connectivity state.
- Action Required: New Requirements, Seller Counters, Buyer Counters, Awaiting Confirmation, Ready to Book and Delayed Dispatch.
- Pipeline: New → Sourcing → Matching → Negotiating → Confirming → Booked.
- Active Work: highest-priority requirements and Deals.
- Today's Follow-ups: Buyer, Seller, quality, dispatch and payment tasks.
- Compact KPIs: Active Deals, Open Requirements, Pending Responses, Awaiting Confirmation, Dispatch Due and Commission This Month.

# 9. Buyer Requirements

- Requirement inbox with mobile cards and desktop table/grid.
- Search and filters.
- Requirement detail: product, quality, commercial terms and next action.
- Primary actions: Find Seller or Ask Buyer.
- Human-readable status labels.
- Clarification workflow.
- Assignment/reassignment within Broker organization.

# 10. Seller Supply & Matching

- Broker searches active Seller lots relevant to a Buyer Requirement.
- No public Seller marketplace.
- Filters: commodity, grade, quantity, location, availability date, price, quality status, lot status, packaging and payment terms.
- Matching workspace compares Buyer need to Seller lots.
- Initial match weights: Commodity 35%, Grade 25%, Price 20%, Location 10%, Quantity 7%, Delivery date 3%.
- Match result is 0–100 with plain-language explanation.
- Broker can manually override with a 1-tap action using a dropdown reason selector.
- Partial fulfillment is supported when the Buyer Requirement permits it.

# 11. Quality

- Use commodity-specific Quality Parameter Master.
- Quality status: Verified, Needs Review, Rejected.
- Broker actions: Approve, Reject, Request Correction, Request New COA/Lab Report, Mark Pending.
- Quality comparison shows Buyer requirement versus Seller lot value.
- Quality decisions are lot-specific and auditable.

# 12. Negotiation

- Seller negotiation: Seller ↔ Broker only.
- Buyer negotiation: Buyer ↔ Broker only.
- Broker can negotiate price, quantity, delivery, payment, packaging, freight, inspection and quality/documents.
- Proposal versions are immutable.
- Negotiation timeline is chronological and easy to read.
- There must be no shared conversation object that exposes the opposite party's private information.

# 13. Deal, Confirmation & Booking

1. Broker creates Final Deal from negotiated terms.
1. System creates an immutable Deal snapshot/version.
1. Buyer confirms separately.
1. Seller confirms separately.
1. Broker validates both confirmations.
1. Broker finalizes Booking.
1. System generates a unique Booking ID.
1. Any post-confirmation commercial change creates a new Deal version and reconfirmation flow.

# 14. Orders, Dispatch & Documents

- Order stages: Booked → Dispatch Planned → Dispatched → In Transit → Delivered → Completed.
- Exceptions: Delayed, Cancelled, Disputed.
- Dispatch data includes authorized operational details such as date, quantity, vehicle, transporter, loading, destination, LR, e-way bill and ETA.
- Documents include COA, lab report, quality certificate, specification, invoice, LR, e-way bill, weighment slip, dispatch and settlement documents.
- Document states: Required, Received, Verified, Missing.

# 15. Payments, Settlement & Commission

- Keep Buyer Payable, Seller Settlement, Broker Commission, Actual Payment and Outstanding separate.
- MVP commission supports fixed commission per MT.
- Commission is calculated server-side.
- Historical commission is immutable.
- BrokerBridge is not a full accounting replacement.

# 16. CRM & Disputes

- CRM: Call Log and Next Follow-Up Date per contact card.
- Contact cards show last activity, open requirements, active Deals and next action.
- Finance: Commission Earned and Payment Status.
- Dispute categories: Quality, Quantity, Delivery, Document, Payment, Commercial, Other.
- Broker can review evidence, add internal notes, request documents, communicate separately and record resolution.
- Disputes never create direct Buyer-Seller communication.

# 17. Notifications & Search

- Notifications cover requirements, Seller responses, Buyer responses, quality, proposals, confirmations, Deals, Booking, dispatch, documents, payments, disputes and CRM tasks.
- Actionable notifications deep-link directly to the relevant work item.
- Search supports Requirement ID, Deal ID, Booking ID, Commodity, Buyer, Seller, authorized mobile number, vehicle number, invoice number and CRM contact.
- Filters support status, commodity, date, Buyer, Seller, quality, payment and dispatch.

# 18. Mobile-First and Low-Bandwidth Requirements

- First-class target: 360px width; usable through 414px+ Android devices.
- Minimum 48×48px touch targets.
- Primary action approximately 56px.
- Zero Data-Wall rule: no heavy data tables are loaded on the mobile shell. All list views are card-based.
- No horizontal scrolling.
- Primary action near thumb zone.
- Search accessible without excessive navigation.
- Skeleton loading, empty states, inline errors and retry.
- Cache master data and avoid unnecessary payload/image loading.
- Safe offline candidates: CRM notes, follow-up tasks and non-critical notes.
- Final Deal, Booking, price commitment, confirmation, commission calculation, payment confirmation and inventory reservation require live server validation.

# 19. Desktop

Desktop is the same Broker product expanded. Use sidebar + main workspace + optional context panel. Desktop may add wider comparisons, tables, keyboard interaction, larger timelines and advanced reports, but it must use the same permissions, state machine and business rules as mobile.

# 20. Security & Audit

- Organization isolation.
- Server-side authorization.
- Channel-level authorization.
- Confidential pricing protection.
- Buyer-private and Seller-private information protection.
- Document authorization.
- Server-side financial calculations.
- Server-side state-transition validation.
- Material events are recorded in an immutable audit history.

# 21. Broker Data Model

- BrokerOrganization
- BrokerUser / organization membership
- Requirement
- RequirementQuality
- SellerInventoryLot / Availability
- LotQuality
- QualityDocument
- QualityVerification
- Match
- Proposal
- ProposalVersion
- Negotiation
- NegotiationEvent
- Deal
- DealVersion
- Booking
- CommissionRule
- CommissionLedger
- Payment
- Settlement
- Dispatch
- TransactionDocument
- Dispute
- Notification
- CRM Contact
- CRM Activity
- CRM Task
- AuditLog

# 22. What the Broker Should Not See by Default

- Database information.
- Technical status codes.
- Raw RLS/authorization concepts.
- Full audit logs.
- Detailed AI mathematics.
- Raw quality schemas.
- Complex financial ledgers.
- All master data.
- Large analytics walls.
- Developer terminology.

# 23. Primary Broker Actions

- Review Requirement
- Find Seller
- Check Quality
- Send Proposal
- Review Counter
- Create Deal
- Check Confirmations
- Finalize Booking
- Track Order
- Handle Issue
- Add Follow-up

# 24. Broker-Facing State Machine

New → Review → Finding Supply → Match Found → Negotiating → Waiting for Confirmation → Ready to Book → Booked → Dispatch → Delivered → Payment → Completed

Exceptions: Cancelled, Expired, Disputed, Delayed and Partially Fulfilled.

# 25. MVP Scope

- Broker login and organization.
- Dashboard.
- Buyer Requirement inbox and detail.
- Seller inventory search.
- Matching and explainability.
- Quality compatibility and verification.
- Seller and Buyer negotiations.
- Immutable proposal history.
- Deal Builder and immutable Deal versions.
- Buyer and Seller confirmations.
- Broker Booking finalization.
- Commission.
- Dispatch.
- Documents.
- Payments/settlement tracking.
- Disputes.
- Notifications.
- CRM (Call Log and Next Follow-Up Date per contact card).
- Audit logging.
- Security and authorization.
- Mobile and desktop responsive behavior.

# 26. Out of Scope

- Public marketplace.
- Buyer-Seller direct chat/calling/WhatsApp/email.
- Autonomous AI negotiation.
- Public Seller directory.
- Commodity exchange/order book.
- Full ERP/accounting replacement.
- Advanced predictive pricing.
- Automated logistics marketplace.
- Cryptocurrency/wallet.
- Uncontrolled marketing system.

# 27. Development Sequence

- Sprint 21 — Broker Foundation Verification: Broker role, routing, shared entities, security and integration verified.
- Sprint 22 — Broker Shell & Navigation: Zero Data-Wall card-based mobile shell at 360px. Primary action in thumb zone. Aggressive master-data caching for 2G/3G networks.
- Sprint 23 — Broker Dashboard: Action-first Broker cockpit.
- Sprint 24 — Buyer Requirements: Requirement inbox and requirement processing.
- Sprint 25 — Seller Supply: Broker-only seller inventory search and lot selection.
- Sprint 26 — Matching Engine: Explainable match recommendations and 1-tap manual override with dropdown reason selector.
- Sprint 27 — Quality Verification: Structured quality, COA and verification workflow.
- Sprint 28 — Negotiation: Separate Buyer-Broker and Seller-Broker negotiations.
- Sprint 29 — Deal & Confirmation: Final Deal, versioning and two-party confirmation.
- Sprint 30 — Booking & Order Operations: Booking, dispatch, delivery and exceptions.
- Sprint 31 — Documents & Finance: Documents, payments, settlement and commission.
- Sprint 32 — CRM & Disputes: Call Log, Next Follow-Up Date and dispute resolution.
- Sprint 33 — Reports & Broker Intelligence: Operational reports and decision-focused analytics.
- Sprint 34 — Hardening & End-to-End UAT: Security, concurrency, mobile, low-bandwidth and full workflow validation.

# 28. Acceptance Criteria

- Broker can log in securely.
- Normal Broker can complete day-to-day Broker work.
- Broker sees only authorized organization data.
- Broker can receive and understand Buyer Requirements.
- Broker can find Seller supply and compare lots.
- Broker can use explainable matching and manual override.
- Broker can verify quality and request documents.
- Broker can negotiate separately with Buyer and Seller.
- Buyer and Seller cannot communicate directly.
- Confidential pricing remains protected.
- Proposal and Deal history is immutable.
- Buyer and Seller confirmations are recorded separately.
- Broker cannot finalize Booking before required confirmations.
- Booking receives a unique ID.
- Commission is calculated server-side and historical values remain stable.
- Broker can coordinate dispatch, documents, payments, CRM and disputes.
- Material actions are audited.
- Mobile interface works at 360px and desktop adapts.
- Common Broker tasks can be completed without technical training.

# 29. Product Design Rule

1. If the Broker does not need to perform an action, automate it or hide it.
1. If the system can determine the answer, show the answer instead of making the Broker calculate it.
1. If a dropdown can replace typing, use the dropdown.
1. If one action can replace five screens, use the one action.
1. If technical complexity can remain in the backend, keep it out of the UI.

# 30. Intended Broker Experience

Broker opens BrokerBridge → sees what needs attention → opens a requirement → Find Seller → selects a strong match → checks quality → negotiates Seller → negotiates Buyer → creates Final Deal → Buyer confirms → Seller confirms → Broker finalizes Booking → tracks dispatch → tracks payment → closes issue/deal.

# 32. Seller-Side Integration Points

- The Seller dashboard (Sprints 13–20) used development-mode simulators where the Broker Dashboard did not yet exist. When building Broker sprints, connect to these existing Seller-side components rather than rebuilding them.

# Broker Request Trigger — connect in Sprint 23

- Seller side ready: the broker_requests database table and the Seller Broker Request Inbox are fully production-ready from Sprint 16.
- What the Broker sprint must add: the Broker UI outbound request trigger that writes a new record to broker_requests.
- Do not rebuild: Seller inbox, response actions (Accept / Reject / Counter), request notifications and deep links are already implemented.

# Broker Finalization Action — connect in Sprint 27

- Seller side ready: the Final Confirmation flow, Visual Diff engine and idempotent Booking creation are fully production-ready from Sprint 18.
- The Seller-side finalization was tested using a dev-mode simulator (DevFinalizationGateTester) in the absence of the real Broker UI.
- What the Broker sprint must add: the real Broker Finalization UI that calls the existing finalizeDealAction server action.
- Do not rebuild: Seller Final Confirmation, Visual Diff, Booking creation, Booking ID generation and inventory lock are already implemented.

# 31. Final Product Principle

BrokerBridge Broker is a simple, mobile-first brokerage operating console sitting on top of a sophisticated transactional platform. The system handles matching logic, permissions, confidential data, versioning, auditability, calculations, state transitions, concurrency, notifications, storage and security. The Broker handles decisions and actions.
