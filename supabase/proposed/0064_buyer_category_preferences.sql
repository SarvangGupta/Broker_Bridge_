-- Migration: 0064_buyer_category_preferences.sql
-- RMBROKER-DIRECTORY-ALL-CATEGORIES-01 (owner-approved for production).
-- One row per buyer and chosen master category. A buyer with no rows is
-- interested in All Categories; rows are never bulk-assigned to express that.
-- Directory visibility only: nothing here creates requirements or matches.

CREATE TABLE public.buyer_category_preferences (
  buyer_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES public.master_categories(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (buyer_id, category_id)
);

CREATE INDEX idx_buyer_category_preferences_category_id
  ON public.buyer_category_preferences(category_id);

ALTER TABLE public.buyer_category_preferences ENABLE ROW LEVEL SECURITY;

-- The postgres default ACL grants extra privileges, so start from nothing.
REVOKE ALL ON TABLE public.buyer_category_preferences FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, DELETE ON TABLE public.buyer_category_preferences TO authenticated;

-- The buyer, an admin, or a broker holding this buyer as a live directory contact.
CREATE POLICY "buyer_category_preferences_select_policy"
ON public.buyer_category_preferences FOR SELECT TO authenticated
USING (
  buyer_id = auth.uid()
  OR public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.crm_contacts c
    WHERE c.user_id = buyer_category_preferences.buyer_id
      AND c.broker_id = auth.uid()
      AND c.removed_at IS NULL
  )
);

CREATE POLICY "buyer_category_preferences_insert_policy"
ON public.buyer_category_preferences FOR INSERT TO authenticated
WITH CHECK (buyer_id = auth.uid() AND public.get_auth_role() = 'buyer');

CREATE POLICY "buyer_category_preferences_delete_policy"
ON public.buyer_category_preferences FOR DELETE TO authenticated
USING (buyer_id = auth.uid() AND public.get_auth_role() = 'buyer');
