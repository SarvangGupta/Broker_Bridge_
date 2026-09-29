'use client';

import React from 'react';
import Link from 'next/link';
import { Card, CardContent, CardFooter } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import {
  ShieldCheck,
  Truck,
  Building,
  Building2,
  MapPin,
  Clock,
  ArrowRight,
  FileText,
  AlertTriangle,
  ShieldAlert,
  PackageCheck,
  Layers,
  Calendar,
} from 'lucide-react';
import { BrokerActiveOrderSummary } from '@/src/server/actions/broker-order-actions';

interface FinalizedDealCardProps {
  order: BrokerActiveOrderSummary;
}

export function FinalizedDealCard({ order }: FinalizedDealCardProps) {
  const isPartial = order.exceptionFlag === 'Partially Fulfilled' || (order.dispatchedQuantity > 0 && order.remainingQuantity > 0);

  return (
    <Card className="border-slate-200/80 bg-white shadow-xs hover:shadow-md transition-all text-slate-900 w-full overflow-hidden flex flex-col justify-between">
      {/* CARD TOP HEADER */}
      <div className="bg-slate-900 text-white p-4 border-b border-slate-800 flex items-center justify-between gap-3">
        <div className="flex items-center gap-2 min-w-0">
          <div className="w-8 h-8 rounded-lg bg-[#0D9488] flex items-center justify-center text-white shrink-0">
            <ShieldCheck className="w-4.5 h-4.5" />
          </div>
          <div className="min-w-0">
            <span className="text-[10px] font-bold uppercase tracking-wider text-teal-400 block">
              Official Booking ID
            </span>
            <span className="text-base font-black font-mono tracking-tight text-white block truncate">
              {order.bookingReference}
            </span>
          </div>
        </div>

        {/* STAGE BADGE */}
        <Badge className="bg-teal-500/20 text-teal-300 border-teal-400/40 text-xs font-mono font-bold px-2.5 py-1 shrink-0">
          {order.fulfillmentStage}
        </Badge>
      </div>

      <CardContent className="p-4 sm:p-5 space-y-4 flex-1">
        {/* EXCEPTION FLAG BADGE (IF ANY) */}
        {order.exceptionFlag && (
          <div className="flex items-center gap-2">
            {order.exceptionFlag === 'Disputed' && (
              <Badge className="bg-rose-100 text-rose-800 border-rose-300 text-[11px] font-bold px-2.5 py-0.5 flex items-center gap-1">
                <ShieldAlert className="w-3 h-3 text-rose-600" />
                Active Dispute
              </Badge>
            )}
            {order.exceptionFlag === 'Delayed' && (
              <Badge className="bg-amber-100 text-amber-800 border-amber-300 text-[11px] font-bold px-2.5 py-0.5 flex items-center gap-1">
                <Clock className="w-3 h-3 text-amber-600" />
                Transit Delay
              </Badge>
            )}
            {order.exceptionFlag === 'Partially Fulfilled' && (
              <Badge className="bg-teal-100 text-teal-800 border-teal-300 text-[11px] font-mono font-bold px-2.5 py-0.5 flex items-center gap-1">
                <PackageCheck className="w-3 h-3 text-[#0D9488]" />
                Partial ({order.dispatchedQuantity} / {order.agreedQuantity} {order.unitSymbol})
              </Badge>
            )}
          </div>
        )}

        {/* COMMODITY & GRADE */}
        <div className="space-y-1">
          <div className="flex items-center justify-between text-xs text-slate-500">
            <span>Commodity & Grade</span>
            <span className="font-mono text-slate-400">Lot #{order.lotNumber}</span>
          </div>
          <h3 className="text-base font-bold text-slate-900 tracking-tight flex items-center gap-2">
            {order.commodityName}
            {order.gradeName && (
              <span className="text-xs font-semibold px-2 py-0.5 rounded-full bg-slate-100 text-slate-700">
                {order.gradeName}
              </span>
            )}
          </h3>
        </div>

        {/* COUNTERPARTY PAIR */}
        <div className="grid grid-cols-2 gap-2 p-3 rounded-xl bg-slate-50 border border-slate-200/60 text-xs">
          <div>
            <span className="text-[10px] font-bold uppercase tracking-wider text-slate-500 flex items-center gap-1">
              <Building className="w-3 h-3 text-blue-600" />
              Buyer
            </span>
            <p className="font-bold text-slate-800 truncate mt-0.5">{order.buyerCompanyName}</p>
          </div>
          <div className="border-l border-slate-200 pl-2">
            <span className="text-[10px] font-bold uppercase tracking-wider text-slate-500 flex items-center gap-1">
              <Building2 className="w-3 h-3 text-teal-600" />
              Seller
            </span>
            <p className="font-bold text-slate-800 truncate mt-0.5">{order.sellerCompanyName}</p>
          </div>
        </div>

        {/* COMMERCIAL METRICS GRID */}
        <div className="grid grid-cols-2 gap-3 text-xs pt-1">
          <div>
            <span className="text-slate-500 block">Agreed Quantity</span>
            <span className="font-mono font-bold text-slate-900 text-sm">
              {order.agreedQuantity} {order.unitSymbol}
            </span>
          </div>
          <div>
            <span className="text-slate-500 block">Total Valuation</span>
            <span className="font-mono font-bold text-teal-800 text-sm">
              ₹{order.totalValuation.toLocaleString('en-IN')}
            </span>
          </div>
        </div>

        {/* LOCATION & DESTINATION */}
        <div className="text-xs text-slate-600 flex items-start gap-1.5 pt-1 border-t border-slate-100">
          <MapPin className="w-3.5 h-3.5 text-slate-400 shrink-0 mt-0.5" />
          <span className="truncate">{order.deliveryLocation}</span>
        </div>
      </CardContent>

      {/* CARD FOOTER ACTIONS */}
      <CardFooter className="p-4 bg-slate-50/80 border-t border-slate-100 flex flex-col sm:flex-row items-center gap-2">
        <Link href={`/broker/orders/${order.bookingReference}`} className="w-full sm:flex-1">
          <Button
            className="w-full h-12 bg-[#0D9488] hover:bg-[#0D9488]/90 text-white font-bold text-xs rounded-xl shadow-xs flex items-center justify-center gap-1.5 cursor-pointer min-h-[48px]"
          >
            <Truck className="w-3.5 h-3.5" />
            <span>View Tracking</span>
            <ArrowRight className="w-3.5 h-3.5 ml-0.5" />
          </Button>
        </Link>

        <Link href={`/broker/deals/${order.quotationId}`} className="w-full sm:w-auto">
          <Button
            variant="outline"
            className="w-full h-12 border-slate-300 text-slate-700 hover:bg-slate-100 font-semibold text-xs rounded-xl flex items-center justify-center gap-1.5 px-3 cursor-pointer min-h-[48px]"
          >
            <FileText className="w-3.5 h-3.5 text-slate-500" />
            <span>Snapshot</span>
          </Button>
        </Link>
      </CardFooter>
    </Card>
  );
}
