import { z } from "zod";

export const paymentSchema = z.object({
  deal_id: z.string().uuid("Invalid deal ID"),
  amount: z.coerce.number().positive("Amount must be positive"),
  reference_number: z.string().min(3, "Reference number must be at least 3 characters"),
});

export const fileDisputeSchema = z.object({
  deal_id: z.string().uuid("Invalid deal ID"),
  reason: z.string().min(5, "Reason must be at least 5 characters"),
  description: z.string().optional(),
});

export const resolveDisputeSchema = z.object({
  dispute_id: z.string().uuid("Invalid dispute ID"),
  deal_id: z.string().uuid("Invalid deal ID"),
  resolution_notes: z.string().min(1, "Resolution notes are required"),
  final_deal_status: z.enum(['Closed', 'Cancelled']),
});
