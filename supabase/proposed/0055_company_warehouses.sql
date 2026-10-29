-- ============================================================================
-- Migration: 0055_company_warehouses.sql   (PROPOSED — not applied)
-- Sprint: RMBUYER-GST-VERIFICATION-WAREHOUSE-E2E-01 & ADDENDUM GPS-MAPS
--
-- Company Warehouses and Unloading Locations with High-Precision GPS:
--   * public.company_warehouses       multiple unloading locations per company with GPS
--   * Row Level Security (RLS)        strict company tenant isolation
--   * trg_notify_warehouse_change     event-driven notifications with Google Maps URL
--                                     to legitimately associated brokers only
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.company_warehouses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES public.users(id),
  name text NOT NULL CHECK (length(btrim(name)) > 0),
  address_line text NOT NULL CHECK (length(btrim(address_line)) > 0),
  state_id text,
  district_id text,
  pin_code text CHECK (pin_code ~ '^[1-9][0-9]{5}$' OR pin_code IS NULL),
  contact_person text,
  contact_phone text,
  unloading_notes text,
  is_active boolean NOT NULL DEFAULT true,
  latitude double precision CHECK (latitude IS NULL OR (latitude >= -90.0 AND latitude <= 90.0)),
  longitude double precision CHECK (longitude IS NULL OR (longitude >= -180.0 AND longitude <= 180.0)),
  gps_accuracy double precision CHECK (gps_accuracy IS NULL OR gps_accuracy >= 0),
  location_captured_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_warehouse_coordinates_pair CHECK (
    (latitude IS NULL AND longitude IS NULL) OR
    (latitude IS NOT NULL AND longitude IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_company_warehouses_company
  ON public.company_warehouses (company_id, is_active);

-- ---------------------------------------------------------------------------
-- 1. Security & Row Level Security
-- ---------------------------------------------------------------------------
ALTER TABLE public.company_warehouses ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.company_warehouses FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.company_warehouses TO authenticated;

DROP POLICY IF EXISTS "company_warehouses_select" ON public.company_warehouses;
CREATE POLICY "company_warehouses_select" ON public.company_warehouses
FOR SELECT TO authenticated
USING (
  company_id = (SELECT u.company_id FROM public.users u WHERE u.id = auth.uid())
  OR public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.crm_contacts cc
    WHERE cc.broker_id = auth.uid() AND cc.company_id = company_warehouses.company_id
  )
  OR EXISTS (
    SELECT 1 FROM public.deals d
    JOIN public.users bu ON bu.id = d.buyer_id
    WHERE d.broker_id = auth.uid() AND bu.company_id = company_warehouses.company_id
  )
);

DROP POLICY IF EXISTS "company_warehouses_insert" ON public.company_warehouses;
CREATE POLICY "company_warehouses_insert" ON public.company_warehouses
FOR INSERT TO authenticated
WITH CHECK (
  company_id = (SELECT u.company_id FROM public.users u WHERE u.id = auth.uid())
  AND created_by = auth.uid()
);

DROP POLICY IF EXISTS "company_warehouses_update" ON public.company_warehouses;
CREATE POLICY "company_warehouses_update" ON public.company_warehouses
FOR UPDATE TO authenticated
USING (
  company_id = (SELECT u.company_id FROM public.users u WHERE u.id = auth.uid())
  OR public.is_admin()
)
WITH CHECK (
  company_id = (SELECT u.company_id FROM public.users u WHERE u.id = auth.uid())
  OR public.is_admin()
);

DROP POLICY IF EXISTS "company_warehouses_delete" ON public.company_warehouses;
CREATE POLICY "company_warehouses_delete" ON public.company_warehouses
FOR DELETE TO authenticated
USING (
  company_id = (SELECT u.company_id FROM public.users u WHERE u.id = auth.uid())
  OR public.is_admin()
);

-- ---------------------------------------------------------------------------
-- 2. Broker Notification on Warehouse Change with Google Maps Integration
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_notify_warehouse_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_company_name text;
  v_change_type text;
  v_title text;
  v_msg text;
  v_maps_url text;
  v_broker record;
  v_idem text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_change_type := 'CREATED';
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.is_active AND NOT NEW.is_active THEN
      v_change_type := 'DEACTIVATED';
    ELSIF NOT OLD.is_active AND NEW.is_active THEN
      v_change_type := 'ACTIVATED';
    ELSIF (OLD.name, OLD.address_line, OLD.pin_code, OLD.unloading_notes, OLD.contact_person, OLD.contact_phone, OLD.latitude, OLD.longitude)
          IS NOT DISTINCT FROM
          (NEW.name, NEW.address_line, NEW.pin_code, NEW.unloading_notes, NEW.contact_person, NEW.contact_phone, NEW.latitude, NEW.longitude) THEN
      RETURN NEW; -- No-op update
    ELSIF (OLD.name, OLD.address_line, OLD.pin_code) IS NOT DISTINCT FROM (NEW.name, NEW.address_line, NEW.pin_code)
          AND (OLD.latitude, OLD.longitude) IS DISTINCT FROM (NEW.latitude, NEW.longitude) THEN
      v_change_type := 'LOCATION_UPDATED';
    ELSIF (OLD.name, OLD.address_line, OLD.pin_code) IS DISTINCT FROM (NEW.name, NEW.address_line, NEW.pin_code)
          AND (OLD.latitude, OLD.longitude) IS NOT DISTINCT FROM (NEW.latitude, NEW.longitude) THEN
      v_change_type := 'ADDRESS_UPDATED';
    ELSE
      v_change_type := 'UPDATED';
    END IF;
  ELSE
    RETURN OLD;
  END IF;

  SELECT name INTO v_company_name FROM public.companies WHERE id = NEW.company_id;
  v_company_name := COALESCE(v_company_name, 'Buyer');

  -- Generate Google Maps URL only from authoritative coordinates
  IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
    v_maps_url := 'https://www.google.com/maps/search/?api=1&query=' || NEW.latitude::text || '%2C' || NEW.longitude::text;
  ELSE
    v_maps_url := NULL;
  END IF;

  v_title := 'Warehouse Update: ' || v_company_name;
  IF v_change_type = 'CREATED' THEN
    v_msg := v_company_name || ' added a new warehouse/unloading location: ' || NEW.name || ' (' || NEW.address_line || ').';
  ELSIF v_change_type = 'DEACTIVATED' THEN
    v_msg := v_company_name || ' deactivated unloading location: ' || NEW.name || '.';
  ELSIF v_change_type = 'LOCATION_UPDATED' THEN
    v_msg := v_company_name || ' updated GPS unloading coordinates for: ' || NEW.name || ' (' || NEW.address_line || '). Google Maps link attached.';
  ELSIF v_change_type = 'ADDRESS_UPDATED' THEN
    v_msg := v_company_name || ' updated unloading address for: ' || NEW.name || ' (' || NEW.address_line || ').';
  ELSE
    v_msg := v_company_name || ' updated unloading location: ' || NEW.name || ' (' || NEW.address_line || ').';
  END IF;

  FOR v_broker IN
    SELECT DISTINCT u.id, u.company_id
    FROM public.users u
    WHERE u.role = 'broker' AND u.status = true
      AND (
        EXISTS (SELECT 1 FROM public.crm_contacts cc WHERE cc.broker_id = u.id AND cc.company_id = NEW.company_id)
        OR EXISTS (
          SELECT 1 FROM public.deals d
          JOIN public.users bu ON bu.id = d.buyer_id
          WHERE d.broker_id = u.id AND bu.company_id = NEW.company_id
        )
      )
  LOOP
    v_idem := 'wh-' || NEW.id::text || '-' || v_change_type || '-' || extract(epoch from COALESCE(NEW.updated_at, now()))::bigint || '-' || v_broker.id::text;
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
      'WAREHOUSE_UPDATED',
      v_title,
      v_msg,
      'Operational unloading location update from counterparty',
      'View Directory',
      '/directory',
      jsonb_build_object(
        'companyId', NEW.company_id,
        'warehouseId', NEW.id,
        'warehouseName', NEW.name,
        'address', NEW.address_line,
        'pinCode', NEW.pin_code,
        'latitude', NEW.latitude,
        'longitude', NEW.longitude,
        'gpsAccuracy', NEW.gps_accuracy,
        'googleMapsUrl', v_maps_url,
        'changeType', v_change_type,
        'updatedAt', COALESCE(NEW.updated_at, now())
      ),
      'Sent',
      v_idem,
      false,
      now()
    )
    ON CONFLICT (idempotency_key) DO NOTHING;
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_warehouse_change ON public.company_warehouses;
CREATE TRIGGER trg_notify_warehouse_change
AFTER INSERT OR UPDATE ON public.company_warehouses
FOR EACH ROW EXECUTE FUNCTION public.trg_notify_warehouse_change();
