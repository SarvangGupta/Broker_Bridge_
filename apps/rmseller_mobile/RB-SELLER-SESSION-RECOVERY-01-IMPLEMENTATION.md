# RB-SELLER-SESSION-RECOVERY-01 — Implementation Report: Fix Expired Session and Seller Desk Access

**Date:** 2026-10-27  
**Repository:** `apps/rmseller_mobile`  
**Target Environment:** Authoritative Supabase Backend (`imztlkvkxzeaekxvmcfe.supabase.co`)  
**Sprint Identifier:** `RB-SELLER-SESSION-RECOVERY-01`

---

## 1. Executive Summary

This sprint resolves the recurring and disruptive **"Your session has expired. Please sign in again."** failure condition experienced by sellers navigating to the **Seller Desk** dashboard or attempting to **Post Commodity Lot**.

Previously, any access token expiration (standard 1-hour JWT lifetime) or PostgREST `PGRST301` ("JWT expired") response caused immediate termination with hardcoded error strings, destructive erasure of local secure storage tokens, and forced sign-outs. Furthermore, concurrent dashboard queries triggered racing refresh calls that violated Supabase Gotrue's single-use refresh token rotation policy, invalidating valid refresh tokens.

We have engineered an **in-flight deduplicated session recovery pipeline** using authoritative Supabase client behaviors (`recoverSession` with static mutex), transparent automatic retries for single safe reads, non-destructive network error isolation, graceful dashboard section degradation, and posting form state preservation.

---

## 2. Root Cause Analysis

Investigation identified four distinct architectural root causes in the Seller app:

### 2.1 Hardcoded Expiry Abort in Repositories
- **CommoditiesRepository (`_resolveSellerOwnershipOrNull`):**
  ```dart
  // PREVIOUS DEFECTIVE CODE:
  if (session == null || session.isExpired) {
    throw Exception('Your session has expired. Please sign in again.');
  }
  ```
  Even though a valid refresh token existed in the Supabase client and device storage, the repository aborted before attempting a token refresh.
- **SellerProfileRepository (`checkListingReadiness`):**
  ```dart
  // PREVIOUS DEFECTIVE CODE:
  if (session == null || session.isExpired) {
    return ListingReadiness.unverified('Your session has expired. Please sign in again.');
  }
  ```
  Immediately locked sellers out of posting without initiating a recovery cycle.

### 2.2 Destructive Storage Wiping on App Launch
- **AuthRepository (`getSavedUser`):**
  When the app booted or returned from background, if Supabase's in-memory session had not yet finished rehydrating (`sessionUserId == null || sessionUserId != userId`), `AuthRepository` executed `await _storage.clearAll();`. This aggressively wiped valid credentials and refresh tokens from `SecureStorageService`, forcing an unnecessary manual re-login.

### 2.3 Gotrue Single-Use Refresh Token Rotation Collision
- Supabase Gotrue uses single-use refresh tokens that rotate on every refresh.
- On Seller Desk launch, `seller_home_screen.dart` simultaneously triggered commodities loading (`getMyCommodities`) and deals loading (`getSellerDeals`).
- If the access token was expired, both queries simultaneously attempted `client.auth.refreshSession()`.
- The first request rotated the refresh token; the second in-flight request presented the now-invalidated token, causing Gotrue to return `invalid_grant` / `token revoked` and destroy the seller's valid session.

### 2.4 Conflation of Network Errors and RLS Failures with Expiry
- Offline drops, timeouts, and authorization/RLS violations (`42501`) were treated generically or led to cascades displaying the "session expired" card, misleading users and purging offline credentials.

---

## 3. Architecture & Implementation Details

### 3.1 Deduplicated In-Flight Session Recovery Mutex (`AuthRepository`)
In `apps/rmseller_mobile/lib/features/authentication/data/auth_repository.dart`:
- Introduced enum `SessionRecoveryState { valid, recovered, unrecoverable, networkError }`.
- Added static mutex future `static Future<SessionRecoveryState>? _inFlightRecovery;`:
  ```dart
  Future<SessionRecoveryState> recoverSession({bool force = false}) async {
    final inFlight = _inFlightRecovery;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _executeRecovery(force: force);
    _inFlightRecovery = future;
    try {
      return await future;
    } finally {
      _inFlightRecovery = null;
    }
  }
  ```
  **Concurrency Safety:** If 5 parallel requests detect an expired session, exactly 1 network refresh is dispatched to Supabase Auth. All 5 awaiters resolve the same recovered session with zero token rotation collisions.

### 3.2 Non-Destructive Offline Handling & Secure Storage Sync
- Differentiates transport exceptions (`SocketException`, `HttpException`, `TimeoutException`) from `AuthException`:
  - On network failures: returns `SessionRecoveryState.networkError` and **preserves** stored refresh tokens and cached user profiles.
  - On terminal auth revocation (`invalid_grant` / `refresh_token_not_found`): safely invokes `_storage.clearAll()` and returns `SessionRecoveryState.unrecoverable`.
- On successful refresh: writes updated `access_token` and `refresh_token` to `SecureStorageService`.

### 3.3 PostgREST PGRST301 Single-Retry Interception
Both `CommoditiesRepository` and `SellerProfileRepository` wrap database read operations:
- If PostgREST returns `PGRST301` / `JWT expired`:
  1. Triggers `authRepository.recoverSession(force: true)`.
  2. If recovered successfully, executes a **single safe read retry**.
  3. If unrecoverable, rethrows a clean `SessionRecoveryException` without infinite loops.

### 3.4 Seller Desk Resilience (`SellerHomeScreen`)
In `apps/rmseller_mobile/lib/features/home/presentation/seller_home_screen.dart`:
- Decoupled `getMyCommodities()` and `getSellerDeals()` into independent async futures so a failure in deals does not blank out commodities or lock the dashboard.
- Removed hardcoded demo firm fallback (`'Bikaner Agro Traders'`), displaying authentic seller firm or default `'Seller Desk'`.
- If an expired session is detected, automatically triggers `recoverSession()` on user-initiated "Try Again".
- For terminal session loss, renders `AppErrorState` with explicit `Sign In` action navigating via `AppRouter.authNotifier.setUnauthenticated()`.

### 3.5 Post Commodity Lot Form State Preservation (`PostCommodityScreen`)
In `apps/rmseller_mobile/lib/features/commodities/presentation/post_commodity_screen.dart`:
- When readiness check detects an expired session, `_buildReadinessCard` renders a specialized warning:
  - Title: **"Session Expired"**
  - Message: *"Your session needs to be refreshed before posting can proceed."*
  - Action Button: **"Sign In Again"**
- **Form Preservation:** All user inputs (commodity choice, variety, grade, quantity, lot number, bag size, pricing, delivery terms, and lab test documents) remain preserved in memory and controllers; nothing is cleared or discarded during recovery.
- Submission mutex prevents double-posts if a network hiccup or session retry occurs during active listing submission.

---

## 4. Modified Files

| File | Changes Made |
| :--- | :--- |
| `lib/features/authentication/data/auth_repository.dart` | Added `SessionRecoveryState`, static `_inFlightRecovery` deduplication mutex, `recoverSession()`, safe `getSavedUser()` bootstrap, token synchronization with `SecureStorageService`. |
| `lib/features/commodities/data/commodities_repository.dart` | Replaced hardcoded session expiry check with `recoverSession()`, added `PGRST301` force-refresh retry. |
| `lib/features/profile/data/seller_profile_repository.dart` | Integrated session recovery in `checkListingReadiness()`, added `PGRST301` catch-and-retry. |
| `lib/features/home/presentation/seller_home_screen.dart` | Removed demo firm fallback, isolated deals from commodities loading, added recovery trigger on error retry, added terminal sign-in button. |
| `lib/features/commodities/presentation/post_commodity_screen.dart` | Form preservation during recovery, specialized session expired readiness card with direct sign-in CTA. |
| `lib/features/commodities/presentation/my_commodities_screen.dart` | Added expired session detection with direct sign-in button on error state. |
| `lib/core/widgets/app_error_state.dart` | Added configurable `retryLabel` (defaults to `'Try Again'`). |
| `test/support/fake_postgrest.dart` | Added loopback auth handler and token refresh simulation. |
| `test/unit/session_recovery_test.dart` | Added 11 focused test scenarios covering full recovery, deduplication, offline behavior, RLS distinction, and form safety. |
| `test/widgets/route_guard_test.dart` | Updated test harness to use `_MockGoRouterState` and `SellerUser` model. |
| `test/widgets/broker_rating_display_test.dart` | Fixed invalid `const` instantiation. |

---

## 5. Security & Isolation Guarantees

1. **No Token Logging:** Access and refresh tokens are strictly passed through secure channels and never logged in debug logs or analytics.
2. **Trusted Seller Ownership:** Authenticated seller identity (`auth.uid()`) continues to be authoritative. No demo accounts, simulated user IDs, or company bypasses were introduced.
3. **Safe Rotation:** By serializing refresh requests through `_inFlightRecovery`, token reuse detection is completely eliminated.
