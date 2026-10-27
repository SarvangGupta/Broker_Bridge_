# BROKERBRIDGE-CHAT-E2E-01 — Buyer ↔ Broker Chat

## Status: **BLOCKED** (awaiting approval to apply migration 0043)

Everything needed for real Buyer↔Broker messaging is **implemented and tested against an in-memory server**. That covers the backend migration, the RMBuyer UI, the RMBroker UI, realtime, read state and notifications.

It is **not live**:
- The chat tables and RPCs don't exist in the only database (production `imztlkvkxzeaekxvmcfe`).
- Applying them requires your approval.
- So no real Buyer→Broker→Buyer exchange has been verified.

The completion rules require that verification, so the status is BLOCKED, not PASS. Until 0043 is applied, tapping Chat shows a load error with Retry, not a fake screen.

Date: 2026-10-26 · Branch `feature/broker-nilesh` · all changes uncommitted

## 1. Audit findings
| Area | Finding |
|---|---|
| Existing chat | **None.** The repo, migrations 0001–0042, RMBuyer and RMBroker have no chat, conversation or message tables, RPCs, routes or screens. Built new; nothing duplicated. |
| Live DB check | Read-only verification against the live DB was **blocked by the tool permission gate**. Evidence comes from the repo migrations, which are the documented source of applied schema. **Before applying, confirm in the live DB that no `chat_*` tables exist.** |
| Identity | `auth.uid()` = `public.users.id` (relied on by 0040). Role/status come from `public.users` (`role`, `status`), which users can't change on their own row (0037), plus `get_auth_role()`. |
| Notifications | `public.notifications`: in-app rows with `idempotency_key UNIQUE`. Clients have SELECT/UPDATE on their own rows only; inserts happen through SECURITY DEFINER RPCs (pattern from 0040). No push/FCM infrastructure exists. |
| Realtime | The `supabase_realtime` publication exists (0008 added deals and quotations). |
| Attachments | No private storage or attachment pipeline for chat, so attachments are **not offered** (no button shown). |

## 2. Backend (prepared, NOT applied)
- `supabase/migrations/0043_buyer_broker_chat.sql`
- `supabase/migrations/rollback_0043.sql`
- `supabase/tests/0043_chat_security_check.sql`: server-side check that runs inside a rolled-back transaction.

**Tables**
- **`chat_conversations`:** `id`, `buyer_id`, `broker_id`, `last_message_at`, `last_message_preview`, `last_sender_id`, and `buyer_last_read_at`/`broker_last_read_at`.
  - `UNIQUE (buyer_id, broker_id)` gives one canonical thread per pair.
  - A CHECK requires buyer ≠ broker.
- **`chat_messages`:** `id`, `conversation_id`, `sender_id`, `body` (CHECK 1–2000 characters after trimming), `client_message_id`, `created_at` (server `clock_timestamp()`).
  - `UNIQUE (conversation_id, sender_id, client_message_id)` is the idempotency key.

**Access**
- RLS is enabled. `authenticated` gets **SELECT only**; the policy is participant-only (`auth.uid()` is the buyer or broker).
- **No INSERT/UPDATE/DELETE grants.** `anon` gets nothing.

**RPCs** (SECURITY DEFINER, `search_path = public`, EXECUTE granted to `authenticated` only)
- **`chat_send_message(body, client_message_id, broker_id?, conversation_id?)`:** the sender is always `auth.uid()`.
  - **Start (`broker_id`):** the caller must be an active `buyer` and the target an active `broker`. The conversation upsert (`ON CONFLICT DO NOTHING` + `FOR UPDATE` re-select) is atomic and safe under concurrency.
  - **Reply (`conversation_id`):** the caller must be a participant, and both participants must still be active in their roles. "Not found" and "not yours" return the same error, so ids can't be probed.
  - **Retries:** a retried `client_message_id` returns the original row with no new message or notification.
  - **On success:** updates the conversation metadata, marks the sender's own side read, and inserts **one** `CHAT_MESSAGE` notification for the *other* participant.
    - `idempotency_key = 'chat-msg-<message id>'`, `action_url = '/chats/<id>'`, payload `{conversationId, messageId}`.
    - The text is lock-screen safe: "New message from <name>", **never the body**.
- **`chat_mark_read(conversation_id)`:** updates only the caller's own `*_last_read_at`, monotonic via `greatest()`. It also marks that conversation's chat notifications read.
- **`chat_inbox(conversation_id?)`:** returns only the caller's conversations, with the counterpart's **name and company name only** (no phone or email).
  - Unread count is the counterpart's messages newer than the caller's read mark; outgoing messages never count.
  - Also returns the counterpart's read mark, which powers "Seen".
- **Realtime:** `chat_messages` and `chat_conversations` are added to `supabase_realtime`. `postgres_changes` honours the SELECT policies, so only participants receive events.

**Business rules enforced in the database**
- Buyer↔Broker only: sellers and admins can't participate, a buyer can't target a seller, and brokers can't start threads.
- Directory visibility is not used for authorization.
- No deal, proposal, requirement or seller visibility rules were touched.

## 3. Client changes
### RMBuyer (`apps/rmbuyer_mobile`)
**New:**
- `lib/features/chat/domain/chat_models.dart`: message and summary models, `kChatMaxLength`, v4 client ids.
- `lib/features/chat/data/chat_gateway.dart`: `ChatGateway` interface plus the Supabase implementation (RPCs, filtered realtime channel, `removeChannel` on cancel).
- `lib/features/chat/presentation/chat_controller.dart`: state, merge and dedupe, optimistic sends, retry, pagination, reconnect resync, read marking.
- `lib/features/chat/presentation/chat_screen.dart`:
  - New-conversation state ("Start a conversation") and active chat.
  - Bubbles with day separators and real timestamps; "Sending…", "Not sent" + Retry, and "Seen" only from real read data.
  - A reconnecting banner, and a keyboard- and safe-area-aware composer.
  - Plain-text rendering.
- `lib/features/chat/presentation/chat_inbox_screen.dart`: "Messages" list newest first, with preview, time, unread badge, and empty, loading and error states.

**Modified:**
- `lib/app/router/app_router.dart`: added `/chats`, `/chats/broker/:brokerId` and `/chats/:id`.
- `lib/features/search/presentation/broker_profile_screen.dart`: the Chat icon is enabled and opens `/chats/broker/<id>`, guarded against repeat taps.
- `lib/features/search/presentation/widgets/broker_result_card.dart`: the card's Chat button is enabled in the same way, and the unused "chat unavailable" constant was removed.
- `lib/features/home/presentation/more_screen.dart`: new **Messages** tile (the inbox entry point; no new bottom tab).
- `lib/features/notifications/domain/buyer_notification_model.dart` and `presentation/buyer_notifications_screen.dart`: a new `chat` target, resolved from `payload.conversationId` or a `/chats/<uuid>` URL (UUID-validated), which opens the conversation.

**Tests:**
- New: `test/support/fake_chat_gateway.dart`, `test/unit/chat_controller_test.dart`, `test/widgets/chat_screen_test.dart`.
- Updated: `broker_profile_screen_test.dart` and `broker_result_card_test.dart`.

### RMBroker (`apps/rmbroker_mobile`)
- **New:** `lib/features/chat/**`, identical to RMBuyer's module, which uses only shared theme tokens.
- **Modified:**
  - `lib/app/router/app_router.dart`: `/chats` and `/chats/:id`. Brokers reply only and never start threads.
  - `lib/features/more/presentation/more_screen.dart`: **Messages** tile.
  - `lib/features/notifications/domain/notification_model.dart`: `conversationId` getter; `resolvedRoute` returns `/chats/<id>` first; `isActionable` covers chat.
- **Tests:** new `test/support/fake_chat_gateway.dart` and `test/features/chat/broker_chat_test.dart`; updated `test/features/more/more_screen_test.dart`.

## 4. Behaviour
**Conversation lookup**
- Buyer taps Chat → `chat_conversations` is filtered by `buyer_id = me AND broker_id = X` (RLS-limited).
- If found: loads history, subscribes and marks read. If not: shows "Start a conversation".
- The first send creates the thread server-side, then the screen subscribes.

**Sending**
- Empty or whitespace text is rejected, and so is anything over 2000 characters.
- The Send button is disabled while the field is empty.
- After a hand-off the input clears and a pending bubble appears.
- On failure the bubble stays with its text, marked "Not sent", with Retry.
- Retry reuses the same `client_message_id`, so a lost response can't create a duplicate.

**Deduplication**
- The send response, realtime echo and history refresh are merged by server id and by (sender, client id).
- Order is server `created_at`, then id.

**Realtime and reconnect**
- Uses Supabase Realtime `postgres_changes` filtered by `conversation_id`.
- On a channel error or timeout a "Reconnecting…" banner shows. When the channel is live again, history resyncs, and it also resyncs when the app returns to the foreground.
- The subscription is removed when leaving the screen.

**Pagination:** 50 per page, loading older messages on scroll-up via `created_at < oldest`.

**Read state**
- Opening or viewing a thread, and every incoming live message, calls `chat_mark_read`, which persists on the server.
- "Seen" appears under the latest outgoing message only when the counterpart's read mark covers it.

**Notifications**
- In-app only (the existing pipeline); **no push** exists in the platform.
- Tapping a chat notification opens `/chats/<id>` in either app, and the screen re-verifies participation through RLS.

**Not built (no backend support):** presence/online, typing indicators, calls, attachments.

## 5. Test results
| Check | Result |
|---|---|
| RMBuyer `flutter analyze` | No issues found |
| RMBuyer `flutter test test/widget_test.dart test/widgets test/unit` | **344 passed, 4 skipped, 0 failed** |
| RMBuyer `flutter build apk --debug` | Built |
| RMBroker `flutter analyze` | No issues found |
| RMBroker `flutter test test/features/chat test/features/notifications` | 50 passed |
| RMBroker full `flutter test` | **483 passed, 0 failed**. `test/features/more/more_screen_test.dart` now scrolls to Settings, which the new Messages tile pushes below the fold at 320dp; there is no overflow |
| RMBroker `flutter build apk --debug` | Built |
| `dart format` | All new and modified chat files in RMBuyer |

**Covered by tests (against the fake server, which mirrors 0043's rules):**
- **Conversations:** a new conversation is created on first send and reused on reopen. Concurrent first sends produce one conversation.
- **Exchange:** a buyer message reaches the broker, the reply reaches the open buyer screen live, and history reloads in order after an "app restart".
- **Sending:**
  - no echo duplicates;
  - empty, whitespace and over-limit messages rejected;
  - failed send → Retry → exactly one stored message;
  - a lost-response retry is deduplicated;
  - pending → sent.
- **Authorization:**
  - another buyer can't read or post by id;
  - brokers and sellers can't start conversations;
  - a buyer can't target a seller;
  - one notification per message, to the recipient only.
- **Read state:** unread counts and their clearing; "Seen" only after the counterpart reads.
- **Realtime:** reconnect resync of a missed message; unsubscribe on leave; pagination without duplicates.
- **Navigation:**
  - Chat icon routes for the exact broker, once, with back returning to the profile;
  - chat notifications route correctly in both apps;
  - the inbox shows the caller's threads only, newest first, with unread badges.
- **Layout:** a 320px long-message layout has no overflow.

**Not verified (BLOCKED):**
- Real database authorization.
- Real realtime delivery.
- A real Buyer→Broker→Buyer exchange.

These need 0043 applied. The fake tests prove the client logic and the rules as specified; they don't prove the SQL itself. `0043_chat_security_check.sql` covers the same rules against real Postgres with simulated JWTs.

## 6. Approvals needed to reach PASS
1. **A1: Apply `0043_buyer_broker_chat.sql`** to `imztlkvkxzeaekxvmcfe`. It adds 2 tables, 3 RPCs and 2 publication entries; nothing existing is altered. Rollback: `rollback_0043.sql`.
2. **A2: Run `supabase/tests/0043_chat_security_check.sql`** with RBTEST ids (two buyers, one broker, one seller). It writes only inside a rolled-back transaction.
3. **A3: Device E2E.**
   - Install both debug APKs.
   - Buyer test account → Varun's profile → Chat → send.
   - Varun (`varun@gmail.com`) on RMBroker → Messages → reply.
   - Confirm the buyer receives it live and after reopening.
   - **This writes real chat rows and notifications to production**, so please confirm which accounts to use.
4. **Optional follow-ups:** push notifications (no FCM exists), attachments (needs private storage and policies), and presence.

## 7. Confirmations
- **Not applied, deployed or committed:** no migration was applied, no database writes were made, no deployment happened, and nothing was committed or pushed.
- **Live DB access:** the one attempted live connection was a `BEGIN READ ONLY` audit, and the permission gate blocked it.
- **Unrelated work:** pre-existing uncommitted changes in RMBuyer, RMBroker and RMSeller were preserved.
