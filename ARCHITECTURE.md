# BrokerBridge Enterprise - Architecture & Directory Structure

This document outlines the folder structure and architectural design of the BrokerBridge Enterprise application. It serves as a map to quickly locate specific functionality.

## Core Application Structure

```text
brokerbridge-enterprise/
├── .env.local
├── .gitignore
├── AGENTS.md
├── app/
│   ├── (admin)/
│   │   └── admin/
│   │       ├── page.tsx
│   │       └── _components/
│   │           ├── admin-dispute-queue.tsx
│   │           ├── admin-help-desk-queue.tsx
│   │           ├── company-approval-queue.tsx
│   │           ├── deal-desk-queue.tsx
│   │           └── MasterDataTabs.tsx
│   ├── (broker)/
│   │   └── broker/
│   │       ├── layout.tsx
│   │       ├── loading.tsx
│   │       ├── error.tsx
│   │       ├── page.tsx
│   │       ├── work/
│   │       │   ├── page.tsx
│   │       │   ├── loading.tsx
│   │       │   └── supply/
│   │       │       ├── page.tsx
│   │       │       └── loading.tsx
│   │       ├── deals/
│   │       │   └── page.tsx
│   │       ├── orders/
│   │       │   └── page.tsx
│   │       ├── more/
│   │       │   └── page.tsx
│   │       └── quotations/
│   │           └── page.tsx
│   ├── (buyer)/
│   │   └── buyer/
│   │       └── page.tsx
│   ├── (seller)/
│   │   └── seller/
│   │       ├── layout.tsx
│   │       └── page.tsx
│   ├── api/
│   │   ├── cron/
│   │   │   ├── monitor-dispatches/
│   │   │   │   └── route.ts
│   │   │   └── process-notifications/
│   │   │       └── route.ts
│   │   ├── quotations/
│   │   │   └── [id]/
│   │   │       └── pdf/
│   │   │           └── route.ts
│   │   ├── reset/
│   │   │   └── route.ts
│   │   └── webhooks/
│   │       └── whatsapp/
│   │           └── route.ts
│   ├── favicon.ico
│   ├── globals.css
│   ├── layout.tsx
│   ├── login/
│   │   └── page.tsx
│   ├── page.tsx
│   └── register/
│       └── page.tsx
├── ARCHITECTURE.md
├── CLAUDE.md
├── components/
│   ├── providers.tsx
│   └── ui/
│       ├── alert.tsx
│       ├── badge.tsx
│       ├── button.tsx
│       ├── calendar.tsx
│       ├── card.tsx
│       ├── command.tsx
│       ├── dialog.tsx
│       ├── form.tsx
│       ├── input-group.tsx
│       ├── input.tsx
│       ├── label.tsx
│       ├── popover.tsx
│       ├── radio-group.tsx
│       ├── select.tsx
│       ├── sheet.tsx
│       ├── skeleton.tsx
│       ├── sonner.tsx
│       ├── table.tsx
│       ├── tabs.tsx
│       └── textarea.tsx
├── components.json
├── docs/
│   ├── BrokerBridge_PRD_v4.0.md
│   ├── BrokerBridge_Seller_PRD_v3.0.md
│   ├── BrokerBridge_Seller_Sprint_Plan_13-20.md
│   ├── BrokerBridge_TRD.md
│   ├── Sprints.md
│   └── seller-foundation-audit-13.1.md
├── drizzle.config.ts
├── eslint.config.mjs
├── lib/
│   ├── supabase/
│   │   ├── client.ts
│   │   ├── middleware.ts
│   │   └── server.ts
│   └── utils.ts
├── middleware.ts
├── next-env.d.ts
├── next.config.ts
├── package.json
├── postcss.config.mjs
├── PROJECTSTATE.MD
├── public/
├── README.md
├── src/
│   ├── app/
│   │   └── api/
│   ├── components/
│   │   ├── dashboard/
│   │   │   ├── action-required-banner.tsx
│   │   │   ├── ai-match-center.tsx
│   │   │   ├── ai-match-workspace.tsx
│   │   │   ├── broker-assignments.tsx
│   │   │   ├── broker-header-dropdown.tsx
│   │   │   ├── broker-request-inbox.tsx
│   │   │   ├── buyer-deals-table.tsx
│   │   │   ├── buyer-header-dropdown.tsx
│   │   │   ├── buyer-quotation-card.tsx
│   │   │   ├── buyer-quotations-list.tsx
│   │   │   ├── company-profile-card.tsx
│   │   │   ├── crm-task-feed.tsx
│   │   │   ├── kpi-cards.tsx
│   │   │   ├── match-filter-bar.tsx
│   │   │   ├── match-result-card.tsx
│   │   │   ├── my-availabilities-table.tsx
│   │   │   ├── my-requirements-table.tsx
│   │   │   ├── negotiation-timeline.tsx
│   │   │   ├── quotation-table-actions.tsx
│   │   │   ├── quotations-deals-tab.tsx
│   │   │   ├── seller-deals-table.tsx
│   │   │   ├── seller-header.tsx
│   │   │   ├── seller-header-dropdown.tsx
│   │   │   ├── seller-nav.tsx
│   │   │   └── seller-workspace-shell.tsx
│   │   ├── dialogs/
│   │   │   └── post-availability-dialog.tsx
│   │   ├── forms/
│   │   │   ├── availability-form.tsx
│   │   │   ├── company-onboarding-form.tsx
│   │   │   ├── crm-activity-dialog.tsx
│   │   │   ├── dynamic-quality-fields.tsx
│   │   │   ├── file-dispute-dialog.tsx
│   │   │   ├── lab-test-form.tsx
│   │   │   ├── loading-readiness-form.tsx
│   │   │   ├── quotation-form.tsx
│   │   │   ├── requirement-form.tsx
│   │   │   └── seller-dispatch-form.tsx
│   │   ├── layout/
│   │   │   ├── notification-bell.tsx
│   │   │   └── user-nav.tsx
│   │   ├── realtime-deals-listener.tsx
│   │   └── ui/
│   │       ├── dashboard-skeleton.tsx
│   │       ├── data-freshness.tsx
│   │       ├── empty-state.tsx
│   │       ├── loading-status-badge.tsx
│   │       ├── quality-status-badge.tsx
│   │       └── sla-badge.tsx
│   ├── hooks/
│   │   ├── use-master-data.ts
│   │   ├── use-media-query.ts
│   │   └── use-realtime-deals.ts
│   ├── lib/
│   │   ├── offline-queue.ts
│   │   ├── pdf-generator.tsx
│   │   └── storage-utils.ts
│   ├── server/
│   │   ├── actions/
│   │   │   ├── admin-actions.ts
│   │   │   ├── admin-profile-actions.ts
│   │   │   ├── analytics-actions.ts
│   │   │   ├── audit-actions.ts
│   │   │   ├── auth-actions.ts
│   │   │   ├── availability-actions.ts
│   │   │   ├── booking-actions.ts
│   │   │   ├── broker-actions.ts
│   │   │   ├── broker-request-actions.ts
│   │   │   ├── company-actions.ts
│   │   │   ├── confirmation-actions.ts
│   │   │   ├── crm-actions.ts
│   │   │   ├── deal-actions.ts
│   │   │   ├── finalization-actions.ts
│   │   │   ├── lab-actions.ts
│   │   │   ├── loading-actions.ts
│   │   │   ├── logistics-actions.ts
│   │   │   ├── master-data-actions.ts
│   │   │   ├── match-actions.ts
│   │   │   ├── notification-actions.ts
│   │   │   ├── quality-verification-actions.ts
│   │   │   ├── quotation-actions.ts
│   │   │   ├── requirement-actions.ts
│   │   │   ├── support-actions.ts
│   │   │   ├── test-booking-action.ts
│   │   │   ├── test-gate-action.ts
│   │   │   ├── transaction-actions.ts
│   │   │   ├── ui-match-actions.ts
│   │   │   ├── user-profile-actions.ts
│   │   │   └── version-actions.ts
│   │   ├── db/
│   │   │   ├── index.ts
│   │   │   └── schema.ts
│   │   ├── notifications/
│   │   │   ├── adapters/
│   │   │   │   ├── email-adapter.ts
│   │   │   │   └── whatsapp-adapter.ts
│   │   │   ├── dispatcher.ts
│   │   │   └── types.ts
│   │   ├── services/
│   │   │   └── whatsapp-service.ts
│   │   └── utils/
│   │       ├── diff-engine.ts
│   │       ├── finalization-gate.ts
│   │       ├── match-engine.ts
│   │       ├── seller-auth.ts
│   │       └── version-engine.ts
│   └── types/
│       ├── availability-schema.ts
│       ├── broker-request-schema.ts
│       ├── company-schema.ts
│       ├── crm-schema.ts
│       ├── deal-schema.ts
│       ├── deal-version-schema.ts
│       ├── lab-schema.ts
│       ├── loading-schema.ts
│       ├── logistics-schema.ts
│       ├── quality-schema.ts
│       ├── quotation-schema.ts
│       ├── requirement-schema.ts
│       └── transaction-schema.ts
├── supabase/
│   └── migrations/
└── tsconfig.json
```

## Architectural Concepts

### 1. The Separation of Concerns
- **Frontend (UI & Routing):** Kept exclusively inside the `app/` directory and `components/`. The UI simply invokes server actions and displays the responses.
- **Backend (Mutations & Validation):** Kept inside `src/server/actions/`. These actions act as the controllers, bridging the gap between the UI and the database.
- **Database (Persistence):** Kept inside `src/server/db/`. Managed entirely by Drizzle ORM using the Supabase transaction pooler.

### 2. Authentication & Middleware
The app employs a robust edge middleware strategy:
- The **Supabase JWT** (JSON Web Token) acts as the single source of truth for a user's role on the edge.
- During registration/login (`auth-actions.ts`), the Drizzle database is checked, and the role is explicitly "stamped" into the JWT using `supabase.auth.updateUser()`.
- The `middleware.ts` runs on Vercel Edge. It reads the JWT from the cookie instantly, without querying the database, and physically prevents unauthorized roles from accessing other route groups (`(admin)`, `(broker)`, `(client)`).

### 3. Database Connection
To prevent exhaustion and packet loss issues:
- Next.js Server Components and Server Actions connect to Supabase exclusively via the **Transaction Pooler (Port 6543)**.
- Direct IPv4 connections (Port 5432) are intentionally avoided for operational runtime to ensure stability.

### 4. Client-Side Caching (TanStack Query)
To support 2G/3G network optimization, **TanStack Query** has been implemented on the client layer. It is configured to globally cache master data state (Commodities, States, Districts) for dropdowns, ensuring sub-second form loading without redundant database calls across the session.

### 5. Offline Capabilities (IndexedDB & Background Sync)
To support low-bandwidth form submissions, IndexedDB and background sync APIs have been implemented on the client layer. Submissions made while offline are stored in a local queue and synced to the `/api/v1/requirements/sync` route when the device reconnects to the network.

### 6. Supply-side Workflow & Data Isolation
The supply-side creation workflows (inventory availability) are complete and isolated securely via Row Level Security (RLS). All seller inventory is explicitly linked to the core master data tables (Commodities, Grades, Locations, Units) to ensure data consistency and enable the future AI matching engine.

### 7. Assignment Model (Bridging Demand & Supply)
The Tier 1 Broker workspace successfully bridges the isolated Buyer (Demand) and Seller (Supply) data silos via the Assignment Model. The Admin Deal Desk routes unassigned requirements and availabilities to specific brokers, who then utilize the CRM Task Feed and AI Match Center to connect counterparties securely. Buyers and Sellers can also bypass the Deal Desk by selecting a "Preferred Broker" during form submission.

### 8. Quotation Lifecycle State Machine
Quotations represent the formalization of a potential trade. The state machine transitions a Quotation from `Draft` (broker creating) -> `Sent` (dispatched to buyer) -> `Countered/Accepted/Rejected` (buyer actions). This enables a fully digitized negotiation audit trail.

### 9. Server-Side PDF Document Pipeline
Official Quotation documents are generated entirely on the server using `@react-pdf/renderer` via `renderToStream`. This ensures pixel-perfect, secure, and fast document generation without relying on client-side rendering or heavy headless browsers. The resulting PDFs are dynamically generated via an API route (`/api/quotations/[id]/pdf`) and passed directly into the WhatsApp dispatcher.

### 10. External WhatsApp API & Webhook Integration
BrokerBridge communicates asynchronously with buyers via the Meta WhatsApp Cloud API. 
- **Dispatcher**: `whatsapp-service.ts` securely triggers template messages with the attached PDF. It features a local development "mock fallback" to avoid API spam when tokens are absent.
- **Webhook Listener**: `/api/webhooks/whatsapp/route.ts` handles the handshake (`hub.challenge`) and securely ingests delivery receipts and user replies from the Meta servers.

### 11. Deal State Machine & Database Transactions
The finalization of a trade requires atomic integrity across multiple tables (Deals, Requirements, Availabilities, Quotations, and Audit Logs). 
- **Drizzle Transactions**: Multi-table deal closures are protected by Drizzle ORM transactions (`db.transaction()`), ensuring that orphaned records or partial states are physically impossible.
- **Supabase Realtime**: UI synchronization is handled via Supabase Realtime pub/sub channels. The client subscribes to `postgres_changes` via custom React hooks (`use-realtime-deals.ts`), which automatically invalidate TanStack queries and refresh the Next.js router when PostgreSQL triggers fire upon deal closure.

### 12. Supabase Storage & Secure Isolation (RLS)
The platform securely hosts logistical documents (Invoices, Lorry Receipts) using Supabase Storage buckets (`brokerbridge_documents`). 
- **Private Buckets**: Buckets are kept private to ensure secure B2B documentation.
- **Row Level Security**: Access is restricted strictly at the Postgres engine level. RLS policies guarantee that users can only upload files to the folder bearing the Deal ID they are authorized for (as verified by the `deals` table), ensuring impenetrable cross-tenant document isolation.

### 13. Automated Background Tasks (Vercel Cron)
To support time-sensitive supply chain logistics without maintaining a long-running Node.js daemon, we employ Vercel Cron.
- Next.js Route Handlers (e.g., `/api/cron/monitor-dispatches`) are configured via `vercel.json` to be invoked automatically on schedules.
- They are secured utilizing a `CRON_SECRET` authorization header validation, blocking any arbitrary external hits while still interacting natively with Drizzle ORM to scan the database and automatically flag ETAs.

### 14. Financial & Conflict Resolution State Machine
The post-dispatch Deal lifecycle relies on a robust state machine transitioning between Payment and Dispute states. 
- **Payment Pipeline**: Verified payments directly trigger the final state change of a Deal to `Closed`.
- **Conflict Resolution**: Buyers and Sellers can flag active Deals as `Disputed`. This alerts Tier 0 Admins in the centralized Admin Dispute Center, allowing them to override deal statuses manually, resulting in either a `Closed` (Settle) or `Cancelled` (Rollback) state based on the resolution consensus.

### 15. Partial Fulfillment State Machine & Dynamic Quantities
The Deal closure engine natively supports Partial Fulfillment workflows:
- **Agreed Quantity Calculation**: When a quotation is accepted, `agreedQuantity` is computed as `Math.min(remainingNeeded, availQuantity)`.
- **State Transition**: If `fulfilledQuantity < totalReqQuantity`, the requirement status transitions to `Partially Fulfilled` (allowing continued matching and quoting). Once `fulfilledQuantity >= totalReqQuantity`, it transitions to `Accepted (Booked)`.
- **AI Match Resiliency**: The match engine dynamically computes unfulfilled quantity (`targetQuantity - fulfilledQuantity`) to guarantee accurate match scoring and prevent over-allocation.

### 16. Multi-Role Trader Permissions & Edge Middleware Routing
To reflect real-world Indian agricultural commodity trading where merchants frequently act as both buyers and sellers:
- **Dual-Persona Workspace Access**: Users registered with `buyer` or `seller` roles (Tier 2 Traders) are granted access to both `/buyer` and `/seller` workspace portals.
- **Edge Middleware Fail-Safe**: Next.js Edge Middleware (`middleware.ts` & `lib/supabase/middleware.ts`) identifies trader sessions (`role === 'buyer' || role === 'seller'`) and authorizes routing between both workspaces without requiring role alterations in auth metadata, while strictly preventing cross-tier elevation to `/broker` (Tier 1) or `/admin` (Tier 0).
- **Universal Profile Toggle UI**: The `<UserNav>` and `<SellerHeaderDropdown>` components dynamically render workspace switching options ("Switch to Seller Workspace" / "Switch to Buyer Workspace") based on active route context.

### 17. Real-Time Analytics & Safe SQL Aggregation Layer
The platform provides instant role-partitioned financial and operational intelligence without introducing heavy OLAP dependencies:
- **Server Action Aggregators**: `analytics-actions.ts` exports dedicated getters (`getAdminKpisAction`, `getBrokerKpisAction`, `getBuyerKpisAction`, `getSellerKpisAction`, `getSellerCommandCenterDataAction`).
- **Safe Drizzle ORM Aggregations**: Currency calculations utilize safe PostgreSQL casts and coalesce expressions (`COALESCE(SUM(CAST(agreed_price AS NUMERIC) * agreed_quantity), 0)::float`) to prevent null reference errors or precision loss on empty tables.
- **Sub-Second RSC Resolution**: Server dashboards execute analytics queries concurrently alongside profile and operational data fetching via `Promise.all`.

### 18. Event-Driven Notification Queue & Background Cron Engine
To support asynchronous multi-channel alerting without blocking core business transactions:
- **Decoupled Event Pipeline**: Domain mutations (deals booked, dispatches submitted, payments verified, disputes raised) insert pending notification records into the `notifications` table with designated channels (`IN_APP`, `WHATSAPP`, `EMAIL`).
- **Atomic Queue Claiming with `FOR UPDATE SKIP LOCKED`**: The background dispatcher (`dispatchPendingNotifications`) utilizes PostgreSQL Common Table Expressions (CTE) with `FOR UPDATE SKIP LOCKED` to atomically claim and lock batches of pending or eligible retry notifications. This completely eliminates race conditions across distributed or concurrent cron invocations without requiring Redis or distributed locking services.
- **Exponential Backoff Retry Strategy**: Failed delivery attempts automatically calculate next retry timestamps (`next_retry_at`) via exponential backoff (1 min, 5 min, 15 min up to `max_attempts`), updating delivery statuses dynamically.
- **Zero-Fallback Route Security**: The `/api/cron/process-notifications` route handler enforces strict Bearer token authentication against `CRON_SECRET`, throwing a 500 error if unconfigured in environment variables and rejecting invalid tokens with 401 Unauthorized.
- **Live In-App Notification Center**: Client-side `<NotificationBell>` with TanStack Query polling, real-time unread badges, mark-as-read/mark-all-as-read mutations, and role-appropriate deep-linking.

### 19. Enterprise Seller Command Center & Authorization Hardening (Sprint 13)
The Seller workspace has been engineered into a task-first Operational Command Center governed by strict enterprise tenant isolation:
- **App Shell & Role-Aware Navigation**: Responsive shell (`seller-workspace-shell.tsx`) with sticky header (`seller-header.tsx`), real-time KYC badges, dual-profile trader switcher, and 8-module sub-navigation (`seller-nav.tsx`) supporting desktop Forest Jade (`#059669`) active underline and mobile slide-out drawer (`Sheet`) with 48px+ touch targets.
- **Task-First Command Center**: `action-required-banner.tsx` prioritizes P0 actionable items (`DISPATCH_DUE`, `DISPUTE_FILED`, `INVENTORY_EXPIRING`, `KYC_PENDING`) with deep-links to resolving screens above informational KPI cards.
- **Seller Sub-Role Authorization & Mutation Gating (`seller-auth.ts`)**: Granular sub-roles `SELLER_ADMIN`, `SELLER_USER`, and `SELLER_VIEWER`. Server Action helper `verifySellerSession({ allowViewer })` extracts the authenticated `companyId` and blocks write mutations by `SELLER_VIEWER`.
- **Zero Buyer PII Leakage**: Seller-facing deal queries in `deal-actions.ts` mask Buyer names as `"Verified Buyer #B-XXXX"` and omit all personal Buyer contact info (phone, email, GST, address).
- **Confidential Pricing Protection**: Minimum asking prices in `availability-actions.ts` are strictly tenant-isolated to the owning seller company.
- **Request-Time Signed Document Access**: Storage access URLs are generated via `getTransactionDocumentSignedUrlAction` only after verifying deal participant membership (Seller, Buyer, Broker, Admin).
- **Shared UX Resilience Baseline**: Pulsing `<DashboardSkeleton>`, `<EmptyState>` with dashed styling, `<DataFreshness>` with live `router.refresh()` triggers, and strict mutation error recovery preventing false success state.

### 20. Traceable Lot Model & Optimistic Concurrency Guard (Sprint 14)
The Seller Availability framework manages high-frequency supply contracts using a mathematically rigorous Traceable Lot Model and concurrency protection:
- **Mathematical Partitioning of Quantities**: A single physical lot is modeled as `totalQuantity` = `availableQuantity` + `reservedQuantity` (locked in deals pending dispatch) + `soldQuantity` (successfully dispatched). 
- **Optimistic Locking for Inventory Integrity**: To eliminate race conditions where multiple brokers or edits try to claim the same `availableQuantity` simultaneously, the `availabilities` table implements Optimistic Locking via a `version` integer column. Drizzle `UPDATE` queries strictly append `AND version = {currentVersion}`, explicitly incrementing it `version = version + 1`. If `0` rows are returned, the transaction fails and throws a "Stale data detected" exception.
- **Server-Enforced Expiry State Machine**: The match engine (`runAiMatchAction`) relies on hard PostgreSQL `WHERE` logic to exclude inventory: `status = 'Active'` and `valid_until > NOW()`. Any expired inventory is physically invisible to algorithms and brokers.
- **1-Click Rapid Renewal**: Expiry necessitates a deliberate "commercial re-evaluation". The `getAvailabilityForRenewalAction` restricts renewals exclusively to `Expired` records, copies non-identifying specs (Commodity, Location), and forces the Seller to re-declare price, quantity, and a new future `valid_until` date on the frontend before generating a fresh DB record.

### 21. Dynamic Quality Engine (EAV) & Secure Laboratory Vault (Sprint 15)
The platform establishes quality as a dynamic, lot-scoped, and audit-grade domain entity rather than static text:
- **Dynamic Entity-Attribute-Value (EAV) Model**: Master templates are configured in `master_quality_parameters` (defining `commodity_id`, `name`, `type`, `unit`, `min_value`, `max_value`, `target_value`, `is_required`). Concrete seller declarations and laboratory analytical results are recorded lot-specifically in `availability_quality_values` and `lab_test_results` linked via cascading foreign keys.
- **Runtime Mathematical Boundary Validation**: `validateQualityEntries` in `quality-schema.ts` enforces type-level and numeric tolerance checks (`minValue <= value <= maxValue`), generating real-time guidance hints and inline error states.
- **Structured Lab Test Engine & Freshness Computation**: Structured metadata in `lab_tests` tracks laboratory names, report numbers, sample dates, and validity periods without relying on PDF parsing. The `computeLabFreshness()` utility computes real-time freshness (`Valid`, `Expiring Soon`, `Expired`).
- **Mathematical Expiry Override**: The `<QualityStatusBadge />` evaluates the physical date against `Date.now()`, automatically overriding database status to `Expired` if the validity date has lapsed.
- **Private Evidence Storage Vault & RLS**: Physical COA documents are stored in the private `brokerbridge_lab_evidence` Supabase Storage bucket. Access is secured via PostgreSQL RLS policies and server-side signed URL generators (`getLabEvidenceSignedUrlAction`), restricting document views strictly to authorized brokers, admins, and the owning seller company.
- **Server Action Upload Bridge**: Document uploads utilize `uploadLabEvidenceAction` to guarantee SSR `httpOnly` cookie authentication and tenant lot validation without exposing client tokens.
- **Broker Quality Verification Pipeline**: `quality-verification-actions.ts` allows verified Tier-1 Brokers and Admins to audit structured parameters against certificates via `<LabReviewDialog />`, executing atomic status transitions across `lab_tests` and `availability_quality_values`.

### 22. Loading Readiness Operational Model & Lot State Machine (Sprint 16)
Loading readiness is modeled as a pre-deal operational attribute linked directly to supply inventory lots:
- **Operational Lot Attributes**: The `availabilities` table includes `loadingStatus` (`'Not Ready'`, `'Ready'`, `'Scheduled'`, `'Loading'`, `'Loaded'`, `'Delayed'`, `'Blocked'`), `loadingDuration` (integer days for AI matching), `loadingStartDate` (timestamp), `loadingCapacity` (daily dispatch rate in MT), `loadingRemarks` (mandatory operational feedback on delayed/blocked states), and `loadingUpdatedAt`.
- **Pre-Deal Dispatch Feasibility**: Loading readiness allows brokers and algorithms to verify physical warehouse throughput before issuing commercial proposals, preventing deal locks on logistically blocked stock.
- **Mobile-First Mutation Surface**: `<LoadingReadinessForm />` and `<LoadingStatusModal />` provide 48px touch targets for rapid single-handed field updates by warehouse operators.
- **Visual Status Badges**: `<LoadingStatusBadge />` provides color-coded indicators (Emerald for Ready/Loaded, Sky for Scheduled/Loading, Amber for Delayed, Rose for Blocked, Slate for Not Ready) embedded directly on inventory cards.

### 23. Privacy-Isolated Broker Request Inbox & AI Decision Gate (Sprint 16)
The Seller commercial negotiation interface operates under strict broker-mediated and non-autonomous governance:
- **Decoupled Deal Engine Architecture**: The Deal Engine enforces complete architectural decoupling between the Buyer's identity and the Seller's commercial visibility. The Seller interacts solely with broker-mediated proposal objects (`broker_requests` / `quotations`) and never interfaces with Buyer systems or direct communications. Commercial terms (quantity, rate, payment terms, delivery parameters) are negotiated purely on market merits while Buyer identity remains fully abstracted behind the Broker Desk.
- **Zero-Buyer Discovery & Hard Privacy Shield**: The Seller Request Inbox query (`getSellerBrokerRequestsAction`) joins quotations with requirements and lots while strictly scrubbing all Buyer personal and organizational contact data (phone numbers, emails, WhatsApp handles, company legal names, and GST numbers). Sellers evaluate trade terms purely on commercial merits (quantity, offered rate, loading timeline, settlement mechanism).
- **Commercial Response Triad**: The `<BrokerRequestInbox />` component allows Sellers to respond to incoming proposals deterministically:
  - **Accept (`'Seller Accepted'`)**: Locks the Seller's consent and notifies the Broker Desk to draft the formal Deal Booking.
  - **Reject (`'Seller Rejected'`)**: Requires a documented operational or pricing rationale ($\ge 5$ characters) using interactive quick-chips.
  - **Counter (`'Seller Countered'`)**: Permits structured adjustments to price, quantity, earliest dispatch date, and commercial notes without overwriting previous proposal states.
- **Active AI Decision Gate Rule**:
  - The AI Match Engine remains strictly recommendation-only. Under no circumstances can automated background crons, algorithms, or bot routines initiate proposals, accept terms, or generate Bookings.
  - Proposal initiation actions (`createQuotationAction`, `initiateBrokerRequestFromAiMatchAction`) enforce authenticated human broker verification (`role === 'broker' || role === 'admin'`). Autonomous calls are explicitly rejected with `"AI autonomous action prohibited. Only an authorized Broker can initiate commercial proposals."`.
  - Booking creation (`acceptQuotationAction`, `createDealAction`) is locked behind explicit human quotation state machine transitions and authorized party confirmations.
- **Enforced Broker Provenance Attribution**: All requests reaching the Seller Inbox enforce Broker Provenance. Each proposal card in `<BrokerRequestInbox />` displays a verified **"Originated by Broker: [Broker Name] • [Broker Agency]"** badge with `<ShieldCheck>`, assuring the Seller of licensed human curation and regulatory accountability.
- **Non-Autonomous Audit Trail**: Critical decision milestones dispatch structured audit events (`logDecisionGateAuditEventAction`) recording actor provenance, match scores, and human review flags for compliance auditing.
- **Notification Deep-Linking Engine**: In-app notifications contain deep-link URLs (`action_url: '/seller/requests?requestId=...'`). The inbox utilizes Next.js `useSearchParams()` to detect deep links, automatically switch status tabs, smooth-scroll to the card, and highlight it with an emerald focus ring.

### 24. Immutable Deal Versioning Engine & Append-Only Negotiation Ledger (Sprint 17)
To ensure absolute regulatory auditability and eliminate destructive data overwrites during commercial trade negotiations:
- **Append-Only Immutability Invariant**: Standard overwrite mutations on proposals (`UPDATE quotations SET offered_price = ...`) have been completely replaced with an immutable Deal Versioning architecture.
  - Commercial state changes are recorded as frozen snapshots in the `deal_versions` table (`version_number`, `status`, `snapshot_payload`).
  - Back-and-forth counter-offers, rejections, and acceptances are permanently logged in the `negotiation_events` table (`action_type`, `payload`, `actor_id`, `company_id`).
  - Historical version rows and snapshot payloads are strictly write-once and mathematically immutable.
- **Material Change Detection & Atomic Supersession (`version-engine.ts`)**:
  - The `detectMaterialChanges` utility normalizes and compares JSONB snapshots across key commercial fields: `rate`, `quantity`, `deliveryDate`, `deliveryTerms`, `deliveryLocation`, `paymentTerms`, `commodityId`, `gradeId`, `lotNumber`, `packagingType`, `unitSymbol`, and `qualityParameters`.
  - When material changes or counter-proposals are submitted, the backend (`createDealVersionInTransaction` in `version-actions.ts`) executes an atomic transaction that:
    1. Updates the previous active version's status strictly to `'Superseded'`.
    2. Inserts a brand new snapshot row with incremented version number (`version_number: previous + 1`).
    3. Leaves previous historical records completely intact for visual diffing and dispute resolution.
- **Optimistic Locking & Stale-Version Concurrency Protection**:
  - To prevent race conditions where a Seller responds to or counters an outdated proposal while a Broker is concurrently modifying terms, the system enforces Optimistic Concurrency Control.
  - Mutating actions (`respondToBrokerRequestAction`, `createNewDealVersionAction`) strictly require an `expectedVersionNumber` from the client.
  - The `verifyLatestVersion()` guard queries the database for the highest active version number. If `highest_version > expectedVersionNumber`, the mutation is immediately aborted with a `STALE_VERSION_DETECTED` exception.
- **Privacy-Enforced Chronological Audit Timeline (`getNegotiationTimelineAction`)**:
  - The timeline fetcher merges `deal_versions` and `negotiation_events` into a single chronological timeline sorted by `created_at ASC`.
  - **Zero-Buyer PII Exposure**: All Buyer private contact data (phone numbers, emails, WhatsApp identifiers) is completely stripped at the server layer. Actor roles and names are strictly normalized to `"You (Seller)"` and `"Broker Desk"` / `"Broker"`.
  - The `<NegotiationTimeline />` component renders a clean vertical rail with distinct version badges (`v1`, `v2`), status icons (`ACCEPT`, `REJECT`, `COUNTER`), and diff summaries inside a responsive `<Sheet>` drawer.

### 25. Commercial Boundaries, Broker Finalization Gate & Idempotent Booking Engine (Sprint 18)
The transition from commercial negotiation to operational fulfillment enforces strict enterprise boundaries and mathematical concurrency invariants:
- **Strict Separation of Concerns**:
  - **Seller Confirmation $\neq$ Booking**:
    - The Seller Final Confirmation action (`confirmFinalDealTermsAction` in `confirmation-actions.ts`) establishes an explicit, binding Seller commitment to the exact agreed Deal Version (`status: 'Seller Confirmed'`).
    - It does **not** create a Booking, generate operational tracking identifiers, or authorize physical dispatch.
    - It writes an immutable audit record to `negotiation_events` and locks the terms against stale broker edits via Optimistic Concurrency Control (`STALE_VERSION_DETECTED`).
  - **Broker Finalization $\neq$ Booking**:
    - The Broker Finalization Gate (`finalizeDealAction` in `finalization-actions.ts`) represents the formal administrative verification and multi-counterparty authorization step.
    - It evaluates three mandatory pre-flight conditions via `validateFinalizationPreconditions` (`finalization-gate.ts`): (1) Deal Version currency check, (2) Mandatory Seller Confirmation check (`MISSING_SELLER_CONFIRMATION` error on unconfirmed proposals), and (3) Buyer Mandate verification.
    - It transitions the deal version, quotation, and deal records to `'Broker Finalized'`. However, it strictly **refrains** from issuing Booking references or altering physical inventory balances.
  - **System Booking Engine (`createIdempotentBookingAction` in `booking-actions.ts`)**:
    - Booking creation is the sole authoritative gateway from commercial agreement into operational fulfillment.
    - Fulfillment modules (Sprint 19 Dispatch, Logistics, Invoicing, Settlement) can only execute against an existing, locked `bookings` record.
- **Server-Computed Visual Diff Engine (`diff-engine.ts`)**:
  - The `computeVersionDiff` engine executes entirely on the server, comparing the current immutable snapshot JSONB against the preceding version snapshot across 15 commercial dimensions (rate, quantity, delivery terms, payment conditions, lab specifications, packaging).
  - Deterministically maps fields to delta states: `unchanged`, `increased` (favorable emerald highlight), `decreased` (reduced rose strikethrough), `added`, `removed`, or `changed`.
  - The `<VisualDiffSnapshot />` and `<FinalDealSnapshot />` components are strictly read-only, prohibiting client-side field edits and preventing visual spoofing.
- **Idempotent Transactional Booking Engine & Inventory Locking**:
  - **Database-Level Unique Guard**: The `bookings` PostgreSQL table enforces a strict `UNIQUE(deal_id)` constraint alongside a globally unique `booking_reference` (`BKG-YYYY-XXXX`).
  - **Atomic Transaction & Inventory Lock (`db.transaction`)**:
    - Checks for an existing booking linked to the deal ID. If present, it immediately returns the existing record without side effects.
    - Verifies the `'Broker Finalized'` status gate.
    - Executes an atomic, conditional SQL inventory reservation on `availabilities`:
      ```sql
      UPDATE availabilities 
      SET available_quantity = available_quantity - :dealQuantity,
          reserved_quantity = reserved_quantity + :dealQuantity,
          version = version + 1
      WHERE id = :lotId AND available_quantity >= :dealQuantity;
      ```
    - Aborts the entire transaction with `INVENTORY_LOCK_FAILED` if stock is insufficient or concurrently locked.
    - Inserts the locked booking row linked to `deal_versions.id` (`lockedVersionId`), updates parent deal status to `'Dispatch Pending'`, records an audit entry in `negotiation_events`, logs decision gate provenance, and queues in-app notifications.
  - **Network Replay & Idempotency Guarantee**:
    - Distributed network retries, browser refreshes, or concurrent double-clicks safely resolve to the existing `bookings` row without duplicate allocations, double-locking inventory, or generating redundant operational orders.

### 26. Dispatch Entry Gate, Partial Fulfillment Math & Scoped Document Vault (Sprint 19)
Fulfillment operations are strictly gated behind authoritative Bookings, maintaining mathematical balance integrity and isolation at the individual shipment level:
- **Authoritative Booking Entry Gate**:
  - The dispatch lifecycle cannot be initiated on open availabilities, negotiations, or unfinalized proposals (`getBookingForDispatchAction` in `booking-actions.ts`).
  - Polymorphic lookup routines resolve bookings safely by both human-readable `booking_reference` (`BKG-YYYY-XXXX`) and PostgreSQL UUID without throwing type-casting syntax errors.
  - Zombie dispatch actions are eliminated: when `remaining_quantity <= 0`, UI mutations are hidden and replaced with an authoritative completion state.
- **Partial Fulfillment Math & Concurrency Engine (`dispatch-actions.ts`)**:
  - Executes strictly inside `db.transaction()` to prevent race conditions during concurrent dispatches across multiple logistics terminals.
  - Queries historical `DISPATCH_SUBMITTED` negotiation events to compute the exact `alreadyDispatchedQuantity` and `remainingQuantity`.
  - Rejects over-dispatch attempts (`dispatch_quantity > remaining_quantity`) with `DISPATCH_QUANTITY_EXCEEDED`.
  - Transitions booking states dynamically between `'Partially Dispatched'` and `'Fully Dispatched'`.
- **Truck-Scoped Document Vault Separation of Concerns**:
  - **Shipment-Level Scoping**: Unlike pre-deal lab evidence (scoped to `availability_id`), fulfillment documents (`dispatch_documents`) are explicitly foreign-keyed to a specific `dispatch_id` (truck/shipment level) rather than the generic global deal or booking. In multi-truck partial fulfillments (e.g., Truck 1 with 36 MT and Truck 2 with 14 MT), each transport vehicle maintains its own isolated document vault for Lorry Receipts (LR), Tax Invoices, e-Way Bills, Weighment Slips, and Loading Photos.
  - **Server Action Upload Bridge (`uploadFulfillmentDocumentAction`)**:
    - Direct browser client uploads to private Supabase Storage buckets fail when authentication cookies are set to `httpOnly`.
    - Uploads are routed through a Next.js Server Action bridge (`'use server'`) in `document-actions.ts`, authenticating via `verifySellerSession()`, validating 5MB file limits and MIME types, and streaming buffers directly via the authenticated server-side Supabase client.
  - **Short-Lived Signed URL Generation**: Document views utilize 15-minute expiring signed URLs (`getDispatchDocumentsAction`), ensuring fulfillment records cannot be permanently hotlinked or accessed by unauthorized tenants.

### 27. Read-Only Server-Side Financial Settlement Ledger (Sprint 19)
The Seller Financial Settlement module provides high-integrity visibility into gross values, commissions, payments, and receivables without client-side financial calculations:
- **Server-Side Math Engine (`getSellerSettlementOverviewAction`)**:
  - Gross sales values (`agreedQuantity * agreedPrice`), broker commissions (custom rule or default ₹25/MT), other charges, net receivables (`grossValue - brokerCommission - otherCharges`), and outstanding balances are calculated exclusively on the server.
  - Reads confirmed payment records (`payments` table) and open disputes (`disputes` table) in a read-only manner.
  - Enforces strict tenant isolation: Sellers can only query financial settlements for deals tied to their authenticated `companyId`.
- **Hard Zero-Buyer PII Shield**:
  - All Buyer banking details, PAN, GST, phone numbers, and corporate email addresses are scrubbed at the query boundary.
  - Counterparty identities are presented under clean pseudonyms (e.g., `"Verified Buyer #B-XXXX"`).
- **Proactive Operational Financial Alerts**:
  - The settlement engine identifies overdue receivables (exceeding payment due dates) and active trade disputes, bubbling them up into P0 `<ActionRequiredBanner>` notifications on the Seller Command Center.

### 28. Broker Lite App Shell, 360px Mobile Standard & Flat Role Architecture (Sprint 22)
The Broker workspace transitions from a desktop-centric portal into **Broker Lite** — a focused, mobile-first operational shell designed for Tier-2/Tier-3 grain mandi environments:
- **Mobile-First App Shell & 360px Viewport Standard (`layout.tsx`, `broker-mobile-nav.tsx`)**:
  - Engineered specifically for low-cost Android smartphones (360px viewport standard) with zero horizontal scrolling.
  - Features fixed bottom navigation with `env(safe-area-inset-bottom)` padding, haptic feedback classes, and minimum 48×48px thumb-friendly touch targets.
  - Sticky mobile header provides real-time connectivity status and a live notification bell.
  - Desktop view gracefully switches to a left navigation sidebar (`broker-sidebar.tsx`) with user profile menu and secure sign-out.
- **5-Destination Information Architecture**:
  - **Home (`/broker`)**: High-priority operational command center with P0 alerts, compact KPIs, active pipeline, and today's follow-ups.
  - **Work (`/broker/work`)**: Core commercial pipeline covering Requirements, Demand-Supply Matches, Quality/Lab tolerances, and Active Negotiations.
  - **Deals (`/broker/deals`)**: Finalized commercial contracts and mutual confirmations awaiting execution.
  - **Orders (`/broker/orders`)**: Booked orders, truck dispatches, and in-transit logistics monitoring.
  - **More (`/broker/more`)**: Secondary operational utilities including CRM contacts, payments ledger, document vault, and personal settings.
- **Flat 4-Role Architecture (`admin`, `broker`, `buyer`, `seller`)**:
  - The dual-hierarchy (`BROKER_ADMIN` vs. `BROKER_USER` or Manager/Viewer subtypes) has been completely eliminated.
  - Permissions are enforced strictly server-side: all operational brokers hold equal day-to-day transaction capabilities.
  - The operational UI strictly excludes "Team Management", "User Management", or technical authorization abstractions, keeping the broker focused solely on trading operations. Platform governance and user onboarding reside exclusively within Tier-0 `/admin`.

### 29. Action-First Broker Operational Dashboard & Zero Data-Wall UI Principle (Sprint 22)
The root Broker dashboard (`/app/(broker)/broker/page.tsx`) replaces the traditional analytics-wall design with an action-driven operational workflow:
- **"Zero Data-Wall" UI Principle**:
  - Traditional dense HTML `<table>` elements are strictly prohibited on the operational dashboard.
  - All operational data is rendered in mobile-friendly, card-based components with structured selection, clear visual hierarchy, and 1-tap action deep links.
- **P0 "Action Required" Prominence**:
  - Alert cards with distinct left-border accents (`border-l-4 border-l-amber-500` for Counter Offers, `border-l-rose-500` for Delayed Dispatches, and `border-l-teal-500` for Ready-to-Book Mandates) sit directly beneath the compact KPI ribbon.
  - Each alert features a thumb-friendly button deep-linking directly to the required workflow (e.g., `/broker/work?tab=negotiations`, `/broker/orders`).
- **Strict Assignment Model (`broker-dashboard-actions.ts`)**:
  - The backend server action `getBrokerDashboardDataAction()` enforces that brokers query **only** records where they are explicitly assigned (`eq(table.brokerId, session.user.id)`).
  - Parallel Drizzle ORM queries (`Promise.all`) fetch active deals, open requirements, dispatches due, and monthly volume commissions.
- **Hard Zero-Buyer PII Shield**:
  - Buyer personal contact information (email, mobile, WhatsApp, GSTIN) is stripped at the query boundary.
  - Counterparty entities are identified strictly by verified corporate company names or anonymized references (`"Verified Buyer #B-XXXX"`).
- **Interactive CRM Follow-ups (`broker-follow-up-tasks.tsx`)**:
  - CRM tasks due today feature an interactive checkbox with optimistic local state toggling, instant strikethrough animation, and server-side state persistence via `toggleTaskStatusAction()`.

### 30. SPA Context Preservation, Confidential Price Governance & Non-Autonomous Decision Gate (Sprint 23)
Connecting Buyer Demand to Seller Supply within the Broker Workspace enforces strict state preservation, privacy masking, and human decision gate invariants:
- **SPA URL Parameter Context Preservation (`/broker/work/supply?requirementId=[id]&commodity=[id]`)**:
  - To prevent operational friction and eliminate state loss when pivoting between Buyer Demand (Requirements inbox) and Seller Supply (Inventory discovery), BrokerBridge utilizes SPA URL parameters (`?tab=matches&reqId=...` and `/broker/work/supply?requirementId=[id]&commodity=[id]`).
  - Next.js client router enables instantaneous navigation without full-page reloads or layout re-renders.
  - The Seller Supply search workspace mounts a sticky contextual match banner displaying active requirement metrics (target quantity, commodity name, target price) while automatically pre-filtering inventory lots to match the requirement.
  - Brokers retain the ability to dismiss or clear filters with a single tap to browse global inventory seamlessly.
- **Confidential Minimum Price Authorization & Floor Governance (`broker-supply-actions.ts`)**:
  - In strict compliance with commercial confidentiality, the Seller's `confidential_minimum_price` is masked from all Buyer views and raw API responses.
  - However, in `getBrokerSupplySearchAction()`, the field is securely authorized and returned exclusively to authenticated Brokers.
  - This empowers the Broker with the true commercial floor to negotiate effectively without exposing the Seller's bottom line to the Buyer or compromising platform integrity.
- **Non-Autonomous Human Broker Decision Gate (`createBrokerRequestToSellerAction`)**:
  - **Core Architectural Invariant**: AI is strictly for recommendation and match scoring; the licensed human Broker is the mandatory, legally accountable decision-maker.
  - The system strictly rejects autonomous bot or background auto-dispatch triggers. All commercial proposals sent to Sellers require explicit human Broker initiation via `<SendRequestDialog />`.
  - Submitting an outbound request inserts a commercial record into `quotations`, initializes Version 1 snapshot in `deal_versions`, triggers an in-app notification to the Seller dashboard (`/seller/requests?requestId=[id]`), and writes an immutable audit record to `audit_logs` via `logDecisionGateAuditEventAction` certifying human Broker provenance (`humanReviewed: true`).

### 31. Broker Booking Finalization & Logistics State Machine Engine (Sprint 27)
The Broker Booking & Orders module (`/broker/deals` and `/broker/orders`) connects the Broker UI to the existing production-ready Seller booking engine (Sprint 18) with strict concurrency safety and fulfillment isolation:
- **Broker UI Wiring to Production Booking Engine (`booking-gate.tsx`)**:
  - The Broker's Booking Gate UI performs pre-flight verification of mutual confirmations (Seller Confirmation + Buyer Confirmation).
  - Triggers the existing idempotent `finalizeDealAction` and `createIdempotentBookingAction` (`booking-actions.ts`).
  - Utilizes optimistic concurrency control (`expectedVersion` version matching) to guarantee that double-clicks, concurrent edits, or network retries gracefully handle `STALE_VERSION_DETECTED` exceptions without producing duplicate booking references or over-allocating inventory.
- **Logistics & Dispatch Operations State Machine (`logistics-tracker.tsx`, `dispatch-details-card.tsx`)**:
  - Maps post-finalization fulfillment across 6 canonical operational stages: `Booked` -> `Dispatch Planned` -> `Dispatched` -> `In Transit` -> `Delivered` -> `Completed`.
  - Supports exception flags (`Delayed`, `Cancelled`, `Disputed`) with non-destructive status recovery.
  - Safely renders signed document links (LRs, Invoices, e-Way bills) and transit updates without hydration mismatches or horizontal scrolling on 360px mobile viewports.
- **Strict Assignment Model Isolation (`getBrokerActiveOrdersAction`)**:
  - All order operations and deal queries enforce server-side `@supabase/ssr` identity checks and filter strictly by `broker_id === user.id`, preventing cross-broker data leaks.


