# RB-SELLER-QUICK-POST-01 — Implementation Report

## 1. Profile completeness (implemented)
`SellerProfileRepository.checkListingReadiness()` reads the **server**: session → `users.company_id` → `companies(name, gst, state_id, district_id)`.

| Result | When | Screen |
|---|---|---|
| **complete** | Linked firm with a name | No blocking step. The firm's registered region becomes the default warehouse state and district if no warehouse is saved on the device |
| **incomplete** | No company link, firm row missing or unreadable, or empty name | Red card with the specific item ("…not linked to a business (firm). Please contact support."). Listing blocked. These cannot be fixed in the app; no fields are invented |
| **unverified** | Network or server error, or no session | Red card **"Could not verify your business profile"** with **Retry**. **Never treated as first-time or incomplete.** Listing blocked until verified. Form values kept |

The warehouse part is checked on the lot itself:
- **Missing state, district or address:** an amber card. It is titled **"Complete your business details once"** for a first-time seller and **"Add your warehouse location"** for a returning one. It lists **only** the missing items and has an **Add warehouse location** button.
- **That button** opens the existing location sheet **prefilled** (new `highlightMissing` mode: the form validates on open, so only empty required fields are flagged). GPS is not required; manual entry works.
- **On save:** the sheet closes back to the same in-progress lot (state kept). If no device default existed, the warehouse is saved **once** as this device's business location (`saveBusinessLocationDefault`, the same keys the profile screen uses). Only the warehouse is saved, never a separate loading or office address.
- **Before review:** completeness is re-checked (`_locationComplete` now includes the address), and the server readiness must be **complete**. The server re-verifies the company on insert (`_requireOwnCompanyId` + RLS).

## 2. Previously posted commodities (implemented)
- **History source:** `CommoditiesRepository.getPostingHistory()` (server only; `[]` offline) feeds `PreviousCommodity.fromListings()`.
  - Distinct by **(product, grade)**, most recent `created_at` first.
  - Lots without a product ID are skipped.
- **Picker** (`showCommodityPickerSheet`, now returning `CommodityPick`):
  - **"Your Previously Posted Commodities"** appears on top (product · grade, category label). Only products still active in the catalogue are shown, and search filters them too. Then **"All products"**, the full master.
  - No history: **"Choose your first commodity"**.
  - **History failure:** "Could not load your previously posted commodities…" with **Retry**. The full catalogue stays usable, and it is never shown as "first commodity".
- **Selecting a previous item:**
  - Sets the product (category from the catalogue) and **its remembered grade**, if that grade is still valid for the product; otherwise the first grade.
  - **Quantity, price, dates, status and broker are not copied.** Quantity and price stay empty and are required.
- **Quick-post path:** for a complete profile, the flow is pick previous → quantity → price → Review & List → List. Location comes from the profile defaults. Optional sections (Additional Details, lab, broker, location edit) stay collapsed and editable.

## 3. Unchanged (preserved)
Submission (`_handleSubmit` → `createCommodity`: own company, server-confirmed ID, friendly errors, duplicate lock); price, broker and status updates (server-confirmed); lab testing and attachment; broker picker; accordion; review sheet.

## 4. Files changed
| File | Change |
|---|---|
| `lib/features/commodities/domain/posting_history.dart` (new) | `PreviousCommodity`, `CommodityPick` |
| `lib/features/commodities/presentation/commodity_picker_sheet.dart` | History section, first-commodity label, history error + Retry; returns `CommodityPick` |
| `lib/features/commodities/presentation/post_commodity_screen.dart` | Readiness and history loading, readiness card, company-region default, preferred grade, address in location completeness, readiness gate in review, save-default-once |
| `lib/features/commodities/presentation/lot_location_sheet.dart` | `highlightMissing` (validate on open) |
| `lib/features/commodities/data/commodities_repository.dart` | `isOnline`, `getPostingHistory()` |
| `lib/features/profile/data/seller_profile_repository.dart` | `ListingReadiness`, `checkListingReadiness()`, `saveBusinessLocationDefault()` |
| `test/support/fake_profile_repository.dart`, `test/support/fake_commodities_repository.dart` | Controllable readiness and history |
| `test/widgets/quick_post_test.dart` (new), `test/unit/listing_readiness_test.dart` (new) | New tests |
| `test/widgets/post_commodity_screen_test.dart` | One assertion updated (the text now also appears on the readiness card) |

## 5. Blockers and limitations (no protected change made)
1. **Warehouse address is device-local.** There is no server column, so a new device or a reinstall asks for it again (state and district fall back to the firm's server region). Server persistence needs a schema change (approval).
2. **Payment terms and quality specs cannot be reused** from past lots; they are not persisted (no column).
3. **Firm problems (not linked, no name) cannot be fixed in the app.** Companies are created by admin or broker flows; the seller is told to contact support.
4. **GST is not required.** No backend rule found; both live sellers lack it. A product decision if it should be.

**No schema, migration, RLS or production change was made.**
