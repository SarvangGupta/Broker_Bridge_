# BROKERAGE APP MASTER CONTEXT
## The Single Source of Truth for Continuing Engineering on BrokerBridge Enterprise & VetKind

**Document Name:** `project-audit/BROKERAGE_APP_MASTER_CONTEXT.md`  
**Date of Audit:** October 17, 2026  
**Auditor:** Senior Software Architect, Technical Lead & Project Auditor  
**Intended Recipient:** ChatGPT / Incoming Senior Engineering Lead  

---

## 1. Project Identity, Repository & Branches

- **Project Name:** BrokerBridge Enterprise (incorporating the VetKind Animal Health India domain extension).
- **Core Business Purpose:** A high-concurrency, mobile-first B2B physical agricultural commodity brokerage operating system and trading desk tailored for Indian Tier-2/Tier-3 agricultural and cattle feed raw material supply chains (wheat, yellow maize, soybean meal, mustard cake, de-oiled rice bran) connecting feed millers, dairy cooperatives, aggregators, and licensed brokers.
- **Enterprise Brand Context:** VetKind Animal Health India (veterinary pharmaceuticals, feed supplements, and dairy herd therapeutics).
- **GitHub Repository URL:** `https://github.com/SarvangGupta/Broker_Bridge_.git`
- **Active Development Branch:** `feature/broker-nilesh`
- **Current Local Commit SHA:** `54393d08684bbf0eec7bddb41630aa1d064462bb`
- **Remote Tracking Reference:** `origin/feature/broker-nilesh` (at `2a06252d8e3380f8f17d9c87afb077b8928321c7`)
- **Local Git Working Tree:** Clean (3 commits ahead of remote: `7da4e8c`, `f553730`, `54393d0`).
- **Git Push Blocker:** Attempting `git push` returns HTTP 403 because Windows Credential Manager supplied GitHub account `Nileshmnit08`, whereas repository collaborator access was shared with `vetkindinfo@gmail.com`. The pending GitHub repository invite for `vetkindinfo@gmail.com` must be accepted in the browser or credentials updated.
- **Vercel Account:** `https://vercel.com/vetkindinfo-9906` (`brokerbridge-enterprise`).

---

## 2. Verified Technology Stack

| Layer | Component | Version | Verification Command & Result |
| :--- | :--- | :--- | :--- |
| **Framework** | Next.js (Turbopack, App Router) | `16.3.0` | `npm run build` — **EXIT 0 (PASS)** across all 48 routes |
| **Runtime / UI** | React | `19.2.8` | React 19 `useTransition`, Server Components |
| **Styling** | Tailwind CSS (v4) | `@tailwindcss/postcss ^4` | Clean CSS build, 0 layout shifts |
| **Components** | Shadcn UI, Base UI, Radix UI | `@base-ui/react ^1.7.0` | 48px touch targets, mobile-first |
| **Language** | TypeScript (Strict Mode) | `^5` | `npx tsc --noEmit` — **0 ERRORS (PASS)** |
| **Database ORM** | Drizzle ORM | `0.45.2` | Clean schema, 0 type drift |
| **Database Engine**| PostgreSQL (Supabase DBaaS) | PostgreSQL 15+ | 38 migration SQL scripts in `supabase/migrations/` |
| **Auth & Sessions**| `@supabase/ssr` | `^0.12.4` | `httpOnly`, `sameSite: lax`, cookie JWT |
| **Document Gen** | `@react-pdf/renderer` | `^4.6.1` | Streams quotations via `/api/quotations/[id]/pdf` |
| **AI Integration** | `@google/generative-ai` | `^0.24.1` | Multimodal document and lab report parsing |

---

## 3. Architecture & Module Map

### 3.1 Flat 4-Role Architecture
The application strictly enforces a **Flat 4-Role Model**:
1. **`BUYER` (`BUYER_ADMIN`):** Procures raw materials; accesses `/buyer/*`. (Theme: Ocean Blue `#0284C7`).
2. **`SELLER` (`SELLER_ADMIN`):** Posts inventory lots; accesses `/seller/*`. (Theme: Forest Emerald `#059669`).
3. **`BROKER` (`BROKER`):** Facilitates trades, reviews lab reports, mints bookings; accesses `/broker/*`. (Theme: Electric Teal `#0D9488`).
4. **`ADMIN` (`ADMIN`):** Master data, KYC verification, God Mode; accesses `/admin/*`. (Theme: Indigo Slate `#4F46E5`).

### 3.2 Directory Structure
```text
Broker_Bridge_/
├── app/
│   ├── (admin)/admin/          # Master data CRUD & God Mode approval queue
│   ├── (broker)/broker/        # Broker Lite Shell (Home, Work, Deals, Orders, More)
│   ├── (buyer)/buyer/          # Enterprise Buyer Shell (Dashboard, Requirements, Proposals, Orders, Payments, Disputes)
│   ├── (seller)/seller/        # Seller Command Center (Inventory, Requests, Deals, Dispatch, Settlements)
│   ├── (vetkind)/vetkind/      # VetKind Animal Health Portal (Catalog, Formulations, Dealers, Inquiries)
│   ├── api/                    # Crons (notifications, dispatches), PDFs, WhatsApp Webhook
│   ├── login/ & register/      # Auth entry points
│   └── layout.tsx & globals.css
├── src/
│   ├── components/             # Shadcn and persona-specific UI components
│   ├── lib/                    # Supabase client/server helpers, validations, storage utilities
│   ├── server/
│   │   ├── actions/            # 68 Server Action suites (F12 tamper-proof mutations)
│   │   ├── db/                 # schema.ts (32 tables), vetkind-schema.ts (4 tables), index.ts
│   │   ├── tests/              # 16 automated test suites (142/142 tests passing)
│   │   └── utils/              # Match engine, version engine, privacy scrubber
│   └── types/                  # TypeScript interfaces and Zod schemas
├── supabase/migrations/        # 38 continuous SQL migrations (0001 - 0034 + RLS scripts)
└── docs/                       # 19 PRDs, sprint plans, and historical audits
```

---

## 4. Master Architectural Invariants (The Non-Negotiable Rules)

1. **The Mediation Firewall (ADR 03):** There is **zero direct communication** between Buyer and Seller. No chat tables, no direct messaging, no phone/email exchange. All interactions route through the Broker Desk.
2. **Immutable Deal Versioning (ADR 02):** Overwrite mutations on agreements are illegal. Every commercial change increments `deal_versions` with an immutable JSONB snapshot. Enforced by PostgreSQL triggers.
3. **Decoupled Confirmation vs. Booking Gate (ADR 06):** Buyer Confirmed + Seller Confirmed = mutual intent, **NOT a booking**. System Booking IDs (`BKG-YYYY-XXXX`) are minted exclusively by the human Broker Desk via `finalizeDealAction` and `createIdempotentBookingAction`.
4. **Nodal Escrow Settlement (ADR 04):** Counterparty bank accounts are redacted. Payments route via virtual account numbers (`BB-NODAL-${bookingReference}`) into a regulated platform nodal escrow account.
5. **Dynamic EAV Quality Engine (ADR 05):** Commodities have dynamic laboratory parameters (`master_quality_parameters`). Selecting a commodity automatically generates parameter inputs with mathematical tolerance validation.
6. **Tier-2 Mobile UX Standards (ADR 07):** 360px viewport baseline, zero horizontal page scroll, minimum 48×48px touch targets, zero HTML data tables on primary mobile views.
7. **Zero-PII Privacy Scrubber (ADR 08):** Automated regex scrubbers strip phone numbers, email addresses, GSTINs, and seller floor prices across all external API and UI payloads.
8. **Server-Side Math Enforcement (ADR 10):** All financial totals, brokerage deductions, and mandi cess are computed on the server. The client never computes monetary values.

---

## 5. Current Implementation Status (Sprints 1–39 Complete)

| Phase | Sprints | Focus | Status |
| :--- | :--- | :--- | :--- |
| **Phase 1** | Sprints 1–3 | Next.js 16 setup, Drizzle ORM, Supabase Auth, Master Data God Mode | **COMPLETED & VERIFIED ✅** |
| **Phase 2** | Sprints 4–6 | Company KYC, Buyer Requirements, Seller Availabilities | **COMPLETED & VERIFIED ✅** |
| **Phase 3** | Sprints 7–9 | Deterministic AI Match Engine, PDF Quotations, Deal Machine | **COMPLETED & VERIFIED ✅** |
| **Phase 4** | Sprints 10–12 | Logistics, Disputes, KPI Dashboards, Multi-Channel Notification Queue | **COMPLETED & VERIFIED ✅** |
| **Phase 5** | Sprints 13–20 | Multi-Sector, Traceable Lots, Dynamic Lab Tests, Loading Readiness, Versioning, Seller Confirmation, Booking, Seller Dispatch & Settlement | **COMPLETED & VERIFIED ✅** |
| **Phase 6** | Sprints 21–30 | Broker Lite Shell, Supply Discovery, COA Verification Desk, Dual-Channel Negotiation, Deal Builder, Logistics Operations, Commission Ledger, CRM | **COMPLETED & VERIFIED ✅** |
| **Phase 7** | Sprints 31–39 | Enterprise Buyer Workspace, 6-Step Wizard, Lab Bounds, Proposals Inbox, Visual Diff Engine, Buyer Confirmation, Orders Hub & Partial Math, Quality Evidence, Document Vault, Nodal Payables, Dispute Tracker | **COMPLETED & VERIFIED ✅** |
| **Phase 8** | Sprint 40 | Comprehensive End-to-End Buyer UAT & Final Polish | **PENDING (Next Step) ⏳** |
| **Domain** | VetKind Portal | Veterinary formulations, product catalog, dealer network, inquiries | **COMPLETED & VERIFIED ✅** |

---

## 6. Critical Open Tasks & Next Engineering Steps

1. **Fix GitHub Push Authorization (P0 Blocker):**
   - Accept the pending repository invitation sent to `vetkindinfo@gmail.com` on GitHub.
   - Update Windows Git credentials or generate a Personal Access Token (PAT) for `vetkindinfo@gmail.com`.
   - Push the 3 verified local commits (`git push origin feature/broker-nilesh`).
2. **Execute Sprint 40 — Buyer End-to-End UAT (P1 High):**
   - Author `src/server/tests/verify-buyer-e2e-uat.ts` validating the 10-phase Buyer journey:
     1. KYC Profile verification.
     2. Requirement creation with dynamic quality bounds.
     3. Broker proposal reception and commercial breakdown.
     4. Counter-offer submission with optimistic locking.
     5. Visual diff review and digital confirmation signature.
     6. Order visibility upon Broker finalization (`BKG-2026-XXXX`).
     7. Partial fulfillment math calculation.
     8. Scientific COA and scale slip document verification.
     9. Nodal escrow payable calculation.
     10. Mediation firewall dispute generation (50-char guard).
3. **Provision Supabase Production Database (P1 High):**
   - Run migrations `0001` through `0034` in `supabase/migrations/` against the production PostgreSQL instance.
   - Execute `seed_states_rajasthan_districts.sql` and manual storage RLS scripts.
   - Set `DATABASE_URL`, `NEXT_PUBLIC_SUPABASE_URL`, and `SUPABASE_SERVICE_ROLE_KEY` in Vercel.
4. **Configure WhatsApp Cloud API Webhook (P2 Medium):**
   - Add Meta Developer credentials in Vercel environment variables.
   - Test webhook handshake at `https://[domain]/api/webhooks/whatsapp`.

---

## 7. Rules for Safely Continuing Development

When continuing development on this codebase, ChatGPT and any human engineer must adhere to the following workflow rules:

- **Rule 1 (Preserve Existing Code):** Do NOT refactor, rename, or dismantle any of the 39 completed sprints. All existing routes, actions, and schemas must remain operational.
- **Rule 2 (Fast-Fix Workflow for UI / Logic Bugs):** When addressing minor UI, styling, or isolated logic bugs, fix directly, run `npx tsc --noEmit` and `npm run build`, and confirm 0 errors.
- **Rule 3 (Audit-First Approach for Security & Schema):** For any changes touching Authentication (`middleware.ts`), Database Schema (`schema.ts`), Immutability Triggers (`0034`), or Role Authorization, conduct a formal audit first before modifying code.
- **Rule 4 (No Schema Drift):** If modifying database models, always generate continuous Drizzle migrations using `npm run db:generate` and maintain `supabase/migrations/meta/_journal.json`.
- **Rule 5 (360px & 48px Invariant):** Any new button, input, or interactive element MUST have `min-h-[48px]` and must NOT cause horizontal scrolling on a 360px viewport.
- **Rule 6 (Server-Side Derivation):** Never accept `user_id`, `role`, or `company_id` from client payloads. Always derive them from the verified `@supabase/ssr` server session.
