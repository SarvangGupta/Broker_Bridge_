"use client";

import React, { useEffect, useState, useTransition } from "react";
import {
  Truck,
  CheckCircle2,
  Clock,
  AlertTriangle,
  AlertCircle,
  MapPin,
  Calendar,
  ShieldCheck,
  RefreshCw,
  Phone,
  User,
  Building2,
  Package,
  Layers,
  ArrowRight,
  Info,
  FileCheck2,
} from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import {
  getDispatchTrackingAction,
  DispatchTrackingData,
} from "@/src/server/actions/dispatch-actions";
import { FulfillmentDocumentUpload } from "@/src/components/forms/fulfillment-document-upload";
import { format } from "date-fns";
import { cn } from "@/lib/utils";
import { toast } from "sonner";

interface LogisticsTrackerProps {
  dispatchId: string;
  initialData?: DispatchTrackingData;
  className?: string;
  showDocumentUpload?: boolean;
}

const STEPS = [
  { id: "Dispatched", label: "Dispatched", description: "Loading completed & vehicle departed" },
  { id: "In Transit", label: "In Transit", description: "Moving toward destination warehouse" },
  { id: "Delivered", label: "Delivered", description: "Physical delivery confirmed by Broker" },
];

export function LogisticsTracker({
  dispatchId,
  initialData,
  className = "",
  showDocumentUpload = true,
}: LogisticsTrackerProps) {
  const [data, setData] = useState<DispatchTrackingData | null>(initialData || null);
  const [isLoading, setIsLoading] = useState<boolean>(!initialData);
  const [isPending, startTransition] = useTransition();

  const fetchTracking = async () => {
    try {
      const res = await getDispatchTrackingAction(dispatchId);
      if (res.success && res.data) {
        setData(res.data);
      } else {
        toast.error(res.error || "Failed to load logistics tracking status.");
      }
    } catch (err) {
      console.error("Logistics tracking fetch error:", err);
      toast.error("Network error loading logistics tracking.");
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    if (!initialData) {
      fetchTracking();
    }
  }, [dispatchId]);

  const handleRefresh = () => {
    startTransition(async () => {
      await fetchTracking();
      toast.success("Logistics status refreshed.");
    });
  };

  if (isLoading) {
    return (
      <Card className={cn("rounded-3xl border-slate-200/90 bg-white shadow-xs", className)}>
        <CardHeader className="p-6 pb-4 space-y-3">
          <div className="flex justify-between items-center">
            <Skeleton className="h-5 w-40" />
            <Skeleton className="h-6 w-24 rounded-full" />
          </div>
          <Skeleton className="h-4 w-64" />
        </CardHeader>
        <CardContent className="p-6 pt-0 space-y-6">
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <Skeleton className="h-20 rounded-2xl" />
            <Skeleton className="h-20 rounded-2xl" />
            <Skeleton className="h-20 rounded-2xl" />
          </div>
          <Skeleton className="h-28 rounded-2xl" />
        </CardContent>
      </Card>
    );
  }

  if (!data) {
    return (
      <Card className={cn("rounded-3xl border-slate-200/90 bg-white p-6 text-center space-y-3", className)}>
        <AlertCircle className="w-8 h-8 text-slate-400 mx-auto" />
        <h4 className="text-sm font-bold text-slate-800">No Logistics Record Found</h4>
        <p className="text-xs text-slate-500 max-w-sm mx-auto">
          No active transit telemetry or dispatch record exists for this ID.
        </p>
        <Button
          onClick={handleRefresh}
          variant="outline"
          className="min-h-[48px] font-bold text-xs rounded-xl"
        >
          <RefreshCw className="w-3.5 h-3.5 mr-1.5" />
          Retry Fetch
        </Button>
      </Card>
    );
  }

  const {
    stageIndex,
    isDelayed,
    isDisputed,
    status,
    delayReason,
    dispute,
    vehicleNumber,
    driverName,
    driverMobile,
    dispatchDate,
    expectedDeliveryDate,
    commodityName,
    gradeName,
    lotNumber,
    dispatchQuantity,
    unitSymbol,
    destinationLocation,
  } = data;

  const isMultiShipment = (data.totalShipments || 1) > 1;

  return (
    <Card className={cn("rounded-3xl border-slate-200/90 bg-white shadow-xs overflow-hidden", className)}>
      {/* HEADER RIBBON */}
      <div
        className={cn(
          "h-1.5 w-full",
          isDisputed
            ? "bg-rose-500"
            : isDelayed
            ? "bg-amber-500"
            : status === "Delivered"
            ? "bg-[#047857]"
            : "bg-blue-600"
        )}
      />

      <CardHeader className="p-5 sm:p-6 pb-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div className="space-y-1">
            <div className="flex items-center gap-2 flex-wrap">
              <span className="text-[11px] font-bold uppercase tracking-wider text-slate-500 flex items-center gap-1.5">
                <Truck className="w-3.5 h-3.5 text-[#047857]" />
                <span>Logistics & Delivery Lifecycle</span>
              </span>
              <span className="text-slate-300">•</span>
              <Badge
                variant="outline"
                className="bg-emerald-50 text-[#047857] border-emerald-300 font-bold text-xs px-2 py-0.5"
              >
                Shipment {data.shipmentNumber || 1} of {data.totalShipments || 1}
              </Badge>
              <Badge
                variant="outline"
                className="bg-slate-100 text-slate-800 border-slate-200 font-mono text-xs font-bold px-2 py-0.5"
              >
                {dispatchQuantity} {unitSymbol} {data.isPartial ? "(Partial Load)" : "(Full Load)"}
              </Badge>
              <span className="text-[11px] font-mono text-slate-500">
                Booking #{data.bookingReference}
              </span>
            </div>

            <CardTitle className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2">
              <span>Shipment #{data.shipmentNumber || 1}: {vehicleNumber}</span>
              {data.transportCompany && (
                <span className="text-sm font-normal text-slate-500">({data.transportCompany})</span>
              )}
            </CardTitle>
            <CardDescription className="text-xs text-slate-600">
              Allocated volume: <strong className="text-slate-900 font-bold">{dispatchQuantity} {unitSymbol}</strong>
              {data.totalBookedQuantity && data.totalBookedQuantity !== dispatchQuantity && (
                <span> (out of {data.totalBookedQuantity} {unitSymbol} total booked order)</span>
              )}
              {" "}• {commodityName} ({gradeName} • Lot #{lotNumber})
            </CardDescription>
          </div>

          <div className="flex items-center gap-2.5">
            {isDisputed ? (
              <Badge className="bg-rose-100 text-rose-800 border-rose-200 font-bold text-xs gap-1 py-1 px-3">
                <AlertCircle className="w-3.5 h-3.5" />
                <span>Dispute Flagged</span>
              </Badge>
            ) : isDelayed ? (
              <Badge className="bg-amber-100 text-amber-800 border-amber-200 font-bold text-xs gap-1 py-1 px-3">
                <AlertTriangle className="w-3.5 h-3.5" />
                <span>Transit Delayed</span>
              </Badge>
            ) : status === "Delivered" ? (
              <Badge className="bg-emerald-100 text-emerald-800 border-emerald-200 font-bold text-xs gap-1 py-1 px-3">
                <CheckCircle2 className="w-3.5 h-3.5" />
                <span>Delivered & Verified</span>
              </Badge>
            ) : (
              <Badge className="bg-blue-100 text-blue-800 border-blue-200 font-bold text-xs gap-1 py-1 px-3">
                <Clock className="w-3.5 h-3.5" />
                <span>In Transit</span>
              </Badge>
            )}

            <Button
              onClick={handleRefresh}
              variant="ghost"
              size="sm"
              disabled={isPending}
              className="h-9 w-9 p-0 rounded-xl text-slate-500 hover:text-slate-900 cursor-pointer"
              title="Refresh tracking status"
            >
              <RefreshCw className={cn("w-4 h-4", isPending && "animate-spin")} />
            </Button>
          </div>
        </div>
      </CardHeader>

      <CardContent className="p-5 sm:p-6 pt-0 space-y-6">
        {/* 1. DISPUTE ALERT BANNER IF ACTIVE */}
        {isDisputed && (
          <div className="p-4 rounded-2xl bg-rose-50 border border-rose-200 text-left space-y-1.5">
            <div className="flex items-center gap-2 text-rose-900 font-bold text-xs sm:text-sm">
              <AlertCircle className="w-4 h-4 text-rose-700 shrink-0" />
              <span>Quality / Delivery Dispute Flagged</span>
            </div>
            <p className="text-xs text-rose-800 leading-relaxed font-medium">
              {dispute?.reason
                ? `Dispute recorded: "${dispute.reason}". Please contact your assigned Broker for resolution and settlement reconciliation.`
                : "Quality/Delivery Dispute: Please contact your Broker."}
            </p>
            {dispute?.description && (
              <p className="text-[11px] text-rose-700 font-normal">
                Notes: {dispute.description}
              </p>
            )}
          </div>
        )}

        {/* 2. DELAY ALERT BANNER IF ACTIVE */}
        {isDelayed && !isDisputed && (
          <div className="p-4 rounded-2xl bg-amber-50 border border-amber-200 text-left space-y-1">
            <div className="flex items-center gap-2 text-amber-900 font-bold text-xs sm:text-sm">
              <AlertTriangle className="w-4 h-4 text-amber-700 shrink-0" />
              <span>Transit Delay Reported</span>
            </div>
            <p className="text-xs text-amber-800 leading-relaxed">
              {delayReason || "Carrier reported a route or checkpoint delay. Expected delivery date may be revised by your Broker."}
            </p>
          </div>
        )}

        {/* 3. THREE-STEP SHIPMENT LIFECYCLE STEPPER */}
        <div className="p-5 sm:p-6 rounded-2xl bg-slate-50 border border-slate-100 space-y-6">
          <div className="flex items-center justify-between text-xs font-bold text-slate-700">
            <span className="uppercase tracking-wider">Shipment Stepper</span>
            <span className="text-slate-400 font-normal">
              Stage {stageIndex + 1} of 3
            </span>
          </div>

          <div className="relative">
            {/* Horizontal Line connector */}
            <div className="hidden sm:block absolute top-5 left-10 right-10 h-1 bg-slate-200 -z-0">
              <div
                className={cn(
                  "h-full transition-all duration-500",
                  isDisputed
                    ? "bg-rose-500"
                    : isDelayed
                    ? "bg-amber-500"
                    : "bg-[#047857]"
                )}
                style={{
                  width: `${(stageIndex / (STEPS.length - 1)) * 100}%`,
                }}
              />
            </div>

            {/* Stepper items */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-6 relative z-10">
              {STEPS.map((step, idx) => {
                const isCompleted = stageIndex > idx || (stageIndex === 2 && idx === 2);
                const isCurrent = stageIndex === idx && !(stageIndex === 2 && idx === 2);

                let badgeStyle = "bg-white border-2 border-slate-200 text-slate-400";
                if (isCompleted) {
                  badgeStyle = "bg-[#047857] border-2 border-[#047857] text-white";
                } else if (isCurrent) {
                  if (isDisputed) {
                    badgeStyle = "bg-rose-600 border-2 border-rose-600 text-white animate-pulse";
                  } else if (isDelayed) {
                    badgeStyle = "bg-amber-500 border-2 border-amber-500 text-white";
                  } else {
                    badgeStyle = "bg-blue-600 border-2 border-blue-600 text-white ring-4 ring-blue-100";
                  }
                }

                return (
                  <div key={step.id} className="flex sm:flex-col items-center sm:text-center gap-3 sm:gap-2">
                    <div
                      className={cn(
                        "w-10 h-10 rounded-full flex items-center justify-center font-bold text-xs shrink-0 shadow-2xs transition-all",
                        badgeStyle
                      )}
                    >
                      {isCompleted ? (
                        <CheckCircle2 className="w-5 h-5 stroke-[2.5]" />
                      ) : (
                        <span>0{idx + 1}</span>
                      )}
                    </div>

                    <div className="space-y-0.5 min-w-0">
                      <div className="text-xs sm:text-sm font-bold text-slate-900 flex items-center gap-1.5 sm:justify-center">
                        <span>{step.label}</span>
                        {isCurrent && (
                          <span
                            className={cn(
                              "text-[10px] px-1.5 py-0.2 rounded font-bold uppercase",
                              isDisputed
                                ? "bg-rose-100 text-rose-800"
                                : isDelayed
                                ? "bg-amber-100 text-amber-800"
                                : "bg-blue-100 text-blue-800"
                            )}
                          >
                            Current
                          </span>
                        )}
                      </div>
                      <p className="text-[11px] text-slate-500 leading-tight">
                        {step.description}
                      </p>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>

        {/* 4. DRIVER & LOGISTICS METADATA TILES (Zero Buyer Exposure) */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
          {/* Tile 1: Vehicle & Transport */}
          <div className="p-3.5 bg-slate-50 rounded-xl border border-slate-100 space-y-1">
            <div className="text-[10px] uppercase font-bold text-slate-400 flex items-center gap-1">
              <Truck className="w-3 h-3 text-slate-400" />
              <span>Assigned Vehicle</span>
            </div>
            <div className="text-xs font-mono font-bold text-slate-900">
              {vehicleNumber}
            </div>
            <div className="text-[11px] text-slate-500 truncate">
              {data.transportCompany || "Commercial Transporter"}
            </div>
          </div>

          {/* Tile 2: Driver Contact */}
          <div className="p-3.5 bg-slate-50 rounded-xl border border-slate-100 space-y-1">
            <div className="text-[10px] uppercase font-bold text-slate-400 flex items-center gap-1">
              <User className="w-3 h-3 text-slate-400" />
              <span>Driver Credentials</span>
            </div>
            <div className="text-xs font-bold text-slate-900">
              {driverName}
            </div>
            <div className="text-[11px] font-mono text-slate-500">
              {driverMobile}
            </div>
          </div>

          {/* Tile 3: Dispatch & ETA Dates */}
          <div className="p-3.5 bg-slate-50 rounded-xl border border-slate-100 space-y-1">
            <div className="text-[10px] uppercase font-bold text-slate-400 flex items-center gap-1">
              <Calendar className="w-3 h-3 text-slate-400" />
              <span>Schedule & ETA</span>
            </div>
            <div className="text-xs font-semibold text-slate-800">
              Dispatched: {format(new Date(dispatchDate), "dd MMM yyyy")}
            </div>
            <div className="text-[11px] font-semibold text-slate-500">
              ETA: {format(new Date(expectedDeliveryDate), "dd MMM yyyy")}
            </div>
          </div>

          {/* Tile 4: Destination & Delivery Terms */}
          <div className="p-3.5 bg-slate-50 rounded-xl border border-slate-100 space-y-1">
            <div className="text-[10px] uppercase font-bold text-slate-400 flex items-center gap-1">
              <MapPin className="w-3 h-3 text-slate-400" />
              <span>Delivery Hub</span>
            </div>
            <div className="text-xs font-bold text-slate-900 truncate" title={destinationLocation}>
              {destinationLocation}
            </div>
            <div className="text-[11px] text-[#047857] font-semibold">
              Broker / Admin Confirmed Gate
            </div>
          </div>
        </div>

        {/* 5. FULFILLMENT DOCUMENTS & PROOF OF DELIVERY */}
        {showDocumentUpload && (
          <div className="space-y-3 pt-2">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-1 pb-2 border-b border-slate-200/80">
              <div className="space-y-0.5">
                <h4 className="text-xs font-bold uppercase tracking-wider text-slate-900 flex items-center gap-1.5">
                  <FileCheck2 className="w-4 h-4 text-[#047857]" />
                  <span>
                    Fulfillment Documents • Shipment #{data.shipmentNumber || 1} ({dispatchQuantity} {unitSymbol} on {vehicleNumber})
                  </span>
                </h4>
                <p className="text-[11px] text-slate-500">
                  Upload the Lorry Receipt (LR/Bilty), Weight Slip, or E-Way Bill specific to vehicle {vehicleNumber}.
                </p>
              </div>
              <Badge
                variant="outline"
                className="bg-slate-50 text-slate-700 border-slate-200 text-[10px] font-bold self-start sm:self-auto"
              >
                Truck Load: {dispatchQuantity} {unitSymbol}
              </Badge>
            </div>

            <div className="p-4 bg-slate-50/70 rounded-2xl border border-slate-200/90">
              <FulfillmentDocumentUpload
                dispatchId={data.dispatchId}
                bookingId={data.bookingReference || data.bookingId}
              />
            </div>
          </div>
        )}

        {/* 6. READ-ONLY NOTICE FOR SELLER */}
        <div className="p-3 rounded-xl bg-slate-100/70 border border-slate-200/80 flex items-start gap-2.5 text-xs text-slate-600">
          <Info className="w-4 h-4 text-slate-500 shrink-0 mt-0.5" />
          <div>
            <span className="font-bold text-slate-800">Read-Only Life Cycle:</span> Delivery confirmation and acceptance signatures are verified by the receiving hub and authorized by the Broker. You will be notified automatically upon final settlement reconciliation.
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
