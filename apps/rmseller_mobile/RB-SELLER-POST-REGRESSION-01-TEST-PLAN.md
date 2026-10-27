# RB-SELLER-POST-REGRESSION-01 — Test Plan

**App:** `apps/rmseller_mobile` · **Date:** 2026-10-27 · **Branch:** `feature/broker-nilesh`

## 1. Environment facts (verified, not assumed)
| Item | Finding | Evidence |
|---|---|---|
| Supabase projects | **One**: `imztlkvkxzeaekxvmcfe`, documented as **production** | `.env`, `.env.local`; `docs/BROKERBRIDGE-CHAT-E2E-01-REPORT.md` |
| Staging | **None** | no staging credentials; FIX-02 staging report |
| Migration 0044 | **Applied to production only** (2026-10-27, FIX-01); staging n/a | read-only check: `trg_prevent_self_company_change` present |
| Production lots | **3** (none created by a seller) | read-only count, 2026-10-27 |
| Seller test suite and the live DB | Safe: no `Supabase.initialize` in tests; test clients point at loopback or unreachable addresses | grep of `test/` |
| Test command | `D:\flutter_sdk\flutter\bin\flutter.bat test` (from `apps/rmseller_mobile`) | — |

**Consequence:** a real server-backed post, price change and broker change would write to **production**. That is not authorized (FIX-02: "Do not … perform production write tests"; saved project rule). So server-backed E2E runs the **real repository online code** (Supabase client → HTTP → PostgREST protocol with RETURNING) against a **loopback fake PostgREST** (`test/support/fake_postgrest.dart`, reused from RMBroker), signed in with a real Supabase session object. Live-RLS behaviour for the same operations was verified in FIX-01 (10/10 in-transaction checks on production, rolled back).

## 2. Scope and method
| Area | Method |
|---|---|
| Field-by-field (A–L) | Existing and new widget tests (offline mode) + code inspection |
| Core E2E (post → price → broker) | `test/unit/seller_lot_e2e_test.dart`: real repository over HTTP |
| Demo / empty state | Repository tests, online and offline |
| Negative / authorization | Loopback failure injection (500, 403/42501, 409/23503, zero rows), no-session, no-company |
| Regression | **Full** seller suite before (clean baseline) and after the changes |
| Static / build | `flutter analyze`, `flutter build apk --debug` |

## 3. Baseline protocol
The baseline is the full suite on the tree **before this sprint's edits**. This sprint's edits were reversed exactly, the suite was run, and the edited file was restored with a hash check. A first background run that overlapped live edits was **discarded** as possibly contaminated.

## 4. Out of scope / not executable here
- Real payments, paid lab requests and real uploads (no test integrations configured).
- Device GPS (no provider configured; RB-SELLER-LOCATION-UX-01).
- Production writes of any kind.
