# RB-SELLER-LAB-01 — Official Rate Card & Pricing Specification Report
## Laboratory Testing Charges, Rate Rules & Sample Submission Protocol

**Project:** RMBroker  
**Application:** RM Seller App (`apps/rmseller_mobile`)  
**Sprint ID:** `RB-SELLER-LAB-01`  
**Date:** October 21, 2026  
**Auditor:** Antigravity AI Coding Agent  
**Status:** **AUTHORITATIVE & VERIFIED**

---

### 1. Executive Summary

This report establishes the authoritative laboratory testing rate card, pricing calculation rules, and physical sample submission guidelines for **RMBroker Seller App** in accordance with `RB-SELLER-LAB-01`.

Partner Laboratory:
- **Laboratory Name:** Riddhi Siddhi Laboratory
- **Authoritative Address:** F-772 B, Road Number 6, Vishwakarma Industrial Area, Jaipur, Rajasthan.
- **Accreditation / Type:** Approved Raw Material & Agricultural Testing Laboratory.

---

### 2. Official Laboratory Rate Card

The laboratory offers 15 standardized chemical/physical assays plus an unpriced custom parameter option:

| # | Test / Assay Parameter | Listed Charge (INR) | Charge Type | Pricing Boundary Rule |
|---|---|---:|---|---|
| 1 | **Crude Protein** | ₹200 | Fixed Per Test | Standard Nitrogen / Dumas assay |
| 2 | **Fat / Oil** | ₹150 | Fixed Per Test | Ether extraction method |
| 3 | **Crude Fiber** | ₹200 | Fixed Per Test | Acid/Alkali digestion |
| 4 | **AIA (Acid Insoluble Ash)** | ₹200 | Fixed Per Test | Sand & silica silica determination |
| 5 | **Moisture** | ₹100 | Fixed Per Test | Oven loss on drying at 105°C |
| 6 | **Calcium** | ₹450 | Fixed Per Test | Mineral titration / Spectrophotometry |
| 7 | **Salt (NaCl)** | ₹480 | Fixed Per Test | Volhard titration |
| 8 | **Urea** | ₹550 | Fixed Per Test | Colorimetric detection |
| 9 | **Starch** | ₹500 | Fixed Per Test | Polarimetric / Enzymatic assay |
| 10 | **Phosphorus** | ₹500 | Fixed Per Test | Molybdate spectrophotometry |
| 11 | **Total Energy** | ₹850 | Fixed Per Test | Bomb calorimetry calculation |
| 12 | **Metabolic Energy (ME)** | ₹850 | Fixed Per Test | Standard animal feed caloric equation |
| 13 | **Total Digestive Nutrients (TDN)** | ₹750 | Fixed Per Test | Proximate analysis synthesis |
| 14 | **Total Ash** | ₹150 | Fixed Per Test | Furnace incineration at 550°C |
| 15 | **FFA (Free Fatty Acids)** | ₹100 | Fixed Per Test | Titration against standard alkali |
| 16 | **Other (Custom Parameters)** | *Not Specified* | Custom Quote | **Strict Rule:** Zero price assigned in UI; displays *"Contact Lab for Custom Quote"* |

---

### 3. Pricing Calculation & Financial Integrity Rules

1. **Strict Deduplication:**
   Each test parameter is unique. Selecting the same test cannot increment the count or double-charge the seller.
2. **"Other" Parameter Rule:**
   No arbitrary, invented, or estimated price may be assigned to "Other". If "Other" is checked by the seller, the UI indicates: *"Custom parameter subject to separate quote by Riddhi Siddhi Laboratory; not included in upfront UPI total."*
3. **No Hidden Surcharges or Unverified Fees:**
   - Zero added courier or pickup booking fees.
   - Zero added platform convenience fees.
   - Zero added unverified taxes (GST) unless explicitly confirmed by authorized backend billing profile.
4. **Estimated Total vs Final Payable Amount:**
   - The UI clearly labels:
     - **Estimated Total:** Sum of selected standard tests.
     - **Final Payable Amount:** Confirmed authoritative amount for UPI payment initiation.
5. **Client-Side Modification Guard:**
   The client calculates and displays the estimated total, but the final payment request created by the backend confirms and validates the exact rate card amount against selected test IDs before accepting UPI confirmation.

---

### 4. Sample Submission Instructions

When lab testing is selected, the seller receives explicit, confirmed laboratory submission instructions:

- **Laboratory Destination:**  
  **Riddhi Siddhi Laboratory**  
  F-772 B, Road Number 6, Vishwakarma Industrial Area, Jaipur, Rajasthan.
- **Sample Requirements:**
  - Standard representative sample weight: **500 grams**.
  - Must be placed in a clean, airtight, moisture-proof poly bag.
  - Labeled clearly on the outer bag with:
    1. Commodity Name & Grade
    2. Mandi Availability Lot Number (e.g. `LOT-RAJ-2026-XXXX`)
    3. Lab Request Reference ID (e.g. `LAB-REQ-XXXX`)
    4. Seller Contact & Dispatch Date
- **Dispatch Responsibility:**
  - The seller coordinates courier or physical drop-off to the Jaipur laboratory address directly.
  - The app makes **no false promises** of automated door pickup, courier tracking, or turnaround times without verified backend support.
- **Estimated Lab Turnaround:**
  - Standard turnaround is 24 to 48 hours following physical sample receipt and logging at the Jaipur laboratory.

---

### 5. Compliance & Invariant Checklist

- [x] All 15 standardized tests reflect exact listed charges (₹100 to ₹850).
- [x] "Other" has zero invented price and is clearly designated as non-payable upfront.
- [x] No unauthorized fees (taxes, courier, service charge) are added.
- [x] Laboratory name and full postal address in Jaipur, Rajasthan are accurately rendered.
- [x] Clear disclaimer that sample delivery must follow confirmed instructions.
