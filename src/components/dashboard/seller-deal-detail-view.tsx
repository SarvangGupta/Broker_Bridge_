"use client";

import React, { useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import {
  Lock,
  Unlock,
  CheckCircle2,
  Copy,
  Check,
  Truck,
  ArrowLeft,
  FileCheck2,
  ShieldCheck,
  Calendar,
  Layers,
  IndianRupee,
  Building2,
  ExternalLink,
  Sparkles,
  Loader2,
  AlertCircle,
  HelpCircle,
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
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { SellerDispatchForm } from "@/src/components/forms/seller-dispatch-form";
import { createIdempotentBookingAction } from "@/src/server/actions/booking-actions";

export interface SellerDealDetailViewProps {
  deal: {
    id: string;
    requirementId?: string;
    quotationId?: string;
    agreedPrice: string | number;
    agreedQuantity: number;
    status: string;
    createdAt: string | Date;
    expectedDeliveryDate?: string | Date;
  };
  quotation?: {
    id: string;
    status: string;
    sellerAvailabilityId?: string;
  } | null;
  latestVersion?: {
    id: string;
    versionNumber: number;
    status: string;
    snapshotPayload: any;
    createdAt: string | Date;
  } | null;
  booking?: {
    id: string;
    bookingReference: string;
    status: string;
    lockedVersionId: string;
    createdAt: string | Date;
  } | null;
  vehicleTypes?: any[];
}

export function SellerDealDetailView({
  deal,
  quotation,
  latestVersion,
  booking: initialBooking,
  vehicleTypes = [],
}: SellerDealDetailViewProps) {
  const router = useRouter();
  const [booking, setBooking] = useState(initialBooking);
  const [copied, setCopied] = useState(false);
  const [isDispatchModalOpen, setIsDispatchModalOpen] = useState(false);
  const [isPending, startTransition] = useTransition();

  const snapshot = latestVersion?.snapshotPayload || {};
  const hasBooking = !!booking?.bookingReference;
  const isBrokerFinalized =
    deal.status === "Broker Finalized" ||
    quotation?.status === "Broker Finalized" ||
    latestVersion?.status === "Broker Finalized";

  const handleCopyBooking = () => {
    if (booking?.bookingReference) {
      navigator.clipboard.writeText(booking.bookingReference);
      setCopied(true);
      toast.success("Booking ID copied to clipboard!");
      setTimeout(() => setCopied(false), 2500);
    }
  };

  const handleCreateBooking = () => {
    startTransition(async () => {
      const targetId = deal.id || quotation?.id || "";
      const res = await createIdempotentBookingAction(targetId);
      if (res.success && res.bookingId) {
        toast.success(res.message || "Unique Booking ID issued successfully!");
        setBooking({
          id: res.data?.id || "new-booking",
          bookingReference: res.bookingId,
          status: "Confirmed",
          lockedVersionId: latestVersion?.id || "",
          createdAt: new Date().toISOString(),
        });
        router.refresh();
      } else {
        toast.error(res.error || "Failed to create booking.");
      }
    });
  };

  const commodityName =
    snapshot.commodityName || snapshot.commodity?.name || "Agricultural Commodity";
  const gradeName =
    snapshot.gradeName || snapshot.grade?.gradeName || "Standard Grade";
  const quantity = Number(deal.agreedQuantity || snapshot.quantity || 0);
  const unitSymbol = snapshot.unitSymbol || "MT";
  const rate = Number(deal.agreedPrice || snapshot.rate || 0);
  const totalValue = quantity * rate;
  const deliveryTerms = snapshot.deliveryTerms || "Ex-Warehouse";
  const paymentTerms =
    snapshot.paymentTerms || "Standard Escrow Settlement via Broker Desk";
  const deliveryDate =
    snapshot.deliveryDate || deal.expectedDeliveryDate
      ? new Date(
          snapshot.deliveryDate || deal.expectedDeliveryDate!
        ).toLocaleDateString("en-IN", {
          day: "numeric",
          month: "short",
          year: "numeric",
        })
      : "As scheduled";

  return (
    <div className="space-y-6">
      {/* 1. HIGH-VISIBILITY LOCKED BOOKING BANNER */}
      {hasBooking ? (
        <div className="relative overflow-hidden rounded-3xl bg-linear-to-r from-emerald-950 via-slate-900 to-emerald-900 text-white p-6 sm:p-8 shadow-xl border border-emerald-500/30">
          <div className="absolute top-0 right-0 -mt-8 -mr-8 w-48 h-48 bg-emerald-500/10 rounded-full blur-3xl pointer-events-none" />
          
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 relative z-10">
            <div className="space-y-3">
              <div className="flex items-center gap-2.5">
                <Badge className="bg-emerald-500/20 text-emerald-300 border-emerald-400/30 font-bold px-3 py-1 gap-1.5 backdrop-blur-md">
                  <Lock className="w-3.5 h-3.5 text-emerald-400" />
                  <span>IMMUTABLE BOOKING LOCKED</span>
                </Badge>
                <Badge
                  variant="outline"
                  className="bg-white/10 text-white border-white/20 text-xs font-mono"
                >
                  Version {latestVersion?.versionNumber || 1}
                </Badge>
              </div>

              <div>
                <span className="text-xs uppercase tracking-wider text-emerald-300/80 font-bold">
                  Official Booking Reference
                </span>
                <div className="flex items-center gap-3 mt-1">
                  <span className="text-2xl sm:text-4xl font-mono font-black tracking-tight text-white select-all">
                    {booking.bookingReference}
                  </span>
                  <Button
                    size="sm"
                    variant="ghost"
                    onClick={handleCopyBooking}
                    className="h-9 px-3 text-emerald-300 hover:text-white hover:bg-emerald-800/40 rounded-xl transition-all cursor-pointer"
                    title="Copy Booking ID"
                  >
                    {copied ? (
                      <Check className="w-4 h-4 text-emerald-400" />
                    ) : (
                      <Copy className="w-4 h-4" />
                    )}
                  </Button>
                </div>
              </div>

              <p className="text-xs sm:text-sm text-emerald-100/70 max-w-xl">
                This transaction has been permanently finalized and locked against Deal Version {latestVersion?.versionNumber || 1}. Inventory lot quantity is reserved. Dispatch operations are now unlocked.
              </p>
            </div>

            {/* ACTION BUTTON (SPRINT 19 UNLOCKED) */}
            <div className="flex flex-col sm:flex-row md:flex-col gap-3 min-w-[220px]">
              <Button
                onClick={() => setIsDispatchModalOpen(true)}
                className="w-full h-12 bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-black rounded-2xl flex items-center justify-center gap-2.5 shadow-lg shadow-emerald-950/40 cursor-pointer transition-all hover:scale-[1.02] active:scale-[0.98]"
              >
                <Truck className="w-5 h-5 text-slate-950" />
                <span>Proceed to Dispatch</span>
              </Button>

              <Link
                href={`/seller/deals/${deal.id || quotation?.id}/confirm`}
                className="w-full inline-flex items-center justify-center gap-2 text-xs font-bold text-slate-300 hover:text-white bg-white/10 hover:bg-white/15 h-10 rounded-xl transition-colors"
              >
                <FileCheck2 className="w-3.5 h-3.5" />
                <span>Review Deal Snapshot & Diff</span>
              </Link>
            </div>
          </div>
        </div>
      ) : (
        /* PENDING BOOKING BANNER */
        <div className="rounded-3xl bg-white border border-slate-200/90 p-6 sm:p-8 shadow-xs space-y-4">
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
            <div className="space-y-2">
              <div className="flex items-center gap-2.5">
                <Badge
                  variant="outline"
                  className={
                    isBrokerFinalized
                      ? "bg-amber-50 text-amber-800 border-amber-300 font-bold gap-1.5"
                      : "bg-slate-100 text-slate-700 border-slate-200 font-bold gap-1.5"
                  }
                >
                  <Lock className="w-3.5 h-3.5 text-slate-500" />
                  <span>
                    {isBrokerFinalized
                      ? "BROKER FINALIZED — READY FOR BOOKING ID"
                      : "PENDING FINAL CONFIRMATION & GATE"}
                  </span>
                </Badge>
                <Badge variant="outline" className="text-xs font-mono">
                  Version {latestVersion?.versionNumber || 1}
                </Badge>
              </div>

              <h2 className="text-xl font-black text-slate-900">
                Booking Reference Not Yet Issued
              </h2>
              <p className="text-xs sm:text-sm text-slate-500 max-w-xl">
                {isBrokerFinalized
                  ? "The Broker Desk has officially finalized the deal terms. Click below to issue the immutable Booking ID and unlock physical dispatch."
                  : "Dispatch operations remain locked until the Broker Finalization Gate is approved and an official Booking Reference is issued."}
              </p>
            </div>

            <div className="flex flex-col sm:flex-row md:flex-col gap-3 min-w-[220px]">
              {isBrokerFinalized ? (
                <Button
                  onClick={handleCreateBooking}
                  disabled={isPending}
                  className="w-full h-12 bg-slate-900 hover:bg-slate-800 text-white font-bold rounded-2xl flex items-center justify-center gap-2 shadow-md cursor-pointer"
                >
                  {isPending ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin text-emerald-400" />
                      <span>Issuing Booking ID...</span>
                    </>
                  ) : (
                    <>
                      <Sparkles className="w-4 h-4 text-emerald-400" />
                      <span>Issue Booking Reference</span>
                    </>
                  )}
                </Button>
              ) : (
                <Button
                  disabled
                  className="w-full h-12 bg-slate-100 text-slate-400 border border-slate-200 font-bold rounded-2xl flex items-center justify-center gap-2 cursor-not-allowed"
                >
                  <Lock className="w-4 h-4 text-slate-400" />
                  <span>Dispatch Locked</span>
                </Button>
              )}

              <Link
                href={`/seller/deals/${deal.id || quotation?.id}/confirm`}
                className="w-full inline-flex items-center justify-center gap-2 text-xs font-bold text-slate-700 hover:text-slate-950 bg-slate-100 hover:bg-slate-200 h-10 rounded-xl transition-colors"
              >
                <FileCheck2 className="w-3.5 h-3.5" />
                <span>Go to Confirmation Screen</span>
              </Link>
            </div>
          </div>
        </div>
      )}

      {/* 2. COMMERCIAL TERMS MATRIX */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* COMMODITY CARD */}
        <Card className="rounded-2xl border-slate-200/80 shadow-2xs">
          <CardHeader className="pb-3">
            <div className="flex items-center justify-between">
              <span className="text-[11px] font-bold uppercase tracking-wider text-slate-400">
                Commodity & Lot
              </span>
              <Layers className="w-4 h-4 text-slate-400" />
            </div>
            <CardTitle className="text-lg font-bold text-slate-900">
              {commodityName}
            </CardTitle>
            <CardDescription className="text-xs text-slate-500">
              {gradeName}
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3 pt-0">
            <div className="p-3 bg-slate-50 rounded-xl border border-slate-100 space-y-1">
              <div className="text-[10px] uppercase font-bold text-slate-400">
                Lot Identification
              </div>
              <div className="text-sm font-mono font-bold text-slate-900">
                Lot #{snapshot.lotNumber || "Standard Lot"}
              </div>
            </div>
            <div className="flex justify-between text-xs text-slate-600">
              <span>Lot Status:</span>
              <span className="font-bold text-emerald-700">Inventory Reserved</span>
            </div>
          </CardContent>
        </Card>

        {/* QUANTITY & RATE CARD */}
        <Card className="rounded-2xl border-slate-200/80 shadow-2xs">
          <CardHeader className="pb-3">
            <div className="flex items-center justify-between">
              <span className="text-[11px] font-bold uppercase tracking-wider text-slate-400">
                Volume & Rate
              </span>
              <IndianRupee className="w-4 h-4 text-slate-400" />
            </div>
            <CardTitle className="text-lg font-bold text-slate-900">
              ₹{rate.toLocaleString("en-IN")}{" "}
              <span className="text-xs font-normal text-slate-500">
                / {unitSymbol}
              </span>
            </CardTitle>
            <CardDescription className="text-xs text-slate-500">
              Agreed Order Volume: {quantity.toLocaleString("en-IN")} {unitSymbol}
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3 pt-0">
            <div className="p-3 bg-emerald-50/60 rounded-xl border border-emerald-100 space-y-1">
              <div className="text-[10px] uppercase font-bold text-emerald-800">
                Total Deal Gross Value
              </div>
              <div className="text-base font-bold text-emerald-950">
                ₹{totalValue.toLocaleString("en-IN")}
              </div>
            </div>
            <div className="flex justify-between text-xs text-slate-600">
              <span>Settlement:</span>
              <span className="font-bold text-slate-900">Broker Escrow Account</span>
            </div>
          </CardContent>
        </Card>

        {/* LOGISTICS & SCHEDULE CARD */}
        <Card className="rounded-2xl border-slate-200/80 shadow-2xs">
          <CardHeader className="pb-3">
            <div className="flex items-center justify-between">
              <span className="text-[11px] font-bold uppercase tracking-wider text-slate-400">
                Delivery & Settlement
              </span>
              <Calendar className="w-4 h-4 text-slate-400" />
            </div>
            <CardTitle className="text-lg font-bold text-slate-900">
              {deliveryTerms}
            </CardTitle>
            <CardDescription className="text-xs text-slate-500">
              Target Delivery: {deliveryDate}
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3 pt-0">
            <div className="p-3 bg-slate-50 rounded-xl border border-slate-100 space-y-1">
              <div className="text-[10px] uppercase font-bold text-slate-400">
                Payment Mechanism
              </div>
              <div className="text-xs font-medium text-slate-900 line-clamp-2">
                {paymentTerms}
              </div>
            </div>
            <div className="flex justify-between text-xs text-slate-600">
              <span>Buyer Exposure:</span>
              <span className="font-bold text-emerald-700">0% (Zero-PII Blind)</span>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* 3. DISPATCH MODAL (IF TRIGGERED) */}
      {isDispatchModalOpen && (
        <Dialog
          open={isDispatchModalOpen}
          onOpenChange={(open) => !open && setIsDispatchModalOpen(false)}
        >
          <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
            <DialogHeader>
              <div className="flex items-center gap-2 text-emerald-700">
                <Truck className="w-5 h-5" />
                <span className="text-xs font-bold uppercase tracking-wider">
                  Sprint 19 Dispatch Initiation
                </span>
              </div>
              <DialogTitle className="text-xl font-bold text-slate-900">
                Dispatch Order (Booking #{booking?.bookingReference || deal.id.substring(0, 8).toUpperCase()})
              </DialogTitle>
              <DialogDescription>
                Assign the transport vehicle, driver credentials, and upload the official dispatch invoice.
              </DialogDescription>
            </DialogHeader>
            <SellerDispatchForm
              dealId={deal.id}
              vehicleTypes={vehicleTypes}
              onSuccess={() => {
                setIsDispatchModalOpen(false);
                toast.success("Dispatch recorded successfully!");
                router.refresh();
              }}
            />
          </DialogContent>
        </Dialog>
      )}
    </div>
  );
}
