import { z } from "zod";

export const acceptQuotationSchema = z.object({
  quotation_id: z.string().uuid(),
});

export const rejectQuotationSchema = z.object({
  quotation_id: z.string().uuid(),
  reason: z.string().min(3, "Rejection reason is mandatory"),
});

export const counterQuotationSchema = z.object({
  quotation_id: z.string().uuid(),
  counter_price: z.number().positive("Counter price must be positive"),
  counter_notes: z.string().optional(),
});
