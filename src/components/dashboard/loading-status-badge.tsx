"use client";

import React from "react";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import {
  Truck,
  CheckCircle2,
  Clock,
  Calendar,
  AlertTriangle,
  AlertCircle,
  Package,
} from "lucide-react";
import { LoadingStatus } from "@/src/types/loading-schema";

interface LoadingStatusBadgeProps {
  status?: LoadingStatus | string | null;
  duration?: number | null;
  startDate?: Date | string | null;
  className?: string;
  showIcon?: boolean;
}

export function LoadingStatusBadge({
  status = "Not Ready",
  duration,
  startDate,
  className,
  showIcon = true,
}: LoadingStatusBadgeProps) {
  const normalizedStatus = (status || "Not Ready") as LoadingStatus;

  // Visual styling & icon resolution according to Sprint 16.2 guidelines
  const getConfig = () => {
    switch (normalizedStatus) {
      case "Ready":
        return {
          label: "Ready for Loading",
          bg: "bg-emerald-50 text-emerald-700 border-emerald-200/80 hover:bg-emerald-100/70",
          icon: CheckCircle2,
          iconColor: "text-emerald-600",
        };
      case "Loaded":
        return {
          label: "Fully Loaded",
          bg: "bg-emerald-50 text-emerald-700 border-emerald-200/80 hover:bg-emerald-100/70",
          icon: CheckCircle2,
          iconColor: "text-emerald-600",
        };
      case "Scheduled":
        return {
          label: "Loading Scheduled",
          bg: "bg-sky-50 text-sky-700 border-sky-200/80 hover:bg-sky-100/70",
          icon: Calendar,
          iconColor: "text-sky-600",
        };
      case "Loading":
        return {
          label: "Loading In Progress",
          bg: "bg-blue-50 text-blue-700 border-blue-200/80 hover:bg-blue-100/70",
          icon: Truck,
          iconColor: "text-blue-600",
        };
      case "Delayed":
        return {
          label: "Loading Delayed",
          bg: "bg-amber-50 text-amber-700 border-amber-200/80 hover:bg-amber-100/70",
          icon: AlertCircle,
          iconColor: "text-amber-600",
        };
      case "Blocked":
        return {
          label: "Loading Blocked",
          bg: "bg-rose-50 text-rose-700 border-rose-200/80 hover:bg-rose-100/70",
          icon: AlertTriangle,
          iconColor: "text-rose-600",
        };
      case "Not Ready":
      default:
        return {
          label: "Not Ready",
          bg: "bg-slate-100 text-slate-600 border-slate-200 hover:bg-slate-200/70",
          icon: Clock,
          iconColor: "text-slate-500",
        };
    }
  };

  const config = getConfig();
  const Icon = config.icon;

  return (
    <Badge
      variant="outline"
      className={cn(
        "inline-flex items-center gap-1.5 px-2.5 py-1 text-xs font-semibold rounded-full shrink-0 transition-colors shadow-2xs",
        config.bg,
        className
      )}
    >
      {showIcon && <Icon className={cn("h-3.5 w-3.5 shrink-0", config.iconColor)} />}
      <span>{config.label}</span>
      {duration && duration > 0 ? (
        <span className="text-[10px] font-normal opacity-80 border-l border-current/20 pl-1.5 ml-0.5">
          {duration}d
        </span>
      ) : null}
    </Badge>
  );
}
