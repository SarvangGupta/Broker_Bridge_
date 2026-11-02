# RMBUYER-MANDATE-DETAILS-OVERFLOW-01 — Report

**Date:** 2026-11-02 · **Branch:** feature/broker-nilesh (uncommitted)
**Final status: PASS WITH LIMITATIONS**

## Root cause
`RequirementDetailsScreen` (`apps/rmbuyer_mobile/lib/features/requirements/presentation/requirement_details_screen.dart`) built the *Commodity & Commercial Terms* card from plain `Row(mainAxisAlignment: spaceBetween)` widgets whose children were unconstrained `Column`s (`_buildMetricItem`). A `Row` gives non-flex children unbounded width, so the label/value `Text` never wrapped. Commodity + Quality Grade (and the 3-cell Quantity / Price / Est. Value row) exceeded the card width on narrow phones → `RIGHT OVERFLOWED BY 17 PIXELS`.

## Files changed
| File | Change |
|---|---|
| `apps/rmbuyer_mobile/lib/features/requirements/presentation/requirement_details_screen.dart` | New `_buildMetricGrid` (LayoutBuilder + Wrap); metric rows use it; empty commodity/grade shows `—`; fulfilled % guarded against quantity 0; status header, Broker Offers header, timeline header and timeline event title rows made flexible (`Expanded`/`Flexible`/`Wrap`) |
| `apps/rmbuyer_mobile/test/widgets/requirement_details_overflow_test.dart` | New — 9 widget tests with an offline fake repository |

No changes to data loading, routing, repository, schema, RLS or backend.

## Responsive behaviour
- Metric grid picks the column count from available width: `floor((width + 16) / (130 × textScale + 16))`, clamped to 1…N items. Every cell gets an equal explicit width, so long values wrap onto multiple lines.
- 320 dp phone: Commodity and Quality Grade stack vertically; Quantity / Price / Value stack too.
- ~360–420 dp: 2 columns. Tablet/wide: all items on one line.
- Large text scale raises the minimum cell width, so columns drop out before text gets squeezed. Font sizes are unchanged.
- Card styling, spacing, theme, `SafeArea`, `SingleChildScrollView` + pull-to-refresh are unchanged.
- Data and navigation are unchanged: same `requirementId` load, AppBar Back (`context.pop()`), Refresh, existing `AppErrorState` with Retry, and the "Requirement Not Found" empty state.

## Tests
New `requirement_details_overflow_test.dart` (9/9 pass):
1. Long commodity and grade on 320 dp: no exception, stacked layout.
2. 2.0× text scale at 360 dp: no overflow.
3. 800 dp wide: side-by-side layout.
4. Blank grade and missing optional fields: `—`, optional rows hidden.
5. Loading, then populated.
6. Error, then Retry reloads (2 loads) and populates.
7. Not found: empty state, not blank.
8. Refresh reloads the same ID.
9. Back pops to the previous GoRouter route.

Existing `requirement_details_screen_test.dart`: 5/5 pass.
`flutter analyze`: **No issues found.**

Broad run `flutter test test/widget_test.dart test/widgets test/unit`: **523 passed, 4 skipped, 3 failed.** The 3 failures are in files this sprint did not touch:
- `chat_screen_test.dart`: the known hard-coded-date "Today" failure.
- `gst_draft_continue_regression_test.dart` scenario 7.
- `profile_screen_test.dart`: pending GST record shown as Verified.

The integration tests that write live rows were **not** run.

## Limitations
- I did not check on a physical device. The overflow fix is verified by widget tests at 320 dp, 360 dp with 2× text, and 800 dp.
- I did not confirm that the new tests fail against the pre-fix code, because stashing was out of scope.
- I did not investigate the 2 GST/profile failures, and I did not compare them with HEAD in this sprint.
