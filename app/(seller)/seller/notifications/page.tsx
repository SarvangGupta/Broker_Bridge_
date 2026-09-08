import React, { Suspense } from "react";
import Link from "next/link";
import { Bell, ShieldCheck, LayoutDashboard, Sparkles, CheckCircle2 } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { BackButton } from "@/src/components/ui/back-button";
import { getSellerNotificationsAction } from "@/src/server/actions/notification-actions";
import { SellerActionCenterView } from "@/src/components/dashboard/seller-action-center-view";

export const dynamic = "force-dynamic";

export default async function SellerActionCenterPage() {
  const res = await getSellerNotificationsAction({ filter: "All" });
  const initialNotifications = res.success && res.data ? res.data.notifications : [];
  const initialCounts = res.success && res.data ? res.data.counts : {
    all: 0,
    unread: 0,
    urgent: 0,
    deals: 0,
    fulfillment: 0,
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
                Action Center
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
                <span>Command Center</span>
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
                <div className="w-9 h-9 rounded-xl bg-slate-900 flex items-center justify-center text-white shadow-xs">
                  <Bell className="w-4 h-4" />
                </div>
                <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight text-slate-900">
                  Seller Action Center
                </h1>
              </div>
              <p className="text-xs sm:text-sm text-slate-500 max-w-2xl">
                Operational notifications, urgent confirmation requests, logistics reminders, and financial settlement alerts.
              </p>
            </div>

            <div className="flex items-center gap-2">
              <Badge
                variant="outline"
                className="bg-slate-50 text-slate-700 border-slate-200 font-bold text-xs px-3 py-1 rounded-lg"
              >
                {initialCounts.unread} Unread Tasks
              </Badge>
            </div>
          </div>
        </div>
      </div>

      {/* 3. MAIN WORKSPACE CONTAINER */}
      <main className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <Suspense
          fallback={
            <div className="flex items-center justify-center py-20 bg-white rounded-3xl border border-slate-200">
              <span className="text-xs text-slate-500 font-semibold">
                Loading Action Center...
              </span>
            </div>
          }
        >
          <SellerActionCenterView
            initialNotifications={initialNotifications}
            initialCounts={initialCounts}
          />
        </Suspense>
      </main>
    </div>
  );
}
