# 07 — INTEGRATIONS AND DEPLOYMENT MAP

**Document Reference:** `project-audit/deep-intelligence/07_INTEGRATIONS_AND_DEPLOYMENT_MAP.md`  
**Investigation Date:** October 17, 2026  
**Auditor:** Principal Cloud Architect & Deployment Specialist  
**Project:** BrokerBridge Enterprise + VetKind Animal Health India  

---

## 1. External Integrations Matrix

This section inventories all external service integrations, mapping their call sites, environment variable consumers, and current verification status:

| Service / Technology | Purpose | Code Call Sites & Consumers | Required Env Variables | Integration Verification Status |
| :--- | :--- | :--- | :--- | :--- |
| **Supabase Auth** | Session creation, JWT claims, user registration | `lib/supabase/client.ts`, `lib/supabase/server.ts`, `middleware.ts`, `src/server/actions/auth-actions.ts` | `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` | **CONFIGURED & LOCALLY TESTED** (Works with fallback sessions in test runners; live cloud auth pending) |
| **PostgreSQL (Supabase DBaaS)** | Primary relational datastore (36 tables) | `src/server/db/index.ts`, `drizzle.config.ts`, `src/server/db/schema.ts` | `DATABASE_URL` | **CONFIGURED** (Drizzle schema verified; live connection unseeded locally) |
| **Drizzle ORM** | Type-safe SQL query generation & schema migrations | `src/server/db/`, `drizzle.config.ts`, `package.json` | `DATABASE_URL` | **SOURCE-VERIFIED** (`drizzle-kit 0.31.10`, `drizzle-orm 0.45.2`) |
| **Supabase Storage** | Private evidence & document vault (COAs, weighbridge slips, LRs) | `src/lib/storage-utils.ts`, `src/server/actions/document-actions.ts`, `lab-actions.ts` | `NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | **CONFIGURED & TESTED WITH SIGNED MOCKS** (RLS policies drafted in `manual_storage_rls.sql`) |
| **Meta WhatsApp Cloud API** | Multi-channel proposal notifications & alerts | `app/api/webhooks/whatsapp/route.ts`, `src/server/notifications/adapters/whatsapp-adapter.ts` | `WHATSAPP_API_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`, `WHATSAPP_WEBHOOK_VERIFY_TOKEN` | **CONFIGURED IN CODE (UNVERIFIED LIVE)** (Live handshake pending Meta Developer token configuration) |
| **Google Generative AI (Gemini)** | Laboratory test document extraction & OCR | `src/server/actions/ocr-actions.ts`, `@google/generative-ai` | `GEMINI_API_KEY`, `GEMINI_MODEL` (`gemini-2.5-flash`) | **CONFIGURED IN CODE** (SDK installed; fallback manual entry operational) |
| **React-PDF Generator** | Dynamic server-side PDF quotation streaming | `app/api/quotations/[id]/pdf/route.ts`, `src/server/actions/quotation-actions.ts` | N/A (Server computational engine) | **VERIFIED OPERATIONAL** (`@react-pdf/renderer ^4.6.1`) |
| **Vercel Cron Automation** | Daily automated dispatch monitoring | `vercel.json`, `app/api/cron/monitor-dispatches/route.ts`, `process-notifications/route.ts` | `CRON_SECRET` | **CONFIGURED** (`vercel.json` schedules daily `0 0 * * *`) |

---

## 2. Environment Variables Catalog

The following variables are defined in `.env.example`:

### Database & Auth
- `NEXT_PUBLIC_SUPABASE_URL`: Public endpoint for Supabase project instance.
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`: Client-safe anonymous key for public SSR session handshakes.
- `SUPABASE_SERVICE_ROLE_KEY`: Privileged backend administrative key for background tasks and storage admin.
- `DATABASE_URL`: Direct or pooled PostgreSQL connection string (e.g. `postgresql://postgres:[password]@db.[ref].supabase.co:6543/postgres`).

### Public Application URL
- `NEXT_PUBLIC_APP_URL`: Base URL (e.g. `http://localhost:3000` or production domain) used for email/notification deep-linking.

### Artificial Intelligence (Google Gemini)
- `GEMINI_API_KEY`: API key for Google Generative AI SDK (`@google/generative-ai`).
- `GEMINI_MODEL`: Default model configuration (`gemini-2.5-flash`).

### Meta WhatsApp Cloud API
- `WHATSAPP_API_TOKEN`: System User Access Token from Meta Developer App.
- `WHATSAPP_PHONE_NUMBER_ID`: WhatsApp Business Phone Number ID.
- `WHATSAPP_WEBHOOK_VERIFY_TOKEN`: Custom secret string for webhook handshake challenge verification.

### Background Automation & Security
- `CRON_SECRET`: High-entropy authorization bearer token to prevent unauthorized public hits to `/api/cron/*`.

---

## 3. Vercel Deployment Architecture

- **Project Name:** `brokerbridge-enterprise` (`package.json:2`).
- **Target Account:** `https://vercel.com/vetkindinfo-9906`.
- **Framework Preset:** Next.js (detected automatically via Turbopack).
- **Node.js Runtime Requirement:** Node `20.x` or higher (verified with Node `v24.19.0`).
- **Build Command:** `next build` (verified clean exit 0 locally).
- **Cron Configuration (`vercel.json`):**
  ```json
  {
    "crons": [
      {
        "path": "/api/cron/monitor-dispatches",
        "schedule": "0 0 * * *"
      }
    ]
  }
  ```
- **Live Deployment Gaps:**
  1. GitHub push authorization (`vetkindinfo@gmail.com`) must be resolved so Vercel can pull from `feature/broker-nilesh`.
  2. Production environment variables listed in Section 2 must be populated in the Vercel Project Settings.
