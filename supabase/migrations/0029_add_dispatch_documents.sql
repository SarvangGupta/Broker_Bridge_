CREATE TABLE "dispatch_documents" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"dispatch_id" uuid NOT NULL,
	"document_type" text NOT NULL,
	"file_url" text NOT NULL,
	"uploaded_by" uuid,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "dispatch_documents" ADD CONSTRAINT "dispatch_documents_dispatch_id_dispatches_id_fk" FOREIGN KEY ("dispatch_id") REFERENCES "public"."dispatches"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "dispatch_documents" ADD CONSTRAINT "dispatch_documents_uploaded_by_users_id_fk" FOREIGN KEY ("uploaded_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "dispatch_documents_dispatch_idx" ON "dispatch_documents" USING btree ("dispatch_id");--> statement-breakpoint
CREATE INDEX "dispatch_documents_type_idx" ON "dispatch_documents" USING btree ("dispatch_id","document_type");
