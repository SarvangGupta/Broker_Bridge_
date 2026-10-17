# DATABASE AND API REFERENCE

**Document Reference:** `project-audit/06_DATABASE_API_REFERENCE.md`  
**Date of Audit:** October 17, 2026  
**Auditor:** Senior Database Architect & Backend Systems Specialist  
**Project:** BrokerBridge Enterprise & VetKind Animal Health India  

---

## 1. Relational Database Architecture Overview

The database is built on **PostgreSQL (Supabase DBaaS)** using **Drizzle ORM** (`src/server/db/schema.ts`, `src/server/db/vetkind-schema.ts`). 

The schema comprises **36 total tables** (32 core trading and governance tables + 4 VetKind domain tables) with strict foreign key constraints, cascaded deletions where appropriate, optimistic locking integers, and append-only database triggers.

---

## 2. Complete PostgreSQL Schema Dictionary

### 2.1 Core Identity & Multi-Tenant Entities
- **`companies`**: Tenant organization entity.
  - Columns: `id` (UUID PK), `name` (TEXT NOT NULL), `gst` (TEXT), `business_type_id` (TEXT), `state_id` (TEXT), `district_id` (TEXT), `status` (BOOL DEFAULT true), `is_verified` (BOOL DEFAULT false), `trust_score` (INT DEFAULT 100).
- **`users`**: User identity linked to Supabase Auth.
  - Columns: `id` (UUID PK), `name` (TEXT NOT NULL), `mobile` (TEXT), `email` (TEXT), `role` (TEXT: `'admin'`, `'broker'`, `'buyer'`, `'seller'`), `status` (BOOL DEFAULT true), `company_id` (UUID FK -> `companies.id`), `created_at` (TIMESTAMP).
- **`profiles_buyer`**: Buyer-specific profile attributes (UUID PK -> `users.id`).
- **`profiles_seller`**: Seller-specific profile attributes (UUID PK -> `users.id`).
- **`profiles_broker`**: Broker-specific profile attributes (UUID PK -> `users.id`).

### 2.2 Master Data Layer
- **`master_business_types`**: Legal organization types (e.g. Pvt Ltd, Proprietorship, LLP, Cooperative).
- **`master_states`**: Indian states (e.g. Rajasthan, Gujarat, Maharashtra, Punjab).
- **`master_districts`**: Districts linked to `master_states.id`.
- **`master_industries`**: Top-level sector (e.g. Agriculture, Animal Husbandry, Dairy).
- **`master_categories`**: Category linked to `master_industries.id` (e.g. Grains, Oilseeds, Cattle Feed Supplements).
- **`master_commodities`**: Tradeable commodity linked to `master_categories.id` (e.g. Wheat, Yellow Maize, Soybean Meal).
- **`master_grades`**: Commodity grade baselines (JSONB parameters).
- **`master_units`**: Measurement units (MT, Quintal, KG, Litre).
- **`master_packaging_types`**: Packaging options (50kg PP Bags, Jute Bags, Bulk Tanker, Loose).
- **`master_quality_parameters`**: Scientific laboratory test parameters.
  - Columns: `id` (UUID PK), `commodity_id` (UUID FK), `name` (TEXT), `type` (TEXT: `'numeric'`, `'boolean'`, `'text'`), `unit` (TEXT: `'%', 'mg/kg'`), `min_value` (NUMERIC), `max_value` (NUMERIC), `target_value` (NUMERIC), `is_required` (BOOL), `is_active` (BOOL).
- **`master_laboratories`**: Accredited testing labs (e.g. NABL certified testing facilities).
- **`master_vehicle_types`**: Transport vehicles (e.g. 10-Tyre Truck, 12-Tyre Truck, Multi-Axle Trailer, Tanker).

### 2.3 Buyer Demand & Specifications
- **`requirements`**: Buyer purchase requirements.
  - Columns: `id` (UUID PK), `company_id` (UUID FK), `commodity_id` (UUID FK), `grade_id` (UUID FK), `quantity` (DOUBLE PRECISION), `unit_id` (UUID FK), `target_price` (DOUBLE PRECISION), `delivery_terms_id` (TEXT), `target_date` (TIMESTAMP), `visibility` (TEXT: `'global'`, `'broker'`), `broker_id` (UUID), `status` (TEXT: `'Draft'`, `'Open'`, `'Matched'`, `'Partially Fulfilled'`, `'Fulfilled'`, `'Cancelled'`), `fulfilled_quantity` (DOUBLE PRECISION DEFAULT 0), `created_at` (TIMESTAMP).
- **`requirement_quality_specs`**: Dynamic parameter constraints defined by the Buyer.
  - Columns: `id` (UUID PK), `requirement_id` (UUID FK ON DELETE CASCADE), `parameter_id` (UUID FK -> `master_quality_parameters.id`), `target_value` (NUMERIC), `tolerance` (NUMERIC).
- **`requirement_documents`**: Mandatory document checklist for compliance.
  - Columns: `id` (UUID PK), `requirement_id` (UUID FK ON DELETE CASCADE), `document_type` (TEXT), `is_mandatory` (BOOL DEFAULT true).

### 2.4 Seller Supply & Quality Evidence
- **`availabilities`**: Seller inventory lots.
  - Columns: `id` (UUID PK), `company_id` (UUID FK), `commodity_id` (UUID FK), `grade_id` (UUID FK), `lot_number` (TEXT), `total_quantity` (NUMERIC), `available_quantity` (NUMERIC), `reserved_quantity` (NUMERIC), `sold_quantity` (NUMERIC), `asking_price` (NUMERIC), `confidential_minimum_price` (NUMERIC), `valid_until` (TIMESTAMP), `version` (INT DEFAULT 1 - Concurrency Lock), `loading_status` (TEXT), `loading_start_date` (TIMESTAMP), `loading_capacity` (NUMERIC), `status` (TEXT: `'Active'`, `'Open'`, `'Reserved'`, `'Sold'`, `'Expired'`, `'Cancelled'`).
- **`availability_quality_values`**: Declared laboratory parameters for the lot.
  - Columns: `id` (UUID PK), `availability_id` (UUID FK ON DELETE CASCADE), `parameter_id` (UUID FK), `value` (TEXT), `source` (TEXT: `'Seller Declared'`), `verification_status` (TEXT: `'Pending'`, `'Verified'`).
- **`lab_tests`**: Official laboratory testing certificate records.
  - Columns: `id` (UUID PK), `availability_id` (UUID FK ON DELETE CASCADE), `company_id` (UUID FK), `laboratory_name` (TEXT), `sample_date` (TIMESTAMP), `test_date` (TIMESTAMP), `report_number` (TEXT), `report_date` (TIMESTAMP), `valid_until` (TIMESTAMP), `file_url` (TEXT - Private Storage path), `status` (TEXT: `'Under Review'`, `'Verified'`, `'Rejected'`, `'Expired'`), `verified_by` (UUID FK -> `users.id`).
- **`lab_test_results`**: Structured analytical results from the lab certificate.
  - Columns: `id` (UUID PK), `lab_test_id` (UUID FK ON DELETE CASCADE), `parameter_id` (UUID FK), `measured_value` (TEXT), `is_within_bounds` (BOOL).

### 2.5 Quotations, Deals, Versioning & Bookings
- **`quotations`**: Commercial proposal entity.
  - Columns: `id` (UUID PK), `requirement_id` (UUID), `broker_id` (UUID), `seller_availability_id` (UUID), `offered_price` (NUMERIC), `status` (TEXT: `'Sent'`, `'Accepted'`, `'Countered'`, `'Rejected'`, `'Expired'`), `valid_until` (TIMESTAMP), `counter_price` (NUMERIC), `counter_notes` (TEXT).
- **`deals`**: Mutual trading contract record.
  - Columns: `id` (UUID PK), `requirement_id` (UUID), `quotation_id` (UUID FK), `buyer_id` (UUID), `seller_id` (UUID), `broker_id` (UUID), `agreed_price` (NUMERIC), `agreed_quantity` (DOUBLE PRECISION), `status` (TEXT: `'Dispatch Pending'`, `'Completed'`, `'Disputed'`).
- **`negotiation_events`**: Append-only chronological audit log of counterparty actions.
  - Columns: `id` (UUID PK), `request_id` (UUID), `company_id` (UUID FK), `actor_id` (UUID FK), `action_type` (TEXT: `'ACCEPT'`, `'REJECT'`, `'COUNTER'`, `'BUYER_FINAL_CONFIRMATION'`, `'AMENDMENT_REQUESTED'`), `payload` (JSONB), `created_at` (TIMESTAMP).
- **`deal_versions`**: Immutable commercial term snapshot versions.
  - Columns: `id` (UUID PK), `request_id` (UUID), `version_number` (INT NOT NULL), `actor_id` (UUID FK), `status` (TEXT: `'Draft'`, `'Proposed'`, `'Countered'`, `'Seller Confirmed'`, `'Buyer Confirmed'`, `'Broker Finalized'`, `'Superseded'`), `snapshot_payload` (JSONB NOT NULL), `created_at` (TIMESTAMP).
- **`bookings`**: Idempotent legal booking reference minted by Broker Desk.
  - Columns: `id` (UUID PK), `booking_reference` (TEXT UNIQUE: e.g. `BKG-2026-8812`), `deal_id` (UUID UNIQUE), `locked_version_id` (UUID FK -> `deal_versions.id`), `status` (TEXT: `'Confirmed'`, `'Completed'`, `'Cancelled'`).

### 2.6 Fulfillment, Logistics, Invoices & Settlements
- **`dispatches`**: Physical transport vehicle dispatches.
  - Columns: `id` (UUID PK), `deal_id` (UUID FK), `seller_id` (UUID FK), `vehicle_type_id` (UUID FK), `vehicle_number` (TEXT), `driver_name` (TEXT), `driver_mobile` (TEXT), `dispatch_date` (TIMESTAMP), `expected_delivery_date` (TIMESTAMP), `status` (TEXT: `'Dispatched'`, `'In Transit'`, `'Delivered'`).
- **`dispatch_documents`**: Transport documentation files.
  - Columns: `id` (UUID PK), `dispatch_id` (UUID FK ON DELETE CASCADE), `document_type` (TEXT: `'LR'`, `'Invoice'`, `'E-Way Bill'`, `'Weighment Slip'`, `'Loading Photo'`), `file_url` (TEXT), `uploaded_by` (UUID FK).
- **`invoices`**: Commercial invoices submitted by Seller.
- **`payments`**: Escrow and settlement payment records.
  - Columns: `id` (UUID PK), `deal_id` (UUID FK), `amount` (NUMERIC), `reference_number` (TEXT), `status` (TEXT: `'Confirmed'`, `'Pending'`).
- **`disputes`**: Formal exception cases mediated by Broker Desk.
  - Columns: `id` (UUID PK), `deal_id` (UUID FK), `filed_by` (UUID FK), `reason` (TEXT: `'Quality'`, `'Quantity'`, `'Delivery'`, `'Document'`, `'Payment'`, `'Commercial'`, `'Other'`), `description` (TEXT), `resolution_notes` (TEXT), `status` (TEXT: `'Open'`, `'Under Broker Review'`, `'Resolved'`).

### 2.7 Platform Operations & Broker CRM
- **`support_tickets`**: Platform helpdesk tickets.
- **`notifications`**: Multi-channel notification queue with exponential retry.
  - Columns: `id` (UUID PK), `user_id` (UUID FK), `company_id` (UUID FK), `channel` (TEXT: `'IN_APP'`, `'WHATSAPP'`, `'EMAIL'`), `event_type` (TEXT), `title` (TEXT), `message` (TEXT), `action_url` (TEXT), `idempotency_key` (TEXT UNIQUE), `delivery_status` (TEXT: `'Pending'`, `'Processing'`, `'Sent'`, `'Failed'`), `is_read` (BOOL), `next_retry_at` (TIMESTAMP).
- **`crm_contacts`**: Broker relationship contacts.
- **`crm_activities`**: Interaction logs (phone calls, mandi visits, notes).
- **`crm_tasks`**: Follow-up task reminders with due dates.

### 2.8 VetKind Animal Health India Schema Extensions
- **`vetkind_categories`**: Animal health categories (Dairy Nutrition, Bovine Therapeutics, Herd Hygiene).
- **`vetkind_products`**: Veterinary formulations, composition, target species, dosage, and withdrawal periods.
- **`vetkind_dealers`**: Authorized veterinary dealers, drug license numbers, territory coverage, and verification status.
- **`vetkind_inquiries`**: Commercial inquiries from veterinarians, dairy cooperatives, and prospective distributors.

---

## 3. Database Migrations Catalog (38 Migrations)

All migrations are maintained in `supabase/migrations/`:
- `0001_init_users_and_companies.sql`: Initial user, company, and profile tables.
- `0002_add_master_tables.sql`: States, districts, commodities, packaging.
- `0003_add_requirements_table.sql`: Buyer requirements baseline.
- `0004_add_availabilities_table.sql`: Seller availabilities baseline.
- `0005_add_quotations_table.sql`: Initial quotations table.
- `0006_add_deals_table.sql`: Initial deals table.
- `0007_add_quotation_rejection_counter_fields.sql`: Rejection reasons.
- `0008_enable_realtime_deals_quotations.sql`: Supabase Realtime broadcast configuration.
- `0009_add_visibility_broker_availabilities.sql`: Private broker visibility.
- `0010_add_visibility_requirements.sql`: Private requirement visibility.
- `0011_add_logistics_tables.sql`: Initial dispatches and logistics.
- `0012_seed_vehicle_types.sql`: Vehicle types seed data.
- `0013_add_payments_and_disputes.sql`: Payments and disputes tables.
- `0014_add_support_tickets.sql`: Helpdesk tickets.
- `0015_add_company_trust_scores.sql`: Trust score algorithm columns.
- `0016_add_fulfilled_quantity_to_requirements.sql`: Partial fulfillment support.
- `0017_add_notifications_table.sql`: Event notification queue.
- `0018_add_master_industries_and_categories.sql`: Multi-sector 3-tier taxonomy.
- `0019_add_crm_tables.sql`: CRM contacts, activities, and tasks.
- `0020_upgrade_availabilities_lot_model.sql`: Traceable lot inventory model.
- `0021_quality_parameter_master_integration.sql`: Dynamic quality parameter EAV schema.
- `0022_add_lab_test_records.sql`: Structured laboratory records and results.
- `0023_add_file_url_to_lab_tests.sql`: Storage file URL mapping.
- `0024_add_loading_readiness_to_availabilities.sql`: Loading readiness model.
- `0025_add_notification_action_url.sql`: Notification deep-linking.
- `0026_add_negotiation_events.sql`: Append-only negotiation event stream.
- `0027_add_deal_versions_snapshot.sql`: Immutable deal versioning table.
- `0028_add_bookings_table.sql`: Idempotent bookings table with unique constraint.
- `0029_add_dispatch_documents.sql`: Transit document vault table.
- `0030_add_seller_action_center_notifications.sql`: Notification idempotency indexing.
- `0031_add_master_laboratories.sql`: Accredited testing laboratories.
- `0032_add_requirement_quality_specs.sql`: Dynamic quality specs for Buyer requirements.
- `0033_add_requirement_documents_table.sql`: Mandatory fulfillment document checklist.
- `0034_enforce_negotiation_immutability.sql`: PostgreSQL database triggers preventing mutation of `negotiation_events` and `deal_versions`.
- `manual_storage_rls.sql`: Supabase storage bucket RLS policies.
- `manual_lab_storage_rls.sql`: Laboratory evidence bucket RLS policies.
- `manual_rls_companies.sql`: Tenant company isolation RLS script.
- `seed_states_rajasthan_districts.sql`: Master geography seed data.

---

## 4. Server Actions API Catalog (Key Action Suites)

The backend provides **68 specialized Server Action suites** in `src/server/actions/`. Every action executes strict session validation and tenant ownership checks:

### 4.1 Buyer Action Suites
- **`buyer-requirement-actions.ts`**: `getBuyerRequirementsListAction`, `getBuyerRequirementDetailAction`, `updateRequirementAction`, `cancelRequirementAction`.
- **`buyer-quality-actions.ts`**: `getCommodityQualityParametersAction`, `saveRequirementQualitySpecsAction`, `getRequirementQualitySpecsAction`.
- **`buyer-proposal-actions.ts`**: `getBuyerProposalsInboxAction`, `getBuyerProposalDetailAction`, `acceptBuyerProposalAction`, `rejectBuyerProposalAction`.
- **`buyer-negotiation-actions.ts`**: `getBuyerNegotiationTimelineAction`, `submitBuyerCounterOfferAction`.
- **`buyer-deal-actions.ts`**: `getFinalDealReviewAction`, `confirmFinalDealAction`, `requestDealAmendmentAction`.
- **`buyer-order-actions.ts`**: `getBuyerOrdersListAction`, `getBuyerBookingVisibilityAction`, `getBuyerDispatchDocumentSignedUrlAction`.
- **`buyer-quality-tracking-actions.ts`**: `getBuyerTransactionQualityAction`, `getBuyerLabReportSignedUrlAction`, `getBuyerWeighmentSlipSignedUrlAction`.
- **`buyer-document-actions.ts`**: `getBuyerDocumentMatrixAction`, `getBuyerDocumentSignedUrlAction`.
- **`buyer-payment-actions.ts`**: `getBuyerPayableLedgerAction`.
- **`buyer-dispute-actions.ts`**: `getBuyerActiveDisputesAction`, `createBuyerDisputeAction`, `uploadBuyerDisputeEvidenceAction`.

### 4.2 Seller Action Suites
- **`availability-actions.ts`**: `createAvailabilityAction`, `getMyAvailabilitiesAction`, `updateAvailabilityAction`, `cancelAvailabilityAction`.
- **`broker-request-actions.ts`**: `getSellerBrokerRequestsAction`, `respondToBrokerRequestAction` (Accept, Reject, Counter).
- **`confirmation-actions.ts`**: `confirmFinalDealTermsAction`, `requestBrokerCorrectionAction`.
- **`dispatch-actions.ts`**: `submitDispatchAction`, `getBookingRemainingQuantityAction`, `getDispatchTrackingAction`.
- **`settlement-actions.ts`**: `getSellerSettlementOverviewAction`.

### 4.3 Broker Action Suites
- **`broker-dashboard-actions.ts`**: `getBrokerDashboardDataAction`.
- **`broker-work-actions.ts`**: `getBrokerAssignedRequirementsAction`.
- **`broker-supply-actions.ts`**: `getBrokerSupplySearchAction` (includes confidential minimum price).
- **`broker-match-actions.ts`**: `getRankedMatchesForRequirementAction`, `logMatchOverrideAction`.
- **`broker-negotiation-actions.ts`**: `sendProposalToSellerAction`, `sendProposalToBuyerAction`.
- **`broker-confirmation-actions.ts`**: `dispatchDealForConfirmationAction`.
- **`finalization-actions.ts`**: `finalizeDealAction`.
- **`booking-actions.ts`**: `createIdempotentBookingAction`.
- **`broker-finance-actions.ts`**: `getBrokerFinancialLedgerAction`.
- **`broker-commission-actions.ts`**: `getBrokerCommissionLedgerAction`.
- **`broker-crm-actions.ts`**: `getBrokerContactAggregatedProfileAction`, `logCrmActivityAction`, `toggleTaskStatusAction`.
- **`broker-dispute-actions.ts`**: `getBrokerActiveDisputesAction`, `resolveDisputeAction`.

### 4.4 VetKind Action Suite
- **`vetkind-actions.ts`**: `getVetKindProductsAction`, `getVetKindProductBySlugAction`, `getVetKindDealersAction`, `submitVetKindInquiryAction`.

---

## 5. API Route Handlers

- **`GET /api/quotations/[id]/pdf`**: Generates and streams official PDF quotation documents via `@react-pdf/renderer`.
- **`POST /api/webhooks/whatsapp`**: Webhook endpoint receiving status callbacks and incoming messages from Meta WhatsApp Cloud API.
- **`GET /api/cron/process-notifications`**: Header-authorized (`CRON_SECRET`) scheduled worker claiming pending notification records (`SKIP LOCKED`) and dispatching via external channels.
- **`GET /api/cron/monitor-dispatches`**: Scheduled worker checking active in-transit dispatches against estimated delivery dates and raising transit delay alerts.
