-- ============================================================================
-- Migration: 0056_warehouse_gps_coordinates.sql   (PROPOSED — not applied)
-- Sprint: RMBUYER-GST-VERIFICATION-WAREHOUSE-E2E-01 & ADDENDUM GPS-MAPS
--
-- Non-destructive upgrade for existing company_warehouses:
--   * Adds latitude, longitude, gps_accuracy, location_captured_at
--   * Adds coordinate range check constraints
--   * Upgrades trg_notify_warehouse_change to generate Google Maps links
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'company_warehouses'
  ) THEN
    RAISE EXCEPTION 'Table public.company_warehouses does not exist. You must run 0055_company_warehouses.sql first to create the table before applying 0056.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'company_warehouses' AND column_name = 'latitude'
  ) THEN
    ALTER TABLE public.company_warehouses
      ADD COLUMN latitude double precision CHECK (latitude IS NULL OR (latitude >= -90.0 AND latitude <= 90.0)),
      ADD COLUMN longitude double precision CHECK (longitude IS NULL OR (longitude >= -180.0 AND longitude <= 180.0)),
      ADD COLUMN gps_accuracy double precision CHECK (gps_accuracy IS NULL OR gps_accuracy >= 0),
      ADD COLUMN location_captured_at timestamptz;

    ALTER TABLE public.company_warehouses
      ADD CONSTRAINT chk_warehouse_coordinates_pair CHECK (
        (latitude IS NULL AND longitude IS NULL) OR
        (latitude IS NOT NULL AND longitude IS NOT NULL)
      );
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Upgraded Broker Notification Trigger with Google Maps Integration
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

