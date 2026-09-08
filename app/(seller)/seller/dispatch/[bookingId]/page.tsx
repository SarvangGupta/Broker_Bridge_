import React from "react";
import Link from "next/link";
import {
  Truck,
  Lock,
  ShieldCheck,
  Package,
  Calendar,
  MapPin,
  IndianRupee,
  Layers,
  AlertCircle,
  CheckCircle2,
  FileCheck2,
  Building2,
  ArrowRight,
  Info,
} from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { BackButton } from "@/src/components/ui/back-button";
import { getBookingForDispatchAction } from "@/src/server/actions/booking-actions";
import { SellerDispatchForm } from "@/src/components/forms/seller-dispatch-form";
import { FulfillmentDocumentUpload } from "@/src/components/forms/fulfillment-document-upload";
import { LogisticsTracker } from "@/src/components/dashboard/logistics-tracker";
import { format } from "date-fns";

export const dynamic = "force-dynamic";

interface GatedDispatchPageProps {
  params: Promise<{ bookingId: string }> | { bookingId: string };
}

export default async function GatedDispatchPage({
  params,
}: GatedDispatchPageProps) {
  const resolvedParams = await params;
  const bookingIdOrReference = resolvedParams.bookingId;

  // 1. Execute the Dispatch Entry Gate Action
  const result = await getBookingForDispatchAction(bookingIdOrReference);

  // -------------------------------------------------------------
  // GATE REJECTION VIEW (Unbooked or unauthorized transaction)
  // -------------------------------------------------------------
  if (!result.success || !result.data) {
    return (
      <div className="min-h-screen bg-[#F8FAFC] font-sans antialiased text-slate-900 pb-20">
        <header className="sticky top-0 z-30 bg-white/95 backdrop-blur-md border-b border-slate-200/90 shadow-2xs">
          <div className="max-w-4xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
            <BackButton label="Back to Orders" fallbackUrl="/seller/dispatch" />
            <Badge
              variant="outline"
              className="bg-rose-50 text-rose-700 border-rose-200 font-bold text-xs gap-1.5"
            >
              <AlertCircle className="h-3.5 w-3.5" />
              <span>Gate Access Denied</span>
            </Badge>
          </div>
        </header>

        <main className="max-w-4xl mx-auto px-4 sm:px-6 pt-12">
          <Card className="border-rose-200 bg-white rounded-3xl shadow-sm overflow-hidden">
            <div className="h-2 w-full bg-rose-500" />
            <CardContent className="p-8 sm:p-12 text-center space-y-6">
              <div className="w-16 h-16 rounded-2xl bg-rose-100 flex items-center justify-center mx-auto text-rose-600">
                <Lock className="w-8 h-8" />
              </div>

              <div className="space-y-2 max-w-lg mx-auto">
                <h1 className="text-2xl font-black text-slate-900">
                  Dispatch Entry Gate Rejection
                </h1>
                <p className="text-sm text-slate-600 leading-relaxed">
                  {result.error ||
                    "Physical dispatches can only be initiated for transactions that have an active, immutable Booking ID issued by the Broker Finalization Gate."}
                </p>
              </div>

              <div className="p-4 rounded-2xl bg-amber-50 border border-amber-200 text-left max-w-lg mx-auto flex items-start gap-3">
                <Info className="w-5 h-5 text-amber-600 shrink-0 mt-0.5" />
                <div className="text-xs text-amber-900 space-y-1">
                  <div className="font-bold">Dispatch Rule (PRD v3.0 Section 19.1):</div>
                  <div>
                    No shipment or transport vehicle can be assigned to an unbooked or unfinalized quotation. Please ensure the Seller Confirmed terms and Broker Finalization have concluded.
                  </div>
                </div>
              </div>

              <div className="flex flex-col sm:flex-row items-center justify-center gap-3 pt-4">
                <Link href="/seller/dispatch">
                  <Button className="font-bold rounded-xl px-6 min-h-[48px] bg-slate-900 hover:bg-slate-800 text-white">
                    <span>View All Booked Orders</span>
                  </Button>
                </Link>
                <Link href="/seller?tab=deals">
                  <Button variant="outline" className="font-bold rounded-xl px-6 min-h-[48px] border-slate-300">
                    <span>Go to Deals & Quotations</span>
                  </Button>
                </Link>
              </div>
            </CardContent>
          </Card>
        </main>
      </div>
    );
  }

  const { booking, deal, quotation, lockedVersion, commercials, vehicleTypes, existingDispatches } =
    result.data;

  const formattedBookingDate = booking.createdAt
    ? format(new Date(booking.createdAt), "dd MMM yyyy, hh:mm a")
    : null;

  return (
    <div className="min-h-screen bg-[#F8FAFC] font-sans antialiased text-slate-900 pb-20">
      {/* 1. TOP STICKY HEADER */}
      <header className="sticky top-0 z-30 bg-white/95 backdrop-blur-md border-b border-slate-200/90 shadow-2xs">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <BackButton label="Back to Orders" fallbackUrl="/seller/dispatch" />

            <div className="hidden sm:flex items-center gap-2">
              <span className="text-slate-300">/</span>
              <span className="text-sm font-bold text-slate-900">
                Dispatch Order #{booking.bookingReference}
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

      {/* 2. HERO TITLE */}
      <div className="bg-white border-b border-slate-200/80">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-6 sm:py-8">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div className="space-y-1">
              <div className="flex items-center gap-2 flex-wrap">
                <div className="w-7 h-7 rounded-lg bg-emerald-100 flex items-center justify-center text-[#047857]">
                  <Truck className="w-4 h-4" />
                </div>
                <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
                  Micro-Sprint 19.1 Dispatch Entry Gate
                </span>
                <span className="text-slate-300">•</span>
                <span className="text-xs font-semibold text-emerald-700">
                  Gate Passed: Confirmed Booking ID
                </span>
              </div>
              <h1 className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight flex items-center gap-2">
                <span>Initiate Shipment Dispatch</span>
              </h1>
              <p className="text-xs sm:text-sm text-slate-500">
                Assign vehicle license, driver credentials, and generate the official dispatch record linked to Booking #{booking.bookingReference}.
              </p>
            </div>

            <div className="flex flex-col sm:items-end gap-1.5 shrink-0">
              <div className="flex items-center gap-2">
                <Badge className="bg-slate-900 text-white font-mono font-bold text-xs sm:text-sm px-3 py-1 rounded-xl shadow-xs gap-1.5">
                  <Lock className="w-3.5 h-3.5 text-emerald-400" />
                  <span>{booking.bookingReference}</span>
                </Badge>
              </div>
              {formattedBookingDate && (
                <div className="text-[11px] text-slate-400 font-medium">
                  Locked on {formattedBookingDate}
                </div>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* 3. MAIN WORKSPACE */}
      <main className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 pt-8 space-y-8">
        {/* SECTION A: READ-ONLY LOCKED TERMS REFERENCE HEADER */}
        <Card className="border-slate-200/90 rounded-3xl bg-white shadow-xs overflow-hidden">
          <div className="h-1.5 w-full bg-gradient-to-r from-emerald-500 via-teal-500 to-indigo-600" />
          <CardHeader className="p-5 sm:p-6 pb-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div className="space-y-1">
                <div className="flex items-center gap-2">
                  <Badge
                    variant="outline"
                    className="bg-emerald-50 text-[#047857] border-emerald-200 font-bold text-xs gap-1"
                  >
                    <Lock className="w-3 h-3" />
                    <span>Locked Commercial Supply Contract</span>
                  </Badge>
                  <Badge
                    variant="outline"
                    className="text-xs font-mono border-slate-200 text-slate-600"
                  >
                    Version {lockedVersion.versionNumber}
                  </Badge>
                </div>
                <CardTitle className="text-lg sm:text-xl font-bold text-slate-900">
                  Authoritative Deal Snapshot Reference
                </CardTitle>
              </div>

              <Link
                href={`/seller/deals/${deal.id}`}
                className="text-xs font-bold text-slate-600 hover:text-slate-900 inline-flex items-center gap-1.5 py-1.5 px-3 rounded-xl hover:bg-slate-100 transition-colors"
              >
                <FileCheck2 className="w-3.5 h-3.5 text-slate-500" />
                <span>View Full Version Snapshot</span>
              </Link>
            </div>
          </CardHeader>

          <CardContent className="p-5 sm:p-6 pt-0 space-y-4">
            {/* 4-COLUMN SUMMARY TILES */}
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
              {/* Tile 1: Commodity */}
              <div className="p-4 bg-slate-50 rounded-2xl border border-slate-100 space-y-1">
                <div className="text-[10px] uppercase font-bold text-slate-400">
                  Commodity & Quality
                </div>
                <div className="text-sm font-bold text-slate-900">
                  {commercials.commodityName}
                </div>
                <div className="text-xs text-slate-500">
                  {commercials.gradeName} • Lot #{commercials.lotNumber}
                </div>
              </div>

              {/* Tile 2: Booked Volume & Remaining */}
              <div className="p-4 bg-emerald-50/60 rounded-2xl border border-emerald-100 space-y-1">
                <div className="text-[10px] uppercase font-bold text-emerald-800">
                  Remaining / Booked Volume
                </div>
                <div className="text-base font-black text-emerald-950">
                  {commercials.remainingQuantity.toLocaleString("en-IN")}{" "}
                  <span className="text-xs font-bold text-emerald-700">
                    {commercials.unitSymbol} left
                  </span>
                </div>
                <div className="text-[11px] text-[#047857] font-semibold flex items-center gap-1">
                  <CheckCircle2 className="w-3 h-3" />
                  <span>Total Booked: {commercials.bookedQuantity} {commercials.unitSymbol}</span>
                </div>
              </div>

              {/* Tile 3: Commercial Rate */}
              <div className="p-4 bg-slate-50 rounded-2xl border border-slate-100 space-y-1">
                <div className="text-[10px] uppercase font-bold text-slate-400">
                  Locked Price / Rate
                </div>
                <div className="text-sm font-bold text-slate-900">
                  ₹{commercials.lockedRate.toLocaleString("en-IN")}{" "}
                  <span className="text-xs font-normal text-slate-500">
                    /{commercials.unitSymbol}
                  </span>
                </div>
                <div className="text-xs font-bold text-[#059669]">
                  Total: ₹{commercials.totalValuation.toLocaleString("en-IN", { maximumFractionDigits: 0 })}
                </div>
              </div>

              {/* Tile 4: Delivery Destination */}
              <div className="p-4 bg-slate-50 rounded-2xl border border-slate-100 space-y-1">
                <div className="text-[10px] uppercase font-bold text-slate-400 flex items-center gap-1">
                  <MapPin className="w-3 h-3 text-slate-400" />
                  <span>Destination & Freight</span>
                </div>
                <div className="text-sm font-bold text-slate-900 truncate" title={commercials.deliveryLocation}>
                  {commercials.deliveryLocation}
                </div>
                <div className="text-xs text-slate-500 truncate">
                  {commercials.deliveryTerms}
                </div>
              </div>
            </div>

            {/* PRE-FILL IMMUTABILITY BANNER */}
            <div className="p-3.5 rounded-xl bg-slate-100/70 border border-slate-200/80 flex items-start gap-2.5 text-xs text-slate-600">
              <ShieldCheck className="w-4 h-4 text-[#047857] shrink-0 mt-0.5" />
              <div>
                <span className="font-bold text-slate-800">
                  Dispatch Integrity Guarantee:
                </span>{" "}
                This dispatch is mathematically locked against Deal Version{" "}
                {lockedVersion.versionNumber}. Commercial quantities and rates are enforced from the immutable contract snapshot.
              </div>
            </div>
          </CardContent>
        </Card>

        {/* SECTION B: DISPATCH FORM ENTRY CARD OR FULLY DISPATCHED STATE */}
        {commercials.remainingQuantity <= 0 ? (
          <Card className="border-emerald-200/90 rounded-3xl bg-gradient-to-br from-emerald-50/70 via-white to-teal-50/40 shadow-xs overflow-hidden">
            <div className="h-1.5 w-full bg-emerald-500" />
            <CardContent className="p-8 text-center space-y-5">
              <div className="w-16 h-16 rounded-2xl bg-emerald-100 flex items-center justify-center mx-auto text-[#047857] shadow-2xs">
                <CheckCircle2 className="w-8 h-8" />
              </div>
              <div className="space-y-1.5 max-w-lg mx-auto">
                <Badge className="bg-emerald-100 text-emerald-800 border-emerald-300 font-bold text-xs uppercase tracking-wider px-3 py-1">
                  Contract 100% Fulfilled
                </Badge>
                <h2 className="text-2xl font-black text-slate-900 tracking-tight">
                  This Booking Has Been Fully Dispatched
                </h2>
                <p className="text-xs sm:text-sm text-slate-600 leading-relaxed">
                  This booking has been fully dispatched. No further trucks can be assigned. All <span className="font-bold text-slate-900">{commercials.bookedQuantity} {commercials.unitSymbol}</span> of this contract have been assigned to transport vehicles and recorded in transit.
                </p>
              </div>

              <div className="flex flex-col sm:flex-row items-center justify-center gap-3 pt-2">
                <Link href="/seller/dispatch">
                  <Button variant="outline" className="font-bold rounded-xl px-6 min-h-[48px] border-slate-200 bg-white hover:bg-slate-50 text-slate-800 shadow-2xs">
                    <span>Back to All Booked Orders</span>
                  </Button>
                </Link>
                <Link href="/seller/payments">
                  <Button className="font-bold rounded-xl px-6 min-h-[48px] bg-[#059669] hover:bg-[#047857] text-white shadow-xs">
                    <span>View Settlement Ledger & Invoices</span>
                  </Button>
                </Link>
              </div>
            </CardContent>
          </Card>
        ) : (
          <Card className="border-slate-200/90 rounded-3xl bg-white shadow-xs">
            <CardHeader className="p-6 pb-4">
              <div className="flex items-center gap-2 text-[#047857]">
                <Truck className="w-5 h-5" />
                <span className="text-xs font-bold uppercase tracking-wider">
                  Logistics & Transport Execution
                </span>
              </div>
              <CardTitle className="text-xl font-bold text-slate-900">
                Logistics & Vehicle Assignment
              </CardTitle>
              <CardDescription className="text-xs sm:text-sm text-slate-500">
                Enter the transport vehicle registration number, driver contact credentials, expected delivery ETA, and specify the dispatched volume.
              </CardDescription>
            </CardHeader>

            <CardContent className="p-6 pt-2">
              <SellerDispatchForm
                bookingId={booking.id}
                bookingReference={booking.bookingReference}
                dealId={deal.id}
                vehicleTypes={vehicleTypes}
                bookedQuantity={commercials.bookedQuantity}
                remainingQuantity={commercials.remainingQuantity}
                unitSymbol={commercials.unitSymbol}
                defaultLoadingLocation={commercials.deliveryLocation}
              />
            </CardContent>
          </Card>
        )}

        {/* SECTION C: EXISTING DISPATCHES & DOCUMENTS VAULT */}
        {existingDispatches.length > 0 && (
          <Card className="border-slate-200/90 rounded-3xl bg-white shadow-xs">
            <CardHeader className="p-6 pb-4">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                <div>
                  <CardTitle className="text-lg font-bold text-slate-900 flex items-center gap-2">
                    <Truck className="w-4 h-4 text-blue-600" />
                    <span>Recorded Shipment Dispatches ({existingDispatches.length})</span>
                  </CardTitle>
                  <CardDescription className="text-xs text-slate-500 mt-1">
                    {existingDispatches.length > 1
                      ? `This booked order is being fulfilled across ${existingDispatches.length} separate truck shipments. Each truck has its own vehicle details and dedicated Lorry Receipt (LR) document vault below.`
                      : "Shipment dispatch recorded for this booking. Upload and view verified Lorry Receipts (LRs), Tax Invoices, and E-Way Bills below."}
                  </CardDescription>
                </div>

                {existingDispatches.length > 1 && (
                  <Badge
                    variant="outline"
                    className="bg-blue-50 text-blue-700 border-blue-200 font-bold text-xs self-start sm:self-auto"
                  >
                    Multi-Shipment Order ({existingDispatches.length} Trucks)
                  </Badge>
                )}
              </div>
            </CardHeader>
            <CardContent className="p-6 pt-0 space-y-6">
              {existingDispatches.map((disp, idx) => (
                <div key={disp.id || idx}>
                  <LogisticsTracker dispatchId={disp.id} />
                </div>
              ))}
            </CardContent>
          </Card>
        )}
      </main>
    </div>
  );
}
