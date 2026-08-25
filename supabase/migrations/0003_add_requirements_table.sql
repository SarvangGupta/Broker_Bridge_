CREATE TABLE IF NOT EXISTS requirements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id),
  commodity_id UUID NOT NULL REFERENCES master_commodities(id),
  grade_id UUID NOT NULL REFERENCES master_grades(id),
  quantity DOUBLE PRECISION NOT NULL,
  unit_id UUID NOT NULL REFERENCES master_units(id),
  target_price DOUBLE PRECISION NOT NULL,
  delivery_terms_id TEXT NOT NULL,
  target_date TIMESTAMP NOT NULL,
  status TEXT NOT NULL DEFAULT 'Open',
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
