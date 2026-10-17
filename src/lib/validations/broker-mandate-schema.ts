import { z } from 'zod';

export const createRequirementSchema = z.object({
  companyId: z.string().uuid('Valid buyer company is required'),
  commodityId: z.string().uuid('Valid commodity is required'),
  gradeId: z.string().uuid('Valid quality grade is required'),
  quantity: z.number().positive('Quantity must be greater than zero'),
  unitId: z.string().uuid('Valid measurement unit is required'),
  targetPrice: z.number().positive('Target price must be greater than zero'),
  deliveryTermsId: z.string().min(1, 'Delivery terms are required'),
  targetDate: z.string().refine((d) => !isNaN(Date.parse(d)), 'Valid delivery date is required'),
  notes: z.string().optional(),
});

export type CreateRequirementInput = z.infer<typeof createRequirementSchema>;

export const updateRequirementSchema = createRequirementSchema.extend({
  status: z.enum([
    'Open',
    'Matching',
    'Partially Allocated',
    'Fully Allocated',
    'Fulfilled',
    'Expired',
    'Cancelled',
  ]).optional(),
});

export type UpdateRequirementInput = z.infer<typeof updateRequirementSchema>;

export const createOfferSchema = z.object({
  companyId: z.string().uuid('Valid seller company is required'),
  commodityId: z.string().uuid('Valid commodity is required'),
  gradeId: z.string().uuid('Valid quality grade is required'),
  quantity: z.number().positive('Offered quantity must be greater than zero'),
  unitId: z.string().uuid('Valid measurement unit is required'),
  askingPrice: z.number().positive('Asking price must be greater than zero'),
  confidentialMinimumPrice: z.number().positive().optional().nullable(),
  stateId: z.string().uuid('Valid state location is required'),
  districtId: z.string().uuid('Valid district location is required'),
  availableFrom: z.string().refine((d) => !isNaN(Date.parse(d)), 'Valid available-from date is required'),
  validUntil: z.string().refine((d) => !isNaN(Date.parse(d)), 'Valid expiration date is required'),
  loadingStatus: z.enum([
    'Not Ready',
    'Ready to Load',
    'Loading in Progress',
    'Delayed',
    'Blocked',
  ]).default('Not Ready'),
  loadingRemarks: z.string().optional(),
});

export type CreateOfferInput = z.infer<typeof createOfferSchema>;

export const updateOfferSchema = createOfferSchema.extend({
  expectedVersion: z.number().int().positive().optional(),
  status: z.enum([
    'Open',
    'Partially Available',
    'Reserved',
    'Unavailable',
    'Expired',
    'Cancelled',
  ]).optional(),
});

export type UpdateOfferInput = z.infer<typeof updateOfferSchema>;
