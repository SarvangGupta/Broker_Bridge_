# RB-SELLER-LAB-PAYMENT-SAFETY-01 — Implementation Report

**App:** `apps/rmseller_mobile` · **Date:** 2026-10-27

## 1. Trace (Phase 1)
| # | Question | Finding |
|---|---|---|
| 1 | Where was simulate mode enabled? | `PostCommodityScreen` passed `simulateSandboxVerification: true` in **two** places: the "Check Status" handler (`_handleVerifyUpiPayment`), and the post-submit re-verification for the real lot (`_handleSubmit`). |
| 2 | Active in release builds? | **Yes.** It was hard-coded, with no build-mode check. |
| 3 | How a UPI reference became "paid" | `LabTestingRepository.verifyPaymentWithBackend` looks the reference up in `_trustedTransactionLedger`, a **static in-memory map inside the app**, not a backend. With simulate on, any unknown reference was written as `true`, and the request became `paidVerified`. |
| 4 | Where "Paid — Payment Verified" was shown or persisted | Shown by `_buildPaymentActionCard` and the review row "Lab Payment Status". Locally the request was marked `paidVerified` + `adminNotified`. **Persistence attempted:** a `lab_tests` insert/update ("UPI Payment Verified", status "Testing In Progress") and an admin `notifications` insert ("Seller paid ₹…"). |
| 5 | Does paid status authorise paid services? | Client-side it triggers the `lab_tests` record (testing in progress) and the admin "paid" notification. Report retrieval keys off `lab_tests.status = 'Report Uploaded'/'Verified'` + `file_url` (admin-set). |
| 6 | Server or client enforced? | **Client only.** There is no server-side payment verification: no gateway, no webhook, and no readable settlement record (a `payments` table exists but is not used by this flow). |

**Live server check** (read-only, project `imztlkvkxzeaekxvmcfe`):

| Table | RLS | Grants to `authenticated` | Effect |
|---|---|---|---|
| `lab_tests` | on | only REFERENCES, TRIGGER, TRUNCATE (**no SELECT/INSERT/UPDATE**); 0 rows | The false "verified" record **could not be written**; the error was swallowed |
| `notifications` | on | SELECT, UPDATE, REFERENCES, TRIGGER, TRUNCATE (**no INSERT**) | The false "Seller paid" notification **could not be written** |

**Root cause:** a hard-coded sandbox flag over a client-side ledger turned any UPI reference into "Paid — Payment Verified".
- The **impact in production was client-side**: a false "Payment confirmed by backend!" message and a "Paid — Payment Verified" label.
- The server writes that would have made it authoritative were already blocked by grants.

## 2. Fix (Phase 2): smallest safe change
| File | Change |
|---|---|
| `lib/features/commodities/data/lab_testing_repository.dart` | See below |
| `lib/features/commodities/presentation/post_commodity_screen.dart` | See below |

**`lab_testing_repository.dart`:**
- New `@visibleForTesting static bool allowSandboxVerificationForTests` (default `false`).
- The sandbox is honoured **only if** `!kReleaseMode && allowSandboxVerificationForTests`.
- `verifyPaymentWithBackend` ignores both the in-app ledger and `simulateSandboxVerification` unless the test sandbox is enabled. In the app a check therefore always returns **`paymentPending`**.
- `registerTrustedBackendConfirmation` is now `@visibleForTesting` and a no-op outside the test sandbox.
- The existing idempotency, already-paid handling, admin-notify-only-after-paid rule and report retrieval are unchanged.

**`post_commodity_screen.dart`:**
- Removed `simulateSandboxVerification: true` from both call sites.
- Corrected the user-facing text:
  - Success SnackBar: "Payment verified. Testing request submitted." (no "by backend" claim). It is now reachable only via a genuine confirmation.
  - Pending SnackBar: "Payment not confirmed yet. UPI payments must be verified by the RMBroker team before lab testing starts; your request stays pending until then."
  - Pending card text: replaced "Verification is performed by the trusted backend. Status is checked automatically." (**both false**) with an accurate explanation.

Not changed: the UPI deep-link launch, the rate card, report retrieval, `attachReportAsAdmin`, the database, RLS and grants.

## 3. Result
- A UPI reference alone **can no longer** produce a verified payment, in any build.
- Unverified requests stay **pending**. The "Paid — Payment Verified" label, the success message, the `lab_tests` write and the admin "paid" notification are unreachable without genuine confirmation.
- A genuinely verified path still works in principle (tested via the test-only sandbox). **No production mechanism can supply that confirmation today.**

## 4. Remaining server-side risks and blockers (not changed; protected)
1. **There is no authoritative payment verification at all.**
   - As a result, a seller who really pays can never see "verified" in the app, and nothing reaches the admin (`lab_tests` and `notifications` writes are denied to sellers).
   - **Paid lab testing cannot complete end to end** until one of these exists (needs a product and backend decision):
     1. a gateway or merchant webhook writing a settlement record,
     2. an admin verification flow, or
     3. a server RPC (`SECURITY DEFINER`) that checks a real settlement table.
2. **Pending requests never reach the server.** Requests live only in an in-app static map, so they are lost on restart, and the team cannot see them to verify. Needs a server-side lab request record (a seller INSERT policy on `lab_tests` with status `Awaiting Payment`, or an RPC). Schema/RLS work, needs approval.
3. **`authenticated` holds TRUNCATE** on `lab_tests` and `notifications` (also seen on `availabilities`). PostgREST does not expose TRUNCATE, but as hardening, `REVOKE TRUNCATE … FROM authenticated` is recommended. Needs approval.
4. **`brokerbridge_lab_evidence` storage** lets any authenticated user upload to any path (from INTEGRITY-02).

## 5. Was production safety verified?
- **Client side:** yes, by tests and code. The simulate path is gone from all app call sites and is inert in release builds.
- **Server side:**
  - Verified **read-only** that sellers cannot write verified `lab_tests` rows or admin notifications.
  - **Not verified:** any end-to-end payment, since no real payments may be made and no gateway exists.
- **Not deployed:** this build is not installed on any device.
