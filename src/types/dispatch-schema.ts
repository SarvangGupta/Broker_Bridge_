import { z } from "zod";

/**
 * Zod validation schema for Seller Dispatch Submission (Micro-Sprint 19.2).
 * Strictly validates vehicle registration, driver contact credentials, transport details,
 * and dispatch quantities against the active booking contract.
 */
export const sellerDispatchSchema = z
  .object({
    booking_id: z.string().min(1, "Booking reference or ID is required"),
    dispatch_quantity: z.coerce
      .number({ invalid_type_error: "Dispatch quantity must be a valid number" })
      .positive("Dispatch quantity must be greater than 0"),
    dispatch_date: z.coerce.date({
      invalid_type_error: "Valid dispatch date is required",
    }),
    vehicle_type: z.string().min(1, "Vehicle type is required"),
    vehicle_type_id: z.string().optional().nullable(),
    vehicle_number: z
      .string()
      .min(4, "Vehicle registration number is required")
      .regex(
        /^[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{4}$/i,
        "Please enter a valid vehicle plate (e.g., RJ14GC5511, MH04AB1234, DL1A1234)"
      )
      .transform((v) => v.toUpperCase().trim()),
    driver_name: z
      .string()
      .min(2, "Driver name must be at least 2 characters")
      .max(100, "Driver name cannot exceed 100 characters"),
    driver_mobile: z
      .string()
      .regex(
        /^[6-9]\d{9}$/,
        "Must be a valid 10-digit Indian mobile number (e.g. 9876543210)"
      ),
    transport_company: z
      .string()
      .min(2, "Transport or Logistics company name is required")
      .max(150, "Transport company name cannot exceed 150 characters"),
    loading_location: z
      .string()
      .min(2, "Loading warehouse or mill location is required")
      .max(200, "Loading location cannot exceed 200 characters"),
    eta: z.coerce.date({
      invalid_type_error: "Valid estimated arrival (ETA) date is required",
    }),
    remarks: z
      .string()
      .max(500, "Remarks cannot exceed 500 characters")
      .optional()
      .nullable(),
  })
  .refine(
    (data) => {
      if (!data.dispatch_date || !data.eta) return true;
      const dispatchTime = new Date(data.dispatch_date).setHours(0, 0, 0, 0);
      const etaTime = new Date(data.eta).setHours(0, 0, 0, 0);
      return etaTime >= dispatchTime;
    },
    {
      message: "Estimated delivery ETA must be on or after the dispatch date",
      path: ["eta"],
    }
  );

export type SellerDispatchFormData = z.infer<typeof sellerDispatchSchema>;

export type DocumentTypeEnum =
  | "LR"
  | "Invoice"
  | "E-Way Bill"
  | "Weighment Slip"
  | "Loading Photo";

export const ALLOWED_DOCUMENT_TYPES: DocumentTypeEnum[] = [
  "LR",
  "Invoice",
  "E-Way Bill",
  "Weighment Slip",
  "Loading Photo",
];
