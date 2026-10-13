'use client';

import React from 'react';
import {
  Scale,
  ShieldCheck,
} from 'lucide-react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';
import { OrderFulfillmentMath } from '@/src/types/buyer-order-types';

export interface OrderFulfillmentCardProps {
  math?: OrderFulfillmentMath | null;
  originalQuantity?: number;
  bookedQuantity?: number;
  remainingQuantity?: number;
  fulfillmentPercentage?: number;
  unitSymbol?: string;
  className?: string;
}

/**
 * Task 2 (Micro-Sprint 38.3): Partial Fulfillment Visualizer Card.
 * Displays progress bar in Ocean Blue (#0284C7) and the exact 3-column math:
 * 1. Original Quantity
 * 2. Booked Quantity
 * 3. Remaining Unfulfilled Quantity
 * 
 * Strictly Read-Only & 360px Viewport Compliant.
 */
export function OrderFulfillmentCard({
  math,
  originalQuantity: propOriginal,
  bookedQuantity: propBooked,
  remainingQuantity: propRemaining,
  fulfillmentPercentage: propPercent,
  unitSymbol: propUnit = 'MT',
  className,
}: OrderFulfillmentCardProps) {
  const origQty = math?.originalQuantity ?? propOriginal ?? 0;
  const bookedQty = math?.bookedQuantity ?? propBooked ?? 0;
  const remQty = math?.remainingQuantity ?? propRemaining ?? Math.max(0, origQty - bookedQty);
  const unit = math?.unitSymbol || propUnit || 'MT';
  const percent =
    math?.fulfillmentPercentage ??
    propPercent ??
    (origQty > 0 ? Math.round((bookedQty / origQty) * 100) : 100);

  const isComplete = remQty === 0;

  return (
    <Card
      className={cn(
        'w-full max-w-full overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-xs',
        className
      )}
    >
      <CardHeader className="p-4 sm:p-5 border-b border-slate-100 pb-3">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2.5">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-sky-50 text-[#0284C7] flex items-center justify-center shrink-0 border border-sky-100">
              <Scale className="w-4 h-4" />
            </div>
            <div>
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                Fulfillment Engine
              </span>
              <CardTitle className="text-sm sm:text-base font-bold text-slate-900 leading-tight">
                Partial Fulfillment Allocation
              </CardTitle>
            </div>
          </div>

          <Badge
            variant="outline"
            className={cn(
              'w-fit text-xs px-2.5 py-0.5 font-bold',
              isComplete
                ? 'bg-emerald-50 text-emerald-700 border-emerald-200'
                : 'bg-sky-50 text-[#0284C7] border-sky-200'
            )}
          >
            {isComplete ? '100% Fully Fulfilled' : `Partial Allocation (${percent}%)`}
          </Badge>
        </div>
      </CardHeader>

      <CardContent className="p-4 sm:p-5 space-y-4">
        {/* Top: Visual Progress Bar in Ocean Blue (#0284C7) */}
        <div className="space-y-1.5">
          <div className="flex items-center justify-between text-xs">
            <span className="font-semibold text-slate-600 flex items-center gap-1.5">
              <span>Fulfilled Ratio</span>
              <span className="text-slate-400 font-normal">
                ({bookedQty.toLocaleString('en-IN')} of {origQty.toLocaleString('en-IN')} {unit})
              </span>
            </span>
            <span className="font-extrabold text-[#0284C7] text-sm">
              {percent}%
            </span>
          </div>

          <div className="w-full bg-slate-100 rounded-full h-3 overflow-hidden border border-slate-200/60 p-0.5">
            <div
              className="bg-[#0284C7] h-full rounded-full transition-all duration-500 ease-out shadow-2xs"
              style={{ width: `${Math.min(100, Math.max(0, percent))}%` }}
            />
          </div>
        </div>

        {/* Bottom: Clean 3-Column Grid with Exact Required PRD Labels */}
        <div className="w-full max-w-full overflow-x-auto no-scrollbar">
          <div className="grid grid-cols-3 gap-2 sm:gap-3 min-w-[280px]">
            {/* 1. Original Quantity */}
            <div className="p-3 sm:p-3.5 rounded-xl border border-slate-200/80 bg-slate-50/70 space-y-1">
              <span className="text-[10px] sm:text-[11px] font-bold text-slate-400 uppercase tracking-wider block truncate">
                Original Quantity
              </span>
              <div className="text-sm sm:text-base font-extrabold text-slate-900 tracking-tight">
                {origQty.toLocaleString('en-IN')}{' '}
                <span className="text-xs font-semibold text-slate-500">{unit}</span>
              </div>
              <span className="text-[10px] sm:text-[11px] text-slate-500 block truncate">
                Requirement Total
              </span>
            </div>

            {/* 2. Booked Quantity */}
            <div className="p-3 sm:p-3.5 rounded-xl border border-sky-100 bg-sky-50/50 space-y-1">
              <span className="text-[10px] sm:text-[11px] font-bold text-[#0284C7] uppercase tracking-wider block truncate">
                Booked Quantity
              </span>
              <div className="text-sm sm:text-base font-extrabold text-[#0284C7] tracking-tight">
                {bookedQty.toLocaleString('en-IN')}{' '}
                <span className="text-xs font-bold text-sky-700">{unit}</span>
              </div>
              <span className="text-[10px] sm:text-[11px] text-sky-800 font-medium block truncate">
                Locked & Confirmed
              </span>
            </div>

            {/* 3. Remaining Unfulfilled Quantity */}
            <div
              className={cn(
                'p-3 sm:p-3.5 rounded-xl border space-y-1',
                remQty > 0
                  ? 'border-amber-200 bg-amber-50/50'
                  : 'border-emerald-200 bg-emerald-50/50'
              )}
            >
              <span
                className={cn(
                  'text-[10px] sm:text-[11px] font-bold uppercase tracking-wider block truncate',
                  remQty > 0 ? 'text-amber-800' : 'text-emerald-800'
                )}
              >
                Remaining Unfulfilled Quantity
              </span>
              <div
                className={cn(
                  'text-sm sm:text-base font-extrabold tracking-tight',
                  remQty > 0 ? 'text-amber-900' : 'text-emerald-900'
                )}
              >
                {remQty.toLocaleString('en-IN')}{' '}
                <span className="text-xs font-semibold">{unit}</span>
              </div>
              <span
                className={cn(
                  'text-[10px] sm:text-[11px] block truncate',
                  remQty > 0 ? 'text-amber-700' : 'text-emerald-700'
                )}
              >
                {remQty > 0 ? 'Open for Next Lot' : 'All Tranches Booked'}
              </span>
            </div>
          </div>
        </div>

        {/* Read-Only Transparency Footnote */}
        <div className="flex items-center gap-2 pt-1 text-[11px] text-slate-500">
          <ShieldCheck className="w-3.5 h-3.5 text-emerald-600 shrink-0" />
          <p className="truncate">
            Read-only aggregation calculated across all finalized broker bookings for this requirement.
          </p>
        </div>
      </CardContent>
    </Card>
  );
}
