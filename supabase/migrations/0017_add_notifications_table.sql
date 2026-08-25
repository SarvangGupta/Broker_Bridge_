-- Migration: 0017_add_notifications_table.sql
-- Creates notifications table for centralized multi-channel notification pipeline

CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE,
    channel TEXT NOT NULL,
    event_type TEXT NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    payload JSONB,
    delivery_status TEXT NOT NULL DEFAULT 'Pending',
    read_at TIMESTAMP WITH TIME ZONE,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    max_attempts INTEGER NOT NULL DEFAULT 3,
    last_attempt_at TIMESTAMP WITH TIME ZONE,
    next_retry_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    provider_message_id TEXT,
    sent_at TIMESTAMP WITH TIME ZONE,
    failed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS notifications_user_created_idx ON public.notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS notifications_tenant_idx ON public.notifications(company_id, created_at DESC);
CREATE INDEX IF NOT EXISTS notifications_queue_idx ON public.notifications(delivery_status, channel, next_retry_at, created_at);
