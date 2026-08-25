CREATE TABLE "quotations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"requirement_id" uuid NOT NULL,
	"broker_id" uuid NOT NULL,
	"seller_availability_id" uuid NOT NULL,
	"offered_price" numeric NOT NULL,
	"status" text DEFAULT 'Sent' NOT NULL,
	"valid_until" timestamp NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL
);
