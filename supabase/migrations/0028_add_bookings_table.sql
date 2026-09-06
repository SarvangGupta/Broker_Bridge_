CREATE TABLE "bookings" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"booking_reference" text NOT NULL,
	"deal_id" uuid NOT NULL,
	"locked_version_id" uuid NOT NULL,
	"status" text DEFAULT 'Confirmed' NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "bookings_booking_reference_unique" UNIQUE("booking_reference"),
	CONSTRAINT "bookings_deal_id_unique" UNIQUE("deal_id")
);
--> statement-breakpoint
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_locked_version_id_deal_versions_id_fk" FOREIGN KEY ("locked_version_id") REFERENCES "public"."deal_versions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "bookings_deal_idx" ON "bookings" USING btree ("deal_id");--> statement-breakpoint
CREATE INDEX "bookings_reference_idx" ON "bookings" USING btree ("booking_reference");
