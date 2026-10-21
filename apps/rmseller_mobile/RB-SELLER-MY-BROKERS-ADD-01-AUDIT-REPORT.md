# RB-SELLER-MY-BROKERS-ADD-01 — Audit Report
**Sprint:** Floating Add Broker & Broker Self-Verification  
**Application:** RM Seller Mobile (`apps/rmseller_mobile`)  
**Sprint Type:** Implementation Sprint (Audit → Implement → Test → Report → Stop)  
**Date:** 2026-10-21  
**Status:** Audit Complete — Implementation Ready

---

## 1. Executive Summary

This audit assesses the requirements and current implementation of the **My Mandi Brokers** page in `rmseller_mobile` for introducing a Floating Action Button (FAB) and a verified **Add Broker** workflow.

The core objective is to allow commodity sellers to add trusted brokers via:
1. Native device phone contacts (using Android's privacy-preserving system contact picker `Intent.ACTION_PICK`).
2. Manual phone number entry with Indian standard validation (+91, 10 digits starting with 6–9).
3. Authoritative backend identity matching against registered broker profiles (`users.role = 'broker'`).
4. Official invitation workflows for unregistered or unverified contacts via WhatsApp / SMS.
5. Strict enforcement of broker self-verification: **brokers, not sellers, must confirm and maintain their own professional desk profiles.** Local phonebook entries must never be treated as verified brokers.

---

## 2. Architecture & Component Inventory

### 2.1 Existing Screens & Routes
- **`MyBrokersScreen` (`lib/features/brokers/presentation/my_brokers_screen.dart`):**
  - Serves as the primary broker directory screen for sellers (`/brokers`), mapped to Branch 2 of `app_router.dart`.
  - Currently supports search query filtering by name, mandi location, and commodity tags.
  - Lists verified broker cards with trust scores, ratings, phone dialer (`tel:`), and WhatsApp (`wa.me`) mediation.
  - Currently lacks an "Add Broker" Floating Action Button or bottom sheet workflow.
- **`BrokerProfileScreen` (`lib/features/brokers/presentation/broker_profile_screen.dart`):**
  - Shows detailed desk metrics, trust score, ratings, and deal eligibility.
- **`ContactLauncherService` (`lib/core/services/contact_launcher_service.dart`):**
  - Provides system dialer launcher (`tel:`) and external WhatsApp launcher (`https://wa.me/91...`).

### 2.2 Domain & Data Layer
- **`SellerBrokerModel` (`lib/features/brokers/domain/seller_broker_model.dart`):**
  - Represents an authorized broker desk with `id`, `name`, `mobile`, `companyName`, `location`, `trustScore`, `isVerified`, `commoditiesHandled`, etc.
  - Needs extension to represent broker lifecycle statuses (`registeredVerified`, `pendingVerification`, `invitationPending`).
- **`SellerBrokerRepository` (`lib/features/brokers/data/seller_broker_repository.dart`):**
  - Queries Supabase `users` joined with `companies` where `role = 'broker' AND status = true`.
  - Fallback broker desks for Jaipur, Bikaner, Indore, and Kota.
  - Needs lookup and registration methods: `lookupBrokerByPhone()`, `addBroker()`, `inviteBroker()`.

### 2.3 Backend & Database Contracts (`src/server/db/schema.ts`)
- **`users` table:** `id (uuid)`, `name (text)`, `mobile (text)`, `role (text)`, `status (boolean)`, `company_id (uuid)`.
- **`companies` table:** `id (uuid)`, `name (text)`, `is_verified (boolean)`, `trust_score (integer)`.
- **`profiles_broker` table:** `id (uuid)` referencing `users.id`.
- **System Invariant:** Public broker self-registration is closed / invite-only by Platform Administration (Sprint 30.2, `auth-actions.ts`). Only Platform Admins approve and verify broker desks.

---

## 3. Contact Picker & Permission Strategy

### 3.1 Android Privacy Model & Safety
- **Requirement:** Avoid requesting broad address-book permissions (`READ_CONTACTS`) or dumping the user's contacts.
- **Platform Capability:** Android provides the system intent `Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI)`.
- **Key Advantage:**
  - When invoked, Android presents the native contacts app.
  - The user explicitly chooses a single contact.
  - The OS returns temporary read URI permission for the selected record only.
  - **No runtime `READ_CONTACTS` permission prompt or entire phonebook access is required.**
  - If a contact has multiple numbers, the native picker lets the user select the exact desired number.
- **Implementation Mechanism:**
  - A lightweight Android MethodChannel in `MainActivity.kt` (`com.brokerbridge.rmseller/contacts`, method `pickContact`).
  - Wrapped by `ContactPickerService` in Dart with graceful fallbacks and cancellation handling.

---

## 4. Phone Validation & Normalization Rules

Mirrors standard project utility `src/lib/phone-utils.ts`:
1. Strips whitespace, hyphens, brackets, dots.
2. Supports `+919876543210`, `919876543210`, `09876543210`, and `9876543210`.
3. Validates exactly 10 digits starting with `6`, `7`, `8`, or `9`.
4. Normalizes to E.164: `+91<10_digits>`.
5. Formats for display: `+91 98765 43210`.
6. Ambiguous, invalid, or non-Indian formats are rejected with clear, actionable validation messages.

---

## 5. Security & Relationship Invariants

1. **Broker Self-Verification:**
   - The seller cannot certify another person's identity or create a verified broker account.
   - Adding a phone contact stores only a local/session nomination or pending invitation.
   - Only Platform Administration and the broker themselves can verify and maintain broker desk credentials.
2. **Counterparty Shield:**
   - direct Buyer contact paths and Buyer directory access remain strictly excluded.
   - Only authorized broker profile attributes (desk name, mandi location, verified badge, trust score) are visible.
3. **No Database Schema Mutations:**
   - Zero modifications to `supabase/migrations` or Drizzle schemas.
   - Sibling apps (`rmbuyer_mobile`, `rmbroker_mobile`) remain untouched.

---

## 6. Implementation Plan

| Step | Component | Action |
|:---|:---|:---|
| 1 | `android/.../MainActivity.kt` | Implement `pickContact` method channel via `Intent.ACTION_PICK` |
| 2 | `lib/core/utils/phone_utils.dart` | Implement phone validation, normalization, and formatting |
| 3 | `lib/core/services/contact_picker_service.dart` | Implement native contact picker bridge with cancellation handling |
| 4 | `lib/features/brokers/domain/seller_broker_model.dart` | Add `SellerBrokerStatus` enum and status fields |
| 5 | `lib/features/brokers/data/seller_broker_repository.dart` | Add `lookupBrokerByPhone()`, `addBroker()`, `inviteBroker()` |
| 6 | `lib/features/brokers/presentation/my_brokers_screen.dart` | Add FAB `Add Broker`, bottom sheet options, manual form, lookup dialog, and status badges |
| 7 | Verification & Testing | Unit tests, widget tests, Node.js automated test runner, Android APK build, device testing |

**Audit Outcome:** Proceeding to Phase 2 (Implementation).
