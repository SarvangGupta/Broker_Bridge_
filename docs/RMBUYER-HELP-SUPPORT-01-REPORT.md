# RMBUYER-HELP-SUPPORT-01 — Report

Date: 2026-10-25 · Branch: `feature/broker-nilesh` · **Status: BLOCKED** · No code changed

## 1. Summary

None of the four requested capabilities has a backend contract or trusted configuration that the Buyer app can use without a schema, RLS, grant or config change. The sprint prohibits all of those. Adding a Help & Support menu would therefore mean nonfunctional items, which the sprint also prohibits, so no UI was added.

| Capability | Status | Blocking dependency |
|---|---|---|
| Report an App Bug | **BLOCKED** | No authorized write path for buyers (§2.1) |
| My Support Tickets | **BLOCKED** | No read path, and no message/history model (§2.2) |
| Contact Admin Support | **BLOCKED** | No configured support channel; the ticket path is blocked (§2.3) |
| Contact via WhatsApp | **BLOCKED** | No official support number configured (§2.4) |
| Ticket notifications | **BLOCKED** | No support event or trigger; buyers can't insert notifications (§2.5) |
| Admin Support role | **Missing** | Only `admin` exists (§2.6) |

## 2. Evidence (live read-only inspection plus code)

Live inspection used `BEGIN READ ONLY`, with metadata and counts only. No rows were read beyond counts, and nothing was written.

### 2.1 Bug reports: no write path

- **Table:** `public.support_tickets` (migration 0014) has the columns `id, user_id, role, issue_type, description, status (default 'Open'), created_at, resolved_at`.
  - There is **no `title`** column, no app/device metadata column, and no attachment reference.
- **Database access:** RLS is enabled with **no policies at all**. `authenticated` has only `REFERENCES` (plus the default-ACL `TRIGGER`/`TRUNCATE`), with **no `INSERT` or `SELECT`**. A Buyer client gets "permission denied" before RLS is even evaluated.
- **No RPC:** no `public` function references `support_tickets`.
- **Web action not callable:** `src/server/actions/support-actions.ts` → `createSupportTicketAction` is a Next.js server action using the web cookie session. The mobile app can't call it, and there is no `app/api/**` REST route for support. The only routes are cron, a quotation PDF, reset, and the WhatsApp webhook.
- **API base URL:** `AppConfig.apiBaseUrl` defaults to `http://localhost:3001/api/v1` in debug builds and to the placeholder `https://rmbroker.example.com/api/v1` in release builds.
- **Attachments:** there are only two storage buckets, `brokerbridge_documents` (deal-scoped) and `brokerbridge_lab_evidence` (listing-scoped). Neither is authorized for support attachments.
- **Existing data:** 0 rows in `support_tickets`.
- **Related existing defect:** RMSeller `SellerRatingsRepository.submitBrokerRating` inserts into `support_tickets` from the mobile client. With no INSERT grant, that insert is denied in production, and the repository catches the error. Out of scope; recorded here.

### 2.2 My Support Tickets: no read path or history model

- **No read access:** there is no SELECT grant or policy for `authenticated`, so a Buyer can't read even their own tickets.
- **No history model:** there is no conversation/history table, no "latest response" field, and no internal-notes field. Any Admin reply or internal note would have nowhere to live, so "internal notes stay private" can't be designed yet.
- **Statuses:** only `'Open'` (the default) and `'Resolved'` (set by `resolveTicketAction`). The expected labels (Submitted, Under Review, In Progress, Waiting for Buyer, Resolved, Closed) are not part of any workflow.

### 2.3 Contact Admin Support: no channel

- **No configured address:** no support email, phone or helpline key exists in `.env`, `.env.local` or the RMBuyer `AppConfig`. Only key names were checked; no values were read.
- **Not trusted configuration:** the only support-looking address in code is `support@brokerbridge.com`, hardcoded in a RMBroker access-denied message, and the `vetkindinfo@…` address on the separate VetKind site. Neither is the platform's support channel.
- **Ticket path blocked:** the in-app ticket route is blocked as described in §2.1.

### 2.4 WhatsApp: no official number

- **Server-only keys:** the environment has only server-side WhatsApp Business API keys (`WHATSAPP_API_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`, `WHATSAPP_WEBHOOK_VERIFY_TOKEN`), used by `src/server/services/whatsapp-service.ts` for outbound messages. None is a public support number a Buyer can chat with.
- **Seller app:** RMSeller's Help screen says helpline and WhatsApp numbers are "scheduled for release".
- **Launcher ready:** the existing `ContactLauncherService.launchWhatsApp` (a `wa.me` link with a prefilled text that the user sends) is ready to reuse once a number is configured.

### 2.5 Ticket notifications

- **Buyer access:** buyers can only SELECT/UPDATE their own `notifications` rows; they have no INSERT, which is correct.
- **No support notification:** there is no trigger on `support_tickets`, and `resolveTicketAction` doesn't create a notification. Live event types are only `REQUIREMENT_CREATED` and `DEAL_VERSION_UPDATE`.
- **Deep link possible:** the `notifications.action_url` column exists and could link to a ticket once tickets exist.

### 2.6 Roles

- **Live roles:** `users.role` holds `admin` (1), `broker` (2), `buyer` (9) and `seller` (7). There is **no Admin Support role**.
- **Web gating:** support actions are gated on `role === 'admin'`, and the admin web console has a "helpdesk" tab (`MasterDataTabs.tsx`) that uses them.

## 3. Proposed changes (approval required; not applied)

**A1 — Ticket creation, Buyer-scoped (recommended: SECURITY DEFINER RPC, no direct table grants).** One migration:

```sql
-- DRAFT ONLY
ALTER TABLE public.support_tickets
  ADD COLUMN IF NOT EXISTS title text,
  ADD COLUMN IF NOT EXISTS app_context jsonb;          -- app version, platform, OS (no secrets)

CREATE OR REPLACE FUNCTION public.create_support_ticket(
  p_title text, p_issue_type text, p_description text, p_app_context jsonb DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_role text; v_id uuid;
BEGIN
  SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
  IF v_role IS NULL THEN RAISE EXCEPTION 'not a registered user'; END IF;
  IF length(trim(p_title)) < 3 OR length(trim(p_description)) < 10 THEN
    RAISE EXCEPTION 'invalid ticket';
  END IF;
  INSERT INTO public.support_tickets (user_id, role, title, issue_type, description, app_context)
  VALUES (auth.uid(), v_role, trim(p_title), p_issue_type, trim(p_description), p_app_context)
  RETURNING id INTO v_id;
  RETURN v_id;                                         -- the real ID the app displays
END $$;
REVOKE ALL ON FUNCTION public.create_support_ticket(text,text,text,jsonb) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.create_support_ticket(text,text,text,jsonb) TO authenticated;
```

**A2 — Buyer reads own tickets.** Either an RPC `my_support_tickets()` returning only that user's buyer-safe columns, or `GRANT SELECT` plus the policy `user_id = auth.uid() OR is_admin()`. The RPC is preferred: when messages arrive, it can exclude internal fields.

**A3 — Conversation and internal notes (needed before "My Tickets" can show responses).** One table, with the visibility rules enforced in RPCs, not only in the UI:
- `support_ticket_messages(id, ticket_id, author_id, author_role, body, is_internal boolean default false, created_at)`;
- Buyer RPCs return only `is_internal = false` rows for their own ticket;
- Buyers may post only non-internal messages on their own open tickets;
- the agreed status set, enforced with a CHECK constraint or the RPC (e.g. Submitted / Under Review / In Progress / Waiting for Buyer / Resolved / Closed).

**A4 — Admin Support role decision.** Either reuse `admin`, as the web helpdesk does today, or introduce a dedicated `support` role in `users.role` and in `app_metadata` (`get_auth_role`), with `is_support()` checks in the A2/A3 RPCs. This is an auth/role change.

**A5 — Notifications.** On an admin reply or status change (in the admin RPC or the existing `resolveTicketAction`), insert into `notifications` server-side: `user_id` is the ticket owner, `event_type = 'SUPPORT_TICKET_UPDATE'`, `action_url = '/support/tickets/<id>'`, and the payload has no internal text.

**A6 — Attachments (optional).** A private bucket `support_attachments` with an object path of `<ticket_id>/…`, readable by the ticket owner and support staff only.

**A7 — Contact configuration.** The owner supplies the official support WhatsApp number (and, optionally, a support email). It should be delivered as trusted configuration: a build-time `--dart-define=SUPPORT_WHATSAPP_NUMBER=…`, or a read-only `app_settings` row. The number must not be hardcoded in the app.

**A8 — Hardening (related).** Fix or remove RMSeller's direct `support_tickets` insert (§2.1) once A1 exists.

## 4. What becomes buildable after approval

| Approved | Buyer app work (small, no further backend) |
|---|---|
| A1 (+A7 optional) | Help & Support menu entry; Report a Bug form with validation, category list (`App bug`, `Login / account`, `Requirements & offers`, `Deals & documents`, `Other`), app version (`AppConfig.appVersion`) and platform/OS; shows the RPC-returned ID only on success; double-submit guard. Contact Admin Support is the same flow. |
| A2 | My Support Tickets list (own tickets, real ID, title, date, status) |
| A3 + A4 | Ticket detail with public replies; Buyer reply where allowed; ownership and internal-note privacy tests against the RPCs |
| A5 | Notification deep link to the ticket |
| A7 | WhatsApp button through the existing `ContactLauncherService` (prefilled, the user sends it); hidden when not configured |

## 5. Verification

| Check | Result |
|---|---|
| 1. Help & Support opens from Profile & Settings | Not built (all items blocked; no nonfunctional menu added) |
| 2–4. Bug report validation, real ticket ID, no false success | Blocked (A1) |
| 5–7. Ownership, internal-note privacy, Admin authorization | Blocked (A2–A4). Today buyers are fully denied at the database (no grants), so no cross-Buyer exposure exists |
| 8. Statuses and responses | Blocked (A3) |
| 9. WhatsApp | Blocked (A7) |
| 10. Notifications | Blocked (A5) |
| 11. Existing profile, navigation and notifications | Unchanged: no code changed. The last full RMBuyer run (previous sprint) was 244 passed, 4 skipped |
| Formatter, analyze and tests | Not run: no code changes |

## 6. Git diff

There are no source changes. The only new file is this report. Earlier uncommitted work (RMBuyer profile/language, RMSeller quantity/price, and the earlier reports) is untouched.
