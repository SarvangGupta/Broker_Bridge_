import { z } from 'zod';

export const contactRoleEnum = z.enum(['buyer', 'seller']);
export type ContactRole = z.infer<typeof contactRoleEnum>;

export const createContactSchema = z.object({
  name: z.string().trim().min(2, 'Contact person name must be at least 2 characters'),
  companyName: z.string().trim().min(2, 'Company name must be at least 2 characters'),
  mobile: z.string().trim().min(10, 'Valid 10-digit mobile number is required'),
  whatsapp: z.string().trim().optional(),
  email: z.string().trim().email('Invalid email address').optional().or(z.literal('')),
  role: contactRoleEnum,
  city: z.string().trim().optional(),
  state: z.string().trim().optional(),
  notes: z.string().trim().optional(),
});

export type CreateContactInput = z.infer<typeof createContactSchema>;

export const updateContactSchema = createContactSchema.extend({
  status: z.boolean().optional(),
});

export type UpdateContactInput = z.infer<typeof updateContactSchema>;
