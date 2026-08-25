CREATE TABLE "availabilities" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"company_id" uuid NOT NULL,
	"commodity_id" uuid NOT NULL,
	"grade_id" uuid NOT NULL,
	"quantity" integer NOT NULL,
	"unit_id" uuid NOT NULL,
	"price" numeric NOT NULL,
	"state_id" uuid NOT NULL,
	"district_id" uuid NOT NULL,
	"valid_until" timestamp NOT NULL,
	"status" text DEFAULT 'Open' NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "availabilities" ADD CONSTRAINT "availabilities_company_id_companies_id_fk" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "availabilities" ADD CONSTRAINT "availabilities_commodity_id_master_commodities_id_fk" FOREIGN KEY ("commodity_id") REFERENCES "public"."master_commodities"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "availabilities" ADD CONSTRAINT "availabilities_grade_id_master_grades_id_fk" FOREIGN KEY ("grade_id") REFERENCES "public"."master_grades"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "availabilities" ADD CONSTRAINT "availabilities_unit_id_master_units_id_fk" FOREIGN KEY ("unit_id") REFERENCES "public"."master_units"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "availabilities" ADD CONSTRAINT "availabilities_state_id_master_states_id_fk" FOREIGN KEY ("state_id") REFERENCES "public"."master_states"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "availabilities" ADD CONSTRAINT "availabilities_district_id_master_districts_id_fk" FOREIGN KEY ("district_id") REFERENCES "public"."master_districts"("id") ON DELETE no action ON UPDATE no action;