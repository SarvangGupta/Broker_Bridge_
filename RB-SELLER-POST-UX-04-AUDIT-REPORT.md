# RB-SELLER-POST-UX-04: Baseline Audit Report
## Post Commodity Lot: Professional Redesign of Sections 1 & 2

**Audit Date:** 2026-10-21  
**Sprint Identifier:** `RB-SELLER-POST-UX-04`  
**Application Audited:** RM Seller Mobile (`apps/rmseller_mobile`)  
**Target Screen:** `apps/rmseller_mobile/lib/features/commodities/presentation/post_commodity_screen.dart`  
**Status:** AUDIT COMPLETE  

---

## 1. Executive Summary

Sprint **RB-SELLER-POST-UX-04** targets a focused, professional UI redesign of **strictly Sections 1 and 2** of the existing **Post Commodity Lot** page in `rmseller_mobile`.

The existing implementation is functionally capable but suffers from amateurish layout decisions, visual misalignment, and vertical screen space waste:
1. **Misleading Batch/Lot Input:** The system-generated Batch/Lot Number (e.g. `LOT-XXXXXX`) is rendered as a prominent, full-width editable `AppTextField` that suggests user entry even though it is generated in `initState()` or persisted from `initialLot`.
2. **Disjointed Section 1 Hierarchy:** The Commodity and Quality Grade dropdowns are stacked vertically on all form factors with detached external `Text` labels, consuming over ~280px of vertical space for two dropdowns.
3. **Misaligned Section 2 Controls:** `Total Quantity` (`AppTextField`) and `Unit` (`DropdownButtonFormField`) sit side-by-side in a `Row`, but have mismatched top baselines, mismatched input decorations, and misaligned bottom borders.
4. **Unbalanced Pricing Layout:** `Asking Price per Unit (₹)` stretches across the entire screen width, while payment terms and commercial pricing have no inline calculation feedback.

---

## 2. Detailed Technical Audit of Sections 1 & 2

### 2.1 Target File & Location
- **Path:** `apps/rmseller_mobile/lib/features/commodities/presentation/post_commodity_screen.dart`
- **Class:** `_PostCommodityScreenState` extends `State<PostCommodityScreen>`
- **Total Lines:** ~2608 lines
- **Lines of Target Sections:** Lines 2143–2265 (`build` method)

### 2.2 Section 1 — Commodity & Specification (Lines 2143–2182)
```dart
// Section 1: Commodity & Quality Grade
_buildSectionHeader('1. Commodity & Specification', LucideIcons.package),
const SizedBox(height: 12),
AppCard(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppTextField(
        controller: _lotNumberController,
        label: 'Lot / Batch Number *',
        hint: 'e.g. LOT-SOY-001',
        validator: (val) => val == null || val.trim().isEmpty ? 'Lot number is required' : null,
      ),
      const SizedBox(height: 14),

      const Text('Commodity *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      DropdownButtonFormField<MasterCommodity>(
        value: _selectedCommodity,
        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
        items: _commodities.map((c) {
          return DropdownMenuItem(value: c, child: Text(c.name));
        }).toList(),
        onChanged: _onCommodityChanged,
      ),
      const SizedBox(height: 14),

      const Text('Quality Grade *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      DropdownButtonFormField<MasterGrade>(
        value: _selectedGrade,
        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
        items: _grades.map((g) {
          return DropdownMenuItem(value: g, child: Text(g.gradeName, style: const TextStyle(fontSize: 13)));
        }).toList(),
        onChanged: (g) => setState(() => _selectedGrade = g),
      ),
    ],
  ),
),
```

#### Key Findings for Section 1:
- **Batch/Lot Number Lifecycle:**
  - Initialized in `initState()`: `_lotNumberController.text = 'LOT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';`
  - Re-hydrated in `_loadMasterData()`: `_lotNumberController.text = lot.lotNumber;` if editing an existing `initialLot`.
  - Consumed in `_handleSubmit()`: `lotNumber: _lotNumberController.text.trim()`.
  - Read in `_generateReportReference()`: `final lot = _lotNumberController.text.trim();`.
  - Rendered in Review Summary: `_lotNumberController.text.trim()`.
  - **Verdict:** The number is strictly system-managed. It must not be displayed as an editable text input. It belongs as a compact, secondary badge/label at the top of Section 1 (e.g. `BATCH / LOT NO.  LOT-XXXXXX`).
- **Commodity & Grade Layout:**
  - Vertically stacked with loose `14px` gaps.
  - On viewports $\ge 500$px, these two fields naturally form a cohesive horizontal pair.
  - On narrow mobile viewports (< 500px), they should stack with consistent, compact spacing and unified label typography.

---

### 2.3 Section 2 — Quantity & Commercial Pricing (Lines 2185–2265)
```dart
// Section 2: Quantity & Commercial Terms
_buildSectionHeader('2. Quantity & Commercial Pricing', LucideIcons.indianRupee),
const SizedBox(height: 12),
AppCard(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            flex: 3,
            child: AppTextField(
              controller: _quantityController,
              label: 'Total Quantity *',
              hint: '100',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Required';
                final n = double.tryParse(val);
                if (n == null || n <= 0) return 'Must be > 0';
                return null;
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Unit *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                DropdownButtonFormField<MasterUnit>(
                  value: _selectedUnit,
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                  items: _units.map((u) {
                    return DropdownMenuItem(value: u, child: Text(u.symbol));
                  }).toList(),
                  onChanged: (u) => setState(() => _selectedUnit = u),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),

      AppTextField(
        controller: _askingPriceController,
        label: 'Asking Price per Unit (₹) *',
        hint: '4800',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        validator: (val) {
          if (val == null || val.trim().isEmpty) return 'Required';
          final p = double.tryParse(val);
          if (p == null || p <= 0) return 'Must be positive';
          return null;
        },
      ),
      const SizedBox(height: 14),

      const Text('Commercial Payment Terms *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        value: _paymentSchedule,
        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
        items: const [
          DropdownMenuItem(value: 'Payment on Delivery (CAD)', child: Text('Payment on Delivery (CAD)')),
          DropdownMenuItem(value: 'Advance RTGS (50% Advance / 50% on B/L)', child: Text('Advance RTGS (50/50)')),
          DropdownMenuItem(value: 'Immediate RTGS on Weighbridge Slip', child: Text('Immediate RTGS on Weighbridge')),
          DropdownMenuItem(value: 'Letter of Credit (LC at Sight)', child: Text('Letter of Credit (LC)')),
        ],
        onChanged: (val) {
          if (val != null) setState(() => _paymentSchedule = val);
        },
      ),
    ],
  ),
),
```

#### Key Findings for Section 2:
- **Baseline Alignment:** `AppTextField` and the adjacent `Unit` `Column` do not share consistent internal padding. `AppTextField` uses `InputDecorationTheme` defaults while `Unit` has hardcoded `contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)`.
- **Asking Price Real Estate:** A single numerical input consumes the full horizontal width, leaving wide empty space.
- **Immediate Valuation Feedback:** `final totalVal = totalQty * askingPrice;` is already computed at line 2112 of `build()`. Displaying an inline live valuation badge (e.g. `Est. Value: ₹4,80,000`) within Section 2 gives immediate commercial confidence without introducing new calculations or database contracts.

---

## 3. Strict Scope & Invariant Guardrails

### 3.1 What Will Be Redesigned:
- **Section 1:**
  - Remove editable `AppTextField` for Batch/Lot Number.
  - Add compact, read-only secondary label `BATCH / LOT NO.  LOT-XXXXXX` at the top of Section 1 with responsive wrapping to prevent overflow on narrow screens.
  - Lay out Commodity and Quality Grade dropdowns with unified label styling, consistent field heights, and responsive 2-column wrapping on wider viewports.
- **Section 2:**
  - Align `Quantity` and `Unit` fields perfectly with unified typography and input decorations.
  - On wide viewports ($\ge 550$px), group Quantity, Unit, and Asking Price into a cohesive commercial row.
  - On narrow viewports (< 550px), stack into clean aligned rows.
  - Include compact, clean live valuation display (`Est. Lot Value: ₹...`) when valid values are entered.
  - Style Commercial Payment Terms dropdown consistently with Section 1 dropdowns.

### 3.2 Explicitly Untouched:
- Section 3: Warehouse Location & Loading (100% untouched).
- Section 4: My Trusted Broker selection & assignment workflows (100% untouched).
- Section 5: Review Listing & Broker Summary (100% untouched).
- Certified lab testing rate card, UPI payments, and admin notifications (100% untouched).
- Lab report attachment pickers and auto-reference generation (100% untouched).
- Submission logic, DTO mapping, validations, and backend calls (100% untouched).
- Buyer App and Broker App (100% untouched).
- Database migrations, RLS policies, schemas (100% untouched).

---

## 4. Verification & Testing Strategy

1. **Flutter Static Analysis:** Run `flutter analyze` on target screen.
2. **Automated Verification Suite:** Create `src/server/tests/verify-rmseller-post-ux-04.ts` covering all structural, functional, responsive, and scope invariants.
3. **Flutter Widget Tests:** Create dedicated widget tests verifying:
   - Batch/Lot Number is displayed as secondary label, NOT as an editable text input.
   - Commodity and Grade dropdowns render cleanly.
   - Quantity, Unit, Price, and Payment Terms validate correctly and update state.
   - Zero overflow across narrow (360px) and wide (800px) viewports.
4. **Physical Device Verification:** Install updated debug APK on Xiaomi Redmi Note 5 Pro and verify live rendering.
