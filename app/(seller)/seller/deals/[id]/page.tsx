import React, { Suspense } from "react";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ShieldCheck, Handshake, Loader2 } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { BackButton } from "@/src/components/ui/back-button";
import { db } from "@/src/server/db";
import { deals, quotations } from "@/src/server/db/schema";
import { eq, or } from "drizzle-orm";
import { getDealVersionSnapshotAction } from "@/src/server/actions/version-actions";
import { getBookingByDealIdAction } from "@/src/server/actions/booking-actions";
import { getMasterVehicleTypesAction } from "@/src/server/actions/master-data-actions";
import { SellerDealDetailView } from "@/src/components/dashboard/seller-deal-detail-view";

export const dynamic = "force-dynamic";

interface SellerDealPageProps {
  params: Promise<{ id: string }> | { id: string };
}

export default async function SellerDealPage({ params }: SellerDealPageProps) {
  const resolvedParams = await params;
  const dealId = resolvedParams.id;

  if (!dealId) {
    notFound();
  }

  // 1. Fetch deal or quotation record
  const dealRecord = await db.query.deals.findFirst({
    where: or(eq(deals.id, dealId), eq(deals.quotationId, dealId)),
  });

  const targetQuotationId = dealRecord ? dealRecord.quotationId : dealId;
  const quotationRecord = await db.query.quotations.findFirst({
    where: eq(quotations.id, targetQuotationId),
  });

  if (!dealRecord && !quotationRecord) {
    notFound();
  }

  // 2. Fetch latest version snapshot, booking, and master vehicle types in parallel
  const [snapshotRes, bookingRes, vehicleTypesRes] = await Promise.all([
    getDealVersionSnapshotAction(targetQuotationId),
    getBookingByDealIdAction(dealRecord ? dealRecord.id : targetQuotationId),
    getMasterVehicleTypesAction(),
  ]);

  const latestVersion = snapshotRes.success && snapshotRes.data ? snapshotRes.data : null;
  const booking = bookingRes.success && bookingRes.data ? bookingRes.data : null;
  const vehicleTypes = vehicleTypesRes.success && vehicleTypesRes.data ? vehicleTypesRes.data : [];

  // Synthesize consistent deal object for the view
  const dealData = {
    id: dealRecord ? dealRecord.id : quotationRecord!.id,
    requirementId: dealRecord?.requirementId || quotationRecord?.requirementId,
    quotationId: targetQuotationId,
    agreedPrice: dealRecord ? dealRecord.agreedPrice : quotationRecord?.offeredPrice || 0,
    agreedQuantity: Number(dealRecord?.agreedQuantity || (latestVersion?.snapshotPayload as any)?.quantity || 1),
    status: dealRecord?.status || quotationRecord?.status || "Draft",
    createdAt: dealRecord?.createdAt || quotationRecord?.createdAt || new Date(),
  };

  return (
    <div className="min-h-screen bg-[#F8FAFC] font-sans antialiased text-slate-900 pb-20">
      {/* TOP STICKY APP BAR */}
      <header className="sticky top-0 z-30 bg-white/95 backdrop-blur-md border-b border-slate-200/90 shadow-2xs">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <BackButton label="Back" fallbackUrl="/seller?tab=deals" />

            <div className="hidden sm:flex items-center gap-2">
              <span className="text-slate-300">/</span>
              <span className="text-sm font-bold text-slate-900">
                Deal #{dealData.id.substring(0, 8).toUpperCase()}
              </span>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <Badge
              variant="outline"
              className="bg-emerald-50 text-[#047857] border-emerald-200 font-bold text-xs gap-1.5 hidden sm:inline-flex"
            >
              <ShieldCheck className="h-3.5 w-3.5" />
              <span>Zero-Buyer Exposure Active</span>
            </Badge>
          </div>
        </div>
      </header>

      {/* HERO TITLE SECTION */}
      <div className="bg-white border-b border-slate-200/80">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-6 sm:py-8">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div className="space-y-1">
              <div className="flex items-center gap-2">
                <div className="w-7 h-7 rounded-lg bg-emerald-100 flex items-center justify-center text-[#047857]">
                  <Handshake className="w-4 h-4" />
                </div>
                <h1 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
                  Deal Details & Dispatch Status
                </h1>
              </div>
              <p className="text-xs sm:text-sm text-slate-500 leading-relaxed max-w-2xl">
                Review locked commercial terms and official booking references for your confirmed commodity trade.
              </p>
            </div>

            <div className="flex items-center gap-2">
              <Badge className="bg-slate-900 text-white font-bold text-xs px-3 py-1 rounded-lg">
                Status: {dealData.status}
              </Badge>
            </div>
          </div>
        </div>
      </div>

      {/* MAIN CONTENT AREA */}
      <main className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 pt-6 sm:pt-8">
        <Suspense
          fallback={
            <div className="flex items-center justify-center py-20">
              <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
            </div>
          }
        >
          <SellerDealDetailView
            deal={dealData}
            quotation={quotationRecord}
            latestVersion={latestVersion}
            booking={booking}
            vehicleTypes={vehicleTypes}
          />
        </Suspense>
      </main>
    </div>
  );
}
