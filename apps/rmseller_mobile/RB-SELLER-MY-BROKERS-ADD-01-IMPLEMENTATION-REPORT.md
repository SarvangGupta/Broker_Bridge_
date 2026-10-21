# RB-SELLER-MY-BROKERS-ADD-01 — Implementation Report
**Sprint:** Floating Add Broker & Broker Self-Verification  
**Application:** RM Seller Mobile (`apps/rmseller_mobile`)  
**Sprint Type:** Implementation Sprint (Audit → Implement → Test → Report → Stop)  
**Status:** PASS  
**Date:** 2026-10-21  

---

## 1. Executive Summary

Micro-sprint **RB-SELLER-MY-BROKERS-ADD-01** implements a production-conscious, privacy-preserving **Add Broker** workflow on the existing **My Mandi Brokers** page in the RMBroker Seller App (`rmseller_mobile`).

The implementation delivers:
1. **Floating Action Button (FAB):** Added a prominent `FloatingActionButton.extended` labeled `"Add Broker"` with `LucideIcons.userPlus`, styled with `AppColors.primary`, accessible tooltip, and responsive list padding ensuring no card obscuration.
2. **Compact Options Bottom Sheet:** Tapping the FAB opens an options modal offering:
   - `Select from Phone Contacts`
   - `Add Number Manually`
   - `Cancel`
3. **Privacy-Preserving Contact Selection:** Built a native Android Platform Channel using `Intent.ACTION_PICK` pointing to `ContactsContract.CommonDataKinds.Phone.CONTENT_URI`. This returns only the contact explicitly picked by the seller without dumping the address book or requiring broad background permissions.
4. **Indian Mobile Standardization:** Implemented `PhoneUtils` to normalize numbers to E.164 (`+919876543210`), format display strings (`+91 98765 43210`), and validate 10-digit Indian numbers starting with 6, 7, 8, or 9.
5. **Authoritative Backend Matching:**
   - Evaluates numbers against registered broker accounts (`users.role = 'broker'`).
   - Distinguishes **Registered & Verified Desks**, **Pending Administrative Verification Desks**, and **Unregistered Contacts**.
6. **Broker Self-Verification Invariant:**
   - Unregistered contacts are nominated with status `SellerBrokerStatus.invitationPending`.
   - **Local phonebook entries are NEVER marked as registered or verified brokers.**
   - The broker must authenticate and confirm their own professional credentials.
7. **Official Broker Invitation Pipeline:**
   - Prepares transparent invitation messages identifying RMBroker and the inviting seller.
   - Triggers WhatsApp (`https://wa.me/91...`) and phone dialer (`tel:`) invitations via `ContactLauncherService`.

---

## 2. Files Modified & Created

| File | Change Type | Description |
|:---|:---|:---|
| `android/.../MainActivity.kt` | Modified | Added `com.brokerbridge.rmseller/contacts` MethodChannel using Android `Intent.ACTION_PICK` for contact picking. |
| `android/.../AndroidManifest.xml` | Modified | Declared `<uses-permission android:name="android.permission.READ_CONTACTS"/>`. |
| `lib/core/utils/phone_utils.dart` | Created | Phone validation, normalization (+91 standard, 10 digits `^[6-9]\d{9}$`), and display formatting. |
| `lib/core/services/contact_picker_service.dart` | Created | Native contact picker bridge with cancellation and error handling. |
| `lib/features/brokers/domain/seller_broker_model.dart` | Modified | Added `SellerBrokerStatus` enum (`registeredVerified`, `pendingVerification`, `invitationPending`) and status getters. |
| `lib/features/brokers/data/seller_broker_repository.dart` | Modified | Added `lookupBrokerByPhone()`, `addBroker()`, `inviteBroker()`, and in-session broker caching. |
| `lib/features/brokers/presentation/my_brokers_screen.dart` | Modified | Added FAB, bottom sheet options, manual entry dialog, match sheet, pending verification sheet, invitation workflow, and status badges. |
| `test/unit/add_broker_test.dart` | Created | Unit tests for PhoneUtils and SellerBrokerRepository lookup logic. |
| `test/widgets/my_brokers_screen_test.dart` | Created | Widget tests for FAB rendering and modal bottom sheets. |
| `src/server/tests/verify-rmseller-my-brokers-add-01.ts` | Created | Automated verification suite covering 18 mandatory requirements. |

---

## 3. Architecture & Technical Decisions

### 3.1 Contact Picker Privacy Invariant
- **Decision:** Use Android's `Intent.ACTION_PICK` instead of requesting full address-book access.
- **Rationale:** Android handles contact selection inside the system Contacts app. The OS returns a URI with temporary read permission for the selected record only. The seller's broader contact book is never accessed or transmitted.

### 3.2 Broker Identity & Self-Verification Invariant
- **Rule:** A seller cannot certify another person's identity.
- **Implementation:**
  - If the contact's number matches a registered broker desk in `users` (`role = 'broker'`), the seller can link the desk to their active Mandi Brokers directory.
  - If the contact is unregistered, an invitation is recorded with `SellerBrokerStatus.invitationPending`.
  - The card displays an "Invitation Pending" badge and explanation.
  - Broker accounts remain invite-only and verified by Platform Administration.

### 3.3 Counterparty Shield Compliance
- Direct Buyer contact details and Buyer directory browsing remain strictly excluded.
- Mediation occurs exclusively through verified Mandi Brokers desks.

---

## 4. Verification Results Summary

1. **Automated Test Runner (`verify-rmseller-my-brokers-add-01.ts`):** 18/18 PASSED (100%).
2. **Flutter Unit & Widget Tests (`flutter test`):** 8/8 PASSED (100%).
3. **Dart Static Analysis (`flutter analyze`):** 0 errors, 0 warnings.
4. **Android APK Compilation (`gradlew assembleDebug`):** BUILD SUCCESSFUL in 54s.
5. **Device Deployment:** Streamed install succeeded on Xiaomi Redmi Note 5 Pro (`e0d9da95`).
6. **Physical Device Visual Verification:** Screenshot confirmed `device_screen_my_brokers_fab.png` with FAB rendered live.

---

## 5. Security & Boundary Review

- **Database Schemas:** Untouched. No migrations were created or modified.
- **Sibling Apps:** `apps/rmbuyer_mobile` and `apps/rmbroker_mobile` remain 100% untouched.
- **Git Status:** Verified zero unrelated tracked file diffs.
