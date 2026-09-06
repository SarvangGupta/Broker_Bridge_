"use client";

import React, { useEffect, useState } from "react";
import {
  Package,
  FlaskConical,
  Truck,
  CreditCard,
  FileText,
  ShieldCheck,
  CheckCircle2,
  Clock,
  ArrowUpDown,
  Award,
  AlertCircle,
  Calendar,
  Layers,
  MapPin,
  RefreshCw,
  Info,
} from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { getDealVersionSnapshotAction } from "@/src/server/actions/version-actions";
import { DealVersionRecord, DealVersionSnapshot, DealVersionStatus } from "@/src/types/deal-version-schema";
import { format } from "date-fns";

interface FinalDealSnapshotProps {
  versionId: string;
  initialData?: DealVersionRecord | null;
  className?: string;
  onRefresh?: () => void;
}

export function FinalDealSnapshot({
  versionId,
  initialData,
  className = "",
  onRefresh,
}: FinalDealSnapshotProps) {
  const [record, setRecord] = useState<DealVersionRecord | null>(initialData || null);
  const [isLoading, setIsLoading] = useState<boolean>(!initialData);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!initialData && versionId) {
      loadSnapshot();
    }
  }, [versionId, initialData]);

  async function loadSnapshot() {
    setIsLoading(true);
    setError(null);
    try {
      const res = await getDealVersionSnapshotAction(versionId);
      if (res.success && res.data) {
        setRecord(res.data);
      } else {
        setError(res.error || "Failed to load deal version snapshot.");
      }
    } catch (err: any) {
      setError(err.message || "An unexpected error occurred while fetching deal terms.");
    } finally {
      setIsLoading(false);
    }
  }

  // Status Badge Formatter
  const getStatusBadge = (status: DealVersionStatus) => {
    switch (status) {
      case "Proposed":
        return (
          <Badge className="bg-amber-500/10 text-amber-700 border-amber-300 font-semibold gap-1.5 px-3 py-1">
            <Clock className="w-3.5 h-3.5 text-amber-600" />
            <span>Proposed Terms</span>
          </Badge>
        );
      case "Countered":
        return (
          <Badge className="bg-purple-500/10 text-purple-700 border-purple-300 font-semibold gap-1.5 px-3 py-1">
            <ArrowUpDown className="w-3.5 h-3.5 text-purple-600" />
            <span>Counter-Proposal</span>
          </Badge>
        );
      case "Seller Confirmed":
        return (
          <Badge className="bg-emerald-500/10 text-[#047857] border-emerald-300 font-semibold gap-1.5 px-3 py-1">
            <CheckCircle2 className="w-3.5 h-3.5 text-[#047857]" />
            <span>Seller Confirmed</span>
          </Badge>
        );
      case "Buyer Confirmed":
        return (
          <Badge className="bg-blue-500/10 text-blue-700 border-blue-300 font-semibold gap-1.5 px-3 py-1">
            <CheckCircle2 className="w-3.5 h-3.5 text-blue-600" />
            <span>Buyer Confirmed</span>
          </Badge>
        );
      case "Broker Finalized":
        return (
          <Badge className="bg-teal-500/10 text-teal-700 border-teal-300 font-semibold gap-1.5 px-3 py-1">
            <Award className="w-3.5 h-3.5 text-teal-600" />
            <span>Broker Finalized</span>
          </Badge>
        );
      case "Superseded":
        return (
          <Badge className="bg-slate-100 text-slate-600 border-slate-300 font-semibold gap-1.5 px-3 py-1">
            <Clock className="w-3.5 h-3.5 text-slate-500" />
            <span>Superseded (Historical)</span>
          </Badge>
        );
      default:
        return (
          <Badge variant="outline" className="font-semibold px-3 py-1">
            {status}
          </Badge>
        );
    }
  };

  if (isLoading) {
    return (
      <div className={`space-y-6 ${className}`}>
        {/* Header Skeleton */}
        <Card className="border-slate-200 shadow-xs">
          <CardHeader className="space-y-3 pb-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
              <div className="space-y-2">
                <Skeleton className="h-6 w-48" />
                <Skeleton className="h-4 w-72" />
              </div>
              <Skeleton className="h-8 w-36 rounded-full" />
            </div>
          </CardHeader>
        </Card>

        {/* Core Terms Skeleton */}
        <Card className="border-slate-200 shadow-xs">
          <CardHeader className="pb-3">
            <Skeleton className="h-5 w-40" />
          </CardHeader>
          <CardContent className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {Array.from({ length: 6 }).map((_, i) => (
              <Skeleton key={i} className="h-20 w-full rounded-xl" />
            ))}
          </CardContent>
        </Card>

        {/* Quality & Logistics Skeletons */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <Card className="border-slate-200 shadow-xs">
            <CardHeader className="pb-3">
              <Skeleton className="h-5 w-48" />
            </CardHeader>
            <CardContent className="space-y-3">
              <Skeleton className="h-16 w-full rounded-xl" />
              <Skeleton className="h-16 w-full rounded-xl" />
            </CardContent>
          </Card>
          <Card className="border-slate-200 shadow-xs">
            <CardHeader className="pb-3">
              <Skeleton className="h-5 w-48" />
            </CardHeader>
            <CardContent className="space-y-3">
              <Skeleton className="h-16 w-full rounded-xl" />
              <Skeleton className="h-16 w-full rounded-xl" />
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  if (error || !record) {
    return (
      <Card className="border-rose-200 bg-rose-50/50 shadow-xs">
        <CardContent className="py-12 flex flex-col items-center text-center space-y-4">
          <div className="w-12 h-12 rounded-full bg-rose-100 flex items-center justify-center text-rose-600">
            <AlertCircle className="w-6 h-6" />
          </div>
          <div className="space-y-1 max-w-md">
            <h3 className="text-base font-bold text-slate-900">Unable to Load Deal Version Snapshot</h3>
            <p className="text-sm text-slate-600 leading-relaxed">
              {error || "The requested deal version could not be found or you do not have permission to view it."}
            </p>
          </div>
          <Button
            onClick={() => loadSnapshot()}
            variant="outline"
            className="border-slate-300 font-semibold gap-2 rounded-xl mt-2"
          >
            <RefreshCw className="w-4 h-4" />
            <span>Try Again</span>
          </Button>
        </CardContent>
      </Card>
    );
  }

  const snap: DealVersionSnapshot = record.snapshotPayload;
  const totalValuation =
    typeof snap.quantity === "number" && typeof snap.rate === "number"
      ? snap.quantity * snap.rate
      : null;

  const formattedDate = record.createdAt
    ? format(new Date(record.createdAt), "dd MMM yyyy, hh:mm a")
    : null;

  const originatorDisplay =
    snap.originatorRole === "seller" || record.actorRole?.includes("seller")
      ? "Proposed by You (Seller)"
      : "Prepared by Broker Desk";

  return (
    <div className={`space-y-6 ${className}`}>
      {/* 1. IMMUTABLE SNAPSHOT HEADER BANNER */}
      <Card className="border-slate-200/90 bg-white shadow-xs overflow-hidden">
        <div className="h-1.5 w-full bg-gradient-to-r from-emerald-500 via-teal-500 to-indigo-600" />
        <CardHeader className="p-4 sm:p-6 pb-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div className="space-y-1">
              <div className="flex items-center gap-2.5 flex-wrap">
                <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
                  Immutable Commercial Snapshot
                </span>
                <span className="text-slate-300">•</span>
                <span className="text-xs font-semibold text-slate-600">{originatorDisplay}</span>
              </div>
              <h2 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight flex items-center gap-2">
                <span>Deal Version {record.versionNumber}</span>
                {snap.lotNumber && (
                  <Badge variant="outline" className="text-xs font-bold border-slate-300 bg-slate-50 text-slate-700">
                    Lot #{snap.lotNumber}
                  </Badge>
                )}
              </h2>
              {formattedDate && (
                <div className="flex items-center gap-1.5 text-xs text-slate-500 pt-0.5">
                  <Calendar className="w-3.5 h-3.5 text-slate-400" />
                  <span>Frozen on {formattedDate}</span>
                </div>
              )}
            </div>

            <div className="flex flex-col sm:items-end gap-2 shrink-0">
              <div className="flex items-center gap-2">
                {getStatusBadge(record.status)}
              </div>
              <div className="flex items-center gap-1.5 text-[11px] font-semibold text-emerald-700 bg-emerald-50 border border-emerald-200/80 px-2.5 py-1 rounded-lg">
                <ShieldCheck className="w-3.5 h-3.5 text-[#047857]" />
                <span>Zero Buyer PII Exposed</span>
              </div>
            </div>
          </div>
        </CardHeader>
      </Card>

      {/* 2. GROUP 1: CORE PRODUCT & COMMERCIAL TERMS */}
      <Card className="border-slate-200 shadow-xs">
        <CardHeader className="p-4 sm:p-5 border-b border-slate-100 bg-slate-50/50">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <div className="w-8 h-8 rounded-lg bg-emerald-100/80 flex items-center justify-center text-[#047857]">
                <Package className="w-4 h-4 stroke-[2.25]" />
              </div>
              <div>
                <CardTitle className="text-base font-bold text-slate-900">
                  Core Commodity & Commercial Terms
                </CardTitle>
                <CardDescription className="text-xs text-slate-500">
                  Primary specifications and negotiated pricing
                </CardDescription>
              </div>
            </div>
          </div>
        </CardHeader>

        <CardContent className="p-4 sm:p-6 space-y-4">
          {/* Commodity & Sector Breadcrumb */}
          <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200/80 flex flex-col sm:flex-row sm:items-center justify-between gap-2">
            <div className="space-y-0.5">
              <div className="text-[11px] font-bold uppercase tracking-wider text-slate-400">
                Sector Hierarchy
              </div>
              <div className="text-xs font-semibold text-slate-600">
                {snap.industryName || "Agri & Commodities"} • {snap.categoryName || "Grains & Pulses"}
              </div>
            </div>
            <div className="sm:text-right">
              <div className="text-[11px] font-bold uppercase tracking-wider text-slate-400">
                Commodity Name
              </div>
              <div className="text-base font-black text-slate-900">{snap.commodityName}</div>
            </div>
          </div>

          {/* Key Terms 3-Column Grid */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3.5">
            {/* Quantity */}
            <div className="p-4 rounded-xl border border-slate-200/80 bg-white shadow-2xs space-y-1">
              <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
                Agreed Quantity
              </span>
              <div className="text-2xl font-black text-slate-900">
                {snap.quantity?.toLocaleString("en-IN")}{" "}
                <span className="text-sm font-bold text-slate-600">{snap.unitSymbol || "MT"}</span>
              </div>
              <p className="text-[11px] text-slate-500">Lot-level allocated supply</p>
            </div>

            {/* Agreed Rate */}
            <div className="p-4 rounded-xl border border-emerald-200/90 bg-emerald-50/40 shadow-2xs space-y-1">
              <span className="text-xs font-bold uppercase tracking-wider text-emerald-800">
                Final Agreed Rate
              </span>
              <div className="text-2xl font-black text-[#047857]">
                ₹{snap.rate?.toLocaleString("en-IN")}
                <span className="text-xs font-bold text-[#047857] ml-1">/{snap.unitSymbol || "MT"}</span>
              </div>
              <p className="text-[11px] text-emerald-700 font-medium">Excluding applicable taxes</p>
            </div>

            {/* Total Estimated Valuation */}
            <div className="p-4 rounded-xl border border-slate-200/80 bg-slate-900 text-white shadow-2xs space-y-1 sm:col-span-2 lg:col-span-1">
              <span className="text-xs font-bold uppercase tracking-wider text-slate-300">
                Total Deal Valuation
              </span>
              <div className="text-2xl font-black text-white">
                {totalValuation !== null ? `₹${totalValuation.toLocaleString("en-IN", { maximumFractionDigits: 2 })}` : "N/A"}
              </div>
              <p className="text-[11px] text-slate-300">Gross contract value</p>
            </div>
          </div>

          {/* Secondary Details Row */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5 pt-1">
            <div className="p-3 rounded-xl border border-slate-200/70 bg-slate-50/60">
              <span className="text-[11px] font-bold uppercase tracking-wider text-slate-400 block mb-0.5">
                Quality Grade / Spec Label
              </span>
              <span className="text-sm font-bold text-slate-800">
                {snap.gradeName || "Standard Quality Grade"}
              </span>
            </div>

            <div className="p-3 rounded-xl border border-slate-200/70 bg-slate-50/60">
              <span className="text-[11px] font-bold uppercase tracking-wider text-slate-400 block mb-0.5">
                Traceable Lot Reference
              </span>
              <span className="text-sm font-bold text-slate-800">
                {snap.lotNumber ? `Lot #${snap.lotNumber}` : "Single Lot Supply"}
              </span>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* 3. GROUP 2 & GROUP 3: QUALITY & LOGISTICS (2-COL ON DESKTOP) */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        
        {/* GROUP 2: QUALITY & LAB TESTING */}
        <Card className="border-slate-200 shadow-xs flex flex-col">
          <CardHeader className="p-4 sm:p-5 border-b border-slate-100 bg-slate-50/50">
            <div className="flex items-center gap-2.5">
              <div className="w-8 h-8 rounded-lg bg-blue-100/80 flex items-center justify-center text-blue-700">
                <FlaskConical className="w-4 h-4 stroke-[2.25]" />
              </div>
              <div>
                <CardTitle className="text-base font-bold text-slate-900">
                  Quality & Lab Specifications
                </CardTitle>
                <CardDescription className="text-xs text-slate-500">
                  Commodity lab parameters & test evidence
                </CardDescription>
              </div>
            </div>
          </CardHeader>

          <CardContent className="p-4 sm:p-5 space-y-4 flex-1">
            {/* Dynamic Quality Parameters List */}
            {snap.qualityParameters && snap.qualityParameters.length > 0 ? (
              <div className="space-y-2">
                <div className="text-xs font-bold uppercase tracking-wider text-slate-500">
                  Dynamic Parameter Results
                </div>
                <div className="divide-y divide-slate-100 border border-slate-200/80 rounded-xl overflow-hidden bg-white">
                  {snap.qualityParameters.map((param, idx) => (
                    <div
                      key={idx}
                      className="p-3 flex items-center justify-between gap-3 text-xs"
                    >
                      <div className="space-y-0.5">
                        <span className="font-bold text-slate-800">{param.name}</span>
                        {param.source && (
                          <span className="text-[10px] text-slate-500 block">
                            Source: {param.source}
                          </span>
                        )}
                      </div>
                      <Badge variant="secondary" className="font-bold text-slate-900 bg-slate-100 text-xs">
                        {param.value} {param.unit || ""}
                      </Badge>
                    </div>
                  ))}
                </div>
              </div>
            ) : (
              <div className="p-3.5 rounded-xl border border-slate-200/70 bg-slate-50 text-xs text-slate-600 flex items-center gap-2.5">
                <Info className="w-4 h-4 text-slate-400 shrink-0" />
                <span>Standard fair average quality (FAQ) specifications apply as declared in listing.</span>
              </div>
            )}

            {/* Quality Notes */}
            {snap.qualityNotes && (
              <div className="p-3 rounded-xl bg-blue-50/50 border border-blue-100 text-xs space-y-1">
                <span className="font-bold text-blue-900 uppercase tracking-wider text-[10px]">
                  Quality Notes & Tolerance
                </span>
                <p className="text-slate-700 leading-relaxed">{snap.qualityNotes}</p>
              </div>
            )}

            {/* Evidence Verification Callout */}
            <div className="p-3 rounded-xl bg-emerald-50 border border-emerald-200/70 flex items-center justify-between gap-2 text-xs text-[#047857] font-semibold mt-auto">
              <div className="flex items-center gap-2">
                <ShieldCheck className="w-4 h-4 text-[#047857] shrink-0" />
                <span>Quality Evidence Status:</span>
              </div>
              <Badge className="bg-emerald-600 text-white font-bold text-[10px] uppercase">
                COA / Lab Verified
              </Badge>
            </div>
          </CardContent>
        </Card>

        {/* GROUP 3: LOGISTICS & LOADING READINESS */}
        <Card className="border-slate-200 shadow-xs flex flex-col">
          <CardHeader className="p-4 sm:p-5 border-b border-slate-100 bg-slate-50/50">
            <div className="flex items-center gap-2.5">
              <div className="w-8 h-8 rounded-lg bg-indigo-100/80 flex items-center justify-center text-indigo-700">
                <Truck className="w-4 h-4 stroke-[2.25]" />
              </div>
              <div>
                <CardTitle className="text-base font-bold text-slate-900">
                  Logistics & Delivery Schedule
                </CardTitle>
                <CardDescription className="text-xs text-slate-500">
                  Dispatch origin, delivery window & freight terms
                </CardDescription>
              </div>
            </div>
          </CardHeader>

          <CardContent className="p-4 sm:p-5 space-y-3.5 flex-1">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              {/* Delivery Date */}
              <div className="p-3 rounded-xl border border-slate-200/80 bg-white">
                <span className="text-[11px] font-bold uppercase tracking-wider text-slate-400 block mb-0.5">
                  Target Delivery Date
                </span>
                <div className="flex items-center gap-1.5 text-sm font-bold text-slate-900">
                  <Calendar className="w-3.5 h-3.5 text-indigo-600" />
                  <span>
                    {snap.deliveryDate
                      ? format(new Date(snap.deliveryDate), "dd MMM yyyy")
                      : "Immediate / Mutually Agreed"}
                  </span>
                </div>
              </div>

              {/* Delivery Terms */}
              <div className="p-3 rounded-xl border border-slate-200/80 bg-white">
                <span className="text-[11px] font-bold uppercase tracking-wider text-slate-400 block mb-0.5">
                  Freight / Delivery Terms
                </span>
                <span className="text-sm font-bold text-slate-900">
                  {snap.deliveryTerms || "Ex-Warehouse"}
                </span>
              </div>
            </div>

            {/* Delivery Location */}
            <div className="p-3 rounded-xl border border-slate-200/80 bg-white space-y-1">
              <span className="text-[11px] font-bold uppercase tracking-wider text-slate-400 block">
                Destination / Loading Location
              </span>
              <div className="flex items-start gap-2 text-xs font-semibold text-slate-800">
                <MapPin className="w-4 h-4 text-slate-400 shrink-0 mt-0.5" />
                <span>
                  {[snap.deliveryLocation, snap.deliveryDistrict, snap.deliveryState]
                    .filter(Boolean)
                    .join(", ") || "Designated Loading Warehouse"}
                </span>
              </div>
            </div>

            {/* Packaging & Loading Readiness */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className="p-3 rounded-xl border border-slate-200/70 bg-slate-50/60">
                <span className="text-[11px] font-bold uppercase tracking-wider text-slate-400 block mb-0.5">
                  Packaging Specification
                </span>
                <span className="text-xs font-bold text-slate-800">
                  {snap.packagingType || "Standard Standard Bags"}
                </span>
              </div>

              <div className="p-3 rounded-xl border border-slate-200/70 bg-slate-50/60">
                <span className="text-[11px] font-bold uppercase tracking-wider text-slate-400 block mb-0.5">
                  Loading Readiness
                </span>
                <span className="text-xs font-bold text-slate-800">
                  {snap.loadingReadiness?.status || "Ready for Loading"}
                  {snap.loadingReadiness?.durationDays
                    ? ` (${snap.loadingReadiness.durationDays} Days)`
                    : ""}
                </span>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* 4. GROUP 4 & GROUP 5: FINANCIALS & SPECIAL CONDITIONS (2-COL ON DESKTOP) */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        
        {/* GROUP 4: FINANCIALS & PAYMENT TERMS */}
        <Card className="border-slate-200 shadow-xs">
          <CardHeader className="p-4 sm:p-5 border-b border-slate-100 bg-slate-50/50">
            <div className="flex items-center gap-2.5">
              <div className="w-8 h-8 rounded-lg bg-amber-100/80 flex items-center justify-center text-amber-800">
                <CreditCard className="w-4 h-4 stroke-[2.25]" />
              </div>
              <div>
                <CardTitle className="text-base font-bold text-slate-900">
                  Financials & Payment Terms
                </CardTitle>
                <CardDescription className="text-xs text-slate-500">
                  Settlement structure, taxes & broker commissions
                </CardDescription>
              </div>
            </div>
          </CardHeader>

          <CardContent className="p-4 sm:p-5 space-y-3.5">
            <div className="p-3.5 rounded-xl border border-slate-200/80 bg-white space-y-1">
              <span className="text-[11px] font-bold uppercase tracking-wider text-slate-400 block">
                Agreed Payment Terms
              </span>
              <p className="text-sm font-bold text-slate-900 leading-snug">
                {snap.paymentTerms || "100% Escrow Settlement via Broker Desk against Weighment & Dispatch Slips"}
              </p>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className="p-3 rounded-xl border border-slate-200/70 bg-slate-50/60">
                <span className="text-[11px] font-bold uppercase tracking-wider text-slate-400 block mb-0.5">
                  Brokerage / Commission
                </span>
                <span className="text-xs font-bold text-slate-800">
                  {typeof snap.brokerageRate === "number" && snap.brokerageRate > 0
                    ? `₹${snap.brokerageRate.toLocaleString("en-IN")}/${snap.unitSymbol || "MT"}`
                    : "Standard Desk Tariff"}
                </span>
              </div>

              <div className="p-3 rounded-xl border border-slate-200/70 bg-slate-50/60">
                <span className="text-[11px] font-bold uppercase tracking-wider text-slate-400 block mb-0.5">
                  Statutory Taxes & Cess
                </span>
                <span className="text-xs font-bold text-slate-800">
                  Applicable GST extra as actuals
                </span>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* GROUP 5: NOTES & SPECIAL CONDITIONS */}
        <Card className="border-slate-200 shadow-xs">
          <CardHeader className="p-4 sm:p-5 border-b border-slate-100 bg-slate-50/50">
            <div className="flex items-center gap-2.5">
              <div className="w-8 h-8 rounded-lg bg-slate-100 flex items-center justify-center text-slate-700">
                <FileText className="w-4 h-4 stroke-[2.25]" />
              </div>
              <div>
                <CardTitle className="text-base font-bold text-slate-900">
                  Special Conditions & Notes
                </CardTitle>
                <CardDescription className="text-xs text-slate-500">
                  Commercial stipulations & broker instructions
                </CardDescription>
              </div>
            </div>
          </CardHeader>

          <CardContent className="p-4 sm:p-5 space-y-3">
            {snap.specialConditions ? (
              <div className="p-3.5 rounded-xl bg-amber-50/60 border border-amber-200/70 space-y-1">
                <span className="text-[10px] font-bold uppercase tracking-wider text-amber-800 block">
                  Contractual Special Conditions
                </span>
                <p className="text-xs font-medium text-slate-800 leading-relaxed">
                  {snap.specialConditions}
                </p>
              </div>
            ) : null}

            {snap.remarks ? (
              <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200/80 space-y-1">
                <span className="text-[10px] font-bold uppercase tracking-wider text-slate-500 block">
                  Negotiation Remarks
                </span>
                <p className="text-xs text-slate-700 leading-relaxed">{snap.remarks}</p>
              </div>
            ) : null}

            {!snap.specialConditions && !snap.remarks && (
              <div className="p-4 rounded-xl border border-dashed border-slate-200 text-center text-xs text-slate-500">
                No special commercial conditions or custom remarks specified for this deal version.
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
