'use client';

import React from 'react';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import {
  History,
  TrendingUp,
  Building2,
  Building,
  User,
  Clock,
  Sparkles,
  Lock,
  ArrowUpDown,
  CheckCircle2,
  XCircle,
  FileText,
  IndianRupee,
  ShieldCheck,
} from 'lucide-react';

export interface MarginSpreadInfo {
  askingPrice: number;
  confidentialMinimumPrice: number | null;
  buyerTargetPrice: number;
  currentOfferedPrice: number;
  grossSpread: number;
  currentMargin: number;
  unitSymbol: string;
  commodityName: string;
  sellerCompanyName: string;
}

export interface MasterTimelineItem {
  id: string;
  type: 'DEAL_VERSION' | 'NEGOTIATION_ACTION';
  channel: 'seller' | 'buyer' | 'broker';
  versionNumber?: number;
  title: string;
  status: string;
  actorName: string;
  actorRole: string;
  summary: string;
  details?: any;
  createdAt: string;
}

interface BrokerMasterTimelineProps {
  marginSpread?: MarginSpreadInfo | null;
  timeline?: MasterTimelineItem[];
  isLoading?: boolean;
}

function cleanSummaryText(summary?: string | null, details?: any): string {
  if (!summary) return 'Negotiation event logged.';
  if (typeof summary === 'string' && (summary.trim().startsWith('{') || summary.trim().startsWith('['))) {
    try {
      const p = JSON.parse(summary.trim());
      const payload = typeof p === 'object' && p !== null ? p : details || {};
      const parts = [];
      const rateVal = payload.counterPrice || payload.offered_price || payload.rate || payload.offeredPrice || payload.landedPrice;
      if (rateVal) parts.push(`Rate: ₹${Number(rateVal).toLocaleString('en-IN')}`);
      const qtyVal = payload.counterQuantity || payload.quantity;
      if (qtyVal) parts.push(`Qty: ${qtyVal}`);
      const delDate = payload.counterDeliveryDate || payload.delivery_date || payload.deliveryDate;
      if (delDate) parts.push(`Delivery: ${delDate}`);
      const notes = payload.counterRemarks || payload.broker_notes || payload.brokerNotes || payload.remarks || payload.notes;
      if (notes) parts.push(`Notes: "${notes}"`);
      return parts.length > 0 ? parts.join(' • ') : 'Negotiation terms updated.';
    } catch {
      return 'Negotiation event logged.';
    }
  }
  return summary;
}

export function BrokerMasterTimeline({
  marginSpread,
  timeline = [],
  isLoading = false,
}: BrokerMasterTimelineProps) {
  if (isLoading) {
    return (
      <div className="space-y-4 py-4 animate-pulse">
        <div className="h-20 bg-slate-200 rounded-xl"></div>
        <div className="space-y-3">
          {[1, 2, 3].map((i) => (
            <div key={i} className="h-16 bg-slate-100 rounded-xl"></div>
          ))}
        </div>
      </div>
    );
  }

  const unitSym = marginSpread?.unitSymbol || 'MT';

  return (
    <div className="w-full space-y-6">
      {/* 1. MARGIN SPREAD SUMMARY CARD (BROKER EYES ONLY) */}
      {marginSpread && (
        <Card className="border border-[#0D9488]/30 shadow-xs bg-gradient-to-br from-slate-900 via-slate-800 to-teal-950 text-white overflow-hidden">
          <CardContent className="p-4 sm:p-5 space-y-3">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div className="flex items-center gap-2 min-w-0">
                <TrendingUp className="w-4 h-4 text-teal-400 shrink-0" />
                <h4 className="font-bold text-xs sm:text-sm text-white tracking-tight truncate">
                  Master Commercial Margin Spread
                </h4>
              </div>
              <Badge className="bg-teal-500/20 text-teal-300 border-teal-500/30 text-[10px] uppercase font-mono shrink-0">
                BROKER DESK EYES ONLY
              </Badge>
            </div>

            <div className="grid grid-cols-2 gap-2.5 pt-1">
              {/* Seller Asking / Min Floor */}
              <div className="p-2.5 rounded-lg bg-white/5 border border-white/10 min-w-0">
                <span className="text-[10px] text-slate-400 font-mono uppercase block truncate">Seller Min Floor</span>
                <span className="text-xs sm:text-sm font-bold text-emerald-300 truncate block">
                  ₹{(marginSpread.confidentialMinimumPrice || marginSpread.askingPrice).toLocaleString('en-IN')}/{unitSym}
                </span>
              </div>

              {/* Buyer Target */}
              <div className="p-2.5 rounded-lg bg-white/5 border border-white/10 min-w-0">
                <span className="text-[10px] text-slate-400 font-mono uppercase block truncate">Buyer Target</span>
                <span className="text-xs sm:text-sm font-bold text-blue-300 truncate block">
                  ₹{marginSpread.buyerTargetPrice.toLocaleString('en-IN')}/{unitSym}
                </span>
              </div>

              {/* Broker Landed Offer */}
              <div className="p-2.5 rounded-lg bg-white/5 border border-white/10 min-w-0">
                <span className="text-[10px] text-slate-400 font-mono uppercase block truncate">Landed Offer Rate</span>
                <span className="text-xs sm:text-sm font-bold text-teal-300 truncate block">
                  ₹{marginSpread.currentOfferedPrice.toLocaleString('en-IN')}/{unitSym}
                </span>
              </div>

              {/* Net Spread / Margin */}
              <div className="p-2.5 rounded-lg bg-teal-500/20 border border-teal-500/40 min-w-0">
                <span className="text-[10px] text-teal-300 font-mono uppercase block truncate">Gross Margin Spread</span>
                <span className="text-xs sm:text-sm font-bold text-white truncate block">
                  {marginSpread.grossSpread >= 0 ? '+' : ''}₹{marginSpread.grossSpread.toLocaleString('en-IN')}/{unitSym}
                </span>
              </div>
            </div>
          </CardContent>
        </Card>
      )}

      {/* 2. UNIFIED CHRONOLOGICAL MASTER TIMELINE */}
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <History className="w-4 h-4 text-[#0D9488]" />
            <h4 className="font-bold text-xs sm:text-sm text-slate-900 tracking-tight">
              Unified Dual-Channel Negotiation Timeline
            </h4>
          </div>
          <span className="text-[10px] font-mono text-slate-500 bg-slate-100 px-2 py-0.5 rounded-md">
            {timeline.length} total events
          </span>
        </div>

        {timeline.length === 0 ? (
          <Card className="border-dashed border border-slate-200 bg-slate-50/50">
            <CardContent className="p-6 text-center space-y-2">
              <History className="w-8 h-8 text-slate-400 mx-auto" />
              <p className="text-xs font-semibold text-slate-600">No Negotiation Events Logged</p>
              <p className="text-[11px] text-slate-400">
                Actions dispatches on both Seller and Buyer streams will appear here chronologically.
              </p>
            </CardContent>
          </Card>
        ) : (
          <div className="relative pl-6 sm:pl-8 space-y-6 before:absolute before:left-2.5 sm:before:left-3.5 before:top-2 before:bottom-2 before:w-0.5 before:bg-slate-200">
            {timeline.map((item, idx) => {
              const isLatest = idx === timeline.length - 1;

              // Color-coded node logic per PRD requirements:
              // - Indigo/Blue for Buyer events
              // - Emerald/Green for Seller events
              // - Electric Teal for Broker mediation actions
              let nodeBg = 'bg-teal-100 border-teal-300 text-teal-700';
              let badgeStyle = 'bg-teal-50 text-teal-700 border-teal-200';
              let channelLabel = 'Broker Mediation';

              if (item.channel === 'buyer') {
                nodeBg = 'bg-blue-100 border-blue-400 text-blue-800';
                badgeStyle = 'bg-blue-50 text-blue-700 border-blue-200';
                channelLabel = 'Buyer Stream';
              } else if (item.channel === 'seller') {
                nodeBg = 'bg-emerald-100 border-emerald-400 text-emerald-800';
                badgeStyle = 'bg-purple-50 text-purple-700 border-purple-200';
                channelLabel = 'Seller Stream';
              }

              const details = item.details || {};

              return (
                <div key={item.id || idx} className="relative group">
                  {/* Timeline Dot */}
                  <div
                    className={`absolute -left-6 sm:-left-8 top-1.5 w-6 h-6 sm:w-7 sm:h-7 rounded-full border-2 ${nodeBg} flex items-center justify-center shadow-2xs z-10`}
                  >
                    {item.channel === 'buyer' ? (
                      <Building className="w-3.5 h-3.5" />
                    ) : item.channel === 'seller' ? (
                      <Building2 className="w-3.5 h-3.5" />
                    ) : (
                      <Sparkles className="w-3.5 h-3.5 text-[#0D9488]" />
                    )}
                  </div>

                  {/* Card Container */}
                  <div
                    className={`p-3.5 sm:p-4 rounded-xl border transition-all ${
                      isLatest
                        ? 'bg-white border-teal-200/90 shadow-sm ring-1 ring-teal-500/10'
                        : 'bg-slate-50/70 border-slate-200/80 hover:bg-white'
                    }`}
                  >
                    <div className="flex flex-wrap items-center justify-between gap-2 mb-2">
                      <div className="flex items-center gap-2">
                        {item.versionNumber && (
                          <span className="px-1.5 py-0.5 rounded-md font-mono text-[10px] font-bold bg-slate-900 text-white">
                            v{item.versionNumber}
                          </span>
                        )}

                        <Badge variant="outline" className={`text-[10px] font-semibold ${badgeStyle}`}>
                          {channelLabel}
                        </Badge>

                        <Badge variant="secondary" className="text-[10px] font-medium bg-slate-100 text-slate-700">
                          {item.status}
                        </Badge>
                      </div>

                      <div className="flex items-center gap-1 text-[11px] text-slate-400 font-mono">
                        <Clock className="w-3 h-3" />
                        <span>
                          {new Date(item.createdAt).toLocaleTimeString('en-IN', {
                            hour: '2-digit',
                            minute: '2-digit',
                          })}
                        </span>
                      </div>
                    </div>

                    <h5 className="font-bold text-xs sm:text-sm text-slate-900 mb-1">
                      {item.title}
                    </h5>

                    <p className="text-xs text-slate-600 mb-2 leading-relaxed">
                      {cleanSummaryText(item.summary, item.details)}
                    </p>

                    {/* Format Rate / Quantity details */}
                    {(details.rate || details.landedPrice || details.offeredPrice || details.counterPrice) && (
                      <div className="grid grid-cols-2 gap-2 mt-2 p-2 rounded-lg bg-slate-100/70 text-[11px]">
                        <div>
                          <span className="text-slate-400 block text-[9px] uppercase font-mono">Rate</span>
                          <span className="font-bold text-slate-800">
                            ₹{Number(details.rate || details.landedPrice || details.offeredPrice || details.counterPrice).toLocaleString('en-IN')}/{unitSym}
                          </span>
                        </div>
                        {details.quantity && (
                          <div>
                            <span className="text-slate-400 block text-[9px] uppercase font-mono">Quantity</span>
                            <span className="font-semibold text-slate-800">{details.quantity} {unitSym}</span>
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
