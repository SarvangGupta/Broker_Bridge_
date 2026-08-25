import { z } from "zod";

export const companyOnboardingSchema = z.object({
  name: z.string().min(2, { message: "Company name must be at least 2 characters." }),
  gst: z.string().optional().refine((val) => {
    if (!val) return true; // It's optional
    return /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/.test(val);
  }, { message: "Invalid GST Number format." }),
  business_type_id: z.string().min(1, { message: "Business type is required." }),
  state_id: z.string().min(1, { message: "State is required." }),
  district_id: z.string().min(1, { message: "District is required." }),
  mobile: z.string().min(10, { message: "Valid 10-digit mobile number required" }),
});

export type CompanyOnboardingFormValues = z.infer<typeof companyOnboardingSchema>;
