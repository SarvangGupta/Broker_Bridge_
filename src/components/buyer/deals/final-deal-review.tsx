'use client';

import React from 'react';
import {
  ShieldCheck,
  CheckCircle2,
  Clock,
  UserCheck,
  AlertTriangle,
  Receipt,
  Truck,
  Package,
  Calendar,
  Building2,
  FileCheck2,
  Handshake,
  Layers,
  ArrowRight,
  Sparkles,
  Info,
  Scale,
  Lock,
} from 'lucide-react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';
import {
  FinalDealReviewData,
  DealConfirmationStatus,
} from '@/src/types/buyer-deal-review';
import {
  computeDealTermsDiff,
  FieldDiffResult,
  formatCurrencyINR,
} from '@/src/utils/visual-diff-engine';

interface FinalDealReviewProps {
  data: FinalDealReviewData;
  className?: string;
}

/**
 * Renders a value passed through the Visual Diff engine.
 * - If changed: renders old value in red with strikethrough, and new value in green.
 * - If unchanged: renders standard neutral text.
 */
function DiffFieldDisplay({
  diff,
  unit,
  className,
}: {
  diff: FieldDiffResult;
  unit?: string;
  className?: string;
}) {
  if (diff.isChanged && diff.previous) {
    return (
      <div className={cn('flex flex-wrap items-center gap-1.5', className)}>
        <span className="inline-flex items-center px-2 py-0.5 rounded text-xs sm:text-sm bg-red-50 text-red-700 line-through font-normal border border-red-200/70 dark:bg-red-950/40 dark:text-red-400 dark:border-red-900/50">
          {diff.previous}
        </span>
        <span className="inline-flex items-center px-2 py-0.5 rounded text-xs sm:text-sm bg-green-50 text-green-700 font-bold border border-green-200/70 dark:bg-green-950/40 dark:text-green-300 dark:border-green-800/50">
          {diff.current}
        </span>
      </div>
    );
  }

  return (
    <span className={cn('text-xs sm:text-sm font-semibold text-slate-900 dark:text-slate-100', className)}>
      {diff.current} {unit ? ` ${unit}` : ''}
    </span>
  );
}

/**
 * Task 4: State Machine Indicators Component
 * Displays prominent status badge mapping to the exact current confirmation state.
 */
function DealStatusBanner({ status }: { status: DealConfirmationStatus }) {
  switch (status) {
    case 'Awaiting Buyer Confirmation':
      return (
        <div className="w-full rounded-2xl border border-sky-200 bg-sky-50/80 p-4 sm:p-5 dark:bg-sky-950/30 dark:border-sky-900/60">
          <div className="flex items-start gap-3">
            <div className="p-2.5 rounded-xl bg-[#0284C7] text-white shrink-0 mt-0.5">
              <Clock className="w-5 h-5 animate-pulse" />
            </div>
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-2 mb-1">
                <span className="px-2.5 py-0.5 rounded-full text-xs font-bold bg-[#0284C7] text-white tracking-wide uppercase">
                  Awaiting Buyer Confirmation
                </span>
                <span className="text-[11px] font-semibold text-sky-700 dark:text-sky-300">
                  Action Required
                </span>
              </div>
              <h2 className="text-sm sm:text-base font-bold text-slate-900 dark:text-slate-100">
                Final Deal Snapshot Ready for Review
              </h2>
              <p className="text-xs sm:text-sm text-slate-600 dark:text-slate-300 mt-0.5">
                The Broker has frozen the agreed commercial terms. Review all parameters and visual diffs below prior to recording your confirmation.
              </p>
            </div>
          </div>
        </div>
      );

    case 'Buyer Confirmed':
      return (
        <div className="w-full rounded-2xl border border-emerald-200 bg-emerald-50/80 p-4 sm:p-5 dark:bg-emerald-950/30 dark:border-emerald-900/60">
          <div className="flex items-start gap-3">
            <div className="p-2.5 rounded-xl bg-emerald-600 text-white shrink-0 mt-0.5">
              <CheckCircle2 className="w-5 h-5" />
            </div>
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-2 mb-1">
                <span className="px-2.5 py-0.5 rounded-full text-xs font-bold bg-emerald-600 text-white tracking-wide uppercase">
                  Buyer Confirmed
                </span>
                <span className="text-[11px] font-semibold text-emerald-700 dark:text-emerald-300">
                  Recorded in Audit Ledger
                </span>
              </div>
              <h2 className="text-sm sm:text-base font-bold text-slate-900 dark:text-slate-100">
                Buyer Confirmation Recorded
              </h2>
              <p className="text-xs sm:text-sm text-slate-600 dark:text-slate-300 mt-0.5">
                You have confirmed these terms. The transaction is pending counterparty confirmation and final broker order execution.
              </p>
            </div>
          </div>
        </div>
      );

    case 'Awaiting Seller Confirmation':
      return (
        <div className="w-full rounded-2xl border border-indigo-200 bg-indigo-50/80 p-4 sm:p-5 dark:bg-indigo-950/30 dark:border-indigo-900/60">
          <div className="flex items-start gap-3">
            <div className="p-2.5 rounded-xl bg-indigo-600 text-white shrink-0 mt-0.5">
              <UserCheck className="w-5 h-5" />
            </div>
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-2 mb-1">
                <span className="px-2.5 py-0.5 rounded-full text-xs font-bold bg-indigo-600 text-white tracking-wide uppercase">
                  Awaiting Seller Confirmation
                </span>
              </div>
              <h2 className="text-sm sm:text-base font-bold text-slate-900 dark:text-slate-100">
                Awaiting Seller Sign-Off
              </h2>
              <p className="text-xs sm:text-sm text-slate-600 dark:text-slate-300 mt-0.5">
                Your confirmation is in place. The Broker desk is coordinating counterparty sign-off.
              </p>
            </div>
          </div>
        </div>
      );

    case 'Confirmed':
      return (
        <div className="w-full rounded-2xl border border-emerald-300 bg-emerald-100/70 p-4 sm:p-5 dark:bg-emerald-950/40 dark:border-emerald-800">
          <div className="flex items-start gap-3">
            <div className="p-2.5 rounded-xl bg-emerald-700 text-white shrink-0 mt-0.5">
              <ShieldCheck className="w-5 h-5" />
            </div>
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-2 mb-1">
                <span className="px-2.5 py-0.5 rounded-full text-xs font-bold bg-emerald-700 text-white tracking-wide uppercase">
                  Confirmed
                </span>
                <span className="text-[11px] font-semibold text-emerald-800 dark:text-emerald-300">
                  Ready for Dispatch
                </span>
              </div>
              <h2 className="text-sm sm:text-base font-bold text-slate-900 dark:text-slate-100">
                Mutual Commercial Agreement Confirmed
              </h2>
              <p className="text-xs sm:text-sm text-slate-600 dark:text-slate-300 mt-0.5">
                Both parties have confirmed terms. Order has been locked by the Broker desk.
              </p>
            </div>
          </div>
        </div>
      );

    case 'Amendment Required':
      return (
        <div className="w-full rounded-2xl border border-amber-300 bg-amber-50/80 p-4 sm:p-5 dark:bg-amber-950/30 dark:border-amber-900/60">
          <div className="flex items-start gap-3">
            <div className="p-2.5 rounded-xl bg-amber-600 text-white shrink-0 mt-0.5">
              <AlertTriangle className="w-5 h-5" />
            </div>
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-2 mb-1">
                <span className="px-2.5 py-0.5 rounded-full text-xs font-bold bg-amber-600 text-white tracking-wide uppercase">
                  Amendment Required
                </span>
              </div>
              <h2 className="text-sm sm:text-base font-bold text-slate-900 dark:text-slate-100">
                Commercial Amendment in Progress
              </h2>
              <p className="text-xs sm:text-sm text-slate-600 dark:text-slate-300 mt-0.5">
                Modifications have been requested. Review the red/green visual differences between proposal versions.
              </p>
            </div>
          </div>
        </div>
      );

    default:
      return null;
  }
}

/**
 * Task 3: Buyer Final Deal Review Interface (Micro-Sprint 37.1)
 * Strictly read-only, mobile-first (360px viewport compliant, zero data-wall).
 */
export function FinalDealReview({ data, className }: FinalDealReviewProps) {
  const diffReport = computeDealTermsDiff(data.currentTerms, data.previousTerms);
  const terms = data.currentTerms;

  return (
    <div className={cn('w-full max-w-full overflow-x-hidden space-y-5', className)}>
      {/* 1. State Machine Indicator Banner */}
      <DealStatusBanner status={data.status} />

      {/* 2. Visual Diff Legend Banner (Displayed if a predecessor version exists) */}
      {data.hasPreviousVersion && (
        <div className="w-full rounded-xl border border-slate-200 bg-slate-50/70 p-3.5 dark:bg-slate-900/40 dark:border-slate-800">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <Sparkles className="w-4 h-4 text-[#0284C7] shrink-0" />
              <span className="text-xs font-bold text-slate-800 dark:text-slate-200">
                Visual Diff Engine Active
              </span>
              <span className="text-[11px] text-slate-500">
                (v{data.previousVersionNumber} ➔ v{data.versionNumber})
              </span>
            </div>

            <div className="flex flex-wrap items-center gap-2 text-[11px]">
              <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded font-bold bg-green-50 text-green-700 border border-green-200 dark:bg-green-950/40 dark:text-green-300 dark:border-green-800">
                <span className="w-1.5 h-1.5 rounded-full bg-green-600" />
                Agreed Term (New)
              </span>
              <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded font-normal bg-red-50 text-red-700 line-through border border-red-200 dark:bg-red-950/40 dark:text-red-400 dark:border-red-900">
                Previous Round
              </span>
            </div>
          </div>
        </div>
      )}

      {/* 3. Core Commercials Card */}
      <Card className="rounded-2xl border border-slate-200 bg-white shadow-xs dark:bg-slate-900 dark:border-slate-800">
        <CardHeader className="pb-3 border-b border-slate-100 dark:border-slate-800">
          <div className="flex items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <div className="p-2 rounded-xl bg-sky-50 text-[#0284C7] dark:bg-sky-950/40">
                <Receipt className="w-4 h-4" />
              </div>
              <div>
                <CardTitle className="text-sm sm:text-base font-bold text-slate-900 dark:text-slate-100">
                  Core Commercials
                </CardTitle>
                <p className="text-[11px] text-slate-500">
                  Agreed commodity, quantity, and landed rate
                </p>
              </div>
            </div>

            <Badge variant="outline" className="text-xs font-bold border-slate-200 text-slate-700 dark:text-slate-300">
              Snapshot v{data.versionNumber}
            </Badge>
          </div>
        </CardHeader>

        <CardContent className="pt-4 space-y-4">
          {/* Commodity & Grade Header */}
          <div className="p-3.5 rounded-xl bg-slate-50/80 border border-slate-200/60 dark:bg-slate-800/40 dark:border-slate-700/60 space-y-1">
            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
              Commodity & Classification
            </span>
            <div className="flex flex-wrap items-baseline gap-2">
              <DiffFieldDisplay
                diff={diffReport.commodity}
                className="text-sm sm:text-base font-bold text-slate-900 dark:text-slate-100"
              />
              <span className="text-slate-400">/</span>
              <DiffFieldDisplay
                diff={diffReport.grade}
                className="text-xs sm:text-sm text-slate-600 dark:text-slate-300 font-medium"
              />
            </div>
          </div>

          {/* Key Metrics Grid */}
          <div className="grid grid-cols-1 xs:grid-cols-2 sm:grid-cols-3 gap-3">
            {/* Quantity */}
            <div className="p-3 rounded-xl border border-slate-200/80 bg-white dark:bg-slate-900 dark:border-slate-800 space-y-1">
              <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider block">
                Final Quantity
              </span>
              <DiffFieldDisplay diff={diffReport.quantity} className="text-base sm:text-lg font-bold" />
              <span className="text-[11px] text-slate-400 block">Lot fulfillment size</span>
            </div>

            {/* Net Landed Rate */}
            <div className="p-3 rounded-xl border border-sky-200 bg-sky-50/40 dark:bg-sky-950/20 dark:border-sky-900 space-y-1">
              <span className="text-[10px] font-bold text-[#0284C7] uppercase tracking-wider block">
                Net Landed Rate
              </span>
              <DiffFieldDisplay diff={diffReport.netLandedPrice} className="text-base sm:text-lg font-bold text-[#0284C7]" />
              <span className="text-[11px] text-slate-500 block">All charges inclusive</span>
            </div>

            {/* Total Estimated Transaction Value */}
            <div className="p-3 rounded-xl border border-slate-200/80 bg-white dark:bg-slate-900 dark:border-slate-800 space-y-1 xs:col-span-2 sm:col-span-1">
              <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider block">
                Total Deal Value
              </span>
              <DiffFieldDisplay diff={diffReport.totalEstimatedValue} className="text-base sm:text-lg font-bold text-emerald-700 dark:text-emerald-400" />
              <span className="text-[11px] text-slate-400 block">Total Buyer outlay</span>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* 4. Buyer-Side Net Cost Breakdown Card */}
      <Card className="rounded-2xl border border-slate-200 bg-white shadow-xs dark:bg-slate-900 dark:border-slate-800">
        <CardHeader className="pb-3 border-b border-slate-100 dark:border-slate-800">
          <div className="flex items-center gap-2">
            <div className="p-2 rounded-xl bg-emerald-50 text-emerald-600 dark:bg-emerald-950/40">
              <Scale className="w-4 h-4" />
            </div>
            <div>
              <CardTitle className="text-sm sm:text-base font-bold text-slate-900 dark:text-slate-100">
                Buyer-Side Commercial Breakdown
              </CardTitle>
              <p className="text-[11px] text-slate-500">
                Transparent itemized breakdown demonstrating true net cost
              </p>
            </div>
          </div>
        </CardHeader>

        <CardContent className="pt-4 space-y-3">
          {/* Base Commodity Price Row */}
          <div className="flex items-center justify-between p-3 rounded-xl bg-slate-50/70 dark:bg-slate-800/40 text-xs sm:text-sm">
            <div className="min-w-0 pr-2">
              <span className="font-semibold text-slate-900 dark:text-slate-100 block">
                Base Commodity Rate
              </span>
              <span className="text-[11px] text-slate-500">Agreed trade price per {terms.unitSymbol}</span>
            </div>
            <DiffFieldDisplay diff={diffReport.basePrice} className="font-bold shrink-0" />
          </div>

          {/* Itemized Charges */}
          <div className="space-y-2 border-t border-b border-slate-100 dark:border-slate-800 py-3">
            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
              Applicable Buyer Charges (Included in Landed Rate)
            </span>

            {terms.applicableCharges.map((charge, idx) => (
              <div key={idx} className="flex items-center justify-between py-1 text-xs">
                <div className="min-w-0 pr-2">
                  <span className="font-medium text-slate-700 dark:text-slate-300 block truncate">
                    {charge.name}
                  </span>
                  <span className="text-[10px] text-slate-400 block truncate">
                    {charge.description}
                  </span>
                </div>
                <div className="text-right shrink-0">
                  <span className="font-semibold text-slate-800 dark:text-slate-200 block">
                    + ₹{charge.rate} / {terms.unitSymbol}
                  </span>
                  <span className="text-[10px] text-slate-400 block">
                    {formatCurrencyINR(charge.amount)} total
                  </span>
                </div>
              </div>
            ))}
          </div>

          {/* Net Landed Cost Total Bar */}
          <div className="flex items-center justify-between p-3.5 rounded-xl bg-sky-50/80 border border-sky-200 dark:bg-sky-950/40 dark:border-sky-900 text-xs sm:text-sm">
            <div>
              <span className="font-bold text-slate-900 dark:text-slate-100 block">
                Net Landed Rate
              </span>
              <span className="text-[11px] text-sky-700 dark:text-sky-300">
                Base rate + ₹{terms.totalChargesPerUnit} applicable charges
              </span>
            </div>
            <div className="text-right">
              <DiffFieldDisplay
                diff={diffReport.netLandedPrice}
                className="text-sm sm:text-base font-extrabold text-[#0284C7]"
              />
            </div>
          </div>
        </CardContent>
      </Card>

      {/* 5. Operations & Logistics Card */}
      <Card className="rounded-2xl border border-slate-200 bg-white shadow-xs dark:bg-slate-900 dark:border-slate-800">
        <CardHeader className="pb-3 border-b border-slate-100 dark:border-slate-800">
          <div className="flex items-center gap-2">
            <div className="p-2 rounded-xl bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300">
              <Truck className="w-4 h-4" />
            </div>
            <div>
              <CardTitle className="text-sm sm:text-base font-bold text-slate-900 dark:text-slate-100">
                Operations & Delivery Logistics
              </CardTitle>
              <p className="text-[11px] text-slate-500">
                Destination, delivery timeline, packaging, and freight terms
              </p>
            </div>
          </div>
        </CardHeader>

        <CardContent className="pt-4 space-y-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
            {/* Delivery Location */}
            <div className="p-3 rounded-xl border border-slate-100 bg-slate-50/60 dark:bg-slate-800/40 dark:border-slate-800 space-y-1">
              <div className="flex items-center gap-1.5 text-slate-500">
                <Building2 className="w-3.5 h-3.5" />
                <span className="text-[10px] font-bold uppercase tracking-wider">
                  Delivery Destination
                </span>
              </div>
              <DiffFieldDisplay diff={diffReport.deliveryLocation} className="font-semibold" />
            </div>

            {/* Delivery Window */}
            <div className="p-3 rounded-xl border border-slate-100 bg-slate-50/60 dark:bg-slate-800/40 dark:border-slate-800 space-y-1">
              <div className="flex items-center gap-1.5 text-slate-500">
                <Calendar className="w-3.5 h-3.5" />
                <span className="text-[10px] font-bold uppercase tracking-wider">
                  Delivery Window
                </span>
              </div>
              <DiffFieldDisplay diff={diffReport.deliveryWindow} className="font-semibold" />
            </div>

            {/* Freight Terms */}
            <div className="p-3 rounded-xl border border-slate-100 bg-slate-50/60 dark:bg-slate-800/40 dark:border-slate-800 space-y-1">
              <div className="flex items-center gap-1.5 text-slate-500">
                <Truck className="w-3.5 h-3.5" />
                <span className="text-[10px] font-bold uppercase tracking-wider">
                  Freight Terms
                </span>
              </div>
              <DiffFieldDisplay diff={diffReport.freightTerms} className="font-semibold" />
            </div>

            {/* Packaging Type */}
            <div className="p-3 rounded-xl border border-slate-100 bg-slate-50/60 dark:bg-slate-800/40 dark:border-slate-800 space-y-1">
              <div className="flex items-center gap-1.5 text-slate-500">
                <Package className="w-3.5 h-3.5" />
                <span className="text-[10px] font-bold uppercase tracking-wider">
                  Packaging Specification
                </span>
              </div>
              <DiffFieldDisplay diff={diffReport.packagingType} className="font-semibold" />
            </div>
          </div>

          {/* Payment Terms & Inspection */}
          <div className="space-y-3 pt-2">
            <div className="p-3.5 rounded-xl border border-slate-100 bg-slate-50/60 dark:bg-slate-800/40 dark:border-slate-800 space-y-1">
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                Payment Terms
              </span>
              <DiffFieldDisplay diff={diffReport.paymentTerms} className="font-semibold text-xs sm:text-sm" />
            </div>

            <div className="p-3.5 rounded-xl border border-slate-100 bg-slate-50/60 dark:bg-slate-800/40 dark:border-slate-800 space-y-1">
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                Inspection & Sampling Protocol
              </span>
              <DiffFieldDisplay diff={diffReport.inspectionRequirements} className="font-semibold text-xs sm:text-sm" />
            </div>

            <div className="p-3.5 rounded-xl border border-slate-100 bg-slate-50/60 dark:bg-slate-800/40 dark:border-slate-800 space-y-1">
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                Special Conditions & Bylaws
              </span>
              <DiffFieldDisplay diff={diffReport.specialConditions} className="font-medium text-xs sm:text-sm text-slate-600 dark:text-slate-300" />
            </div>
          </div>
        </CardContent>
      </Card>

      {/* 6. Quality Specifications Card */}
      <Card className="rounded-2xl border border-slate-200 bg-white shadow-xs dark:bg-slate-900 dark:border-slate-800">
        <CardHeader className="pb-3 border-b border-slate-100 dark:border-slate-800">
          <div className="flex items-center gap-2">
            <div className="p-2 rounded-xl bg-purple-50 text-purple-600 dark:bg-purple-950/40">
              <FileCheck2 className="w-4 h-4" />
            </div>
            <div>
              <CardTitle className="text-sm sm:text-base font-bold text-slate-900 dark:text-slate-100">
                Quality Parameters & Lab Limits
              </CardTitle>
              <p className="text-[11px] text-slate-500">
                Contractual quality parameters verified against master bounds
              </p>
            </div>
          </div>
        </CardHeader>

        <CardContent className="pt-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
            {diffReport.qualityDiffs.map((q, idx) => (
              <div
                key={idx}
                className="p-3 rounded-xl border border-slate-100 bg-slate-50/60 dark:bg-slate-800/40 dark:border-slate-800 flex items-center justify-between gap-2"
              >
                <div className="min-w-0">
                  <span className="font-semibold text-xs text-slate-800 dark:text-slate-200 block truncate">
                    {q.parameterName}
                  </span>
                  <span className="text-[10px] text-slate-400 block">Lab Tested Specification</span>
                </div>
                <div className="text-right shrink-0">
                  {q.isChanged && q.previous ? (
                    <div className="flex items-center gap-1.5">
                      <span className="text-[11px] bg-red-50 text-red-700 line-through px-1.5 py-0.5 rounded border border-red-200">
                        {q.previous}
                      </span>
                      <span className="text-xs font-bold bg-green-50 text-green-700 px-1.5 py-0.5 rounded border border-green-200">
                        {q.current}
                      </span>
                    </div>
                  ) : (
                    <span className="text-xs font-bold text-slate-900 dark:text-slate-100">
                      {q.current}
                    </span>
                  )}
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* 7. Broker Governance & Booking Isolation Seal */}
      <div className="rounded-2xl border border-slate-200 bg-white p-4 sm:p-5 shadow-xs dark:bg-slate-900 dark:border-slate-800 space-y-3">
        <div className="flex items-center justify-between gap-3 pb-3 border-b border-slate-100 dark:border-slate-800">
          <div className="flex items-center gap-2.5">
            <div className="p-2 rounded-xl bg-sky-50 text-[#0284C7] dark:bg-sky-950/40">
              <Handshake className="w-4 h-4" />
            </div>
            <div>
              <span className="text-xs font-bold text-slate-900 dark:text-slate-100 block">
                {data.brokerName}
              </span>
              <span className="text-[11px] text-slate-500 block">
                {data.brokerAgency}
              </span>
            </div>
          </div>

          <div className="text-right text-[11px] text-slate-400">
            <span>Snapshot Created</span>
            <span className="block font-semibold text-slate-700 dark:text-slate-300">
              {new Date(data.snapshotTimestamp).toLocaleString('en-IN', {
                day: 'numeric',
                month: 'short',
                hour: '2-digit',
                minute: '2-digit',
              })}
            </span>
          </div>
        </div>

        {/* Architecture Rule Callout (PRD Section 3 & 37) */}
        <div className="flex items-start gap-2.5 p-3 rounded-xl bg-amber-50/70 border border-amber-200/80 text-amber-900 dark:bg-amber-950/30 dark:border-amber-900/60 dark:text-amber-300 text-xs">
          <Lock className="w-4 h-4 shrink-0 mt-0.5 text-amber-600 dark:text-amber-400" />
          <div className="space-y-0.5">
            <span className="font-bold block">
              Governance & Booking Isolation Architecture
            </span>
            <p className="text-[11px] text-amber-800 dark:text-amber-300/90 leading-relaxed">
              Buyer confirmation records official commercial agreement over this deal snapshot. Buyer confirmation does not finalize system Booking. Physical booking execution remains exclusively the Broker's responsibility.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
