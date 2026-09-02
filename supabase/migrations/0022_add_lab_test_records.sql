CREATE TABLE "lab_test_results" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"lab_test_id" uuid NOT NULL,
	"parameter_id" uuid NOT NULL,
	"measured_value" text NOT NULL,
	"is_within_bounds" boolean DEFAULT true NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "lab_tests" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"availability_id" uuid NOT NULL,
	"company_id" uuid NOT NULL,
	"laboratory_name" text NOT NULL,
	"laboratory_location" text,
	"sample_id" text,
	"sample_date" timestamp,
	"test_date" timestamp NOT NULL,
	"report_number" text NOT NULL,
	"report_date" timestamp NOT NULL,
	"valid_until" timestamp,
	"status" text DEFAULT 'Under Review' NOT NULL,
	"verified_by" uuid,
	"verified_at" timestamp,
	"verification_notes" text,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "lab_test_results" ADD CONSTRAINT "lab_test_results_lab_test_id_lab_tests_id_fk" FOREIGN KEY ("lab_test_id") REFERENCES "public"."lab_tests"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "lab_test_results" ADD CONSTRAINT "lab_test_results_parameter_id_master_quality_parameters_id_fk" FOREIGN KEY ("parameter_id") REFERENCES "public"."master_quality_parameters"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "lab_tests" ADD CONSTRAINT "lab_tests_availability_id_availabilities_id_fk" FOREIGN KEY ("availability_id") REFERENCES "public"."availabilities"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "lab_tests" ADD CONSTRAINT "lab_tests_company_id_companies_id_fk" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "lab_tests" ADD CONSTRAINT "lab_tests_verified_by_users_id_fk" FOREIGN KEY ("verified_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;