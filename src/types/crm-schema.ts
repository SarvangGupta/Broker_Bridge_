import { z } from "zod";

export const activitySchema = z.object({
  contact_id: z.string().uuid("Invalid contact ID"),
  type: z.enum(['Call', 'Meeting', 'Note', 'Task']),
  notes: z.string().min(2, "Notes must be at least 2 characters"),
  follow_up_date: z.coerce.date().optional(),
});

export const taskSchema = z.object({
  contact_id: z.string().uuid("Invalid contact ID"),
  title: z.string().min(2, "Task description must be at least 2 characters"),
  due_date: z.coerce.date(),
  priority: z.enum(['High', 'Medium', 'Low']),
});
