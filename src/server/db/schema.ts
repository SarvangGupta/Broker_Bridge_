import { pgTable, uuid, text, boolean, timestamp, jsonb, integer, numeric, doublePrecision, index, uniqueIndex } from 'drizzle-orm/pg-core';

export const companies = pgTable('companies', {
  id: uuid('id').defaultRandom().primaryKey(),
  name: text('name').notNull(),
  gst: text('gst'),
  businessTypeId: text('business_type_id'),
  stateId: text('state_id'),
  districtId: text('district_id'),
  status: boolean('status').default(true).notNull(),
  isVerified: boolean('is_verified').default(false).notNull(),
  trustScore: integer('trust_score').default(100).notNull(),
});

export const users = pgTable('users', {
  id: uuid('id').defaultRandom().primaryKey(),
  name: text('name').notNull(),
  mobile: text('mobile'),
  email: text('email'),
  role: text('role'),
  status: boolean('status').default(true).notNull(),
  companyId: uuid('company_id').references(() => companies.id),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const profilesBuyer = pgTable('profiles_buyer', {
  id: uuid('id').references(() => users.id).primaryKey(),
});

export const profilesSeller = pgTable('profiles_seller', {
  id: uuid('id').references(() => users.id).primaryKey(),
});

export const profilesBroker = pgTable('profiles_broker', {
  id: uuid('id').references(() => users.id).primaryKey(),
});

export const masterBusinessTypes = pgTable('master_business_types', {
  id: uuid('id').defaultRandom().primaryKey(),
  name: text('name').notNull(),
  status: boolean('status').default(true).notNull(),
});

export const masterStates = pgTable('master_states', {
  id: uuid('id').defaultRandom().primaryKey(),
  name: text('name').notNull(),
  code: text('code'),
});

export const masterDistricts = pgTable('master_districts', {
  id: uuid('id').defaultRandom().primaryKey(),
  name: text('name').notNull(),
  stateId: uuid('state_id').references(() => masterStates.id),
});

export const masterIndustries = pgTable('master_industries', {
  id: uuid('id').defaultRandom().primaryKey(),
  name: text('name').notNull(),
  isActive: boolean('is_active').default(true).notNull(),
});

export const masterCategories = pgTable('master_categories', {
  id: uuid('id').defaultRandom().primaryKey(),
  industryId: uuid('industry_id').references(() => masterIndustries.id),
  name: text('name').notNull(),
  isActive: boolean('is_active').default(true).notNull(),
});

export const masterCommodities = pgTable('master_commodities', {
  id: uuid('id').defaultRandom().primaryKey(),
  categoryId: uuid('category_id').references(() => masterCategories.id),
  name: text('name').notNull(),
  code: text('code'),
  status: boolean('status').default(true).notNull(),
});

export const masterGrades = pgTable('master_grades', {
  id: uuid('id').defaultRandom().primaryKey(),
  commodityId: uuid('commodity_id').references(() => masterCommodities.id),
  gradeName: text('grade_name').notNull(),
  parameters: jsonb('parameters'),
});

export const masterUnits = pgTable('master_units', {
  id: uuid('id').defaultRandom().primaryKey(),
  name: text('name').notNull(),
  symbol: text('symbol'),
});

export const masterPackagingTypes = pgTable('master_packaging_types', {
  id: uuid('id').defaultRandom().primaryKey(),
  name: text('name').notNull(),
  status: boolean('status').default(true).notNull(),
});

export const masterQualityParameters = pgTable('master_quality_parameters', {
  id: uuid('id').defaultRandom().primaryKey(),
  commodityId: uuid('commodity_id').references(() => masterCommodities.id).notNull(),
  name: text('name').notNull(),
  type: text('type').notNull(), // 'numeric', 'boolean', 'text'
  unit: text('unit'), // '%', 'mg/kg'
  minValue: numeric('min_value'),
  maxValue: numeric('max_value'),
  targetValue: numeric('target_value'),
  isRequired: boolean('is_required').default(false).notNull(),
  isActive: boolean('is_active').default(true).notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
});

export const masterLaboratories = pgTable('master_laboratories', {
  id: uuid('id').defaultRandom().primaryKey(),
  name: text('name').notNull(),
  location: text('location'),
  isActive: boolean('is_active').default(true).notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const requirements = pgTable('requirements', {
  id: uuid('id').defaultRandom().primaryKey(),
  companyId: uuid('company_id').references(() => companies.id).notNull(),
  commodityId: uuid('commodity_id').references(() => masterCommodities.id).notNull(),
  gradeId: uuid('grade_id').references(() => masterGrades.id).notNull(),
  quantity: doublePrecision('quantity').notNull(),
  unitId: uuid('unit_id').references(() => masterUnits.id).notNull(),
  targetPrice: doublePrecision('target_price').notNull(),
  deliveryTermsId: text('delivery_terms_id').notNull(),
  targetDate: timestamp('target_date').notNull(),
  visibility: text('visibility').default('global').notNull(),
  brokerId: uuid('broker_id'),
  status: text('status').default('Open').notNull(),
  fulfilledQuantity: doublePrecision('fulfilled_quantity').default(0).notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const requirementQualitySpecs = pgTable('requirement_quality_specs', {
  id: uuid('id').defaultRandom().primaryKey(),
  requirementId: uuid('requirement_id').references(() => requirements.id, { onDelete: 'cascade' }).notNull(),
  parameterId: uuid('parameter_id').references(() => masterQualityParameters.id).notNull(),
  targetValue: numeric('target_value').notNull(),
  tolerance: numeric('tolerance'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
});

export const requirementDocuments = pgTable('requirement_documents', {
  id: uuid('id').defaultRandom().primaryKey(),
  requirementId: uuid('requirement_id').references(() => requirements.id, { onDelete: 'cascade' }).notNull(),
  documentType: text('document_type').notNull(),
  isMandatory: boolean('is_mandatory').default(true).notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
});

export const availabilities = pgTable('availabilities', {
  id: uuid('id').defaultRandom().primaryKey(),
  companyId: uuid('company_id').references(() => companies.id).notNull(),
  commodityId: uuid('commodity_id').references(() => masterCommodities.id).notNull(),
  gradeId: uuid('grade_id').references(() => masterGrades.id).notNull(),
  quantity: integer('quantity').notNull(), // Sprint 6 compatibility
  unitId: uuid('unit_id').references(() => masterUnits.id).notNull(),
  price: numeric('price').notNull(), // Sprint 6 compatibility
  stateId: uuid('state_id').references(() => masterStates.id).notNull(),
  districtId: uuid('district_id').references(() => masterDistricts.id).notNull(),
  visibility: text('visibility').default('global').notNull(),
  brokerId: uuid('broker_id'),
  status: text('status').default('Open').notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  // Lot / Batch Data Model (Sprint 14.1 - PRD v3.0)
  lotNumber: text('lot_number'),
  totalQuantity: numeric('total_quantity').notNull(),
  availableQuantity: numeric('available_quantity').notNull(),
  reservedQuantity: numeric('reserved_quantity').default('0').notNull(),
  soldQuantity: numeric('sold_quantity').default('0').notNull(),
  minimumOrderQuantity: numeric('minimum_order_quantity'),
  askingPrice: numeric('asking_price').notNull(),
  confidentialMinimumPrice: numeric('confidential_minimum_price'),
  availableFrom: timestamp('available_from').defaultNow().notNull(),
  validUntil: timestamp('valid_until').notNull(),
  version: integer('version').default(1).notNull(),
  // Loading Readiness Model (Sprint 16.1 - PRD v3.0)
  loadingStatus: text('loading_status').default('Not Ready').notNull(),
  loadingDuration: integer('loading_duration'),
  loadingStartDate: timestamp('loading_start_date'),
  loadingCapacity: numeric('loading_capacity'),
  loadingRemarks: text('loading_remarks'),
  loadingUpdatedAt: timestamp('loading_updated_at'),
});

export const availabilityQualityValues = pgTable('availability_quality_values', {
  id: uuid('id').defaultRandom().primaryKey(),
  availabilityId: uuid('availability_id').references(() => availabilities.id, { onDelete: 'cascade' }).notNull(),
  parameterId: uuid('parameter_id').references(() => masterQualityParameters.id).notNull(),
  value: text('value').notNull(),
  source: text('source').default('Seller Declared').notNull(),
  verificationStatus: text('verification_status').default('Pending').notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
});

export const labTests = pgTable('lab_tests', {
  id: uuid('id').defaultRandom().primaryKey(),
  availabilityId: uuid('availability_id').references(() => availabilities.id, { onDelete: 'cascade' }).notNull(),
  companyId: uuid('company_id').references(() => companies.id).notNull(),
  laboratoryName: text('laboratory_name').notNull(),
  laboratoryLocation: text('laboratory_location'),
  sampleId: text('sample_id'),
  sampleDate: timestamp('sample_date'),
  testDate: timestamp('test_date').notNull(),
  reportNumber: text('report_number').notNull(),
  reportDate: timestamp('report_date').notNull(),
  validUntil: timestamp('valid_until'),
  fileUrl: text('file_url'),
  status: text('status').default('Under Review').notNull(), // 'Sample Pending', 'Testing In Progress', 'Report Uploaded', 'Under Review', 'Verified', 'Correction Required', 'Rejected', 'Expired'
  verifiedBy: uuid('verified_by').references(() => users.id),
  verifiedAt: timestamp('verified_at'),
  verificationNotes: text('verification_notes'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
});

export const labTestResults = pgTable('lab_test_results', {
  id: uuid('id').defaultRandom().primaryKey(),
  labTestId: uuid('lab_test_id').references(() => labTests.id, { onDelete: 'cascade' }).notNull(),
  parameterId: uuid('parameter_id').references(() => masterQualityParameters.id).notNull(),
  measuredValue: text('measured_value').notNull(),
  isWithinBounds: boolean('is_within_bounds').default(true).notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
});

export const quotations = pgTable('quotations', {
  id: uuid('id').defaultRandom().primaryKey(),
  requirementId: uuid('requirement_id').notNull(),
  brokerId: uuid('broker_id').notNull(),
  sellerAvailabilityId: uuid('seller_availability_id').notNull(),
  offeredPrice: numeric('offered_price').notNull(),
  status: text('status').default('Sent').notNull(),
  validUntil: timestamp('valid_until').notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  rejectionReason: text('rejection_reason'),
  counterPrice: numeric('counter_price'),
  counterNotes: text('counter_notes'),
});

export const deals = pgTable('deals', {
  id: uuid('id').defaultRandom().primaryKey(),
  requirementId: uuid('requirement_id').notNull(),
  quotationId: uuid('quotation_id').references(() => quotations.id).notNull(),
  buyerId: uuid('buyer_id').notNull(),
  sellerId: uuid('seller_id').notNull(),
  brokerId: uuid('broker_id'),
  agreedPrice: numeric('agreed_price').notNull(),
  agreedQuantity: doublePrecision('agreed_quantity').notNull(),
  status: text('status').default('Dispatch Pending').notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  closedAt: timestamp('closed_at'),
});

export const masterVehicleTypes = pgTable('master_vehicle_types', {
  id: uuid('id').defaultRandom().primaryKey(),
  name: text('name').notNull(),
  status: boolean('status').default(true).notNull(),
});

export const dispatches = pgTable('dispatches', {
  id: uuid('id').defaultRandom().primaryKey(),
  dealId: uuid('deal_id').references(() => deals.id).notNull(),
  sellerId: uuid('seller_id').references(() => users.id).notNull(),
  vehicleTypeId: uuid('vehicle_type_id').references(() => masterVehicleTypes.id),
  vehicleNumber: text('vehicle_number').notNull(),
  driverName: text('driver_name').notNull(),
  driverMobile: text('driver_mobile').notNull(),
  dispatchDate: timestamp('dispatch_date').notNull(),
  expectedDeliveryDate: timestamp('expected_delivery_date').notNull(),
  status: text('status').default('Dispatched').notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const dispatchDocuments = pgTable('dispatch_documents', {
  id: uuid('id').defaultRandom().primaryKey(),
  dispatchId: uuid('dispatch_id').references(() => dispatches.id, { onDelete: 'cascade' }).notNull(),
  documentType: text('document_type').notNull(), // 'LR', 'Invoice', 'E-Way Bill', 'Weighment Slip', 'Loading Photo'
  fileUrl: text('file_url').notNull(),
  uploadedBy: uuid('uploaded_by').references(() => users.id),
  createdAt: timestamp('created_at').defaultNow().notNull(),
}, (table) => [
  index('dispatch_documents_dispatch_idx').on(table.dispatchId),
  index('dispatch_documents_type_idx').on(table.dispatchId, table.documentType),
]);

export const invoices = pgTable('invoices', {
  id: uuid('id').defaultRandom().primaryKey(),
  dealId: uuid('deal_id').references(() => deals.id).notNull(),
  sellerId: uuid('seller_id').references(() => users.id).notNull(),
  invoiceNo: text('invoice_no').notNull(),
  amount: numeric('amount').notNull(),
  status: text('status').default('Pending').notNull(),
  fileUrl: text('file_url').notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const payments = pgTable('payments', {
  id: uuid('id').defaultRandom().primaryKey(),
  dealId: uuid('deal_id').references(() => deals.id).notNull(),
  amount: numeric('amount').notNull(),
  referenceNumber: text('reference_number').notNull(),
  status: text('status').default('Confirmed').notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const disputes = pgTable('disputes', {
  id: uuid('id').defaultRandom().primaryKey(),
  dealId: uuid('deal_id').references(() => deals.id).notNull(),
  filedBy: uuid('filed_by').references(() => users.id).notNull(),
  reason: text('reason').notNull(),
  description: text('description'),
  resolutionNotes: text('resolution_notes'),
  status: text('status').default('Open').notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  resolvedAt: timestamp('resolved_at'),
});

export const supportTickets = pgTable('support_tickets', {
  id: uuid('id').defaultRandom().primaryKey(),
  userId: uuid('user_id').references(() => users.id),
  role: text('role').notNull(),
  issueType: text('issue_type').notNull(),
  description: text('description').notNull(),
  status: text('status').default('Open').notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  resolvedAt: timestamp('resolved_at'),
});

export const notifications = pgTable('notifications', {
  id: uuid('id').defaultRandom().primaryKey(),
  userId: uuid('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  companyId: uuid('company_id').references(() => companies.id, { onDelete: 'cascade' }),
  channel: text('channel').default('IN_APP').notNull(), // 'IN_APP', 'WHATSAPP', 'EMAIL'
  eventType: text('event_type').notNull(), // 'KYC_STATUS', 'AVAILABILITY_APPROVED', 'AVAILABILITY_REJECTED', 'AVAILABILITY_EXPIRING', 'AVAILABILITY_EXPIRED', 'QUALITY_REVIEW', 'LAB_UPDATE', 'NEW_BROKER_REQUEST', 'BROKER_COUNTER', 'DEAL_VERSION_UPDATE', 'FINAL_CONFIRMATION_REQUIRED', 'CONFIRMATION_OUTCOME', 'BOOKING_CREATED', 'LOADING_REMINDER', 'DISPATCH_REMINDER', 'DOCUMENT_ISSUE', 'DELIVERY_UPDATE', 'PAYMENT_UPDATE', 'SYSTEM'
  title: text('title').notNull(),
  message: text('message').default('').notNull(),
  contextReason: text('context_reason').default('').notNull(),
  actionLabel: text('action_label').default('View Details').notNull(),
  actionUrl: text('action_url').default('/seller').notNull(),
  idempotencyKey: text('idempotency_key'),
  payload: jsonb('payload'),
  deliveryStatus: text('delivery_status').default('Pending').notNull(), // 'Pending', 'Processing', 'Sent', 'Failed'
  isRead: boolean('is_read').default(false).notNull(),
  readAt: timestamp('read_at'),
  attemptCount: integer('attempt_count').default(0).notNull(),
  maxAttempts: integer('max_attempts').default(3).notNull(),
  lastAttemptAt: timestamp('last_attempt_at'),
  nextRetryAt: timestamp('next_retry_at'),
  errorMessage: text('error_message'),
  providerMessageId: text('provider_message_id'),
  sentAt: timestamp('sent_at'),
  failedAt: timestamp('failed_at'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
}, (table) => [
  uniqueIndex('notifications_idempotency_key_idx').on(table.idempotencyKey),
  index('notifications_user_created_idx').on(table.userId, table.createdAt),
  index('notifications_tenant_idx').on(table.companyId, table.createdAt),
  index('notifications_user_is_read_idx').on(table.userId, table.isRead, table.createdAt),
  index('notifications_queue_idx').on(table.deliveryStatus, table.channel, table.nextRetryAt, table.createdAt),
]);

export const crmContacts = pgTable('crm_contacts', {
  id: uuid('id').defaultRandom().primaryKey(),
  brokerId: uuid('broker_id').references(() => users.id).notNull(),
  userId: uuid('user_id').references(() => users.id),
  companyId: uuid('company_id').references(() => companies.id),
  lastActivityAt: timestamp('last_activity_at'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const crmActivities = pgTable('crm_activities', {
  id: uuid('id').defaultRandom().primaryKey(),
  contactId: uuid('contact_id').references(() => crmContacts.id, { onDelete: 'cascade' }).notNull(),
  type: text('type').notNull(),
  notes: text('notes').notNull(),
  followUpDate: timestamp('follow_up_date'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const crmTasks = pgTable('crm_tasks', {
  id: uuid('id').defaultRandom().primaryKey(),
  brokerId: uuid('broker_id').references(() => users.id).notNull(),
  contactId: uuid('contact_id'),
  title: text('title').notNull(),
  dueDate: timestamp('due_date').notNull(),
  priority: text('priority').notNull(),
  status: text('status').default('Pending').notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const negotiationEvents = pgTable('negotiation_events', {
  id: uuid('id').defaultRandom().primaryKey(),
  requestId: uuid('request_id').notNull(),
  companyId: uuid('company_id').references(() => companies.id).notNull(),
  actorId: uuid('actor_id').references(() => users.id).notNull(),
  actionType: text('action_type').notNull(), // 'ACCEPT', 'REJECT', 'COUNTER'
  payload: jsonb('payload'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
}, (table) => [
  index('negotiation_events_request_idx').on(table.requestId, table.createdAt),
  index('negotiation_events_company_idx').on(table.companyId, table.createdAt),
]);

export const dealVersions = pgTable('deal_versions', {
  id: uuid('id').defaultRandom().primaryKey(),
  requestId: uuid('request_id').notNull(),
  versionNumber: integer('version_number').notNull(),
  actorId: uuid('actor_id').references(() => users.id).notNull(),
  status: text('status').default('Proposed').notNull(), // 'Draft', 'Proposed', 'Countered', 'Seller Confirmed', 'Buyer Confirmed', 'Broker Finalized', 'Superseded'
  snapshotPayload: jsonb('snapshot_payload').notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
}, (table) => [
  index('deal_versions_request_idx').on(table.requestId, table.versionNumber),
]);

export const bookings = pgTable('bookings', {
  id: uuid('id').defaultRandom().primaryKey(),
  bookingReference: text('booking_reference').notNull().unique(),
  dealId: uuid('deal_id').notNull().unique(),
  lockedVersionId: uuid('locked_version_id').references(() => dealVersions.id).notNull(),
  status: text('status').default('Confirmed').notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
}, (table) => [
  index('bookings_deal_idx').on(table.dealId),
  index('bookings_reference_idx').on(table.bookingReference),
]);
