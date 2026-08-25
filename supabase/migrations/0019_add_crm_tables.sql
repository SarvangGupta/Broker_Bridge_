-- Migration: 0019_add_crm_tables.sql
CREATE TABLE IF NOT EXISTS public.crm_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    broker_id UUID NOT NULL REFERENCES public.users(id),
    user_id UUID REFERENCES public.users(id),
    company_id UUID REFERENCES public.companies(id),
    last_activity_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.crm_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_id UUID NOT NULL REFERENCES public.crm_contacts(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    notes TEXT NOT NULL,
    follow_up_date TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.crm_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    broker_id UUID NOT NULL REFERENCES public.users(id),
    contact_id UUID REFERENCES public.crm_contacts(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    due_date TIMESTAMP NOT NULL,
    priority TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'Pending',
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
