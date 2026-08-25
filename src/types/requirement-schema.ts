import { z } from "zod";

export const requirementBaseSchema = z.object({
  commodity_id: z.string().min(1, { message: "Commodity is required" }),
  grade_id: z.string().min(1, { message: "Grade is required" }),
  quantity: z.number().positive({ message: "Quantity must be positive" }).min(1, { message: "Minimum quantity is 1" }),
  unit_id: z.string().min(1, { message: "Unit is required" }),
  target_price: z.number().positive({ message: "Target price must be positive" }),
  delivery_terms_id: z.string().min(1, { message: "Delivery terms are required" }),
  target_date: z.coerce.date().refine((date) => date > new Date(), { message: "Target date must be in the future" }),
  visibility: z.enum(['global', 'restricted']).default('global'),
  broker_id: z.string().uuid().optional().nullable().or(z.literal('')),
});

export const requirementSchema = requirementBaseSchema.superRefine((data, ctx) => {
  if (data.visibility === 'restricted' && !data.broker_id) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "Preferred Broker is required for Private Network visibility",
      path: ["broker_id"],
    });
  }
});

export type RequirementFormValues = z.infer<typeof requirementBaseSchema>;
