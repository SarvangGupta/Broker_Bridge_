**BROKERBRIDGE ENTERPRISE**

**BUYER PRODUCT REQUIREMENTS DOCUMENT**

**Version 1.2 — FINAL**

Buyer Admin • Mobile-First • Broker-Mediated Procurement

| **Attribute** | **Final Definition** |
| --- | --- |
| Buyer role | BUYER_ADMIN only |
| Primary device | Android/mobile phone |
| Secondary device | Laptop/desktop |
| Core relationship | Buyer ↔ Broker |
| Seller relationship | Broker ↔ Seller; no direct Buyer-Seller communication |
| Navigation | Dashboard → Requirements → Proposals → Negotiations → Orders → Quality & Documents → Payments → Disputes → Notifications → Profile |
| Reports | Removed from Buyer product |

# 1. Purpose

This is the final Buyer PRD for BrokerBridge. It consolidates the existing Buyer PRD, the current Broker PRD, the shared foundation/sprints and the mobile-first UX rules. It defines what the Buyer sees, what the Buyer can do, how the Buyer works with the Broker, and how the same product adapts from phone to laptop.

Core UX principle: simple outside, complex inside. Backend complexity such as matching, versioning, authorization, audit, calculations and state machines must not become Buyer mental workload.

# 2. Product Definition & Broker Relationship

BrokerBridge Buyer is a secure procurement workspace for a verified Buyer Admin. The Buyer creates a commodity requirement, sends it into the Broker workflow, receives Broker proposals, negotiates with the Broker, confirms the final Deal, tracks Booking/dispatch/delivery, reviews quality/documents, monitors Buyer-side payments and raises disputes.

| **Relationship** | **Allowed** | **Not Allowed** |
| --- | --- | --- |
| Buyer ↔ Broker | Requirements, clarification, proposals, counters, Deal confirmation, status and issue handling. | Anything outside authorization/security rules. |
| Broker ↔ Seller | Supply discovery, quality verification, negotiation, Seller confirmation, dispatch and issue handling. | Exposing Seller private information to Buyer. |
| Buyer ↔ Seller | Only Broker-mediated commercial information. | Direct chat, call, email, WhatsApp, contact exchange or private document exchange. |

The Broker is the controlled intermediary. Seller identity, if operationally required, must never become a direct-contact route.

# 3. Final Role Model

There is exactly one Buyer role: BUYER_ADMIN. BUYER_USER and BUYER_VIEWER are removed.

| **Role** | **Scope** | **Permissions** |
| --- | --- | --- |
| BUYER_ADMIN | Entire Buyer organization | Full Buyer access: company profile, KYC, delivery locations, requirements, proposals, negotiations, Deals, orders, quality/documents, payments, disputes, notifications and security/session controls. |

Do not build Buyer user management, assigned-requirement permissions or Buyer RBAC screens in this version.

# 4. Non-Negotiable Business Rules

- Buyer never communicates directly with Seller.
- Buyer cannot browse/search a Seller directory.
- Buyer cannot retrieve Seller phone, email, WhatsApp, address or direct-contact information.
- Buyer receives Seller-side commercial supply only through Broker Proposals.
- Buyer negotiates only with Broker.
- Seller confidential minimum price and private Seller negotiation notes never reach Buyer.
- Buyer private target price and notes remain protected from Seller.
- Final commercial terms lock after required confirmation.
- Post-confirmation changes use Broker-controlled, versioned amendment flow.
- Quality is structured through the shared commodity-specific Quality Parameter Master.
- Financial calculations and state transitions are server-side validated.
- Buyer can access only its own organization data and authorized transaction documents.
- Material commercial/security actions are audited.

# 5. Buyer Navigation — Final

| **#** | **Item** | **Purpose** |
| --- | --- | --- |
| 1 | Dashboard | See what needs action now. |
| 2 | My Requirements | Create and track procurement requirements. |
| 3 | Broker Proposals | Review Broker commercial proposals. |
| 4 | Negotiations | Continue Buyer ↔ Broker negotiation. |
| 5 | Orders | Track confirmed transactions and delivery. |
| 6 | Quality & Documents | Review quality and transaction documents. |
| 7 | Payments | See payable, paid, outstanding and overdue amounts. |
| 8 | Disputes | Raise and track transaction issues. |
| 9 | Notifications | See workflow alerts and open exact actions. |
| 10 | Profile | Company profile, KYC, delivery locations and security/session settings. |

Reports are intentionally removed. Buyer history remains available contextually inside Requirements, Orders, Payments and Profile where needed. There is no separate Reports module.

# 6. Dashboard — Action-First Buyer Home

The dashboard is a control center, not a data wall. The first screen must answer: What needs action? What is happening with my procurement? What changed?

1. Header: company name, KYC state, lightweight connectivity state, notifications, profile and Trader Workspace Toggle (switches to the Seller Workspace at /seller).
1. Primary action: + Create Requirement.
1. Action Required: only items requiring Buyer action.
1. Compact KPIs: Active Requirements, Pending Quotations, Active Orders, In Transit, Payment Pending, Deals Closed.
1. New Broker Proposals.
1. Open Negotiations.
1. Awaiting Confirmation.
1. Active Orders.
1. Quality/Documents requiring attention.
1. Payments due/overdue.
1. Disputes only when active.
1. Recent Activity.

| **KPI** | **Meaning** | **Tap Action** |
| --- | --- | --- |
| Active Requirements | Requirements still being sourced, negotiated or fulfilled. | Open Requirements |
| Pending Quotations | Broker proposals awaiting Buyer response. | Open Proposals |
| Active Orders | Confirmed transactions still operationally active. | Open Orders |
| In Transit | Shipments currently moving. | Track Dispatch |
| Payment Pending | Buyer-side amounts due/outstanding. | Open Payments |
| Deals Closed | Completed transaction count. | Open relevant history |

| **Action Required** | **What Buyer Sees** | **CTA** |
| --- | --- | --- |
| Proposal waiting | Commodity, quantity, offered rate, validity | Review Proposal |
| Negotiation waiting | Last Broker position and next action | Continue |
| Deal confirmation | Final price, quantity, quality, delivery and payment | Review & Confirm |
| Payment due | Amount and due date | View Payment |
| Dispatch/delivery action | Order, ETA and required confirmation | Track Order |
| Quality/document action | Document or quality status | Review |
| Dispute update | Issue and latest status | View Dispute |

# 7. Requirement Management

A Requirement is the Buyer demand the Broker processes against Seller supply.

## 7.1 Mobile Create Requirement Flow

1. What do you need? Commodity + Grade.
2. How much? Quantity + Unit + target/indicative price.
3. Where? State → District → City/Delivery Location.
4. When? Target delivery date/window.
5. Quality? Commodity-specific parameters.
6. Commercial terms? Delivery terms + Payment terms + Packaging.
7. Extra information? Special instructions + documents + Priority.
8. Review & Submit.

## 7.2 Requirement Fields

| **Field** | **Required** | **Rule** |
| --- | --- | --- |
| Commodity | Yes | Searchable master dropdown. |
| Quality Grade | Yes | Filtered by commodity. |
| Quantity | Yes | Positive number; policy-controlled maximum. |
| Unit | Yes | Master UOM. |
| Target/Indicative Price | Yes by current specification | Positive numeric. |
| Delivery State | Yes | Cascading master data. |
| Delivery District | Yes | Filtered by State. |
| Delivery City | Optional | Filtered by District. |
| Delivery Location | Yes | Reusable Buyer destination. |
| Target Delivery Date | Yes | Future date. |
| Delivery Terms | Yes | Master data. |
| Packaging | Optional | Master data. |
| Payment Terms | Yes | Master data. |
| Quality Parameters | When applicable | Commodity-specific min/max/range/target. |
| Special Instructions | Optional | Short controlled text. |
| Priority | Yes | Low / Medium / High / Urgent. |
| Documents | When applicable | Specification/supporting files. |

## 7.3 Requirement Lifecycle

Draft → Submitted/Open → Broker Review/Sourcing → Proposal Received → Negotiating → Awaiting Confirmation → Confirmed/Booked → Fulfilled/Closed. Exceptions: Cancelled, Expired, Disputed, Delayed and Partially Fulfilled where applicable.

Backend may use granular states; Buyer UI uses human labels such as “Finding supply”, “New proposal”, “Negotiation in progress” and “Awaiting confirmation”.

Implementation guardrail: the mobile-optimized Requirement form, cascading master data (State → District) and the Service Worker offline queue already exist from the original foundation build. Implementation must upgrade and extend this existing form and offline-queue architecture rather than rebuilding the Requirement engine from scratch.

When a Requirement is partially fulfilled, the Requirement Detail screen must explicitly visualize 'Original Quantity', 'Booked Quantity' and 'Remaining Unfulfilled Quantity', derived from the existing partial-fulfillment calculation engine.

# 8. Broker Proposals

The Buyer never sees the Broker internal matching workspace. The Broker may use AI matching, Seller inventory, quality verification and separate Seller negotiation; the Buyer sees only the resulting authorized Broker Proposal.

| **Buyer Can See** | **Buyer Cannot See** |
| --- | --- |
| Commodity/grade | Seller phone/email/WhatsApp |
| Quantity | Seller confidential minimum price |
| Price/unit | Seller private notes |
| Quality terms | Other Seller lots/private matches |
| Delivery terms/date | Broker internal AI score mathematics |
| Payment terms | Seller internal records |
| Packaging/freight/inspection | Direct Seller contact path |
| Applicable Buyer-side charges | Seller-side confidential charges unless policy requires disclosure |
| Broker message | Private Broker CRM notes |

Proposal actions: Accept, Reject or Counter, subject to workflow state. Reject requires a reason. Counter creates an immutable negotiation event. Expired proposals cannot be accepted. Multiple proposals may exist for one Requirement.

# 9. Negotiation — Buyer ↔ Broker Only

Negotiation must feel like a simple commercial timeline, not a complex CRM/chat system.

| **Event** | **Buyer View** |
| --- | --- |
| Broker Proposal | Terms proposed by Broker. |
| Buyer Counter | Buyer submitted counter terms. |
| Broker Revision | Broker revised commercial position. |
| Buyer Acceptance | Buyer accepted presented terms. |
| Final Deal | Broker-created consolidated Deal. |

Permitted negotiation fields may include price, quantity, delivery date, payment terms, quality/document requirements, packaging, freight and inspection. Seller-side private negotiation is never shown as a shared conversation.

# 10. Final Deal & Booking

The Final Deal is a separate, reviewable object. The Buyer confirms the Deal; the Broker finalizes the Booking after required confirmations.

1. Broker creates final consolidated Deal.
1. Buyer reviews immutable Deal snapshot.
1. System displays Visual Diff engine: changed fields are highlighted (green/red) against the previous proposal version prior to Buyer confirmation.
1. Buyer confirms.
1. Seller confirms separately.
1. Broker validates required confirmations.
1. Broker finalizes Booking.
1. System generates unique Booking ID.

| **Deal Snapshot** | **Buyer Sees** |
| --- | --- |
| Commodity/grade | Final values |
| Quantity/unit | Final values |
| Rate | Final rate |
| Quality | Snapshot of agreed specification |
| Delivery | Location/date/window |
| Payment | Agreed terms |
| Packaging/freight | Agreed terms |
| Taxes/charges | Applicable Buyer-side amounts |
| Seller reference | Only if policy permits |
| Version | Deal version/timestamp |

Buyer cannot finalize Booking. After confirmation, commercial terms are immutable to Buyer. Any amendment creates a new version and reconfirmation flow.

# 11. Orders & Dispatch

| **System State** | **Buyer Label** | **Action** |
| --- | --- | --- |
| Booked | Order confirmed | View order |
| Dispatch Planned | Preparing shipment | Track |
| Dispatched | Shipment dispatched | Track |
| In Transit | On the way | Track ETA |
| Delivered | Delivered | Confirm/review |
| Completed | Completed | View |
| Delayed | Delivery delayed | Review update |
| Disputed | Issue under review | View dispute |
| Cancelled | Cancelled | View reason/history |

Order detail uses a simple progress timeline. Show Booking ID, commodity, booked/dispatched quantity, delivery location, dispatch date, ETA, authorized transport information, LR/e-way bill references, documents, payment state and dispute/quality state.

For orders in a Partially Fulfilled state, Order Detail must explicitly visualize 'Original Quantity', 'Booked Quantity' and 'Remaining Unfulfilled Quantity' based on the partial fulfillment calculation logic.

# 12. Quality & Documents

| **Document/Information** | **Buyer Use** |
| --- | --- |
| COA | Review quality evidence. |
| Laboratory report | Review test results. |
| Product specification | Compare against requested quality. |
| Quality certificate | Review compliance. |
| Weighment document | Review quantity evidence. |
| Invoice | Review payment document. |
| LR | Review shipment documentation. |
| E-way bill | Review logistics documentation. |

Document access is organization- and transaction-authorized. Documents must never become a mechanism for discovering Seller contact details.

# 13. Payments

The Buyer payment screen is operational, not an accounting system. Show what is owed, what is paid and what needs attention.

| **Field** | **Buyer View** |
| --- | --- |
| Total payable | Buyer-side amount due. |
| Paid | Recorded payment. |
| Outstanding | Remaining amount. |
| Due date | Expected payment date. |
| Status | Pending / Part Paid / Paid / Overdue / Disputed. |
| Buyer-side Broker charge | Only applicable Buyer charge. |

Seller settlement and Broker internal commission accounting are not Buyer-facing modules.

# 14. Disputes

| **Category** | **Examples** |
| --- | --- |
| Quality | Quality mismatch, failed test. |
| Quantity | Short/wrong quantity. |
| Delivery | Delay, non-delivery. |
| Document | Missing/incorrect document. |
| Payment | Invoice/payment mismatch. |
| Commercial | Authorized commercial issue. |
| Other | Other transaction issue. |

Flow: Buyer opens dispute → selects category → describes issue → uploads evidence → Broker receives → Broker coordinates resolution → resolution recorded → authorized workflow closes dispute. Disputes never create direct Buyer-Seller communication.

# 15. Notifications

| **Event** | **Buyer Message** | **CTA** |
| --- | --- | --- |
| New proposal | New proposal received | Review |
| Counter | Broker responded to your counter | Continue |
| Deal confirmation | Deal is ready for confirmation | Review & Confirm |
| Booking | Booking is confirmed | View Order |
| Dispatch | Order dispatched | Track |
| Delay | Delivery delayed; new ETA available | View Update |
| Document | COA/document uploaded | Review |
| Payment | Payment is due | View Payment |
| Dispute | Dispute updated | View Dispute |

Every actionable notification deep-links to the exact object/action. The Buyer should never need to return to Dashboard and search again.

# 16. Profile, KYC & Delivery Locations

| **Area** | **Functions** |
| --- | --- |
| Company Profile | Company/firm, authorized person, address, GST/PAN and business information. |
| KYC & Verification | Status and required documents. |
| Delivery Locations | Reusable plants/warehouses/destinations. |
| Payment Information | Buyer-side payment information where required. |
| Security & Sessions | Authentication/session controls. |

There is no Buyer user-management screen because the product has one Buyer role only: BUYER_ADMIN.

# 17. Mobile-First UX — Mandatory

- Design first at 360px; support 360–414px+ Android devices.
- Minimum touch target 48×48px; primary actions about 56px high.
- Primary action stays near thumb zone.
- No horizontal scrolling on operational screens.
- No giant mobile tables; use cards, timelines and compact rows.
- One logical section per mobile form screen with progress indicator.
- Maximum two scrolls to reach the primary action where practical.
- Search is visible on list screens without excessive navigation.
- Human-readable labels; never expose technical state codes.
- Skeleton loaders for lists/cards; never unexplained blank screens.
- Every empty state explains what is missing and gives one next action.
- Inline field validation; retryable network errors.
- Lazy-load documents/images and minimize payloads for slow networks.
- Safe offline form work queues and syncs on reconnect.
- Commitment actions require live server validation.
- UI strings are i18n-ready from day one.
- Hindi can be added without component rewrites.

# 18. Laptop/Desktop — Same Product, Expanded

Desktop is not a second application. It is the same Buyer product with more space.

| **Mobile** | **Laptop/Desktop** |
| --- | --- |
| Compact navigation | Sidebar navigation |
| Card lists | Cards or wider tables for history |
| Single-column forms | Wider/two-column forms where useful |
| Thumb-zone CTA | Prominent header/top CTA |
| Compact timeline | Wider timeline/context panel |

- Same routes, data, permissions and business rules.
- Same state when switching devices.
- No separate mobile/desktop business logic.
- Desktop-only features cannot expose prohibited data.
- Keyboard/mouse must work.
- Responsive CSS/layout performs the adaptation.

# 19. Simple Outside, Complex Inside

| **Backend Complexity** | **Buyer Experience** |
| --- | --- |
| AI matching | A clean Broker Proposal. |
| Immutable versions | Simple “Updated terms / Version 2”. |
| RLS/security | Nothing technical. |
| Commission calculation | Only applicable Buyer charge. |
| Audit logging | Simple relevant activity history. |
| State machine | Human labels: “Awaiting confirmation”. |
| Realtime | Cards/timelines update automatically. |
| Offline sync | “Saved — syncing when online.” |

# 20. Exceptions & Edge Cases

| **Scenario** | **Buyer Experience** |
| --- | --- |
| Seller supply unavailable | Broker sends revised/alternate proposal. |
| Proposal expired | Show Expired; block acceptance; await new proposal. |
| Buyer rejects | Capture reason; return to Broker workflow according to state. |
| Duplicate requirement | Show warning with similar existing requirement. |
| Dispatch delayed | Show Delayed prominently and new ETA. |
| Wrong quantity | Flag discrepancy and offer Dispute. |
| Invoice mismatch | Show issue and controlled payment state. |
| Payment overdue | Prominent alert and Payment CTA. |
| Quality rejected | Route to dispute. |
| Master-data gap | Request New Item; do not create free-text commodity. |
| Offline submission | Show saved/syncing state; never falsely claim server submission. |

# 21. Security, Data & Audit

- Organization-level RLS isolates Buyer data.
- Server-side authorization is mandatory for protected resources.
- Buyer APIs must not return Seller private contact data or confidential minimum price.
- File downloads require organization + transaction authorization.
- Commercial mutations use server-side validation.
- Price, quantity, commission and payable calculations are server-side.
- State transitions are server-side validated.
- Sensitive actions create immutable audit events.
- Cancelled/deleted records remain auditable where required.
- Notification deep links re-check authorization.

# 22. Realtime, Offline & Low-Bandwidth

| **Area** | **Requirement** |
| --- | --- |
| Realtime | Proposal, negotiation, confirmation, dispatch, payment and dispute changes can update relevant Buyer UI. |
| Caching | Cache master data and stable references aggressively. |
| Pagination | Server-side pagination; never load entire histories. |
| Offline | Safe drafts/non-critical form work may queue. |
| Live-only | Deal confirmation, Booking, payment confirmation and other commitments require live validation. |
| Sync | Idempotency prevents duplicate submissions. |
| Slow network | Lazy-load files/images and minimize API payloads. |

# 23. Final Buyer Screens

- Login / Authentication
- Buyer Onboarding
- Buyer Dashboard
- My Requirements
- Create Requirement
- Edit Requirement
- Requirement Detail
- Quality Requirement
- Requirement Documents
- Broker Proposals
- Proposal Detail
- Proposal Comparison
- Broker Negotiation
- Counter Offer
- Final Deal Review
- Deal Confirmation
- My Orders
- Order Detail
- Quality & Documents
- Dispatch Tracking
- Payments
- Disputes
- Notifications
- Profile
- KYC & Verification
- Delivery Locations
- Security / Sessions

Removed: Reports, Buyer User Management, Buyer Viewer/User roles, Seller directory, direct Seller communication and Seller contact discovery.

# 24. Logical Buyer Data Scope

| **Entity** | **Purpose** |
| --- | --- |
| BuyerOrganization | Buyer company/firm. |
| BuyerAdmin | Single Buyer role/login identity. |
| KYCProfile/KYCDocument | Verification. |
| DeliveryLocation | Reusable destination. |
| Requirement/RequirementQuality/RequirementDocument | Buyer demand and specification. |
| BrokerProposal/ProposalVersion | Broker proposal and immutable revisions. |
| Negotiation/NegotiationEvent | Broker-mediated negotiation and immutable history. |
| Deal/DealVersion | Final commercial agreement and versions. |
| Booking | Operational transaction. |
| CommissionRule/CommissionLedger | Applied commission record; Buyer sees only applicable charge. |
| Payment | Buyer-side payment. |
| TransactionDocument | Invoice, LR, COA, e-way bill, etc. |
| Delivery/Dispatch | Shipment tracking. |
| Dispute | Buyer transaction issue. |
| Notification | Buyer workflow alert. |
| AuditLog | Business/security history. |

# 25. Buyer Development Sequence

| **Phase** | **Deliverable** |
| --- | --- |
| B0 | Verify shared architecture, Buyer route, RLS, master data and Broker integration points. |
| B1 | BUYER_ADMIN authentication, organization isolation, Profile/KYC. |
| B2 | Mobile-first Buyer shell + final navigation. |
| B3 | Action-first Dashboard + KPI data. |
| B4 | Requirement create/edit/status workflow. |
| B5 | Quality Parameter Master + quality UI + documents. |
| B6 | Broker Proposal inbox/detail/comparison. |
| B7 | Broker-only negotiation + immutable events. |
| B8 | Final Deal snapshot + Buyer confirmation. |
| B9 | Booking/Orders + dispatch/delivery tracking. |
| B10 | Quality/Documents + delivery/quality acceptance. |
| B11 | Payments + Buyer financial view. |
| B12 | Disputes + evidence workflow. |
| B13 | Notifications + deep links + realtime. |
| B14 | Mobile/desktop polish + offline + low-bandwidth optimization. |
| B15 | Security, authorization, audit and end-to-end UAT. |

Reports are intentionally excluded.

# 26. Acceptance Criteria

- Only BUYER_ADMIN exists.
- Dashboard is understandable within seconds.
- Create Requirement is always easy to find.
- Buyer can create a structured requirement from a phone.
- Master data and cascading locations work correctly.
- Buyer can define commodity-specific quality.
- Buyer receives proposals only through Broker.
- Buyer cannot discover or directly contact Seller.
- Buyer can Accept, Reject or Counter a Broker Proposal.
- Negotiation is Buyer ↔ Broker only and history is immutable.
- Buyer can review the Final Deal snapshot and confirm it.
- Buyer cannot finalize Booking.
- Booking occurs only after required confirmations and Broker finalization.
- Buyer can track order, dispatch, ETA and delivery.
- Buyer can access authorized quality/documents.
- Buyer can see Buyer-side payment status and due amounts.
- Buyer can raise and track disputes.
- Notifications deep-link to exact actions.
- Profile contains company, KYC, delivery locations and security/session controls.
- No Reports module exists.
- No Buyer User/Viewer management exists.
- Phone and laptop use the same product and workflow.
- Mobile works at 360px without horizontal scrolling.
- Loading, empty, error and retry states exist.
- Offline actions never falsely claim server completion.
- RLS/API authorization blocks unauthorized Buyer/Seller data access.
- Material actions are audit logged.

# 27. Explicit Buyer Out of Scope

- Buyer User / Buyer Viewer roles.
- Buyer user-management module.
- Separate Buyer Reports module.
- Seller directory/search.
- Direct Buyer-Seller chat/call/email/WhatsApp.
- Direct Seller document exchange.
- Seller confidential minimum price.
- Broker internal CRM.
- Broker AI Match Center.
- Autonomous AI negotiation.
- Public marketplace browsing.
- Full procurement ERP replacement.
- Advanced laboratory management.
- Automated logistics marketplace.
- Cryptocurrency/wallet.

# 28. Final Product Design Rules

1. If the Buyer does not need to act on it, do not put it on the dashboard.
1. If the system knows the next action, show the next action.
1. If one button can complete the task, do not create five buttons.
1. Use structured master data instead of unnecessary typing.
1. Hide technical concepts that do not help the Buyer.
1. Use human-readable statuses.
1. Keep navigation short.
1. Every important notification opens the exact object requiring attention.
1. Mobile is the primary experience; desktop is the same product expanded.
1. Complexity belongs in the backend, not in the Buyer mental workload.

# 29. Final Buyer Journey

Buyer opens BrokerBridge → sees Action Required → creates Requirement → Broker receives it → Broker finds and verifies Seller supply → Broker negotiates with Seller separately → Broker sends Proposal → Buyer reviews → Buyer accepts/rejects/counters → Broker creates Final Deal → Buyer confirms → Seller confirms separately → Broker finalizes Booking → Buyer tracks dispatch → Buyer receives delivery → Buyer reviews quality/documents → Buyer pays according to terms → Buyer raises dispute if required → transaction completes.

The Buyer should experience this as a small number of obvious actions. Matching, versioning, security, authorization, audit, calculations, notifications and state transitions remain system complexity.

# 30. Source Alignment & Precedence

| **Source** | **Applied Here** |
| --- | --- |
| Current Buyer PRD v1.1 | Buyer requirements, proposals, Broker-only negotiation, Deal, Booking, documents, payments, disputes and security. |
| Broker PRD v2.2 / Broker Lite | Broker as intermediary, separate Buyer/Seller channels, action-first UX, mobile-first standards and simple-outside/complex-inside. |
| BrokerBridge PRD v4.0 | Global master data, state machines, notifications, quality, platform security and foundation. |
| Existing Sprints/Foundation | Existing shared architecture is preserved; Buyer work extends it rather than rebuilding it. |

Where documents conflict, this final Buyer PRD applies the current Broker-controlled model and the final Buyer decisions: one role only (BUYER_ADMIN), no Buyer Reports module, short task-first navigation, and direct Buyer-Seller communication prohibited.

# 31. Final Product Definition

BrokerBridge Buyer is a minimal, mobile-first procurement workspace for one role: BUYER_ADMIN. The Buyer defines what is needed, receives Broker-mediated options, negotiates only with Broker, confirms final terms, tracks the resulting order, reviews quality/documents, monitors Buyer-side payments and handles disputes. The same product automatically expands to laptop/desktop without changing workflow, permissions or business rules.
