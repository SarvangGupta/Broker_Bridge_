"use client";

import React, { useState, useEffect, useTransition } from "react";
import {
  Truck,
  FileCheck2,
  Calendar,
  User,
  MapPin,
  Clock,
  CheckCircle2,
  AlertTriangle,
  AlertCircle,
  ExternalLink,
  ShieldCheck,
  Package,
  Layers,
  RefreshCw,
} from "lucide-react";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { Card, CardContent } from "@/components/ui/card";
import { FulfillmentDocumentUpload } from "@/src/components/forms/fulfillment-document-upload";
import {
  getDispatchTrackingAction,
  DispatchTrackingData,
} from "@/src/server/actions/dispatch-actions";
import { format } from "date-fns";
import { toast } from "sonner";
import { cn } from "@/lib/utils";

export interface DispatchDetailsSheetProps {
  dispatchId: string | null;
  bookingId?: string;
  isOpen: boolean;
  onOpenChange: (open: boolean) => void;
  initialData?: DispatchTrackingData | null;
}

const STEPS = [
  { id: "Dispatched", label: "Dispatched", description: "Vehicle departed from mill/warehouse" },
  { id: "In Transit", label: "In Transit", description: "Moving toward destination hub" },
  { id: "Delivered", label: "Delivered", description: "Delivery verified & signed off" },
];

export function DispatchDetailsSheet({
  dispatchId,
  bookingId,
  isOpen,
  onOpenChange,
  initialData,
}: DispatchDetailsSheetProps) {
  const [data, setData] = useState<DispatchTrackingData | null>(initialData || null);
  const [isLoading, setIsLoading] = useState<boolean>(!initialData && !!dispatchId);
  const [isPending, startTransition] = useTransition();

  const fetchTracking = async (id: string) => {
    setIsLoading(true);
    try {
      const res = await getDispatchTrackingAction(id);
      if (res.success && res.data) {
        setData(res.data);
      } else {
        toast.error(res.error || "Failed to load shipment details.");
      }
    } catch (err: any) {
      console.error("Failed to load dispatch details:", err);
      toast.error("Error loading shipment details.");
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    if (isOpen && dispatchId) {
      if (!initialData || initialData.dispatchId !== dispatchId) {
        fetchTracking(dispatchId);
      } else {
        setData(initialData);
        setIsLoading(false);
      }
    } else if (!isOpen) {
      setData(null);
    }
  }, [isOpen, dispatchId, initialData]);

  const effectiveBookingId =
    data?.bookingReference || data?.bookingId || bookingId || "BK-ACTIVE";

  return (
    <Sheet open={isOpen} onOpenChange={onOpenChange}>
      <SheetContent
        side="right"
        className="w-full sm:max-w-2xl overflow-y-auto p-0 border-l border-slate-200/90 bg-white"
      >
        {/* TOP HEADER */}
        <div className="sticky top-0 z-20 bg-white/95 backdrop-blur-md border-b border-slate-200/90 p-6 pb-4">
          <SheetHeader className="space-y-1 text-left">
            <div className="flex items-center justify-between gap-3">
              <div className="flex items-center gap-2">
                <div className="w-8 h-8 rounded-xl bg-emerald-100 flex items-center justify-center text-[#047857]">
                  <Truck className="w-4 h-4" />
                </div>
                <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
                  Shipment Telemetry
                </span>
              </div>

              {data && (
                <Badge
                  variant="outline"
                  className={cn(
                    "text-xs font-bold px-2.5 py-1",
                    data.isDisputed
                      ? "bg-rose-50 text-rose-700 border-rose-200"
                      : data.isDelayed
                      ? "bg-amber-50 text-amber-700 border-amber-200"
                      : data.status === "Delivered"
                      ? "bg-emerald-50 text-[#047857] border-emerald-200"
                      : "bg-blue-50 text-blue-700 border-blue-200"
                  )}
                >
                  {data.status}
                </Badge>
              )}
            </div>

            <SheetTitle className="text-xl font-black text-slate-900">
              {data ? `Vehicle: ${data.vehicleNumber}` : "Dispatch Details"}
            </SheetTitle>
            <SheetDescription className="text-xs text-slate-500">
              Booking Ref #{effectiveBookingId} • Immutable Contract Fulfillment
            </SheetDescription>
          </SheetHeader>
        </div>

        {/* BODY */}
        <div className="p-6 space-y-6">
          {isLoading ? (
            <div className="space-y-4">
              <Skeleton className="h-28 rounded-2xl w-full" />
              <div className="grid grid-cols-2 gap-3">
                <Skeleton className="h-20 rounded-xl" />
                <Skeleton className="h-20 rounded-xl" />
              </div>
              <Skeleton className="h-48 rounded-2xl w-full" />
            </div>
          ) : !data && dispatchId ? (
            <div className="p-8 text-center bg-slate-50 rounded-2xl border border-slate-200 space-y-3">
              <AlertCircle className="w-8 h-8 text-slate-400 mx-auto" />
              <div className="text-sm font-bold text-slate-800">
                Dispatch Record Not Found
              </div>
              <p className="text-xs text-slate-500 max-w-xs mx-auto">
                Unable to load telemetry for ID #{dispatchId}.
              </p>
            </div>
          ) : data ? (
            <>
              {/* 1. DISPUTE / DELAY ALERTS */}
              {data.isDisputed && (
                <div className="p-4 rounded-2xl bg-rose-50 border border-rose-200 text-left space-y-1">
                  <div className="flex items-center gap-2 text-rose-900 font-bold text-xs sm:text-sm">
                    <AlertCircle className="w-4 h-4 text-rose-700 shrink-0" />
                    <span>Quality / Delivery Dispute Flagged</span>
                  </div>
                  <p className="text-xs text-rose-800 leading-relaxed font-medium">
                    {data.dispute?.reason || "Please contact your Broker for dispute resolution."}
                  </p>
                </div>
              )}

              {data.isDelayed && !data.isDisputed && (
                <div className="p-4 rounded-2xl bg-amber-50 border border-amber-200 text-left space-y-1">
                  <div className="flex items-center gap-2 text-amber-900 font-bold text-xs sm:text-sm">
                    <AlertTriangle className="w-4 h-4 text-amber-700 shrink-0" />
                    <span>Transit Delay Reported</span>
                  </div>
                  <p className="text-xs text-amber-800 leading-relaxed">
                    {data.delayReason || "Carrier reported a route delay. Delivery timeline may adjust."}
                  </p>
                </div>
              )}

              {/* 2. THREE-STEP LIFECYCLE STEPPER */}
              <div className="p-5 rounded-2xl bg-slate-50 border border-slate-200/80 space-y-4">
                <div className="flex items-center justify-between text-xs font-bold text-slate-700">
                  <span className="uppercase tracking-wider">Shipment Lifecycle</span>
                  <span className="text-slate-400 font-normal">
                    Stage {data.stageIndex + 1} of 3
                  </span>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                  {STEPS.map((step, idx) => {
                    const isCompleted = data.stageIndex > idx || (data.stageIndex === 2 && idx === 2);
                    const isCurrent = data.stageIndex === idx && !(data.stageIndex === 2 && idx === 2);

                    return (
                      <div
                        key={step.id}
                        className={cn(
                          "p-3 rounded-xl border flex items-center gap-2.5 text-left transition-all",
                          isCompleted
                            ? "bg-emerald-50 border-emerald-200 text-emerald-950"
                            : isCurrent
                            ? "bg-blue-50 border-blue-200 text-blue-950 ring-2 ring-blue-500/20"
                            : "bg-white border-slate-200 text-slate-400"
                        )}
                      >
                        <div
                          className={cn(
                            "w-6 h-6 rounded-full flex items-center justify-center font-bold text-[10px] shrink-0",
                            isCompleted
                              ? "bg-[#047857] text-white"
                              : isCurrent
                              ? "bg-blue-600 text-white"
                              : "bg-slate-100 text-slate-400"
                          )}
                        >
                          {isCompleted ? <CheckCircle2 className="w-3.5 h-3.5" /> : idx + 1}
                        </div>
                        <div className="min-w-0">
                          <div className="text-xs font-bold truncate">{step.label}</div>
                          <div className="text-[10px] text-slate-500 leading-tight line-clamp-1">
                            {step.description}
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* 3. CORE DISPATCH METRICS (Vehicle Number, Driver, ETA, Volume) */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                {/* Tile 1: Vehicle & Transporter */}
                <div className="p-4 bg-slate-50 rounded-2xl border border-slate-100 space-y-1">
                  <div className="text-[10px] uppercase font-bold text-slate-400 flex items-center gap-1">
                    <Truck className="w-3 h-3 text-slate-400" />
                    <span>Assigned Vehicle</span>
                  </div>
                  <div className="text-sm font-mono font-black text-slate-900">
                    {data.vehicleNumber}
                  </div>
                  <div className="text-xs text-slate-500 truncate">
                    {data.transportCompany || "Commercial Logistics"}
                  </div>
                </div>

                {/* Tile 2: Driver Contact */}
                <div className="p-4 bg-slate-50 rounded-2xl border border-slate-100 space-y-1">
                  <div className="text-[10px] uppercase font-bold text-slate-400 flex items-center gap-1">
                    <User className="w-3 h-3 text-slate-400" />
                    <span>Driver Credentials</span>
                  </div>
                  <div className="text-sm font-bold text-slate-900">
                    {data.driverName}
                  </div>
                  <div className="text-xs font-mono text-slate-500">
                    {data.driverMobile}
                  </div>
                </div>

                {/* Tile 3: Schedule & ETA */}
                <div className="p-4 bg-slate-50 rounded-2xl border border-slate-100 space-y-1">
                  <div className="text-[10px] uppercase font-bold text-slate-400 flex items-center gap-1">
                    <Calendar className="w-3 h-3 text-slate-400" />
                    <span>Dispatch Date & ETA</span>
                  </div>
                  <div className="text-xs font-semibold text-slate-800">
                    Departed: {format(new Date(data.dispatchDate), "dd MMM yyyy")}
                  </div>
                  <div className="text-xs font-bold text-[#059669]">
                    ETA: {format(new Date(data.expectedDeliveryDate), "dd MMM yyyy")}
                  </div>
                </div>

                {/* Tile 4: Volume & Commodity */}
                <div className="p-4 bg-slate-50 rounded-2xl border border-slate-100 space-y-1">
                  <div className="text-[10px] uppercase font-bold text-slate-400 flex items-center gap-1">
                    <Layers className="w-3 h-3 text-slate-400" />
                    <span>Dispatched Volume</span>
                  </div>
                  <div className="text-sm font-black text-slate-900">
                    {data.dispatchQuantity.toLocaleString("en-IN")}{" "}
                    <span className="text-xs font-bold text-[#047857]">
                      {data.unitSymbol}
                    </span>
                  </div>
                  <div className="text-xs text-slate-500 truncate">
                    {data.commodityName} ({data.gradeName})
                  </div>
                </div>
              </div>

              {/* 4. FULFILLMENT DOCUMENTS & PROOF OF DELIVERY */}
              <div className="space-y-3 pt-2">
                <div className="flex items-center justify-between">
                  <h3 className="text-sm font-black text-slate-900 flex items-center gap-2">
                    <FileCheck2 className="w-4 h-4 text-[#047857]" />
                    <span>Fulfillment Documents & Proof of Delivery</span>
                  </h3>
                </div>

                <div className="p-4 bg-slate-50/70 rounded-2xl border border-slate-200/90">
                  <FulfillmentDocumentUpload
                    dispatchId={data.dispatchId}
                    bookingId={effectiveBookingId}
                  />
                </div>
              </div>
            </>
          ) : null}
        </div>
      </SheetContent>
    </Sheet>
  );
}
