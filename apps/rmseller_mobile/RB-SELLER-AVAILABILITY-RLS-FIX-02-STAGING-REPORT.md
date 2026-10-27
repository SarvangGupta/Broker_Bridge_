# RB-SELLER-AVAILABILITY-RLS-FIX-02 — Staging Report

**Status: BLOCKED. No staging target exists. No database changes were made in this sprint.**

## 1. Target verification (Phase 1, step 3)
| Check | Result |
|---|---|
| Supabase projects configured in the workspace | **One**: `imztlkvkxzeaekxvmcfe` (`.env`, `.env.local`; same URL in all apps) |
| Staging credentials or a staging project | **None.** `.env.example` has no staging entries, and there is no Supabase branch configuration. |
| How the repo documents `imztlkvkxzeaekxvmcfe` | **Production.** `docs/BROKERBRIDGE-CHAT-E2E-01-REPORT.md`: "the only database (production `imztlkvkxzeaekxvmcfe`)". `docs/RMBUYER-NOTIFICATION-CENTER-01-REPORT.md`: "no separate test or staging Supabase project; the apps and tests point at production". |

The target **cannot be verified as staging**. Per Phase 1, I stopped before any database modification.

## 2. Important: migration 0044 is already on production
In RB-SELLER-AVAILABILITY-RLS-FIX-01, after the owner replied "approve" to the proposal, migration 0044 (parts A–D) was **applied to `imztlkvkxzeaekxvmcfe` on 2026-10-27**:
- via `scripts/apply-migration-0044.mjs`, in one transaction,
- with 10/10 impersonated checks passing before COMMIT, and the synthetic rows rolled back.

The proposal had stated this project was the only, live database. This sprint's instruction says production deployment was **not** authorized, so the earlier apply went beyond what is now authorized. It is reported here rather than silently corrected.

**Current production state** (read-only, 2026-10-27):
- The three `availabilities` policies contain the seller branch.
- `trg_prevent_self_company_change` exists on `public.users`.
- `availabilities` still has **3 rows**: no synthetic data persisted and no real seller lot has been created.

**Not done:** I did not run the rollback. The instruction forbids running it blindly without assessing state, and reverting production is a decision for the owner (see the production review).

## 3. File locations
The instruction references `supabase/proposed/0044_…`. After the apply, those files were moved to:
- `supabase/migrations/0044_allow_sellers_own_availabilities.sql` (header marked APPLIED)
- `supabase/migrations/rollback_0044.sql`

## 4. What staging would need
One of these:
- a separate Supabase project (staging) with its connection details provided out of band, or
- a Supabase **branch** of `imztlkvkxzeaekxvmcfe`.

A staging copy must first be brought to the pre-0044 policy state; otherwise it would only re-test what production already runs. The apply script then runs unchanged against it (`DATABASE_URL` pointed at staging).
