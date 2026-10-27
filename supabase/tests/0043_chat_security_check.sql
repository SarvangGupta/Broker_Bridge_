-- Server-side verification for 0043_buyer_broker_chat.sql.
-- Runs entirely inside a transaction that is ROLLED BACK: nothing persists.
-- Run only after 0043 is applied, and only with owner approval (it executes
-- writes inside the transaction against whatever database it is pointed at).
--
-- Usage (psql): \set buyer_a '<uuid>' etc., or edit the four ids below.
-- Prereqs: buyer_a, buyer_b = active users.role='buyer'; broker_x = active broker;
-- seller_s = active seller. Use RBTEST/demo accounts, never real customers.

BEGIN;

CREATE TEMP TABLE ids AS SELECT
  '00000000-0000-0000-0000-00000000000a'::uuid AS buyer_a,   -- EDIT
  '00000000-0000-0000-0000-00000000000b'::uuid AS buyer_b,   -- EDIT
  '00000000-0000-0000-0000-0000000000b1'::uuid AS broker_x,  -- EDIT
  '00000000-0000-0000-0000-0000000000c1'::uuid AS seller_s;  -- EDIT
GRANT SELECT ON ids TO authenticated;

-- Preflight: fail fast with a clear message instead of "function does not exist".
DO $$
DECLARE r RECORD;
BEGIN
  IF to_regprocedure('public.chat_send_message(text,uuid,uuid,uuid)') IS NULL
     OR to_regclass('public.chat_conversations') IS NULL THEN
    RAISE EXCEPTION 'Migration 0043 is not applied in this database. Apply 0043_buyer_broker_chat.sql first.';
  END IF;
  SELECT * INTO r FROM ids;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = r.buyer_a  AND lower(role) = 'buyer'  AND status)
  OR NOT EXISTS (SELECT 1 FROM public.users WHERE id = r.buyer_b  AND lower(role) = 'buyer'  AND status)
  OR NOT EXISTS (SELECT 1 FROM public.users WHERE id = r.broker_x AND lower(role) = 'broker' AND status)
  OR NOT EXISTS (SELECT 1 FROM public.users WHERE id = r.seller_s AND lower(role) = 'seller' AND status) THEN
    RAISE EXCEPTION 'Edit the ids table: need 2 active buyers, 1 active broker, 1 active seller (placeholders still set?)';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION pg_temp.act_as(u uuid) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
$$;

CREATE TEMP TABLE results (check_name text, passed boolean);
GRANT ALL ON results TO authenticated;

SET LOCAL ROLE authenticated;

-- 1. Buyer A starts a conversation atomically with the first message.
SELECT pg_temp.act_as(buyer_a) FROM ids;
SELECT public.chat_send_message('RBTEST hello', '11111111-1111-4111-8111-111111111111', (SELECT broker_x FROM ids));
-- Retry with the same key: no duplicate.
SELECT public.chat_send_message('RBTEST hello', '11111111-1111-4111-8111-111111111111', (SELECT broker_x FROM ids));
-- Second message via the broker id again: same conversation.
SELECT public.chat_send_message('RBTEST again', '22222222-2222-4222-8222-222222222222', (SELECT broker_x FROM ids));
INSERT INTO results SELECT 'one conversation per pair',
  (SELECT count(*) FROM chat_conversations c, ids WHERE c.buyer_id = ids.buyer_a AND c.broker_id = ids.broker_x) = 1;
INSERT INTO results SELECT 'idempotent retry',
  (SELECT count(*) FROM chat_messages) = 2;

-- 2. Broker replies by conversation id and sees it in the inbox.
SELECT pg_temp.act_as(broker_x) FROM ids;
INSERT INTO results SELECT 'broker inbox shows buyer, unread=2',
  (SELECT unread_count = 2 FROM public.chat_inbox() i, ids WHERE i.counterpart_id = ids.buyer_a);
SELECT public.chat_send_message('RBTEST reply', '33333333-3333-4333-8333-333333333333', NULL,
  (SELECT id FROM chat_conversations));
SELECT public.chat_mark_read((SELECT id FROM chat_conversations));
INSERT INTO results SELECT 'broker unread cleared',
  (SELECT unread_count = 0 FROM public.chat_inbox());

-- 3. Notifications: one per message, to the other participant only.
RESET ROLE;
INSERT INTO results SELECT 'notifications to recipient only',
  (SELECT count(*) FILTER (WHERE n.user_id = ids.broker_x) = 2
      AND count(*) FILTER (WHERE n.user_id = ids.buyer_a) = 1
   FROM notifications n, ids WHERE n.event_type = 'CHAT_MESSAGE'
     AND n.payload->>'conversationId' = (SELECT id::text FROM chat_conversations));
SET LOCAL ROLE authenticated;

-- 4. Buyer B: cannot see, read or post into Buyer A's conversation.
SELECT pg_temp.act_as(buyer_b) FROM ids;
INSERT INTO results SELECT 'other buyer sees no conversations', (SELECT count(*) FROM chat_conversations) = 0;
INSERT INTO results SELECT 'other buyer sees no messages', (SELECT count(*) FROM chat_messages) = 0;
INSERT INTO results SELECT 'other buyer inbox empty', (SELECT count(*) FROM public.chat_inbox()) = 0;
DO $$ BEGIN
  PERFORM public.chat_send_message('RBTEST intrude', gen_random_uuid(), NULL,
    (SELECT c.id FROM public.chat_conversations c LIMIT 1));
  INSERT INTO results VALUES ('other buyer cannot post by id', false);
EXCEPTION WHEN OTHERS THEN INSERT INTO results VALUES ('other buyer cannot post by id', true);
END $$;

-- 5. Role rules: seller cannot start; buyer cannot target seller; broker cannot start.
SELECT pg_temp.act_as(seller_s) FROM ids;
DO $$ BEGIN
  PERFORM public.chat_send_message('x', gen_random_uuid(), (SELECT broker_x FROM ids));
  INSERT INTO results VALUES ('seller cannot start chat', false);
EXCEPTION WHEN OTHERS THEN INSERT INTO results VALUES ('seller cannot start chat', true);
END $$;
SELECT pg_temp.act_as(buyer_a) FROM ids;
DO $$ BEGIN
  PERFORM public.chat_send_message('x', gen_random_uuid(), (SELECT seller_s FROM ids));
  INSERT INTO results VALUES ('buyer cannot chat a seller', false);
EXCEPTION WHEN OTHERS THEN INSERT INTO results VALUES ('buyer cannot chat a seller', true);
END $$;
SELECT pg_temp.act_as(broker_x) FROM ids;
DO $$ BEGIN
  PERFORM public.chat_send_message('x', gen_random_uuid(), (SELECT broker_x FROM ids));
  INSERT INTO results VALUES ('broker cannot start chat', false);
EXCEPTION WHEN OTHERS THEN INSERT INTO results VALUES ('broker cannot start chat', true);
END $$;

-- 6. No direct writes, empty bodies rejected.
DO $$ BEGIN
  INSERT INTO public.chat_messages (conversation_id, sender_id, body, client_message_id)
  SELECT id, (SELECT broker_x FROM ids), 'forged', gen_random_uuid() FROM public.chat_conversations LIMIT 1;
  INSERT INTO results VALUES ('no direct INSERT', false);
EXCEPTION WHEN OTHERS THEN INSERT INTO results VALUES ('no direct INSERT', true);
END $$;
DO $$ BEGIN
  PERFORM public.chat_send_message('   ', gen_random_uuid(), NULL, (SELECT id FROM public.chat_conversations LIMIT 1));
  INSERT INTO results VALUES ('whitespace rejected', false);
EXCEPTION WHEN OTHERS THEN INSERT INTO results VALUES ('whitespace rejected', true);
END $$;

RESET ROLE;
SELECT check_name, passed FROM results;
SELECT bool_and(passed) AS all_passed, count(*) AS checks FROM results;

ROLLBACK;
