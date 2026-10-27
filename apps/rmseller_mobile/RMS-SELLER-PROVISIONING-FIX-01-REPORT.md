# RMS-SELLER-PROVISIONING-FIX-01: Account Provisioning & Commodity Posting Fix

**Sprint Identifier:** `RMS-SELLER-PROVISIONING-FIX-01`  
**Application Target:** `apps/rmseller_mobile`  
**Status:** Verification Complete (Code Changes & Tests Verified; Database Migration Staged for Approval)  
**Date:** 2026-10-27  

---

## Executive Summary

When a seller completed the Post Commodity form and tapped **"Review & List Commodity"**, the application raised the blocking error:
> *"Your account is not yet provisioned in the database. Please contact support."*

This sprint investigated the root cause across both the Flutter client codebase and the Supabase database schema/RLS policies, resolved the account provisioning and readiness evaluation pipeline, preserved commodity draft state when navigating to profile completion, staged a secure and idempotent SQL migration, and verified all flows against unit and widget test suites.

---

## Step 1 — Root Cause Analysis & Failure Trace

### 1. The Action Chain
The exact sequence of events triggering the failure was traced as follows:
1. **User Action:** Seller enters commodity details in `PostCommodityScreen` and taps **"Review & List Commodity"** (`_openReview()`).
2. **Readiness Check:** `_openReview()` inspects `_readiness`, which was populated via `_loadReadiness()` calling `SellerProfileRepository.checkListingReadiness()`.
3. **Database Query:** In `SellerProfileRepository.checkListingReadiness()`:
   ```dart
   final user = await client
       .from('users')
       .select('id, name, role, status, company_id')
       .eq('id', session.user.id)
       .maybeSingle();
   ```
4. **Failure Condition:** If `user == null` (i.e. the authenticated user in `auth.users` has no matching row in `public.users`), the method returned:
   ```dart
   ListingReadiness.incomplete([
     'Your account is not yet provisioned in the database. Please contact support.',
   ]);
   ```
5. **UI Blocker:** `_openReview()` inspected `if (r.status != ListingReadinessStatus.complete)`, blocked navigation to `ReviewListingSheet`, and displayed a `SnackBar` with the error text. Furthermore, the UI provided no button or pathway to complete the profile.

### 2. Database & Identity Mapping Root Cause
1. **Missing Trigger:** In Supabase, user authentication records live in `auth.users`. However, business roles and seller data live in `public.users`. There is no trigger on `auth.users` to automatically insert or provision a corresponding row into `public.users` upon signup or phone authentication.
2. **RLS Insert Restriction:** RLS on `public.users` has policy `users_insert_policy`:
   ```sql
   CREATE POLICY users_insert_policy ON public.users
   FOR INSERT WITH CHECK (is_admin() OR (is_broker() AND ...));
   ```
   An authenticated user with role `seller` cannot directly insert their own record into `public.users` via PostgREST (doing so fails with PostgreSQL error `42501: permission denied`).
3. **Restricted RPC Function:** The existing database function `public.provision_individual_seller(target_auth_user_id uuid)` contains a strict admin check:
   ```sql
   IF NOT (public.is_admin() OR CURRENT_USER = 'postgres') THEN
     RAISE EXCEPTION '42501: Only administrators or postgres can provision individual sellers';
   END IF;
   ```
   Authenticated sellers could not self-provision via RPC without receiving a `42501` exception.
4. **Real Accounts Affected:** Inspection of the database identified registered seller accounts in `auth.users` that lacked `public.users` rows:
   - `seller.bikaner@gmail.com` (`4e21f195-2f3b-465d-94cc-e47eebd92800`)
   - `seller@demo.com` (`49534f2f-ec4e-445f-84e8-7d09c7056b6a`)

---

## Step 2 — Account Provisioning Implementation

### 1. Client-Side Idempotent Auto-Provisioning
In [seller_profile_repository.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/profile/data/seller_profile_repository.dart):
- Added `Future<bool> provisionCurrentSeller()`:
  - Invokes `client.rpc('provision_individual_seller', params: {'target_auth_user_id': session.user.id})`.
  - Ensures the user ID is strictly taken from `session.user.id` (never trusting client-supplied arguments).
  - Uses a `@visibleForTesting performProvisioning` hook so tests can mock or verify behavior reliably.
- In `checkListingReadiness()`:
  - When `user == null`, it automatically calls `await provisionCurrentSeller()`.
  - Re-queries `public.users` post-provisioning.
  - If still missing, returns an actionable message:
    `'Your account is not yet provisioned in the database. Please complete your profile to continue.'`
- In `getProfile()`:
  - Removed hardcoded fallback company records (`Bikaner Agro Processing Ltd`, `08AAAAA0000A1Z5`, etc.).
  - Hydrates profile attributes from `session.user.userMetadata` (name, phone, state, district).
  - Keeps `companyId` empty for Individual and Sole Proprietorship sellers, maintaining clean isolation between individual sellers and corporate accounts.
- In `updateProfile()`:
  - Verifies whether the `public.users` row exists. If absent, attempts `provisionCurrentSeller()` prior to saving updates, ensuring profile edits succeed even for newly onboarded accounts.

In [commodities_repository.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/commodities/data/commodities_repository.dart):
- In `_resolveSellerOwnershipOrNull()`:
  - When no `public.users` row is found, calls `_profileRepo.provisionCurrentSeller()` before evaluating fallback paths, enabling first-time sellers to seamlessly resolve their ownership identity.

### 2. Proposed SQL Migration (`0049_allow_seller_self_provisioning.sql`)
A migration has been staged at [0049_allow_seller_self_provisioning.sql](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/supabase/proposed/0049_allow_seller_self_provisioning.sql) to authorize authenticated sellers to provision themselves without admin intervention:

```sql
-- Migration: 0049_allow_seller_self_provisioning.sql
-- Purpose: Permit authenticated sellers to self-provision their own public.users record
-- Security: Restricted to auth.uid() = target_auth_user_id and role = 'seller'

CREATE OR REPLACE FUNCTION public.provision_individual_seller(
  target_auth_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_calling_user_id uuid;
  v_caller_role text;
  v_auth_record record;
  v_existing_user record;
  v_full_name text;
  v_phone text;
  v_email text;
BEGIN
  v_calling_user_id := auth.uid();

  -- Authorize: Either admin, postgres, or the caller provisioning their own seller account
  IF NOT (
    public.is_admin()
    OR CURRENT_USER = 'postgres'
    OR (v_calling_user_id IS NOT NULL AND v_calling_user_id = target_auth_user_id)
  ) THEN
    RAISE EXCEPTION '42501: Not authorized to provision this user';
  END IF;

  -- Verify target auth user exists
  SELECT id, email, phone, raw_user_meta_data
  INTO v_auth_record
  FROM auth.users
  WHERE id = target_auth_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION '40401: Auth user % not found', target_auth_user_id;
  END IF;

  -- Validate role is seller
  v_caller_role := COALESCE(
    v_auth_record.raw_user_meta_data->>'role',
    'seller'
  );

  IF v_calling_user_id = target_auth_user_id AND v_caller_role NOT IN ('seller', 'individual_seller') THEN
    RAISE EXCEPTION '42501: Only sellers can be provisioned via self-service';
  END IF;

  -- Idempotency check: Return existing profile if already provisioned
  SELECT id, name, role, company_id, status
  INTO v_existing_user
  FROM public.users
  WHERE id = target_auth_user_id;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'status', 'ALREADY_EXISTS',
      'user_id', v_existing_user.id,
      'role', v_existing_user.role,
      'has_company', (v_existing_user.company_id IS NOT NULL)
    );
  END IF;

  -- Resolve attributes
  v_full_name := COALESCE(
    v_auth_record.raw_user_meta_data->>'full_name',
    v_auth_record.raw_user_meta_data->>'name',
    split_part(COALESCE(v_auth_record.email, 'Seller'), '@', 1)
  );
  v_phone := COALESCE(
    v_auth_record.phone,
    v_auth_record.raw_user_meta_data->>'phone'
  );
  v_email := v_auth_record.email;

  -- Insert seller into public.users
  INSERT INTO public.users (
    id,
    name,
    email,
    phone,
    role,
    status,
    company_id,
    created_at,
    updated_at
  ) VALUES (
    target_auth_user_id,
    v_full_name,
    v_email,
    v_phone,
    'seller',
    'active',
    NULL,
    NOW(),
    NOW()
  );

  RETURN jsonb_build_object(
    'status', 'PROVISIONED',
    'user_id', target_auth_user_id,
    'role', 'seller',
    'has_company', false
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.provision_individual_seller(uuid) TO authenticated;
```

---

## Step 3 — Commodity Posting & Profile Completion UX

In [post_commodity_screen.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/commodities/presentation/post_commodity_screen.dart):
1. **Interactive Readiness Banner:**
   - When `_readiness.status == ListingReadinessStatus.incomplete`, the banner now renders an explicit **"Complete Profile"** button (`actionLabel: 'Complete Profile'`).
2. **Review Action Feedback:**
   - If a seller taps **"Review & List Commodity"** while profile fields remain missing, the error `SnackBar` presents an actionable **"Complete Profile"** `SnackBarAction`.
3. **Seamless Draft Preservation:**
   - Implemented `_openCompleteProfile()`:
     ```dart
     Future<void> _openCompleteProfile() async {
       await Navigator.of(context).push(
         MaterialPageRoute(
           builder: (ctx) => const SellerProfileScreen(isInitialEdit: true),
         ),
       );
       if (mounted) {
         await _loadReadiness();
       }
     }
     ```
   - Since `PostCommodityScreen` manages its input controllers in state memory, navigating to `SellerProfileScreen` and returning preserves:
     - Selected Commodity, Grade, and Variety
     - Quantity and Bag Size
     - Floor Price and Payment Terms
     - Warehouse Address, State, and District
     - Inspection and Delivery Dates
   - Upon return, `_loadReadiness()` automatically refreshes readiness; once complete, the seller can proceed to review and list immediately.
4. **Broker-Mediated Workflow Preserved:**
   - Verified that individual and company listings maintain broker assignment (`preferred_broker_id` or default mandi broker pool).
   - Direct seller-to-buyer contact details remain shielded behind the broker-mediated workflow.

---

## Step 4 — Regression Testing & Verification

### 1. Focused Unit Tests: `test/unit/seller_provisioning_test.dart`
All 8 test scenarios passed successfully:
1. **Existing seller with a valid company profile:** Passes readiness check and lists commodity under company ownership.
2. **Newly registered individual seller:** Auto-provisions seamlessly and completes readiness.
3. **Sole proprietor without company incorporation documents:** Posts as an individual seller (`seller_user_id` set, `company_id` null).
4. **Missing seller profile:** Returns actionable message guiding the user to "Complete Profile".
5. **Repeated provisioning idempotency:** Second provisioning invocation succeeds without duplicate rows or errors.
6. **Network failure during readiness check:** Returns clear unverified retry message without crashing.
7. **Unauthorized role (buyer):** Blocked by security constraint (`42501: Only sellers can be provisioned via self-service`).
8. **Broker assignment preservation:** Listing correctly assigns broker without exposing direct counterparty contact.

### 2. Session Recovery & Auth Tests: `test/unit/session_recovery_test.dart`
All 11 lifecycle scenarios passed (19/19 combined in suite):
- Expired tokens transparently recovered via `refreshSession`.
- Invalid refresh token safely routes to sign-in.
- RLS permissions errors (`42501`) properly distinguished from auth expiry.
- Submission locks prevent duplicate postings.
- Authentic database records always prioritized over demo fallbacks.

### 3. Widget & Interaction Tests: `post_commodity_screen_test.dart` & `post_commodity_ux04_test.dart`
- 24/24 widget tests passed.
- Verified collapse/expand behavior, validation of mandatory fields, live valuation badges, and navigation flows.

### 4. Static Code Analysis
- `flutter analyze lib test` ran with **0 errors**.
- Resolved unused imports and deprecations across the modified components.

---

## Step 5 — Proposed Database Action Plan (Approval Required)

Per the Zero-Friction Execution Policy, database modifications require explicit approval before applying:

### Action 1: Deploy RPC Function Update
- **Target File:** [0049_allow_seller_self_provisioning.sql](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/supabase/proposed/0049_allow_seller_self_provisioning.sql)
- **Effect:** Allows authenticated users with role `seller` to provision their matching `public.users` row via `provision_individual_seller(auth.uid())`.

### Action 2: Provision Existing Unlinked Accounts
Execute the following idempotent statements in the database:
```sql
SELECT public.provision_individual_seller('4e21f195-2f3b-465d-94cc-e47eebd92800'); -- seller.bikaner@gmail.com
SELECT public.provision_individual_seller('49534f2f-ec4e-445f-84e8-7d09c7056b6a'); -- seller@demo.com
```

---

## Modified Files Summary

| File | Change Summary |
|---|---|
| [seller_profile_repository.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/profile/data/seller_profile_repository.dart) | Added `provisionCurrentSeller()`, auto-provisioning hook in `checkListingReadiness()`, session metadata profile hydration, and eliminated hardcoded demo company fallbacks. |
| [commodities_repository.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/commodities/data/commodities_repository.dart) | Auto-provisions seller identity in `_resolveSellerOwnershipOrNull()` when unprovisioned. |
| [post_commodity_screen.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/commodities/presentation/post_commodity_screen.dart) | Added "Complete Profile" button to readiness banner and review snackbar; implemented draft-preserving navigation. |
| [0049_allow_seller_self_provisioning.sql](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/supabase/proposed/0049_allow_seller_self_provisioning.sql) | Staged secure `SECURITY DEFINER` RPC function permitting authenticated sellers to provision their own `public.users` record. |
| [seller_provisioning_test.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/test/unit/seller_provisioning_test.dart) | Added 8 comprehensive regression tests for provisioning, sole proprietors, unlinked accounts, and security constraints. |
| [fake_postgrest.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/test/support/fake_postgrest.dart) | Added RPC routing and mock RPC handler support for unit tests. |

---

## Manual Verification Steps

1. Launch `rmseller_mobile` with an account that has an `auth.users` login but no `public.users` profile (or newly signed-up seller).
2. Navigate to **Post Commodity Lot**.
3. Fill in commodity details (e.g., Mustard Seed, Grade A, 100 quintals, ₹5,400/quintal).
4. Tap **"Review & List Commodity"**:
   - If profile details were missing, observe the banner and SnackBar prompting **"Complete Profile"** (instead of the dead-end "contact support" message).
5. Tap **"Complete Profile"**:
   - Verify you are navigated to the Seller Profile screen.
   - Enter your name, phone number, and location (no company incorporation required for individuals).
   - Save profile and return.
6. Observe that all previously entered commodity lot fields remain intact.
7. Tap **"Review & List Commodity"**:
   - The Review sheet opens smoothly without the provisioning error.
8. Tap **"Confirm & List Commodity"**:
   - Listing is published under the authenticated seller's ID with broker assignment.
