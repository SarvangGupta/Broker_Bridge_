-- Rollback for 0065_seller_listing_broker_notifications.sql.
-- Removes the trigger and its helper functions. Notification rows already
-- delivered are kept (they are ordinary broker inbox history); to remove them
-- too, uncomment the DELETE below.

BEGIN;

DROP TRIGGER IF EXISTS availabilities_notify_brokers ON public.availabilities;
DROP FUNCTION IF EXISTS public.notify_listing_brokers();
DROP FUNCTION IF EXISTS public._insert_listing_broker_notification(
  uuid, uuid, jsonb, text, text, text, text[], text, text, text, text, numeric, numeric, boolean);
DROP FUNCTION IF EXISTS public._fmt_listing_number(numeric);

-- DELETE FROM public.notifications WHERE idempotency_key LIKE 'avl:%';

COMMIT;
