**BrokerBridge**

**Seller Dashboard & Seller-Side Product Requirements**

**Unified PRD — Version 3.0**

*Merged from v1.1 + v2.0 · Incorporating Strategic Enhancements*

Production-Ready Seller Scope · August 2026

**Product Boundary**

*This document defines only what the Seller can see, create, edit, receive, confirm, and track inside BrokerBridge. Buyer, Broker, Admin, global matching, and marketplace logic are referenced only where they directly affect Seller behavior.*

**⭐  New in v3.0 (Strategic Enhancements)**

*1-Click Availability Renewal  ·  Visual Diff on Deal Confirmation*

# 0. Document Lineage & Purpose

This PRD is the single source of truth for the Seller side of BrokerBridge. It merges the operational depth of v1.1 (Loading Readiness, Quality/Lab, State Machines, Production Rules) with the structural clarity of v2.0 (WhatsApp removal, Seller Final Confirmation, Deal Versioning, Broker Finalization → Booking workflow) and adds two strategic UX enhancements from leadership.

| **Source** | **Version** | **What This PRD Carries Forward** |
| --- | --- | --- |
| Seller PRD | v1.1 | Dashboard hierarchy, availability state machine, loading readiness, dynamic quality, lab testing, dispatch, payment, notification events, security, audit, error/edge-case rules, screen list, data model. |
| Seller PRD | v2.0 | WhatsApp removed from deal flow, Seller Final Deal Confirmation (mandatory state), Deal Versioning (immutable snapshots), Broker Finalization → Booking separation, explicit availability contract, AI = recommendation only. |
| Leadership | v3.0 | 1-Click Availability Renewal (Quick Renew/Duplicate after expiry). Visual Diff on Final Deal Confirmation screen (green/red delta from previous version). |

# 1. Product Definition & Non-Negotiable Rules

BrokerBridge Seller is a secure, broker-controlled commodity supply workspace where a verified Seller manages inventory and quality, receives broker-originated commercial requests, responds to negotiation, explicitly confirms final terms, fulfils booked transactions, and tracks dispatch and settlement — without direct Buyer communication.

| **Rule** | **Requirement** |
| --- | --- |
| No direct Buyer contact | No Buyer directory, direct chat, calling, email, or contact details exposed to Seller at any layer (UI, API, database, documents, notifications). |
| Broker-mediated commercial flow | All commercial proposals and negotiation responses move through the Broker. Seller never initiates contact with Buyer. |
| AI = Recommendation only | AI ranks/recommends Seller availability. AI never selects, commits, negotiates, finalizes a deal, or creates a Booking. Broker is the decision-maker. |
| Seller Final Confirmation (mandatory) | Seller must explicitly review and confirm the exact final Deal Version snapshot before Broker can finalize. |
| Final terms are immutable | Confirmed commercial terms cannot be edited. Any post-confirmation amendment creates a new version and audit event. |
| Broker Finalization → Booking | Broker Finalization is a distinct state/action. Only after it succeeds does the system create a unique Booking ID. Confirmation ≠ Booking. |
| WhatsApp removed from state machine | Quotation, negotiation, confirmation, finalization, and Booking are in-app/system workflows. WhatsApp is notification-only, never a transactional state trigger. |
| Structured data | Commodity, grade, unit, location, packaging, payment, delivery values come from master data. Free text only where explicitly permitted. |
| Lot-level truth | Inventory tracked by lot/batch so quantity, price, quality, documents, and reservations remain traceable. |
| Dynamic quality | Quality fields generated from selected commodity's configured template, not hard-coded. |
| Confidential minimum price | Seller's minimum acceptable price is visible only to authorized Broker/Admin roles, never Buyer-facing. |
| Auditability | All material Seller actions logged: actor, organization, entity, timestamp, old/new values, deal/booking reference. |
| Production resilience | Forms, uploads, notifications, and state changes handle retry, failure, stale data, low bandwidth, and duplicate submissions safely. |

# 2. Established Foundation — Regression-Protected

*📌  These items are carried forward from the completed sprint record. Treat as regression-protected functionality — not to be redesigned casually.*

| **Area** | **Status** | **Source** |
| --- | --- | --- |
| Authentication & role routing | Supabase Auth, OTP signup, role-based routing, protected Seller workspace. | Sprints 1–2 |
| Master data | Commodities, grades, locations, logistics; inactive records as soft-deletes. | Sprint 3 |
| Seller onboarding & KYC | Company profile onboarding, Admin approval pipeline, Buyer/Seller RLS isolation. | Sprint 4 |
| Seller Availability Engine | Availability form, Seller Hub, quantity, price, warehouse, Valid Until fields. | Sprint 6 |
| AI Match foundation | Broker-side matching with structured Seller availability and confidence scoring. | Sprint 7 |
| Quotation / deal flow | Broker quotation, PDF generation, accepted-quote booking workflow. | Sprints 8–9 |
| Dispatch & secure files | Seller dispatch form, protected invoice/LR storage. | Sprint 10 |
| Payments / disputes | Payment confirmation tracking, Admin dispute resolution. | Sprint 11 |
| Notifications | In-app, WhatsApp (notification-only), email notification architecture, bell, atomic cron dispatcher. | Sprint 12 |
| Analytics / partial fulfillment | KPI aggregations, partial-fulfillment state logic. | Sprint 12 |

# 3. What Version 3.0 Adds & Tightens

## From v2.0 (Structural Changes)

- WhatsApp permanently removed from quotation, negotiation, confirmation, and Booking state transitions.
- Seller Final Deal Confirmation is a mandatory transaction state — not an optional button.
- Deal Versioning: every material commercial revision creates an immutable versioned snapshot.
- Broker Finalization → Booking: two distinct states. Booking ID issued only after Broker Finalization succeeds.
- Explicit availability creation contract: Grade, Lot/Batch, Availability From/Expiry, COA, and Confidential Minimum Price are required, not optional.
- AI = recommendation only, with a hard Broker decision gate before any commercial action.

## From v1.1 (Operational Depth)

- Action-first dashboard with operational priority hierarchy (P0/P1/P2 widgets).
- Loading Readiness as a first-class pre-deal supply attribute with structured state machine.
- Structured Lab Testing record (not just a PDF attachment) linked to the lot.
- Quality freshness metadata: Source, Test Date, Valid Until, and Verification Status.
- Seller-triggered operational notifications: Ready for Loading, Loading Started, Loading Delayed, etc.
- Complete error/edge-case and recovery rules for production resilience.
- Full 24-section acceptance criteria tied to persistence, authorization, audit, and retry.

## New in v3.0 (Strategic UX Enhancements)

**⭐  Enhancement 1: 1-Click Availability Renewal**

Because the system automatically expires availabilities by Valid Until date, Sellers should never be forced to re-enter an entire form from scratch. If 100 MT of Chana expires, the Seller clicks "Quick Renew" (or "Duplicate") on the expired record.

- System pre-fills all fields from the expired record: commodity, grade, lot, quantity, price, location, quality, loading settings.
- Seller updates only the fields that changed — typically Availability From, Valid Until, and Asking Price.
- System creates a new Availability record (the original expired record is preserved in history).
- Quick Renew is available on any record in Expired status; it is not available on Active or Reserved records.
- The resulting new record enters the standard Draft → Pending Approval → Active workflow.
*📌  UX target: Seller should complete a renewal in under 60 seconds. Pre-fill accuracy is critical — never auto-fill price from expired records without surfacing it for review.*

**⭐  Enhancement 2: Visual Diff on Deal Confirmation Screen**

Since every commercial revision creates an immutable Deal Version, the Final Deal Confirmation screen must visually highlight exactly what changed from the previous version so the Seller never has to guess what they are confirming.

- Changed fields highlighted in green (increased in Seller's favor or new addition) or red (reduced or removed).
- Unchanged fields shown in normal weight with no color indicator.
- A "What Changed" summary banner at the top of the screen lists the changed fields before the full snapshot.
- If it is Version 1 (no prior version exists), the diff section is omitted and replaced with a "First Version" label.
- The diff is computed server-side from the immutable version snapshots; the UI renders the annotated result.
- Diff display is read-only — the Seller cannot edit from this screen. Actions are only "Confirm Final Terms" or "Request Broker Correction".
*📌  Design target: Apple-tier clarity. At a glance, the Seller must know: "Price went from ₹2,100/MT to ₹2,050/MT (red). Quantity unchanged. Payment terms unchanged." No ambiguity about what is being confirmed.*

# 4. Seller Dashboard — Operational Command Center

The Seller dashboard answers, in one screen: What stock do I have? What needs my action? What is ready to load? What commercial requests are waiting? What orders are active? Are my quality documents valid? What money is pending?

The dashboard is operational, not a marketplace discovery page. Every widget must show current state + count/value + the next useful action.

## 4.1 Dashboard Widget Hierarchy

| **Priority** | **Widget** | **Seller Sees** | **Primary Action** |
| --- | --- | --- | --- |
| P0 | Action Required | All time-sensitive items: broker requests, pending confirmation, quality correction, dispatch due, missing document, delayed loading, payment exception. | Open relevant task |
| P0 | Active Inventory | Active lots, available/reserved quantities, availability expiry. Expired availability flagged. | View / update lot |
| P0 | Broker Requests | New broker-originated commercial requests with response deadline. Never Buyer contact details. | Review / accept / reject / counter |
| P0 | Final Deal Confirmation | Deals awaiting Seller final confirmation. Prominent action. Exact final snapshot shown. | Review & confirm |
| P1 | Negotiations | Open negotiations, latest version/status. | Open negotiation timeline |
| P1 | Loading Readiness | Ready / Scheduled / Loading / Delayed / Blocked lots. | Update loading state |
| P1 | Quality & Lab | Lots pending review, missing tests, expiring reports, verified lots. | Open quality / lab |
| P1 | Confirmed Bookings | Bookings created after Broker Finalization; Booking ID and locked terms. | View order |
| P1 | Dispatch Pending | Booked transactions needing dispatch action. | Open dispatch workflow |
| P1 | Payments | Pending / part-paid / paid / overdue / disputed receivables. | View settlement |
| P2 | Notifications | Unread alerts with priority and channel status. | Open notification center |
| P2 | Quick Actions | Add Availability, Update Stock, Upload Lab Report, Mark Ready for Loading, View Broker Requests. | Start workflow |

## 4.2 Dashboard Behavior Rules

- Every card must deep-link to the exact filtered screen that resolves the issue.
- Critical action items appear above informational metrics.
- Expired availability and invalid/expired lab reports must be visually distinguishable from valid records.
- Dashboard data must tolerate temporary network failure; stale data labeled with timestamp rather than silently presented.
- Pull-to-refresh revalidates server truth and reconciles local state.

## 4.3 Dashboard States

| **State** | **Meaning** |
| --- | --- |
| Normal | No critical action pending; show operational inventory, requests and orders. |
| Action Required | One or more time-sensitive Seller actions exist. |
| Warning | Expiring availability, expiring lab report, loading delay, insufficient quantity or document issue. |
| Blocked | Seller account, lot, quality, payment or fulfilment action blocked by approval/state rule. |
| Offline / Stale | Latest data could not be refreshed; cached values shown with timestamp and retry control. |

# 5. Seller Navigation & Module Boundary

| **Module** | **Seller Purpose** |
| --- | --- |
| Dashboard | Operational command center. |
| My Commodities / Availability | Create, edit, monitor, renew Seller supply lots. |
| Quality & Lab | Enter dynamic quality values, upload reports, track verification/expiry. |
| Broker Requests / Deals | Review broker-originated requests, respond, track negotiation, confirm final version. |
| Orders / Dispatch | Fulfil booked transactions, maintain dispatch status and details. |
| Documents | Access Seller-authorized KYC, lot, and transaction documents. |
| Payments | View settlement amounts, payments, outstanding, and exceptions. |
| Notifications | See actionable system/Broker notifications and delivery status. |
| Profile / KYC | Manage organization profile within permission rules. |
| User Management | Seller Admin manages permitted users for own organization. |

# 6. Seller Availability & Commodity Logic

The availability record is the core Seller-side business object. It is not a marketplace listing; it is a controlled supply record the Broker uses for matching and commercial coordination. The following fields form the explicit availability creation contract.

## 6.1 Availability Creation Fields (Explicit Contract)

| **Section** | **Field** | **Requirement / Logic** |
| --- | --- | --- |
| Commodity | Commodity | Searchable master-data selection; mandatory. |
| Commodity | Category / Sub-category | Shown when configured by commodity master. |
| Commodity | Grade | Filtered by commodity; mandatory when applicable. |
| Commodity | Batch / Lot Number | Required for traceability where applicable. |
| Quantity | Total Quantity | Number > 0. |
| Quantity | Available Quantity | Cannot exceed total or become negative. |
| Quantity | Reserved Quantity | System-controlled; Seller should not overwrite. |
| Quantity | Unit | Master-data selection. |
| Quantity | Minimum Order Quantity | Optional; if present must be ≤ available quantity. |
| Price | Asking Price | Mandatory positive value. |
| Price | Price Unit | Explicit and compatible with UOM. |
| Price | Price Valid From / Until | Validity window enforced; expired prices not usable. |
| Price | Confidential Minimum Price | Optional; visible only to authorized Broker/Admin, never Buyer-facing. |
| Location | State → District → City | Cascading master-data selectors. |
| Location | Warehouse / Stock Location | Master data where available. |
| Location | Loading Point | Specific operational loading point. |
| Availability | Available From | Current or future date. |
| Availability | Valid Until / Expiry | Must be after Available From. System auto-expires on this date. |
| Loading | Loading Status | Structured state enum (see Section 7). |
| Loading | Loading Duration | Stored numerically; master-data selection. |
| Loading | Loading Remarks | Operational constraints or conditions. |
| Quality | Dynamic Quality Parameters | Loaded from commodity quality template (see Section 8). |
| Documents | COA / Lab Report | Attached to exact lot; verification tracked. |
| Documents | Lot / Product Photos | Optional unless required by commodity rules. |
| Commercial | Packaging Available | Master-data selection where applicable. |
| Commercial | Delivery Terms Offered | Master data. |
| Commercial | Remarks | Controlled text limit; no Buyer information. |

## 6.2 Availability Status Machine

| **Status** | **Seller Meaning** | **Allowed Seller Action** |
| --- | --- | --- |
| Draft | Record not submitted for activation. | Edit / submit / discard. |
| Pending Approval | Submitted; awaiting configured review. | View / respond to correction. |
| Active | Available to eligible Broker workflows. | Update non-locked fields; pause/expire if permitted. |
| Partially Reserved | Part of quantity allocated to transactions. | Manage remaining available quantity. |
| Reserved | Quantity fully reserved. | View only; no new allocation. |
| Sold | No available quantity remains. | View only. |
| Expired | Validity window ended. System auto-expired. | Quick Renew (1-Click) → new Draft with all fields pre-filled. |
| Cancelled | Seller withdrew per policy. | View audit history. |

## 6.3  ⭐  1-Click Availability Renewal (Quick Renew)

**Why:**  Availability records auto-expire by Valid Until date. Without Quick Renew, sellers must re-enter the entire form — a painful, error-prone experience especially for repeat inventory.

| **Step** | **Action** | **System Behavior** |
| --- | --- | --- |
| 1 | Seller sees Expired record on dashboard or availability list. | Record shown with "Expired" badge and "Quick Renew" CTA. |
| 2 | Seller taps "Quick Renew" (or "Duplicate"). | System opens a pre-filled availability form cloned from the expired record. |
| 3 | Seller reviews and updates fields (typically: Dates, Price, Quantity). | All other fields pre-filled. Price surfaced prominently for mandatory review before submit. |
| 4 | Seller submits. | New Availability record created in Draft status. Original expired record preserved in history. |
| 5 | New record enters approval workflow. | Draft → Pending Approval → Active (standard flow). |

*📌  Quick Renew is available only on Expired records. Active, Reserved, or Sold records use the standard Edit workflow.*

## 6.4 Production Validation Rules

- All server-side numeric validation must mirror UI validation; client validation is not trusted.
- Concurrent edits must not overwrite newer server truth without conflict detection.
- Reserve/release/consume quantity actions must be transactional.
- Duplicate submit must be idempotent — create one record only.
- Expired availability automatically excluded from active matching until renewed.
- Any price change affecting an active lot must create an audit event.

# 7. Loading Readiness — Pre-Deal Supply Attribute

Loading readiness is a pre-deal commercial attribute, not merely a post-booking dispatch field. A Broker needs to know whether a matched lot can become a dispatchable shipment and how long preparation will take.

## 7.1 Loading Fields

| **Field** | **Type / Values** | **Logic** |
| --- | --- | --- |
| Loading Status | Controlled enum | Not Ready / Ready / Scheduled / Loading / Loaded / Delayed / Blocked. |
| Loading Duration | Controlled + numeric | Same Day / 1 / 2 / 3 / 4 / 5 / More Than 5 Days / Custom. Stored numerically for matching. |
| Loading Start | Date/time | Actual or expected start date/time when applicable. |
| Loading Capacity | Number + unit | Optional daily loading capacity. |
| Loading Remarks | Short text | Reason, instructions, or operational constraints. |
| Last Updated | System timestamp | Shows freshness of readiness data. |

## 7.2 Loading State Machine

| **State** | **Meaning** | **Typical Next State** |
| --- | --- | --- |
| Not Ready | Stock exists but cannot currently be loaded. | Ready / Blocked |
| Ready | Seller confirms lot is operationally ready. | Scheduled / Loading |
| Scheduled | Loading date/time has been arranged. | Loading / Delayed |
| Loading | Physical loading has started. | Loaded / Delayed |
| Loaded | Quantity physically loaded. | Dispatch / Completed |
| Delayed | Loading cannot meet current schedule. | Scheduled / Ready / Blocked |
| Blocked | Operational, quality, document, or commercial issue prevents loading. | Ready / Resolved |

## 7.3 Broker Notification Triggers

- Seller marks a lot Ready for Loading.
- Seller changes loading date/time.
- Seller marks Loading Started.
- Seller marks Loading Delayed.
- Seller marks Loading Completed/Loaded.
- Available quantity materially changes.
- Loading status becomes Blocked and requires attention.
*📌  Notifications route through BrokerBridge notification architecture (in-app + WhatsApp/email where configured). They do not create a direct Buyer–Seller communication channel.*

# 8. Quality & Laboratory Testing

Quality is a first-class Seller capability. The product must support structured commodity-specific quality and a traceable laboratory evidence layer. A PDF alone is insufficient for durable operational data. Quality must not be a single free-text field.

## 8.1 Dynamic Quality Engine

When the Seller selects a commodity, the UI loads the configured quality template. Parameters may use numeric, text, boolean, or controlled values, and may carry: unit, minimum, maximum, guaranteed value, typical value, testing method, required flag, and active flag.

## 8.2 Quality Record Model

| **Field** | **Requirement** |
| --- | --- |
| Parameter | Commodity-specific parameter from master mapping. |
| Value | Seller-entered or imported result using the parameter's type and unit. |
| Min / Max | Optional declared or contractual bounds. |
| Guaranteed Value | Optional declared guarantee. |
| Typical Value | Optional typical reference. |
| Testing Method | Optional methodology used for the result. |
| Source | Seller Declared / Internal QC / Third-Party Lab / Broker Verified / Other. |
| Test Date | Date result was generated. |
| Valid Until | Optional validity/expiry date. |
| Verification Status | Pending / Under Review / Verified / Correction Required / Rejected / Expired. |

## 8.3 Laboratory Test Record

| **Field** | **Requirement** |
| --- | --- |
| Lab Testing Required | Yes / No. |
| Test Status | Not Required / Required / Sample Pending / Testing In Progress / Report Uploaded / Broker Review / Verified / Correction Required / Rejected / Expired. |
| Laboratory Name | Structured or approved lab name; free text only if configured. |
| Laboratory Location | State/city/address as configured. |
| Sample ID / Batch ID | Links test to physical sample and Seller lot. |
| Sample Date | Date of sample collection. |
| Test Date | Date testing occurred. |
| Report Number | Laboratory reference. |
| Report Date | Date report was issued. |
| Test Parameters | Structured results mapped to commodity quality template. |
| Report File | PDF/image upload with secure access control. |
| Valid Until | Optional expiry date. |
| Verification | Broker/Admin verification state. |

## 8.4 Quality Freshness & Display

The dashboard must show quality freshness so operational users can distinguish recent valid evidence from stale evidence.

**Example:**  "Moisture 11.2% — Third-Party Lab — Tested 7 days ago — Verified"

## 8.5 Quality & Lab Rules

- A lot may be published without a lab report only when the commodity policy permits it.
- Mandatory quality parameters must be complete before the lot can reach Active state.
- Expired laboratory evidence must not appear as current verified evidence.
- Editing verified quality creates a new value/version and returns the record to review where policy requires.
- Only authorized Broker/Admin users can mark quality/lab evidence as Verified.
- The Seller can see its own quality history but cannot modify Broker verification outcome.

# 9. AI Match — Recommendation Only; Broker = Decision-Maker

AI evaluates authorized Seller availability against the Buyer requirement using configured signals: commodity, grade, quantity, price proximity, location, availability dates, loading readiness, and quality compatibility.

- AI returns ranked recommendations with explainable match factors and confidence scores.
- Broker reviews recommendations and selects which Seller/availability to approach.
- Only the Broker can initiate the Seller-side commercial request.
- AI cannot: accept a Seller, negotiate, finalize a deal, create a Booking, or bypass Broker approval.
*📌  This preserves the established principle: AI presents; Broker decides; Seller confirms; system books.*

# 10. Broker-Originated Deal Requests & Seller Negotiation

## 10.1 What Seller Sees vs. Does Not See

| **Seller CAN See** | **Seller Must NOT See** |
| --- | --- |
| Commodity and required specification | Buyer phone number |
| Requested quantity | Buyer email |
| Delivery location / requirement | Buyer direct WhatsApp or contact |
| Proposed Seller-side commercial terms | Buyer private notes |
| Payment terms proposed | Buyer internal account information |
| Broker messages and transaction status | Other buyer/seller private accounts |

## 10.2 Seller Response Actions

- Accept Broker proposal
- Reject Broker proposal (with reason where configured)
- Counter price
- Counter quantity
- Counter delivery date
- Counter payment terms (where permitted)
- Add remarks to Broker
Every response is linked to a Negotiation/Deal ID, creates an immutable event, and is delivered to the Broker-side workflow only — never directly to the Buyer.

# 11. Deal Versioning — Immutable Commercial Snapshots

Every material commercial proposal is a versioned snapshot. Historical versions are permanently read-only.

| **Field** | **Requirement** |
| --- | --- |
| Deal Version | Sequential version number for each commercial revision. |
| Snapshot Contents | Commodity, grade, lot, quantity/unit, seller rate, commission, delivery/location, delivery date, payment terms, quality snapshot, transport terms, special conditions. |
| Created By / At | Actor, role, and timestamp. |
| Status | Draft / Proposed / Countered / Seller Confirmed / Buyer Confirmed / Broker Finalized / Superseded. |
| Immutability | Confirmed or superseded versions cannot be edited at any layer. |
| Amendment rule | Any post-confirmation change creates a new version and audit event. |

# 12. Seller Final Deal Confirmation — Mandatory State

*📌  Seller Final Deal Confirmation is a mandatory transaction state, not an optional button. Broker cannot finalize without it.*

## 12.1 Confirmation Workflow Steps

| **Step** | **Action** |
| --- | --- |
| 1 | Seller opens the exact final Deal Version (deep-linked from dashboard action item). |
| 2 | System displays the complete commercial snapshot with all terms. |
| 3 ⭐ (v3.0) | System displays Visual Diff: changed fields highlighted green (favorable) or red (reduced). "What Changed" banner lists delta fields at top of screen. |
| 4 | Seller reviews commodity, grade, lot/batch, quantity, price, delivery, payment, quality, loading, and all applicable terms. |
| 5 | Seller explicitly confirms the displayed version ("Confirm Final Terms" button). |
| 6 | Confirmation stores: Seller actor, timestamp, Deal Version reference — immutable audit event. |
| 7 (if rejected) | Seller taps "Request Broker Correction." Broker must revise; a new Deal Version is created. Seller does not edit commercial terms directly. |

## 12.2  ⭐  Visual Diff Screen — Specification

| **Element** | **Requirement** |
| --- | --- |
| Version label | Show exact version number being confirmed (e.g., "Version 3 of 3"). |
| What Changed banner | Summary at top: list of changed field names. E.g., "Price changed · Delivery date changed." Shown only when a previous version exists. |
| Changed field — reduced | Shown in red with strikethrough of old value → new value. E.g., "₹2,100/MT → ₹2,050/MT" in red. |
| Changed field — increased / added | Shown in green. E.g., "30 days payment terms → 45 days" in green. |
| Unchanged fields | Normal weight, no color indicator. |
| First version | No diff section; shows "First Version" label instead. |
| Diff source | Computed server-side from immutable version snapshots. UI renders annotated result only. |
| Actions | "Confirm Final Terms" or "Request Broker Correction." No editing from this screen. |
| Audit | Actor, timestamp, version, and event recorded on confirm or rejection. |

# 13. Canonical Finalization → Booking Workflow

**Critical Rule:**  Seller Confirmation ≠ Booking.  Broker Finalization ≠ Booking.  Broker Finalization → System creates Booking ID.

| **Step** | **Action** |
| --- | --- |
| 1 | Broker prepares final commercial terms → Deal Version created. |
| 2 | Seller reviews final version with Visual Diff (see Section 12.2). |
| 3 | Seller performs Final Deal Confirmation (explicit action, audited). |
| 4 | Required Buyer-side confirmation completed through Broker-controlled workflow. |
| 5 | Broker performs explicit Finalization. |
| 6 | System validates: all required confirmations present + current version is valid. |
| 7 | System creates unique Booking ID. |
| 8 | Booking becomes locked operational transaction record. |
| 9 | Seller proceeds to Dispatch. |

# 14. Orders, Dispatch & Fulfilment

## 14.1 Order Status Machine

| **Status** | **Seller Meaning** |
| --- | --- |
| Booked | Broker finalized; system created Booking ID. Seller can prepare fulfilment. |
| Dispatch Planned | Dispatch preparation in progress. |
| Dispatched | Commodity has left loading location. |
| In Transit | Shipment is moving. |
| Delivered | Delivery has been recorded. |
| Completed | Transaction operationally completed. |
| Cancelled | Booking cancelled by authorized workflow. |
| Disputed | Transaction has an active dispute. |

## 14.2 Seller Dispatch Fields

| **Field** | **Logic / Validation** |
| --- | --- |
| Dispatch Date | Date validation against booked state/workflow. |
| Quantity Dispatched | > 0 and cannot exceed remaining bookable quantity. |
| Vehicle Number | Indian vehicle plate format validation. |
| Vehicle Type | Master data. |
| Transporter | Master data or permitted controlled free text. |
| Driver Name / Mobile | Required where operational workflow requires it. |
| Loading Location | Selected from authorized warehouse/loading points. |
| Destination | System-provided from booked transaction. |
| LR Number | Stored against transaction. |
| E-way Bill Number | Stored where required. |
| Invoice Number / Amount | Validated positive amount and transaction linkage. |
| Dispatch Documents | Invoice, LR, e-way bill, weighment slip, loading photos. |
| Remarks | Short operational note. |

## 14.3 Partial Fulfilment

Where partial fulfilment is enabled, the Seller may dispatch a valid subset of booked quantity. The platform calculates remaining quantity transactionally and prevents double allocation. Each partial dispatch retains its own timestamp, quantity, and documents.

# 15. Documents

| **Document Group** | **Examples** | **Seller Behavior** |
| --- | --- | --- |
| KYC | GST certificate, PAN, bank proof | Upload/update per approval workflow. |
| Quality | COA, lab report, quality certificate, batch report, specification sheet | Attach to specific lot/batch; track verification and expiry. |
| Fulfilment | Invoice, LR, e-way bill, weighment slip, loading photos | Attach to booked transaction/dispatch. |
| Other support | Configured supporting documents | Transaction-scoped and role-scoped. |

*📌  Secure file access is mandatory: guessing a URL must not grant access. Seller APIs must return only documents authorized for the Seller organization and specific transaction.*

# 16. Payments & Settlement View

The Seller workspace is not a full accounting ERP. It provides a trustworthy settlement view scoped to the Seller's own transactions.

| **Field** | **Requirement** |
| --- | --- |
| Gross Sale Value | Confirmed Seller-side transaction value. |
| Broker Commission | Commission captured per booked rule. |
| Other Charges | Explicit configured applicable charges. |
| Net Receivable | Expected Seller settlement. |
| Paid Amount | Recorded received amount. |
| Outstanding | Remaining amount. |
| Due Date | Configured payment due date. |
| Status | Pending / Part Paid / Paid / Overdue / Disputed. |

# 17. Notifications & Action Center

Notifications are operational events, not generic alerts. Every notification must explain: what happened, why it matters, and what the next action is. WhatsApp is a notification delivery channel only — no transactional state depends on a WhatsApp action.

## 17.1 Notification Event Catalog

| **Event** | **Seller Notification** | **Primary Action** |
| --- | --- | --- |
| KYC change | KYC status changed / correction needed. | Open KYC |
| Availability approved | Lot approved / active. | View lot |
| Availability rejected/correction | Correction required on lot. | Edit lot |
| Availability expiring | Lot expiring soon. | Quick Renew ⭐ |
| Availability expired | Lot expired. | Quick Renew ⭐ |
| Quality review | Quality verified / corrected / rejected. | Open quality |
| Lab update | Test/report requested, uploaded, reviewed, verified, or expired. | Open lab |
| New Broker request | New commercial request received. | Review request |
| Broker counter-proposal | Broker returned a counter. | Review negotiation |
| Deal version update | New version awaiting response. | Review version |
| Final confirmation required | Deal awaiting your final confirmation. | Confirm now |
| Confirmation outcome | Final terms confirmed / rejected. | View deal |
| Broker finalization / Booking | Booking created; ID issued. | View booking |
| Loading reminder | Loading update needed. | Update loading state |
| Dispatch reminder | Dispatch action due. | Open dispatch |
| Document issue | Document missing or verification issue. | Upload / replace |
| Delivery update | Delivery or dispute status update. | View order |
| Payment update | Payment recorded / overdue / disputed. | View settlement |

## 17.2 Notification Reliability Rules

- Create notifications transactionally with the business event where possible.
- Use queue/outbox-style dispatcher so transient channel failures do not lose events.
- Retry with backoff; mark permanent failures for operational visibility.
- Do not duplicate notifications when an action is retried.
- Deep-link every actionable notification to the Seller screen that resolves it.
- Respect channel configuration and Seller permissions. Never leak Buyer information in notification payloads.

# 18. Security, Roles & Access Control

## 18.1 Seller Roles

| **Role** | **Access** |
| --- | --- |
| SELLER_ADMIN | Manage own organization profile, permitted users, KYC, availability, quality, deals, documents, and payments. |
| SELLER_USER | Manage permitted availability, respond to Broker workflows, confirm final terms, dispatch, and upload documents. |
| SELLER_VIEWER | Read-only access to authorized availability, deals, orders, documents, and reports. |

## 18.2 Security Rules

- Enforce organization-level isolation at database/RLS and API layers, not UI only.
- Every protected resource must authorize the current organization and role.
- Seller APIs must never return Buyer private contact information.
- Seller must never receive another organization's inventory or transaction data.
- Confidential Seller minimum price must never be returned to Buyer-facing APIs.
- Confirmed commercial terms and historical Deal Versions are immutable from Seller UI and API.
- File downloads require authorization at request time — no URL guessing.
- Sensitive actions must produce audit events.

## 18.3 Audit Log Fields

Actor, organization, action, entity, entity ID, timestamp, old/new values, deal/booking reference, IP/device where appropriate.

# 19. Production-Grade UX Requirements

| **Principle** | **Seller Implementation Requirement** |
| --- | --- |
| Mobile first | Design for 360px first; desktop is an enhancement. One-hand use in thumb-friendly zones. |
| User-facing language | Use business terminology, not database terminology. Clear status and next action always visible. |
| Minimal typing | Searchable dropdowns / controlled values for all master data. |
| Fast workflows | Reach primary Seller actions within a few taps. 1-Click Renewal ≤ 60s. ⭐ |
| Low bandwidth | Compress files, lazy-load non-critical content, support retry/offline queue for safe form submissions. |
| Clear state | Never hide whether data is Draft / Pending / Verified / Active / Delayed / Blocked / Expired / Completed. |
| Error recovery | Errors must explain what failed and how to retry. Never silently discard input. |
| Data freshness | Show timestamps/stale indicators when a screen uses cached data. |
| Explicit confirmation | Destructive actions and final deal confirmation need explicit user action and audit. |
| Visual diff | Final Deal Confirmation screen shows green/red diff from previous version. ⭐ |
| Stale-version protection | When another actor changes a deal, Seller sees a stale-version warning. |
| No false success | Do not show success when uploads or state transitions fail. |
| Accessibility | Readable type, large touch targets, clear status labels, sufficient contrast, keyboard support on desktop. |
| Idempotent booking | Repeated finalization requests cannot create duplicate bookings. |

# 20. Seller-Side Logical Data Model

| **Entity** | **Purpose & Seller Relevance** |
| --- | --- |
| Seller Organization / User | Identity, organization, and role scope. Tenant boundary. |
| KYC Profile / KYC Document | Seller verification. Activation and compliance. |
| Commodity / CommodityGrade | Master data. Structured supply selection. |
| InventoryLot / Availability | Core Seller supply record. Lot-level truth. |
| Quality Template / Parameter | Dynamic commodity-specific quality definition. |
| InventoryLotQuality | Actual lot quality values. Commodity-specific. |
| QualityDocument | COA / lab / specification files attached to lot. |
| LabTest | Structured laboratory event — metadata and structured results. |
| LabTestResult | Machine-readable lab evidence per parameter. |
| PriceOffer | Asking price and confidential minimum. Commercial truth. |
| LoadingReadiness | Loading state, duration, and readiness facts. Pre-deal attribute. |
| Negotiation / NegotiationEvent | Broker-mediated negotiation history. Immutable events. |
| Deal | Commercial workflow record. |
| DealVersion | Immutable commercial snapshot per revision. |
| Booking | Operational transaction created after Broker Finalization. Has unique Booking ID. |
| Dispatch | Shipment data. Available only for booked transactions. |
| TransactionDocument | Booking / dispatch / payment documents. |
| Payment / CommissionLedger | Settlement state and commission tracking. |
| Notification | Seller system notifications with deep-links. |
| AuditLog | Immutable security/business action history. |

# 21. Critical Seller Workflows

## 21.1 Create & Publish Availability

- Seller opens Add Availability.
- Selects commodity and grade.
- Enters quantity, unit, and lot/batch number.
- Selects State → District → City → warehouse/loading point.
- Sets asking price, confidential minimum, and price validity.
- Sets Availability From and Valid Until (Expiry) dates.
- Sets Loading Status and Loading Duration.
- Completes dynamic quality parameters as required by commodity template.
- Adds lab testing record/report when applicable.
- Uploads COA and quality documents.
- Reviews summary.
- Submits for configured approval/activation.

## 21.2  ⭐  Quick Renew (1-Click Availability Renewal)

- Seller sees Expired record on dashboard or availability list.
- Taps "Quick Renew" / "Duplicate" button.
- System opens pre-filled form cloned from expired record.
- Seller updates only changed fields (typically: dates, price, quantity).
- Price field surfaced prominently for mandatory review.
- Seller submits → new record created in Draft status.
- Original expired record preserved in history.
- New record enters Draft → Pending Approval → Active workflow.

## 21.3 Update Loading Readiness

- Open active lot or loading card.
- Select new Loading Status.
- If needed, set loading start/date and duration.
- Enter short operational remark.
- Submit once.
- System validates transition, updates dashboard, creates Broker notification and audit event.

## 21.4 Respond to Broker Request

- Open Broker Request.
- Review commodity, quantity, commercial terms, delivery requirement, and Broker message.
- Choose Accept / Reject / Counter.
- If Counter: edit only allowed fields.
- Review response.
- Submit → System creates immutable negotiation event. Seller sees updated status.

## 21.5 Final Deal Confirmation

- Open Final Deal Confirmation from dashboard action item.
- Review full commercial snapshot.
- Review Visual Diff — note what changed from previous version. ⭐
- Confirm Final Terms (explicit action) — or Request Broker Correction.
- System records actor, timestamp, version. Broker can now finalize.

## 21.6 Lab Test Submission

- Open lot Quality & Lab.
- Create or open Lab Test.
- Enter lab metadata and test dates.
- Enter structured test results.
- Upload report file.
- Submit → System validates file type and required data.
- Status moves to Broker Review.
- Seller receives verification outcome later.

# 22. Error, Edge-Case & Recovery Rules

A production Seller product must define failure behavior before implementation. All cases below are mandatory.

| **Case** | **Required Behavior** |
| --- | --- |
| Duplicate form submission | Idempotency key / server guard; create one record only. |
| Network failure during submit | Persist safe local draft/queue where supported; clearly show pending sync. |
| User refreshes during submit | Do not duplicate transaction. |
| Two Seller users edit same lot | Detect stale version; require reconciliation — no silent overwrite. |
| Quantity becomes insufficient | Reject allocation atomically; show remaining server quantity. |
| Price expires during negotiation | Show current price validity before Seller final response. |
| Lab report expires | Mark evidence Expired; prevent display as current verified evidence. |
| Loading date becomes impossible | Allow Delayed/Blocked transition with reason and Broker notification. |
| Notification channel fails | Keep in-app event; retry configured external channels with backoff. |
| File upload interrupted | Allow retry without corrupting or duplicating the document record. |
| Unauthorized resource URL | Return authorization failure; never expose file. |
| Deal already finalized | Reject Seller edits to immutable commercial fields. |
| Partial dispatch exceeds remaining quantity | Reject transactionally. |
| Seller account suspended | Prevent new live availability and restricted commercial actions; preserve read/audit access. |
| Repeated finalization request | Idempotent; do not create duplicate Bookings. |
| Quick Renew on Active record | Block action; show user message: "Quick Renew is only available on expired records." |

# 23. Reports & Seller Visibility

All reports are Seller-scoped. They must never become a hidden channel for accessing Buyer-private data.

- Sales by date and commodity.
- Quantity available / reserved / sold.
- Average selling rate.
- Broker commission and net receivables.
- Outstanding payments and overdue tracking.
- Inventory by state.
- Quality verification status.
- Lab test status and expiry.
- Loading readiness and delays.
- Dispatch status and completed transactions.
- Deal version history and negotiation timeline (read-only).

# 24. Implementation Status & Remaining Work

| **Area** | **Status** | **Remaining Production Work** |
| --- | --- | --- |
| Onboarding / KYC | Established | Harden validation, approval, and recovery. |
| Lot inventory | Established | Enforce complete availability contract and expiry. |
| Commodity / Grade | Established | Use master selectors and request-new-item path. |
| Availability | Foundation exists | Make Grade, Lot/Batch, From/Expiry, COA, and confidential minimum explicit. Add Quick Renew ⭐. |
| Pricing | Established | Enforce confidentiality, validity, and audit on price change. |
| Quality templates | Established | Complete dynamic validation end-to-end. |
| Lab testing | Foundation | Implement structured lab record, results, source, freshness, and expiry. |
| Loading readiness | Expansion needed | Implement status, duration, readiness, and Broker notification events as pre-deal attributes. |
| AI Match | Foundation | Hard-enforce recommendation-only; implement Broker decision gate. |
| Negotiation | Foundation | Version every material commercial revision; immutable events. |
| Seller Final Confirmation | Required | Mandatory state + confirmation screen with Visual Diff ⭐. |
| Deal Versioning | Required | Immutable versions, supersession, audit history, snapshot completeness. |
| Broker Finalization → Booking | Required | Separate states; idempotent Booking creation. |
| WhatsApp in deal flow | Remove | Remove from quotation / negotiation / confirmation / Booking transitions. |
| Dispatch | Established | Allow only after Booking; harden quantity validation and partial fulfilment. |
| Payments | Foundation | Verify permissions, accuracy, and overdue handling. |
| Notifications | Foundation | System event is source of truth; add Quick Renew and Final Confirmation triggers ⭐; deep-link consistency. |
| Security / Audit | Foundation | Test new version / finalization / Booking controls; audit immutability enforcement. |
| Operational resilience | Foundation | Apply retry, stale-data, idempotency consistently to all Seller forms and uploads. |

# 25. Seller MVP & Production Acceptance Criteria

*📌  A feature is not complete because the UI renders. It is complete only when the business rule, persistence, authorization, audit, retry behavior, and user feedback work together.*

## Core Access & Isolation

- Verified Seller can access only its organization's data (UI, API, database).
- Seller cannot retrieve Buyer contact details through any path.
- Confidential minimum price is Broker/Admin-only at all layers.

## Availability

- Seller can create availability with commodity, grade, lot/batch, quantity, location, price, validity, loading, quality, and COA/lab data.
- Availability expiry is automatically enforced server-side.
- Quick Renew pre-fills all fields from expired record; new record enters standard workflow. ⭐
- Quick Renew is unavailable on Active or Reserved records.
- Concurrent quantity edits are transactional; stale version detected.

## Quality & Lab

- Quality fields are dynamically generated from selected commodity template.
- Mandatory quality parameters enforced per commodity configuration.
- Lab testing data and documents tied to exact lot.
- Loading status and duration are structured and actionable.
- Expired lab evidence excluded from verified evidence display.

## Negotiation & Deal Flow

- AI cannot independently select, negotiate, finalize, or book.
- Seller receives commercial requests only through Broker-controlled workflows.
- Seller can Accept, Reject, or Counter (permitted fields only).
- Every material commercial revision creates an immutable Deal Version.
- Seller must explicitly confirm the exact final version before Broker can finalize.
- Final Confirmation screen shows Visual Diff from previous version (green/red). ⭐
- Broker cannot finalize without required Seller confirmation.

## Booking & Finalization

- Broker Finalization is distinct from Booking creation.
- Booking is created only after successful Broker Finalization; unique Booking ID issued.
- Historical Deal Versions cannot be edited.
- No WhatsApp action required for any state progression in deal flow.
- Repeated finalization requests cannot create duplicate Bookings.

## Dispatch, Payments & Documents

- Dispatch is possible only for a booked transaction.
- Partial dispatch quantity validated transactionally.
- Seller can upload transaction documents with secure access control.
- Seller can view settlement, outstanding, and payment status.

## Operational & UX

- Every sensitive Seller action creates an audit event.
- Duplicate submissions do not create duplicate business records or notifications.
- Failure and retry states are visible and recoverable.
- Dashboard deep-links resolve directly to the action that needs attention.
- Seller UI remains usable on 360px mobile layouts and low-bandwidth conditions.

# 26. Out of Scope

- Buyer directory or Buyer search.
- Direct Buyer–Seller chat, calling, email, or contact exchange.
- Seller-side public marketplace discovery.
- AI price negotiation controlled by Seller UI.
- AI autonomous Seller selection or Booking creation.
- Full Seller accounting/ERP replacement.
- Seller-controlled logistics marketplace.
- Cryptocurrency/wallet functionality.
- Uncontrolled public listings.

# 27. Canonical End-to-End Seller Workflow

| **Step** | **Action** |
| --- | --- |
| 1 | Seller Onboarding & KYC Verification |
| 2 | Create Availability: Commodity + Grade + Lot/Batch |
| 3 | → Quantity + Location (State → District → City → Warehouse) |
| 4 | → Price + Confidential Minimum + Price Validity |
| 5 | → Availability From + Valid Until (Expiry) |
| 6 | → Loading Readiness (Status + Duration + Remarks) |
| 7 | → Dynamic Quality Parameters (Commodity Template) |
| 8 | → COA / Lab Report Upload |
| 9 | Activate Availability (Draft → Pending → Active) |
| 10 | AI Recommendation (Broker reviews ranked matches) |
| 11 | Broker Decision: selects Seller/availability to approach |
| 12 | Broker-Originated Deal Request → Seller receives notification |
| 13 | Seller Negotiation: Accept / Reject / Counter |
| 14 | Deal Versioning: each revision creates immutable snapshot |
| 15 | Final Deal Version prepared by Broker |
| 16 | ⭐ Seller Final Deal Confirmation (with Visual Diff screen) |
| 17 | Required Buyer-side confirmation (Broker-controlled workflow) |
| 18 | Broker Finalization |
| 19 | System creates unique Booking ID → Booking Locked |
| 20 | Dispatch preparation → documents uploaded |
| 21 | Dispatched → In Transit → Delivered |
| 22 | Payment / Settlement → Completed (or Dispute resolution) |
| 23 ⭐ | (On expiry of any availability) → Quick Renew → restart from Step 2 in < 60s |

# 28. Final Product Rule

**AI recommends. Broker decides. Seller confirms. Broker finalizes. The system books. Final terms are versioned and immutable. The application is the source of truth.**

**BrokerBridge Seller is not a form for posting stock.**

*It is a live operational supply workspace: the Seller keeps its inventory truthful, priceable, locatable, quality-backed and load-ready; responds to Broker-mediated opportunities; fulfils confirmed orders; renews expired supply in one click; and confirms final commercial terms with complete clarity on what changed — maintaining a reliable digital record of its commercial and operational commitments.*

*BrokerBridge Seller Dashboard PRD — Version 3.0 · August 2026*

*Merged from v1.1 + v2.0 · Incorporating 1-Click Availability Renewal & Visual Diff on Deal Confirmation*
