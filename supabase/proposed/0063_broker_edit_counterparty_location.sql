-- ============================================================================
-- Migration: 0063_broker_edit_counterparty_location.sql   (PROPOSED - not applied)
-- Sprint: RMBROKER-LOCATION-PERSISTENCE-E2E-03
-- Requires: 0055_company_warehouses.sql, 0060_crm_contacts_soft_removal.sql
--
-- A broker may edit a saved location only for a company in their active CRM
-- contacts, and may not move it to a company outside them. Delete is not granted.
-- ============================================================================

DROP POLICY IF EXISTS "company_warehouses_broker_update" ON public.company_warehouses;
CREATE POLICY "company_warehouses_broker_update" ON public.company_warehouses
FOR UPDAT# MICRO-SPRINT: RMBUYER-MANDATE-DETAILS-OVERFLOW-01

## Objective
Fix the Mandate Details screen opened from a requirement selected on the Buyer Home screen. The current screen shows a Flutter layout overflow (`RIGHT OVERFLOWED BY 17 PIXELS`) in the Commodity & Commercial Terms section.

## Reproduce
1. Open RMBuyer.
2. Open the current requirements section on Home.
3. Select an existing requirement.
4. Open its Mandate Details screen.
5. Inspect the Commodity & Commercial Terms card on a narrow Android device.

## Fix the UI
Inspect the actual widget tree and identify the overflowing Row or fixed-width layout.

Specifically:
- Commodity and Quality Grade must not compete for fixed horizontal space.
- Use responsive layout constraints.
- On narrow screens, stack Commodity and Quality Grade vertically or use a layout that wraps safely.
- Allow long commodity names and grade descriptions to wrap onto multiple lines.
- Ensure Target Quantity, Target Price, and Estimated Mandate Value also adapt to narrow widths. Use a responsive grid or stacked layout when necessary.
- Do not use hard-coded widths that exceed the available screen width.
- Preserve readable labels, spacing, typography, and card styling.
- Keep the entire screen vertically scrollable.
- Respect SafeArea and existing app theme.
- Do not shrink text to an unreadable size to hide the overflow.

## Data and Navigation
- Preserve the selected requirement ID and load its real details.
- Do not replace live requirement data with mock values.
- Preserve existing Back and Refresh behavior.
- Handle missing or unavailable requirement data with a clear error/empty state and a working Retry action.
- Do not navigate to a blank screen if the requirement cannot be loaded.

## Tests
Add or update widget tests for:
1. Long commodity name and long grade.
2. Narrow phone width.
3. Large text scale.
4. Missing grade or optional commercial fields.
5. Loading, error, and populated states.
6. Back and refresh behavior.

Run focused tests and `flutter analyze`. If feasible, run the existing Buyer widget/unit test suites without stashing or altering unrelated work.

## Scope and safety
- Make the smallest safe UI fix.
- Preserve existing uncommitted changes.
- Do not refactor unrelated screens.
- Do not modify database schema, RLS, grants, production data, or backend APIs.
- Do not commit, push, or deploy.

## Report
Create `docs/RMBUYER-MANDATE-DETAILS-OVERFLOW-01-REPORT.md` with:
- Root cause.
- Files changed.
- Responsive behavior implemented.
- Test results.
- Any remaining limitations.

Final status: PASS, PASS WITH LIMITATIONS, FAIL, or BLOCKED.E TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.crm_contacts cc
    WHERE cc.broker_id = auth.uid()
      AND cc.company_id = company_warehouses.company_id
      AND cc.removed_at IS NULL
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.crm_contacts cc
    WHERE cc.broker_id = auth.uid()
      AND cc.company_id = company_warehouses.company_id
      AND cc.removed_at IS NULL
  )
);
