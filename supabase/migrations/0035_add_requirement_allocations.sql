-- Micro-Sprint RB-09: RMBroker Match Center & Controlled Allocations
-- Migration: 0035_add_requirement_allocations.sql

CREATE TABLE IF NOT EXISTS "requirement_allocations" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  "allocation_reference" text UNIQUE NOT NULL,
  "requirement_id" uuid NOT NULL REFERENCES "requirements"("id") ON DELETE RESTRICT,
  "availability_id" uuid NOT NULL REFERENCES "availabilities"("id") ON DELETE RESTRICT,
  "broker_id" uuid NOT NULL REFERENCES "users"("id") ON DELETE RESTRICT,
  "deal_id" uuid REFERENCES "deals"("id") ON DELETE SET NULL,
  "allocated_quantity" double precision NOT NULL CHECK ("allocated_quantity" > 0),
  "unit_id" uuid NOT NULL REFERENCES "master_units"("id"),
  "price_basis" text DEFAULT 'FOR_DESTINATION',
  "allocated_price" numeric(12,2),
  "status" text NOT NULL DEFAULT 'PROPOSED' CHECK ("status" IN ('PROPOSED', 'CONFIRMED', 'COMMITTED_TO_DEAL', 'RELEASED', 'CANCELLED')),
  "notes" text,
  "release_reason" text,
  "version" integer NOT NULL DEFAULT 1,
  "allocated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "confirmed_at" timestamp with time zone,
  "released_at" timestamp with time zone
);

CREATE INDEX IF NOT EXISTS "idx_alloc_requirement" ON "requirement_allocations" ("requirement_id", "status");
CREATE INDEX IF NOT EXISTS "idx_alloc_availability" ON "requirement_allocations" ("availability_id", "status");
CREATE INDEX IF NOT EXISTS "idx_alloc_broker" ON "requirement_allocations" ("broker_id");
CREATE INDEX IF NOT EXISTS "idx_alloc_deal" ON "requirement_allocations" ("deal_id");
