# Micro-Sprint 13.1: Existing Seller Foundation Audit Report
**BrokerBridge Enterprise — Production Seller Scope**  
**Audit Date:** August 2026  
**Auditor:** Antigravity AI Pair Programmer & System Architect  
**Document Status:** Complete & Implementation-Ready  
**Sprint Phase:** Sprint 13 — Seller Command Center & Foundation Audit  

---

## 1. Executive Summary & Audit Scope

Before beginning new feature development for the **Seller Command Center (Sprints 13–20)**, a comprehensive **read-only codebase audit** was executed across the existing BrokerBridge Enterprise repository. 

The purpose of this audit is to:
1. **Regression-Protect Existing Assets:** Verify that all core shared capabilities established in Sprints 1–12 (Auth, Master Data, KYC Onboarding, Availabilities, AI Matching, Quotations/Deals, Dispatch/Storage, Payments/Disputes, Notifications, and Analytics) remain stable and are not rewritten without justification.
2. **Audit Seller Architecture:** Inspect every Seller-facing route, Server Action, database entity, Supabase RLS policy, storage configuration, and background cron hook.
3. **Isolate Conflicting Legacy Flows:** Locate legacy transactional dependencies on WhatsApp and direct quote acceptance flows that conflict with the non-negotiable rules of Seller PRD v3.0 (*"WhatsApp is notification-only; Seller Final Confirmation and Broker Finalization are mandatory distinct states"*).
4. **Establish the Baseline Gap Analysis:** Categorize every subsystem as **`[Existing]`**, **`[Needs hardening]`**, or **`[Missing]`** to guide micro-sprints 13.2 through 20.5.

---

## 2. Architectural Audit of Seller Subsystems

### 2.1 Routes & App Shell
- **Path:** `app/(seller)/seller/page.tsx`
  - **Current Implementation:** Serves the Seller Dashboard. Checks for authenticated user and company profile. If no company profile is found, renders `CompanyOnboardingForm`. If verified, renders top nav with `NotificationBell`, `SellerHeaderDropdown`, 3 top-level KPI cards (`Active Inventory`, `Pending Dispatches`, `Total Revenue`), and a 2-tab view (`My Inventory` via `MyAvailabilitiesTable` and `My Deals` via `SellerDealsTable`).
  - **Component Structure:**
    - `src/components/dashboard/my-availabilities-table.tsx` — Displays listed availabilities, quantities, prices, location, and validity.
    - `src/components/dashboard/seller-deals-table.tsx` — Displays booked deals, status badges, dispatch trigger button, and dispute filing button.
    - `src/components/dialogs/post-availability-dialog.tsx` — Modal wrapper for `AvailabilityForm`.
    - `src/components/dashboard/seller-header-dropdown.tsx` — Header profile dropdown with dual-workspace toggle (`/buyer`), settings, support, and sign out.
- **Middleware & Routing Guard:** `middleware.ts` / `lib/supabase/middleware.ts`
  - Enforces session tokens via secure HTTP-only cookies.
  - Enforces role-based routing (`/admin`, `/broker`, `/buyer`, `/seller`).
  - Allows dual-workspace trader switching between `/buyer` and `/seller` for verified trading entities.

### 2.2 Seller-Related Server Actions
| Server Action File | Primary Functions | Role / Security Check | Status |
| :--- | :--- | :--- | :--- |
| `src/server/actions/availability-actions.ts` | `createAvailabilityAction`, `getMyAvailabilitiesAction`, `cancelAvailabilityAction` | Authenticated + Company Linked | `[Existing]` (Needs contract expansion in 14.1–14.3) |
| `src/server/actions/deal-actions.ts` | `acceptQuotationAction`, `rejectQuotationAction`, `counterQuotationAction`, `getDealsByCompanyAction` | Authenticated + Party to Deal | `[Existing]` (Needs Seller isolation & new confirmation gate in 18.1–18.4) |
| `src/server/actions/quotation-actions.ts` | `createQuotationAction`, `reviseQuotationAction`, `sendQuotationAction`, `getBrokerQuotationsAction`, `getBuyerQuotationsAction` | Broker / Admin / Party to Requirement | `[Existing]` (Contains legacy direct WhatsApp dispatch) |
| `src/server/actions/logistics-actions.ts` | `createDispatchAction`, `createInvoiceAction` | Seller verified on Deal | `[Existing]` (Needs partial dispatch expansion in 19.2) |
| `src/server/actions/transaction-actions.ts` | `confirmPaymentAction`, `fileDisputeAction`, `resolveDisputeAction`, `getOpenDisputesAction` | Party to Deal / Admin | `[Existing]` (Functional foundation) |
| `src/server/actions/company-actions.ts` | `createCompanyProfile`, `getCompanyProfile`, `getPendingCompaniesAction`, `approveCompanyAction`, `rejectCompanyAction` | Authenticated / Admin | `[Existing]` (Complete foundation) |
| `src/server/actions/analytics-actions.ts` | `getSellerKpisAction`, `getBuyerKpisAction`, `getAdminKpisAction`, `getBrokerKpisAction` | Company verified | `[Existing]` (Production-ready aggregations) |
| `src/server/actions/notification-actions.ts` | `getNotificationsAction`, `getUnreadNotificationCountAction`, `markNotificationAsReadAction`, `markAllNotificationsAsReadAction` | User Auth ID | `[Existing]` (In-App notification foundation) |
| `src/server/actions/user-profile-actions.ts` | `getUserProfileAction`, `updateUserProfileAction`, `getFullBuyerProfileDetailsAction` | Authenticated User | `[Existing]` |
| `src/server/actions/match-actions.ts` & `ui-match-actions.ts` | `getMatchesForRequirementAction`, `getUiMatchesForRequirementAction` | Broker / Admin | `[Existing]` (Recommendation-only engine) |

### 2.3 Database Entities & Schema (`src/server/db/schema.ts`)
- **`companies`**: `id`, `name`, `gst`, `businessTypeId`, `stateId`, `districtId`, `status`, `isVerified`, `trustScore`.
- **`users`**: `id`, `name`, `mobile`, `email`, `role`, `status`, `companyId`, `createdAt`.
- **`availabilities`**: `id`, `companyId`, `commodityId`, `gradeId`, `quantity`, `unitId`, `price`, `stateId`, `districtId`, `validUntil`, `visibility`, `brokerId`, `status`, `createdAt`.
- **`quotations`**: `id`, `requirementId`, `brokerId`, `sellerAvailabilityId`, `offeredPrice`, `status`, `validUntil`, `createdAt`, `rejectionReason`, `counterPrice`, `counterNotes`.
- **`deals`**: `id`, `requirementId`, `quotationId`, `buyerId`, `sellerId`, `brokerId`, `agreedPrice`, `agreedQuantity`, `status`, `createdAt`, `closedAt`.
- **`dispatches`**: `id`, `dealId`, `sellerId`, `vehicleTypeId`, `vehicleNumber`, `driverName`, `driverMobile`, `dispatchDate`, `expectedDeliveryDate`, `status`, `createdAt`.
- **`invoices`**: `id`, `dealId`, `sellerId`, `invoiceNo`, `amount`, `status`, `fileUrl`, `createdAt`.
- **`payments`**: `id`, `dealId`, `amount`, `referenceNumber`, `status`, `createdAt`.
- **`disputes`**: `id`, `dealId`, `filedBy`, `reason`, `description`, `resolutionNotes`, `status`, `createdAt`, `resolvedAt`.
- **`notifications`**: `id`, `userId`, `companyId`, `channel`, `eventType`, `title`, `message`, `payload`, `deliveryStatus`, `readAt`, `attemptCount`, `maxAttempts`, `lastAttemptAt`, `nextRetryAt`, `errorMessage`, `providerMessageId`, `sentAt`, `failedAt`, `createdAt`.
- **Master Tables**: `masterStates`, `masterDistricts`, `masterIndustries`, `masterCategories`, `masterCommodities`, `masterGrades`, `masterUnits`, `masterPackagingTypes`, `masterVehicleTypes`, `masterBusinessTypes`.

### 2.4 Supabase Storage & RLS
- **Storage Bucket:** `brokerbridge_documents` (configured with authenticated RLS in `supabase/migrations/manual_storage_rls.sql`).
- **Database RLS:** `manual_rls_companies.sql` secures company isolation at PostgreSQL layer. Application actions execute via Drizzle with explicit session authentication.

### 2.5 Notification Pipeline & Cron Infrastructure
- **Dispatcher:** `src/server/notifications/dispatcher.ts` (Atomic queue processing using `FOR UPDATE SKIP LOCKED`, exponential backoff retry scheduling).
- **Adapters:** `whatsapp-adapter.ts` (mock/live WhatsApp Cloud API), `email-adapter.ts` (mock/SMTP).
- **Cron Jobs:**
  - `/api/cron/process-notifications/route.ts` — Asynchronous notification queue processor.
  - `/api/cron/monitor-dispatches/route.ts` — Automated dispatch ETA & SLA monitor.

---

## 3. Foundation Mapping & Categorized Gap Analysis

| Subsystem / Feature Area | Existing Implementation in Codebase | Seller PRD v3.0 Requirement | Classification | Sprint Target |
| :--- | :--- | :--- | :--- | :--- |
| **Authentication & Role Access** | Supabase Auth OTP, `middleware.ts` role checks, trader toggle in `seller-header-dropdown.tsx`. | Enforce strict Seller organization isolation; never leak Buyer private data. | **`[Existing]`** (Harden data leakage in actions) | 13.4 |
| **Workspace Shell & Navigation** | Basic top nav + tabs in `app/(seller)/seller/page.tsx`. | Command Center layout with responsive navigation, mobile-first 360px reflow, role-aware menus. | **`[Needs hardening]`** | 13.2 |
| **Action Required Command Center** | Simple 3 KPI cards on dashboard. | Priority P0 Action Required widget (broker requests, deal confirmations, quality corrections, dispatch due, loading alerts). | **`[Needs hardening]`** | 13.3 |
| **Lot & Batch Tracking** | `availabilities` table tracks total `quantity`, `price`, `valid_until`. | Full lot/batch model: Lot Number, Available vs Total vs Reserved Quantity, MOQ, Active/Reserved state tracking. | **`[Needs hardening]`** | 14.1, 14.5 |
| **Availability Form & Contract** | `availability-form.tsx` has basic fields (Commodity, Grade, Quantity, Price, State, District, Valid Until). | Explicit Contract: Add Availability From date, Confidential Minimum Price, Loading Point, MOQ, Quality Template parameters, COA upload. | **`[Needs hardening]`** | 14.2 |
| **Availability Lifecycle & Auto-Expiry** | Status is `'Open'` or `'Cancelled'`. Manual date checking. | State machine: `Draft` ➔ `Pending Approval` ➔ `Active` ➔ `Reserved` ➔ `Fulfilled` / `Expired` / `Cancelled`. | **`[Needs hardening]`** | 14.3 |
| **⭐ 1-Click Availability Renewal** | None (Seller must re-enter form from scratch). | Quick Renew / Duplicate button on expired lots pre-fills all data for 60-second re-listing. | **`[Missing]`** | 14.4 |
| **Quantity Concurrency & Locking** | Basic Drizzle updates. | Transactional inventory reservation and optimistic locking to prevent overselling across concurrent quotes. | **`[Needs hardening]`** | 14.5 |
| **Dynamic Quality Parameters** | `master_grades.parameters` exists as JSONB. | Dynamic form rendering based on selected commodity's master quality template (Moisture, Admixture, Protein, Oil, etc.). | **`[Missing]`** | 15.1, 15.2 |
| **Structured Lab Testing Records** | None (Only generic file upload exists). | Lab Record entity: Lab Name, Certificate Number, Test Date, Expiry Date, Verified status, COA attachment. | **`[Missing]`** | 15.3, 15.4 |
| **Quality Freshness & Expiry** | None. | Verification badges and freshness checks (expired reports excluded from verified matching). | **`[Missing]`** | 15.5 |
| **Loading Readiness** | None. | Pre-deal supply attribute: Loading Status (`Ready`, `Scheduled`, `Loading`, `Delayed`, `Blocked`), Duration, Remarks, and Broker alerts. | **`[Missing]`** | 16.1, 16.2 |
| **Broker Request Inbox** | None (Broker requests do not have dedicated Seller inbox). | Dedicated Seller inbox for broker-originated demand with response deadline countdown and Accept/Reject/Counter actions. | **`[Missing]`** | 16.3, 16.4 |
| **AI Recommendation Gate** | `match-engine.ts` calculates confidence score (35% Commodity, 20% Grade, 20% Price, 15% Quantity, 10% Location/Logistics). | Hard rule: AI recommendations surface only to Broker. Broker is mandatory decision-maker before Seller receives commercial request. | **`[Existing]`** | 16.5 |
| **Deal Versioning & Snapshots** | Single `quotations` record updated on revision (`status = 'Revised Sent'`). | Immutable `deal_versions` entity. Every price/quantity/term revision creates a permanent immutable snapshot with audit trail. | **`[Missing]`** | 17.1–17.5 |
| **⭐ Visual Diff on Deal Confirmation** | None. | Visual Diff Screen displaying green/red highlight of changes compared to previous Deal Version. | **`[Missing]`** | 18.2 |
| **Seller Final Deal Confirmation** | Deal is created directly upon Buyer quote acceptance in `acceptQuotationAction`. | Mandatory Seller Confirmation state before deal can be finalized by Broker. | **`[Missing]`** | 18.1, 18.3 |
| **Broker Finalization ➔ Idempotent Booking** | Quotation acceptance directly inserts a `deals` row. | Distinct 2-step state progression: Broker Finalization Gate ➔ Idempotent Booking Creation with unique `Booking ID`. | **`[Missing]`** | 18.4, 18.5 |
| **Seller Dispatch Workflow** | `SellerDispatchForm` captures Vehicle No, Driver Name, Mobile, Date, ETA. Updates status to `'In Transit'`. | Enforce Booked Order prerequisite, partial shipment support, driver validation, and LR upload. | **`[Needs hardening]`** | 19.1, 19.2, 19.3 |
| **Fulfilment Documents** | `invoices` table and `createInvoiceAction`. | Secure multi-document manager (Tax Invoice, E-Way Bill, Lorry Receipt, Weighbridge Slip). | **`[Needs hardening]`** | 19.3 |
| **Payments & Settlement View** | `payments` table and `confirmPaymentAction`. | Detailed Seller settlement breakdown: Total Value, Advance Received, Pending Settlement, Overdue alerts, Dispute records. | **`[Needs hardening]`** | 19.4 |
| **Notifications & Action Center** | Multi-channel notification engine (Sprint 12) with in-app bell. | Seller event catalog mapping (19 distinct events including Quick Renew, Loading Delay, Deal Request, Confirmation Required). | **`[Needs hardening]`** | 20.1 |
| **Seller Reports & Analytics** | `getSellerKpisAction` computes Active Inventory, Pending Dispatches, Total Revenue. | Filterable operational reports: Inventory Aging, Dispatch Performance, Quality Pass Rates, Fulfillment Ratios. | **`[Needs hardening]`** | 20.2 |
| **Security & Privacy Isolation** | RLS on companies; server action company validation. | Total scrubbing of Buyer contact details from all Seller endpoints, payloads, and queries. Confidential min price masking. | **`[Needs hardening]`** | 20.3 |

---

## 4. Conflicting Legacy Flows & Migration Requirements

The audit identified three specific legacy implementation patterns from Sprints 1–12 that conflict with the Seller PRD v3.0 rules and must be migrated:

### 4.1 Direct Synchronous WhatsApp Dispatch in Quotation Action
- **Conflicting Code:** `src/server/actions/quotation-actions.ts` (lines 42, 171, and 238–251)
  ```typescript
  // Inside createQuotationAction and reviseQuotationAction:
  await sendQuotationAction(inserted[0].id);
  
  // Inside sendQuotationAction:
  const dispatchResult = await sendQuotationWhatsAppNotification({
    recipientPhone: buyerUser.mobile!,
    quotationId: quotationId,
    ...
  });
  ```
- **Conflict with Rule:** 
  > *"WhatsApp is permanently removed from quotation, negotiation, confirmation, finalization, and Booking state transitions. WhatsApp is notification-only and must be routed asynchronously through the unified notification dispatcher (`notifications` queue), never triggered directly inside transactional actions."*
- **Migration Plan:** 
  - Remove direct synchronous calls to `sendQuotationWhatsAppNotification`.
  - In state transition actions, insert an event row into the `notifications` table with `channel: 'WHATSAPP'` and `delivery_status: 'Pending'`. The atomic cron dispatcher (`/api/cron/process-notifications`) will pick up and dispatch messages with retry safety without blocking server actions.

### 4.2 Immediate Deal Creation on Single Buyer Acceptance
- **Conflicting Code:** `src/server/actions/deal-actions.ts` (`acceptQuotationAction`, lines 29–110)
  ```typescript
  // Currently: Buyer calls acceptQuotationAction -> immediately creates row in deals table
  const dealInsert = await tx.insert(deals).values({
    requirementId: requirement.id,
    quotationId: quotation.id,
    buyerId: requirement.companyId,
    sellerId: availability.companyId,
    status: 'Dispatch Pending',
    ...
  });
  ```
- **Conflict with Rule:** 
  > *"Seller Final Deal Confirmation is a mandatory transaction state — not an optional button. Broker Finalization and Booking creation are separate. Successful finalization causes the system to create the unique Booking ID. Confirmation ≠ Booking."*
- **Migration Plan (Sprint 18):**
  - Refactor `acceptQuotationAction` to transition the proposal to `Pending Seller Final Confirmation`.
  - Introduce the mandatory Seller review and confirmation action (`confirmFinalDealAction`).
  - Introduce the Broker Finalization action (`finalizeDealByBrokerAction`) which atomically checks both Buyer and Seller confirmations before issuing an immutable `Booking ID` and creating the booked deal.

### 4.3 Buyer Company Data Exposure in Seller Deal Queries
- **Conflicting Code:** `src/server/actions/deal-actions.ts` (`getDealsByCompanyAction`, lines 218–242)
  ```typescript
  // Currently: Left joins and returns buyerCompany object in all queries
  const companyDeals = await db
    .select({
      deal: deals,
      requirement: requirements,
      commodity: masterCommodities,
      grade: masterGrades,
      buyerCompany: { id: buyerCompanyTable.id, name: buyerCompanyTable.name, ... },
      sellerCompany: { id: sellerCompanyTable.id, name: sellerCompanyTable.name, ... }
    })
  ```
- **Conflict with Rule:** 
  > *"No direct Buyer contact, Buyer directory, Buyer phone/email/WhatsApp, or direct communication path. No Buyer details exposed to Seller at any layer (UI, API, database, documents, notifications)."*
- **Migration Plan (Sprint 13.4):**
  - Implement a dedicated `getSellerDealsAction` (or sanitize `getDealsByCompanyAction` based on caller role) that masks `buyerCompany` details to an anonymized identifier (e.g., `"Verified Buyer #B-8832"`) so Buyer private identity never enters the Seller client payload.

---

## 5. Non-Redesign Confirmation Checklist

To ensure documentation integrity and prevent unnecessary rework, this audit formally verifies that all completed foundational elements from Sprints 1–12 are sound and **must NOT be redesigned**:

- [x] **Authentication & Role Infrastructure (Sprints 1–2):** Supabase Auth OTP, session cookies, and Next.js middleware role routing are completely functional.
- [x] **Master Data System (Sprint 3):** PostgreSQL normalized tables for States, Districts, Industries, Categories, Commodities, Grades, Units, Packaging, and Vehicles are complete and active.
- [x] **Company Onboarding & Verification Pipeline (Sprint 4):** Company profile creation, GST validation, and Admin approval workflow are fully established.
- [x] **AI Match Rule Engine (Sprint 7):** Deterministic weighted scoring algorithm (`match-engine.ts`) with explainability breakdown operates correctly for Broker recommendation.
- [x] **Logistics & Secure File Storage (Sprint 10):** Supabase Storage bucket `brokerbridge_documents` with RLS policies and dispatch tracking schema is functional.
- [x] **Dispute Resolution & Payment Tracking (Sprint 11):** Payment confirmation schema and Tier 0 Admin dispute override state machine are functional.
- [x] **Unified Notification Dispatcher (Sprint 12):** Atomic queue polling via `FOR UPDATE SKIP LOCKED`, exponential backoff retries, and `/api/cron/process-notifications` route handler are fully implemented.
- [x] **Partial Fulfillment Math (Sprint 12):** Fractional requirement fulfillment calculations (`fulfilledQuantity`, multi-deal allocation) are verified and operational.

---

## 6. Conclusion & Next Steps

The existing codebase foundation (Sprints 1–12) is exceptionally solid. The Seller workspace is ready to advance to **Micro-Sprint 13.2: Seller Workspace Shell & Navigation**.

### Immediate Implementation Roadmap:
1. **Micro-Sprint 13.2:** Build the unified Seller application shell, responsive navigation, and role-aware navigation bar.
2. **Micro-Sprint 13.3:** Implement the P0 Action Required Command Center dashboard widgets.
3. **Micro-Sprint 13.4:** Harden Seller authorization, apply Buyer privacy masking to all Seller payloads, and audit confidential price boundaries.
4. **Micro-Sprint 13.5:** Establish shared resilience, offline queue, and error boundary baseline.

---
*Report generated and archived for Lead Architect review.*
