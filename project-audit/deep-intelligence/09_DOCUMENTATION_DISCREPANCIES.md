# 09 — ARCHITECTURE AND DOCUMENTATION DISCREPANCY REGISTER

**Document Reference:** `project-audit/deep-intelligence/09_DOCUMENTATION_DISCREPANCIES.md`  
**Investigation Date:** October 17, 2026  
**Auditor:** Principal Systems Auditor & Requirements Analyst  
**Project:** BrokerBridge Enterprise + VetKind Animal Health India  

---

## 1. Discrepancy Register

This register compares claims in existing documentation against concrete source code findings. No contradictions have been silently overwritten.

| ID | Claim in Documentation | Actual Source Evidence | Classification | Impact | Recommended Next Step |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **DISC-01** | `BrokerBridge_PRD_v4.0.md` §4 states users pick static quality "Grades" from dropdowns mapped to `master_grades`. | `src/components/buyer/requirements/quality-parameters-form.tsx` and `src/server/actions/buyer-quality-actions.ts` dynamically render scientific laboratory parameters from `master_quality_parameters`. `master_grades` is resolved automatically on the backend (`effectiveGradeId`). | `EVOLVED REQUIREMENT` (Resolved by ADR 05) | Minimal. The dynamic EAV system is superior and verified operational. | Maintain Dynamic Quality Engine; preserve backward compatibility with `master_grades` FK. |
| **DISC-02** | Early draft user stories in `BrokerBridge_PRD_v4.0.md` suggested in-app messaging between buyers and sellers. | The codebase implements a strict **Mediation Firewall** (`src/server/utils/buyer-privacy-scrubber.ts`, `buyer-dispute-actions.ts`). Zero chat tables, direct message models, or counterparty websocket rooms exist. | `ARCHITECTURAL PIVOT` (Enforced by ADR 03) | High positive impact: prevents platform disintermediation and protects broker business model. | Preserve Mediation Firewall. Ensure ChatGPT does not attempt to create a direct Buyer-Seller chat. |
| **DISC-03** | PRD v4.0 §11 implied quotation acceptance creates an instant booking. | Sprint 18 and Sprint 37 decouple confirmation from booking. Buyer and Seller confirmation updates `deal_versions` to `'Buyer Confirmed'` / `'Seller Confirmed'`. Booking ID (`BKG-YYYY-XXXX`) is minted exclusively by Broker in `createIdempotentBookingAction`. | `ARCHITECTURAL PIVOT` (Enforced by ADR 06) | Critical: Prevents unauthorized warehouse inventory commitments before broker credit and logistics review. | Maintain decoupled booking gate. |
| **DISC-04** | `PROJECTSTATE.MD` Note 2 states `buyer-dashboard-actions.ts` returns structural mock data for zero-wall rendering. | `src/server/actions/buyer-dashboard-actions.ts:28-85` returns mock KPI objects when live database tables are unseeded. | `CONFIRMED TECHNICAL DEBT` | Medium. Dashboard displays demo counts until wired to live SQL queries. | Replace mock arrays with live Drizzle `count()` and `sum()` queries once production database is seeded. |
| **DISC-05** | Prompt states git repository was shared with `vetkindinfo@gmail.com`. | Executing `git push` fails with HTTP 403 because Windows Credential Manager supplied GitHub account `Nileshmnit08`. | `AUTHENTICATION MISMATCH` | Critical Blocker: Prevents pushing local commits to remote branch `feature/broker-nilesh`. | Accept repo invite for `vetkindinfo@gmail.com` in browser or update Git credentials. |
| **DISC-06** | Prompt refers to project as "Brokerage App Development / VetKind". Codebase is named `brokerbridge-enterprise`. | `package.json:2` defines `"name": "brokerbridge-enterprise"`. The codebase was built as BrokerBridge Enterprise across 39 sprints, with VetKind domain added in `vetkind-schema.ts` and `/vetkind`. | `DOMAIN COEXISTENCE` (Resolved by ADR 09) | Positive: Both commodity raw-material sourcing and veterinary finished-product distribution coexist without conflict. | Continue Modular Coexistence Architecture. Do not rename repository or delete BrokerBridge files. |
| **DISC-07** | `verify-negotiation-immutability.ts` in Sprint 36 log reported 7/7 tests passing. | Running `npx tsx src/server/tests/verify-negotiation-immutability.ts` during this audit yielded 1/7 passed (6 failed) because the local environment is not connected to a live running PostgreSQL database. | `ENVIRONMENTAL LIMITATION` | High: Pure state transition logic passes, but live DB catalog triggers cannot be checked without an active database. | Execute test against live Supabase PostgreSQL instance after production database provisioning. |

---

## 2. Document Conflict Resolution Summary

All identified discrepancies reflect the natural maturation of the software over 39 sprints (e.g. pivoting from static grades to scientific laboratory tolerances, and introducing the Mediation Firewall to protect the brokerage model). 

The precedence order established in `02_DOCUMENT_REGISTER.md` correctly elevates `ARCHITECTURE.md`, `PROJECTSTATE.MD`, and persona PRDs above the older initial draft PRD v4.0.
