# RB-SELLER-POST-REGRESSION-01 — Field-by-Field Results

**Legend**
- **PASS:** an automated test ran and passed. The test is named, `file › test`.
- **CODE:** verified by code inspection only; no test executed.
- **BLOCKED:** cannot run here; the reason is given.

**Test file short names**
| Short name | File |
|---|---|
| `ux05` | `test/widgets/post_commodity_screen_test.dart` |
| `ux04` | `post_commodity_ux04_test.dart` |
| `picker` | `post_commodity_product_picker_test.dart` |
| `qp` | `post_commodity_quantity_price_test.dart` |
| `loc` | `lot_location_sheet_test.dart` |
| `codec` | `lot_location_test.dart` |
| `e2e` | `test/unit/seller_lot_e2e_test.dart` |
| `repo` | `commodities_repository_test.dart` |
| `details` | `commodity_details_screen_test.dart` |

## Field inventory (from the current screen)
Batch/Lot No. badge · Commodity (searchable picker + category label) · Quality Grade · Total Quantity · Unit · Asking Price · Commercial Payment Terms · Additional Details: Available From / Valid Until · Warehouse & Loading (Location sheet: Warehouse name/address/state/district/PIN, Loading same-as checkbox + gate/platform + own address, Office same-as checkbox + own address, GPS button) · Physical Loading Readiness · Request Certified Lab Testing (toggle, tests, UPI pay, verify) · Add Lab Report (image / document / camera) · My Trusted Broker (Select / Change) · Review & List Commodity → review sheet (Edit per section) → List Commodity on Desk.

## A. Batch / Lot Number
| ID | Case | Expected | Actual | Status |
|---|---|---|---|---|
| A1 | Generated once and shown | `LOT-…` badge | `ux04 › POST-UX04-01` | PASS |
| A2 | Not an editable field | no text field | `ux04 › POST-UX04-01` | PASS |
| A3 | Not regenerated on rebuild or refresh | set once in `initState`, preserved through retries | `_lotNumberController` written only in `initState` and from `initialLot` | CODE |
| A4 | Failed submit creates no published state | error, no success | `qp › valid entry … failed save shows no success`; `ux05 › RLS rejection …` | PASS |
| A5 | Retry does not duplicate (concurrent taps) | one insert | `e2e › duplicate concurrent submission sends one insert` | PASS |
| A6 | Retry after an **ambiguous** response | no duplicate | No idempotency or unique constraint (OPEN-01) | **FAIL (open, needs DB approval)** |

## B. Commodity selection
| ID | Case | Status / evidence |
|---|---|---|
| B1 | Search by name, case-insensitive partial | PASS `picker › search "DOC"…` |
| B2 | Select, then switch: category and grades update | PASS `picker › category label and grades update…` |
| B3 | Correct category resolved | PASS `picker › …`; `ux05 › collapsed summaries…` |
| B4 | Missing category shows "Category unavailable" (regression) | PASS `picker › missing category…` |
| B5 | Rapid changes, no stale grade | CODE: `_onCommodityChanged` clears the grade first and ignores late responses (`_selectedCommodity?.id != newComm.id`) |
| B6 | Catalogue load error, retry, empty catalogue | PASS `picker` (error/retry); CODE (empty state `commodity-empty`) |
| B7 | Category on device requires a signed-in session | PASS on device (RB-SELLER-POST-CATEGORY-FIX-01) |

## C. Quality grade and specifications
| ID | Case | Status |
|---|---|---|
| C1 | Grades only for the selected product | PASS `picker › GRADE-01 Maize DDGS…` |
| C2 | Product without a grade cannot be listed | PASS `picker › product without a grade…` |
| C3 | Grade belongs to product, checked at submit | CODE `_handleSubmit` (commodityId check) |
| C4 | Selected IDs in payload | PASS `picker › submission carries the selected product ID and its own grade ID` |

## D. Quantity and unit
| ID | Case | Status |
|---|---|---|
| D1 | Empty / zero / non-numeric quantity blocked | PASS `qp › missing / zero / nonnumeric quantity blocks submission` |
| D2 | Negative quantity | CODE: validator `n <= 0` and submit check `totalQty <= 0` |
| D3 | Decimal allowed | CODE: `numberWithOptions(decimal: true)`, parsed as double |
| D4 | Excessive value | No existing upper-bound rule; not invented → N/A |
| D5 | MT default (Metric Ton row), no duplicate MT | PASS `qp › new lots default to "Metric Ton"…` |
| D6 | Edited lot keeps its own unit, no relabel | PASS `qp › editing a KG lot keeps KG…` |
| D7 | Quantity and unit stored and read back | PASS `e2e › full lifecycle` (`total_quantity`, `unit_id` in POST) |

## E. Asking price and payment terms
| ID | Case | Status |
|---|---|---|
| E1 | Missing / negative / non-numeric price blocked | PASS `qp › missing / negative / nonnumeric price…` |
| E2 | Zero price | CODE: validator `p <= 0` |
| E3 | Price label uses selected unit (₹ per MT/KG) | PASS `qp`, `ux04 › POST-UX04-03` |
| E4 | Live gross value | PASS `ux04 › POST-UX04-04` |
| E5 | Review matches entered values | PASS `ux05 › review shows current values…` |
| E6 | Payment terms persisted | **Not persisted server-side** (no column; session cache only), OPEN-04 |

## F. Locations
| ID | Case | Status |
|---|---|---|
| F1 | Saved profile location loaded, never demo defaults | PASS `ux05 › saved profile location fills…`, `… unknown district asks for it once` |
| F2 | No saved location → prompt; listing blocked | PASS `ux05 › no saved location…` |
| F3 | Loading / office same-as checkboxes, independent | PASS `loc › loading and office default to shared…`, `loc › unchecking loading opens its form without touching office` |
| F4 | Distinct address not silently overwritten | PASS `loc › re-checking a distinct address asks…`; `ux05 › a saved distinct office is kept separate` |
| F5 | State change clears incompatible district | PASS `loc › changing state clears…` |
| F6 | GPS | PASS (disabled path: `loc › GPS is disabled…`); PASS (fake provider: `loc › certain GPS result fills…`); **BLOCKED** on a real device (no provider) |
| F7 | Cancel / Save / validation | PASS `loc › save is blocked until warehouse address is entered…` |
| F8 | Review shows location summaries | PASS `ux05 › review shows current values…` |
| F9 | Loading text persisted and read back | PASS `e2e › full lifecycle` (`loading_remarks`) |
| F10 | Warehouse / office text persisted | **Not persisted** (no columns), OPEN-04 |

## G. Loading readiness and dates
| ID | Case | Status |
|---|---|---|
| G1 | Readiness options from master list; value in payload | CODE (`verifiedLoadingStatuses`, `loading_status`) |
| G2 | Dates in Additional Details, picker bounds | CODE (`firstDate` / `lastDate`) |
| G3 | Valid Until ≥ Available From | **No rule exists**, OPEN-05 |

## H. Certified lab testing
| ID | Case | Status |
|---|---|---|
| H1 | Optional; summary "Testing not requested" | PASS `ux05 › collapsed summaries…` |
| H2 | Expanding the section starts no request or payment | CODE (the toggle alone drives it) |
| H3 | UPI payment / verification / admin notify | **BLOCKED**: no test payment integration; real payments prohibited |

## I. Existing lab report attachment
| ID | Case | Status |
|---|---|---|
| I1 | Cancel attaches nothing | PASS `ux05 › lab report picker cancel attaches nothing` (**BUG-08 fixed**) |
| I2 | Picker failure / permission denied → message, nothing attached | PASS `ux05 › lab report picker failure attaches nothing` (**BUG-08**) |
| I3 | Allowed document types | CODE (`pdf, doc, docx, jpg, jpeg, png`) |
| I4 | Oversized file | No rule exists, OPEN-06 |
| I5 | Attachment does not start testing or payment | CODE (separate state `_labAttachment`) |
| I6 | Upload and persistence | **Not implemented**: no upload pipeline, no column; now honestly `isUploaded: false` |
| I7 | Real device pick | **BLOCKED** (needs the phone; not run) |

## J. Broker selection
| ID | Case | Status |
|---|---|---|
| J1 | Single broker (model is single-select); summary and review show it | PASS `ux05 › collapsed summaries…`, `review shows current values…` (open pool) |
| J2 | Broker in payload, visibility restricted | PASS `e2e › full lifecycle` |
| J3 | Only trusted brokers offered | CODE (`_brokerRepository.getBrokers()`) |
| J4 | Server rejects an unauthorized broker | **Not enforced by RLS**, OPEN-02 |
| J5 | Multiple brokers | N/A (not supported by the model) |

## K. Sections and form state
| ID | Case | Status |
|---|---|---|
| K1 | Accordion opens and closes; values kept | PASS `ux05 › only one section is open; collapsing keeps typed values` |
| K2 | Accessible headers | PASS `ux05 › section headers are accessible…` |
| K3 | 320 px, every section | PASS `ux05 › each section opens at 320px…` |
| K4 | Return from location editor keeps the form | PASS `loc` + `ux05 › review … Edit returns to the section` |
| K5 | Android Back | CODE (standard `Navigator`; no custom `WillPopScope`). Device not run |

## L. Review and submit
| ID | Case | Status |
|---|---|---|
| L1 | Summaries match form state | PASS `ux05 › review shows current values…` |
| L2 | Missing data opens the right section and shows errors | PASS `ux05 › empty submit shows field errors…`, `no saved location…` |
| L3 | Edit returns without reset or submit | PASS `ux05 › review … Edit returns…` |
| L4 | Submit only after confirming the review | PASS `ux05 › confirming the review submits once…` |
| L5 | Failed submit: friendly error, values kept, no success | PASS `ux05 › RLS rejection…`, `qp › … no success` |
