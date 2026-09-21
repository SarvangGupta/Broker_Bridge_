'use client';

import React from 'react';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import {
  History,
  CheckCircle2,
  XCircle,
  ArrowUpDown,
  FileText,
  Clock,
  User,
  Building,
  Sparkles,
  ShieldCheck,
} from 'lucide-react';
import type { NegotiationTimelineItem } from '@/src/types/deal-version-schema';

interface BrokerBuyerTimelineProps {
  requirementId: string;
  timeline: NegotiationTimelineItem[];
  isLoading?: boolean;
}

export function BrokerBuyerTimeline({
  requirementId,
  timeline = [],
  isLoading = false,
}: BrokerBuyerTimelineProps) {
  if (isLoading) {
    return (
      <div className="space-y-4 py-4 animate-pulse">
        <div className="h-4 bg-slate-200 rounded-md w-1/3"></div>
        <div className="space-y-3">
          {[1, 2, 3].map((i) => (
            <div key={i} className="p-4 bg-slate-100 rounded-xl space-y-2">
              <div className="h-3 bg-slate-200 rounded-md w-1/4"></div>
              <div className="h-3 bg-slate-200 rounded-md w-3/4"></div>
            </div>
          ))}
        </div>
      </div>
    );
  }

  if (!timeline || timeline.length === 0) {
    return (
      <Card className="border-dashed border border-slate-200 bg-slate-50/50">
        <CardContent className="p-6 text-center space-y-2">
          <History className="w-8 h-8 text-slate-400 mx-auto" />
          <p className="text-xs font-semibold text-slate-600">No Buyer Channel History</p>
          <p className="text-[11px] text-slate-400">
            Initial commercial proposal is awaiting submission to the Buyer.
          </p>
        </CardContent>
      </Card>
    );
  }

  const formatPrice = (val?: number | string | null) => {
    if (!val) return null;
    const num = Number(val);
    if (isNaN(num)) return val;
    return `₹${num.toLocaleString('en-IN')}`;
  };

  const cleanSummaryText = (summary?: string | null, details?: any): string => {
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
  };

  return (
    <div className="w-full space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <History className="w-4 h-4 text-[#0D9488]" />
          <h4 className="font-bold text-xs sm:text-sm text-slate-900 tracking-tight">
            Buyer Channel Timeline & Proposal History
          </h4>
        </div>
        <span className="text-[10px] font-mono text-slate-500 bg-slate-100 px-2 py-0.5 rounded-md">
          {timeline.length} {timeline.length === 1 ? 'event' : 'events'}
        </span>
      </div>

      {/* Timeline Rail */}
      <div className="relative pl-6 sm:pl-8 space-y-6 before:absolute before:left-2.5 sm:before:left-3.5 before:top-2 before:bottom-2 before:w-0.5 before:bg-slate-200">
        {timeline.map((item, idx) => {
          const isLatest = idx === timeline.length - 1;
          const isBuyer = item.actorRole?.toLowerCase().includes('buyer') || item.title?.toLowerCase().includes('buyer');

          // Node Icon selection
          let icon = <FileText className="w-3.5 h-3.5 text-slate-600" />;
          let nodeBg = 'bg-slate-100 border-slate-300';

          if (item.status === 'BUYER_ACCEPTED' || item.status === 'Buyer Accepted') {
            icon = <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" />;
            nodeBg = 'bg-emerald-100 border-emerald-300';
          } else if (item.status === 'BUYER_REJECTED' || item.status === 'Buyer Rejected') {
            icon = <XCircle className="w-3.5 h-3.5 text-rose-600" />;
            nodeBg = 'bg-rose-100 border-rose-300';
          } else if (item.status === 'BUYER_COUNTER' || item.status === 'Countered') {
            icon = <ArrowUpDown className="w-3.5 h-3.5 text-amber-600" />;
            nodeBg = 'bg-amber-100 border-amber-300';
          } else if (item.status === 'Proposed to Buyer' || item.status === 'BROKER_PROPOSAL_TO_BUYER') {
            icon = <Sparkles className="w-3.5 h-3.5 text-[#0D9488]" />;
            nodeBg = 'bg-teal-100 border-teal-300';
          }

          const details = item.details || {};
          const displayPrice = formatPrice(details.rate || details.landedPrice || details.counterPrice);
          const displayQty = details.quantity || details.counterQuantity;
          const unitSym = details.unitSymbol || 'MT';

          return (
            <div key={item.id || idx} className="relative group">
              {/* Timeline Node Dot */}
              <div
                className={`absolute -left-6 sm:-left-8 top-1.5 w-6 h-6 sm:w-7 sm:h-7 rounded-full border-2 ${nodeBg} flex items-center justify-center shadow-2xs z-10 transition-transform group-hover:scale-110`}
              >
                {icon}
              </div>

              {/* Event Card */}
              <div
                className={`p-3.5 sm:p-4 rounded-xl border transition-all ${
                  isLatest
                    ? 'bg-white border-teal-200/90 shadow-sm ring-1 ring-teal-500/10'
                    : 'bg-slate-50/70 border-slate-200/80 hover:bg-white'
                }`}
              >
                {/* Top Badge & Actor Header */}
                <div className="flex flex-wrap items-center justify-between gap-2 mb-2">
                  <div className="flex items-center gap-2">
                    {item.versionNumber && (
                      <span className="px-1.5 py-0.5 rounded-md font-mono text-[10px] font-bold bg-slate-900 text-white">
                        v{item.versionNumber}
                      </span>
                    )}

                    <Badge
                      variant="outline"
                      className={`text-[10px] font-semibold ${
                        isBuyer
                          ? 'bg-blue-50 text-blue-700 border-blue-200'
                          : 'bg-teal-50 text-teal-700 border-teal-200'
                      }`}
                    >
                      {isBuyer ? (
                        <Building className="w-3 h-3 mr-1 inline" />
                      ) : (
                        <User className="w-3 h-3 mr-1 inline" />
                      )}
                      {isBuyer ? 'Buyer Mandate' : 'Broker Desk'}
                    </Badge>

                    <Badge
                      variant="secondary"
                      className={`text-[10px] font-medium ${
                        item.status === 'Superseded'
                          ? 'bg-slate-100 text-slate-400 line-through'
                          : 'bg-slate-100 text-slate-700'
                      }`}
                    >
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

                {/* Main Event Title */}
                <h5 className="font-bold text-xs sm:text-sm text-slate-900 mb-1">
                  {item.title}
                </h5>

                {/* Summary Text */}
                <p className="text-xs text-slate-600 mb-2 leading-relaxed">
                  {cleanSummaryText(item.summary, item.details)}
                </p>

                {/* Highlighted Terms Pill Grid */}
                {(displayPrice || displayQty || details.deliveryDate || details.paymentTerms) && (
                  <div className="grid grid-cols-2 sm:grid-cols-3 gap-2 mt-2 p-2.5 rounded-lg bg-slate-100/70 text-[11px]">
                    {displayPrice && (
                      <div>
                        <span className="text-slate-400 block text-[9px] uppercase font-mono">Landed Rate</span>
                        <span className="font-bold text-slate-800">{displayPrice}/{unitSym}</span>
                      </div>
                    )}
                    {displayQty && (
                      <div>
                        <span className="text-slate-400 block text-[9px] uppercase font-mono">Quantity</span>
                        <span className="font-semibold text-slate-800">{displayQty} {unitSym}</span>
                      </div>
                    )}
                    {details.deliveryDate && (
                      <div>
                        <span className="text-slate-400 block text-[9px] uppercase font-mono">Target Delivery</span>
                        <span className="font-medium text-slate-800">{details.deliveryDate}</span>
                      </div>
                    )}
                  </div>
                )}

                {/* Remarks / Message */}
                {(details.remarks || details.brokerNotes || details.counterRemarks) && (
                  <div className="mt-2.5 text-[11px] text-slate-500 italic bg-blue-50/50 p-2 rounded-md border border-blue-100/60">
                    &ldquo;{details.remarks || details.brokerNotes || details.counterRemarks}&rdquo;
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
