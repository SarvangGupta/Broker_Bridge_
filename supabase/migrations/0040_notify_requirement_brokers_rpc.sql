-- Migration: 0040_notify_requirement_brokers_rpc.sql
-- Description: Authorizes authenticated buyers to securely dispatch requirement notifications
-- to selected licensed brokers using a SECURITY DEFINER RPC.
-- Counterparty Shield & Security:
-- 1. Caller must belong to the company that owns the requirement.
-- 2. Recipient users must be active users with role = 'broker'.
-- 3. Notification contents and payload are derived directly from verified database records.
-- 4. Idempotency key prevents duplicate notifications on rapid taps or retries.

CREATE OR REPLACE FUNCTION public.notify_requirement_brokers(
    p_requirement_id UUID,
    p_broker_ids UUID[]
)
RETURNS TABLE (
    notified_count INTEGER,
    notified_broker_ids UUID[]
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_calling_user_id UUID;
    v_req RECORD;
    v_broker RECORD;
    v_count INTEGER := 0;
    v_notified UUID[] := '{}';
    v_idempotency_key TEXT;
    v_commodity_name TEXT;
    v_unit_symbol TEXT;
BEGIN
    v_calling_user_id := auth.uid();
    IF v_calling_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to notify requirement brokers';
    END IF;

    -- 1. Validate requirement exists and belongs to calling user's enterprise
    SELECT r.id, r.company_id, r.commodity_id, r.quantity, r.target_price, r.status, r.delivery_terms_id,
           mc.name AS commodity_name, mu.symbol AS unit_symbol
    INTO v_req
    FROM public.requirements r
    LEFT JOIN public.master_commodities mc ON mc.id = r.commodity_id
    LEFT JOIN public.master_units mu ON mu.id = r.unit_id
    WHERE r.id = p_requirement_id;

    IF v_req.id IS NULL THEN
        RAISE EXCEPTION 'Requirement not found: %', p_requirement_id;
    END IF;

    -- Verify the calling user is in the requirement's company OR is admin
    IF NOT (
        EXISTS (
            SELECT 1 FROM public.users u 
            WHERE u.id = v_calling_user_id 
              AND (u.company_id = v_req.company_id OR u.role = 'admin')
        )
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Caller does not own requirement %', p_requirement_id;
    END IF;

    -- 2. Process each requested broker safely
    IF p_broker_ids IS NOT NULL AND array_length(p_broker_ids, 1) > 0 THEN
        FOR v_broker IN 
            SELECT id, name, company_id
            FROM public.users
            WHERE id = ANY(p_broker_ids)
              AND role = 'broker'
              AND status = true
        LOOP
            v_idempotency_key := 'req-' || p_requirement_id::text || '-broker-' || v_broker.id::text;
            v_commodity_name := COALESCE(v_req.commodity_name, 'Commodity');
            v_unit_symbol := COALESCE(v_req.unit_symbol, 'MT');

            INSERT INTO public.notifications (
                user_id,
                company_id,
                channel,
                event_type,
                title,
                message,
                context_reason,
                action_label,
                action_url,
                payload,
                delivery_status,
                idempotency_key,
                is_read,
                created_at
            ) VALUES (
                v_broker.id,
                v_broker.company_id,
                'IN_APP',
                'REQUIREMENT_CREATED',
                'New Procurement Requirement: ' || v_commodity_name,
                'Buyer posted requirement for ' || v_req.quantity::text || ' ' || v_unit_symbol || ' of ' || v_commodity_name || '.',
                'Direct mandate notification from verified buyer',
                'Inspect Requirement',
                '/work?tab=0',
                jsonb_build_object(
                    'requirementId', p_requirement_id,
                    'commodity', v_commodity_name,
                    'quantity', v_req.quantity,
                    'unit', v_unit_symbol,
                    'targetPrice', v_req.target_price,
                    'deliveryLocation', v_req.delivery_terms_id,
                    'createdAt', now()
                ),
                'Sent',
                v_idempotency_key,
                false,
                now()
            )
            ON CONFLICT (idempotency_key) DO NOTHING;

            IF FOUND THEN
                v_count := v_count + 1;
                v_notified := array_append(v_notified, v_broker.id);
            END IF;
        END LOOP;
    END IF;

    RETURN QUERY SELECT v_count, v_notified;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.notify_requirement_brokers(UUID, UUID[]) TO authenticated;
