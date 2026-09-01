ALTER TABLE "availabilities" ADD COLUMN "lot_number" text;--> statement-breakpoint
ALTER TABLE "availabilities" ADD COLUMN "total_quantity" numeric;--> statement-breakpoint
ALTER TABLE "availabilities" ADD COLUMN "available_quantity" numeric;--> statement-breakpoint
ALTER TABLE "availabilities" ADD COLUMN "reserved_quantity" numeric DEFAULT '0' NOT NULL;--> statement-breakpoint
ALTER TABLE "availabilities" ADD COLUMN "sold_quantity" numeric DEFAULT '0' NOT NULL;--> statement-breakpoint
ALTER TABLE "availabilities" ADD COLUMN "minimum_order_quantity" numeric;--> statement-breakpoint
ALTER TABLE "availabilities" ADD COLUMN "asking_price" numeric;--> statement-breakpoint
ALTER TABLE "availabilities" ADD COLUMN "confidential_minimum_price" numeric;--> statement-breakpoint
ALTER TABLE "availabilities" ADD COLUMN "available_from" timestamp DEFAULT now() NOT NULL;--> statement-breakpoint
ALTER TABLE "availabilities" ADD COLUMN "version" integer DEFAULT 1 NOT NULL;--> statement-breakpoint

-- Migrate existing data from Sprint 6 columns to the new Lot/Batch columns
UPDATE "availabilities" SET 
  "total_quantity" = "quantity",
  "available_quantity" = "quantity",
  "asking_price" = "price";--> statement-breakpoint

-- Apply NOT NULL constraints after data is populated
ALTER TABLE "availabilities" ALTER COLUMN "total_quantity" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "availabilities" ALTER COLUMN "available_quantity" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "availabilities" ALTER COLUMN "asking_price" SET NOT NULL;
