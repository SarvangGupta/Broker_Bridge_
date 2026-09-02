import { z } from "zod";

export const LAB_TEST_STATUSES = [
  'Sample Pending',
  'Testing In Progress',
  'Report Uploaded',
  'Under Review',
  'Verified',
  'Correction Required',
  'Rejected',
  'Expired',
] as const;

export type LabTestStatus = typeof LAB_TEST_STATUSES[number];

export const labTestResultItemSchema = z.object({
  parameter_id: z.string().uuid("Valid parameter ID is required"),
  measured_value: z.string().min(1, "Measured value is required"),
});

export const labTestFormSchema = z
  .object({
    availability_id: z.string().uuid("Availability ID is required"),
    laboratory_name: z.string().min(2, "Laboratory name must be at least 2 characters"),
    laboratory_location: z.string().optional().nullable(),
    sample_id: z.string().optional().nullable(),
    sample_date: z.coerce.date().optional().nullable(),
    test_date: z.coerce.date({ required_error: "Test date is required" }),
    report_number: z.string().min(2, "Report number must be at least 2 characters"),
    report_date: z.coerce.date({ required_error: "Report date is required" }),
    valid_until: z.coerce.date().optional().nullable(),
    file_url: z.string().optional().nullable(),
    results: z.array(labTestResultItemSchema).min(1, "At least one measured result is required"),
  })
  .superRefine((data, ctx) => {
    const now = new Date();
    // Allow small 24hr buffer for timezone differences
    const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    if (data.test_date > tomorrow) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Test date cannot be in the future",
        path: ["test_date"],
      });
    }

    if (data.report_date < data.test_date) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Report date must be on or after test date",
        path: ["report_date"],
      });
    }

    if (data.valid_until && data.valid_until <= data.report_date) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Validity date must be after report date",
        path: ["valid_until"],
      });
    }

    if (data.sample_date && data.sample_date > data.test_date) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Sample date must be on or before test date",
        path: ["sample_date"],
      });
    }
  });

export type LabTestFormInput = z.infer<typeof labTestFormSchema>;

/**
 * Checks whether a measured value conforms to master parameter min/max range boundaries.
 */
export function checkIsWithinBounds(
  measuredValue: string,
  param: {
    minValue?: string | number | null;
    maxValue?: string | number | null;
    type?: string | null;
  }
): boolean {
  if (!measuredValue || measuredValue.trim() === '') return true;

  if (param.type === 'numeric' || (!param.type && !isNaN(Number(measuredValue)))) {
    const num = Number(measuredValue);
    if (isNaN(num)) return false;

    if (param.minValue !== null && param.minValue !== undefined) {
      const min = Number(param.minValue);
      if (!isNaN(min) && num < min) return false;
    }

    if (param.maxValue !== null && param.maxValue !== undefined) {
      const max = Number(param.maxValue);
      if (!isNaN(max) && num > max) return false;
    }
  }

  return true;
}

export type LabFreshnessStatus = 'Valid' | 'Expiring Soon' | 'Expired';

/**
 * Calculates mathematical freshness status for a lab report.
 * - 'Expired' if past validUntil or past 30 days of testDate.
 * - 'Expiring Soon' if within 7 days of expiry.
 * - 'Valid' otherwise.
 */
export function computeLabFreshness(
  testDate: Date | string,
  validUntil?: Date | string | null
): LabFreshnessStatus {
  const now = new Date().getTime();

  if (validUntil) {
    const expiryTime = new Date(validUntil).getTime();
    if (isNaN(expiryTime)) return 'Valid';

    if (expiryTime <= now) {
      return 'Expired';
    }

    const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
    if (expiryTime - now <= sevenDaysMs) {
      return 'Expiring Soon';
    }

    return 'Valid';
  }

  const testTime = new Date(testDate).getTime();
  if (isNaN(testTime)) return 'Valid';

  const thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;
  const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
  const defaultExpiryTime = testTime + thirtyDaysMs;

  if (now >= defaultExpiryTime) {
    return 'Expired';
  }

  if (defaultExpiryTime - now <= sevenDaysMs) {
    return 'Expiring Soon';
  }

  return 'Valid';
}
