# Micro-Sprint 31.1: Existing Buyer Foundation Audit Report
**BrokerBridge Enterprise — Buyer Module Scope**  
**Audit Date:** October 2026  
**Auditor:** Antigravity AI Pair Programmer & System Architect  
**Document Status:** Complete & Implementation-Ready  
**Sprint Phase:** Sprint 31 — Buyer Foundation & Access Audit  

---

## 1. Executive Summary & Audit Scope

Before commencing feature development for the **Buyer Workspace Shell and Sprint 31–40 Capabilities**, a comprehensive **read-only codebase audit** was performed across the BrokerBridge Enterprise repository.

The primary objectives of this audit are to:
1. **Regression-Protect Existing Assets:** Verify that all core capabilities established in Sprints 1–5 (Auth, Organization Isolation, Cascading Master Data, Requirement Engine, and Offline Sync Queue) remain stable and are protected against accidental refactoring.
2. **Audit Buyer Architecture:** Inspect existing Buyer routes (`/app/(buyer)/...`), Server Actions (`requirement-actions.ts`, `quotation-actions.ts`, `deal-actions.ts`, `analytics-actions.ts`), schema definitions (`schema.ts`), and PostgreSQL RLS policies (`manual_rls_companies.sql`).
3. **Verify Data Isolation (RLS):** Confirm that Row Level Security policies and Server Action query boundaries strictly isolate Buyer organization data from other companies and prevent cross-tenant data leaks.
4. **Confirm Requirement Form & Offline Engine:** Verify that the mobile-optimized `RequirementForm` and IndexedDB service worker queue built in Sprint 5 are present and ready to be extended (not rebuilt).
5. **Establish the Baseline Gap Analysis:** Categorize every subsystem as **`[Intact]`**, **`[Needs hardening]`**, or **`[Missing]`** to guide micro-sprints 31.2 through 40.5.

---

## 2. Architectural Audit of Buyer Subsystems

### 2.1 Routes & App Shell
- **Path:** `app/(buyer)/buyer/page.tsx`
  - **Current Implementation:** Renders the Buyer Hub page. Performs server-side session checks via Supabase SSR client. Retrieves company profile, user details, and buyer KPIs via `Promise.all([getCompanyProfile(), getFullBuyerProfileDetailsAction(), getBuyerKpisAction()])`.
  - **Onboarding Gate:** If no company is linked to the user, renders `CompanyOnboardingForm`. Once onboarded, renders header shell with `NotificationBell`, `BuyerHeaderDropdown`, 3 KPI overview cards (`Active Requirements`, `Booked Deals`, `Total Value Spent`), and a 3-tab trigger system (`Requirements`, `Offers`, `Deals`).
  - **Child Components:**
    - `src/components/dashboard/my-requirements-table.tsx` — Displays buyer requirements, status badges, and actions.
    - `src/components/dashboard/buyer-quotations-list.tsx` — Displays broker proposals with Accept/Counter/Reject actions.
    - `src/components/dashboard/buyer-deals-table.tsx` — Displays confirmed deals.
    - `src/components/dialogs/post-requirement-dialog.tsx` — Modal container for `RequirementForm`.
    - `src/components/dashboard/buyer-header-dropdown.tsx` — Header dropdown with dual-workspace toggle (`/seller`), profile info, and sign out.
- **Middleware Guard:** `middleware.ts` & `lib/supabase/middleware.ts`
  - Enforces HTTP-only secure cookie sessions.
  - Validates role permissions (`role.includes('buyer')` or `role.includes('seller')`).
  - Allows verified dual-workspace trader switching between `/buyer` and `/seller`.

### 2.2 Buyer Server Actions (`src/server/actions/`)
| Server Action File | Primary Functions | Role / Security Boundary | Status |
| :--- | :--- | :--- | :--- |
| `src/server/actions/requirement-actions.ts` | `createRequirementAction`, `getMyRequirementsAction`, `cancelRequirementAction` | Authenticated + User's `companyId` filter | **`[Intact]`** (Needs quality parameter expansion in 34.2) |
| `src/server/actions/quotation-actions.ts` | `getBuyerQuotationsAction`, `getQuotationsByRequirementAction`, `reviseQuotationAction` | Authenticated + Requirement's `companyId` check | **`[Intact]`** (Needs proposal versioning UI in 35.3) |
| `src/server/actions/deal-actions.ts` | `acceptQuotationAction`, `rejectQuotationAction`, `counterQuotationAction`, `getDealsByCompanyAction` | Authenticated + Buyer/Seller `companyId` check | **`[Intact]`** (Needs final confirmation gate in 37.1) |
| `src/server/actions/analytics-actions.ts` | `getBuyerKpisAction` | Authenticated + Buyer `companyId` SQL aggregation | **`[Intact]`** (Production-ready aggregations) |
| `src/server/actions/company-actions.ts` | `getCompanyProfile`, `createCompanyProfile` | Authenticated user ID | **`[Intact]`** |
| `src/server/actions/user-profile-actions.ts` | `getFullBuyerProfileDetailsAction` | Authenticated user ID | **`[Intact]`** |

### 2.3 Database Entities & Schema (`src/server/db/schema.ts`)
- **`companies`**: `id`, `name`, `gst`, `businessTypeId`, `stateId`, `districtId`, `status`, `isVerified`, `trustScore`.
- **`users`**: `id`, `name`, `mobile`, `email`, `role`, `status`, `companyId`, `createdAt`.
- **`requirements`**: `id`, `companyId`, `commodityId`, `gradeId`, `quantity`, `fulfilledQuantity`, `unitId`, `targetPrice`, `deliveryTermsId`, `targetDate`, `visibility`, `status`, `brokerId`, `createdAt`.
- **`quotations`**: `id`, `requirementId`, `brokerId`, `sellerAvailabilityId`, `offeredPrice`, `status`, `validUntil`, `createdAt`, `rejectionReason`, `counterPrice`, `counterNotes`.
- **`deals`**: `id`, `requirementId`, `quotationId`, `buyerId`, `sellerId`, `brokerId`, `agreedPrice`, `agreedQuantity`, `status`, `createdAt`, `closedAt`.
- **`bookings`**: `id`, `dealId`, `bookingNumber`, `buyerId`, `sellerId`, `brokerId`, `agreedPrice`, `agreedQuantity`, `status`, `createdAt`.
- **Master Tables**: `masterStates`, `masterDistricts`, `masterIndustries`, `masterCategories`, `masterCommodities`, `masterGrades`, `masterUnits`, `masterBusinessTypes`.

### 2.4 Row Level Security (RLS) & Storage
- **Company RLS Policy:** `supabase/migrations/manual_rls_companies.sql` enables RLS on `companies`. SELECT/UPDATE policies restrict access using `id IN (SELECT company_id FROM users WHERE id = auth.uid())`.
- **Server Actions Guard:** All Drizzle ORM database queries resolve the authenticated user's `companyId` first and append `eq(requirements.companyId, companyId)` or `eq(deals.buyerId, companyId)` to prevent cross-tenant data exposure.

### 2.5 Mobile Offline-Queue Engine (`src/lib/offline-queue.ts`)
- **Storage Layer:** Uses `idb` library to maintain IndexedDB database `BrokerBridgeDB` with object store `offlineRequirements`.
- **Form Integration:** `src/components/forms/requirement-form.tsx` checks `navigator.onLine`. If offline, stores raw payload locally via `saveRequirementOffline(data)` and alerts user.
- **Auto-Sync:** Subscribes to `window.addEventListener("online", syncOfflineData)` to automatically push saved requirements to `/api/v1/requirements/sync` when connectivity restores.

---

## 3. Strict Verification Checks

### 3.1 Row Level Security & Organization Data Isolation Check
- [x] **PostgreSQL RLS Active:** `companies` table has RLS enabled via `manual_rls_companies.sql`.
- [x] **Auth UID Scoping:** RLS subquery evaluates `WHERE users.id = auth.uid()` to map user session to company record.
- [x] **Server Action Scoping:** `getMyRequirementsAction()`, `getBuyerQuotationsAction()`, and `getBuyerKpisAction()` explicitly enforce `eq(companyId, userCompanyId)`.
- [x] **Seller Privacy Protection:** `getDealsByCompanyAction()` anonymizes Buyer PII for Seller view (`Verified Buyer #B-XXXX`), ensuring Buyer identity cannot be harvested.

### 3.2 Mobile-Optimized Requirement Form Verification Checklist
- [x] **Cascading Select Architecture:** 4-stage cascading selection active (`Industry` ➔ `Category` ➔ `Commodity` ➔ `Quality Parameter / Grade`).
- [x] **Zod Validation:** `requirementSchema` validates numeric `quantity`, `target_price`, `unit_id`, `delivery_terms_id`, and `target_date`.
- [x] **360px Touch Targets:** Inputs and combobox triggers styled with `min-h-[48px]` for mobile usability.
- [x] **IndexedDB Offline Storage:** `saveRequirementOffline` stores offline submissions in `BrokerBridgeDB`.
- [x] **Auto-Sync Listener:** Online event handler present and ready to be extended for new quality criteria fields in Sprint 34.

---

## 4. Foundation Mapping & Categorized Gap Analysis

| Subsystem / Feature Area | Existing Implementation in Codebase | Buyer PRD v1.2 / Sprint Plan Requirement | Classification | Target Sprint |
| :--- | :--- | :--- | :--- | :--- |
| **Authentication & Role Access** | Supabase Auth, `middleware.ts` role checks, trader dropdown in `buyer-header-dropdown.tsx`. | Enforce single `BUYER_ADMIN` role; isolate organization workspace. | **`[Intact]`** | 31.2, 31.3 |
| **Buyer Profile & KYC** | `CompanyOnboardingForm` and `company-actions.ts`. | Complete Buyer profile, address/delivery location master, and KYC verification foundation. | **`[Intact]`** | 31.4 |
| **Buyer Shell & Mobile Navigation** | Basic top nav + 3 tabs in `app/(buyer)/buyer/page.tsx`. | Mobile-first shell with 360px reflow, bottom navigation bar, and final 10-item menu drawer. | **`[Needs hardening]`** | 32.1, 32.2 |
| **Action Required Dashboard** | 3 top KPI cards on Buyer Hub. | Priority Action Required widget (pending proposals, negotiation turns, deal confirmations, dispatches, payments). | **`[Needs hardening]`** | 32.3, 32.4 |
| **Requirement Management** | `RequirementForm` and `my-requirements-table.tsx`. | Comprehensive requirement list, status filter cards, edit/cancel actions, and detail drawer. | **`[Intact]`** | 33.1–33.5 |
| **Dynamic Quality Criteria** | Basic `grade_id` selector. | Commodity-specific quality criteria parameters (Moisture, Admixture, Protein, Oil) and COA document upload. | **`[Needs hardening]`** | 34.1–34.5 |
| **Broker Proposals Workspace** | `BuyerQuotationsList` component. | Dedicated Broker Proposals inbox, structured proposal cards, fee/tax breakdown, and 1-tap Accept/Reject/Counter. | **`[Needs hardening]`** | 35.1–35.5 |
| **Buyer ↔ Broker Negotiation** | Basic counter price field on quotation. | Dedicated Buyer-Broker negotiation channel, versioned event timeline, and counter proposal builder. | **`[Missing]`** | 36.1–36.5 |
| **Final Deal & Confirmation** | `acceptQuotationAction` directly creates deal. | Immutable Deal Version snapshot, Visual Diff comparison screen, and mandatory Buyer Final Confirmation gate. | **`[Missing]`** | 37.1–37.5 |
| **Orders, Booking & Logistics** | `BuyerDealsTable` displays confirmed deals. | Booking ID tracking, live multi-stage dispatch tracker, driver details, and delivery completion sign-off. | **`[Needs hardening]`** | 38.1–38.5 |
| **Quality, Documents, Payments & Disputes** | Basic transaction dispute endpoint. | Operational document vault (COA, Tax Invoice, LR), Buyer payment ledger (Paid/Outstanding/Overdue), and Dispute tracker. | **`[Missing]`** | 39.1–39.5 |
| **Notifications, Security & UAT** | Basic `NotificationBell` component. | Notification queue integration with deep-linking, low-bandwidth optimization, and E2E UAT sign-off. | **`[Missing]`** | 40.1–40.5 |

---

## 5. Architectural Recommendations for Micro-Sprint 31.2

1. **Keep Requirement Engine Intact:** Extend `src/components/forms/requirement-form.tsx` without rewriting the cascading dropdowns or IndexedDB offline sync engine.
2. **Harden Routing Guards:** Verify in Micro-Sprint 31.2 that `BUYER_ADMIN` users without a company profile are strictly routed to `/buyer` onboarding and cannot access `/seller` routes until verified.
3. **Prepare Navigation Architecture:** In Sprint 32, transform the single-page tab layout into a responsive navigation drawer supporting the locked 10-item Buyer taxonomy (Dashboard, Requirements, Proposals, Negotiations, Orders, Quality & Documents, Payments, Disputes, Notifications, Profile).

---
**Audit Report Sign-off:** Approved for Micro-Sprint 31.2 execution.
