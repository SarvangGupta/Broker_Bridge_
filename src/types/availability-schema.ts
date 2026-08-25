import { z } from "zod";

export const availabilityBaseSchema = z.object({
  commodity_id: z.string().min(1, "Commodity is required"),
  grade_id: z.string().min(1, "Grade is required"),
  quantity: z.number().positive("Quantity must be positive").min(1, "Minimum quantity is 1"),
  unit_id: z.string().min(1, "Unit is required"),
  price: z.number().positive("Price must be positive"),
  state_id: z.string().min(1, "State is required"),
  district_id: z.string().min(1, "District is required"),
  valid_until: z.coerce.date().refine((data) => data > new Date(), {
    message: "Valid until date must be in the future",
  }),
  visibility: z.enum(['global', 'restricted']).default('global'),
  broker_id: z.string().uuid().optional().nullable().or(z.literal('')),
});

export const availabilitySchema = availabilityBaseSchema.superRefine((data, ctx) => {
  if (data.visibility === 'restricted' && !data.broker_id) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "Preferred Broker is required for Private Network visibility",
      path: ["broker_id"],
    });
  }
});

export type AvailabilitySchema = z.infer<typeof availabilityBaseSchema>;
