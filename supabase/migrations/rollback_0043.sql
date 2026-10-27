-- Rollback for 0043_buyer_broker_chat.sql. Destroys all chat data.
BEGIN;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'chat_messages') THEN
    ALTER PUBLICATION supabase_realtime DROP TABLE public.chat_messages;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'chat_conversations') THEN
    ALTER PUBLICATION supabase_realtime DROP TABLE public.chat_conversations;
  END IF;
END $$;
DROP FUNCTION IF EXISTS public.chat_inbox(UUID);
DROP FUNCTION IF EXISTS public.chat_mark_read(UUID);
DROP FUNCTION IF EXISTS public.chat_send_message(TEXT, UUID, UUID, UUID);
DELETE FROM public.notifications WHERE event_type = 'CHAT_MESSAGE';
DROP TABLE IF EXISTS public.chat_messages;
DROP TABLE IF EXISTS public.chat_conversations;
COMMIT;
