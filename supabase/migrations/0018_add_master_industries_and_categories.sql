-- Migration: 0018_add_master_industries_and_categories.sql
-- Sprint 13: Multi-Sector Architecture (Industry -> Category -> Commodity)

CREATE TABLE IF NOT EXISTS "master_industries" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"is_active" boolean DEFAULT true NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "master_categories" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"industry_id" uuid,
	"name" text NOT NULL,
	"is_active" boolean DEFAULT true NOT NULL
);
--> statement-breakpoint
ALTER TABLE "master_commodities" ADD COLUMN IF NOT EXISTS "category_id" uuid;
--> statement-breakpoint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'master_categories_industry_id_master_industries_id_fk'
    ) THEN
        ALTER TABLE "master_categories" 
        ADD CONSTRAINT "master_categories_industry_id_master_industries_id_fk" 
        FOREIGN KEY ("industry_id") REFERENCES "public"."master_industries"("id") 
        ON DELETE no action ON UPDATE no action;
    END IF;
END $$;
--> statement-breakpoint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'master_commodities_category_id_master_categories_id_fk'
    ) THEN
        ALTER TABLE "master_commodities" 
        ADD CONSTRAINT "master_commodities_category_id_master_categories_id_fk" 
        FOREIGN KEY ("category_id") REFERENCES "public"."master_categories"("id") 
        ON DELETE no action ON UPDATE no action;
    END IF;
END $$;