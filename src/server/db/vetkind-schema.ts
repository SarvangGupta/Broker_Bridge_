import {
  pgTable,
  uuid,
  text,
  boolean,
  timestamp,
  jsonb,
  integer,
  numeric,
  index,
  uniqueIndex,
} from 'drizzle-orm/pg-core';
import { users } from './schema';

/**
 * VetKind Animal Health India - Product Categories
 * Covers dairy, bovine, small ruminants, and livestock health segments.
 */
export const vetkindCategories = pgTable('vetkind_categories', {
  id: uuid('id').defaultRandom().primaryKey(),
  name: text('name').notNull(),
  slug: text('slug').notNull().unique(),
  description: text('description'),
  icon: text('icon'),
  displayOrder: integer('display_order').default(0).notNull(),
  status: boolean('status').default(true).notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

/**
 * VetKind Animal Health India - Product Catalogue
 * Stores pharmaceutical formulations, feed supplements, and hygiene solutions.
 */
export const vetkindProducts = pgTable('vetkind_products', {
  id: uuid('id').defaultRandom().primaryKey(),
  categoryId: uuid('category_id')
    .references(() => vetkindCategories.id)
    .notNull(),
  name: text('name').notNull(),
  slug: text('slug').notNull().unique(),
  sku: text('sku').notNull().unique(),
  shortDescription: text('short_description').notNull(),
  fullDescription: text('full_description'),
  composition: text('composition').notNull(),
  indications: text('indications').notNull(),
  dosageInstructions: text('dosage_instructions').notNull(),
  targetSpecies: jsonb('target_species').notNull(), // e.g. ["Cattle", "Buffalo", "Calf", "Sheep", "Goat"]
  packaging: text('packaging').notNull(), // e.g. "1 Litre Bottle", "5L Jerry Can", "10x4 Bolus Box"
  storageInstructions: text('storage_instructions'),
  withdrawalPeriod: text('withdrawal_period'), // critical veterinary compliance term
  mrp: numeric('mrp'),
  dealerPrice: numeric('dealer_price'),
  status: boolean('status').default(true).notNull(),
  isFeatured: boolean('is_featured').default(false).notNull(),
  imageUrl: text('image_url'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
}, (table) => [
  index('vetkind_products_category_idx').on(table.categoryId),
  index('vetkind_products_status_idx').on(table.status),
  uniqueIndex('vetkind_products_sku_idx').on(table.sku),
]);

/**
 * VetKind Animal Health India - Authorized Dealers & Distributors
 */
export const vetkindDealers = pgTable('vetkind_dealers', {
  id: uuid('id').defaultRandom().primaryKey(),
  businessName: text('business_name').notNull(),
  dealerCode: text('dealer_code').notNull().unique(),
  contactPerson: text('contact_person').notNull(),
  mobile: text('mobile').notNull(),
  email: text('email'),
  state: text('state').notNull(),
  district: text('district').notNull(),
  address: text('address'),
  pincode: text('pincode'),
  gstNumber: text('gst_number'),
  drugLicenseNo: text('drug_license_no'),
  territoryCovered: text('territory_covered').notNull(),
  verificationStatus: text('verification_status').default('Pending').notNull(), // 'Pending', 'Verified', 'Active', 'Suspended'
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
}, (table) => [
  index('vetkind_dealers_state_idx').on(table.state),
  index('vetkind_dealers_status_idx').on(table.verificationStatus),
]);

/**
 * VetKind Animal Health India - Clinical & Commercial Inquiries
 * Handles inquiries from veterinarians, dairy cooperatives, commercial farms, and prospective dealers.
 */
export const vetkindInquiries = pgTable('vetkind_inquiries', {
  id: uuid('id').defaultRandom().primaryKey(),
  productId: uuid('product_id').references(() => vetkindProducts.id),
  inquiryType: text('inquiry_type').notNull(), // 'Dealer Application', 'Farmer Product Enquiry', 'Veterinary Advisory', 'Bulk Dairy Order'
  name: text('name').notNull(),
  mobile: text('mobile').notNull(),
  email: text('email'),
  city: text('city').notNull(),
  state: text('state').notNull(),
  dairyHerdSize: text('dairy_herd_size'), // e.g. "1-10 Animals", "11-30 Animals", "30+ Commercial Dairy"
  message: text('message').notNull(),
  status: text('status').default('New').notNull(), // 'New', 'Contacted', 'In Progress', 'Resolved'
  assignedTo: uuid('assigned_to').references(() => users.id),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  resolvedAt: timestamp('resolved_at'),
}, (table) => [
  index('vetkind_inquiries_type_idx').on(table.inquiryType),
  index('vetkind_inquiries_status_idx').on(table.status),
  index('vetkind_inquiries_created_idx').on(table.createdAt),
]);
