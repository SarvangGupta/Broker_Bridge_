"use client";

import { useMemo } from "react";
import { Badge } from "@/components/ui/badge";
import {
  CheckCircle2,
  Clock,
  AlertTriangle,
  XCircle,
  AlertCircle,
  ShieldAlert,
  FileCheck2,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { computeLabFreshness, LabFreshnessStatus } from "@/src/types/lab-schema";

export interface QualityStatusBadgeProps {
  status?: string | null;
  validUntil?: Date | string | null;
  testDate?: Date | string | null;
  className?: string;
  showIcon?: boolean;
}

export function QualityStatusBadge({
  status,
  validUntil,
  testDate,
  className,
  showIcon = true,
}: QualityStatusBadgeProps) {
  const { effectiveStatus, freshness } = useMemo(() => {
    if (!status && !testDate && !validUntil) {
      return { effectiveStatus: "Seller Declared", freshness: null };
    }

    const calculatedFreshness: LabFreshnessStatus | null = testDate
      ? computeLabFreshness(testDate, validUntil)
      : validUntil && new Date(validUntil).getTime() < Date.now()
      ? "Expired"
      : null;

    // Mathematical Expiry Override
    let resolvedStatus = status || "Seller Declared";
    if (calculatedFreshness === "Expired" || (validUntil && new Date(validUntil).getTime() < Date.now())) {
      resolvedStatus = "Expired";
    }

    return {
      effectiveStatus: resolvedStatus,
      freshness: calculatedFreshness,
    };
  }, [status, validUntil, testDate]);

  switch (effectiveStatus) {
    case "Verified":
      return (
        <Badge
          variant="outline"
          className={cn(
            "bg-emerald-50 text-emerald-700 border-emerald-200/90 font-semibold px-2.5 py-1 text-xs shrink-0 rounded-full flex items-center gap-1",
            className
          )}
        >
          {showIcon && <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" />}
          <span>Lab Verified</span>
        </Badge>
      );

    case "Under Review":
    case "Report Uploaded":
    case "Pending":
      return (
        <Badge
          variant="outline"
          className={cn(
            "bg-amber-50 text-amber-700 border-amber-200/90 font-semibold px-2.5 py-1 text-xs shrink-0 rounded-full flex items-center gap-1",
            className
          )}
        >
          {showIcon && <Clock className="w-3.5 h-3.5 text-amber-600" />}
          <span>Under Review</span>
        </Badge>
      );

    case "Correction Required":
      return (
        <Badge
          variant="outline"
          className={cn(
            "bg-orange-50 text-orange-700 border-orange-200/90 font-semibold px-2.5 py-1 text-xs shrink-0 rounded-full flex items-center gap-1",
            className
          )}
        >
          {showIcon && <AlertTriangle className="w-3.5 h-3.5 text-orange-600" />}
          <span>Correction Required</span>
        </Badge>
      );

    case "Rejected":
      return (
        <Badge
          variant="outline"
          className={cn(
            "bg-rose-50 text-rose-700 border-rose-200/90 font-semibold px-2.5 py-1 text-xs shrink-0 rounded-full flex items-center gap-1",
            className
          )}
        >
          {showIcon && <XCircle className="w-3.5 h-3.5 text-rose-600" />}
          <span>Lab Rejected</span>
        </Badge>
      );

    case "Expired":
      return (
        <Badge
          variant="outline"
          className={cn(
            "bg-red-50 text-red-700 border-red-200 font-semibold px-2.5 py-1 text-xs shrink-0 rounded-full flex items-center gap-1",
            className
          )}
        >
          {showIcon && <AlertCircle className="w-3.5 h-3.5 text-red-600" />}
          <span>Lab Expired</span>
        </Badge>
      );

    case "Seller Declared":
    default:
      return (
        <Badge
          variant="outline"
          className={cn(
            "bg-slate-100 text-slate-700 border-slate-200/90 font-medium px-2.5 py-1 text-xs shrink-0 rounded-full flex items-center gap-1",
            className
          )}
        >
          {showIcon && <FileCheck2 className="w-3.5 h-3.5 text-slate-500" />}
          <span>Seller Declared</span>
        </Badge>
      );
  }
}
