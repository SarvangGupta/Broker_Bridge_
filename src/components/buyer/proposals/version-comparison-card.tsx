'use client';

import React from 'react';
import { 
  Lock, 
  Sparkles, 
  ArrowRight, 
  TrendingDown, 
  TrendingUp, 
  Minus,
  CheckCircle2, 
  Calendar, 
  Truck, 
  CreditCard, 
  Package, 
  Scale,
  MapPin,
  MessageSquare,
  X
} from 'lucide-react';
import { BuyerProposalVersionItem } from '@/src/types/buyer-proposal';
import { cn } from '@/lib/utils';

interface VersionComparisonCardProps {
  selectedVersion: BuyerProposalVersionItem;
  latestVersion: BuyerProposalVersionItem;
  className?: string;
}

function formatCurrency(amount?: number | null): string {
  if (amount === undefined || amount === null) return '—';
  return new Intl.NumberFormat('en-IN', {
    maximumFractionDigits: 0,
  }).format(amount);
}

function formatDate(dateStr?: string | null): string {
  if (!dateStr) return 'Flexible / Immediate';
  const d = new Date(dateStr);
  return d.toLocaleDateString('en-IN', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
}

export function VersionComparisonCard({
  selectedVersion,
  latestVersion,
  className,
}: VersionComparisonCardProps) {
  const isComparingSame = selectedVersion.versionNumber === latestVersion.versionNumber;

  const pastPrice = selectedVersion.terms.pricePerUnit;
  const currentPrice = latestVersion.terms.pricePerUnit;
  const priceDiff = currentPrice - pastPrice;

  const pastQty = selectedVersion.terms.quantity;
  const currentQty = latestVersion.terms.quantity;
  const qtyDiff = currentQty - pastQty;

  return (
    <div
      className={cn(
        'w-full max-w-full overflow-x-hidden bg-white rounded-2xl border border-slate-200 shadow-xs p-4 sm:p-6 space-y-5',
        className
      )}
    >
      {/* 1. Card Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2.5 pb-4 border-b border-slate-100">
        <div>
          <h3 className="text-base sm:text-lg font-bold text-slate-900 leading-tight">
            Commercial Iteration Comparison
          </h3>
          <p className="text-xs text-slate-500 mt-0.5">
            {isComparingSame
              ? `Reviewing active Version ${latestVersion.versionNumber} terms`
              : `Comparing Version ${selectedVersion.versionNumber} against active Version ${latestVersion.versionNumber}`}
          </p>
        </div>

        {!isComparingSame && (
          <div className="flex items-center gap-2">
            {priceDiff < 0 ? (
              <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">
                <TrendingDown className="w-3.5 h-3.5" />
                <span>Price Savings: -₹{formatCurrency(Math.abs(priceDiff))} / {latestVersion.terms.unit}</span>
              </span>
            ) : priceDiff > 0 ? (
              <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-amber-50 text-amber-800 border border-amber-200">
                <TrendingUp className="w-3.5 h-3.5" />
                <span>Rate Adjustment: +₹{formatCurrency(priceDiff)} / {latestVersion.terms.unit}</span>
              </span>
            ) : (
              <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium bg-slate-100 text-slate-600">
                <Minus className="w-3.5 h-3.5" />
                <span>Rate Unchanged</span>
              </span>
            )}
          </div>
        )}
      </div>

      {/* 2. Side-by-Side Comparison Grid (Mobile Stacks 1 col, Desktop 2 cols) */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 sm:gap-6">
        {/* COLUMN 1: Past Version (Read-Only) */}
        <div className="rounded-xl border border-slate-200/90 bg-slate-50/70 p-4 sm:p-5 space-y-4">
          {/* Column Header */}
          <div className="flex items-center justify-between gap-2 pb-3 border-b border-slate-200">
            <div className="flex items-center gap-2">
              <span className="px-2.5 py-1 rounded-lg text-xs font-bold bg-slate-200 text-slate-800">
                Version {selectedVersion.versionNumber}
              </span>
              <span className="text-xs font-semibold text-slate-500">
                {selectedVersion.status}
              </span>
            </div>

            <span className="inline-flex items-center gap-1 text-[11px] font-medium text-slate-400">
              <Lock className="w-3 h-3" />
              <span>Immutable Record</span>
            </span>
          </div>

          {/* Pricing Highlight */}
          <div className="space-y-1">
            <span className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider block">
              Offered Rate
            </span>
            <div className="text-xl sm:text-2xl font-bold text-slate-800">
              ₹{formatCurrency(selectedVersion.terms.pricePerUnit)}{' '}
              <span className="text-xs font-normal text-slate-500">
                / {selectedVersion.terms.unit}
              </span>
            </div>
            <span className="text-xs text-slate-500 block">
              Total: ₹{formatCurrency(selectedVersion.terms.totalEstimatedValue || selectedVersion.terms.pricePerUnit * selectedVersion.terms.quantity)}
            </span>
          </div>

          {/* Parameter Rows */}
          <div className="space-y-3 pt-2 text-xs divide-y divide-slate-200/60">
            {/* Quantity */}
            <div className="pt-2 flex items-center justify-between gap-2">
              <span className="text-slate-500 flex items-center gap-1.5">
                <Scale className="w-3.5 h-3.5 text-slate-400" />
                <span>Volume:</span>
              </span>
              <span className="font-semibold text-slate-800">
                {formatCurrency(selectedVersion.terms.quantity)} {selectedVersion.terms.unit}
              </span>
            </div>

            {/* Delivery Window */}
            <div className="pt-2 flex items-start justify-between gap-2">
              <span className="text-slate-500 flex items-center gap-1.5 shrink-0">
                <Calendar className="w-3.5 h-3.5 text-slate-400" />
                <span>Delivery:</span>
              </span>
              <span className="font-medium text-slate-700 text-right">
                {formatDate(selectedVersion.terms.deliveryWindowStart)} — {formatDate(selectedVersion.terms.deliveryWindowEnd)}
              </span>
            </div>

            {/* Freight */}
            <div className="pt-2 flex items-center justify-between gap-2">
              <span className="text-slate-500 flex items-center gap-1.5 shrink-0">
                <Truck className="w-3.5 h-3.5 text-slate-400" />
                <span>Freight:</span>
              </span>
              <span className="font-medium text-slate-800 text-right truncate">
                {selectedVersion.terms.freightTerms || 'FOR Destination'}
              </span>
            </div>

            {/* Payment */}
            <div className="pt-2 flex items-start justify-between gap-2">
              <span className="text-slate-500 flex items-center gap-1.5 shrink-0">
                <CreditCard className="w-3.5 h-3.5 text-slate-400" />
                <span>Payment:</span>
              </span>
              <span className="font-medium text-slate-800 text-right leading-tight max-w-[60%]">
                {selectedVersion.terms.paymentTerms || 'Standard Escrow'}
              </span>
            </div>

            {/* Packaging */}
            <div className="pt-2 flex items-center justify-between gap-2">
              <span className="text-slate-500 flex items-center gap-1.5 shrink-0">
                <Package className="w-3.5 h-3.5 text-slate-400" />
                <span>Packaging:</span>
              </span>
              <span className="font-medium text-slate-800 text-right">
                {selectedVersion.terms.packagingType || '50kg Bags'}
              </span>
            </div>
          </div>

          {/* Broker Note */}
          {selectedVersion.brokerNotes && (
            <div className="p-3 rounded-lg bg-white border border-slate-200/80 text-xs text-slate-600 space-y-1">
              <div className="flex items-center gap-1 text-[11px] font-semibold text-slate-400 uppercase">
                <MessageSquare className="w-3 h-3" />
                <span>Broker Note (Round {selectedVersion.versionNumber})</span>
              </div>
              <p className="italic leading-relaxed">
                "{selectedVersion.brokerNotes}"
              </p>
            </div>
          )}
        </div>

        {/* COLUMN 2: Current Active Version */}
        <div className="rounded-xl border-2 border-sky-300 bg-sky-50/30 p-4 sm:p-5 space-y-4">
          {/* Column Header */}
          <div className="flex items-center justify-between gap-2 pb-3 border-b border-sky-100">
            <div className="flex items-center gap-2">
              <span className={cn(
                "px-2.5 py-1 rounded-lg text-xs font-bold text-white",
                latestVersion.status === 'Rejected'
                  ? "bg-rose-600"
                  : latestVersion.status === 'Accepted'
                  ? "bg-emerald-600"
                  : "bg-[#0284C7]"
              )}>
                Round {latestVersion.versionNumber}
              </span>
              <span className={cn(
                "text-xs font-semibold",
                latestVersion.status === 'Rejected'
                  ? "text-rose-700"
                  : latestVersion.status === 'Accepted'
                  ? "text-emerald-700"
                  : "text-[#0284C7]"
              )}>
                {latestVersion.status === 'Rejected'
                  ? "Declined Offer"
                  : latestVersion.status === 'Accepted'
                  ? "Accepted Offer"
                  : "Current Active Offer"}
              </span>
            </div>

            <span className={cn(
              "inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase",
              latestVersion.status === 'Rejected'
                ? "bg-rose-100 text-rose-800"
                : latestVersion.status === 'Accepted'
                ? "bg-emerald-100 text-emerald-800"
                : "bg-emerald-100 text-emerald-800"
            )}>
              {latestVersion.status === 'Rejected' ? (
                <>
                  <X className="w-3 h-3 text-rose-600" />
                  <span>Declined</span>
                </>
              ) : latestVersion.status === 'Accepted' ? (
                <>
                  <CheckCircle2 className="w-3 h-3 text-emerald-600" />
                  <span>Accepted</span>
                </>
              ) : (
                <>
                  <CheckCircle2 className="w-3 h-3" />
                  <span>Actionable</span>
                </>
              )}
            </span>
          </div>

          {/* Pricing Highlight in Ocean Blue */}
          <div className="space-y-1">
            <span className="text-[11px] font-semibold text-[#0284C7] uppercase tracking-wider block">
              Current Offered Rate
            </span>
            <div className="text-xl sm:text-2xl font-black text-[#0284C7]">
              ₹{formatCurrency(latestVersion.terms.pricePerUnit)}{' '}
              <span className="text-xs font-normal text-slate-600">
                / {latestVersion.terms.unit}
              </span>
            </div>
            <span className="text-xs font-semibold text-slate-700 block">
              Total: ₹{formatCurrency(latestVersion.terms.totalEstimatedValue || latestVersion.terms.pricePerUnit * latestVersion.terms.quantity)}
            </span>
          </div>

          {/* Parameter Rows */}
          <div className="space-y-3 pt-2 text-xs divide-y divide-sky-100">
            {/* Quantity */}
            <div className="pt-2 flex items-center justify-between gap-2">
              <span className="text-slate-500 flex items-center gap-1.5">
                <Scale className="w-3.5 h-3.5 text-[#0284C7]" />
                <span>Volume:</span>
              </span>
              <span className="font-bold text-slate-900">
                {formatCurrency(latestVersion.terms.quantity)} {latestVersion.terms.unit}
                {qtyDiff !== 0 && (
                  <span className="text-[11px] text-[#0284C7] ml-1.5 font-normal">
                    ({qtyDiff > 0 ? `+${qtyDiff}` : qtyDiff} {latestVersion.terms.unit})
                  </span>
                )}
              </span>
            </div>

            {/* Delivery Window */}
            <div className="pt-2 flex items-start justify-between gap-2">
              <span className="text-slate-500 flex items-center gap-1.5 shrink-0">
                <Calendar className="w-3.5 h-3.5 text-[#0284C7]" />
                <span>Delivery:</span>
              </span>
              <span className="font-semibold text-slate-900 text-right">
                {formatDate(latestVersion.terms.deliveryWindowStart)} — {formatDate(latestVersion.terms.deliveryWindowEnd)}
              </span>
            </div>

            {/* Freight */}
            <div className="pt-2 flex items-center justify-between gap-2">
              <span className="text-slate-500 flex items-center gap-1.5 shrink-0">
                <Truck className="w-3.5 h-3.5 text-[#0284C7]" />
                <span>Freight:</span>
              </span>
              <span className="font-semibold text-slate-900 text-right truncate">
                {latestVersion.terms.freightTerms || 'FOR Destination'}
              </span>
            </div>

            {/* Payment */}
            <div className="pt-2 flex items-start justify-between gap-2">
              <span className="text-slate-500 flex items-center gap-1.5 shrink-0">
                <CreditCard className="w-3.5 h-3.5 text-[#0284C7]" />
                <span>Payment:</span>
              </span>
              <span className="font-semibold text-slate-900 text-right leading-tight max-w-[60%]">
                {latestVersion.terms.paymentTerms || 'Standard Escrow'}
              </span>
            </div>

            {/* Packaging */}
            <div className="pt-2 flex items-center justify-between gap-2">
              <span className="text-slate-500 flex items-center gap-1.5 shrink-0">
                <Package className="w-3.5 h-3.5 text-[#0284C7]" />
                <span>Packaging:</span>
              </span>
              <span className="font-semibold text-slate-900 text-right">
                {latestVersion.terms.packagingType || '50kg Bags'}
              </span>
            </div>
          </div>

          {/* Broker Note */}
          {latestVersion.brokerNotes && (
            <div className="p-3 rounded-lg bg-white border border-sky-200 text-xs text-slate-700 space-y-1">
              <div className="flex items-center gap-1 text-[11px] font-semibold text-[#0284C7] uppercase">
                <MessageSquare className="w-3 h-3" />
                <span>Current Broker Remarks</span>
              </div>
              <p className="italic leading-relaxed font-medium">
                "{latestVersion.brokerNotes}"
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
