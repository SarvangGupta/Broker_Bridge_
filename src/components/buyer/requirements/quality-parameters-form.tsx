'use client';

import React, { useEffect, useState, useMemo } from 'react';
import { 
  FlaskConical, 
  Sparkles, 
  AlertCircle, 
  CheckCircle2, 
  Info,
  Loader2,
  Check
} from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { cn } from '@/lib/utils';
import { 
  getCommodityQualityParametersAction, 
  CommodityQualityParameter 
} from '@/src/server/actions/buyer-quality-actions';
import {
  validateSingleQualityParam,
  validateAllQualityParams,
  extractParamBounds,
} from '@/src/lib/validations/buyer-quality-schema';

export interface QualityParameterValue {
  parameter_id: string;
  required_value: number | string;
  parameter_name?: string;
  unit?: string | null;
}

export interface QualityParametersFormProps {
  commodityId?: string;
  gradeId?: string;
  value?: QualityParameterValue[];
  onChange?: (values: QualityParameterValue[]) => void;
  onValidationChange?: (isValid: boolean, errors: Record<string, string>) => void;
  disabled?: boolean;
}

export function QualityParametersForm({
  commodityId,
  gradeId,
  value = [],
  onChange,
  onValidationChange,
  disabled = false,
}: QualityParametersFormProps) {
  const [parameters, setParameters] = useState<CommodityQualityParameter[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [touched, setTouched] = useState<Record<string, boolean>>({});

  // Map incoming values by parameter_id for fast lookup
  const valueMap = useMemo(() => {
    const map: Record<string, number | string> = {};
    if (Array.isArray(value)) {
      for (const item of value) {
        if (item.parameter_id) {
          map[item.parameter_id] = item.required_value;
        }
      }
    }
    return map;
  }, [value]);

  // Fetch parameters when commodity or grade changes
  useEffect(() => {
    let isMounted = true;

    async function fetchParameters() {
      if (!commodityId) {
        setParameters([]);
        setError(null);
        return;
      }

      setLoading(true);
      setError(null);

      try {
        const res = await getCommodityQualityParametersAction(commodityId, gradeId);
        if (!isMounted) return;

        if (res.success && res.data) {
          setParameters(res.data);
        } else {
          setError(res.error || 'Failed to load master quality parameters.');
          setParameters([]);
        }
      } catch (err: any) {
        if (!isMounted) return;
        setError(err.message || 'Error fetching master quality parameters.');
        setParameters([]);
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    }

    fetchParameters();

    return () => {
      isMounted = false;
    };
  }, [commodityId, gradeId]);

  // Real-time validation computation against active parameters
  const validationResult = useMemo(() => {
    if (parameters.length === 0) {
      return { isValid: true, errors: {} };
    }
    return validateAllQualityParams(value, parameters as any);
  }, [value, parameters]);

  // Notify parent wizard of validation status changes
  useEffect(() => {
    onValidationChange?.(validationResult.isValid, validationResult.errors);
  }, [validationResult, onValidationChange]);

  const handleInputChange = (param: CommodityQualityParameter, rawVal: string) => {
    setTouched((prev) => ({ ...prev, [param.id]: true }));

    if (!onChange) return;

    // Build updated values array
    const filtered = (value || []).filter((v) => v.parameter_id !== param.id);

    if (rawVal.trim() !== '') {
      filtered.push({
        parameter_id: param.id,
        required_value: rawVal.trim(),
        parameter_name: param.name,
        unit: param.unit,
      });
    }

    onChange(filtered);
  };

  const handleBlur = (paramId: string) => {
    setTouched((prev) => ({ ...prev, [paramId]: true }));
  };

  // State 1: No Commodity Selected
  if (!commodityId) {
    return (
      <div className="flex flex-col items-center justify-center p-6 rounded-xl border border-dashed border-slate-200 bg-slate-50/60 text-center space-y-2">
        <div className="p-2.5 rounded-full bg-sky-50 text-[#0284C7]">
          <FlaskConical className="w-5 h-5" />
        </div>
        <p className="text-xs font-semibold text-slate-700">
          Quality Parameters & Specifications
        </p>
        <p className="text-xs text-slate-500 max-w-xs leading-relaxed break-words">
          Select a commodity above to automatically load official master quality parameters and permissible tolerances.
        </p>
      </div>
    );
  }

  // State 2: Loading State with Mobile Touch Skeletons
  if (loading) {
    return (
      <div className="space-y-3 pt-2">
        <div className="flex items-center justify-between">
          <Skeleton className="h-4 w-44" />
          <Skeleton className="h-4 w-20" />
        </div>
        <div className="flex flex-col space-y-3">
          {[1, 2, 3].map((i) => (
            <div key={i} className="p-3.5 rounded-xl border border-slate-200 bg-white space-y-2">
              <div className="flex justify-between items-center">
                <Skeleton className="h-4 w-32" />
                <Skeleton className="h-4 w-16" />
              </div>
              <Skeleton className="h-12 w-full rounded-md" />
              <Skeleton className="h-3 w-48" />
            </div>
          ))}
        </div>
      </div>
    );
  }

  // State 3: Error State
  if (error) {
    return (
      <div className="flex flex-col p-4 rounded-xl border border-rose-200 bg-rose-50/60 text-rose-800 space-y-2">
        <div className="flex items-center gap-2">
          <AlertCircle className="w-4 h-4 text-rose-600 shrink-0" />
          <p className="text-xs font-semibold break-words max-w-full">{error}</p>
        </div>
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() => {
            if (commodityId) {
              setLoading(true);
              setError(null);
              getCommodityQualityParametersAction(commodityId, gradeId).then((res) => {
                setLoading(false);
                if (res.success && res.data) setParameters(res.data);
                else setError(res.error || 'Retry failed');
              });
            }
          }}
          className="self-start min-h-[44px] text-xs border-rose-300 text-rose-700 hover:bg-rose-100"
        >
          Retry Loading Parameters
        </Button>
      </div>
    );
  }

  // State 4: Commodity has no master quality parameters configured
  if (parameters.length === 0) {
    return (
      <div className="flex flex-col p-4 rounded-xl border border-slate-200 bg-slate-50/80 text-slate-700 space-y-1.5">
        <div className="flex items-center gap-2">
          <Info className="w-4 h-4 text-[#0284C7] shrink-0" />
          <span className="text-xs font-semibold text-slate-800">
            Standard Trade Grade Specifications Apply
          </span>
        </div>
        <p className="text-xs text-slate-500 leading-relaxed break-words">
          No separate parameter tests configured for this commodity in the master directory. Baseline commercial grade standards will be enforced during matching and quotation.
        </p>
      </div>
    );
  }

  // State 5: Active Master-Driven Parameter Form
  return (
    <div className="flex flex-col space-y-3.5 w-full max-w-full">
      {/* Header with Title and Count Badge */}
      <div className="flex items-center justify-between pb-1 flex-wrap gap-2">
        <div className="space-y-0.5 min-w-0">
          <div className="flex items-center gap-2">
            <FlaskConical className="w-4 h-4 text-[#0284C7] shrink-0" />
            <span className="text-xs font-bold text-slate-900 uppercase tracking-wider truncate">
              Quality Parameters & Tolerances
            </span>
          </div>
          <p className="text-[11px] text-slate-500 break-words">
            Master-driven specifications. Enter your acceptable target thresholds.
          </p>
        </div>
        <Badge
          variant="outline"
          className="text-[11px] font-medium bg-sky-50 text-[#0284C7] border-sky-200 shrink-0"
        >
          {parameters.length} Parameter{parameters.length > 1 ? 's' : ''}
        </Badge>
      </div>

      {/* Dynamic Master Parameter Fields - Strictly flex-col for 360px mobile viewports */}
      <div className="flex flex-col space-y-3">
        {parameters.map((param) => {
          const currentVal = valueMap[param.id] ?? '';
          const isEntered = currentVal !== '';
          const isFieldTouched = Boolean(touched[param.id]);

          // Extract bounds using standardized validator utility
          const { minVal, maxVal, hasMin, hasMax, isMandatory, unitStr } = extractParamBounds(param as any);
          const hasBaseline = Boolean(param.grade_baseline || param.gradeBaseline);
          const baselineVal = param.grade_baseline || param.gradeBaseline;

          // Single field validation check
          const singleValidation = validateSingleQualityParam(currentVal, param as any);
          const hasError = !singleValidation.isValid && (isEntered || isFieldTouched);
          const errorMessage = singleValidation.error;
          const isValidWithVal = singleValidation.isValid && isEntered;

          // Format master range badge: e.g. "Allowed: 8.0 - 14.0 %"
          let allowedBadgeText = '';
          if (hasMin && hasMax) {
            allowedBadgeText = `Allowed: ${minVal} – ${maxVal}${unitStr}`;
          } else if (hasMin) {
            allowedBadgeText = `Allowed: Min ${minVal}${unitStr}`;
          } else if (hasMax) {
            allowedBadgeText = `Allowed: Max ${maxVal}${unitStr}`;
          } else if (hasBaseline) {
            allowedBadgeText = `Standard: ${baselineVal}${unitStr}`;
          } else {
            allowedBadgeText = 'Standard Grade';
          }

          return (
            <div
              key={param.id}
              className={cn(
                "flex flex-col space-y-2 p-3.5 rounded-xl border bg-white transition-all max-w-full",
                hasError
                  ? "border-destructive bg-rose-50/20 shadow-xs"
                  : isValidWithVal
                  ? "border-emerald-500/50 bg-emerald-50/10 shadow-xs"
                  : isEntered
                  ? "border-[#0284C7]/50 bg-sky-50/20 shadow-xs"
                  : "border-slate-200 hover:border-slate-300"
              )}
            >
              {/* Parameter Name, Unit & Badges */}
              <div className="flex items-center justify-between gap-2 flex-wrap">
                <Label
                  htmlFor={`quality-input-${param.id}`}
                  className="text-xs font-semibold text-slate-800 flex items-center gap-1.5 cursor-pointer max-w-full flex-wrap"
                >
                  <span className="break-words">{param.name}</span>
                  {param.unit && (
                    <span className="text-slate-500 font-normal">
                      ({param.unit})
                    </span>
                  )}
                  {isMandatory && (
                    <span className="text-rose-500 font-bold ml-0.5" title="Mandatory parameter">
                      *
                    </span>
                  )}
                </Label>

                {/* Badges: Allowed master range badge & baseline badge */}
                <div className="flex items-center gap-1.5 shrink-0 flex-wrap">
                  {/* Task 2: Master range badge */}
                  <span
                    className={cn(
                      "text-[10px] font-semibold px-2 py-0.5 rounded border tracking-tight",
                      hasError
                        ? "bg-rose-50 text-rose-700 border-rose-200"
                        : "bg-sky-50 text-[#0284C7] border-sky-200"
                    )}
                  >
                    {allowedBadgeText}
                  </span>

                  {/* Mandatory indicator badge */}
                  {isMandatory && (
                    <span className="text-[10px] font-bold text-rose-600 bg-rose-50 px-1.5 py-0.5 rounded border border-rose-200">
                      Required
                    </span>
                  )}
                </div>
              </div>

              {/* Input Control: Strictly min-h-[48px] with inputMode="decimal" */}
              <div className="relative">
                <Input
                  id={`quality-input-${param.id}`}
                  type="text"
                  inputMode="decimal"
                  pattern="[0-9]*[.,]?[0-9]*"
                  disabled={disabled}
                  placeholder={
                    hasBaseline
                      ? `Standard: ${baselineVal}`
                      : hasMin && hasMax
                      ? `e.g. ${minVal}`
                      : hasMin
                      ? `Min ${minVal}`
                      : hasMax
                      ? `Max ${maxVal}`
                      : "Enter target threshold"
                  }
                  value={currentVal}
                  onChange={(e) => handleInputChange(param, e.target.value)}
                  onBlur={() => handleBlur(param.id)}
                  className={cn(
                    "min-h-[48px] h-12 text-sm bg-white transition-colors",
                    hasError
                      ? "border-destructive text-destructive focus-visible:ring-destructive focus-visible:border-destructive"
                      : isValidWithVal
                      ? "border-emerald-500 focus-visible:ring-emerald-500 focus-visible:border-emerald-500"
                      : "border-slate-300 focus-visible:ring-[#0284C7] focus-visible:border-[#0284C7]",
                    param.unit || isValidWithVal || hasError ? "pr-20" : ""
                  )}
                />

                {/* Right side indicators: Unit and status icon */}
                <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-3 gap-1.5">
                  {/* Valid green check indicator */}
                  {isValidWithVal && !hasError && (
                    <div className="w-5 h-5 rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center">
                      <Check className="w-3 h-3 stroke-[3]" />
                    </div>
                  )}

                  {/* Destructive red alert indicator */}
                  {hasError && (
                    <div className="w-5 h-5 rounded-full bg-rose-100 text-rose-600 flex items-center justify-center">
                      <AlertCircle className="w-3.5 h-3.5" />
                    </div>
                  )}

                  {/* Unit text */}
                  {param.unit && (
                    <span className="text-xs font-semibold text-slate-400 font-mono">
                      {param.unit}
                    </span>
                  )}
                </div>
              </div>

              {/* Real-time Inline Feedback (Error or Helper) */}
              {hasError && errorMessage ? (
                /* Task 2: Immediate inline red validation message */
                <div className="flex items-start gap-1.5 text-xs text-destructive font-medium pt-0.5 break-words max-w-full">
                  <AlertCircle className="w-3.5 h-3.5 text-destructive shrink-0 mt-0.5" />
                  <span className="break-words max-w-full leading-snug">{errorMessage}</span>
                </div>
              ) : isValidWithVal ? (
                /* Valid confirmation indicator */
                <div className="flex items-center justify-between text-[11px] text-emerald-600 font-semibold pt-0.5">
                  <span className="flex items-center gap-1">
                    <CheckCircle2 className="w-3.5 h-3.5" /> Validated within master bounds
                  </span>
                  <span className="font-mono">{currentVal}{param.unit ? ` ${param.unit}` : ''}</span>
                </div>
              ) : (
                /* Default helper range text */
                <div className="flex items-center justify-between text-[11px] text-slate-500 pt-0.5 flex-wrap gap-1">
                  <span className="font-medium text-slate-500 break-words">{allowedBadgeText}</span>
                  {isMandatory && !isEntered && (
                    <span className="text-rose-500 font-medium text-[10px]">
                      Field is mandatory
                    </span>
                  )}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
