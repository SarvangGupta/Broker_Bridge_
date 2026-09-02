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

