import { z } from "zod"
import { 
  requirementWizardSchema, 
  requirementWizardBaseSchema, 
  RequirementWizardFormValues 
} from "@/src/lib/validations/requirement-schema"

export { 
  requirementWizardSchema, 
  requirementWizardBaseSchema, 
  type RequirementWizardFormValues 
}

export const requirementBaseSchema = z.object({
  commodity_id: z.string().min(1, { message: "Commodity is required" }),
  grade_id: z.string().min(1, { message: "Grade is required" }),
  quantity: z.number().positive({ message: "Quantity must be positive" }).min(1, { message: "Minimum quantity is 1" }),
  unit_id: z.string().min(1, { message: "Unit is required" }),
  target_price: z.number().positive({ message: "Target price must be positive" }),
  delivery_terms_id: z.string().optional().default("EXW"),
  target_date: z.coerce.date().optional().default(() => new Date(Date.now() + 14 * 86400000)),
  visibility: z.enum(['global', 'restricted']).default('global'),
  broker_id: z.string().optional().or(z.literal('')),
  // Extended fields for Sprint 33 wizard backward-compatibility
  delivery_state_id: z.string().optional(),
  delivery_district_id: z.string().optional(),
  delivery_city_id: z.string().optional(),
  delivery_window_start: z.coerce.date().optional(),
  delivery_window_end: z.coerce.date().optional(),
  payment_terms: z.string().optional(),
  packaging_type: z.string().optional(),
  freight_terms: z.string().optional(),
  allow_partial_fulfillment: z.boolean().optional().default(true),
})

export const requirementSchema = requirementBaseSchema.superRefine((data, ctx) => {
  if (data.visibility === 'restricted' && !data.broker_id) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "Preferred Broker is required for Private Network visibility",
      path: ["broker_id"],
    })
  }
})

export type RequirementFormValues = z.infer<typeof requirementBaseSchema>
