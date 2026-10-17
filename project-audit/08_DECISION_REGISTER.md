# PROJECT DECISION REGISTER (ARCHITECTURAL DECISION RECORDS)

**Document Reference:** `project-audit/08_DECISION_REGISTER.md`  
**Date of Audit:** October 17, 2026  
**Auditor:** Senior Software Architect & Technical Historian  
**Project:** BrokerBridge Enterprise & VetKind Animal Health India  

---

## 1. Architectural Decision Records (ADRs)

This register preserves the formal architectural, business, and security decisions that govern the codebase. Every incoming developer or AI assistant must adhere strictly to these decisions to avoid breaking established system invariants.

---

### ADR 01: Flat 4-Role Model vs. Hierarchical Role RBAC
- **Status:** `ACCEPTED & ENFORCED`
- **Context:** Early designs explored sub-roles such as `BROKER_ADMIN`, `BROKER_AGENT`, `BUYER_VIEWER`, and `SELLER_OPERATOR`.
- **Decision:** The platform enforces a **Flat 4-Role Architecture**: `'admin'`, `'broker'`, `'buyer'`, and `'seller'`. Sub-roles and team management interfaces were deliberately omitted from the operational workspace.
- **Rationale:** Agricultural brokerage in Tier-2/Tier-3 Indian mandis operates with lean trading desks. Hierarchical role configuration creates operational friction and confusion on mobile screens.
- **Implications:** Role checks in middleware and server actions evaluate only these 4 canonical strings. No team permission management tables exist.

---

### ADR 02: Immutable Deal Versioning vs. Overwrite Mutations
- **Status:** `ACCEPTED & ENFORCED`
- **Context:** Initial prototypes updated price and quantity columns directly on `quotations` and `deals` tables.
- **Decision:** Overwrite mutations on commercial contracts are strictly prohibited. Every change increments `deal_versions` (`v1` → `v2` → `v3`) with a frozen JSONB snapshot.
- **Rationale:** Agricultural commodity trade disputes frequently hinge on "who changed what and when." An immutable snapshot trail is legally indispensable for arbitration.
- **Implications:** Backed by PostgreSQL trigger `prevent_deal_version_snapshot_tampering()` in migration `0034_enforce_negotiation_immutability.sql`.

---

### ADR 03: The Mediation Firewall (Zero Counterparty Intermediation)
- **Status:** `ACCEPTED & ENFORCED`
- **Context:** Common consumer marketplace architectures feature in-app chat or messaging between buyers and sellers.
- **Decision:** Mathematically and architecturally, **zero direct communication channels exist between Buyer and Seller**. All proposals, counters, quality questions, and disputes route exclusively through the assigned Broker Desk.
- **Rationale:** Preventing platform disintermediation is the core commercial requirement of a B2B brokerage platform. If buyers and sellers obtain each other's phone numbers or chat directly, transactions move off-platform.
- **Implications:** No chat tables, direct message endpoints, or shared contact records exist. Payloads are filtered through `buyer-privacy-scrubber.ts`.

---

### ADR 04: Nodal Escrow Settlement vs. Direct Counterparty Payments
- **Status:** `ACCEPTED & ENFORCED`
- **Context:** Traditional mandi trade often relies on post-delivery direct bank transfers, resulting in high default and payment delay rates.
- **Decision:** Direct counterparty bank transfers are disallowed. The platform operates on a **Regulated Nodal Escrow Model** utilizing virtual account numbers (`BB-NODAL-${bookingReference}`).
- **Rationale:** Fiduciary escrow ensures the Seller that funds are secured before loading trucks, while ensuring the Buyer that funds are not released until delivery receipts and weighbridge slips are verified.
- **Implications:** Seller bank details are completely redacted from Buyer payloads. The Buyer pays into the platform nodal account.

---

### ADR 05: Dynamic EAV Quality Engine vs. Static Quality Grades
- **Status:** `ACCEPTED & ENFORCED`
- **Context:** Early PRDs required users to pick static grades (e.g. "Grade A") from a dropdown.
- **Decision:** Replaced static grade selection with the **Dynamic Commodity-Specific Quality Engine** (`master_quality_parameters` + `availability_quality_values` / `requirement_quality_specs`).
- **Rationale:** Agricultural commodities (e.g. Soybean Meal vs. Yellow Maize) have completely different scientific parameters (Protein %, Moisture %, Sand/Silica %, Aflatoxin ppb) with numerical tolerances that must be validated mathematically.
- **Implications:** When a user selects a commodity, the UI dynamically renders parameter inputs with master min/max boundaries. Legacy grade IDs are resolved automatically on the backend.

---

### ADR 06: Decoupled Confirmation vs. Broker Booking Gate
- **Status:** `ACCEPTED & ENFORCED`
- **Context:** Does mutual acceptance automatically generate a booking?
- **Decision:** **Seller Confirmation + Buyer Confirmation ≠ Booking**. Counterparty confirmations record mutual intent, but the legal generation of the physical Booking ID (`BKG-YYYY-XXXX`) is an exclusive action executed by the human Broker Desk via `finalizeDealAction` and `createIdempotentBookingAction`.
- **Rationale:** Brokers must verify physical logistics feasibility, warehouse loading readiness, and market credit before committing the legal trade contract.
- **Implications:** Dispatch and fulfillment features are strictly locked until a valid `booking_reference` exists.

---

### ADR 07: Tier-2 Mobile-First 360px & 48px Touch Invariant
- **Status:** `ACCEPTED & ENFORCED`
- **Context:** Desktop ERP designs with complex tables and small buttons fail in agricultural mandi environments.
- **Decision:** All screens must render flawlessly on a **360px viewport** with zero horizontal document scroll (`overflow-x-hidden`). All interactive elements must enforce a minimum **48×48px touch target**.
- **Rationale:** Mandi traders and field brokers operate predominantly on mid-tier Android smartphones while standing in warehouses or loading yards.
- **Implications:** HTML `<table>` elements are prohibited on primary mobile screens. Tables on admin/ledger screens must be enclosed in horizontal touch-pan wrappers.

---

### ADR 08: Zero-PII Regex & Privacy Scrubber
- **Status:** `ACCEPTED & ENFORCED`
- **Context:** Free-text remarks fields and counter-offer notes can accidentally leak phone numbers, email addresses, or GSTINs.
- **Decision:** All negotiation events, proposal payloads, and notification dispatches pass through automated regex scrubbers (`sanitizeBuyerNegotiationPayload`, `sanitizePayloadForBuyer`, `sanitizePayloadForSeller`) that redact phone numbers, emails, GST numbers, and confidential floor prices.
- **Rationale:** Protects counterparties from accidental data leakage and intentional attempts to exchange contact info in remarks fields.
- **Implications:** Tested and verified via automated test suite `verify-negotiation-immutability.ts`.

---

### ADR 09: Modular Coexistence Architecture (BrokerBridge + VetKind)
- **Status:** `ACCEPTED & ENFORCED`
- **Context:** Reconciling the user's business brand (VetKind Animal Health India) with the existing 39 sprints of agricultural commodity brokerage code (BrokerBridge Enterprise).
- **Decision:** Implement a **Modular Coexistence Strategy**. The BrokerBridge raw-material trading engine (`/buyer`, `/seller`, `/broker`, `/admin`) is preserved intact as the institutional commodity sourcing desk. VetKind operates as an integrated domain extension (`/vetkind`, `src/server/db/vetkind-schema.ts`) managing veterinary formulations, dealer networks, and dairy herd health.
- **Rationale:** Destructive refactoring would compromise 39 sprints of verified, battle-tested code. Coexistence provides both raw-material procurement and finished-goods distribution in a single unified platform.
- **Implications:** 4 dedicated schema tables (`vetkind_categories`, `vetkind_products`, `vetkind_dealers`, `vetkind_inquiries`) operate with 0 schema drift or conflict with core BrokerBridge tables.

---

### ADR 10: Server-Side Math Enforcement (F12 DOM Defense)
- **Status:** `ACCEPTED & ENFORCED`
- **Context:** Client-side JavaScript calculations (e.g. total contract values, brokerage fees, outstanding balances) can be tampered with via browser developer tools.
- **Decision:** All financial formulas, taxes, mandi cess, and balances are computed exclusively on the server in Server Actions. Pre-calculated read-only values are returned to the client.
- **Rationale:** Financial and legal integrity requires absolute immunity from client-side DOM or script manipulation.
- **Implications:** Client UI components only display formatted numbers; they never compute or submit monetary totals to the backend.
