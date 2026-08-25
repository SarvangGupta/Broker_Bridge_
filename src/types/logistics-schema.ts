import { z } from "zod";

export const dispatchSchema = z.object({
  deal_id: z.string().uuid("Invalid deal ID"),
  vehicle_type_id: z.string().uuid("Invalid vehicle type ID"),
  vehicle_type_name: z.string().optional(),
  other_vehicle_type: z.string().optional(),
  vehicle_number: z.string().regex(/^[A-Z]{2}[0-9]{2}[A-Z]{1,2}[0-9]{4}$/, "Must be a valid Indian vehicle number (e.g., RJ14GC5511)"),
  driver_name: z.string().min(2, "Driver name is required"),
  driver_mobile: z.string().regex(/^[6-9]\d{9}$/, "Must be a valid 10-digit Indian mobile number"),
  dispatch_date: z.coerce.date(),
  expected_delivery_date: z.coerce.date()
}).superRefine((data, ctx) => {
  if (data.vehicle_type_name === 'Other Commercial Vehicle') {
    if (!data.other_vehicle_type || data.other_vehicle_type.length < 2) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['other_vehicle_type'],
        message: 'Please specify the vehicle type',
      });
    }
  }
});

export const invoiceSchema = z.object({
  deal_id: z.string().uuid("Invalid deal ID"),
  invoice_no: z.string().min(3, "Invoice number is required"),
  amount: z.number().positive("Amount must be greater than 0"),
  file_url: z.string().min(1, "File upload is required")
});

export type DispatchData = z.infer<typeof dispatchSchema>;
export type InvoiceData = z.infer<typeof invoiceSchema>;
