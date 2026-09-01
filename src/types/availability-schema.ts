import { z } from "zod";

export const availabilityBaseSchema = z.object({
  commodity_id: z.string().min(1, "Commodity is required"),
  grade_id: z.string().min(1, "Grade is required"),
  lot_number: z.string().optional().nullable(),
  total_quantity: z.number().positive("Total quantity must be positive").min(1, "Minimum quantity is 1"),
  minimum_order_quantity: z.number().positive().optional(),
  unit_id: z.string().min(1, "Unit is required"),
  asking_price: z.number().positive("Asking price must be positive"),
  confidential_minimum_price: z.number().positive().optional(),
  state_id: z.string().min(1, "State is required"),
  district_id: z.string().min(1, "District is required"),
  city_id: z.string().min(1, "City is required"),
  warehouse_name: z.string().optional(),
  available_from: z.coerce.date().default(() => new Date()),
  valid_until: z.coerce.date(),
  visibility: z.enum(['global', 'restricted']).default('global'),
  broker_id: z.string().uuid().optional().nullable().or(z.literal('')),
  id: z.string().uuid().optional(),
  version: z.number().int().optional(),
});

export const availabilitySchema = availabilityBaseSchema.superRefine((data, ctx) => {
  if (data.visibility === 'restricted' && !data.broker_id) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "Preferred Broker is required for Private Network visibility",
      path: ["broker_id"],
    });
  }
  if (data.minimum_order_quantity && data.minimum_order_quantity > data.total_quantity) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "Minimum order quantity must be <= total quantity",
      path: ["minimum_order_quantity"],
    });
  }
  if (data.confidential_minimum_price && data.confidential_minimum_price > data.asking_price) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "Confidential minimum price must be <= asking price",
      path: ["confidential_minimum_price"],
    });
  }
  if (data.valid_until <= data.available_from) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "Valid until date must be strictly after available from date",
      path: ["valid_until"],
    });
  }
});

export type AvailabilitySchema = z.infer<typeof availabilityBaseSchema>;

export const AVAILABILITY_STATUSES = [
  'Draft', 
  'Pending Approval', 
  'Active', 
  'Reserved', 
  'Sold', 
  'Expired', 
  'Deactivated'
] as const;

export type AvailabilityStatus = typeof AVAILABILITY_STATUSES[number];

export const VALID_STATUS_TRANSITIONS: Record<AvailabilityStatus, AvailabilityStatus[]> = {
  'Draft': ['Pending Approval', 'Deactivated'],
  'Pending Approval': ['Active', 'Deactivated'],
  'Active': ['Reserved', 'Sold', 'Expired', 'Deactivated'],
  'Reserved': ['Sold', 'Active', 'Expired', 'Deactivated'],
  'Sold': [],
  'Expired': ['Deactivated'],
  'Deactivated': [],
};
