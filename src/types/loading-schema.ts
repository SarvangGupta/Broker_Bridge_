import { z } from "zod";

/**
 * Allowed operational loading statuses for Seller Inventory lots.
 */
export const LOADING_STATUSES = [
  'Not Ready',
  'Ready',
  'Scheduled',
  'Loading',
  'Loaded',
  'Delayed',
  'Blocked',
] as const;

export type LoadingStatus = typeof LOADING_STATUSES[number];

/**
 * Zod validation schema for updating lot loading readiness (Sprint 16.1).
 * Features sanitizing preprocessing for empty strings, nulls, and numeric coercion.
 */
export const loadingReadinessSchema = z
  .object({
    loading_status: z.enum(LOADING_STATUSES, {
      required_error: "Loading status is required",
      invalid_type_error: "Invalid loading status",
    }).default('Not Ready'),
    loading_duration: z.preprocess(
      (val) => (val === "" || val === null || val === undefined || isNaN(Number(val)) ? undefined : Number(val)),
      z.number({ invalid_type_error: "Loading duration must be a number" })
        .int("Loading duration must be a whole number (e.g. 1, 2, 3 days)")
        .positive("Loading duration must be a positive number")
        .optional()
        .nullable()
    ),
    loading_start_date: z.preprocess(
      (val) => (val === "" || val === null || val === undefined ? undefined : val),
      z.coerce.date({ invalid_type_error: "Invalid start date" }).optional().nullable()
    ),
    loading_capacity: z.preprocess(
      (val) => (val === "" || val === null || val === undefined || isNaN(Number(val)) ? undefined : Number(val)),
      z.number({ invalid_type_error: "Loading capacity must be a number" })
        .positive("Loading capacity must be a positive number")
        .optional()
        .nullable()
    ),
    loading_remarks: z.preprocess(
      (val) => (val === "" || val === null || val === undefined ? undefined : String(val).trim()),
      z.string().optional().nullable()
    ),
  })
  .superRefine((data, ctx) => {
    // Refinement: If loading_status is 'Delayed' or 'Blocked', loading_remarks is required.
    if (data.loading_status === 'Delayed' || data.loading_status === 'Blocked') {
      if (!data.loading_remarks || data.loading_remarks.trim() === '') {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: `Loading remarks are required when status is '${data.loading_status}' to explain constraints or delay reasons.`,
          path: ["loading_remarks"],
        });
      }
    }
  });

export type LoadingReadinessInput = z.infer<typeof loadingReadinessSchema>;
export type LoadingReadinessPayload = LoadingReadinessInput;

/**
 * UI / Operational metadata for Loading Status display (useful for badges and filters).
 */
export const LOADING_STATUS_CONFIG: Record<
  LoadingStatus,
  { label: string; variant: 'default' | 'secondary' | 'destructive' | 'outline' | 'warning' | 'success'; description: string }
> = {
  'Not Ready': {
    label: 'Not Ready',
    variant: 'secondary',
    description: 'Stock is currently being aggregated or processed.',
  },
  'Ready': {
    label: 'Ready for Loading',
    variant: 'success',
    description: 'Stock is packed, weighed, and immediately available for vehicle dispatch.',
  },
  'Scheduled': {
    label: 'Scheduled',
    variant: 'outline',
    description: 'Loading has been planned for a specific target date/time.',
  },
  'Loading': {
    label: 'Loading In Progress',
    variant: 'default',
    description: 'Vehicles are currently being loaded at the warehouse/facility.',
  },
  'Loaded': {
    label: 'Loaded',
    variant: 'success',
    description: 'Vehicles are fully loaded and prepared for gate pass/dispatch.',
  },
  'Delayed': {
    label: 'Loading Delayed',
    variant: 'warning',
    description: 'Loading has encountered a temporary delay (reason documented).',
  },
  'Blocked': {
    label: 'Blocked',
    variant: 'destructive',
    description: 'Loading is halted due to warehouse, weather, or operational issues.',
  },
};
