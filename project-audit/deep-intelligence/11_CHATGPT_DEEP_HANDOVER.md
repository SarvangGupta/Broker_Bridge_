# 11 — CHATGPT DEEP PROJECT HANDOVER MANUAL
## The Exhaustive Engineering Manual for BrokerBridge Enterprise + VetKind

**Document Reference:** `project-audit/deep-intelligence/11_CHATGPT_DEEP_HANDOVER.md`  
**Investigation Date:** October 17, 2026  
**Auditor:** Principal Software Architect, Full-Stack Lead & Security Auditor  
**Intended Recipient:** ChatGPT (Senior Full-Stack Developer Role)  

---

## 1. Project Context & Verification Summary

You are taking over an existing, production-grade TypeScript application: **BrokerBridge Enterprise** (with the **VetKind Animal Health India** domain extension).

- **Current Repository Root:** `C:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_` *(Source-Verified)*
- **GitHub Remote:** `https://github.com/SarvangGupta/Broker_Bridge_.git` *(Source-Verified)*
- **Active Branch:** `feature/broker-nilesh` *(Source-Verified)*
- **Current HEAD Commit:** `54393d08684bbf0eec7bddb41630aa1d064462bb` *(Source-Verified)*
- **Tracking Branch:** `origin/feature/broker-nilesh` at `2a06252d8e3380f8f17d9c87afb077b8928321c7` *(Source-Verified)*
- **Working Tree:** Clean (Ahead by 3 local commits: `7da4e8c`, `f553730`, `54393d0`) *(Source-Verified)*
- **Compilation Health:** `npm run build` exits 0 (48 static/dynamic routes); `npx tsc --noEmit` exits with 0 errors *(Test-Verified)*
- **Operational Status:** Sprints 1 through 39 (Phases 1–7) are **100% complete, verified, and audited**. The single remaining roadmap sprint is **Sprint 40: End-to-End Buyer UAT & Final Polish**.

---

## 2. Core Architectural Invariants (Non-Negotiable Guardrails)

Any changes you make must strictly preserve these 8 established architectural invariants:

1. **The Mediation Firewall (ADR 03):** Zero direct counterparty interaction. Buyers and Sellers never have direct chat, messaging, or phone exchange. All interactions route through the Broker Desk. Enforced in `src/server/utils/buyer-privacy-scrubber.ts`. *(Source-Verified)*
2. **Immutable Deal Versioning (ADR 02):** Contracts are never updated in-place. Every price, quantity, or term change increments `deal_versions` with an immutable JSONB snapshot, defended by PostgreSQL database triggers (`0034_enforce_negotiation_immutability.sql`). *(Source-Verified)*
3. **Decoupled Confirmation vs. Booking Gate (ADR 06):** Buyer Confirmed + Seller Confirmed = mutual intent, **NOT a booking**. System Booking IDs (`BKG-YYYY-XXXX`) are minted exclusively by the human Broker Desk via `finalizeDealAction` and `createIdempotentBookingAction`. *(Source-Verified)*
4. **Nodal Escrow Settlement (ADR 04):** Counterparty bank details are redacted. Payments route via virtual account identifiers (`BB-NODAL-${bookingReference}`) into a regulated platform nodal trade settlement account. *(Source-Verified)*
5. **Dynamic EAV Quality Engine (ADR 05):** Commodities have dynamic laboratory parameters (`master_quality_parameters`). Selecting a commodity automatically generates parameter inputs with mathematical tolerance validation. *(Source-Verified)*
6. **Tier-2 Mobile UX Standards (ADR 07):** Mobile-first design on a 360px viewport baseline with zero horizontal page scroll (`overflow-x-hidden`) and minimum 48×48px touch targets (`min-h-[48px]`). *(Source-Verified)*
7. **Zero-PII Privacy Scrubber (ADR 08):** Automated regex and data sanitation filters strip telephone numbers, email addresses, GSTINs, and confidential floor prices across all external API and UI channels. *(Test-Verified)*
8. **Server-Side Math Enforcement (ADR 10):** All financial calculations (gross payables, brokerage deductions, mandi cess) are executed on the server. Never compute financial amounts on the client. *(Source-Verified)*

---

## 3. Technology Stack & Key Commands

- **Framework:** Next.js `16.3.0` (Turbopack, App Router)
- **Runtime / UI:** React `19.2.8`, Tailwind CSS v4, Shadcn UI, Base UI (`@base-ui/react ^1.7.0`)
- **Language:** TypeScript 5 Strict Mode (`tsconfig.json`)
- **Database:** PostgreSQL (Supabase DBaaS), Drizzle ORM `0.45.2`, Drizzle Kit `0.31.10`
- **Auth:** `@supabase/ssr ^0.12.4` with `httpOnly` cookie sessions

### Operational Commands
- Start dev server: `npm run dev` (Runs on `http://localhost:3001`)
- Run typecheck: `npx tsc --noEmit`
- Run production build: `npm run build`
- Run test suite: `npx tsx src/server/tests/[test-file].ts`
- Generate Drizzle migrations: `npm run db:generate`

---

## 4. Immediate Blockers & Operational Next Steps

### Blocker 1: Git Remote Push 403 Authorization (P0)
- **Problem:** `git push origin feature/broker-nilesh` fails with HTTP 403 because Windows Credential Manager supplied GitHub account `Nileshmnit08`, whereas access was granted to `vetkindinfo@gmail.com`.
- **Action Required:** The user must log into GitHub as `vetkindinfo@gmail.com`, accept the pending collaboration invite for `SarvangGupta/Broker_Bridge_`, and update Windows Git credentials.

### Blocker 2: Supabase Production PostgreSQL Provisioning (P1)
- **Problem:** The local sandbox operates against mock data and schema definitions; the remote Supabase database has not yet executed the 38 migrations.
- **Action Required:** Execute `supabase/migrations/0001` through `0034` on the remote Supabase PostgreSQL instance and set `DATABASE_URL` in Vercel.

---

## 5. Primary Development Mission: Sprint 40 (Buyer End-to-End UAT)

Your primary engineering assignment is to implement **Sprint 40: Comprehensive Buyer End-to-End UAT**:

1. Verify that your working tree on branch `feature/broker-nilesh` is clean.
2. Create `src/server/tests/verify-buyer-e2e-uat.ts` chaining all 10 phases of the canonical Buyer journey:
   - Phase 1: KYC Profile & Organization isolation (`verifyBuyerSession`).
   - Phase 2: Requirement submission with dynamic quality parameter boundaries.
   - Phase 3: Broker proposal reception with net landed rate breakdown.
   - Phase 4: Buyer counter-offer submission with optimistic locking (`STALE_VERSION_DETECTED`).
   - Phase 5: Visual diff review (Red/Green delta engine) and digital signature confirmation.
   - Phase 6: Order tracking upon Broker booking minting (`BKG-2026-XXXX`).
   - Phase 7: Partial fulfillment math calculation (Original, Booked, Remaining).
   - Phase 8: Scientific quality (COA) and weighbridge scale slip inspection.
   - Phase 9: Nodal escrow payable calculation.
   - Phase 10: Mediation firewall dispute generation (50-character validation guard).
3. Execute the runner:
   ```bash
   npx tsx src/server/tests/verify-buyer-e2e-uat.ts
   ```
4. Verify that all 10 phase assertions exit with code 0.
5. Update `PROJECTSTATE.MD` to mark Sprint 40 as `COMPLETED ✅`.

---

## 6. Rules of Engagement

- **Preserve Existing Code:** Do NOT refactor or delete any of the 39 completed sprints.
- **Fast-Fix Workflow:** Fix minor UI or logic bugs directly, followed by `npx tsc --noEmit` and `npm run build`.
- **Audit-First Workflow:** For authentication, schema changes, migrations, or security changes, conduct an audit first and seek user confirmation before mutating code.
- **Report Exact Evidence:** In every response, state the exact files modified, commands executed, and verification output.
