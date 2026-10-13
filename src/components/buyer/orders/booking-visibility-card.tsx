'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import {
  PackageCheck,
  ShieldCheck,
  Clock,
  Copy,
  Check,
  ExternalLink,
  Layers,
  Scale,
  Receipt,
  AlertCircle,
  Calendar,
  Lock,
  Building2,
} from 'lucide-react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { BuyerBookingVisibilityData } from '@/src/types/buyer-order-types';
import { formatCurrencyINR } from '@/src/utils/visual-diff-engine';

interface BookingVisibilityCardProps {
  data?: BuyerBookingVisibilityData | null;
  error?: string | null;
  className?: string;
}

/**
 * Maps raw booking status to semantic styling.
 */
function getStatusBadgeStyle(status?: string | null): {
  variant: 'default' | 'outline';
  className: string;
  label: string;
} {
  const norm = (status || '').toLowerCase().trim();

  if (norm.includes('awaiting') || norm.includes('pending') || norm.includes('draft')) {
    return {
      variant: 'outline',
      className: 'bg-amber-50 text-amber-800 border-amber-300 font-bold',
      label: 'Awaiting Broker Finalization',
    };
  }

  if (norm.includes('dispatched') || norm.includes('transit')) {
    return {
      variant: 'outline',
      className: 'bg-indigo-50 text-indigo-700 border-indigo-200 font-bold',
      label: status || 'In Transit',
    };
  }

  if (norm.includes('delivered') || norm.includes('completed')) {
    return {
      variant: 'outline',
      className: 'bg-emerald-100 text-emerald-800 border-emerald-300 font-bold',
      label: 'Delivered & Fulfilled',
    };
  }

  if (norm.includes('cancelled') || norm.includes('rejected')) {
    return {
      variant: 'outline',
      className: 'bg-red-50 text-red-700 border-red-200 font-bold',
      label: 'Cancelled',
    };
  }

  // Default: Confirmed / Booked
  return {
    variant: 'outline',
    className: 'bg-emerald-50 text-emerald-700 border-emerald-200 font-bold',
    label: 'Booking Confirmed',
  };
}

/**
 * Task 2 (Micro-Sprint 38.1): Buyer Booking Visibility Card Component.
 * Surfaces the locked Booking ID and high-level order summary to the Buyer.
 * 
 * Strict Mobile Standard:
 * 360px viewport compliant, stacks vertically, zero horizontal scrolling.
 */
export function BookingVisibilityCard({
  data,
  error,
  className,
}: BookingVisibilityCardProps) {
  const [copied, setCopied] = useState(false);

  const handleCopyBookingId = (text: string) => {
    if (!text) return;
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  // 1. Fallback State / Pending Broker Finalization State (PRD 38.1)
  const isPending = !data || !data.isBrokerFinalized || !data.bookingId;

  if (isPending) {
    return (
      <Card
        className={cn(
          'w-full max-w-full overflow-hidden rounded-2xl border border-amber-200 bg-amber-50/50 shadow-xs',
          className
        )}
      >
        <CardHeader className="p-4 sm:p-5 border-b border-amber-100/80 pb-3">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2.5">
            <div className="flex items-center gap-2.5">
              <div className="w-9 h-9 rounded-xl bg-amber-100 text-amber-700 flex items-center justify-center shrink-0 border border-amber-200">
                <Clock className="w-5 h-5 animate-pulse" />
              </div>
              <div className="min-w-0">
                <span className="text-[10px] sm:text-xs font-bold text-amber-700 uppercase tracking-wider block">
                  Commercial Allocation Gate
                </span>
                <CardTitle className="text-base sm:text-lg font-bold text-slate-900 leading-tight">
                  Awaiting Broker Finalization
                </CardTitle>
              </div>
            </div>

            <Badge
              variant="outline"
              className="w-fit bg-amber-100/80 text-amber-800 border-amber-300 font-bold text-xs"
            >
              Action Required: Broker Desk
            </Badge>
          </div>
        </CardHeader>

        <CardContent className="p-4 sm:p-5 space-y-4">
          <div className="p-3.5 rounded-xl bg-white border border-amber-200/80 shadow-2xs space-y-2">
            <div className="flex items-start gap-2.5">
              <Lock className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
              <div className="space-y-1">
                <p className="text-xs sm:text-sm font-semibold text-slate-900">
                  Your order will appear here once the Broker generates the physical Booking ID.
                </p>
                <p className="text-[11px] sm:text-xs text-slate-600 leading-relaxed">
                  Your commercial confirmation has been recorded in the immutable audit ledger. In accordance with platform governance, the physical Booking ID is minted exclusively by the Broker desk upon verifying supplier warehouse allocation.
                </p>
              </div>
            </div>
          </div>

          {/* Preliminary Deal Context if present */}
          {data && (
            <div className="grid grid-cols-1 xs:grid-cols-2 sm:grid-cols-3 gap-2.5 pt-1">
              <div className="p-3 rounded-xl bg-white/80 border border-amber-100">
                <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                  Deal Reference
                </span>
                <span className="text-xs sm:text-sm font-bold text-slate-800 block mt-0.5 truncate">
                  {data.dealReference || `DEAL-${data.dealId.slice(0, 8).toUpperCase()}`}
                </span>
              </div>

              <div className="p-3 rounded-xl bg-white/80 border border-amber-100">
                <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                  Commodity
                </span>
                <span className="text-xs sm:text-sm font-bold text-slate-800 block mt-0.5 truncate">
                  {data.commodityName}
                </span>
              </div>

              <div className="p-3 rounded-xl bg-white/80 border border-amber-100 xs:col-span-2 sm:col-span-1">
                <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                  Agreed Volume
                </span>
                <span className="text-xs sm:text-sm font-bold text-slate-800 block mt-0.5">
                  {data.finalQuantity} {data.unitSymbol}
                </span>
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    );
  }

  // 2. Confirmed & Locked Booking State (PRD 38.1)
  const statusBadge = getStatusBadgeStyle(data.bookingStatus);

  return (
    <Card
      className={cn(
        'w-full max-w-full overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-xs',
        className
      )}
    >
      {/* Header: Prominent Booking ID in Ocean Blue (#0284C7) */}
      <CardHeader className="p-4 sm:p-6 border-b border-slate-100 pb-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div className="flex items-start gap-3 min-w-0">
            <div className="w-10 h-10 sm:w-11 sm:h-11 rounded-xl bg-sky-50 text-[#0284C7] flex items-center justify-center shrink-0 border border-sky-100">
              <PackageCheck className="w-5 h-5 sm:w-6 sm:h-6" />
            </div>

            <div className="min-w-0">
              <div className="flex items-center gap-2">
                <span className="text-[10px] sm:text-xs font-bold text-slate-400 uppercase tracking-wider">
                  Physical Booking ID
                </span>
                <span className="inline-flex items-center gap-1 text-[10px] font-semibold text-emerald-700 bg-emerald-50 px-1.5 py-0.5 rounded border border-emerald-200">
                  <ShieldCheck className="w-3 h-3" />
                  Locked
                </span>
              </div>

              {/* Ocean Blue Booking ID with 1-click copy */}
              <div className="flex items-center gap-2 mt-0.5">
                <CardTitle className="text-xl sm:text-2xl font-black tracking-tight text-[#0284C7] truncate">
                  {data.bookingId}
                </CardTitle>

                <Button
                  type="button"
                  variant="ghost"
                  size="icon"
                  onClick={() => handleCopyBookingId(data.bookingId)}
                  className="h-8 w-8 rounded-lg text-slate-400 hover:text-slate-700 hover:bg-slate-100 shrink-0 cursor-pointer"
                  title="Copy Booking ID"
                >
                  {copied ? (
                    <Check className="w-4 h-4 text-emerald-600" />
                  ) : (
                    <Copy className="w-4 h-4" />
                  )}
                  <span className="sr-only">Copy Booking ID</span>
                </Button>
              </div>
            </div>
          </div>

          {/* Current Booking Status Badge */}
          <div className="flex items-center gap-2 self-start sm:self-center">
            <Badge variant={statusBadge.variant} className={cn('text-xs px-3 py-1', statusBadge.className)}>
              {statusBadge.label}
            </Badge>
          </div>
        </div>
      </CardHeader>

      {/* Body: Compact Grid with Deal Reference, Matched Commodity & Locked Quantity */}
      <CardContent className="p-4 sm:p-6 space-y-4">
        <div className="grid grid-cols-1 xs:grid-cols-2 sm:grid-cols-4 gap-3">
          {/* 1. Associated Deal Reference */}
          <div className="p-3 sm:p-3.5 rounded-xl border border-slate-200/80 bg-slate-50/60 space-y-1">
            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
              Deal Reference
            </span>
            <div className="flex items-center gap-1.5">
              <span className="text-xs sm:text-sm font-bold text-slate-900 truncate">
                {data.dealReference}
              </span>
              {data.dealId && (
                <Link
                  href={`/buyer/deals/${data.dealId}`}
                  className="text-slate-400 hover:text-[#0284C7] shrink-0"
                  title="View Deal Snapshot"
                >
                  <ExternalLink className="w-3.5 h-3.5" />
                </Link>
              )}
            </div>
            <span className="text-[11px] text-slate-500 block truncate">
              Mutual Agreement
            </span>
          </div>

          {/* 2. Matched Commodity & Classification */}
          <div className="p-3 sm:p-3.5 rounded-xl border border-slate-200/80 bg-slate-50/60 space-y-1">
            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
              Matched Commodity
            </span>
            <span className="text-xs sm:text-sm font-bold text-slate-900 block truncate">
              {data.commodityName}
            </span>
            <span className="text-[11px] text-slate-500 block truncate">
              {data.gradeName || 'Standard Grade'}
            </span>
          </div>

          {/* 3. Locked Final Quantity */}
          <div className="p-3 sm:p-3.5 rounded-xl border border-slate-200/80 bg-slate-50/60 space-y-1">
            <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider block">
              Locked Final Quantity
            </span>
            <div className="flex items-baseline gap-1">
              <span className="text-base sm:text-lg font-black text-slate-900">
                {data.finalQuantity.toLocaleString('en-IN')}
              </span>
              <span className="text-xs font-semibold text-slate-600">
                {data.unitSymbol}
              </span>
            </div>
            <span className="text-[11px] text-slate-400 block">
              Physical Lot Allocation
            </span>
          </div>

          {/* 4. Locked Landed Rate & Value */}
          <div className="p-3 sm:p-3.5 rounded-xl border border-sky-100 bg-sky-50/40 space-y-1">
            <span className="text-[10px] font-bold text-[#0284C7] uppercase tracking-wider block">
              Total Contract Value
            </span>
            <div className="text-base sm:text-lg font-black text-[#0284C7] truncate">
              {formatCurrencyINR(data.totalEstimatedValue)}
            </div>
            <span className="text-[11px] text-sky-800 font-medium block truncate">
              @{formatCurrencyINR(data.finalRate)}/{data.unitSymbol}
            </span>
          </div>
        </div>

        {/* Footer Governance Seal: Broker Regulated Desk */}
        <div className="p-3 rounded-xl bg-slate-50 border border-slate-200/60 flex flex-col xs:flex-row xs:items-center justify-between gap-2 text-xs text-slate-600">
          <div className="flex items-center gap-2 min-w-0">
            <Building2 className="w-3.5 h-3.5 text-slate-400 shrink-0" />
            <span className="truncate">
              Finalized via <strong>{data.brokerAgency || 'BrokerBridge Verified Commodity Desk'}</strong>
            </span>
          </div>

          <div className="flex items-center gap-1.5 text-[11px] text-slate-400 shrink-0">
            <Calendar className="w-3.5 h-3.5" />
            <span>
              Booked on {new Date(data.createdAt).toLocaleDateString('en-IN', {
                day: '2-digit',
                month: 'short',
                year: 'numeric',
              })}
            </span>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
