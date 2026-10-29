ALTER TABLE "companies" ADD COLUMN "gst_verified" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "companies" ADD COLUMN "gst_verified_at" timestamp;--> statement-breakpoint
ALTER TABLE "companies" ADD COLUMN "gst_live_data" jsonb;