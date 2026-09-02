"use client";

import { useEffect, useState } from "react";
import { Loader2, Sparkles, CheckCircle2, AlertCircle } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { getQualityTemplateByCommodityAction } from "@/src/server/actions/quality-actions";
import { QualityTemplateParameter } from "@/src/types/quality-schema";
import { cn } from "@/lib/utils";

interface DynamicQualityFieldsProps {
  commodityId?: string;
  values: Record<string, string>;
  onChange: (values: Record<string, string>) => void;
  errors?: Record<string, string>;
  disabled?: boolean;
  onTemplateLoaded?: (template: QualityTemplateParameter[]) => void;
}

export function DynamicQualityFields({
  commodityId,
  values,
  onChange,
  errors = {},
  disabled = false,
  onTemplateLoaded,
}: DynamicQualityFieldsProps) {
  const [template, setTemplate] = useState<QualityTemplateParameter[]>([]);
  const [loading, setLoading] = useState(false);
  const [fetchError, setFetchError] = useState<string | null>(null);

  useEffect(() => {
    let isMounted = true;

    async function fetchQualityTemplate() {
      if (!commodityId) {
        setTemplate([]);
        onTemplateLoaded?.([]);
        return;
      }

      setLoading(true);
      setFetchError(null);

      try {
        const res = await getQualityTemplateByCommodityAction(commodityId);
        if (!isMounted) return;

        if (res.success && res.data) {
          const mapped: QualityTemplateParameter[] = res.data.map((p) => ({
            id: p.id,
            commodityId: p.commodityId,
            name: p.name,
            type: p.type,
            unit: p.unit,
            minValue: p.minValue,
            maxValue: p.maxValue,
            targetValue: p.targetValue,
            isRequired: p.isRequired,
            isActive: p.isActive,
          }));
          setTemplate(mapped);
          onTemplateLoaded?.(mapped);
        } else {
          setFetchError(res.error || "Failed to load quality parameters.");
          setTemplate([]);
          onTemplateLoaded?.([]);
        }
      } catch (err: any) {
        if (!isMounted) return;
        setFetchError(err.message || "Failed to load quality parameters.");
        setTemplate([]);
        onTemplateLoaded?.([]);
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    }

    fetchQualityTemplate();

    return () => {
      isMounted = false;
    };
  }, [commodityId]);

  const handleFieldChange = (paramId: string, val: string) => {
    onChange({
      ...values,
      [paramId]: val,
    });
  };

  if (!commodityId) {
    return (
      <div className="rounded-lg border border-dashed border-slate-200 p-6 text-center text-sm text-muted-foreground bg-slate-50/50">
        <Sparkles className="mx-auto h-6 w-6 text-slate-400 mb-2" />
        <p className="font-medium text-slate-700">Select a commodity first</p>
        <p className="text-xs text-slate-500 mt-0.5">
          Quality parameter specifications will automatically populate based on the commodity chosen.
        </p>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center p-8 space-y-3 rounded-lg border bg-slate-50/50">
        <Loader2 className="h-6 w-6 animate-spin text-primary" />
        <p className="text-sm font-medium text-slate-600">
          Loading commodity quality specifications...
        </p>
      </div>
    );
  }

  if (fetchError) {
    return (
      <div className="rounded-lg border border-destructive/20 bg-destructive/5 p-4 text-sm text-destructive flex items-center space-x-2">
        <AlertCircle className="h-5 w-5 shrink-0" />
        <span>{fetchError}</span>
      </div>
    );
  }

  if (template.length === 0) {
    return (
      <div className="rounded-lg border border-dashed border-slate-200 p-6 text-center text-sm text-muted-foreground bg-slate-50/50">
        <CheckCircle2 className="mx-auto h-6 w-6 text-emerald-500 mb-2" />
        <p className="font-medium text-slate-700">No dynamic quality parameters configured</p>
        <p className="text-xs text-slate-500 mt-0.5">
          Standard trade specifications apply to this commodity.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between pb-1">
        <p className="text-xs text-slate-500 font-medium">
          Enter lot-specific lab & QC measurements. Fields marked with <span className="text-destructive font-bold">*</span> are required.
        </p>
        <Badge variant="outline" className="text-[11px] font-mono bg-white">
          {template.length} Parameters
        </Badge>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {template.map((param) => {
          const fieldError = errors[param.id];
          const currentValue = values[param.id] ?? "";

          // Format label with unit (e.g. "Moisture %")
          const displayLabel = param.unit 
            ? `${param.name} (${param.unit})` 
            : param.name;

          return (
            <div
              key={param.id}
              className={cn(
                "flex flex-col space-y-1.5 p-3.5 rounded-lg border bg-card transition-colors",
                fieldError
                  ? "border-destructive/60 bg-destructive/[0.02]"
                  : "border-slate-200/80 hover:border-slate-300"
              )}
            >
              {/* Header: Label + Badges */}
              <div className="flex items-center justify-between gap-2">
                <Label
                  htmlFor={`quality-param-${param.id}`}
                  className="text-sm font-medium text-slate-800 flex items-center gap-1 cursor-pointer"
                >
                  {displayLabel}
                  {param.isRequired && (
                    <span className="text-destructive font-bold text-base leading-none" title="Required">*</span>
                  )}
                </Label>

                {/* Target badge if present */}
                {param.targetValue !== null && param.targetValue !== undefined && (
                  <span className="text-[10px] font-medium px-1.5 py-0.5 rounded bg-emerald-50 text-emerald-700 border border-emerald-200/60">
                    Target: {param.targetValue}{param.unit ? ` ${param.unit}` : ""}
                  </span>
                )}
              </div>

              {/* Dynamic Input Control based on parameter type */}
              {param.type === "numeric" ? (
                <div className="relative">
                  <Input
                    id={`quality-param-${param.id}`}
                    type="number"
                    inputMode="decimal"
                    step="any"
                    disabled={disabled}
                    placeholder={
                      param.targetValue
                        ? `e.g. ${param.targetValue}`
                        : param.minValue
                        ? `e.g. ${param.minValue}`
                        : "Enter value"
                    }
                    value={currentValue}
                    onChange={(e) => handleFieldChange(param.id, e.target.value)}
                    className={cn(
                      "min-h-[48px] h-12 text-base font-normal",
                      param.unit ? "pr-12" : "",
                      fieldError && "border-destructive focus-visible:ring-destructive"
                    )}
                  />
                  {param.unit && (
                    <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-3">
                      <span className="text-xs text-muted-foreground font-mono font-medium">
                        {param.unit}
                      </span>
                    </div>
                  )}
                </div>
              ) : param.type === "boolean" ? (
                <Select
                  value={currentValue}
                  onValueChange={(val) => handleFieldChange(param.id, val || "")}
                  disabled={disabled}
                >
                  <SelectTrigger
                    id={`quality-param-${param.id}`}
                    className={cn(
                      "min-h-[48px] h-12 w-full text-base",
                      fieldError && "border-destructive focus:ring-destructive"
                    )}
                  >
                    <SelectValue placeholder="Select Yes / No" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="Yes" className="min-h-[48px]">
                      Yes (Conforming)
                    </SelectItem>
                    <SelectItem value="No" className="min-h-[48px]">
                      No (Non-Conforming)
                    </SelectItem>
                  </SelectContent>
                </Select>
              ) : (
                <Input
                  id={`quality-param-${param.id}`}
                  type="text"
                  disabled={disabled}
                  placeholder="Enter specification details"
                  value={currentValue}
                  onChange={(e) => handleFieldChange(param.id, e.target.value)}
                  className={cn(
                    "min-h-[48px] h-12 text-base",
                    fieldError && "border-destructive focus-visible:ring-destructive"
                  )}
                />
              )}

              {/* Hint text below input (e.g. "Max allowed: 14%") */}
              <div className="flex items-center justify-between text-xs text-muted-foreground pt-0.5">
                {param.minValue !== null && param.minValue !== undefined && param.maxValue !== null && param.maxValue !== undefined ? (
                  <span>Allowed range: {param.minValue} – {param.maxValue}{param.unit ? ` ${param.unit}` : ""}</span>
                ) : param.maxValue !== null && param.maxValue !== undefined ? (
                  <span>Max allowed: {param.maxValue}{param.unit ? ` ${param.unit}` : ""}</span>
                ) : param.minValue !== null && param.minValue !== undefined ? (
                  <span>Min required: {param.minValue}{param.unit ? ` ${param.unit}` : ""}</span>
                ) : (
                  <span>Standard parameter specification</span>
                )}
              </div>

              {/* Inline Field Error */}
              {fieldError && (
                <p className="text-xs font-medium text-destructive flex items-center gap-1 mt-1">
                  <AlertCircle className="h-3.5 w-3.5 shrink-0" />
                  <span>{fieldError}</span>
                </p>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
