import { z } from "zod";

export const qualityEntrySchema = z.object({
  parameter_id: z.string().uuid(),
  parameter_name: z.string(),
  value: z.string(),
  min_value: z.number().nullable().optional(),
  max_value: z.number().nullable().optional(),
  type: z.string(), // 'numeric' | 'boolean' | 'text'
  is_required: z.boolean(),
  unit: z.string().nullable().optional(),
});

export type QualityEntry = z.infer<typeof qualityEntrySchema>;

export const saveQualityValuesSchema = z.object({
  availability_id: z.string().uuid(),
  values: z.array(
    z.object({
      parameter_id: z.string().uuid(),
      value: z.string(),
    })
  ),
});

export type SaveQualityValuesInput = z.infer<typeof saveQualityValuesSchema>;

export const masterQualityParameterFormSchema = z.object({
  id: z.string().uuid().optional(),
  commodity_id: z.string().uuid("Commodity is required"),
  name: z.string().min(1, "Parameter name is required"),
  type: z.enum(["numeric", "boolean", "text"]).default("numeric"),
  unit: z.string().optional().nullable(),
  min_value: z.coerce.number().nullable().optional(),
  max_value: z.coerce.number().nullable().optional(),
  target_value: z.coerce.number().nullable().optional(),
  is_required: z.boolean().default(false),
});

export type MasterQualityParameterFormValues = z.infer<typeof masterQualityParameterFormSchema>;

export interface QualityTemplateParameter {
  id: string;
  commodityId: string;
  name: string;
  type: string; // 'numeric' | 'boolean' | 'text'
  unit?: string | null;
  minValue?: string | number | null;
  maxValue?: string | number | null;
  targetValue?: string | number | null;
  isRequired: boolean;
  isActive: boolean;
}

export interface QualityValidationResult {
  isValid: boolean;
  errors: Record<string, string>; // Keyed by parameter_id
}

/**
 * Validates entered quality values against dynamic template specifications.
 * Supports both Record<parameterId, value> and array format.
 *
 * @param entries Map of parameterId -> value string or array of entries
 * @param templateParameters List of active parameter templates for the commodity
 */
export function validateQualityEntries(
  entries: Record<string, string> | Array<{ parameter_id: string; value: string }>,
  templateParameters: QualityTemplateParameter[]
): QualityValidationResult {
  const errors: Record<string, string> = {};

  const entriesMap: Record<string, string> = Array.isArray(entries)
    ? entries.reduce((acc, curr) => {
        acc[curr.parameter_id] = curr.value;
        return acc;
      }, {} as Record<string, string>)
    : entries;

  for (const param of templateParameters) {
    if (!param.isActive) continue;

    const rawVal = entriesMap[param.id];
    const val = rawVal !== undefined && rawVal !== null ? String(rawVal).trim() : '';

    // 1. Validate Required Fields
    if (param.isRequired && val === '') {
      errors[param.id] = `${param.name} is required.`;
      continue;
    }

    // If optional and blank, skip further validation
    if (val === '') {
      continue;
    }

    // 2. Type-specific validation
    if (param.type === 'numeric') {
      const num = Number(val);
      if (isNaN(num)) {
        errors[param.id] = `${param.name} must be a valid number.`;
        continue;
      }

      const unitLabel = param.unit ? ` ${param.unit}` : '';

      if (param.minValue !== null && param.minValue !== undefined) {
        const min = Number(param.minValue);
        if (!isNaN(min) && num < min) {
          errors[param.id] = `${param.name} cannot be less than ${min}${unitLabel}.`;
          continue;
        }
      }

      if (param.maxValue !== null && param.maxValue !== undefined) {
        const max = Number(param.maxValue);
        if (!isNaN(max) && num > max) {
          errors[param.id] = `${param.name} cannot exceed ${max}${unitLabel}.`;
          continue;
        }
      }
    } else if (param.type === 'boolean') {
      const lower = val.toLowerCase();
      if (!['true', 'false', 'yes', 'no', '1', '0'].includes(lower)) {
        errors[param.id] = `${param.name} must be Yes or No.`;
        continue;
      }
    }
  }

  return {
    isValid: Object.keys(errors).length === 0,
    errors,
  };
}
