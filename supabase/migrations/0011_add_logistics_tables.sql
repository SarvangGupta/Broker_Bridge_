CREATE TABLE "dispatches" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"deal_id" uuid NOT NULL,
	"seller_id" uuid NOT NULL,
	"vehicle_type_id" uuid,
	"vehicle_number" text NOT NULL,
	"driver_name" text NOT NULL,
	"driver_mobile" text NOT NULL,
	"dispatch_date" timestamp NOT NULL,
	"expected_delivery_date" timestamp NOT NULL,
	"status" text DEFAULT 'Dispatched' NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "invoices" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"deal_id" uuid NOT NULL,
	"seller_id" uuid NOT NULL,
	"invoice_no" text NOT NULL,
	"amount" numeric NOT NULL,
	"status" text DEFAULT 'Pending' NOT NULL,
	"file_url" text NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "master_vehicle_types" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"status" boolean DEFAULT true NOT NULL
);
--> statement-breakpoint
ALTER TABLE "dispatches" ADD CONSTRAINT "dispatches_deal_id_deals_id_fk" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "dispatches" ADD CONSTRAINT "dispatches_seller_id_users_id_fk" FOREIGN KEY ("seller_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "dispatches" ADD CONSTRAINT "dispatches_vehicle_type_id_master_vehicle_types_id_fk" FOREIGN KEY ("vehicle_type_id") REFERENCES "public"."master_vehicle_types"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "invoices" ADD CONSTRAINT "invoices_deal_id_deals_id_fk" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "invoices" ADD CONSTRAINT "invoices_seller_id_users_id_fk" FOREIGN KEY ("seller_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;