-- Backfill any existing NULL rows before applying constraints
UPDATE "notifications" SET "channel" = 'IN_APP' WHERE "channel" IS NULL;--> statement-breakpoint
UPDATE "notifications" SET "message" = '' WHERE "message" IS NULL;--> statement-breakpoint
UPDATE "notifications" SET "action_url" = '/seller' WHERE "action_url" IS NULL;--> statement-breakpoint

ALTER TABLE "notifications" ALTER COLUMN "channel" SET DEFAULT 'IN_APP';--> statement-breakpoint
ALTER TABLE "notifications" ALTER COLUMN "message" SET DEFAULT '';--> statement-breakpoint
ALTER TABLE "notifications" ALTER COLUMN "action_url" SET DEFAULT '/seller';--> statement-breakpoint
ALTER TABLE "notifications" ALTER COLUMN "action_url" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "notifications" ADD COLUMN "context_reason" text DEFAULT '' NOT NULL;--> statement-breakpoint
ALTER TABLE "notifications" ADD COLUMN "action_label" text DEFAULT 'View Details' NOT NULL;--> statement-breakpoint
ALTER TABLE "notifications" ADD COLUMN "idempotency_key" text;--> statement-breakpoint
ALTER TABLE "notifications" ADD COLUMN "is_read" boolean DEFAULT false NOT NULL;--> statement-breakpoint
CREATE UNIQUE INDEX "notifications_idempotency_key_idx" ON "notifications" USING btree ("idempotency_key");--> statement-breakpoint
CREATE INDEX "notifications_user_is_read_idx" ON "notifications" USING btree ("user_id","is_read","created_at");
