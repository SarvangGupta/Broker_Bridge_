import { z } from 'zod';

export const generateFinalDealSnapshotSchema = z.object({
  requestId: z.string().min(1, 'Request ID / Quotation ID is required'),
  requirementId: z.string().min(1, 'Requirement ID is required'),
  sellerAvailabilityId: z.string().optional().nullable(),
  lotId: z.string().optional().nullable(),
  lotNumber: z.string().optional().nullable(),
  commodityName: z.string().min(1, 'Commodity name is required'),
  gradeName: z.string().optional().nullable(),

  // Commercials
  quantity: z.preprocess(
    (val) => (val === '' || val === null || val === undefined || isNaN(Number(val)) ? undefined : Number(val)),
    z.number({ invalid_type_error: 'Quantity must be a valid number' }).positive('Quantity must be greater than 0')
  ),
  baseRate: z.preprocess(
    (val) => (val === '' || val === null || val === undefined || isNaN(Number(val)) ? undefined : Number(val)),
    z.number({ invalid_type_error: 'Base rate must be a valid number' }).positive('Base rate must be greater than 0')
  ),
  deliveryDate: z.string().min(1, 'Delivery date is required'),
  unitSymbol: z.string().default('MT'),

  // Commission Strategy
  buyerMarkup: z.preprocess(
    (val) => (val === '' || val === null || val === undefined || isNaN(Number(val)) ? 0 : Number(val)),
    z.number({ invalid_type_error: 'Buyer markup must be a valid number' }).min(0, 'Buyer markup cannot be negative')
  ),
  sellerDeduction: z.preprocess(
    (val) => (val === '' || val === null || val === undefined || isNaN(Number(val)) ? 0 : Number(val)),
    z.number({ invalid_type_error: 'Seller deduction must be a valid number' }).min(0, 'Seller deduction cannot be negative')
  ),

  // Logistics
  deliveryTerms: z.string().optional().nullable(),
  deliveryLocation: z.string().optional().nullable(),
  packagingType: z.string().optional().nullable(),

  // Financials
  paymentTerms: z.string().optional().nullable(),
  specialConditions: z.string().max(1000, 'Special conditions cannot exceed 1000 characters').optional().nullable(),

  // Optimistic Concurrency Control
  expectedVersionNumber: z.number().int().positive().optional().nullable(),
});

export type GenerateFinalDealSnapshotPayload = z.infer<typeof generateFinalDealSnapshotSchema>;
