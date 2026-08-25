import { z } from "zod";

export const supportTicketSchema = z.object({
  issue_type: z.string().min(1, "Please select an issue type"),
  description: z.string().min(10, "Description must be at least 10 characters long"),
});

export type SupportTicketInput = z.infer<typeof supportTicketSchema>;
