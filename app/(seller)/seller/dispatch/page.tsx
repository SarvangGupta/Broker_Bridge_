import React, { Suspense } from "react";
import Link from "next/link";
import { Truck, ShieldCheck, RefreshCw, LayoutDashboard } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { BackButton } from "@/src/components/ui/back-button";
import { getSellerBookedOrdersAction } from "@/src/server/actions/booking-actions";
import { BookedOrdersTable } from "@/src/components/dashboard/booked-orders-table";

export const dynamic = "force-dynamic";

export default async function SellerDispatchListPage() {
  const bookedOrdersRes = await getSellerBookedOrdersAction();
  const initialOrders = bookedOrdersRes.success && bookedOrdersRes.data ? bookedOrdersRes.data : [];

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
                Dispatch Management
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
                className="border-slate-300 font-bold text-xs rounded-xl h-9 gap-1.5"
              >
                <LayoutDashboard className="w-3.5 h-3.5 text-slate-600" />
                <span>Dashboard</span>
              </Button>
            </Link>
          </div>
        </div>
      </header>

      {/* 2. HERO BANNER */}
      <div className="bg-white border-b border-slate-200/80">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-6 sm:py-8">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div className="space-y-1">
              <div className="flex items-center gap-2">
                <div className="w-7 h-7 rounded-lg bg-emerald-100 flex items-center justify-center text-[#047857]">
                  <Truck className="w-4 h-4" />
                </div>
                <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
                  Sprint 19 Logistics & Settlement
                </span>
              </div>
              <h1 className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight">
                Orders & Dispatch Command
              </h1>
              <p className="text-xs sm:text-sm text-slate-500 max-w-2xl">
                Initiate dispatches against finalized, locked commercial bookings. Track vehicle license details, driver assignments, and shipment invoices.
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* 3. MAIN TABLE SECTION */}
      <main className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 pt-8">
        <Suspense
          fallback={
            <div className="p-8 text-center bg-white rounded-2xl border border-slate-200">
              <span className="text-xs text-slate-500 font-semibold">
                Loading Booked Orders...
              </span>
            </div>
          }
        >
          <BookedOrdersTable initialOrders={initialOrders} />
        </Suspense>
      </main>
    </div>
  );
}
