-- Rollback Migration: rollback_0040.sql
REVOKE EXECUTE ON FUNCTION public.notify_requirement_brokers(UUID, UUID[]) FROM authenticated;
DROP FUNCTION IF EXISTS public.notify_requirement_brokers(UUID, UUID[]);
