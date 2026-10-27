# RB-SELLER-QUICK-POST-01 — Audit Report

**App:** `apps/rmseller_mobile` · **Date:** 2026-10-27

## 1. Sources inspected
- **Code:** `post_commodity_screen.dart`, `commodity_picker_sheet.dart`, `lot_location_sheet.dart`, `commodities_repository.dart`, `seller_profile_repository.dart`, `business_location_model.dart`.
- **Reports:** POST-UX-05, LOCATION-UX-01, PRICE-SYNC-FIX-01, POST-REGRESSION-01, POST-INTEGRITY-02.
- **Live production schema and policies:** read-only, `BEGIN READ ONLY … ROLLBACK`; counts only, no personal data.

The workspace was unchanged since INTEGRITY-02.

## 2. Where seller business data lives (verified)
| Data | Location | Server-persisted? | Seller can read? |
|---|---|---|---|
| Company link | `users.company_id` | Yes | Yes (own row) |
| Firm name | `companies.name` (NOT NULL) | Yes | **Yes**: policy "Users can select their own company" |
| GST | `companies.gst` (nullable) | Yes | Yes |
| Firm registered region | `companies.state_id`, `district_id` (text) | Yes | Yes |
| Warehouse name/address/PIN | `business_location_*` secure-storage preferences | **No (device only)** | n/a |
| Office address | `office_address` preference | **No (device only)** | n/a |
| Loading text | per lot, `availabilities.loading_remarks` | Yes (per lot) | Yes |

Note: `getProfile()` fills demo Bikaner defaults when nothing is saved. It is **not** used for completeness or prefill; `getSavedBusinessLocation()` (null when unsaved) is.

**Live counts:**
- 2 seller logins, both with a firm name and a company state and district; **0 with GST**.
- **0 lots** for seller companies, so in production **both real sellers are first-time sellers (Journey A)**.

## 3. Mandatory vs optional (for publishing a lot)
| Field | Rule source | Mandatory |
|---|---|---|
| Signed-in session | RLS (`authenticated`) | Yes |
| `company_id` (own firm) | `availabilities.company_id` NOT NULL + 0044 RLS | Yes |
| Firm name | `companies.name` NOT NULL (a firm must exist) | Yes (implied) |
| Commodity, grade, unit | NOT NULL | Yes |
| Quantity, asking price | NOT NULL + app rule (> 0) | Yes, **per lot** |
| Warehouse state, district | `availabilities.state_id/district_id` NOT NULL | Yes |
| Warehouse address | Business detail (dispatch point); asked once, then reused on this device | Yes (app rule) |
| Valid until (≥ available from) | NOT NULL + app rule | Yes (defaults to today + 7 days) |
| GST | nullable | No |
| Loading / office address | nullable; defaults to "same as warehouse" | No |
| Payment terms, lab testing, lab report, broker | optional | No |

## 4. Listing history
- **Source:** `CommoditiesRepository.getCommodities()` (server, own company, `created_at desc`, limit 50) plus session-confirmed lots.
- **There is no `updated_at`**, so ordering uses `created_at`.
- **Offline mode returns sample lots.** The new `getPostingHistory()` therefore returns `[]` offline, so sample lots can never appear as history.

## 5. What can be safely reused from an old lot
| Value | Reuse? | Why |
|---|---|---|
| Product (commodity) | Yes, if still active in the catalogue | Identity |
| Grade | Yes, if still a grade of that product | Identity |
| Category | Resolved fresh from the catalogue | Authoritative |
| Quantity, asking price, availability dates, status | **Never** | Transaction-specific |
| Broker | **No** | Listing-specific; the seller chooses again |
| Payment terms, quality specs | **Not available** | Not persisted server-side (no column), so there is nothing authoritative to reuse |
| Warehouse/loading location | From the **current** profile defaults, not the old lot | The old lot's warehouse text is not persisted |
