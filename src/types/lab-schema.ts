import { z } from "zod";

export const LAB_TEST_STATUSES = [
  'Not Required',
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
  measured_value: z.string().optional().default(""),
});

export const labTestFormSchema = z
  .object({
    availability_id: z.string().uuid("Availability ID is required"),
    is_lab_required: z.boolean().default(true),
    laboratory_name: z.string().optional().nullable(),
    laboratory_location: z.string().optional().nullable(),
    sample_id: z.string().optional().nullable(),
    sample_date: z.coerce.date().optional().nullable(),
    test_date: z.coerce.date().optional().nullable(),
    report_number: z.string().optional().nullable(),
    report_date: z.coerce.date().optional().nullable(),
    valid_until: z.coerce.date().optional().nullable(),
    file_url: z.string().optional().nullable(),
    results: z.array(labTestResultItemSchema).optional().default([]),
  })
  .superRefine((data, ctx) => {
    // If lab test is explicitly NOT required, bypass all field validations
    if (data.is_lab_required === false) {
      return;
    }

    // When lab test IS required:
    if (!data.laboratory_name || data.laboratory_name.trim().length < 2) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Laboratory name must be at least 2 characters",
        path: ["laboratory_name"],
      });
    }

    if (!data.report_number || data.report_number.trim().length < 2) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Report number must be at least 2 characters",
        path: ["report_number"],
      });
    }

    if (!data.test_date) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Test date is required",
        path: ["test_date"],
      });
    }

    if (!data.report_date) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Report date is required",
        path: ["report_date"],
      });
    }

    const hasAtLeastOneResult = Array.isArray(data.results) && data.results.some((r) => r.measured_value && r.measured_value.trim() !== "");
    if (!hasAtLeastOneResult && data.results && data.results.length > 0) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "At least one measured result is required",
        path: ["results"],
      });
    }

    if (data.test_date && data.report_date) {
      const test = new Date(data.test_date);
      const report = new Date(data.report_date);
      if (!isNaN(test.getTime()) && !isNaN(report.getTime())) {
        test.setHours(0, 0, 0, 0);
        report.setHours(0, 0, 0, 0);
        if (report.getTime() < test.getTime()) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: "Report date cannot be before test date",
            path: ["report_date"],
          });
        }
      }
    }

    if (data.valid_until && data.report_date) {
      const validUntil = new Date(data.valid_until);
      const report = new Date(data.report_date);
      if (!isNaN(validUntil.getTime()) && !isNaN(report.getTime())) {
        validUntil.setHours(0, 0, 0, 0);
        report.setHours(0, 0, 0, 0);
        if (validUntil.getTime() <= report.getTime()) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: "Expiry date must be after report date",
            path: ["valid_until"],
          });
        }
      }
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
