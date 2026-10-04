import { z } from "zod"

// Step 1: What
export const step1WhatSchema = z.object({
  commodity_id: z.string().min(1, { message: "Commodity selection is required" }),
  grade_id: z.string().min(1, { message: "Grade / Quality parameter selection is required" }),
})

// Step 2: How Much
export const step2HowMuchSchema = z.object({
  quantity: z
    .number({ invalid_type_error: "Quantity must be a valid number" })
    .positive({ message: "Quantity must be greater than 0" })
    .min(1, { message: "Minimum quantity is 1" }),
  unit_id: z.string().min(1, { message: "Unit of measurement is required" }),
  target_price: z
    .number({ invalid_type_error: "Target price must be a valid number" })
    .positive({ message: "Target price must be greater than 0" }),
  allow_partial_fulfillment: z.boolean().default(true),
})

// Step 3: Where
export const step3WhereSchema = z.object({
  delivery_state_id: z.string().min(1, { message: "Delivery state is required" }),
  delivery_district_id: z.string().optional(),
  delivery_city_id: z.string().optional(),
})

// Step 4: When
export const step4WhenSchema = z
  .object({
    delivery_window_start: z.coerce.date().optional(),
    delivery_window_end: z.coerce
      .date()
      .optional()
      .refine((date) => !date || date >= new Date(new Date().setHours(0, 0, 0, 0)), {
        message: "Delivery window end date must not be in the past",
      }),
    target_date: z.coerce.date().optional(),
  })
  .refine(
    (data) => {
      if (data.delivery_window_start && data.delivery_window_end) {
        return data.delivery_window_end >= data.delivery_window_start
      }
      return true
    },
    {
      message: "Delivery window end date cannot be earlier than start date",
      path: ["delivery_window_end"],
    }
  )

// Step 5: Commercials
export const step5CommercialsSchema = z.object({
  payment_terms: z.string().min(1, { message: "Payment terms selection is required" }),
  packaging_type: z.string().min(1, { message: "Packaging type selection is required" }),
  freight_terms: z.string().min(1, { message: "Freight / Logistics terms are required" }),
  delivery_terms_id: z.string().optional(),
  visibility: z.enum(['global', 'restricted']).default('global'),
  broker_id: z.string().optional().or(z.literal('')),
})

// Combined Requirement Base Schema
export const requirementWizardBaseSchema = step1WhatSchema
  .merge(step2HowMuchSchema)
  .merge(step3WhereSchema)
  .merge(step5CommercialsSchema)
  // Step 4 includes refinement rules, so we merge standard object and refine
  .merge(
    z.object({
      delivery_window_start: z.coerce.date().optional(),
      delivery_window_end: z.coerce.date().optional(),
      target_date: z.coerce.date().optional(),
    })
  )

// Full Requirement Schema with SuperRefinement rules
export const requirementWizardSchema = requirementWizardBaseSchema.superRefine((data, ctx) => {
  if (data.visibility === 'restricted' && !data.broker_id) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "Preferred Broker is required when Private Network visibility is selected",
      path: ["broker_id"],
    })
  }
  if (data.delivery_window_start && data.delivery_window_end && data.delivery_window_end < data.delivery_window_start) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "Delivery window end date cannot be earlier than start date",
      path: ["delivery_window_end"],
    })
  }
})

export type RequirementWizardFormValues = z.infer<typeof requirementWizardSchema>
