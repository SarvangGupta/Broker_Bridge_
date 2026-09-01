import { pgTable, uuid, text, boolean, timestamp, jsonb, integer, numeric, doublePrecision, index } from 'drizzle-orm/pg-core';

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
  channel: text('channel').notNull(), // 'IN_APP', 'WHATSAPP', 'EMAIL'
  eventType: text('event_type').notNull(), // 'MATCH_CREATED', 'MATCH_UPDATED', 'NEGOTIATION_RECEIVED', 'NEGOTIATION_ACCEPTED', 'DEAL_CREATED', 'DEAL_UPDATED', 'SYSTEM'
  title: text('title').notNull(),
  message: text('message').notNull(),
  payload: jsonb('payload'),
  deliveryStatus: text('delivery_status').default('Pending').notNull(), // 'Pending', 'Processing', 'Sent', 'Failed'
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
  index('notifications_user_created_idx').on(table.userId, table.createdAt),
  index('notifications_tenant_idx').on(table.companyId, table.createdAt),
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


