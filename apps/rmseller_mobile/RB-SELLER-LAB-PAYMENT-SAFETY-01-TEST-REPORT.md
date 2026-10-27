# RB-SELLER-LAB-PAYMENT-SAFETY-01 — Test Report

All commands were run from `apps/rmseller_mobile` with `D:\flutter_sdk\flutter\bin\flutter.bat`. No real payments were made and no payment provider was contacted. The only production access was read-only grant and policy inspection.

## 1. Commands and outcomes
| # | Command | Passed | Failed | Skipped | Notes |
|---|---|---|---|---|---|
| 1 | `flutter test test/unit/lab_payment_safety_test.dart test/widgets/post_commodity_screen_test.dart` (first) | 22 | 1 | 0 | The new widget test hung in `pumpAndSettle`: `url_launcher` never completes under the test binding |
| 2 | Same, with `UrlLauncherPlatform` stubbed in that test | 22 | 1 | 0 | The result SnackBar was queued behind "UPI app opened…"; the test now waits for the first to expire |
| 3 | Same | **23** | 0 | 0 | |
| 4 | `flutter test --reporter expanded` (**full suite**) | **225** | **15** | 0 | |
| 5 | `flutter analyze lib test` | — | — | — | **0 errors** outside the 3 test files that already fail to compile; no warnings or infos in the changed files |
| 6 | `flutter build apk --debug` | — | — | — | **Built** (not installed) |

**Against the previous baseline (217 / 15):**
- +8 new tests, all passing.
- The **same 15 failing tests by name**, unrelated to this sprint: 3 compile-error files; auth ×2, negotiation ×4, invoice ×2, rate-broker ×2, sales-history ×2.
- **0 new failures.**

## 2. New tests
**`test/unit/lab_payment_safety_test.dart`** (7):

| Test | Requirement |
|---|---|
| arbitrary UPI reference with simulate=true stays pending | Arbitrary reference cannot verify; simulate cannot verify in app builds |
| the request's own reference cannot verify itself either | Same, using the generated reference |
| client-side ledger hook is ignored outside the test sandbox | The in-app ledger cannot be used to fake confirmation |
| unverified payment cannot trigger the paid admin notification | Unverified payments cannot unlock paid-lab actions |
| repeated checks stay pending (no drift to verified) | Pending stays unverified |
| *(sandbox)* failed confirmation stays pending | Failed payments stay unverified |
| *(sandbox)* a confirmed entry verifies and only then notifies | The existing verified path still works when genuinely confirmed |

**`test/widgets/post_commodity_screen_test.dart`** (+1): *UPI payment check stays pending; label never claims verified*.
- Lab testing on → Pay via UPI (stubbed launcher) → "Payment Verification Pending" with the accurate explanation.
- Check Status → "Payment not confirmed yet…".
- **"Paid — Payment Verified" and "Payment verified" never appear.** UI labels match the actual (pending) status.

## 3. Limits of the evidence
- **`kReleaseMode` cannot be true inside `flutter test`.** The release-build guarantee comes from the code: no app call site passes simulate any more, and the sandbox also requires the `@visibleForTesting` flag.
- **No genuine server-side verification exists to test.** The "verified path still works" test uses the test-only sandbox.
- **No device run.** The build was not installed.

## Status: **PASS WITH LIMITATIONS**
- The false verification is removed client-side. The server never persisted it (grants block it; verified read-only).
- Real payment verification remains **unavailable** (see the implementation report §4).
