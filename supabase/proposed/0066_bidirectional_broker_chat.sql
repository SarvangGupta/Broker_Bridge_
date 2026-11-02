-- Migration: 0066_bidirectional_broker_chat.sql
-- Micro-Sprint: RM-CHAT-BIDIRECTIONAL-E2E-01
-- Extends the 0043 chat (same tables, same RLS, same realtime) so that:
--   * a seller can open a conversation with a broker (as buyers already can);
--   * a broker can open a conversation with a buyer or seller the desk already
--     works with (CRM contact, assigned requirement, or managed lot);
--   * both sides then reply through the existing chat_send_message path.
--
-- Model: one conversation per (client user, broker user). The 0043 column
-- chat_conversations.buyer_id now holds the client participant, who is an
-- active buyer OR seller; the name is kept so 0043 clients keep working.
-- Every conversation still has exactly one active broker, so a buyer and a
-- seller can never share a conversation (Counterparty Shield).
--
-- No table, column, RLS policy or grant on existing tables changes.
-- NOT APPLIED. Requires owner approval. Depends on 0043.

BEGIN;

COMMENT ON COLUMN public.chat_conversations.buyer_id IS
  'Client participant: an active buyer or seller user (0066). Column name kept from 0043.';

-- ============================================================================
-- 1. Broker -> client relationship check (internal)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.chat_broker_may_contact(p_broker UUID, p_client UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.chat_conversations c
    WHERE c.broker_id = p_broker AND c.buyer_id = p_client
  ) OR EXISTS (
    SELECT 1 FROM public.crm_contacts cc
    JOIN public.users u ON u.id = p_client
    WHERE cc.broker_id = p_broker
      AND (cc.user_id = p_client OR (u.company_id IS NOT NULL AND cc.company_id = u.company_id))
  ) OR EXISTS (
    SELECT 1 FROM public.requirements r
    JOIN public.users u ON u.id = p_client
    WHERE r.broker_id = p_broker AND lower(u.role) = 'buyer'
      AND u.company_id IS NOT NULL AND r.company_id = u.company_id
  ) OR EXISTS (
    SELECT 1 FROM public.availabilities a
    JOIN public.users u ON u.id = p_client
    WHERE a.broker_id = p_broker AND lower(u.role) = 'seller'
      AND (a.seller_user_id = p_client OR (u.company_id IS NOT NULL AND a.company_id = u.company_id))
  );
$$;

REVOKE ALL ON FUNCTION public.chat_broker_may_contact(UUID, UUID) FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- 2. chat_send_message: same signature and behaviour as 0043, except the
--    client side may be a buyer or a seller.
-- ============================================================================
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
    IF v_me.role NOT IN ('buyer', 'seller') THEN
      RAISE EXCEPTION 'Only buyers and sellers can start a broker conversation' USING ERRCODE = '42501';
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
      WHERE u.id = v_conv.buyer_id AND lower(u.role) IN ('buyer', 'seller') AND u.status = true
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

  IF v_msg.id IS NULL THEN
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
-- 3. chat_send_message_to: first message to a specific user (any role).
--    Brokers reach related buyers/sellers; buyers and sellers reach brokers
--    (delegates to the 0043 path). Conversation + message are one transaction.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.chat_send_message_to(
  p_body TEXT,
  p_client_message_id UUID,
  p_counterpart_id UUID
)
RETURNS public.chat_messages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_role TEXT;
  v_conv_id UUID;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;
  IF p_counterpart_id IS NULL OR p_counterpart_id = v_uid THEN
    RAISE EXCEPTION 'Invalid chat request' USING ERRCODE = '22023';
  END IF;

  SELECT lower(role) INTO v_role FROM public.users WHERE id = v_uid AND status = true;
  IF v_role IN ('buyer', 'seller') THEN
    RETURN public.chat_send_message(p_body, p_client_message_id, p_counterpart_id, NULL);
  END IF;
  IF v_role IS DISTINCT FROM 'broker' THEN
    RAISE EXCEPTION 'Not authorized to chat' USING ERRCODE = '42501';
  END IF;

  -- One error for "no such user", "wrong role", "inactive" and "unrelated",
  -- so a broker cannot probe the user directory through chat.
  IF NOT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = p_counterpart_id AND lower(u.role) IN ('buyer', 'seller') AND u.status = true
  ) OR NOT public.chat_broker_may_contact(v_uid, p_counterpart_id) THEN
    RAISE EXCEPTION 'Contact not available for chat' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.chat_conversations (buyer_id, broker_id)
  VALUES (p_counterpart_id, v_uid)
  ON CONFLICT ON CONSTRAINT chat_conversations_pair_key DO NOTHING;

  SELECT id INTO v_conv_id FROM public.chat_conversations
  WHERE buyer_id = p_counterpart_id AND broker_id = v_uid;

  RETURN public.chat_send_message(p_body, p_client_message_id, NULL, v_conv_id);
END;
$$;

REVOKE ALL ON FUNCTION public.chat_send_message_to(TEXT, UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chat_send_message_to(TEXT, UUID, UUID) TO authenticated;

-- ============================================================================
-- 4. Broker: who to chat with for a requirement or a lot on the desk.
--    Returns names only (never phone/email), only for the broker's own
--    assigned requirement / managed lot.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.chat_contacts_for_context(
  p_requirement_id UUID DEFAULT NULL,
  p_availability_id UUID DEFAULT NULL
)
RETURNS TABLE (user_id UUID, name TEXT, role TEXT, company TEXT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT u.id, u.name, lower(u.role), co.name
  FROM public.users u
  LEFT JOIN public.companies co ON co.id = u.company_id
  WHERE public.is_broker()
    AND u.status = true
    AND (
      (lower(u.role) = 'buyer' AND EXISTS (
        SELECT 1 FROM public.requirements r
        WHERE r.id = p_requirement_id AND r.broker_id = auth.uid()
          AND u.company_id IS NOT NULL AND r.company_id = u.company_id))
      OR
      (lower(u.role) = 'seller' AND EXISTS (
        SELECT 1 FROM public.availabilities a
        WHERE a.id = p_availability_id AND a.broker_id = auth.uid()
          AND (a.seller_user_id = u.id OR (u.company_id IS NOT NULL AND a.company_id = u.company_id))))
    )
  ORDER BY u.name, u.id;
$$;

REVOKE ALL ON FUNCTION public.chat_contacts_for_context(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chat_contacts_for_context(UUID, UUID) TO authenticated;

-- ============================================================================
-- 5. Inbox: 0043 columns plus the counterpart's role (buyer/seller/broker).
--    The return type changes, so the function is dropped and recreated.
-- ============================================================================
DROP FUNCTION IF EXISTS public.chat_inbox(UUID);
CREATE FUNCTION public.chat_inbox(p_conversation_id UUID DEFAULT NULL)
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
  counterpart_last_read_at TIMESTAMPTZ,
  counterpart_role TEXT
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
    CASE WHEN auth.uid() = c.buyer_id THEN c.broker_last_read_at ELSE c.buyer_last_read_at END,
    lower(cp.role)
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

COMMIT;
