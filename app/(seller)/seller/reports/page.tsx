import React, { Suspense } from "react";
import Link from "next/link";
import { BarChart3, ShieldCheck, LayoutDashboard } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { BackButton } from "@/src/components/ui/back-button";
import { getSellerAnalyticsAction } from "@/src/server/actions/report-actions";
import { SellerReportsView } from "@/src/components/dashboard/seller-reports-view";

export const dynamic = "force-dynamic";

export default async function SellerReportsPage() {
  const res = await getSellerAnalyticsAction("30d");

  const initialData = res.success && res.data ? res.data : {
    timeRange: "30d" as const,
    kpis: {
      grossRevenue: 0,
      netReceivables: 0,
      totalCollected: 0,
      totalOutstanding: 0,
      totalOverdue: 0,
      totalCommission: 0,
      unitsSold: 0,
      totalOrdersCount: 0,
      activeDispatchesCount: 0,
    },
    inventory: {
      availableQuantity: 0,
      reservedQuantity: 0,
      soldQuantity: 0,
      totalQuantity: 0,
      availablePercent: 0,
      reservedPercent: 0,
      soldPercent: 0,
    },
    timeSeries: [],
    pipeline: {
      dispatchPending: 0,
      inTransit: 0,
      delivered: 0,
      closed: 0,
    },
    recentTransactions: [],
    companyName: "Seller Enterprise",
  };

  return (
    <div className="min-h-screen bg-[#F8FAFC] font-sans antialiased text-slate-900 pb-20">
      {/* 1. TOP STICKY APP BAR */}
      <header className="sticky top-0 z-30 bg-white/95 backdrop-blur-md border-b border-slate-200/90 shadow-2xs">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <BackButton label="Dashboard" fallbackUrl="/seller" />

            <div className="hidden sm:flex items-center gap-2">
              <span className="text-slate-300">/</span>
              <span className="text-sm font-bold text-slate-900">
                Reports & Analytics
              </span>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <Badge
              variant="outline"
              className="bg-emerald-50 text-[#047857] border-emerald-200 font-bold text-xs gap-1.5 hidden sm:inline-flex"
            >
              <ShieldCheck className="h-3.5 w-3.5" />
              <span>Zero-Buyer PII Shield</span>
            </Badge>

            <Link href="/seller">
              <Button
                variant="outline"
                size="sm"
                className="border-slate-300 font-bold text-xs rounded-xl h-9 gap-1.5 cursor-pointer"
              >
                <LayoutDashboard className="w-3.5 h-3.5 text-slate-600" />
                <span>Dashboard</span>
              </Button>
            </Link>
          </div>
        </div>
      </header>

      {/* 2. MAIN WORKSPACE CONTAINER */}
      <main className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-6 sm:py-8">
        <Suspense
          fallback={
            <div className="flex items-center justify-center py-20 bg-white rounded-3xl border border-slate-200">
              <div className="flex flex-col items-center gap-2">
                <BarChart3 className="w-8 h-8 text-emerald-600 animate-pulse" />
                <span className="text-xs text-slate-500 font-semibold">
                  Aggregating Seller Financial & Inventory Reports...
                </span>
              </div>
            </div>
          }
        >
          <SellerReportsView initialData={initialData} />
        </Suspense>
      </main>
    </div>
  );
}
