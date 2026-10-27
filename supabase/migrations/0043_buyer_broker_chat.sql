-- Migration: 0043_buyer_broker_chat.sql
-- Micro-Sprint: BROKERBRIDGE-CHAT-E2E-01
-- Buyer <-> Broker chat: one canonical conversation per (buyer user, broker user).
--
-- Security model:
-- 1. Clients get SELECT only (RLS: participants of the conversation). No direct
--    INSERT/UPDATE/DELETE grants; every write goes through SECURITY DEFINER RPCs.
-- 2. Sender identity is always auth.uid(); roles come from public.users
--    (role + status), which users cannot change on their own row (0037).
-- 3. Only an active buyer can open a conversation, and only with an active broker.
--    Sellers and admins cannot be chat participants (Counterparty Shield).
-- 4. Conversation creation is atomic: UNIQUE (buyer_id, broker_id) + ON CONFLICT.
-- 5. Message sends are idempotent per (conversation, sender, client_message_id).
-- 6. One in-app notification per persisted message (idempotency_key = message id).
-- NOT APPLIED. Requires owner approval before running against any shared database.

BEGIN;

-- ============================================================================
-- 1. Tables
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.chat_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  buyer_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  broker_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_message_at TIMESTAMPTZ,
  last_message_preview TEXT,
  last_sender_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  buyer_last_read_at TIMESTAMPTZ,
  broker_last_read_at TIMESTAMPTZ,
  CONSTRAINT chat_conversations_pair_key UNIQUE (buyer_id, broker_id),
  CONSTRAINT chat_conversations_distinct_participants CHECK (buyer_id <> broker_id)
);

CREATE INDEX IF NOT EXISTS chat_conversations_broker_idx
  ON public.chat_conversations (broker_id, last_message_at DESC);
CREATE INDEX IF NOT EXISTS chat_conversations_buyer_idx
  ON public.chat_conversations (buyer_id, last_message_at DESC);

CREATE TABLE IF NOT EXISTS public.chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.chat_conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  client_message_id UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT chat_messages_body_len CHECK (
    length(btrim(body)) BETWEEN 1 AND 2000
  ),
  CONSTRAINT chat_messages_idempotency_key UNIQUE (conversation_id, sender_id, client_message_id)
);

CREATE INDEX IF NOT EXISTS chat_messages_conversation_idx
  ON public.chat_messages (conversation_id, created_at DESC, id DESC);

-- ============================================================================
-- 2. RLS + grants: participants may read; nobody writes directly
-- ============================================================================
ALTER TABLE public.chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.chat_conversations FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.chat_messages FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.chat_conversations TO authenticated;
GRANT SELECT ON TABLE public.chat_messages TO authenticated;

DROP POLICY IF EXISTS chat_conversations_participant_select ON public.chat_conversations;
CREATE POLICY chat_conversations_participant_select ON public.chat_conversations
FOR SELECT TO authenticated
USING (auth.uid() = buyer_id OR auth.uid() = broker_id);

DROP POLICY IF EXISTS chat_messages_participant_select ON public.chat_messages;
CREATE POLICY chat_messages_participant_select ON public.chat_messages
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.chat_conversations c
    WHERE c.id = chat_messages.conversation_id
      AND (auth.uid() = c.buyer_id OR auth.uid() = c.broker_id)
  )
);

-- ============================================================================
-- 3. Send (creates the conversation atomically with the first message)
-- ============================================================================
-- Exactly one of p_broker_id (buyer starting/continuing with a broker) or
-- p_conversation_id (either participant replying) must be provided.
CREATE OR REPLACE FUNCTION public.chat_send_message(
  p_body TEXT,
  p_client_message_id UUID,
  p_broker_id UUID DEFAULT NULL,
  p_conversation_id UUID DEFAULT NULL
)
RETURNS public.chat_messages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_me RECORD;
  v_conv public.chat_conversations;
  v_msg public.chat_messages;
  v_body TEXT := btrim(coalesce(p_body, ''));
  v_recipient UUID;
  v_recipient_company UUID;
  v_inserted BOOLEAN := false;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;
  IF length(v_body) = 0 OR length(v_body) > 2000 THEN
    RAISE EXCEPTION 'Message must be 1-2000 characters' USING ERRCODE = '22023';
  END IF;
  IF p_client_message_id IS NULL OR ((p_broker_id IS NULL) = (p_conversation_id IS NULL)) THEN
    RAISE EXCEPTION 'Invalid chat request' USING ERRCODE = '22023';
  END IF;

  SELECT id, lower(role) AS role, name, status INTO v_me
  FROM public.users WHERE id = v_uid;
  IF v_me.id IS NULL OR v_me.status IS NOT TRUE THEN
    RAISE EXCEPTION 'Not authorized to chat' USING ERRCODE = '42501';
  END IF;

  IF p_broker_id IS NOT NULL THEN
    IF v_me.role <> 'buyer' THEN
      RAISE EXCEPTION 'Only buyers can start a broker conversation' USING ERRCODE = '42501';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM public.users b
      WHERE b.id = p_broker_id AND lower(b.role) = 'broker' AND b.status = true
    ) THEN
      RAISE EXCEPTION 'Broker not available for chat' USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.chat_conversations (buyer_id, broker_id)
    VALUES (v_uid, p_broker_id)
    ON CONFLICT ON CONSTRAINT chat_conversations_pair_key DO NOTHING;

    SELECT * INTO v_conv FROM public.chat_conversations
    WHERE buyer_id = v_uid AND broker_id = p_broker_id
    FOR UPDATE;
  ELSE
    SELECT * INTO v_conv FROM public.chat_conversations
    WHERE id = p_conversation_id
    FOR UPDATE;
    IF v_conv.id IS NULL OR v_uid NOT IN (v_conv.buyer_id, v_conv.broker_id) THEN
      -- Same error for "missing" and "not yours" so ids cannot be probed.
      RAISE EXCEPTION 'Conversation not found' USING ERRCODE = '42501';
    END IF;
    -- Both participants must still hold their roles and be active.
    IF NOT EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = v_conv.buyer_id AND lower(u.role) = 'buyer' AND u.status = true
    ) OR NOT EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = v_conv.broker_id AND lower(u.role) = 'broker' AND u.status = true
    ) THEN
      RAISE EXCEPTION 'Conversation is no longer active' USING ERRCODE = '42501';
    END IF;
  END IF;

  INSERT INTO public.chat_messages (conversation_id, sender_id, body, client_message_id)
  VALUES (v_conv.id, v_uid, v_body, p_client_message_id)
  ON CONFLICT ON CONSTRAINT chat_messages_idempotency_key DO NOTHING
  RETURNING * INTO v_msg;
  v_inserted := v_msg.id IS NOT NULL;

  IF NOT v_inserted THEN
    -- Retry of an already-persisted send: return the original, no side effects.
    SELECT * INTO v_msg FROM public.chat_messages
    WHERE conversation_id = v_conv.id AND sender_id = v_uid
      AND client_message_id = p_client_message_id;
    RETURN v_msg;
  END IF;

  UPDATE public.chat_conversations SET
    last_message_at = v_msg.created_at,
    last_message_preview = left(v_body, 140),
    last_sender_id = v_uid,
    buyer_last_read_at = CASE WHEN v_uid = buyer_id THEN v_msg.created_at ELSE buyer_last_read_at END,
    broker_last_read_at = CASE WHEN v_uid = broker_id THEN v_msg.created_at ELSE broker_last_read_at END
  WHERE id = v_conv.id;

  v_recipient := CASE WHEN v_uid = v_conv.buyer_id THEN v_conv.broker_id ELSE v_conv.buyer_id END;
  SELECT company_id INTO v_recipient_company FROM public.users WHERE id = v_recipient;

  -- Lock-screen safe: sender name only, never the message body.
  INSERT INTO public.notifications (
    user_id, company_id, channel, event_type, title, message, context_reason,
    action_label, action_url, payload, delivery_status, idempotency_key, is_read, created_at
  ) VALUES (
    v_recipient, v_recipient_company, 'IN_APP', 'CHAT_MESSAGE',
    'New message from ' || coalesce(nullif(btrim(v_me.name), ''), 'your contact'),
    'Open the conversation to read it.',
    'Direct chat message',
    'Open Chat',
    '/chats/' || v_conv.id::text,
    jsonb_build_object('conversationId', v_conv.id, 'messageId', v_msg.id),
    'Sent',
    'chat-msg-' || v_msg.id::text,
    false,
    now()
  )
  ON CONFLICT (idempotency_key) DO NOTHING;

  RETURN v_msg;
END;
$$;

REVOKE ALL ON FUNCTION public.chat_send_message(TEXT, UUID, UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chat_send_message(TEXT, UUID, UUID, UUID) TO authenticated;

-- ============================================================================
-- 4. Mark read (caller's own side only)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.chat_mark_read(p_conversation_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;
  -- greatest() keeps concurrent marks monotonic.
  UPDATE public.chat_conversations SET
    buyer_last_read_at = CASE WHEN v_uid = buyer_id
      THEN greatest(coalesce(buyer_last_read_at, '-infinity'), now()) ELSE buyer_last_read_at END,
    broker_last_read_at = CASE WHEN v_uid = broker_id
      THEN greatest(coalesce(broker_last_read_at, '-infinity'), now()) ELSE broker_last_read_at END
  WHERE id = p_conversation_id AND v_uid IN (buyer_id, broker_id);

  -- Clear this conversation's chat notifications for the caller.
  UPDATE public.notifications SET is_read = true, read_at = coalesce(read_at, now())
  WHERE user_id = v_uid AND event_type = 'CHAT_MESSAGE' AND is_read = false
    AND payload->>'conversationId' = p_conversation_id::text;
END;
$$;

REVOKE ALL ON FUNCTION public.chat_mark_read(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chat_mark_read(UUID) TO authenticated;

-- ============================================================================
-- 5. Inbox: caller's conversations with the counterpart's public identity
-- ============================================================================
-- Exposes only the counterpart's name and company name (needed by brokers,
-- who may not otherwise read buyer user rows). Never phone/email.
CREATE OR REPLACE FUNCTION public.chat_inbox(p_conversation_id UUID DEFAULT NULL)
RETURNS TABLE (
  conversation_id UUID,
  buyer_id UUID,
  broker_id UUID,
  counterpart_id UUID,
  counterpart_name TEXT,
  counterpart_company TEXT,
  last_message_at TIMESTAMPTZ,
  last_message_preview TEXT,
  last_sender_id UUID,
  unread_count INTEGER,
  counterpart_last_read_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    c.id,
    c.buyer_id,
    c.broker_id,
    cp.id,
    cp.name,
    co.name,
    c.last_message_at,
    c.last_message_preview,
    c.last_sender_id,
    (
      SELECT count(*)::int FROM public.chat_messages m
      WHERE m.conversation_id = c.id
        AND m.sender_id <> auth.uid()
        AND m.created_at > coalesce(
          CASE WHEN auth.uid() = c.buyer_id THEN c.buyer_last_read_at ELSE c.broker_last_read_at END,
          '-infinity')
    ),
    CASE WHEN auth.uid() = c.buyer_id THEN c.broker_last_read_at ELSE c.buyer_last_read_at END
  FROM public.chat_conversations c
  JOIN public.users cp
    ON cp.id = CASE WHEN auth.uid() = c.buyer_id THEN c.broker_id ELSE c.buyer_id END
  LEFT JOIN public.companies co ON co.id = cp.company_id
  WHERE auth.uid() IN (c.buyer_id, c.broker_id)
    AND (p_conversation_id IS NULL OR c.id = p_conversation_id)
  ORDER BY c.last_message_at DESC NULLS LAST, c.created_at DESC;
$$;

REVOKE ALL ON FUNCTION public.chat_inbox(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chat_inbox(UUID) TO authenticated;

-- ============================================================================
-- 6. Realtime (postgres_changes honours the SELECT policies above)
-- ============================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'chat_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'chat_conversations'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_conversations;
  END IF;
END $$;

COMMIT;
