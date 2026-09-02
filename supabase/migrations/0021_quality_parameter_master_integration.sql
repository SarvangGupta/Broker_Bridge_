CREATE TABLE "availability_quality_values" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"availability_id" uuid NOT NULL,
	"parameter_id" uuid NOT NULL,
	"value" text NOT NULL,
	"source" text DEFAULT 'Seller Declared' NOT NULL,
	"verification_status" text DEFAULT 'Pending' NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "master_quality_parameters" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"commodity_id" uuid NOT NULL,
	"name" text NOT NULL,
	"type" text NOT NULL,
	"unit" text,
	"min_value" numeric,
	"max_value" numeric,
	"target_value" numeric,
	"is_required" boolean DEFAULT false NOT NULL,
	"is_active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "availability_quality_values" ADD CONSTRAINT "availability_quality_values_availability_id_availabilities_id_fk" FOREIGN KEY ("availability_id") REFERENCES "public"."availabilities"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "availability_quality_values" ADD CONSTRAINT "availability_quality_values_parameter_id_master_quality_parameters_id_fk" FOREIGN KEY ("parameter_id") REFERENCES "public"."master_quality_parameters"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "master_quality_parameters" ADD CONSTRAINT "master_quality_parameters_commodity_id_master_commodities_id_fk" FOREIGN KEY ("commodity_id") REFERENCES "public"."master_commodities"("id") ON DELETE no action ON UPDATE no action;
