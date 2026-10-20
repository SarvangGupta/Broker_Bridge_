# RB-REQ-FREEZE-01 — Requirement Card Freeze: Root-Cause Investigation, Fix & Verification Report

**Sprint Reference:** RB-REQ-FREEZE-01  
**Target Application:** RMBroker (Flutter mobile app — `apps/rmbroker_mobile`)  
**Status:** Complete & Verified  

---

## 1. Executive Summary

A critical freeze occurred in the RMBroker application when interacting with requirement cards on the Active Work Desk (`/work`). Tapping on a requirement card either caused the screen to become unresponsive or blocked users from navigating between tabs or selecting other mandates.

Through static analysis, widget lifecycle tracing, and live device inspection, three primary root causes were identified:
1. **Unmounted Context & Race Condition in Bottom Sheet Transition**: In `requirement_detail_sheet.dart`, clicking "Initiate Negotiation & Submit Proposal" dismissed the detail sheet via `pop()`, then attempted to open `NegotiateRequirementSheet` after a fixed 150ms delay using the now-unmounted `context`. Furthermore, the `_isOpeningSheet` mutex guard in `work_screen.dart` was not released between the detail sheet dismissal and the subsequent sheet invocation, deadlocking the opening mechanism.
2. **Global Modal Barrier Ingestion (`useRootNavigator: true`)**: Pushing bottom sheets to the root navigator created full-screen modal barriers that covered the entire `NavigationShell` (including bottom navigation tabs and top app bars). Any pending transition or network wait completely intercepted pointer gestures across the entire application.
3. **15-Second Connect Timeout on Unreachable REST API**: `ApiClient` defaulted to a 15-second connection timeout against `localhost:3001`. On real physical devices where local development servers are offline, network probes blocked UI resolution for 15 seconds before falling back to Supabase.

All defects were resolved with zero modification to the Buyer or Seller applications. All 252 tests pass, and zero analyzer issues remain.

---

## 2. Root Cause Analysis

### A. Lifecycle Violation & Stale BuildContext
In `apps/rmbroker_mobile/lib/features/work/presentation/widgets/requirement_detail_sheet.dart`:
```dart
onPressed: () async {
  // Pop detail sheet first so modal sheets don't stack and conflict
  Navigator.of(context, rootNavigator: true).pop();
  await Future.delayed(const Duration(milliseconds: 150));
  if (context.mounted) {
    await NegotiateRequirementSheet.show(context, requirement: requirement);
  }
},
```
- `context` belonged to the `RequirementDetailSheet` widget element inside the modal route.
- Popping the sheet immediately unmounted the element.
- After the 150ms delay, `context.mounted` was guaranteed to be `false`, completely aborting the call to `NegotiateRequirementSheet.show`.
- If invoked without the mounted check, looking up the deactivated ancestor threw a framework assertion, leaving the router in an unstable state.

### B. Mutex Deadlock in `WorkScreen`
In `apps/rmbroker_mobile/lib/features/work/presentation/work_screen.dart`:
```dart
Future<void> _openRequirementDetail(RequirementItem req) async {
  if (_isOpeningSheet) return;
  _isOpeningSheet = true;
  try {
    await RequirementDetailSheet.show(...);
  } finally {
    if (mounted) _isOpeningSheet = false;
  }
}
```
If the detail sheet attempted to invoke `_openNegotiateRequirement(req)` before `_openRequirementDetail` exited its `try` block, the mutex check `if (_isOpeningSheet) return;` immediately aborted, dropping the user action silently.

### C. Root Navigator Scope vs. Stateful Shell Branch
- In `AppRouter`, bottom tabs (`Home`, `Work Desk`, `Deals`, `Directory`, `More`) are managed inside `StatefulShellRoute.indexedStack`.
- Adding `useRootNavigator: true` to bottom sheets forced modal routes above the `StatefulShellRoute`.
- The resulting `ModalBarrier` consumed all touch events for the entire screen, freezing the bottom navigation bar and preventing users from switching tabs.
- Scoping bottom sheets to the local branch navigator (`useRootNavigator: false`, default) preserves bottom tab access and cleanly isolates modal lifecycle within the Work Desk.

### D. Unbounded REST Probe Timeout
In `work_repository.dart`, `getRequirementNegotiationDetails` called `_apiClient.get(...)` with only `sendTimeout` and `receiveTimeout` specified in `Options`. The `connectTimeout` defaulted to `AppConfig.connectTimeout` (15 seconds). On mobile devices with no local dev server running on port 3001, the repository stalled the UI for 15 seconds before reaching the Supabase fallback.

---

## 3. Implementation Details

### 1. Structured Action Enum Return (`requirement_detail_sheet.dart`)
Replaced the ad-hoc pop-and-delay pattern with a clean, decoupled result pattern:
```dart
enum RequirementDetailAction {
  negotiate,
  findMatches,
}
```
- When the user taps "Initiate Negotiation & Submit Proposal":
  `Navigator.of(context).pop(RequirementDetailAction.negotiate);`
- When the user taps "Find Matching Offers":
  `Navigator.of(context).pop(RequirementDetailAction.findMatches);`
- `RequirementDetailSheet.show` now returns `Future<RequirementDetailAction?>`.
- Removed `useRootNavigator: true` from `showModalBottomSheet`.

### 2. Lifecycle Coordination in `WorkScreen` (`work_screen.dart`)
```dart
Future<void> _openRequirementDetail(RequirementItem req) async {
  if (_isOpeningSheet) return;
  _isOpeningSheet = true;
  RequirementDetailAction? action;
  try {
    action = await RequirementDetailSheet.show(
      context: context,
      requirement: req,
      onFindMatches: () => _onFindMatchesForRequirement(req),
    );
  } finally {
    if (mounted) {
      _isOpeningSheet = false;
    }
  }

  if (!mounted) return;

  if (action == RequirementDetailAction.negotiate) {
    await _openNegotiateRequirement(req);
  } else if (action == RequirementDetailAction.findMatches) {
    _onFindMatchesForRequirement(req);
  }
}
```
- The `try-finally` block for `_isOpeningSheet` strictly wraps the detail sheet lifecycle.
- Once the detail sheet is dismissed, `_isOpeningSheet` is guaranteed reset to `false`.
- If `action == RequirementDetailAction.negotiate`, `_openNegotiateRequirement(req)` is invoked on `WorkScreen`'s valid, permanently mounted context.
- Removed `_checkInitialRequirement` which previously forced auto-selection of requirements on startup.

### 3. Local Navigator Scoping Across Work Desk
Removed `useRootNavigator: true` from:
- `RequirementDetailSheet.show`
- `NegotiateRequirementSheet.show`
- `OfferDetailSheet.show`
- `CreateRequirementSheet.show`
- `CreateOfferSheet.show`
- `CreateAllocationSheet.show`

All sheets now mount within the active tab branch (`_workNavigatorKey`), preventing global barrier lockups.

### 4. Fast-Fail REST Probe (`work_repository.dart`)
Added strict 1000ms timeouts with a 1200ms future timeout on `getRequirementNegotiationDetails`:
```dart
final res = await _apiClient.get(
  '/broker/requirements/$requirementId/proposal',
  options: Options(
    receiveTimeout: const Duration(milliseconds: 1000),
    sendTimeout: const Duration(milliseconds: 1000),
  ),
).timeout(const Duration(milliseconds: 1200));
```
Unreachable REST endpoints instantly fall back to Supabase direct queries within 1.2s without freezing the interface.

---

## 4. Verification and Test Results

### A. Static Analysis
Command: `flutter analyze`  
Result: **No issues found! (ran in 5.2s)**

### B. Automated Tests
Command: `flutter test test/features/work/work_desk_tap_test.dart`  
Targeted test steps executed:
- STEP 1: Verify Work Desk rendered with requirement cards
- STEP 2: Tap first requirement card (`RBTEST Frontier Starch Processing`)
- STEP 3: Verify `RequirementDetailSheet` appears
- STEP 4: Close sheet via X button
- STEP 5: Verify sheet is dismissed
- STEP 6: Tap second requirement card (`RBTEST Golden Harvest Flour Mills`)
- STEP 7: Verify second `RequirementDetailSheet` appears
- STEP 8: Close second sheet
- STEP 9: Verify second sheet closed
- STEP 10: Tap direct Proposal button on requirement card
- STEP 11: Verify `NegotiateRequirementSheet` appears
- STEP 12: Close negotiation sheet
- STEP 13: Verify negotiation sheet dismissed
- STEP 14: Tap first card again to open detail sheet
- STEP 15: Tap "Initiate Negotiation & Submit Proposal" button inside detail sheet
- STEP 16: Verify detail sheet cleanly dismissed and `NegotiateRequirementSheet` opened
- STEP 17: Close negotiation sheet
- STEP 18: Tap "Offers" tab and verify tab switch
- STEP 19: Tap "Match Center" tab and verify tab switch
- STEP 20: Tap "Requirements" tab and verify tab switch
- STEP 21: Done — all transitions verified successfully  
Result: **All tests passed!**

Command: `flutter test`  
Result: **All 252 tests passed!**

### C. Physical Device Verification
- Device: Xiaomi Redmi Note 5 Pro (`e0d9da95`, Android 9).
- Built debug APK: `flutter build apk --debug` (30.2s).
- Streamed Install via `adb -s e0d9da95 install -r build\app\outputs\flutter-apk\app-debug.apk`: **Success**.
- Screen capture confirmed clean launch to Home dashboard with responsive bottom navigation bar and zero unhandled exceptions.

---

## 5. Scope Confirmation
- Modified only `apps/rmbroker_mobile`.
- **Zero changes** made to `apps/rmbuyer_mobile` or `apps/rmseller_mobile`.
- Backend contracts and security policies preserved.
