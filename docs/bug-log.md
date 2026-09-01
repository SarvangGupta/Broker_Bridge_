# BrokerBridge Bug & Resolution Log

This document tracks UI/UX anomalies, architectural logic bugs, and their eventual resolutions to ensure institutional knowledge is preserved and regressions are avoided.

## Sprint 14.5 - Active Inventory Edit Button Omission
- **Issue:** On the Seller Inventory Dashboard, the cards for `Active` and `Open` inventory lots initially only exposed a "Cancel Listing" action. Sellers had no physical button to click to trigger an "Edit" or update flow.
- **Root Cause:** In the initial sprint UI pass, the `inventory-card.tsx` (and `my-availabilities-table.tsx`) components only mapped the `cancelAvailabilityAction`. The necessity of standard updates (price adjustments) and concurrency testing required an explicit Edit flow.
- **Resolution:** 
  1. Injected an "Edit Listing" button alongside the "Cancel" button, gated to only show for `Active` or `Open` statuses. 
  2. Directed the Edit button to open the `post-availability-dialog.tsx` with an `?edit=[id]` URL parameter.
  3. Encountered multiple secondary bugs:
     - Frontend validation silently failed because the hidden `version` integer field defaulted to a string; resolved by enforcing `{ valueAsNumber: true }` in `react-hook-form`.
     - The backend action `updateAvailabilityAction` mapped frontend keys (e.g. `total_quantity`) to Drizzle without transforming them to camelCase, resolved by standardizing Drizzle `set` mapping.
     - The `id` and `version` scoping references were briefly lost from the `WHERE` clause during the mapping refactor.
     - The `getAvailabilityForEditAction` server action was originally created but omitted from export.
  4. Fully restored the Edit state, keeping all master data cascading dropdowns unlocked so the Seller can fluidly modify the entire supply contract.
