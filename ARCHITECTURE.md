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
│   │       ├── page.tsx
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
│   │   │   ├── file-dispute-dialog.tsx
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
│   │   │   ├── auth-actions.ts
│   │   │   ├── availability-actions.ts
│   │   │   ├── broker-actions.ts
│   │   │   ├── company-actions.ts
│   │   │   ├── crm-actions.ts
│   │   │   ├── deal-actions.ts
│   │   │   ├── logistics-actions.ts
│   │   │   ├── master-data-actions.ts
│   │   │   ├── match-actions.ts
│   │   │   ├── notification-actions.ts
│   │   │   ├── quotation-actions.ts
│   │   │   ├── requirement-actions.ts
│   │   │   ├── support-actions.ts
│   │   │   ├── transaction-actions.ts
│   │   │   ├── ui-match-actions.ts
│   │   │   └── user-profile-actions.ts
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
│   │       ├── match-engine.ts
│   │       └── seller-auth.ts
│   └── types/
│       ├── availability-schema.ts
│       ├── company-schema.ts
│       ├── crm-schema.ts
│       ├── deal-schema.ts
│       ├── logistics-schema.ts
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
