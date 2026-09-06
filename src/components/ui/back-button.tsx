"use client";

import React from "react";
import { useRouter } from "next/navigation";
import { ArrowLeft } from "lucide-react";
import { cn } from "@/lib/utils";

export interface BackButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  label?: string;
  fallbackUrl?: string;
  className?: string;
}

/**
 * Smart Back Navigation Button.
 * Executes client-side `router.back()` so the user is returned to the exact
 * screen they navigated from (e.g. Dashboard, Inbox, or previous view).
 */
export function BackButton({
  label = "Back",
  fallbackUrl,
  className,
  ...props
}: BackButtonProps) {
  const router = useRouter();

  const handleBack = () => {
    if (typeof window !== "undefined" && window.history.length > 1) {
      router.back();
    } else if (fallbackUrl) {
      router.push(fallbackUrl);
    } else {
      router.back();
    }
  };

  return (
    <button
      type="button"
      onClick={handleBack}
      className={cn(
        "inline-flex items-center gap-1.5 text-xs font-bold text-slate-700 hover:text-slate-950 bg-slate-100 hover:bg-slate-200 px-3 py-2 rounded-xl transition-colors cursor-pointer",
        className
      )}
      {...props}
    >
      <ArrowLeft className="h-3.5 w-3.5" />
      <span>{label}</span>
    </button>
  );
}
