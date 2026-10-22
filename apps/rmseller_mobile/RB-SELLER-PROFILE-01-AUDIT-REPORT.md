# RB-SELLER-PROFILE-01 — Pre-Implementation Audit Report
**Sprint:** Editable Profile & Dashboard Three-Dot Menu  
**Application:** RM Seller Mobile (`apps/rmseller_mobile`)  
**Sprint Type:** Implementation Sprint (Audit → Implement → Test → Report → Stop)  
**Status:** PASS  
**Date:** 2026-10-22  

---

## 1. Executive Summary

This audit assesses the existing architecture, navigation, and persistence mechanisms of the Seller App (`rmseller_mobile`) in preparation for sprint **RB-SELLER-PROFILE-01**.

The two primary objectives of this sprint are:
1. Transforming the Seller Profile view from a static, read-only display into a fully editable, validated, and persistently synchronized profile experience.
2. Introducing a standard three-dot overflow menu in the top-right corner of the Seller Dashboard app bar, providing direct, accessible navigation to My Profile, Settings, Help & Support, Notifications, and Logout.

The audit confirms that all necessary underlying components—Supabase database tables, RLS policies, encrypted local storage, Riverpod app preferences, and GoRouter routing infrastructure—already exist and support the required functionality without requiring any schema migrations, RLS mutations, or changes to commodity trading workflows.

---

## 2. Pre-Implementation Audit Checkpoints

### 2.1 Seller Dashboard Header & Menu Placement
- **File:** `apps/rmseller_mobile/lib/features/home/presentation/seller_home_screen.dart`
- **Current AppBar Actions:**
  ```dart
  actions: [
    IconButton(
      icon: const Icon(LucideIcons.bell),
      tooltip: 'Notifications',
      onPressed: () => context.push('/notifications'),
    ),
    IconButton(
      icon: const Icon(LucideIcons.search),
      tooltip: 'Search',
      onPressed: () => context.push('/search'),
    ),
  ]
  ```
- **Audit Finding:**
  - The actions currently display notifications and search icons.
  - Adding a standard `PopupMenuButton` as the rightmost item in `actions` places the three-dot overflow icon (`LucideIcons.ellipsisVertical`) precisely at the top-right corner of the header.
  - This placement preserves existing AppBar title elements (Company Name, Mediation Info Icon, Seller Desk subtitle) and avoids introducing any prominent banners or layout regressions.

### 2.2 Profile Architecture & Persistence Mechanisms
- **Files Inspected:**
  - `apps/rmseller_mobile/lib/features/profile/presentation/seller_profile_screen.dart`
  - `apps/rmseller_mobile/lib/features/authentication/data/auth_repository.dart`
  - `apps/rmseller_mobile/lib/core/security/secure_storage_service.dart`
  - `src/server/db/schema.ts`
  - `supabase/migrations/0001_init_users_and_companies.sql`
  - `supabase/migrations/0037_add_broker_directory_rls_and_grants.sql`
  - `supabase/migrations/manual_rls_companies.sql`

- **Authoritative Data Model & Schema:**
  - Table `public.users`:
    - `id`: UUID (Primary Key, matches Supabase Auth `auth.uid()`) — **Read-Only**
    - `name`: TEXT NOT NULL (Seller Full Name / Contact Person) — **Editable**
    - `mobile`: TEXT (Registered Contact Mobile Number) — **Editable**
    - `email`: TEXT (Registered Login Email) — **Read-Only** (bound to Auth identity)
    - `role`: TEXT ('seller') — **Read-Only** (enforced by RLS self-promotion guard)
    - `company_id`: UUID (FK to `companies.id`) — **Read-Only**
    - `created_at`: TIMESTAMP — **Read-Only**
  - Table `public.companies`:
    - `id`: UUID (Primary Key) — **Read-Only**
    - `name`: TEXT NOT NULL (Enterprise Entity Name) — **Editable**
    - `gst`: TEXT (15-character GSTIN) — **Editable**
    - `is_verified`: BOOLEAN (Authoritative verification flag) — **Read-Only**
    - `trust_score`: INTEGER (Authoritative trade trust score) — **Read-Only**
    - `state_id`: TEXT / `district_id`: TEXT (Location metadata) — **Editable**

- **RLS & Security Verification:**
  - `users_update_policy` (Migration `0037`): Allows `auth.uid() = users.id` to update self, strictly asserting `LOWER(role) = public.get_auth_role()`.
  - `Users can update their own company` (Migration `manual_rls_companies.sql`): Allows updating company row where `id IN (SELECT company_id FROM users WHERE id = auth.uid())`.
  - **Verdict:** Backend permissions already exist for self-profile and company updates! No schema changes or RLS changes are required or authorized.

- **Storage & Offline/Test Mode:**
  - `SecureStorageService` caches `user_id`, `user_role`, `user_email`, `user_full_name`, `company_id`, `company_name`, `company_gst`, and arbitrary preferences via encrypted local storage with in-memory test fallback.
  - Adding `SellerProfileRepository` with authoritative Supabase sync and `SecureStorageService` fallback guarantees deterministic operation across unit tests, widget tests, and production networks.

### 2.3 Profile Image / Logo Upload Feasibility
- **Audit Finding:**
  - In `supabase/migrations/manual_storage_rls.sql`, the storage bucket `brokerbridge_documents` only allows SELECT access when the object path matches an active deal (`{deal_id}/{filename}`).
  - There is no dedicated public or user-scoped avatar storage bucket in Supabase migrations.
  - In `src/server/db/schema.ts`, neither `users` nor `companies` contains an `avatar_url` or `logo_url` column.
  - In accordance with Section 5.D of the sprint specification:
    *"Do not introduce a new storage bucket, change storage policies, or expose public access to private files without the required approval. If image upload cannot be implemented safely within the existing architecture, complete the rest of the profile functionality and document the limitation."*
  - **Decision:** Document this limitation cleanly. Render a polished, role-tailored enterprise avatar badge in the UI (displaying store icon and enterprise monogram initials), and omit file upload to prevent unauthorized storage mutations.

### 2.4 Existing Settings Implementation
- **Files Inspected:**
  - `apps/rmseller_mobile/lib/core/preferences/app_settings_provider.dart`
  - `apps/rmseller_mobile/lib/features/profile/presentation/widgets/app_settings_section.dart`
  - `apps/rmseller_mobile/lib/app/router/app_router.dart`
- **Audit Finding:**
  - Sprint `RB-APP-SETTINGS-01` fully implemented `AppSettingsSection` featuring Theme (System, Light, Dark), Language (English, Hindi with honesty disclosure), Font Scaling (4 tiers: Small 0.85x, Default 1.0x, Large 1.15x, Extra Large 1.30x via `TextScaler`), and Accessibility high-contrast toggle.
  - Route `/settings` in `app_router.dart` currently routes to `SellerProfileScreen()`.
  - Creating a dedicated `SellerSettingsScreen` at `/settings` wrapping `AppSettingsSection` in a clean `Scaffold` with an AppBar back button will provide a dedicated settings experience from the overflow menu while preserving the embedded section on `SellerProfileScreen`.

### 2.5 Help & Support Feasibility & Verification
- **Files Inspected:**
  - `apps/rmseller_mobile/lib/core/config/app_config.dart`
  - `apps/rmseller_mobile/lib/features/notifications/presentation/seller_notifications_screen.dart`
  - `src/types/support-schema.ts`
- **Audit Finding:**
  - There is currently no dedicated Help & Support screen in `rmseller_mobile`.
  - There are NO verified external telephone numbers, email addresses, or WhatsApp channels configured in `AppConfig`.
  - In strict compliance with Section 8:
    *"Do not invent support numbers, email addresses, WhatsApp numbers, URLs, or service commitments. If no verified support contact is configured, provide useful in-app help content and clearly document that a verified contact channel still needs to be supplied."*
  - **Decision:** Implement `SellerHelpSupportScreen` providing clear in-app guidance for Dashboard KPIs, Profile editing, commodity listing, broker-mediated workflow compliance, Counterparty Shield rules, and support query submission, with an honest disclosure stating that official regional helpline numbers will be published upon mandi authority deployment.

### 2.6 Notifications, Privacy Policy & Terms Review
- **Notifications:**
  - Fully implemented at route `/notifications` (`SellerNotificationsScreen`). Included in overflow menu!
- **Privacy Policy & Terms:**
  - Neither a dedicated privacy policy screen nor approved terms document exists in the client codebase.
  - In accordance with Section 4.B:
    *"Include only if an existing or approved policy page/document is available... Do not add every optional item blindly. Include optional items only when they have a real destination and working functionality."*
  - **Decision:** Do not add dead placeholder items for Privacy Policy and Terms & Conditions. The overflow menu will feature: My Profile, Settings, Help & Support, Notifications, Divider, and Logout.

### 2.7 Authentication, Session & Logout Integrity
- **Files Inspected:**
  - `apps/rmseller_mobile/lib/features/authentication/data/auth_repository.dart`
  - `apps/rmseller_mobile/lib/app/router/app_router.dart`
- **Audit Finding:**
  - Standard logout flow executes `_authRepository.signOut()` followed by `AppRouter.authNotifier.setUnauthenticated()`.
  - GoRouter's route guard intercepts the unauthenticated state and redirects to `/login`.
  - Back navigation from `/login` cannot return to protected routes.
  - Reusing this exact flow from the overflow menu ensures identical session cleanup and security posture.

---

## 3. Implementation Plan

1. **Profile Data Layer (`SellerProfileModel` & `SellerProfileRepository`):**
   - Create `SellerProfileModel` with full fields (id, fullName, email, mobile, role, companyId, companyName, companyGst, primaryMandi, trustScore, isVerified).
   - Create `SellerProfileRepository` interfacing with Supabase `users` and `companies` tables, with fallback to `SecureStorageService`.
2. **Dedicated Settings Screen (`SellerSettingsScreen`):**
   - Create standalone settings page at `/settings` hosting `AppSettingsSection`.
3. **Dedicated Help & Support Screen (`SellerHelpSupportScreen`):**
   - Create comprehensive in-app help guide at `/help` without fabricated contact details.
4. **Interactive Profile Screen (`SellerProfileScreen`):**
   - Implement View Mode and Edit Mode.
   - Edit Profile button opens pre-populated form.
   - Field-level validation for name, company name, 10-digit mobile, GSTIN format.
   - Clear distinction between editable and read-only fields.
   - Save Changes with progress indicator and authoritative refresh.
   - Cancel button reverting unsaved changes.
5. **Dashboard Overflow Menu (`SellerHomeScreen`):**
   - Add `PopupMenuButton` at top-right of AppBar.
   - Items: My Profile, Settings, Help & Support, Notifications, Divider, Logout.
   - Confirmation dialog before signing out.
6. **Router Updates (`AppRouter`):**
   - Register `/settings` -> `SellerSettingsScreen`.
   - Register `/help` -> `SellerHelpSupportScreen`.
7. **Verification & Testing:**
   - Create automated TypeScript verification suite (`verify-rmseller-profile-01.ts`).
   - Create Flutter widget test suite covering profile editing, menu actions, settings, and validation.
   - Run `flutter analyze` and `flutter test`.
