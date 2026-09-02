import { z } from "zod";

export const availabilityBaseSchema = z.object({
  commodity_id: z.string().min(1, "Commodity is required"),
  grade_id: z.string().optional().nullable().or(z.literal('')),
  lot_number: z.string().optional().nullable().or(z.literal('')),
  total_quantity: z.preprocess(
    (val) => (val === "" || val === null || val === undefined ? 0 : Number(val)),
    z.number({ required_error: "Total quantity is required" }).positive("Total quantity must be positive")
  ),
  minimum_order_quantity: z.preprocess(
    (val) => (val === "" || val === null || val === undefined || isNaN(Number(val)) ? undefined : Number(val)),
    z.number().positive().optional()
  ),
  unit_id: z.string().min(1, "Unit of measurement is required"),
  asking_price: z.preprocess(
    (val) => (val === "" || val === null || val === undefined ? 0 : Number(val)),
    z.number({ required_error: "Asking price is required" }).positive("Asking price must be positive")
  ),
  confidential_minimum_price: z.preprocess(
    (val) => (val === "" || val === null || val === undefined || isNaN(Number(val)) ? undefined : Number(val)),
    z.number().positive().optional()
  ),
  state_id: z.string().min(1, "State is required"),
  district_id: z.string().min(1, "District is required"),
  city_id: z.string().optional().nullable().or(z.literal('')),
  warehouse_name: z.string().optional().nullable().or(z.literal('')),
  available_from: z.coerce.date().default(() => new Date()),
  valid_until: z.coerce.date({ required_error: "Valid until date is required", invalid_type_error: "Valid until date is required" }),
  visibility: z.enum(['global', 'restricted']).default('global'),
  broker_id: z.preprocess(
    (val) => (val === "none" || val === "" || val === null || val === undefined ? null : String(val)),
    z.string().uuid().optional().nullable()
  ),
  id: z.preprocess(
    (val) => (val === "" || val === null || val === undefined ? undefined : String(val)),
    z.string().uuid().optional().nullable()
  ),
  version: z.preprocess(
    (val) => (val === "" || val === null || val === undefined || isNaN(Number(val)) ? 1 : Number(val)),
    z.number().int().optional()
  ),
});

export const availabilitySchema = availabilityBaseSchema.superRefine((data, ctx) => {
  if (data.visibility === 'restricted' && (!data.broker_id || data.broker_id === 'none')) {
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
  if (data.valid_until && data.available_from && new Date(data.valid_until) <= new Date(data.available_from)) {
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
  'Open',
  'Reserved', 
  'Sold', 
  'Expired', 
  'Deactivated',
  'Cancelled'
] as const;

export type AvailabilityStatus = typeof AVAILABILITY_STATUSES[number];

export const VALID_STATUS_TRANSITIONS: Record<AvailabilityStatus, AvailabilityStatus[]> = {
  'Draft': ['Pending Approval', 'Deactivated', 'Cancelled'],
  'Pending Approval': ['Active', 'Deactivated', 'Cancelled'],
  'Active': ['Reserved', 'Sold', 'Expired', 'Deactivated', 'Cancelled'],
  'Open': ['Reserved', 'Sold', 'Expired', 'Deactivated', 'Cancelled'],
  'Reserved': ['Sold', 'Active', 'Expired', 'Deactivated', 'Cancelled'],
  'Sold': [],
  'Expired': ['Deactivated', 'Cancelled'],
  'Deactivated': [],
  'Cancelled': [],
};
