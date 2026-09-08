import React from "react";
import Link from "next/link";
import {
  Wallet,
  ShieldCheck,
  Building2,
  RefreshCw,
  FileCheck2,
  Lock,
  ArrowRight,
} from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { BackButton } from "@/src/components/ui/back-button";
import { getSellerSettlementOverviewAction } from "@/src/server/actions/settlement-actions";
import { SettlementWorkspaceView } from "@/src/components/dashboard/settlement-workspace-view";

export const dynamic = "force-dynamic";

export default async function SellerPaymentsPage() {
  const result = await getSellerSettlementOverviewAction();

  const summary = result.success && result.data ? result.data.summary : null;
  const records = result.success && result.data ? result.data.records : [];

  return (
    <div className="min-h-screen bg-[#F8FAFC] font-sans antialiased text-slate-900 pb-20">
      {/* 1. TOP STICKY HEADER */}
      <header className="sticky top-0 z-30 bg-white/95 backdrop-blur-md border-b border-slate-200/90 shadow-2xs">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <BackButton label="Command Center" fallbackUrl="/seller" />
            <div className="hidden sm:flex items-center gap-2">
              <span className="text-slate-300">/</span>
              <span className="text-sm font-bold text-slate-900">
                Settlement & Payment Ledger
              </span>
            </div>
          </div>

          <div className="flex items-center gap-2.5">
            <Badge
              variant="outline"
              className="bg-emerald-50 text-[#047857] border-emerald-200 font-bold text-xs gap-1.5 px-3 py-1"
            >
              <ShieldCheck className="w-3.5 h-3.5 text-[#047857]" />
              <span>Server-Calculated Math Engine</span>
            </Badge>
          </div>
        </div>
      </header>

      {/* 2. HERO TITLE SECTION */}
      <div className="bg-white border-b border-slate-200/80">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 sm:py-8">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div className="space-y-1">
              <div className="flex items-center gap-2">
                <div className="w-7 h-7 rounded-lg bg-emerald-100 flex items-center justify-center text-[#047857]">
                  <Wallet className="w-4 h-4" />
                </div>
                <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
                  Seller PRD v3.0 Section 19.4
                </span>
                <span className="text-slate-300">•</span>
                <span className="text-xs font-semibold text-emerald-700">
                  Payments & Settlement
                </span>
              </div>
              <h1 className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight">
                Payments & Settlement Ledger
              </h1>
              <p className="text-xs sm:text-sm text-slate-500 max-w-2xl">
                Server-validated balance sheet scoped to confirmed commercial bookings and dispatches. Monitor net receivables, broker commissions, and payment disbursements.
              </p>
            </div>

            <div className="flex items-center gap-3">
              <Link href="/seller?tab=deals">
                <Button
                  variant="outline"
                  className="min-h-[48px] font-bold text-xs rounded-xl border-slate-300 gap-1.5"
                >
                  <FileCheck2 className="w-4 h-4 text-slate-500" />
                  <span>View Deals & Contracts</span>
                </Button>
              </Link>
            </div>
          </div>
        </div>
      </div>

      {/* 3. MAIN WORKSPACE */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-8 space-y-8">
        {/* FINANCIAL SUMMARY & SETTLEMENT LEDGER */}
        <SettlementWorkspaceView initialSummary={summary} initialRecords={records} />
      </main>
    </div>
  );
}
