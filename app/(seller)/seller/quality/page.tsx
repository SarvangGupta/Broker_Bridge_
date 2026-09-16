import React, { Suspense } from "react";
import Link from "next/link";
import { FlaskConical, ShieldCheck, LayoutDashboard, Loader2 } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { BackButton } from "@/src/components/ui/back-button";
import { getSellerGlobalLabReportsAction } from "@/src/server/actions/lab-actions";
import { SellerQualityVaultView } from "@/src/components/dashboard/seller-quality-vault-view";

export const dynamic = "force-dynamic";

export default async function SellerQualityPage() {
  const res = await getSellerGlobalLabReportsAction();
  const reports = res.success && res.data ? res.data : [];

  return (
    <div className="min-h-screen bg-[#F8FAFC] font-sans antialiased text-slate-900 pb-20">
      {/* 1. TOP STICKY APP BAR */}
      <header className="sticky top-0 z-30 bg-white/95 backdrop-blur-md border-b border-slate-200/90 shadow-2xs">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <BackButton label="Dashboard" fallbackUrl="/seller" />

            <div className="hidden sm:flex items-center gap-2">
              <span className="text-slate-300">/</span>
              <span className="text-sm font-bold text-slate-900">
                Quality & Lab Reports
              </span>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <Badge
              variant="outline"
              className="bg-emerald-50 text-[#047857] border-emerald-200 font-bold text-xs gap-1.5 hidden sm:inline-flex"
            >
              <ShieldCheck className="h-3.5 w-3.5" />
              <span>Accredited COA Vault</span>
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
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 sm:py-8">
        <Suspense
          fallback={
            <div className="flex items-center justify-center py-20 bg-white rounded-3xl border border-slate-200">
              <div className="flex flex-col items-center gap-2">
                <Loader2 className="w-8 h-8 text-emerald-600 animate-spin" />
                <span className="text-xs text-slate-500 font-semibold">
                  Loading Centralized Quality Vault...
                </span>
              </div>
            </div>
          }
        >
          <SellerQualityVaultView initialReports={reports} />
        </Suspense>
      </main>
    </div>
  );
}
