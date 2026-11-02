-- Migration: 0067_chat_context_conversations.sql
-- Micro-Sprint: RM-CHAT-ALLOCATION-PRIVACY-E2E-02
-- Depends on 0043 + 0066 (both verified present in production, read-only, 2026-11-02).
--
-- 1. Conversations may be linked to ONE context: a buyer requirement or a
--    seller offer (availability). One conversation per (client, broker, context);
--    the existing context-less conversations stay as the general thread, so
--    buyer-started 0043 chats keep working unchanged.
-- 2. Context chats are only between the context's assigned broker and its own
--    client: requirement -> its broker + a buyer of its company; offer -> its
--    broker + its owning seller. Buyers and sellers never share a conversation.
-- 3. Replies in a context chat require the context to still be assigned to
--    that broker (reassignment stops the old broker writing; history stays
--    readable to the participants under the unchanged 0043 RLS).
-- 4. Fix: removed CRM contacts (crm_contacts.removed_at) no longer authorise
--    broker-initiated general chats.
--
-- RLS policies and grants on chat tables are unchanged (participants SELECT only;
-- all writes through SECURITY DEFINER functions).
-- NOT APPLIED. Requires owner approval.

BEGIN;

-- Pre-check: 0066 must be present (chat_send_message_to exists).
DO $$
BEGIN
  IF to_regprocedure('public.chat_send_message_to(text, uuid, uuid)') IS NULL THEN
    RAISE EXCEPTION 'Aborting 0067: migration 0066 is not applied';
  END IF;
END $$;

-- ============================================================================
-- 1. Context columns and per-context uniqueness
-- ============================================================================
ALTER TABLE public.chat_conversations
  ADD COLUMN IF NOT EXISTS requirement_id UUID REFERENCES public.requirements(id),
  ADD COLUMN IF NOT EXISTS availability_id UUID REFERENCES public.availabilities(id);

ALTER TABLE public.chat_conversations DROP CONSTRAINT IF EXISTS chat_conversations_single_context;
ALTER TABLE public.chat_conversations ADD CONSTRAINT chat_conversations_single_context
  CHECK (requirement_id IS NULL OR availability_id IS NULL);

-- The 0043 pair key becomes "one general conversation per pair".
ALTER TABLE public.chat_conversations DROP CONSTRAINT IF EXISTS chat_conversations_pair_key;
CREATE UNIQUE INDEX IF NOT EXISTS chat_conversations_general_key
  ON public.chat_conversations (buyer_id, broker_id)
  WHERE requirement_id IS NULL AND availability_id IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS chat_conversations_requirement_key
  ON public.chat_conversations (buyer_id, broker_id, requirement_id)
  WHERE requirement_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS chat_conversations_availability_key
  ON public.chat_conversations (buyer_id, broker_id, availability_id)
  WHERE availability_id IS NOT NULL;

-- ============================================================================
-- 2. Relationship check: ignore removed CRM contacts
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
    WHERE cc.broker_id = p_broker AND cc.removed_at IS NULL
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
-- 3. Context resolution (internal): who are the two parties of a context?
--    Returns the conversation's (client, broker) for caller + counterpart, or
--    no row when the pair is not the context's own parties.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.chat_context_parties(
  p_caller UUID, p_counterpart UUID, p_requirement_id UUID, p_availability_id UUID
)
RETURNS TABLE (client_id UUID, broker_id UUID)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH me AS (SELECT id, lower(role) AS role FROM public.users WHERE id = p_caller AND status = true),
       cp AS (SELECT id, lower(role) AS role FROM public.users WHERE id = p_counterpart AND status = true),
       pair AS (
         SELECT CASE WHEN me.role = 'broker' THEN cp.id ELSE me.id END AS client_id,
                CASE WHEN me.role = 'broker' THEN me.id ELSE cp.id END AS broker_id
         FROM me, cp
         WHERE (me.role = 'broker') <> (cp.role = 'broker')
           AND (me.role IN ('buyer', 'seller', 'broker')) AND (cp.role IN ('buyer', 'seller', 'broker'))
       )
  SELECT pair.client_id, pair.broker_id FROM pair
  JOIN public.users cl ON cl.id = pair.client_id
  WHERE (
    p_requirement_id IS NOT NULL AND p_availability_id IS NULL AND EXISTS (
      SELECT 1 FROM public.requirements r
      WHERE r.id = p_requirement_id AND r.broker_id = pair.broker_id
        AND lower(cl.role) = 'buyer' AND cl.company_id IS NOT NULL AND r.company_id = cl.company_id)
  ) OR (
    p_availability_id IS NOT NULL AND p_requirement_id IS NULL AND EXISTS (
      SELECT 1 FROM public.availabilities a
      WHERE a.id = p_availability_id AND a.broker_id = pair.broker_id
        AND lower(cl.role) = 'seller'
        AND (a.seller_user_id = cl.id OR (cl.company_id IS NOT NULL AND a.company_id = cl.company_id)))
  );
$$;
REVOKE ALL ON FUNCTION public.chat_context_parties(UUID, UUID, UUID, UUID) FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- 4. chat_send_message: 0066 behaviour, with the general-pair upsert on the new
--    partial index and the context-assignment check on replies.
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
    ON CONFLICT (buyer_id, broker_id) WHERE requirement_id IS NULL AND availability_id IS NULL
    DO NOTHING;

    SELECT * INTO v_conv FROM public.chat_conversations
    WHERE buyer_id = v_uid AND broker_id = p_broker_id
      AND requirement_id IS NULL AND availability_id IS NULL
    FOR UPDATE;
  ELSE
    SELECT * INTO v_conv FROM public.chat_conversations
    WHERE id = p_conversation_id
    FOR UPDATE;
    IF v_conv.id IS NULL OR v_uid NOT IN (v_conv.buyer_id, v_conv.broker_id) THEN
      RAISE EXCEPTION 'Conversation not found' USING ERRCODE = '42501';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = v_conv.buyer_id AND lower(u.role) IN ('buyer', 'seller') AND u.status = true
    ) OR NOT EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = v_conv.broker_id AND lower(u.role) = 'broker' AND u.status = true
    ) THEN
      RAISE EXCEPTION 'Conversation is no longer active' USING ERRCODE = '42501';
    END IF;
    -- Context chats: the context must still be assigned to this broker.
    IF (v_conv.requirement_id IS NOT NULL OR v_conv.availability_id IS NOT NULL) AND NOT EXISTS (
      SELECT 1 FROM public.chat_context_parties(v_conv.buyer_id, v_conv.broker_id,
        v_conv.requirement_id, v_conv.availability_id)
    ) THEN
      RAISE EXCEPTION 'Conversation is no longer active' USING ERRCODE = '42501';
    END IF;
  END IF;

  INSERT INTO public.chat_messages (conversation_id, sender_id, body, client_message_id)
  VALUES (v_conv.id, v_uid, v_body, p_client_message_id)
  ON CONFLICT ON CONSTRAINT chat_messages_idempotency_key DO NOTHING
  RETURNING * INTO v_msg;

  IF v_msg.id IS NULL THEN
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
-- 5. chat_send_message_to: 0066 behaviour (general thread), new upsert target.
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

  IF NOT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = p_counterpart_id AND lower(u.role) IN ('buyer', 'seller') AND u.status = true
  ) OR NOT public.chat_broker_may_contact(v_uid, p_counterpart_id) THEN
    RAISE EXCEPTION 'Contact not available for chat' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.chat_conversations (buyer_id, broker_id)
  VALUES (p_counterpart_id, v_uid)
  ON CONFLICT (buyer_id, broker_id) WHERE requirement_id IS NULL AND availability_id IS NULL
  DO NOTHING;

  SELECT id INTO v_conv_id FROM public.chat_conversations
  WHERE buyer_id = p_counterpart_id AND broker_id = v_uid
    AND requirement_id IS NULL AND availability_id IS NULL;

  RETURN public.chat_send_message(p_body, p_client_message_id, NULL, v_conv_id);
END;
$$;
REVOKE ALL ON FUNCTION public.chat_send_message_to(TEXT, UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chat_send_message_to(TEXT, UUID, UUID) TO authenticated;

-- ============================================================================
-- 6. chat_send_in_context: first (or any) message in a requirement/offer chat,
--    from either party. Conversation + message in one transaction.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.chat_send_in_context(
  p_body TEXT,
  p_client_message_id UUID,
  p_counterpart_id UUID,
  p_requirement_id UUID DEFAULT NULL,
  p_availability_id UUID DEFAULT NULL
)
RETURNS public.chat_messages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_client UUID;
  v_broker UUID;
  v_conv_id UUID;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;
  IF p_counterpart_id IS NULL OR ((p_requirement_id IS NULL) = (p_availability_id IS NULL)) THEN
    RAISE EXCEPTION 'Invalid chat request' USING ERRCODE = '22023';
  END IF;

  SELECT client_id, broker_id INTO v_client, v_broker
  FROM public.chat_context_parties(v_uid, p_counterpart_id, p_requirement_id, p_availability_id);
  IF v_client IS NULL THEN
    -- One error for unknown, unrelated, wrong-role or unassigned (no probing).
    RAISE EXCEPTION 'Contact not available for chat' USING ERRCODE = '42501';
  END IF;

  IF p_requirement_id IS NOT NULL THEN
    INSERT INTO public.chat_conversations (buyer_id, broker_id, requirement_id)
    VALUES (v_client, v_broker, p_requirement_id)
    ON CONFLICT (buyer_id, broker_id, requirement_id) WHERE requirement_id IS NOT NULL DO NOTHING;
    SELECT id INTO v_conv_id FROM public.chat_conversations
    WHERE buyer_id = v_client AND broker_id = v_broker AND requirement_id = p_requirement_id;
  ELSE
    INSERT INTO public.chat_conversations (buyer_id, broker_id, availability_id)
    VALUES (v_client, v_broker, p_availability_id)
    ON CONFLICT (buyer_id, broker_id, availability_id) WHERE availability_id IS NOT NULL DO NOTHING;
    SELECT id INTO v_conv_id FROM public.chat_conversations
    WHERE buyer_id = v_client AND broker_id = v_broker AND availability_id = p_availability_id;
  END IF;

  RETURN public.chat_send_message(p_body, p_client_message_id, NULL, v_conv_id);
END;
$$;
REVOKE ALL ON FUNCTION public.chat_send_in_context(TEXT, UUID, UUID, UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chat_send_in_context(TEXT, UUID, UUID, UUID, UUID) TO authenticated;

-- ============================================================================
-- 7. chat_find_conversation: the caller's conversation with a person, in a
--    context or the general thread. NULL when none (or not the caller's).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.chat_find_conversation(
  p_counterpart_id UUID,
  p_requirement_id UUID DEFAULT NULL,
  p_availability_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT c.id FROM public.chat_conversations c
  WHERE ((c.buyer_id = auth.uid() AND c.broker_id = p_counterpart_id)
      OR (c.broker_id = auth.uid() AND c.buyer_id = p_counterpart_id))
    AND c.requirement_id IS NOT DISTINCT FROM p_requirement_id
    AND c.availability_id IS NOT DISTINCT FROM p_availability_id
  LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.chat_find_conversation(UUID, UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chat_find_conversation(UUID, UUID, UUID) TO authenticated;

-- ============================================================================
-- 8. Inbox: 0066 columns + context. The label never names the other client
--    party: a buyer only ever has requirement/general chats, a seller only
--    offer/general chats.
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
  counterpart_role TEXT,
  requirement_id UUID,
  availability_id UUID,
  context_label TEXT
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
    lower(cp.role),
    c.requirement_id,
    c.availability_id,
    CASE
      WHEN c.requirement_id IS NOT NULL THEN 'Requirement · ' || coalesce(rc.name, 'commodity')
      WHEN c.availability_id IS NOT NULL THEN 'Offer · ' || coalesce(ac.name, 'commodity')
        || coalesce(' · ' || a.lot_number, '')
    END
  FROM public.chat_conversations c
  JOIN public.users cp
    ON cp.id = CASE WHEN auth.uid() = c.buyer_id THEN c.broker_id ELSE c.buyer_id END
  LEFT JOIN public.companies co ON co.id = cp.company_id
  LEFT JOIN public.requirements r ON r.id = c.requirement_id
  LEFT JOIN public.master_commodities rc ON rc.id = r.commodity_id
  LEFT JOIN public.availabilities a ON a.id = c.availability_id
  LEFT JOIN public.master_commodities ac ON ac.id = a.commodity_id
  WHERE auth.uid() IN (c.buyer_id, c.broker_id)
    AND (p_conversation_id IS NULL OR c.id = p_conversation_id)
  ORDER BY c.last_message_at DESC NULLS LAST, c.created_at DESC;
$$;
REVOKE ALL ON FUNCTION public.chat_inbox(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chat_inbox(UUID) TO authenticated;

COMMIT;
