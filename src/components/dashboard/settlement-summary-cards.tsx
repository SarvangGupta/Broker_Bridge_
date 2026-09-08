"use client";

import React from "react";
import {
  Wallet,
  CheckCircle2,
  Clock,
  AlertTriangle,
  IndianRupee,
  Layers,
  ArrowUpRight,
  ShieldCheck,
} from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { SettlementSummary } from "@/src/types/settlement-schema";

interface SettlementSummaryCardsProps {
  summary?: SettlementSummary | null;
  isLoading?: boolean;
}

/**
 * Formats numbers into standard Indian Rupee notation (e.g. ₹1,50,000)
 */
function formatRupee(amount: number): string {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 0,
  }).format(amount);
}

export function SettlementSummaryCards({
  summary,
  isLoading = false,
}: SettlementSummaryCardsProps) {
  if (isLoading || !summary) {
    return (
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <div
            key={i}
            className="p-5 bg-white rounded-2xl border border-slate-200 shadow-2xs space-y-3"
          >
            <div className="flex justify-between items-center">
              <Skeleton className="h-4 w-28" />
              <Skeleton className="h-8 w-8 rounded-xl" />
            </div>
            <Skeleton className="h-8 w-36" />
            <Skeleton className="h-3 w-44" />
          </div>
        ))}
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      {/* 1. TOTAL NET RECEIVABLES (Primary Forest Jade Accent) */}
      <div className="p-5 sm:p-6 bg-white rounded-2xl border border-emerald-200/90 shadow-2xs hover:border-emerald-300 transition-all space-y-3 relative overflow-hidden group">
        <div className="h-1 w-full bg-gradient-to-r from-emerald-500 to-[#047857] absolute top-0 left-0" />
        <div className="flex items-center justify-between">
          <span className="text-[11px] font-bold uppercase tracking-wider text-[#047857]">
            Total Net Receivables
          </span>
          <div className="w-9 h-9 rounded-xl bg-emerald-50 text-[#047857] flex items-center justify-center">
            <Wallet className="w-4 h-4 stroke-[2.2]" />
          </div>
        </div>

        <div className="space-y-0.5">
          <div className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight">
            {formatRupee(summary.totalReceivables)}
          </div>
          <div className="text-xs text-slate-500 font-medium flex items-center gap-1">
            <span>After ₹{summary.totalCommission.toLocaleString("en-IN")} commission</span>
          </div>
        </div>

        <div className="pt-2 border-t border-slate-100 flex items-center justify-between text-xs text-slate-500">
          <span className="font-semibold text-slate-700">{summary.totalRecords} Booked Trades</span>
          <Badge variant="outline" className="bg-emerald-50/60 text-[#047857] border-emerald-200 text-[10px] font-bold">
            Post-Commission
          </Badge>
        </div>
      </div>

      {/* 2. COLLECTED / SETTLED (Emerald Green) */}
      <div className="p-5 sm:p-6 bg-white rounded-2xl border border-slate-200/90 shadow-2xs hover:border-slate-300 transition-all space-y-3 relative overflow-hidden">
        <div className="h-1 w-full bg-emerald-500 absolute top-0 left-0" />
        <div className="flex items-center justify-between">
          <span className="text-[11px] font-bold uppercase tracking-wider text-emerald-800">
            Collected / Settled
          </span>
          <div className="w-9 h-9 rounded-xl bg-emerald-100 text-emerald-800 flex items-center justify-center">
            <CheckCircle2 className="w-4 h-4 stroke-[2.2]" />
          </div>
        </div>

        <div className="space-y-0.5">
          <div className="text-2xl sm:text-3xl font-black text-emerald-950 tracking-tight">
            {formatRupee(summary.totalCollected)}
          </div>
          <div className="text-xs text-emerald-800 font-semibold flex items-center gap-1">
            <ShieldCheck className="w-3.5 h-3.5 text-[#047857]" />
            <span>{summary.paidCount} Fully Settled</span>
          </div>
        </div>

        <div className="pt-2 border-t border-slate-100 flex items-center justify-between text-xs text-slate-500">
          <span>{summary.partPaidCount} Partial Payments</span>
          <Badge className="bg-emerald-100 text-emerald-900 text-[10px] font-bold">
            {summary.totalReceivables > 0
              ? `${Math.round((summary.totalCollected / summary.totalReceivables) * 100)}% Settled`
              : "100%"}
          </Badge>
        </div>
      </div>

      {/* 3. OUTSTANDING BALANCE (Slate / Amber Neutral) */}
      <div className="p-5 sm:p-6 bg-white rounded-2xl border border-slate-200/90 shadow-2xs hover:border-slate-300 transition-all space-y-3 relative overflow-hidden">
        <div className="h-1 w-full bg-slate-400 absolute top-0 left-0" />
        <div className="flex items-center justify-between">
          <span className="text-[11px] font-bold uppercase tracking-wider text-slate-500">
            Outstanding Balance
          </span>
          <div className="w-9 h-9 rounded-xl bg-slate-100 text-slate-700 flex items-center justify-center">
            <Clock className="w-4 h-4 stroke-[2.2]" />
          </div>
        </div>

        <div className="space-y-0.5">
          <div className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight">
            {formatRupee(summary.totalOutstanding)}
          </div>
          <div className="text-xs text-slate-500 font-medium">
            <span>Pending settlement reconciliation</span>
          </div>
        </div>

        <div className="pt-2 border-t border-slate-100 flex items-center justify-between text-xs text-slate-500">
          <span>{summary.pendingCount} Pending Invoices</span>
          <Badge variant="outline" className="bg-slate-50 text-slate-700 border-slate-200 text-[10px] font-semibold">
            In Transit / Grace
          </Badge>
        </div>
      </div>

      {/* 4. OVERDUE PAYMENTS (Rose Alert) */}
      <div className="p-5 sm:p-6 bg-white rounded-2xl border border-rose-200/90 shadow-2xs hover:border-rose-300 transition-all space-y-3 relative overflow-hidden">
        <div className="h-1 w-full bg-rose-500 absolute top-0 left-0" />
        <div className="flex items-center justify-between">
          <span className="text-[11px] font-bold uppercase tracking-wider text-rose-700">
            Overdue Balance
          </span>
          <div className="w-9 h-9 rounded-xl bg-rose-100 text-rose-700 flex items-center justify-center">
            <AlertTriangle className="w-4 h-4 stroke-[2.2]" />
          </div>
        </div>

        <div className="space-y-0.5">
          <div className="text-2xl sm:text-3xl font-black text-rose-950 tracking-tight">
            {formatRupee(summary.totalOverdue)}
          </div>
          <div className="text-xs text-rose-700 font-semibold flex items-center gap-1">
            <span>{summary.overdueCount} Invoices Past Due</span>
          </div>
        </div>

        <div className="pt-2 border-t border-rose-100 flex items-center justify-between text-xs text-slate-500">
          <span>{summary.disputedCount} In Dispute</span>
          <Badge className="bg-rose-100 text-rose-800 text-[10px] font-bold">
            Action Required
          </Badge>
        </div>
      </div>
    </div>
  );
}
