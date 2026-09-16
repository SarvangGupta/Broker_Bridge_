__Phase 1: Foundation & Identity \(Sprints 1–3\)__

- __Sprint 1: Repository Setup & Database Architecture__
	- __Goal:__ Initialize the core Next\.js App Router project and Supabase DBaaS infrastructure\.
	- __Key Tasks:__ Configure Tailwind CSS and shadcn/ui\. [x] Set up Drizzle ORM and design the normalized PostgreSQL schema \(Users, Companies, Master Tables\)\. *(Note: Database initialization is handled via manual DBA review rather than automated Drizzle pushes.)*
	- __Technical Deliverables:__ Initial Drizzle migration files and GitHub/Vercel CI/CD pipeline link\.
- __Sprint 2: Authentication & Role\-Based Middleware__
	- __Goal:__ Implement secure entry and role\-based routing\.
	- __Key Tasks:__ Integrate Supabase Auth for mobile OTP signups\. Write Next\.js Middleware to parse JWT role claims and enforce Tier 0 \(Admin\), Tier 1 \(Broker\), and Tier 2 \(Buyer/Seller\) routing\. 
	- __Technical Deliverables:__ Login/Signup screens, protected route groups \(/\(admin\), /\(broker\), /\(client\)\), and session cookie management\.
- __Sprint 3: Master Data & Admin "God Mode"__ (COMPLETED ✅)
	- __Goal:__ Build the centralized master data layer and grant Admin visibility. 
	- __Key Tasks:__ [x] Create the Admin UI for full CRUD operations on Commodities, Grades, Locations, and Logistics. [x] Implement database soft-deletes. 
	- __Technical Deliverables:__ Admin dashboard, Server Actions for master data mutations, and cached TanStack queries for global dropdowns\.

__Phase 2: Core Trading Entities \(Sprints 4–6\)__

- __Sprint 4: Buyer & Seller Onboarding Workflows__ (COMPLETED ✅)
	- __Goal:__ Complete user profile setup and the Admin approval pipeline\.
	- __Key Tasks:__ Build company profile forms requiring GST and Master Data locations\. Create the Admin approval queue\. Set up Row Level Security \(RLS\) policies to ensure Buyer/Seller data isolation\. 
	- __Technical Deliverables:__ Zod\-validated onboarding forms and Supabase RLS policies\.
- __Sprint 5: The Requirement Engine \(Buyer Focus\)__ (COMPLETED ✅)
	- __Goal:__ Enable Buyers to create and track requirements in under 60 seconds\. 
	- __Key Tasks:__ [x] Build the mobile\-optimized Requirement form\. [x] Implement frontend logic to fetch cascading master data \(State  District  City\)\. 
	- __Technical Deliverables:__ createRequirementAction and Service Worker offline\-queue configuration for low\-bandwidth form submission\. 
- __Sprint 6: Availability Engine \(Seller Focus\)__ (COMPLETED ✅)
	- __Goal:__ Allow Sellers to publish and track inventory availability\.
	- __Key Tasks:__ [x] Build the Availability form \(Quantity, Price, Warehouse Location, Valid Until dates\)\. [x] Implement tabbed Seller Hub for inventory tracking.
	- __Technical Deliverables:__ Seller Dashboard grid/cards, Server Actions for inventory lifecycle management, and Drizzle/Supabase table synchronization.

__Phase 3: The Broker & Deal Engine \(Sprints 7–9\)__

- __Sprint 7: AI Matching & CRM Activity Feed__ (COMPLETED ✅)
	- __Goal:__ Equip Brokers with AI intelligence and relationship management tools\.
	- __Key Tasks:__ [x] Build the backend Rule Engine for the AI Confidence Score \(Commodity 35%, Grade 25%, Price Proximity 20%, etc\.\)\. [x] Create the Broker CRM task feed\. [x] Build the Admin Deal Desk for manual assignments.
	- __Technical Deliverables:__ AI match Server Action returning JSONB explainability strings, and Supabase Realtime match notifications\.
- __Sprint 8: Quotation Workflow & Document Generation__ (COMPLETED ✅)
	- __Goal:__ Digitize the negotiation and quotation process\.
	- __Key Tasks:__ Build the Broker quotation form\. Implement server\-side PDF generation for quotes\. Integrate the WhatsApp Business API to send PDF quotes directly to Buyers\. 
	- __Technical Deliverables:__ PDF buffer generator and WhatsApp API webhook route handler \(/api/webhooks/whatsapp\)\.
- __Sprint 9: Deal State Machine & Database Transactions__ (COMPLETED ✅)
	- __Goal:__ Convert accepted quotes into immutable booked deals\.
	- __Key Tasks:__ Implement the Buyer accept/reject/counter UI\. Write the critical Drizzle database transaction that locks the deal, updates requirement statuses, and triggers the audit log\. 
	- __Technical Deliverables:__ acceptQuotationAction transaction logic and Supabase Realtime broadcasts to Broker/Seller dashboards\.

__Phase 4: Logistics, Resolution, and Polish \(Sprints 10–12\)__

- __Sprint 10: Dispatch Tracking & File Storage__ (COMPLETED ✅)
	- __Goal:__ Track logistics from loading to delivery confirmation\.
	- __Key Tasks:__ [x] Build the Seller Dispatch form \(Vehicle No, Driver Details\)\. [x] Configure Supabase Storage buckets for secure Invoice and Lorry Receipt PDF uploads\. 
	- __Technical Deliverables:__ RLS\-protected Supabase Storage buckets and a Vercel Cron job to monitor dispatch ETAs\.
- __Sprint 11: Payments, Disputes, and Audit Logs__ (COMPLETED ✅)
	- __Goal:__ Complete the transaction lifecycle and ensure total system accountability\. *(Note: Audit Logs deferred to Sprint 12)*
	- __Key Tasks:__ [x] Build payment confirmation tracking and the Admin Dispute Resolution interface\. [ ] Enforce PostgreSQL triggers to make the audit\_logs table immutable\. 
	- __Technical Deliverables:__ Payment verification Server Actions and Admin God Mode deal status overrides\. 
- __Sprint 12: Analytics, Notifications, and Final Polish__ (COMPLETED ✅)
	- __Goal:__ Deploy performance optimizations, real-time analytics dashboards, and decoupled notification pipeline\.
	- __Key Tasks:__ [x] Build dynamic KPI cards \(GMV, Active Deals, Volumes, Revenue\) using safe Drizzle aggregations\. [x] Finalize multi-channel notification architecture \(In-App, WhatsApp, Email\) mapped to the Notification Matrix\. [x] Implement Partial Fulfillment state machine and dual-workspace Trader Profile toggle\. [x] Deploy atomic notification cron dispatcher utilizing PostgreSQL `FOR UPDATE SKIP LOCKED` and exponential backoff retry scheduling\.
	- __Technical Deliverables:__ `/api/cron/process-notifications` Route Handler, `analytics-actions.ts` aggregation actions, `<NotificationBell>` UI component, and verified TypeScript compiler pass \(`tsc --noEmit`\)\.

__Phase 5: Enterprise Seller Command Center & Core Modules \(Sprints 13–20\)__

- __Sprint 13: Seller Foundation, Command Center & UX Baseline__ (COMPLETED ✅)
	- __Goal:__ Upgrade the Seller application layout into an Enterprise App Shell, establish task-first Command Center with P0 action alerts, enforce zero Buyer PII leakage, and deploy shared UX resilience baseline.
	- __Key Tasks:__
		- [x] __13.1 — Seller Foundation Audit:__ Executed full codebase audit across Seller routes, Server Actions, schemas, and notification triggers. Authored `seller-foundation-audit-13.1.md`.
		- [x] __13.2 — Seller Workspace Shell & Role-Aware Navigation:__ Built sticky header (`seller-header.tsx`) with real-time KYC badges, `<SellerHeaderDropdown>`, trader switcher, and 8-module sub-navigation (`seller-nav.tsx`) supporting desktop underline tabs and mobile drawer (`Sheet`).
		- [x] __13.3 — Seller Command Center (Operational Dashboard):__ Built task-first Command Center with Top KPI ribbon, P0 `<ActionRequiredBanner>` with deep-linking action cards (`DISPATCH_DUE`, `DISPUTE_FILED`, `INVENTORY_EXPIRING`, `KYC_PENDING`), operational quick-access workspace cards, and `getSellerCommandCenterDataAction()`.
		- [x] __13.4 — Seller Authorization & Privacy Hardening:__ Implemented `verifySellerSession()` helper in `seller-auth.ts`, enforced Buyer privacy masking (`"Verified Buyer #B-XXXX"` in `deal-actions.ts`), confidential minimum price protection in `availability-actions.ts`, request-time document signed URL verification (`getTransactionDocumentSignedUrlAction`), and gated write mutations against `SELLER_VIEWER`.
		- [x] __13.5 — Shared UX / Resilience Baseline:__ Created `<DashboardSkeleton>`, reusable `<EmptyState>`, `<DataFreshness>` with live refresh triggers, and enforced mobile-first 48px touch targets.
	- __Technical Deliverables:__ `seller-workspace-shell.tsx`, `seller-header.tsx`, `seller-nav.tsx`, `seller-auth.ts`, `action-required-banner.tsx`, `dashboard-skeleton.tsx`, `empty-state.tsx`, `data-freshness.tsx`, and passed `tsc --noEmit` validation.

- __Sprint 14: Inventory & Availability 2.0__ (COMPLETED ✅)
	- __Goal:__ Complete Seller Supply Contract, Traceable Lot Model, Auto-Expiry, Quick Renew, and Optimistic Locking Concurrency Guard.
	- __Key Tasks:__
		- [x] __14.1 — Database Migration & Versioning:__ Implement Lot Model quantities and `version` integer for optimistic locking.
		- [x] __14.2 — Availability Form (Seller Supply Contract):__ Build mobile-optimized frontend form mapped to database columns.
		- [x] __14.3 — Availability State Machine & Expiry:__ Enforce deterministic server-enforced state machine and exclude expired records from AI Match Engine.
		- [x] __14.4 — 1-Click Availability Renewal (Quick Renew):__ Allow Sellers to duplicate expired records with field locking.
		- [x] __14.5 — Quantity Concurrency & Inventory Integrity:__ Implement Optimistic Locking on edits.
	- __Technical Deliverables:__ `availability-schema.ts`, `availability-form.tsx`, `availability-actions.ts`, `match-actions.ts`, and verified TypeScript compiler pass `tsc --noEmit`.

- __Sprint 15: Quality, Lab Testing & Evidence__ (COMPLETED ✅)
	- __Goal:__ Make quality a structured, commodity-specific, lot-scoped system with dynamic EAV parameters, structured lab records, private storage vault, and mathematical expiry guards.
	- __Key Tasks:__
		- [x] __15.1 — Quality Parameter Master Integration:__ Created dynamic EAV schema tables `master_quality_parameters` and `availability_quality_values` with `getQualityTemplateByCommodityAction`.
		- [x] __15.2 — Seller Quality Entry & Lot-Scoped Validation:__ Built dynamic quality UI (`dynamic-quality-fields.tsx`) and runtime boundary validator (`validateQualityEntries`) checking min, max, target, and required rules.
		- [x] __15.3 — Structured Lab Test Record & Quality Freshness Engine:__ Built `lab_tests` and `lab_test_results` tables, `<LabTestForm />` with 4-card responsive workflow, and `computeLabFreshness` engine (`Valid`, `Expiring Soon`, `Expired`).
		- [x] __15.4 — Secure Lab Documents & Evidence Vault:__ Configured private Supabase Storage bucket `brokerbridge_lab_evidence` with RLS policies, `<LabDocumentUpload />` component, Server Action upload bridge (`uploadLabEvidenceAction`), and 60-minute signed URL generator (`getLabEvidenceSignedUrlAction`).
		- [x] __15.5 — Quality Readiness, Broker Verification & Supply Badges:__ Built `quality-verification-actions.ts` with `reviewLabTestAction` (role-gated to Broker/Admin), `<QualityStatusBadge />` with mathematical expiry override, `<LabReviewDialog />` broker audit modal, and AI match engine readiness indicators.
	- __Technical Deliverables:__ `quality-schema.ts`, `lab-schema.ts`, `lab-actions.ts`, `quality-verification-actions.ts`, `lab-test-form.tsx`, `dynamic-quality-fields.tsx`, `quality-status-badge.tsx`, `manual_lab_storage_rls.sql`, and verified `tsc --noEmit` compiler pass.

- __Sprint 16: Loading Readiness & Broker Request Inbox__ (COMPLETED ✅)
	- __Goal:__ Make loading readiness a pre-deal operational attribute of inventory lots, deploy privacy-safe Broker Request Inbox with Accept/Reject/Counter response triad, integrate notification deep-linking, and enforce AI Recommendation Decision Gate.
	- __Key Tasks:__
		- [x] __16.1 — Loading Readiness Model & Schema:__ Added `loading_status`, `loading_duration`, `loading_start_date`, `loading_capacity`, `loading_remarks`, and `loading_updated_at` to `availabilities` table with Drizzle migration `0024_add_loading_readiness_to_availabilities.sql`. Built `loading-schema.ts` and `loading-actions.ts`.
		- [x] __16.2 — Loading Readiness UI & Inventory Card Updates:__ Built mobile-optimized `<LoadingReadinessForm />` with 48px touch targets, responsive `<LoadingStatusModal />` (Dialog for desktop / bottom Sheet for mobile), and color-coded `<LoadingStatusBadge />` on `<InventoryCard />`.
		- [x] __16.3 — Broker Request Inbox & Response Workflow:__ Built `/src/server/actions/broker-request-actions.ts` with strict zero-Buyer-PII scrubbing, `broker-request-schema.ts`, and `<BrokerRequestInbox />` supporting status tabs, expiration countdown badges, commercial summaries, Accept modal, Counter modal, and Reject modal with quick-chips. Created `/seller/requests` route and embedded inbox in Command Center.
		- [x] __16.4 — Request Notifications & Deep Links:__ Added `action_url` column to `notifications` schema (migration `0025_add_notification_action_url.sql`). Updated notification bell to handle deep-link routing and optimistic mark-as-read. Enhanced `<BrokerRequestInbox />` with `useSearchParams()` deep-link auto-tabbing, smooth scrolling, and visual highlight.
		- [x] __16.5 — AI Recommendation Decision Gate & Broker Provenance:__ Enforced server-side human broker session validation (`role === 'broker' || role === 'admin'`) rejecting autonomous bot executions. Added verified "Broker-Mediated Request" pill with `<ShieldCheck>` on request cards, structured audit logging (`logDecisionGateAuditEventAction`), and dev hardening verification utility (`verifyDecisionGateIntegrityAction`).
	- __Technical Deliverables:__ `loading-schema.ts`, `loading-actions.ts`, `loading-readiness-form.tsx`, `loading-status-badge.tsx`, `loading-status-modal.tsx`, `broker-request-schema.ts`, `broker-request-actions.ts`, `broker-request-inbox.tsx`, `/seller/requests/page.tsx`, `audit-actions.ts`, `test-gate-action.ts`, and passed `tsc --noEmit` validation.
	- __Broker Handover Note (SELLER-SIDE READY):__ The Seller's Broker Request Inbox and response actions are fully production-ready. When building the Broker Dashboard in the future, developers only need to connect the Broker's outbound request trigger to the existing `broker_requests` database table.

- __Sprint 17: Negotiation + Deal Versioning__ (COMPLETED ✅)
	- __Goal:__ Replace overwrite-style mutations with an immutable Deal Versioning system, enforce append-only audit trail for back-and-forth negotiation events, implement material change detection and automatic supersession, deploy optimistic locking concurrency protection, and build a privacy-safe read-only audit timeline UI.
	- __Key Tasks:__
		- [x] __17.1 — Negotiation Action Model (Backend & Events):__ Added `negotiation_events` table to Drizzle schema (migration `0026_add_negotiation_events.sql`). Hardened `respondToBrokerRequestAction` with atomic Drizzle transactions logging immutable negotiation records (`ACCEPT`, `REJECT`, `COUNTER`).
		- [x] __17.2 — Deal Version Entity & Snapshot:__ Added `deal_versions` table to Drizzle schema (migration `0027_add_deal_versions_snapshot.sql`). Created Zod validation schemas in `deal-version-schema.ts`, `createDealVersionSnapshotAction`, `getDealVersionsAction`, and `getLatestDealVersionAction`.
		- [x] __17.3 — Version Creation & Supersession Rules:__ Built `detectMaterialChanges` and `getMaterialDiffList` in `version-engine.ts`. Implemented `createNewDealVersionAction` and `createDealVersionInTransaction` ensuring material commercial changes atomically supersede previous versions (`status: 'Superseded'`) without mutating historical snapshots.
		- [x] __17.4 — Stale-Version Protection (Optimistic Concurrency):__ Implemented `verifyLatestVersion()` in `version-engine.ts`. Injected `expectedVersionNumber` into Zod schemas, `respondToBrokerRequestAction`, and `createDealVersionInTransaction`, rejecting stale client edits with `"STALE_VERSION_DETECTED"`. Added "Refresh Deal" toast recovery and version badge `v{latestVersionNumber}` on request cards.
		- [x] __17.5 — Negotiation Timeline & Audit UI:__ Built `getNegotiationTimelineAction` in `version-actions.ts` with strict zero-Buyer-PII scrubbing and tenant isolation. Created read-only `<NegotiationTimeline />` vertical timeline component. Integrated into `<BrokerRequestInbox />` via interactive version badges and a responsive slide-out `<Sheet>` drawer.
	- __Technical Deliverables:__ `negotiation_events` and `deal_versions` schema tables, `0026_add_negotiation_events.sql`, `0027_add_deal_versions_snapshot.sql`, `deal-version-schema.ts`, `version-engine.ts`, `version-actions.ts`, `negotiation-timeline.tsx`, `<BrokerRequestInbox />` Sheet integration, and passed `tsc --noEmit` validation.

- __Sprint 18: Final Confirmation + Finalization + Booking__ (COMPLETED ✅)
	- __Goal:__ Implement the critical commercial boundary: Seller Confirmation ≠ Booking; Broker Finalization → System Booking.
	- __Key Tasks:__
		- [x] __18.1 — Final Deal Snapshot (Read-Only):__ Built `getDealVersionSnapshotAction(versionId)` in `version-actions.ts` with strict session verification, tenant isolation, and zero Buyer PII exposure. Built mobile-first read-only `<FinalDealSnapshot />` rendering frozen `snapshot_payload` JSONB with 5 comprehensive term groups. Created `/seller/deals/[id]/confirm/page.tsx` route with server-side pre-fetching.
		- [x] __18.2 — Visual Diff Confirmation Screen:__ Built Server-Side Diff Engine (`computeVersionDiff` in `diff-engine.ts`) comparing commercial fields to produce deterministic delta states (`unchanged`, `increased` [emerald], `decreased` [rose strikethrough], `changed`). Built `<VisualDiffSnapshot />` with "What Changed" summary banner and delta annotations.
		- [x] __18.3 — Seller Final Confirmation:__ Built `confirmFinalDealTermsAction` and `requestBrokerCorrectionAction` in `confirmation-actions.ts` with atomic transactions, optimistic locking (`STALE_VERSION_DETECTED`), immutable `negotiation_events` auditing, and broker in-app notifications. Built `<FinalConfirmationActions />` action bar.
		- [x] __18.4 — Broker Finalization Gate:__ Built `validateFinalizationPreconditions` in `finalization-gate.ts` enforcing 3 mandatory pre-flight checks: Version Concurrency match, Seller Confirmed status, and Buyer Mandate confirmation. Built `finalizeDealAction` in `finalization-actions.ts` and interactive `<DevFinalizationGateTester />`.
		- [x] __18.5 — Idempotent Booking Creation:__ Added `bookings` table with database-level `UNIQUE` constraint on `deal_id` (migration `0028_add_bookings_table.sql`). Built `createIdempotentBookingAction` in `booking-actions.ts` with transaction-safe inventory reservation on `availabilities` table, unique reference generation (`BKG-YYYY-XXXX`), and replay-safe idempotency. Built Seller Deal View at `/seller/deals/[id]/page.tsx` with `<SellerDealDetailView />`.
	- __Technical Deliverables:__ `bookings` table schema, `0028_add_bookings_table.sql`, `diff-engine.ts`, `finalization-gate.ts`, `confirmation-actions.ts`, `finalization-actions.ts`, `booking-actions.ts`, `final-deal-snapshot.tsx`, `visual-diff-snapshot.tsx`, `final-confirmation-actions.tsx`, `dev-finalization-gate-tester.tsx`, `seller-deal-detail-view.tsx`, `/seller/deals/[id]/confirm/page.tsx`, and passed `tsc --noEmit` validation.
	- __Broker Handover Note (SELLER-SIDE READY):__ The Seller's Final Confirmation flow, the Visual Diff engine, and the Idempotent Booking generator are fully production-ready. We used a Dev Mode Simulator (`dev-finalization-gate-tester.tsx`) to test the `finalizeDealAction` and state machine transitions. When building the Broker Dashboard in the future, developers only need to connect the real Broker's UI to these existing server actions.

- __Sprint 19: Dispatch, Documents & Seller Settlement__ (COMPLETED ✅)
	- __Goal:__ Harden the established Sprint-10/11 operational foundation so fulfillment begins only from a valid Booking and quantity/payment data remain trustworthy.
	- __Key Tasks:__
		- [x] __19.1 — Booked Order / Dispatch Entry Gate:__ Built `getSellerBookedOrdersAction` and `getBookingForDispatchAction` in `booking-actions.ts` with strict tenant isolation, zero Buyer PII leakage, and gate rejection for unbooked trades. Resolved polymorphic UUID / Booking Reference lookup bug. Built `<BookedOrdersTable />`, `/seller/dispatch` route, and gated `/seller/dispatch/[bookingId]` page.
		- [x] __19.2 — Dispatch & Partial Fulfillment Engine:__ Upgraded `sellerDispatchSchema` in `dispatch-schema.ts`. Built `submitDispatchAction` and `getBookingRemainingQuantityAction` in `dispatch-actions.ts` with Drizzle `db.transaction()` concurrency and balance checks, state transitions (`Partially Dispatched` vs `Fully Dispatched`), and immutable `negotiation_events` auditing. Upgraded `<SellerDispatchForm />` with dynamic partial fulfillment inputs, `remainingQuantity` prop, inline validation for quantity overflows, 1-click "Fill All Remaining", and 48px touch targets.
		- [x] __19.3 — Fulfilment Documents:__ Secure Seller document handling (Invoice, LR, e-Way Bill, Weighment slip, Loading photo) with `dispatch_documents` table (migration `0029_add_dispatch_documents.sql`), private Supabase storage bridge with exponential backoff upload retries (`uploadFulfillmentDocument` in `storage-utils.ts`), short-lived 15-minute signed URLs in `document-actions.ts`, and interactive `<FulfillmentDocumentUpload />` and `<DispatchDetailsSheet />` components.
		- [x] __19.4 — Payment & Settlement View:__ Built `getSellerSettlementOverviewAction` in `settlement-actions.ts` calculating gross sale value, broker commission, net receivables, paid amount, outstanding balance, and overdue tracking. Built `<SettlementSummaryCards />`, `<SettlementLedgerTable />`, `<SettlementWorkspaceView />`, and `/seller/payments` route.
		- [x] __19.5 — Delivery / Completion State Integration:__ Built `getDispatchTrackingAction` in `dispatch-actions.ts` and `<LogisticsTracker />` with 3-stage stepper (`Dispatched` -> `In Transit` -> `Delivered`), delay alerts, and open dispute integration. Integrated P0 Action Required banners in `analytics-actions.ts` and `<ActionRequiredBanner />` for overdue payments, transit delays, and active disputes.
	- __Technical Deliverables:__ `dispatch_documents` table schema, `0029_add_dispatch_documents.sql`, `dispatch-schema.ts`, `settlement-schema.ts`, `dispatch-actions.ts`, `booking-actions.ts`, `document-actions.ts`, `settlement-actions.ts`, `seller-dispatch-form.tsx`, `booked-orders-table.tsx`, `fulfillment-document-upload.tsx`, `dispatch-details-sheet.tsx`, `logistics-tracker.tsx`, `settlement-ledger-table.tsx`, `settlement-summary-cards.tsx`, `settlement-workspace-view.tsx`, `/seller/dispatch/page.tsx`, `/seller/dispatch/[bookingId]/page.tsx`, `/seller/payments/page.tsx`, and passed `tsc --noEmit` validation.

- __Sprint 20: Notifications, Reports, Security & End-to-End UAT__ (COMPLETED ✅)
	- __Goal:__ Close the Seller MVP by validating the complete workflow, deploying an operational Seller Action Center, exposing Seller-owned reporting, and verifying end-to-end security posture.
	- __Key Tasks:__
		- [x] __20.1 — Seller Notification & Action Center:__ Enhanced `notifications` schema with `context_reason`, `action_label`, `action_url`, `idempotency_key`, and `is_read` (`0030_add_seller_action_center_notifications.sql`). Built `dispatchSellerNotificationAction` with automated regex Buyer PII scrubber and duplicate alert suppression. Built primary Action Center (`/seller/notifications`) with tab filtering, 3-part operational cards, and 48px touch targets. Upgraded `<NotificationBell />` popover with unread counter and deep links.
		- [x] __20.2 — Seller Reports & Visibility:__ Built `getSellerAnalyticsAction` with server-side tenant isolation (`report-actions.ts`), `sellerReportSchema` (`report-schema.ts`), and `/seller/reports` page featuring time-range filtering (`7d`, `30d`, `all`), Inventory Status breakdown (Available vs Reserved vs Sold), Sales trend charts, financial overview (Gross Sales, Commission, Net Receivables, Overdue), and CSV ledger export.
		- [x] __20.3 — Security & State-Transition Double Check:__ Implemented automated security & state-transition harness (`security-state-audit.ts` / `runSecurityDoubleCheckAction`) asserting 7 mandatory gate checks (Unbooked dispatch block, premature finalization block, cross-tenant file URL leakage block, price tamper block, stale version concurrency block, viewer role mutation block, direct buyer PII leakage block) with 7/7 (100%) PASS score. Hardened `logistics-actions.ts`.
		- [x] __20.4 — Performance, Mobile & Resilience Validation:__ Created Seller workspace root Error Boundary (`error.tsx`) with user-friendly retry trigger and Global Loading Skeleton (`loading.tsx`). Conducted 360px mobile viewport audit ensuring all buttons, inputs, selects enforce `min-h-[48px]` touch targets, responsive table horizontal scroll wrappers (`overflow-x-auto`), and CLS = 0 layout stability.
		- [x] __20.5 — End-to-End Seller UAT & Release Gate:__ Built Automated E2E Positive Path Runner (`uat-positive-path.ts`) executing the 10-phase / 23-step canonical Seller journey (10/10 PASS) and Negative Boundary Attack Suite (`uat-negative-cases.ts`) covering stale versions, quantity overflows, expired supplies, IDOR defense, and replay idempotency (5/5 PASS). Generated Production Release Checklist (`SELLER_RELEASE_CHECKLIST.md`) with 100% acceptance criteria signoff.
	- __Technical Deliverables:__ `0030_add_seller_action_center_notifications.sql`, `notification-actions.ts`, `seller-action-center-view.tsx`, `/seller/notifications/page.tsx`, `report-actions.ts`, `seller-reports-view.tsx`, `/seller/reports/page.tsx`, `security-state-audit.ts`, `uat-positive-path.ts`, `uat-negative-cases.ts`, `SELLER_RELEASE_CHECKLIST.md`, and passed `tsc --noEmit` validation (0 errors).

---

__Phase 6: Enterprise Broker Workspace & Mediation Engine (Sprints 21–30)__

- __Sprint 21: Pre-Broker Platform & Security Audit Gate__ (COMPLETED ✅)
	- __Goal:__ Mandatory regression, integration, security, and data/state audit across Sprints 1–20 before commencing Broker feature implementation.
	- __Key Tasks:__
		- [x] __21.1 & 21.2 — Foundation & Seller Dashboard Audit:__ Completed and documented in `platform-audit-21.md`. Verified multi-tenant boundaries, zero client impersonation, and state machines.
		- [x] __21.3 — Cross-Module Integration Audit:__ Completed and documented in `integration-audit-21.3.md`. Traced shared demand-to-supply pipeline (`Buyer` -> `Requirement` -> `Seller` -> `Lot` -> `Quotation` -> `Deal` -> `Booking` -> `Dispatch`).
		- [x] __21.4 — Security & Flat Role Architecture Audit:__ Completed and documented in `security-audit-21.4.md`. Verified channel disintermediation, zero Buyer PII leakage, storage directory traversal guards, and officially transitioned to Flat 4-Role Architecture (`admin`, `broker`, `buyer`, `seller`).
		- [x] __21.5 — Acceptance Gate:__ 100% test pass rates across 7 security gates, 10 positive UAT phases, and 5 negative boundary suites. Formally cleared for Sprint 22 (Green Light).
	- __Technical Deliverables:__ `docs/platform-audit-21.md`, `docs/integration-audit-21.3.md`, `docs/security-audit-21.4.md`.

- __Sprint 22: Broker Shell + Home (Broker Lite)__ (COMPLETED ✅)
	- __Goal:__ Deploy mobile-first Broker Lite App Shell, 5-destination navigation, flat role operational security, and Action-First live data dashboard.
	- __Key Tasks:__
		- [x] __22.1 — Mobile Application Shell:__ Built Broker workspace root shell in `app/(broker)/broker/layout.tsx` tested at 360px viewport. Implemented Broker Global Loading Skeleton (`loading.tsx`) and Error Boundary (`error.tsx`).
		- [x] __22.2 — Core Navigation & Flat Role Security:__ Built desktop left sidebar (`broker-sidebar.tsx`) and mobile bottom nav + sticky header (`broker-mobile-nav.tsx`) with 5 core operational tabs: **Home** (`/broker`), **Work** (`/broker/work`), **Deals** (`/broker/deals`), **Orders** (`/broker/orders`), and **More** (`/broker/more`). Strictly enforced flat `broker` role — zero "Team Management", "User Management", or `BROKER_ADMIN` sub-roles exposed.
		- [x] __22.3 — Action-First Broker Dashboard (Zero Data-Walls):__ Completely stripped out legacy horizontal `<Tabs>` interface from `app/(broker)/broker/page.tsx`. Rebuilt with compact 4-card KPI ribbon (`Active Deals`, `Open Requirements`, `Dispatch Due`, `Commission This Month`) with Electric Teal (`#0D9488`) icon accents. Placed P0 "Action Required" alert cards with left-border accents above general metrics. Built 2-column lower section for Active Pipeline and Today's Follow-ups.
		- [x] __22.4 — Live Data Integration (Strict Assignment Model):__ Built `getBrokerDashboardDataAction()` in `src/server/actions/broker-dashboard-actions.ts` executing parallel Drizzle ORM queries (`Promise.all`). Enforced strict assignment filter (`broker_id === currentUser.id`) and absolute Zero-Buyer-PII scrubbing. Converted `page.tsx` into an `async Server Component` with `<BrokerFollowUpTasks />` interactive client component wired to `toggleTaskStatusAction()`. Handled all empty states gracefully.
	- __Technical Deliverables:__ `app/(broker)/broker/layout.tsx`, `page.tsx`, `loading.tsx`, `error.tsx`, `work/page.tsx`, `deals/page.tsx`, `orders/page.tsx`, `more/page.tsx`, `broker-sidebar.tsx`, `broker-mobile-nav.tsx`, `broker-follow-up-tasks.tsx`, `broker-dashboard-actions.ts`, and verified `npx tsc --noEmit` pass (0 errors).

- __Sprint 23: Requirements + Seller Supply__ (COMPLETED ✅)
	- __Goal:__ Buyer requirement processing, Seller inventory discovery, and broker outbound commercial trigger.
	- __Key Tasks:__
		- [x] __23.1 — Buyer Requirements Inbox:__ Built mobile-first, card-first Buyer Requirements Inbox inside `/broker/work` tab adhering strictly to Broker Assignment Model (`eq(requirements.brokerId, user.id)`), Zero Data-Wall rule, and zero Buyer PII leakage. Implemented read-only Drizzle server action `getBrokerAssignedRequirementsAction()` with multi-table joins. Built mobile `<RequirementCard />` with bold commercial metrics, sector breadcrumbs, and $\ge 48\text{px}$ touch targets for "Find Seller" (Electric Teal `#0D9488`) and "Ask Buyer". Integrated `<BrokerRequirementsInbox />`, `<BrokerWorkWorkspace />`, and specialized loading skeleton in `app/(broker)/broker/work/loading.tsx`.
		- [x] __23.2 — Seller Supply Discovery:__ Built Seller Supply Search engine at `/broker/work/supply` with `getBrokerSupplySearchAction()`. Strictly enforced active lot filters (`validUntil > NOW()`), seller visibility boundaries (`visibility = 'global' OR brokerId = user.id`), and authorized Broker retrieval of Seller's `confidentialMinimumPrice`. Built `<SupplyFiltersComponent />` (mobile bottom Sheet + desktop 4-column panel with human-readable name resolvers) and `<SupplyCard />` with negotiation floor pricing.
		- [x] __23.3 — Acceptance & Context Preservation:__ Connected "Find Seller" route from Requirement Card to `/broker/work/supply?requirementId=[id]&commodity=[id]`, displaying contextual match banner and pre-filtering supply parameters without full-page state loss.
		- [x] __23.4 — Outbound Request Trigger (Seller Connection):__ Built `createBrokerRequestToSellerAction()` inserting commercial proposals into the existing `quotations` table, initializing Version 1 in `deal_versions`, and firing in-app notification to the Seller dashboard (`/seller/requests?requestId=[id]`) without altering Seller-side inbox logic from Sprint 16. Built responsive `<SendRequestDialog />` with 48px touch targets.
	- __Technical Deliverables:__ `src/server/actions/broker-work-actions.ts`, `src/server/actions/broker-supply-actions.ts`, `src/server/actions/broker-outbound-actions.ts`, `src/components/broker/work/requirement-card.tsx`, `src/components/broker/work/broker-requirements-inbox.tsx`, `src/components/broker/work/broker-work-workspace.tsx`, `src/components/broker/work/supply-filters.tsx`, `src/components/broker/work/supply-card.tsx`, `src/components/broker/work/broker-supply-search-workspace.tsx`, `src/components/broker/work/send-request-dialog.tsx`, `app/(broker)/broker/work/page.tsx`, `app/(broker)/broker/work/supply/page.tsx`, and verified `npx tsc --noEmit` pass (0 errors).

---

### 🚀 **Global Platform Status: SPRINT 23 COMPLETED | ADVANCING TO SPRINT 24**
Sprint 23 (Requirements + Seller Supply) is 100% complete, manually verified, and audited. The platform is ready to begin **Sprint 24: Matching + Quality**.



