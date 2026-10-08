import { z } from 'zod';

export interface MasterQualityParameter {
  id: string;
  name: string;
  type?: string;
  unit?: string | null;
  min_value?: number | string | null;
  max_value?: number | string | null;
  target_value?: number | string | null;
  is_mandatory?: boolean;
  grade_baseline?: string | number | null;
  minValue?: number | string | null;
  maxValue?: number | string | null;
  targetValue?: number | string | null;
  isRequired?: boolean;
  gradeBaseline?: string | number | null;
}

export interface SingleQualityValidationResult {
  isValid: boolean;
  error?: string;
}

export interface AllQualityValidationResult {
  isValid: boolean;
  errors: Record<string, string>;
}

export interface QualitySpecInput {
  parameterId?: string;
  parameter_id?: string;
  targetValue?: number | string;
  target_value?: number | string;
  tolerance?: number | string | null;
}

/**
 * Extracts and sanitizes numeric min/max bounds from a master quality parameter
 * supporting both camelCase and snake_case representations.
 */
export function extractParamBounds(param: MasterQualityParameter): {
  minVal: number | null;
  maxVal: number | null;
  hasMin: boolean;
  hasMax: boolean;
  isMandatory: boolean;
  unitStr: string;
} {
  const isMandatory = Boolean(param.is_mandatory ?? param.isRequired);

  const rawMin = param.min_value !== undefined && param.min_value !== null && param.min_value !== ''
    ? param.min_value
    : (param.minValue !== undefined && param.minValue !== null && param.minValue !== '' ? param.minValue : null);

  const rawMax = param.max_value !== undefined && param.max_value !== null && param.max_value !== ''
    ? param.max_value
    : (param.maxValue !== undefined && param.maxValue !== null && param.maxValue !== '' ? param.maxValue : null);

  const hasMin = rawMin !== null && !isNaN(Number(rawMin));
  const hasMax = rawMax !== null && !isNaN(Number(rawMax));
  const minVal = hasMin ? Number(rawMin) : null;
  const maxVal = hasMax ? Number(rawMax) : null;
  const unitStr = param.unit ? ` ${param.unit}` : '';

  return { minVal, maxVal, hasMin, hasMax, isMandatory, unitStr };
}

/**
 * Validates an individual quality parameter against master data boundaries.
 * 
 * @param value The value entered by the user (number, numeric string, or empty)
 * @param param The master quality parameter definition
 */
export function validateSingleQualityParam(
  value: any,
  param: MasterQualityParameter
): SingleQualityValidationResult {
  const { minVal, maxVal, hasMin, hasMax, isMandatory, unitStr } = extractParamBounds(param);
  const rawStr = value !== undefined && value !== null ? String(value).trim() : '';

  // 1. Mandatory check
  if (rawStr === '') {
    if (isMandatory) {
      return {
        isValid: false,
        error: `${param.name} is required.`,
      };
    }
    // Optional field with no entry is valid
    return { isValid: true };
  }

  // 2. Numeric conversion check
  const sanitized = rawStr.replace(',', '.');
  const num = parseFloat(sanitized);

  if (isNaN(num) || !isFinite(num)) {
    return {
      isValid: false,
      error: `${param.name} must be a valid number.`,
    };
  }

  // 3. Mathematical Range Bounds Check
  if (hasMin && hasMax) {
    if (num < minVal! || num > maxVal!) {
      return {
        isValid: false,
        error: `${param.name} must be between ${minVal} and ${maxVal}${unitStr}`,
      };
    }
  } else if (hasMin) {
    if (num < minVal!) {
      return {
        isValid: false,
        error: `${param.name} must be at least ${minVal}${unitStr}`,
      };
    }
  } else if (hasMax) {
    if (num > maxVal!) {
      return {
        isValid: false,
        error: `${param.name} must not exceed ${maxVal}${unitStr}`,
      };
    }
  }

  return { isValid: true };
}

/**
 * Validates a dictionary or array of user-entered quality parameters
 * against a list of active master parameters for a commodity.
 */
export function validateAllQualityParams(
  values: Record<string, any> | Array<{ parameter_id?: string; parameterId?: string; required_value?: any; target_value?: any; targetValue?: any }>,
  masterParams: MasterQualityParameter[]
): AllQualityValidationResult {
  const errors: Record<string, string> = {};

  // Normalize values map
  const valueMap: Record<string, any> = {};
  if (Array.isArray(values)) {
    for (const item of values) {
      const pId = item.parameter_id || item.parameterId;
      const val = item.required_value ?? item.target_value ?? item.targetValue;
      if (pId) {
        valueMap[pId] = val;
      }
    }
  } else if (typeof values === 'object' && values !== null) {
    Object.assign(valueMap, values);
  }

  for (const param of masterParams) {
    const val = valueMap[param.id];
    const res = validateSingleQualityParam(val, param);
    if (!res.isValid && res.error) {
      errors[param.id] = res.error;
    }
  }

  return {
    isValid: Object.keys(errors).length === 0,
    errors,
  };
}

/**
 * Micro-Sprint 34.2: Dynamic Quality Zod Validation Factory
 * 
 * Dynamically constructs a Zod validation schema tailored to the active
 * master quality parameters of the selected commodity.
 * 
 * @param masterParams Array of master parameters for the commodity
 */
export function createDynamicQualitySchema(masterParams: MasterQualityParameter[]) {
  const shape: Record<string, z.ZodTypeAny> = {};

  for (const param of masterParams) {
    const { minVal, maxVal, hasMin, hasMax, isMandatory, unitStr } = extractParamBounds(param);

    let rangeMessage = `${param.name} must be a valid number`;
    if (hasMin && hasMax) {
      rangeMessage = `${param.name} must be between ${minVal} and ${maxVal}${unitStr}`;
    } else if (hasMin) {
      rangeMessage = `${param.name} must be at least ${minVal}${unitStr}`;
    } else if (hasMax) {
      rangeMessage = `${param.name} must not exceed ${maxVal}${unitStr}`;
    }

    // Number validation with bounds
    let baseNumber = z.number({ invalid_type_error: `${param.name} must be a valid number` });
    if (hasMin) {
      baseNumber = baseNumber.min(minVal!, { message: rangeMessage });
    }
    if (hasMax) {
      baseNumber = baseNumber.max(maxVal!, { message: rangeMessage });
    }

    // Decimal coercion preprocessor
    let fieldValidator = z.preprocess((val) => {
      if (val === '' || val === null || val === undefined) return undefined;
      if (typeof val === 'number') return val;
      const parsed = parseFloat(String(val).replace(',', '.'));
      return isNaN(parsed) ? val : parsed;
    }, baseNumber);

    if (isMandatory) {
      shape[param.id] = fieldValidator.refine((v) => v !== undefined && v !== null, {
        message: `${param.name} is required.`,
      });
    } else {
      shape[param.id] = fieldValidator.optional();
    }
  }

  return z.object(shape);
}
