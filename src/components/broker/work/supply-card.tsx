'use client';

import React from 'react';
import {
  Building2,
  ShieldCheck,
  MapPin,
  Calendar,
  Lock,
  Truck,
  CheckCircle2,
  Layers,
  ChevronRight,
  Clock,
  Sparkles,
  Info,
} from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { formatIndianCurrency } from '@/lib/utils';
import type { BrokerSupplyLot } from '@/src/server/actions/broker-supply-actions';

interface SupplyCardProps {
  lot: BrokerSupplyLot;
  requirementId?: string;
  onSelectLot?: (lot: BrokerSupplyLot) => void;
}

export function SupplyCard({ lot, requirementId, onSelectLot }: SupplyCardProps) {
  const formattedUnit = lot.unitSymbol || lot.unitName || 'MT';
  const formattedAskingPrice = formatIndianCurrency(lot.askingPrice);
  const formattedFloorPrice = lot.confidentialMinimumPrice
    ? formatIndianCurrency(lot.confidentialMinimumPrice)
    : formattedAskingPrice;

  // Loading Status Badge styling
  const getLoadingStatusBadge = (status: string) => {
    const s = status.toLowerCase();
    if (s.includes('ready') && !s.includes('not')) {
      return (
        <Badge className="bg-emerald-50 text-emerald-700 border-emerald-200 hover:bg-emerald-50 text-[11px] font-semibold flex items-center gap-1 shrink-0">
          <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
          <span>Ready to Load</span>
        </Badge>
      );
    }
    if (s.includes('progress') || s.includes('loading')) {
      return (
        <Badge className="bg-blue-50 text-blue-700 border-blue-200 hover:bg-blue-50 text-[11px] font-semibold flex items-center gap-1 shrink-0">
          <Truck className="w-3 h-3 text-blue-500" />
          <span>Loading Active</span>
        </Badge>
      );
    }
    if (s.includes('delayed') || s.includes('blocked')) {
      return (
        <Badge className="bg-amber-50 text-amber-700 border-amber-200 hover:bg-amber-50 text-[11px] font-semibold flex items-center gap-1 shrink-0">
          <Clock className="w-3 h-3 text-amber-500" />
          <span>Delayed</span>
        </Badge>
      );
    }
    return (
      <Badge className="bg-slate-100 text-slate-600 border-slate-200 hover:bg-slate-100 text-[11px] font-medium">
        {lot.loadingStatus || 'Not Ready'}
      </Badge>
    );
  };

  return (
    <Card className="w-full bg-white border border-slate-200/80 shadow-2xs hover:shadow-md transition-all duration-200 rounded-xl overflow-hidden flex flex-col justify-between">
      <div className="p-4 sm:p-5 space-y-3.5">
        {/* Header: Seller Company Name & Lot ID */}
        <div className="flex items-start justify-between gap-2">
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-1.5 flex-wrap">
              <span className="font-bold text-slate-900 text-sm sm:text-base truncate tracking-tight">
                {lot.sellerCompanyName}
              </span>
              {lot.sellerCompanyVerified && (
                <span title="Verified Seller Profile" className="text-[#0D9488] shrink-0">
                  <ShieldCheck className="w-4 h-4 fill-teal-50" />
                </span>
              )}
            </div>
            <div className="flex items-center gap-2 mt-0.5 text-xs text-slate-400 font-mono">
              <span>{lot.lotNumber}</span>
              <span>•</span>
              <span className="text-slate-500 font-sans font-medium text-[11px]">
                Trust Score: {lot.sellerTrustScore}%
              </span>
            </div>
          </div>

          {/* Loading Status Badge */}
          {getLoadingStatusBadge(lot.loadingStatus)}
        </div>

        {/* Commodity & Grade Banner */}
        <div className="bg-slate-50/90 rounded-lg p-2.5 border border-slate-100/90 space-y-1">
          <div className="flex items-center gap-1.5 text-[11px] font-medium text-slate-500 truncate">
            {lot.industryName && <span>{lot.industryName}</span>}
            {lot.categoryName && (
              <>
                <span>•</span>
                <span>{lot.categoryName}</span>
              </>
            )}
          </div>
          <div className="flex items-center justify-between gap-2 flex-wrap">
            <span className="font-bold text-slate-800 text-sm sm:text-base">
              {lot.commodityName}{' '}
              <span className="text-[#0D9488] font-semibold text-xs sm:text-sm">
                • {lot.gradeName}
              </span>
            </span>
            {lot.commodityCode && (
              <span className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-white text-slate-500 border border-slate-200/60">
                {lot.commodityCode}
              </span>
            )}
          </div>
        </div>

        {/* Available Volume & Location Grid */}
        <div className="grid grid-cols-2 gap-2.5 pt-1">
          {/* Available Quantity */}
          <div className="p-2.5 rounded-lg bg-slate-50/60 border border-slate-100">
            <span className="text-[11px] font-medium text-slate-400 uppercase tracking-wider block">
              Available Supply
            </span>
            <div className="mt-0.5 flex items-baseline gap-1">
              <span className="text-base sm:text-lg font-extrabold text-slate-900 tracking-tight">
                {lot.availableQuantity.toLocaleString('en-IN')}
              </span>
              <span className="text-xs font-semibold text-slate-600">{formattedUnit}</span>
            </div>
            <span className="text-[10px] text-slate-400 block mt-0.5 truncate">
              Total Lot: {lot.totalQuantity} {formattedUnit}
            </span>
          </div>

          {/* Location */}
          <div className="p-2.5 rounded-lg bg-slate-50/60 border border-slate-100">
            <span className="text-[11px] font-medium text-slate-400 uppercase tracking-wider block">
              Location
            </span>
            <div className="mt-0.5 flex items-center gap-1 text-slate-800 font-semibold text-xs sm:text-sm truncate">
              <MapPin className="w-3.5 h-3.5 text-[#0D9488] shrink-0" />
              <span className="truncate">
                {lot.districtName ? `${lot.districtName}, ` : ''}
                {lot.stateName || 'India'}
              </span>
            </div>
            <span className="text-[10px] text-slate-400 block mt-0.5 truncate">
              Valid until: {lot.validUntilFormatted}
            </span>
          </div>
        </div>

        {/* Pricing Section (CRITICAL GUARDRAIL 1: Asking Price + Confidential Minimum Price) */}
        <div className="p-3 rounded-xl bg-slate-50/90 border border-slate-200/70 space-y-2">
          {/* Public Asking Price */}
          <div className="flex items-baseline justify-between gap-2">
            <span className="text-xs font-semibold text-slate-500">Seller Asking Price:</span>
            <div className="flex items-baseline gap-1">
              <span className="text-base sm:text-lg font-extrabold text-slate-900">
                {formattedAskingPrice}
              </span>
              <span className="text-xs font-semibold text-slate-500">/ {formattedUnit}</span>
            </div>
          </div>

          {/* Confidential Floor Price (Authorized for Broker Only) */}
          <div className="flex items-center justify-between gap-2 pt-1.5 border-t border-slate-200/60">
            <div className="flex items-center gap-1.5 text-xs font-bold text-amber-700">
              <Lock className="w-3.5 h-3.5 text-amber-600 shrink-0" />
              <span>Broker Floor (Confidential Min):</span>
            </div>
            <div className="bg-amber-100/70 border border-amber-200/80 px-2 py-0.5 rounded text-xs font-mono font-bold text-amber-900">
              {formattedFloorPrice}
            </div>
          </div>
        </div>

        {/* Additional operational details */}
        {lot.loadingRemarks && (
          <div className="text-[11px] text-slate-500 italic bg-white p-2 rounded border border-slate-100">
            &ldquo;{lot.loadingRemarks}&rdquo;
          </div>
        )}
      </div>

      {/* Action Row */}
      {/* TOUCH TARGET RULE: min-h-[48px] */}
      <div className="p-3 sm:p-4 bg-slate-50/60 border-t border-slate-100">
        <Button
          type="button"
          onClick={() => {
            if (onSelectLot) {
              onSelectLot(lot);
            }
          }}
          className="w-full min-h-[48px] h-12 bg-[#0D9488] hover:bg-teal-700 text-white font-bold text-sm shadow-xs rounded-lg transition-all flex items-center justify-center gap-2"
        >
          <Sparkles className="w-4 h-4 shrink-0" />
          <span>Select Lot for Negotiation</span>
          <ChevronRight className="w-4 h-4 ml-auto opacity-70 shrink-0" />
        </Button>
      </div>
    </Card>
  );
}
