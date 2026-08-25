CREATE TABLE "master_business_types" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"status" boolean DEFAULT true NOT NULL
);
--> statement-breakpoint
CREATE TABLE "master_commodities" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"code" text,
	"status" boolean DEFAULT true NOT NULL
);
--> statement-breakpoint
CREATE TABLE "master_districts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"state_id" uuid
);
--> statement-breakpoint
CREATE TABLE "master_grades" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"commodity_id" uuid,
	"grade_name" text NOT NULL,
	"parameters" jsonb
);
--> statement-breakpoint
CREATE TABLE "master_packaging_types" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"status" boolean DEFAULT true NOT NULL
);
--> statement-breakpoint
CREATE TABLE "master_states" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"code" text
);
--> statement-breakpoint
CREATE TABLE "master_units" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"symbol" text
);
--> statement-breakpoint
ALTER TABLE "master_districts" ADD CONSTRAINT "master_districts_state_id_master_states_id_fk" FOREIGN KEY ("state_id") REFERENCES "public"."master_states"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "master_grades" ADD CONSTRAINT "master_grades_commodity_id_master_commodities_id_fk" FOREIGN KEY ("commodity_id") REFERENCES "public"."master_commodities"("id") ON DELETE no action ON UPDATE no action;