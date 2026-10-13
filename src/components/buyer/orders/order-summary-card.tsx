'use client';

import React from 'react';
import Link from 'next/link';
import {
  PackageCheck,
  Truck,
  MapPin,
  ArrowRight,
  Calendar,
  Layers,
  Building2,
  ShieldCheck,
} from 'lucide-react';
import { Card, CardHeader, CardTitle, CardContent, CardFooter } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { BuyerOrderItem } from '@/src/types/buyer-order-types';
import { formatCurrencyINR } from '@/src/utils/visual-diff-engine';

interface OrderSummaryCardProps {
  order: BuyerOrderItem;
  className?: string;
}

/**
 * Maps logistics status to color-coded badge.
 */
function getOrderStatusStyle(status: string): {
  className: string;
  label: string;
} {
  const norm = status.toLowerCase().trim();

  if (norm.includes('transit')) {
    return {
      className: 'bg-indigo-50 text-indigo-700 border-indigo-200 font-bold',
      label: 'In Transit',
    };
  }

  if (norm.includes('dispatch planned') || norm.includes('planned')) {
    return {
      className: 'bg-sky-50 text-sky-700 border-sky-200 font-bold',
      label: 'Dispatch Planned',
    };
  }

  if (norm.includes('dispatched')) {
    return {
      className: 'bg-blue-50 text-blue-700 border-blue-200 font-bold',
      label: 'Dispatched',
    };
  }

  if (norm.includes('delivered') || norm.includes('completed')) {
    return {
      className: 'bg-emerald-50 text-emerald-800 border-emerald-300 font-bold',
      label: 'Delivered',
    };
  }

  if (norm.includes('cancelled')) {
    return {
      className: 'bg-red-50 text-red-700 border-red-200 font-bold',
      label: 'Cancelled',
    };
  }

  // Default: Booked / Confirmed
  return {
    className: 'bg-emerald-50 text-emerald-700 border-emerald-200 font-bold',
    label: 'Booked',
  };
}

/**
 * Task 2 (Micro-Sprint 38.2): Mobile-First Order Summary Card.
 * Displays an active procurement order with locked Booking ID and status badge.
 */
export function OrderSummaryCard({ order, className }: OrderSummaryCardProps) {
  const statusStyle = getOrderStatusStyle(order.status);
  const formattedDate = new Date(order.createdAt).toLocaleDateString('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  });

  return (
    <Card
      className={cn(
        'w-full max-w-full overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-xs hover:shadow-md transition-all flex flex-col justify-between group',
        className
      )}
    >
      <div>
        {/* Header: Prominent Booking ID in Ocean Blue (#0284C7) + Status Badge */}
        <CardHeader className="p-4 sm:p-5 pb-3 border-b border-slate-100">
          <div className="flex items-start justify-between gap-2.5">
            <div className="min-w-0">
              <div className="flex items-center gap-1.5 mb-1">
                <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">
                  Booking Reference
                </span>
                <span className="inline-flex items-center gap-0.5 text-[9px] font-semibold text-emerald-700 bg-emerald-50 px-1 py-0.2 rounded border border-emerald-200">
                  <ShieldCheck className="w-2.5 h-2.5" />
                  Locked
                </span>
              </div>
              <CardTitle className="text-lg sm:text-xl font-black text-[#0284C7] tracking-tight truncate group-hover:text-[#0369A1] transition-colors">
                {order.bookingId}
              </CardTitle>
            </div>

            <Badge variant="outline" className={cn('text-xs px-2.5 py-0.5 shrink-0', statusStyle.className)}>
              {statusStyle.label}
            </Badge>
          </div>
        </CardHeader>

        {/* Body: Commodity & Grade, Final Quantity, and Delivery Location */}
        <CardContent className="p-4 sm:p-5 space-y-3.5">
          {/* Commodity & Grade Header */}
          <div className="space-y-0.5">
            <div className="flex items-center gap-1.5 text-xs font-semibold text-slate-500">
              <Layers className="w-3.5 h-3.5 text-slate-400 shrink-0" />
              <span className="truncate">{order.commodityName}</span>
            </div>
            <p className="text-sm font-bold text-slate-900 truncate">
              {order.gradeName || 'Standard Commercial Grade'}
            </p>
          </div>

          {/* Key Metrics: Quantity & Total Value */}
          <div className="grid grid-cols-2 gap-2 p-3 rounded-xl bg-slate-50/80 border border-slate-200/60">
            <div>
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                Agreed Volume
              </span>
              <div className="text-sm sm:text-base font-extrabold text-slate-900 mt-0.5">
                {order.finalQuantity.toLocaleString('en-IN')}{' '}
                <span className="text-xs font-semibold text-slate-500">{order.unitSymbol}</span>
              </div>
            </div>

            <div>
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                Total Value
              </span>
              <div className="text-sm sm:text-base font-extrabold text-[#0284C7] mt-0.5 truncate">
                {formatCurrencyINR(order.totalEstimatedValue)}
              </div>
            </div>
          </div>

          {/* Delivery Location */}
          <div className="flex items-start gap-2 text-xs text-slate-600">
            <MapPin className="w-3.5 h-3.5 text-slate-400 shrink-0 mt-0.5" />
            <div className="min-w-0">
              <span className="text-slate-400 text-[10px] uppercase font-bold block">
                Delivery Location
              </span>
              <span className="font-medium text-slate-800 line-clamp-1">
                {order.deliveryLocation}
              </span>
            </div>
          </div>

          {/* Booked Date & Agency */}
          <div className="flex items-center justify-between text-[11px] text-slate-400 pt-1 border-t border-slate-100">
            <div className="flex items-center gap-1">
              <Calendar className="w-3 h-3 text-slate-400" />
              <span>Booked on {formattedDate}</span>
            </div>
            <span className="truncate max-w-[120px] text-right">
              {order.dealReference}
            </span>
          </div>
        </CardContent>
      </div>

      {/* Action Footer: "Track Order" button (min-h-[48px] touch target) */}
      <CardFooter className="p-4 sm:p-5 pt-0">
        <Link
          href={`/buyer/orders/${order.bookingId}`}
          className="w-full inline-flex items-center justify-between min-h-[48px] h-12 px-4 rounded-xl border border-slate-200 text-slate-800 hover:text-[#0284C7] hover:border-sky-300 hover:bg-sky-50 font-bold text-xs sm:text-sm transition-all cursor-pointer group-hover:border-sky-200 shadow-2xs"
        >
          <span className="inline-flex items-center">
            <Truck className="w-4 h-4 mr-2 text-[#0284C7]" />
            <span>Track Order</span>
          </span>
          <ArrowRight className="w-4 h-4 text-slate-400 group-hover:text-[#0284C7] group-hover:translate-x-0.5 transition-all" />
        </Link>
      </CardFooter>
    </Card>
  );
}
