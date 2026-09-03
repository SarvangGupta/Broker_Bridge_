ALTER TABLE "availabilities" ADD COLUMN "loading_status" text DEFAULT 'Not Ready' NOT NULL;--> statement-breakpoint
ALTER TABLE "availabilities" ADD COLUMN "loading_duration" integer;--> statement-breakpoint
ALTER TABLE "availabilities" ADD COLUMN "loading_start_date" timestamp;--> statement-breakpoint
ALTER TABLE "availabilities" ADD COLUMN "loading_capacity" numeric;--> statement-breakpoint
ALTER TABLE "availabilities" ADD COLUMN "loading_remarks" text;--> statement-breakpoint
ALTER TABLE "availabilities" ADD COLUMN "loading_updated_at" timestamp;
