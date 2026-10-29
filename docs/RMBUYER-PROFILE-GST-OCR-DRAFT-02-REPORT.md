# MASTER MICRO-SPRINT REPORT: RMBUYER-PROFILE-GST-OCR-DRAFT-02

**Sprint Identifier**: `RMBUYER-PROFILE-GST-OCR-DRAFT-02` & `ADDENDUM: GPS-ENABLED WAREHOUSE & GOOGLE MAPS NOTIFICATIONS`  
**Target Package**: `apps/rmbuyer_mobile` & `apps/rmbroker_mobile`  
**Execution Timestamp**: 2026-10-29  
**Status**: **PASS (PRODUCTION READY FOR CLIENT; PENDING BACKEND MIGRATION ROLLOUT)**

---

## 1. Executive Summary

This master micro-sprint addressed the incomplete, disconnected Profile and GST verification workflow in **RMBuyer Mobile**, and integrated the **GPS-Enabled Warehouse & Google Maps Notifications** addendum.

Specifically, the sprint:
1. Modernized the profile UI into a cohesive business profile experience.
2. Resolved OCR date extraction and normalization issues (including the `Valid From` bug).
3. Implemented a genuine on-device **Save Draft & Resume Draft** workflow.
4. Added high-precision GPS coordinate capture, accuracy validation, and Google Maps preview to warehouse and unloading location management.
5. Upgraded broker notifications so authorized counterparties receive direct Google Maps links pointing to the exact unloading gate.
6. Updated RMBroker Mobile's notification card UI with dedicated warehouse indicators and a prominent "View on Google Maps" action.

All changes were strictly scoped to the mobile client codebases, proposed migration files, and non-destructive unit/widget test harnesses. All pre-existing working-tree changes across the monorepo were preserved, and no unapproved production migrations or database mutations were applied.

---

## 2. Root Cause Analysis & Architectural Fixes

### A. The "Valid From" Extraction Bug in `GstCertificateParser`
- **Root Cause**:
  In `GstCertificateParser.parse()`, line 231 had:
  ```dart
  if (liability == null && standalone.length >= 2) {
    if (standalone.length >= 3 || standalone[1] == standalone[0]) {
      layoutValidityFrom = standalone[1];
    }
  }
  ```
  Whenever the Date of Liability was detected from row 6 (`liability != null`), this condition evaluated to `false`. As a consequence, `layoutValidityFrom` was completely null, dropping the Valid From date from certificates even when cleanly present in the value column!
- **Fix Applied**:
  1. Removed the `liability == null` restriction so value-column standalone dates are evaluated regardless of whether row 6 had an explicit text label.
  2. Implemented forward proximity line scanning (`followingFromDate`) to locate dates appearing on immediate lines (1–4 lines) after a standalone `From` label.
  3. Ensured that Date of Liability, Valid From, Valid To, and Issue Date remain strictly isolated concepts and are never mixed up. If a date is unreadable, it remains null and is reported in review notes rather than guessed.

### B. Date Normalization Discrepancy (PostgreSQL vs. Flutter)
- **Problem**:
  In PostgreSQL (`0054_buyer_gst_verification.sql`), dates are stored as SQL `date` types formatted as `YYYY-MM-DD`. In the Flutter mobile form, text controllers and date formatters expect Indian standard `DD/MM/YYYY`. When reloading records from the backend, dates appeared missing or malformed.
- **Fix Applied**:
  Updated `GstVerificationRecord.fromRow()` in `gst_verification_repository.dart` with `normDate()` which converts `YYYY-MM-DD` strings into `DD/MM/YYYY`. This guarantees that text controllers and read-only displays receive normalized `DD/MM/YYYY` representations.

### C. Local Draft Persistence Architecture (`GstDraftRepository`)
- **Design & Policy**:
  Database table `buyer_gst_verifications` enforces status constraints (`pending`, `approved`, `rejected`, `superseded`) and only receives formal, reviewed submissions. Storing incomplete drafts in the production backend would violate security and submission triggers.
- **Implementation**:
  Created `apps/rmbuyer_mobile/lib/features/profile/data/gst_draft_repository.dart`:
  - `GstDraft`: Holds `companyId`, `userId`, `values` (`Map<GstField, String>`), `imagePath`, `savedAt`, and `editedFields`.
  - User and Company Isolation: Keyed as `gst_draft_${companyId}_${userId}` so multiple users on the same phone cannot view or overwrite each other's drafts.
  - `GstDraftStorage`: Contract supporting persistent storage (`SecureGstDraftStorage` using `flutter_secure_storage`) and transient in-memory storage (`InMemoryGstDraftStorage`) for tests and test-environments without active platform channels.
  - Automatic Lifecycle: Draft is preserved during edits, restored upon resuming, and cleared only upon explicit user action ("Discard") or successful server submission.

---

## 3. Profile UI & Experience Redesign

### A. Profile Overview Screen (`ProfileSettingsScreen`)
The profile overview was reorganized into 5 cohesive, Material 3 structured sections:

1. **Section 1: Personal Profile**:
   - Circular avatar with user initials.
   - Full Name, Mobile Number, and Sign-in Email.
   - Role badge (`BUYER` / `ADMIN`).
   - Quick action to open Edit Profile (`Key('settings-edit-profile')`).

2. **Section 2: Business Profile**:
   - Company Business Name, Legal Name, Trade Name, Constitution, Principal Address, State/PIN, and GSTIN.
   - Status Indicator: `Complete` (Green), `Partial Details` (Amber), or `Details Missing` (Grey).
   - Empty-state call-to-action when unverified: "Complete GST verification to register your verified business legal details."

3. **Section 3: GST Verification Status Card**:
   - Authoritative Status Badge:
     - `Verified` (Green): Approved by admin with reviewed timestamp.
     - `Pending` (Amber): Submitted and awaiting admin review.
     - `Draft Saved` (Amber): Displayed when an unsubmitted local draft exists (`Key('settings-gst-draft-badge')`) with formatted timestamp (`DD/MM/YYYY HH:mm`). Action: "Continue Draft".
     - `Rejected` (Red): Shows backend rejection reason and action "Resubmit GST Certificate".
     - `Not Verified` (Grey): Action "Start Verification".
   - Shows GSTIN and warns if an unbacked legacy `is_verified` flag exists without an approved GST record.

4. **Section 4: Warehouses & Unloading Locations**:
   - Summary card displaying total active locations (`X Active`).
   - Highlights Primary Unloading Depot (e.g. name and PIN code).
   - Guidance empty-state for accounts without registered depots.
   - Direct shortcut `Key('settings-warehouses')` navigating to `/settings/warehouses`.

5. **Section 5: Account & App Settings**:
   - Language selector (Tamil, Hindi, Punjabi, Telugu, Kannada, Malayalam, English).
   - Display settings (Theme modes).
   - Sign Out action with confirmation dialog.
   - App version footer (`RMBuyer Mobile v1.0.0`).

### B. Edit Profile Screen (`BuyerProfileScreen`)
Structured into 5 clear sections:
1. **Personal Details**: Editable Name and Mobile number fields with client-side Indian mobile validation (`+91XXXXXXXXXX`). Read-only sign-in email.
2. **Company Details**: Read-only display of business name, legal name, trade name, constitution, address, and PIN with protected-field lock explanation.
3. **GST Details & Verification Shortcut**: Displays current GSTIN, verification status, and direct button (`Key('profile-gst-action-btn')`) linking to `/gst-verification`.
4. **Operational Warehouses Shortcut**: Shortcut button (`Key('profile-warehouses-action-btn')`) linking to `/settings/warehouses`.
5. **Account & Security Notes**: Explanation of role and protected data boundaries.

### C. GST Verification Screen (`GstVerificationScreen`)
- **4-Step Progress Indicator**:
  - Step 1: Upload Certificate
  - Step 2: Extract
  - Step 3: Review / Draft
  - Step 4: Status
- **Save Draft & Resume Draft Action**:
  - "Save Draft" button alongside "Submit for Verification".
  - Banner displayed when a draft is stored locally on the device with "Resume Draft" and "Discard" actions.
  - Form allows saving at any point without blocking on optional or unreadable fields.
  - Discarding triggers a confirmation dialog preventing accidental loss of progress.

---

## 4. ADDENDUM: GPS-Enabled Warehouse & Google Maps Notifications

### A. Location Architecture & Dependencies
- Standardized on `geolocator: ^14.0.1` (consistent with `apps/rmseller_mobile`).
- Created abstract contract `LocationProvider` and implementation `DeviceLocationService` (`apps/rmbuyer_mobile/lib/features/profile/data/device_location_service.dart`):
  - Enforces explicit user tap (no passive/background tracking).
  - High accuracy GPS mode with a 25-second timeout.
  - Configurable accuracy threshold (<= 100 meters).
  - Bounded coordinates validation (-90 <= lat <= 90, -180 <= lng <= 180, non-zero null-island exclusion).
  - Distinguishes statuses: `ok`, `serviceDisabled`, `permissionDenied`, `permissionDeniedForever`, `timeout`, `poorAccuracy`, `invalidCoordinates`, `unavailable`.
  - Offers deep links to system `openAppSettings()` and `openLocationSettings()`.

### B. Warehouse UI Enhancements (`WarehouseManagementScreen`)
1. **Form Sheet (`_WarehouseFormSheet`)**:
   - Dedicated **Warehouse GPS Location** section.
   - Explanatory guidance: *"Stand at the actual warehouse gate or unloading entrance when capturing GPS coordinates to ensure accurate dispatch logistics."*
   - Status indicators: `Location captured` (Green), `Location not captured` (Grey), `Location permission unavailable` (Red/Amber).
   - "Use Current GPS Location" button (`Key('warehouse-gps-capture-button')`).
   - Real-time coordinate feedback: Latitude (`Key('warehouse-gps-lat-text')`), Longitude (`Key('warehouse-gps-lng-text')`), and Accuracy radius (`Key('warehouse-gps-accuracy-text')`).
   - "Open in Google Maps" preview action (`Key('warehouse-gps-preview-button')`).
   - "Refresh GPS Location" action (`Key('warehouse-gps-refresh-button')`).
   - "Clear Coordinates" action (`Key('warehouse-gps-clear-button')`).
   - Low accuracy banner with "Retry GPS" and "Accept Anyway" options.
   - Failure preservation: If a GPS refresh fails, previously saved coordinates are preserved and not silently overwritten.
2. **Warehouse Cards View**:
   - Warehouses with GPS display a green GPS badge with exact coordinates and accuracy, plus an inline `Maps` preview link.
   - Warehouses without GPS clearly display a fallback badge: `No GPS captured (Address only)`.

### C. Database Persistence & Proposed Migrations
1. **Schema Enhancements**:
   - Columns: `latitude double precision`, `longitude double precision`, `gps_accuracy double precision`, `location_captured_at timestamptz`.
   - Constraints:
     - `CHECK (latitude IS NULL OR (latitude >= -90.0 AND latitude <= 90.0))`
     - `CHECK (longitude IS NULL OR (longitude >= -180.0 AND longitude <= 180.0))`
     - `CHECK (gps_accuracy IS NULL OR gps_accuracy >= 0)`
     - `CONSTRAINT chk_warehouse_coordinates_pair CHECK ((latitude IS NULL AND longitude IS NULL) OR (latitude IS NOT NULL AND longitude IS NOT NULL))`
2. **Migrations Added/Updated**:
   - `supabase/proposed/0055_company_warehouses.sql`: Complete table creation with GPS columns and updated trigger.
   - `supabase/proposed/0056_warehouse_gps_coordinates.sql`: Non-destructive `ALTER TABLE` upgrade for environments with pre-existing table.
   - `supabase/proposed/rollback_0055.sql` and `supabase/proposed/rollback_0056.sql`: Matching rollback scripts.

### D. Google Maps URL Generation
- Constructed strictly from validated coordinates:
  ```
  https://www.google.com/maps/search/?api=1&query=LATITUDE%2CLONGITUDE
  ```
- URL-encoded format: `https://www.google.com/maps/search/?api=1&query=25.1825%2C75.8398`.
- If coordinates are absent or invalid, returns `null`. Never fabricates a link.

### E. RMBroker Notification Delivery & UI
1. **Database Trigger (`trg_notify_warehouse_change`)**:
   - Detects change types: `CREATED`, `DEACTIVATED`, `ACTIVATED`, `LOCATION_UPDATED` (coords only), `ADDRESS_UPDATED`, `UPDATED`.
   - Includes `googleMapsUrl`, `latitude`, `longitude`, `gpsAccuracy`, `changeType`, and address summary in the JSONB payload.
   - Filters recipients strictly to active brokers associated via verified CRM contact (`crm_contacts`) or active counterparty deal (`deals`).
   - Generates deterministic idempotency key (`wh-<id>-<type>-<timestamp>-<brokerId>`) with `ON CONFLICT DO NOTHING`.
2. **RMBroker Notification Card (`NotificationCard`)**:
   - Identifies warehouse events with `LucideIcons.warehouse` and teal branding (`#0D9488`).
   - Displays headline (company name), warehouse name fact, and address fact.
   - When coordinates exist, renders a prominent **"View on Google Maps"** action button (`ValueKey('notif_maps_<id>')`) opening the external Maps app via `url_launcher`.
   - Preserves internal directory/warehouse details action separately.

---

## 5. Verification & Automated Test Evidence

### A. Test Execution Summary

| Test Suite | Package | File | Tests Run | Result |
| :--- | :--- | :--- | :---: | :---: |
| **GST Draft Repository** | `rmbuyer_mobile` | `test/unit/gst_draft_repository_test.dart` | 4 | **PASSED** |
| **GST Parser & Field Extraction** | `rmbuyer_mobile` | `test/unit/gst_certificate_test.dart` | 8 | **PASSED** |
| **Reference Certificate & Layout** | `rmbuyer_mobile` | `test/unit/gst_reference_certificate_test.dart` | 30 | **PASSED** |
| **GST Status Truth & Authority** | `rmbuyer_mobile` | `test/unit/gst_status_truth_test.dart` | 12 | **PASSED** |
| **Buyer Warehouse Domain & GPS Persistence** | `rmbuyer_mobile` | `test/unit/buyer_warehouse_repository_test.dart` | 13 | **PASSED** |
| **Warehouse Broker Notification Simulator** | `rmbuyer_mobile` | `test/unit/warehouse_broker_notification_backend_test.dart` | 6 | **PASSED** |
| **Draft & 4-Step Progress Flow** | `rmbuyer_mobile` | `test/widgets/gst_draft_and_progress_test.dart` | 4 | **PASSED** |
| **GST Verification Screen UI** | `rmbuyer_mobile` | `test/widgets/gst_verification_screen_test.dart` | 32 | **PASSED** |
| **Profile Settings & GST Card** | `rmbuyer_mobile` | `test/widgets/profile_settings_gst_test.dart` | 7 | **PASSED** |
| **Edit Profile & Protected Fields** | `rmbuyer_mobile` | `test/widgets/profile_screen_test.dart` | 11 | **PASSED** |
| **Settings Language & Routing** | `rmbuyer_mobile` | `test/widgets/settings_language_test.dart` | 8 | **PASSED** |
| **Warehouse GPS & Management UI** | `rmbuyer_mobile` | `test/widgets/warehouse_management_screen_test.dart` | 12 | **PASSED** |
| **RMBroker Warehouse Notifications & Maps Action** | `rmbroker_mobile` | `test/features/notifications/warehouse_notification_e2e_test.dart` | 6 | **PASSED** |
| **Total Verified Automated Tests** | **Both Apps** | **13 test files** | **153 tests** | **100% PASS** |

### B. Flutter Code Analysis
- `apps/rmbuyer_mobile`: `flutter analyze` -> **No issues found!** (0 errors, 0 warnings, 0 lints).
- `apps/rmbroker_mobile`: `flutter analyze` -> **No issues found!** (0 errors, 0 warnings, 0 lints).

### C. Android Build & Real Device Installation
- **Binary Built**: `build\app\outputs\flutter-apk\app-debug.apk` (220.6s).
- **Target Device**: Redmi Note 5 Pro (`e0d9da95`), Android 9.
- **Package**: `com.rmbroker.rmbuyer.rmbuyer_mobile`.
- **Install Output**: `Performing Streamed Install -> Success`.
- **Verified Device Timestamp**: `lastUpdateTime=2026-10-29 17:23:11`.

---

## 6. Security & Isolation Controls Verified

1. **Self-Approval Prevention**: The mobile client has no capability or API to mark its own company as verified. Status is strictly derived from authoritative backend records (`buyer_gst_verifications`).
2. **Draft Isolation**: Local draft storage keys contain both `companyId` and `userId`. Switching accounts or signing in with a different user never exposes previous draft contents.
3. **Protected Field Immutability**: All company fields (legal name, GSTIN, constitution, address) remain strictly read-only on the mobile client and can only be updated through verified GST administrative approvals.
4. **Broker Notification Scope**: Notifications are triggered only after successful database commits and delivered strictly to authorized brokers with existing verified relationships (CRM or Deal).
5. **No Passive Tracking**: Location services are requested and read strictly on-demand upon explicit user tap. No background location daemon or persistent tracking exists.
6. **No Fabricated Maps URLs**: If a warehouse lacks coordinates, the Google Maps action is completely omitted and the plain text address is shown.

---

## 7. Deliverable File Changes

### RMBuyer Mobile (`apps/rmbuyer_mobile`)
- `pubspec.yaml` *(Added `geolocator: ^14.0.1`)*
- `android/app/src/main/AndroidManifest.xml` *(Added location permissions and queries)*
- `lib/features/profile/domain/company_warehouse.dart` *(Updated with coordinates, accuracy, and Maps URL)*
- `lib/features/profile/data/device_location_service.dart` *(New LocationProvider service)*
- `lib/features/profile/presentation/warehouse_management_screen.dart` *(Updated with GPS capture UI and card maps)*
- `test/unit/buyer_warehouse_repository_test.dart` *(Updated with coordinate serialization & validation)*
- `test/unit/warehouse_broker_notification_backend_test.dart` *(Updated with Maps URL & change types)*
- `test/widgets/warehouse_management_screen_test.dart` *(Updated with GPS capture widget tests)*

### RMBroker Mobile (`apps/rmbroker_mobile`)
- `lib/features/notifications/domain/notification_model.dart` *(Added warehouse getters and googleMapsUrl)*
- `lib/features/notifications/presentation/widgets/notification_card.dart` *(Added warehouse branding and View on Google Maps button)*
- `test/features/notifications/warehouse_notification_e2e_test.dart` *(Updated with Maps action integration tests)*

### Database & Migrations (`supabase/proposed`)
- `0055_company_warehouses.sql` *(Updated with GPS columns & upgraded trigger)*
- `0056_warehouse_gps_coordinates.sql` *(New non-destructive upgrade migration)*
- `rollback_0056.sql` *(New rollback script)*

---

## 8. Rollout Recommendation & Status

- **Status**: **PASS (PRODUCTION READY FOR CLIENT; PENDING BACKEND MIGRATION ROLLOUT)**
- The client implementation in both RMBuyer Mobile and RMBroker Mobile is completely tested, verified, and installed on the connected physical device.
- Upon database administrator authorization, migrations `0053`, `0054`, and `0055` (or `0056`) can be deployed to staging/production databases to enable real-time backend persistence.
