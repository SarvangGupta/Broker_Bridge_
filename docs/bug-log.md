# BrokerBridge Bug & Resolution Log

This document tracks UI/UX anomalies, architectural logic bugs, and their eventual resolutions to ensure institutional knowledge is preserved and regressions are avoided.

## Sprint 14.5 - Active Inventory Edit Button Omission
- **Issue:** On the Seller Inventory Dashboard, the cards for `Active` and `Open` inventory lots initially only exposed a "Cancel Listing" action. Sellers had no physical button to click to trigger an "Edit" or update flow.
- **Root Cause:** In the initial sprint UI pass, the `inventory-card.tsx` (and `my-availabilities-table.tsx`) components only mapped the `cancelAvailabilityAction`. The necessity of standard updates (price adjustments) and concurrency testing required an explicit Edit flow.
- **Resolution:** 
  1. Injected an "Edit Listing" button alongside the "Cancel" button, gated to only show for `Active` or `Open` statuses. 
  2. Directed the Edit button to open the `post-availability-dialog.tsx` with an `?edit=[id]` URL parameter.
  3. Encountered multiple secondary bugs:
     - Frontend validation silently failed because the hidden `version` integer field defaulted to a string; resolved by enforcing `{ valueAsNumber: true }` in `react-hook-form`.
     - The backend action `updateAvailabilityAction` mapped frontend keys (e.g. `total_quantity`) to Drizzle without transforming them to camelCase, resolved by standardizing Drizzle `set` mapping.
     - The `id` and `version` scoping references were briefly lost from the `WHERE` clause during the mapping refactor.
     - The `getAvailabilityForEditAction` server action was originally created but omitted from export.
  4. Fully restored the Edit state, keeping all master data cascading dropdowns unlocked so the Seller can fluidly modify the entire supply contract.

## Sprint 15.2 - Post Availability Submission Failures & Dynamic Quality Engine Alignment

### 1. Silent Form Submission Failure (Post Availability Button Unresponsive)
- **Issue:** When sellers filled out the "Post Availability" modal and clicked the "Post Availability" button, nothing happened. No network request was dispatched, the modal did not close, and the console logged `AvailabilityForm validation errors: {}` without user feedback.
- **Root Causes:**
  1. **Rogue Hidden Inputs:** Hidden `<input type="hidden" name="id" />` and `<input type="hidden" name="version" />` were registered in the form DOM, injecting `""` (empty string) into UUID fields and `NaN` into number fields during create mode, failing Zod schema parsing.
  2. **Unsanitized Select Values:** The Preferred Broker dropdown used value `"none"` for the "No Preferred Broker" option, which failed the `z.string().uuid()` validation on `broker_id`.
  3. **Empty String to Number Coercion:** Empty/cleared numeric fields (`total_quantity`, `asking_price`, `minimum_order_quantity`, `confidential_minimum_price`) submitted `""` rather than `undefined`/`null`, failing standard Zod number schemas.
  4. **Uninitialized Validity Date:** `valid_until` was not initialized with a default date, causing schema rejection if the date picker was untouched.
  5. **Silent Rejection in `onInvalid`:** `react-hook-form`'s `onInvalid` handler was only logging to `console.error` and failed to display toast notifications when errors had non-standard keys.
- **Resolution:**
  1. Wrapped all optional, UUID, and numeric fields in `src/types/availability-schema.ts` with `z.preprocess` to sanitize empty strings (`""`), `"none"`, `null`, and `NaN` into appropriate types.
  2. Removed the hidden `<input type="hidden">` tags from `availability-form.tsx`.
  3. Initialized `valid_until` default value to 7 days in the future.
  4. Enhanced `onInvalid` in `availability-form.tsx` to run `availabilitySchema.safeParse` directly and toast exact, human-readable field errors to the user.

---

### 2. PRD Conflict: Legacy Quality Parameter Dropdown vs. Dynamic Quality Engine
- **Issue:** The Availability Form in Section 1 ("Product Details") presented a standalone "Quality Parameter" dropdown mapped to `master_grades`. This violated Seller PRD v3.0 (Section 8), which mandates that selecting a Commodity must automatically generate all required dynamic laboratory parameters (e.g., Moisture %, Foreign Matter) in Section 2 rather than forcing the user to select an arbitrary grade.
- **Root Causes:**
  1. The database table `availabilities` enforced a strict foreign key `grade_id NOT NULL REFERENCES master_grades.id`, which had historically been exposed directly to the seller as a required dropdown.
  2. The Dynamic Quality Engine (`<DynamicQualityFields />`) was not automatically receiving the active `commodity_id` prop to fetch and render commodity-specific specification inputs.
- **Resolution:**
  1. Removed the standalone "Quality Parameter" dropdown completely from Section 1 in `src/components/forms/availability-form.tsx`.
  2. Reorganized Section 1 into a clean 2-column layout: Row 1 is Industry + Category, Row 2 is Commodity + Lot/Batch Number.
  3. Updated `src/components/forms/dynamic-quality-fields.tsx` to accept `commodityId`, fetch parameter templates via `getQualityTemplateByCommodityAction`, and dynamically render responsive input fields with tolerance hints (e.g. *Max allowed: 14%*).
  4. Updated `createAvailabilityAction` and `updateAvailabilityAction` in `src/server/actions/availability-actions.ts` to automatically resolve `effectiveGradeId` from matching `masterGrades` in PostgreSQL, fulfilling DB foreign key constraints without requiring seller manual input.

---

### 3. Active vs. Open Inventory Visibility in Seller Command Center
- **Issue:** Newly posted lots created with status `'Active'` did not appear in the Open Inventory table or the KPI summary ribbon on the Seller Command Center.
- **Root Cause:** Analytics actions (`getSellerStatsAction`, `getSellerCommandCenterDataAction`) and the AI match engine were querying only `eq(availabilities.status, 'Open')`, omitting modern lots marked as `'Active'`.
- **Resolution:** Updated all inventory count, KPI, and match engine queries across `src/server/actions/analytics-actions.ts` and `src/server/utils/match-engine.ts` to filter with `inArray(availabilities.status, ['Active', 'Open'])`.

---

## Sprint 15.4 - Lab Evidence Storage Bucket & RLS Policy Enforcement
- **Issue:** When uploading PDF/Image COA certificates via `<LabDocumentUpload />`, the client received error `Lab evidence upload failed: new row violates row-level security policy`.
- **Root Cause:** In Supabase Storage, the `storage.objects` table enforces Row-Level Security by default. The dedicated private bucket `brokerbridge_lab_evidence` and its corresponding `INSERT`, `UPDATE`, and `SELECT` RLS policies written in `supabase/migrations/manual_lab_storage_rls.sql` had not yet been executed on the live PostgreSQL instance.
- **Resolution:**
  1. Created the `brokerbridge_lab_evidence` private storage bucket.
  2. Applied the `INSERT` RLS policy on `storage.objects` for `authenticated` users uploading with path format `{availability_id}/{filename}`.
  3. Applied the `SELECT` policy restricting download/view access exclusively to Admin/Broker roles and the lot-owning Seller company.

---

## Sprint 16.4 - Notification Action URL Schema & Instant Dev Refresh
- **Issue:** 
  1. Terminal logged `PostgresError: column "action_url" does not exist` during notification queries (`getInAppNotificationsAction`).
  2. Clicking "Generate Test Broker Request" did not update the header notification bell unread counter instantly.
- **Root Causes:**
  1. The Drizzle schema was updated with `actionUrl: text('action_url')`, but the generated migration file `0025_add_notification_action_url.sql` had not yet been executed on the live Supabase PostgreSQL database.
  2. The frontend Notification Bell was polling on a 15-second interval and did not receive immediate cache invalidation upon mock request generation.
- **Resolution:**
  1. Applied `ALTER TABLE "notifications" ADD COLUMN IF NOT EXISTS "action_url" text;` directly to PostgreSQL.
  2. Updated `createMockBrokerRequestAction` in `src/server/actions/broker-request-actions.ts` to explicitly queue the notification with `action_url` and invoke `revalidatePath('/', 'layout')`.
  3. Injected `queryClient.invalidateQueries({ queryKey: ['in-app-notifications'] })` into `handleGenerateMock` in `src/components/dashboard/broker-request-inbox.tsx` to instantly re-fetch and increment the unread badge in the header.

---

## Sprint 17.5 - Deal Version Supersession Engine & Initial Snapshot Seeder

- **Issue:** When a Seller submitted a counter-offer via the Broker Request Inbox, the system failed to create a new incremental row (`Version 2`) in `deal_versions` and failed to mark `Version 1` as `'Superseded'`. The negotiation timeline consequently displayed only a single version or failed to reflect the back-and-forth immutable audit trail.
- **Root Causes:**
  1. **Dev Seeder Snapshot Omission:** `createMockBrokerRequestAction` in `src/server/actions/broker-request-actions.ts` inserted rows into the parent `quotations` table but omitted inserting the initial baseline `Version 1` snapshot (`status: 'Proposed'`) into `deal_versions`.
  2. **Zero-Row Version Lookup:** When countering a request that had no prior `deal_versions` record, `existingVersions` returned empty (`[]`), causing `highestVersion` to evaluate to `null` and defaulting `nextVersionNumber` to `1` without marking any record as `Superseded`.
  3. **Strict Material Diff vs. Counter Action:** `createDealVersionInTransaction` evaluated `detectMaterialChanges` strictly against numeric and date fields. If a counter-offer maintained identical price/quantity terms but provided commercial counter remarks or changed originator roles (`broker` -> `seller`), the version engine concluded that no material changes occurred and exited early without incrementing the version.
- **Resolution:**
  1. **Fixed Dev & AI Match Seeders:** Updated `createMockBrokerRequestAction` and `initiateBrokerRequestFromAiMatchAction` in `src/server/actions/broker-request-actions.ts` to immediately insert the initial `Version 1` record (`status: 'Proposed'`) with frozen commodity, lot, quantity, rate, and delivery terms snapshots into `deal_versions`.
  2. **Legacy / Unversioned Request Fallback:** Enhanced `createDealVersionInTransaction` in `src/server/actions/version-actions.ts` to automatically query the parent `quotation` and synthesize `Version 1` (`status: 'Superseded'`) on the fly if an unversioned proposal is countered.
  3. **Counter & State Transition Handling:** Enhanced the change detection condition in `createDealVersionInTransaction` so that whenever `status === 'Countered'`, or an originator role change (`broker` to `seller`) or status change occurs, a new immutable row with `version_number: previous + 1` and `status: 'Countered'` is guaranteed to be created, and the previous version is atomically updated to `'Superseded'`.
  4. **Optimistic Stale-Version Protection:** Passed `expectedVersionNumber` through `respondToBrokerRequestAction` into `createDealVersionInTransaction` to enforce concurrency protection against stale proposals.

---

## Sprint 18.1/18.5 - Smart Back Navigation & Hierarchical Route Resolution

- **Issue:** Navigating back from the Deal Confirmation Snapshot (`/seller/deals/[id]/confirm`) or Deal Detail View (`/seller/deals/[id]`) using static `<Link href="/seller/deals">` caused user disorientation or routing loops when users arrived via deep links from the Command Center (`/seller`), Broker Request Inbox (`/seller/requests`), or Notification Bell links.
- **Root Cause:** Hardcoded static parent paths ignored previous navigation context and broke browser history continuity, forcing users into the general Deals table rather than returning them to their origin workflow (e.g. Inbox tab or Notification deep-link source).
- **Resolution:**
  1. Implemented "Smart Back Navigation" using Next.js `useRouter()` and `router.back()` with fallback routing to preserve context.
  2. Preserved deep-link query parameters (`?requestId=...`) and active tab states across navigation boundaries.
  3. Ensured breadcrumbs and header back buttons dynamically honor the referrer context, eliminating routing loops between the Dashboard, Requests Inbox, and Confirmation views.

---

## Sprint 19 - Dispatch, Documents & Settlement Bug Resolutions

### 1. PostgreSQL UUID vs. Booking Reference Polymorphic Lookup Bug (Sprint 19.1/19.5)
- **Issue:** Navigating to `/seller/dispatch/[bookingId]` or querying dispatch/booking details using human-readable booking references (e.g. `BKG-2026-XHNG`) threw `PostgresError: invalid input syntax for type uuid: "BKG-2026-XHNG"`.
- **Root Cause:** Drizzle queries directly executed `eq(bookings.id, rawBookingId)` on strings without validating whether the input string was a standard UUID or a formatted reference code (`"BKG-2026-XXXX"`).
- **Resolution:**
  1. Implemented polymorphic lookup utilities using `isUuid` regex (`/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i`).
  2. Queries first check `bookings.bookingReference = rawBookingId.toUpperCase()`, falling back to `bookings.id` or `bookings.dealId` lookups only if the input matches UUID formatting.

---

### 2. "Zombie" Dispatch Button on Fully Dispatched Bookings (Sprint 19.1/19.2)
- **Issue:** When a booking was 100% fulfilled (`remaining_quantity <= 0`), the "Initiate Dispatch" button remained clickable on the Booked Orders table, permitting sellers to attempt dispatching zero or negative quantities.
- **Root Cause:** UI action render conditions evaluated parent deal status rather than dynamic `remainingQuantity <= 0` balance.
- **Resolution:**
  1. Gated `<BookedOrdersTable />` to render a neutral "View Shipments & Documents" action when `remainingQuantity <= 0 || isFullyDispatched || bookingStatus === 'Fully Dispatched'`.
  2. Added an authoritative green completion banner on `/seller/dispatch/[bookingId]` ("This Booking Has Been Fully Dispatched") and hid the dispatch submission form once 100% fulfilled.

---

### 3. `ALLOWED_DOCUMENT_TYPES.map is not a function` Runtime Crash (Sprint 19.3)
- **Issue:** Mounting the `<FulfillmentDocumentUpload />` component triggered an unhandled React TypeError: `ALLOWED_DOCUMENT_TYPES.map is not a function`.
- **Root Cause:** `ALLOWED_DOCUMENT_TYPES` had been exported as an object mapping (`{ LR: '...', INVOICE: '...' }`) rather than an iterable array in `src/types/dispatch-schema.ts`.
- **Resolution:** Standardized `ALLOWED_DOCUMENT_TYPES` as a typed array `["LR", "Invoice", "E-Way Bill", "Weighment Slip", "Loading Photo"]` with defensive array fallbacks.

---

### 4. Supabase Storage RLS Violation on Document Upload (Sprint 19.3/19.5)
- **Issue:** Uploading a PDF or image of a Lorry Receipt (LR) or Weighbridge Slip failed with `Fulfillment document upload failed after 3 attempts: new row violates row-level security policy`.
- **Root Cause:** The browser-side `createClient()` Supabase client attempted direct uploads to the `brokerbridge_documents` storage bucket. However, auth tokens are stored in `httpOnly` secure cookies by `@supabase/ssr` to prevent XSS theft, so browser requests lacked ambient JWT auth headers, violating PostgreSQL RLS policies for `authenticated` users.
- **Resolution:**
  1. Created `uploadFulfillmentDocumentAction` as a Next.js Server Action (`'use server'`) in `src/server/actions/document-actions.ts`.
  2. The action authenticates the seller session server-side via `verifySellerSession()`, parses the file buffer, streams it to Supabase Storage via the server client with active session credentials, and inserts the document metadata into `dispatch_documents` atomically.

---

### 5. Disjointed Dispatch-to-Document Workflow (Sprint 19.2/19.3 UX)
- **Issue:** After creating a dispatch record via `<SellerDispatchForm>`, the modal immediately closed, requiring the seller to manually locate the order in a nested table to attach Lorry Receipts (LR/Bilty).
- **Root Cause:** `<SellerDispatchForm>` lacked a post-submission step state.
- **Resolution:**
  1. Added `createdDispatchId` local state in `seller-dispatch-form.tsx`.
  2. Upon successful creation, the form dynamically transitions in-place to the "Upload Fulfillment Documents" step with vehicle registration highlights, allowing immediate LR/Invoice upload or 1-click "Skip & Upload Later".

---

### 6. Multi-Shipment Quantity Ambiguity in Partial Fulfillment Views (Sprint 19.2/19.5)
- **Issue:** When a booking was fulfilled across multiple partial shipments (e.g. 50 MT total split into Truck 1: 36 MT and Truck 2: 14 MT), the page rendered duplicate telemetry cards and two identical upload vaults without indicating which truck/quantity each vault was for.
- **Root Cause:** `getDispatchTrackingAction` defaulted each shipment card to `totalBookedQuantity` (50 MT) without querying the `negotiation_events` ledger for specific truck payloads.
- **Resolution:**
  1. Enhanced `getDispatchTrackingAction` to pull `DISPATCH_SUBMITTED` events from `negotiation_events`, computing `shipmentNumber`, `totalShipments`, `isPartial`, and exact `dispatchQuantity`.
  2. Upgraded `<LogisticsTracker />` and the dispatch page to display "Shipment X of Y (36 MT Partial Load vs 14 MT Final Load)" badges and truck-scoped document upload vaults.



