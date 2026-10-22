# RB-SELLER-DASH-01 — Audit Report
**Sprint:** Compact Dashboard Mediation Disclaimer  
**Application:** RM Seller Mobile (`apps/rmseller_mobile`)  
**Sprint Type:** Implementation Sprint (Audit → Implement → Test → Report → Stop)  
**Date:** 2026-10-21  
**Status:** Audit Complete — Implementation Ready

---

## 1. Executive Summary

This audit assesses the Seller App Dashboard in `rmseller_mobile` to replace the prominent, space-consuming mediation disclaimer banner with a compact, unobtrusive information icon.

The Seller Dashboard currently displays a large banner titled **"Mandi Mediation Active"** at the top of the main scroll view. This banner occupies significant vertical viewport space before the seller can view their operational Key Performance Indicators (KPIs) and primary actions.

The goal of this sprint is to:
1. Reclaim top-of-dashboard vertical screen real estate by removing the prominent disclaimer banner.
2. Introduce a compact, unobtrusive information icon near the dashboard heading.
3. Preserve the exact legal and operational disclosure on demand via an accessible, responsive dialog/modal with platform-standard dismissal.
4. Ensure zero disruption to business logic, broker mediation workflows, deal state, or other modules in the application.

---

## 2. Pre-Implementation Inspection

### 2.1 Current Seller Dashboard Architecture
- **File:** `lib/features/home/presentation/seller_home_screen.dart`
- **Component:** `SellerHomeScreen` (StatefulWidget backed by `_SellerHomeScreenState`)
- **Route:** `/home` (BottomNavigationBar Branch 0)
- **Top-Level Layout:**
  - `AppBar`: Displays `_companyName` (titleMedium) and `Seller Desk • $_sellerName` subtitle. Contains action buttons for Notifications (`LucideIcons.bell`) and Search (`LucideIcons.search`).
  - `Body`: `RefreshIndicator` wrapping a `ListView` with 16px horizontal and 12px vertical padding.

### 2.2 Existing Disclaimer Location & Content
- **Current Position:** Lines 140–141 in `seller_home_screen.dart`, positioned as the first element in the `ListView` above the 4 Metric Cards.
- **Current Widget:** `_buildActionCenterCard(BuildContext context)` (lines 274–313):
  - Container/Card styling: `AppCard` with `AppColors.primaryContainer.withOpacity(0.5)` background and `AppColors.primary.withOpacity(0.3)` border.
  - Icon: A 36px circular badge containing `LucideIcons.shieldCheck` in white on `AppColors.primary`.
  - Verbatim Text:
    - **Title:** `Mandi Mediation Active` (14px, w700, `AppColors.primary`)
    - **Description:** `All commodity negotiations and bookings are mediated through authorized mandi brokers. Buyer identities are shielded.` (12px, `AppColors.textSecondaryLight`)
- **Space Impact:** Consumes approximately 80–90 vertical pixels of prime screen space on standard mobile viewports, pushing the primary KPIs (`Active Lots`, `In Negotiation`, `Booked Deals`, `Ready to Load`) downwards.

### 2.3 Existing Design System & Dialog Components
- **Color Tokens (`lib/app/theme/app_colors.dart`):**
  - Primary: Deep Burgundy (`0xFF7C1D24`)
  - Primary Container: `0xFFF9EBEB`
  - Text Primary/Secondary: `0xFF1E293B` / `0xFF475569`
  - Surfaces: `surfaceLight` (`0xFFFFFFFF`), `surfaceDark` (`0xFF1F2937`)
- **Icons (`package:lucide_icons_flutter/lucide_icons.dart`):**
  - `LucideIcons.info` (standard compact info indicator)
  - `LucideIcons.shieldCheck` (authoritative mediation / shield indicator)
- **Modal / Dialog UX Patterns:**
  - `AlertDialog` with `SingleChildScrollView`, custom rounded shape (16px), theme-aware background, and explicit "Close" action button (used in `sales_history_screen.dart`, `rate_broker_screen.dart`).

---

## 3. UI/UX Transformation Plan

### 3.1 Banner Removal
- Remove `_buildActionCenterCard(context)` and the trailing `SizedBox(height: 16)` from the `ListView` in `seller_home_screen.dart`.
- The dashboard body will immediately begin with the 4 Authoritative Metric Cards (`Active Lots`, `In Negotiation`, `Booked Deals`, `Ready to Load`).

### 3.2 Compact Information Icon Placement
- Position a small information icon (`LucideIcons.info`, 16px) immediately adjacent to the company heading in the `AppBar` title row.
- Provide accessible labeling:
  - `tooltip: 'Mediation information'`
  - `Key: Key('mediation_info_button')`
  - Semantics label: `'Mediation information'`
- Visual hierarchy:
  - Size: 16px
  - Color: `AppColors.primary` (matching brand tone)
  - Layout: `Flexible` container for `_companyName` to ensure zero overflow on narrow or dense screens.
  - Independence: Does not crowd or compete with the primary AppBar actions (Notifications, Search).

### 3.3 On-Demand Detailed Disclosure
- When tapped, invoke `_showMediationDisclaimerDialog(context)`.
- Use an `AlertDialog` containing:
  - **Header:** Circle badge with `LucideIcons.shieldCheck` + title `'Mandi Mediation Active'`.
  - **Body Content:** Verbatim existing text in a `SingleChildScrollView`:
    `"All commodity negotiations and bookings are mediated through authorized mandi brokers. Buyer identities are shielded."`
  - **Action:** Standard `Close` button dismissing via `Navigator.of(dialogContext).pop()`.
  - **Dismissal:** Platform back gesture/button and barrier tap enabled (`barrierDismissible: true`).
  - **Theming:** Full light/dark support using `Theme.of(context).brightness`.

---

## 4. Scope & Invariant Guardrails

- **Scope Restriction:** Restricted strictly to `SellerHomeScreen` (`lib/features/home/presentation/seller_home_screen.dart`) and corresponding tests in `rmseller_mobile`.
- **Zero Business Logic Mutations:** No changes to mediation contracts, broker assignments, deal negotiations, commission calculations, or counterparty shield enforcement.
- **Verbatim Text Preservation:** The disclaimer text is preserved verbatim without alteration.
- **Preserve Unrelated Changes:** Clean working tree; zero modifications outside the approved scope.
