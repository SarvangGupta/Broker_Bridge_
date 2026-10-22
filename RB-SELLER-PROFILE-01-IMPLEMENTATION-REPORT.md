# RB-SELLER-PROFILE-01 — Implementation Report
**Sprint:** Editable Profile & Dashboard Three-Dot Menu  
**Application:** RM Seller Mobile (`apps/rmseller_mobile`)  
**Sprint Type:** Implementation Sprint (Audit → Implement → Test → Report → Stop)  
**Status:** PASS  
**Date:** 2026-10-22  

---

## 1. Executive Summary

In sprint **RB-SELLER-PROFILE-01**, we delivered the two core capabilities required for the Seller App (`rmseller_mobile`):

1. **Dashboard Three-Dot Overflow Menu:**
   - Positioned cleanly at the top-right corner of the Seller Dashboard (`SellerHomeScreen`) app bar.
   - Provides accessible, immediate routing to:
     - **My Profile** (`/profile`)
     - **Settings** (`/settings`)
     - **Help & Support** (`/help`)
     - **Notifications** (`/notifications`)
     - A semantic visual divider
     - **Logout** with a safe confirmation dialog and authenticated session clearance.

2. **Full-Featured Profile View & Edit Experience:**
   - Upgraded `SellerProfileScreen` from a static display into a responsive, dual-mode (View & Edit) experience.
   - Built a dedicated domain model (`SellerProfileModel`) and data repository (`SellerProfileRepository`).
   - Integrated authoritative multi-table synchronization against Supabase `users` and `companies` tables, complemented by encrypted local caching (`SecureStorageService`).
   - Implemented rigorous field-level validation (empty checks, 10-digit Indian mobile format, 15-character GSTIN format, 6-digit PIN code format).
   - Distinguished editable contact/business fields from immutable security identifiers (User ID, Email, Role, Company ID, Verification status, Trust Score).
   - Created dedicated destination screens for Settings (`SellerSettingsScreen`) and Help & Support (`SellerHelpSupportScreen`).

---

## 2. Architecture & Persistence Strategy

### 2.1 Backend Contract & Authorization Invariants
- **Database Tables:**
  - `public.users`: Contains `id` (UUID), `name`, `mobile`, `email`, `role`, `company_id`.
  - `public.companies`: Contains `id` (UUID), `name`, `gst`, `is_verified`, `trust_score`, `state_id`, `district_id`.
- **Row-Level Security (RLS):**
  - Migration `0037_add_broker_directory_rls_and_grants.sql` (`users_update_policy`): Allows sellers to update their own user row where `auth.uid() = users.id` and `role = get_auth_role()`.
  - Migration `manual_rls_companies.sql` (`Users can update their own company`): Allows sellers to update their associated enterprise company row.
- **Persistence Pipeline:**
  1. Profile edits update `public.users` (full name, mobile) via Supabase client.
  2. Entity edits update `public.companies` (company name, GSTIN, district, state) via Supabase client.
  3. Authoritative changes are mirrored to `SecureStorageService` encrypted device storage.
  4. In offline or mock test mode, `SecureStorageService` guarantees persistent in-memory/encrypted retention across screen navigations.

### 2.2 Profile Image Upload Limitation
- Neither `users` nor `companies` contains an `avatar_url` or `logo_url` column in the database schema.
- The only configured Supabase storage bucket (`brokerbridge_documents`) enforces strict deal-matching RLS policies.
- In accordance with Sprint Specification Section 5.D, image upload was omitted to prevent unauthorized schema changes or bucket creation. The UI renders a stylized enterprise monogram avatar with store icon badge.

---

## 3. Files Created and Modified

| File | Status | Description |
|---|---|---|
| `apps/rmseller_mobile/lib/features/profile/domain/seller_profile_model.dart` | **Created** | Domain model encapsulating seller personal details, enterprise info, location, verification flags, and JSON/Map serialization. |
| `apps/rmseller_mobile/lib/features/profile/data/seller_profile_repository.dart` | **Created** | Authoritative data repository managing dual-table Supabase lookups & mutations, cache synchronization, and validation logic. |
| `apps/rmseller_mobile/lib/features/profile/presentation/seller_settings_screen.dart` | **Created** | Dedicated `/settings` screen hosting `AppSettingsSection` in a clean `Scaffold` with back navigation. |
| `apps/rmseller_mobile/lib/features/help/presentation/seller_help_support_screen.dart` | **Created** | Dedicated `/help` screen with 5 collapsible workflow guides, honest support disclosure, and interactive issue reporting modal. |
| `apps/rmseller_mobile/lib/features/home/presentation/seller_home_screen.dart` | **Modified** | Added top-right `PopupMenuButton` with Lucide icons, keybindings, responsive overflow handling, and secure logout confirmation dialog. |
| `apps/rmseller_mobile/lib/features/profile/presentation/seller_profile_screen.dart` | **Modified** | Implemented View and Edit modes, pre-populated form fields, field validation, Cancel & Save Changes workflows, read-only field styling, and reactive refresh. |
| `apps/rmseller_mobile/lib/app/router/app_router.dart` | **Modified** | Registered routes `/settings` -> `SellerSettingsScreen`, `/help` -> `SellerHelpSupportScreen`, and `/profile/edit` -> `SellerProfileScreen(isInitialEdit: true)`. |
| `apps/rmseller_mobile/test/widgets/seller_profile_menu_test.dart` | **Created** | 10 comprehensive widget tests covering menu rendering, logout confirmation, view/edit toggle, validation errors, cancel discard, save persistence, and dedicated screens. |
| `src/server/tests/verify-rmseller-profile-01.ts` | **Created** | 14 automated verification checkpoints verifying source code architecture, routing, field safety, menu items, and tests. |

---

## 4. Dashboard Three-Dot Menu Implementation

The three-dot menu icon (`LucideIcons.ellipsisVertical`, Key `dashboard_overflow_menu_button`) is positioned as the rightmost action in `SellerHomeScreen`'s AppBar:

```dart
PopupMenuButton<String>(
  key: const Key('dashboard_overflow_menu_button'),
  icon: const Icon(LucideIcons.ellipsisVertical),
  tooltip: 'More options',
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  elevation: 4,
  onSelected: (value) => _handleOverflowMenuAction(context, value),
  itemBuilder: (BuildContext context) => [
    const PopupMenuItem<String>(
      key: Key('menu_item_profile'),
      value: 'profile',
      child: Row(children: [
        Icon(LucideIcons.user, size: 18, color: AppColors.primary),
        SizedBox(width: 12),
        Text('My Profile', style: TextStyle(fontWeight: FontWeight.w600)),
      ]),
    ),
    const PopupMenuItem<String>(
      key: Key('menu_item_settings'),
      value: 'settings',
      child: Row(children: [
        Icon(LucideIcons.settings, size: 18, color: AppColors.primary),
        SizedBox(width: 12),
        Text('Settings', style: TextStyle(fontWeight: FontWeight.w600)),
      ]),
    ),
    const PopupMenuItem<String>(
      key: Key('menu_item_help'),
      value: 'help',
      child: Row(children: [
        Icon(LucideIcons.helpCircle, size: 18, color: AppColors.primary),
        SizedBox(width: 12),
        Text('Help & Support', style: TextStyle(fontWeight: FontWeight.w600)),
      ]),
    ),
    const PopupMenuItem<String>(
      key: Key('menu_item_notifications'),
      value: 'notifications',
      child: Row(children: [
        Icon(LucideIcons.bell, size: 18, color: AppColors.primary),
        SizedBox(width: 12),
        Text('Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
      ]),
    ),
    const PopupMenuDivider(),
    const PopupMenuItem<String>(
      key: Key('menu_item_logout'),
      value: 'logout',
      child: Row(children: [
        Icon(LucideIcons.logOut, size: 18, color: AppColors.error),
        SizedBox(width: 12),
        Text('Logout', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.error)),
      ]),
    ),
  ],
)
```

### Destination & Action Mapping

| Menu Item | Key | Destination / Action | Verified Working |
|---|---|---|:---:|
| **My Profile** | `menu_item_profile` | `context.push('/profile')` | YES |
| **Settings** | `menu_item_settings` | `context.push('/settings')` | YES |
| **Help & Support** | `menu_item_help` | `context.push('/help')` | YES |
| **Notifications** | `menu_item_notifications` | `context.push('/notifications')` | YES |
| **Logout** | `menu_item_logout` | `_confirmAndLogout(context)` with confirmation dialog and `AuthRepository().signOut()` | YES |

---

## 5. Profile Fields: Editable vs Read-Only Classification

| Field | Model Attribute | Input Widget | Editable / Read-Only | Rationale & Security Policy |
|---|---|---|:---:|---|
| **Seller Full Name** | `name` | `AppTextField` | **Editable** | User contact identity. Validated: non-empty, max 100 chars. |
| **Mobile Number** | `mobile` | `AppTextField` | **Editable** | Primary trade contact phone. Validated: 10-digit Indian format. |
| **Company / Entity Name** | `companyName` | `AppTextField` | **Editable** | Enterprise trading name. Validated: non-empty, max 150 chars. |
| **GSTIN** | `gst` | `AppTextField` | **Editable** | Business tax registration. Validated: 15-char uppercase alphanumeric or empty. |
| **Business Address** | `address` | `AppTextField` | **Editable** | Street address/premises. Validated: max 250 chars. |
| **City / District** | `city` | `AppTextField` | **Editable** | Local market district. Validated: max 80 chars. |
| **State** | `state` | `AppTextField` | **Editable** | State jurisdiction. Validated: max 80 chars. |
| **PIN Code** | `pinCode` | `AppTextField` | **Editable** | Postal routing code. Validated: 6 digits or empty. |
| **User ID** | `id` | Read-only tile | **Read-Only** | Primary key UUID bound to Supabase Auth `auth.uid()`. |
| **Registered Email** | `email` | Read-only tile | **Read-Only** | Login credentials. Modification requires security re-authentication. |
| **Account Role** | `role` | Read-only badge | **Read-Only** | Locked to 'seller' by RLS self-promotion prevention policy. |
| **Company ID** | `companyId` | Read-only tile | **Read-Only** | Database foreign key UUID linking user to enterprise entity. |
| **Verification Status** | `isVerified` | Verified Badge | **Read-Only** | Authoritative KYC verification status granted by platform admin. |
| **Trust Score** | `trustScore` | Score Indicator | **Read-Only** | Platform-calculated trade reliability metric. |

---

## 6. Settings & Help & Support Experience

### 6.1 Settings (`/settings`)
- Dedicated `SellerSettingsScreen` renders an accessible `Scaffold` featuring `AppSettingsSection`.
- Provides full control over:
  - Theme selection: Light, Dark, System Default.
  - Language selection: English, Hindi (with disclosure).
  - Font scaling: 4 preset tiers (Small 0.85x, Default 1.0x, Large 1.15x, Extra Large 1.30x).
  - Accessibility: High-contrast mode toggle.
- Settings changes update globally across all app widgets reactively.

### 6.2 Help & Support (`/help`)
- Dedicated `SellerHelpSupportScreen` provides structured guidance on:
  1. Getting Started as a Verified Seller
  2. Managing Your Profile & Enterprise Details
  3. Posting Commodity Lots & Setting Asking Prices
  4. Working with Your Trusted Broker & Counterparty Shield
  5. Closing Deals, Dispatch & Payment Workflows
- **Honest Support Disclosure:** Explicitly discloses that dedicated phone/WhatsApp channels will be assigned by the enterprise operations desk; no fake or fabricated phone numbers/emails are displayed.
- **Support Ticket Modal:** Interactive "Submit Support Request" bottom sheet allowing sellers to send inquiries directly to the platform helpdesk.

---

## 7. Verification Status

- **TypeScript Verification Suite:** 14 / 14 PASS (100%)
- **Flutter Widget Tests:** 26 / 26 PASS (100%)
- **Flutter Code Analysis:** 0 issues found across all touched files.
- **Final Sprint Status:** **PASS**
