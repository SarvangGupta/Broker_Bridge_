-- PROPOSED — NOT APPLIED. Requires explicit production approval
-- (RB-SELLER-COMMODITY-BROKER-NOTIFY-01). Rollback: rollback_0065.sql.
--
-- Notifies the broker assigned to a seller commodity listing (availabilities row)
-- whenever the SELLER creates, changes, reassigns or removes that listing.
--
-- Why a trigger: RMSeller writes availabilities directly through PostgREST, so
-- an AFTER ROW trigger is the only place that sees every committed seller
-- mutation. The notification rows are written in the SAME transaction as the
-- listing change, so:
--   * a failed / rejected / rolled-back mutation creates no notification;
--   * a successful one cannot lose its notification if the app closes;
--   * a retry that changes nothing (no column diff) creates nothing, and a
--     unique idempotency_key (per listing, broker, event, transaction) blocks
--     duplicates from repeated trigger firings.
--
-- Security:
--   * Recipient is read from the row's own broker_id (trusted server data, the
--     seller client never names recipients) and must be an active role=broker
--     user. availabilities has a single broker_id, so at most one broker per
--     listing (plus the previous broker never being notified on reassignment).
--   * Only mutations made BY THE LISTING'S SELLER (its company seller or the
--     individual seller_user_id) notify. Broker, admin and service-role writes
--     (e.g. deal reservations) do not; the acting user is never notified.
--   * The payload carries no buyer data and never confidential_minimum_price.
--   * Notification company_id is the broker's own company (same as 0040).
--   * No RLS, grant or table change. Push is NOT sent: there is no push provider
--     in this codebase; these are IN_APP rows read by the broker Alerts screen.

BEGIN;

CREATE OR REPLACE FUNCTION public.notify_listing_brokers()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor        uuid := auth.uid();
  v_new          jsonb := CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END;
  v_old          jsonb := CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END;
  v_rec          jsonb := COALESCE(v_new, v_old);
  v_id           text  := v_rec->>'id';
  v_new_broker   uuid  := NULLIF(v_new->>'broker_id', '')::uuid;
  v_old_broker   uuid  := NULLIF(v_old->>'broker_id', '')::uuid;
  v_key          text;
  v_changed      text[] := '{}';
  v_cats         text[] := '{}';
  v_cat          text;
  v_labels       text[] := '{}';
  v_commodity    text;
  v_unit         text;
  v_seller       text;
  v_lot          text;
  v_price        numeric;
  v_qty          numeric;
  v_status       text  := v_rec->>'status';
  v_removed      boolean := false;
  v_subject      text;
  v_event        text;
  v_title        text;
  v_message      text;
  -- Columns that are never broker-visible changes: bookkeeping, deal-driven
  -- quantities (not seller actions), the confidential floor price, and the
  -- broker assignment itself (handled separately).
  c_ignored CONSTANT text[] := ARRAY[
    'id', 'created_at', 'updated_at', 'version', 'loading_updated_at',
    'reserved_quantity', 'sold_quantity', 'confidential_minimum_price',
    'broker_id', 'company_id', 'seller_user_id'];
BEGIN
  -- 1. Seller-side mutations only. COALESCE: a NULL guard must fail closed.
  IF v_actor IS NULL OR NOT COALESCE(
       (v_rec->>'company_id' IS NULL AND v_rec->>'seller_user_id' = v_actor::text)
       OR EXISTS (
         SELECT 1 FROM public.users u
         WHERE u.id = v_actor
           AND lower(u.role) = 'seller'
           AND u.status = true
           AND u.company_id IS NOT NULL
           AND u.company_id::text = v_rec->>'company_id'),
       false) THEN
    RETURN NULL;
  END IF;

  -- 2. What changed (UPDATE only), bucketed into broker-meaningful categories.
  IF TG_OP = 'UPDATE' THEN
    FOR v_key IN SELECT jsonb_object_keys(v_new) LOOP
      CONTINUE WHEN v_key = ANY (c_ignored);
      CONTINUE WHEN (v_new->v_key) IS NOT DISTINCT FROM (v_old->v_key);
      v_changed := v_changed || v_key;
      v_cat := CASE
        WHEN v_key IN ('price', 'asking_price') THEN 'price'
        WHEN v_key IN ('quantity', 'total_quantity', 'available_quantity',
                       'minimum_order_quantity') THEN 'quantity'
        WHEN v_key IN ('state_id', 'district_id', 'loading_location_id',
                       'loading_location_snapshot')
          OR v_key ~ '(warehouse|mandi|address|latitude|longitude|dispatch)' THEN 'location'
        WHEN v_key ~ '^payment' THEN 'payment'
        WHEN v_key IN ('commodity_id', 'grade_id')
          OR v_key ~ '(quality|spec|lab_)' THEN 'quality'
        WHEN v_key = 'status' THEN 'status'
        ELSE 'other'
      END;
      IF NOT v_cat = ANY (v_cats) THEN v_cats := v_cats || v_cat; END IF;
    END LOOP;
  END IF;

  -- 3. Listing summary from trusted master data.
  SELECT mc.name INTO v_commodity FROM public.master_commodities mc
   WHERE mc.id::text = v_rec->>'commodity_id';
  SELECT mu.symbol INTO v_unit FROM public.master_units mu
   WHERE mu.id::text = v_rec->>'unit_id';
  IF v_rec->>'company_id' IS NOT NULL THEN
    SELECT c.name INTO v_seller FROM public.companies c WHERE c.id::text = v_rec->>'company_id';
  ELSE
    SELECT u.name INTO v_seller FROM public.users u WHERE u.id::text = v_rec->>'seller_user_id';
  END IF;
  v_commodity := COALESCE(NULLIF(trim(v_commodity), ''), 'Commodity');
  v_unit      := COALESCE(NULLIF(trim(v_unit), ''), 'MT');
  v_seller    := COALESCE(NULLIF(trim(v_seller), ''), 'Seller');
  v_lot       := COALESCE(NULLIF(trim(v_rec->>'lot_number'), ''),
                          'LOT-' || upper(left(v_id, 6)));
  v_price     := COALESCE(NULLIF(v_rec->>'asking_price', '')::numeric,
                          NULLIF(v_rec->>'price', '')::numeric);
  v_qty       := COALESCE(NULLIF(v_rec->>'available_quantity', '')::numeric,
                          NULLIF(v_rec->>'quantity', '')::numeric);
  v_subject   := v_commodity || ' — ' || v_lot;
  v_removed   := TG_OP = 'DELETE'
                 OR ('status' = ANY (v_changed)
                     AND lower(v_status) IN ('cancelled', 'canceled', 'withdrawn',
                                             'removed', 'deleted', 'archived'));

  -- 4. Removal / status / field changes go to the CURRENT broker, only when the
  --    broker did not change in the same write (a reassignment sends step 5).
  IF TG_OP = 'DELETE' THEN
    PERFORM public._insert_listing_broker_notification(
      v_old_broker, v_actor, v_rec, 'AVAILABILITY_REMOVED', 'Commodity listing removed',
      v_seller || ' has removed ' || v_subject || '. This listing is no longer available.',
      v_changed, v_seller, v_commodity, v_unit, v_lot, v_price, v_qty, true);
    RETURN NULL;
  END IF;

  IF TG_OP = 'INSERT' THEN
    PERFORM public._insert_listing_broker_notification(
      v_new_broker, v_actor, v_rec, 'AVAILABILITY_CREATED', 'New commodity listing',
      v_seller || ' listed ' || v_subject || ': '
        || public._fmt_listing_number(v_qty) || ' ' || v_unit
        || COALESCE(' at ₹' || public._fmt_listing_number(v_price) || '/' || v_unit, '')
        || '. Open the listing to view the details.',
      v_changed, v_seller, v_commodity, v_unit, v_lot, v_price, v_qty, false);
    RETURN NULL;
  END IF;

  -- UPDATE
  IF v_new_broker IS DISTINCT FROM v_old_broker THEN
    -- 5. Newly assigned broker learns the listing is available to them. The
    --    previous broker is not notified (no product rule requires it).
    PERFORM public._insert_listing_broker_notification(
      v_new_broker, v_actor, v_rec, 'AVAILABILITY_ASSIGNED', 'Commodity listing assigned to you',
      v_seller || ' assigned ' || v_subject || ' to you: '
        || public._fmt_listing_number(v_qty) || ' ' || v_unit
        || COALESCE(' at ₹' || public._fmt_listing_number(v_price) || '/' || v_unit, '')
        || '. Open the listing to view the details.',
      v_changed, v_seller, v_commodity, v_unit, v_lot, v_price, v_qty, v_removed);
    RETURN NULL;
  END IF;

  IF array_length(v_changed, 1) IS NULL THEN
    RETURN NULL; -- nothing broker-visible changed (e.g. an identical retry)
  END IF;

  IF v_removed THEN
    v_event := 'AVAILABILITY_REMOVED';
    v_title := 'Commodity listing removed';
    v_message := v_seller || ' has removed ' || v_subject
      || '. This listing is no longer available.';
  ELSIF array_length(v_cats, 1) = 1 THEN
    v_event := CASE v_cats[1]
      WHEN 'price'    THEN 'AVAILABILITY_PRICE_UPDATED'
      WHEN 'quantity' THEN 'AVAILABILITY_QUANTITY_UPDATED'
      WHEN 'location' THEN 'AVAILABILITY_LOCATION_UPDATED'
      WHEN 'payment'  THEN 'AVAILABILITY_PAYMENT_TERMS_UPDATED'
      WHEN 'quality'  THEN 'AVAILABILITY_QUALITY_UPDATED'
      WHEN 'status'   THEN 'AVAILABILITY_STATUS_CHANGED'
      ELSE 'AVAILABILITY_UPDATED' END;
    v_title := CASE v_cats[1]
      WHEN 'price'    THEN 'Commodity price updated'
      WHEN 'quantity' THEN 'Commodity quantity updated'
      WHEN 'location' THEN 'Dispatch location updated'
      WHEN 'payment'  THEN 'Payment terms updated'
      WHEN 'quality'  THEN 'Commodity quality updated'
      WHEN 'status'   THEN 'Commodity listing status changed'
      ELSE 'Commodity listing updated' END;
    v_message := CASE v_cats[1]
      WHEN 'price' THEN v_seller || ' updated the price for ' || v_subject
        || COALESCE(' to ₹' || public._fmt_listing_number(v_price) || '/' || v_unit, '')
        || '. Open the listing to view the latest details.'
      WHEN 'quantity' THEN v_seller || ' updated the quantity for ' || v_subject
        || ' to ' || public._fmt_listing_number(v_qty) || ' ' || v_unit
        || '. Open the listing to view the latest details.'
      WHEN 'status' THEN v_seller || ' changed the status of ' || v_subject
        || ' to ' || COALESCE(v_status, 'unknown')
        || '. Open the listing to view the latest details.'
      ELSE v_seller || ' updated the '
        || CASE v_cats[1]
             WHEN 'location' THEN 'dispatch location'
             WHEN 'payment'  THEN 'payment terms'
             WHEN 'quality'  THEN 'quality/specification'
             ELSE 'details' END
        || ' for ' || v_subject || '. Open the listing to view the latest details.'
    END;
  ELSE
    FOREACH v_cat IN ARRAY v_cats LOOP
      v_labels := v_labels || CASE v_cat
        WHEN 'location' THEN 'dispatch location'
        WHEN 'payment'  THEN 'payment terms'
        WHEN 'quality'  THEN 'quality/specification'
        WHEN 'other'    THEN 'other details'
        ELSE v_cat END;
    END LOOP;
    v_event := 'AVAILABILITY_UPDATED';
    v_title := 'Commodity listing updated';
    v_message := v_seller || ' updated ' || array_to_string(v_labels, ', ')
      || ' for ' || v_subject || '. Open the listing to view the latest details.';
  END IF;

  PERFORM public._insert_listing_broker_notification(
    v_new_broker, v_actor, v_rec, v_event, v_title, v_message,
    v_changed, v_seller, v_commodity, v_unit, v_lot, v_price, v_qty, v_removed);
  RETURN NULL;
END;
$$;

-- Plain number text without trailing zeros: 5850.00 -> 5850, 12.50 -> 12.5.
CREATE OR REPLACE FUNCTION public._fmt_listing_number(p numeric)
RETURNS text
LANGUAGE sql IMMUTABLE
AS $$
  SELECT CASE WHEN p IS NULL THEN NULL
    ELSE rtrim(rtrim(round(p, 2)::text, '0'), '.') END;
$$;

-- Writes one IN_APP notification to [p_broker] if it is an active broker other
-- than the acting user. Idempotent per listing/broker/event/transaction.
CREATE OR REPLACE FUNCTION public._insert_listing_broker_notification(
  p_broker uuid, p_actor uuid, p_rec jsonb, p_event text, p_title text,
  p_message text, p_changed text[], p_seller text, p_commodity text,
  p_unit text, p_lot text, p_price numeric, p_qty numeric, p_removed boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_company uuid;
  v_id text := p_rec->>'id';
BEGIN
  IF p_broker IS NULL OR p_broker = p_actor THEN
    RETURN;
  END IF;
  SELECT u.company_id INTO v_company
  FROM public.users u
  WHERE u.id = p_broker AND lower(u.role) = 'broker' AND u.status = true;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  INSERT INTO public.notifications (
    user_id, company_id, channel, event_type, title, message, context_reason,
    action_label, action_url, payload, delivery_status, idempotency_key,
    is_read, created_at)
  VALUES (
    p_broker, v_company, 'IN_APP', p_event, p_title, p_message,
    'Seller update on a listing assigned to you',
    CASE WHEN p_removed THEN 'View Offers' ELSE 'Open Listing' END,
    '/work?tab=1&offerId=' || v_id,
    jsonb_build_object(
      'availabilityId', v_id,
      'lotNumber', p_lot,
      'commodity', p_commodity,
      'sellerName', p_seller,
      'quantity', p_qty,
      'unit', p_unit,
      'price', p_price,
      'status', p_rec->>'status',
      'changeType', p_event,
      'changedFields', to_jsonb(COALESCE(p_changed, '{}'::text[])),
      'listingRemoved', p_removed,
      'occurredAt', now()),
    'Sent',
    'avl:' || v_id || ':' || p_broker::text || ':' || p_event || ':' || txid_current()::text,
    false, now())
  ON CONFLICT (idempotency_key) DO NOTHING;
END;
$$;

-- Internal helpers: never callable through the API.
REVOKE ALL ON FUNCTION public.notify_listing_brokers() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._insert_listing_broker_notification(
  uuid, uuid, jsonb, text, text, text, text[], text, text, text, text, numeric, numeric, boolean)
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS availabilities_notify_brokers ON public.availabilities;
CREATE TRIGGER availabilities_notify_brokers
  AFTER INSERT OR UPDATE OR DELETE ON public.availabilities
  FOR EACH ROW EXECUTE FUNCTION public.notify_listing_brokers();

COMMIT;
