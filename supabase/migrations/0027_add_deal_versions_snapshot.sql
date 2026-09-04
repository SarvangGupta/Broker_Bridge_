CREATE TABLE "deal_versions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"request_id" uuid NOT NULL,
	"version_number" integer NOT NULL,
	"actor_id" uuid NOT NULL,
	"status" text DEFAULT 'Proposed' NOT NULL,
	"snapshot_payload" jsonb NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "deal_versions" ADD CONSTRAINT "deal_versions_actor_id_users_id_fk" FOREIGN KEY ("actor_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "deal_versions_request_idx" ON "deal_versions" USING btree ("request_id","version_number");