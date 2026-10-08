CREATE TABLE IF NOT EXISTS "requirement_quality_specs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"requirement_id" uuid NOT NULL,
	"parameter_id" uuid NOT NULL,
	"target_value" numeric NOT NULL,
	"tolerance" numeric,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "requirement_quality_specs" ADD CONSTRAINT "requirement_quality_specs_requirement_id_requirements_id_fk" FOREIGN KEY ("requirement_id") REFERENCES "public"."requirements"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "requirement_quality_specs" ADD CONSTRAINT "requirement_quality_specs_parameter_id_master_quality_parameters_id_fk" FOREIGN KEY ("parameter_id") REFERENCES "public"."master_quality_parameters"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "idx_req_quality_specs_req_id" ON "requirement_quality_specs"("requirement_id");
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "idx_req_quality_specs_param_id" ON "requirement_quality_specs"("parameter_id");
