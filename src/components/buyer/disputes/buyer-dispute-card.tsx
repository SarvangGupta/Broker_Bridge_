'use client';

import React from 'react';
import Link from 'next/link';
import {
  AlertTriangle,
  Scale,
  Truck,
  FileText,
  CreditCard,
  Briefcase,
  HelpCircle,
  Clock,
  CheckCircle2,
  ArrowRight,
  ShieldCheck,
  Calendar,
  ExternalLink,
  ShieldAlert,
} from 'lucide-react';
import { Card, CardHeader, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';
import {
  BuyerDisputeCategory,
  BuyerDisputeItem,
  BuyerDisputeStatus,
} from '@/src/types/buyer-dispute-types';

export interface BuyerDisputeCardProps {
  dispute: BuyerDisputeItem;
  className?: string;
}

/**
 * Task 3 (Micro-Sprint 39.4): Buyer Dispute Card Component.
 * 
 * Displays an active or resolved dispute filed by the Buyer.
 * 
 * STRICT UX RULE:
 * This is a strictly read-only tracker. There is NO chat box or messaging channel.
 * Disputes are mediated exclusively through the neutral Broker desk.
 */
export function BuyerDisputeCard({ dispute, className }: BuyerDisputeCardProps) {
  const formattedDate = new Date(dispute.createdAt).toLocaleDateString('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });

  const formattedResolvedDate = dispute.resolvedAt
    ? new Date(dispute.resolvedAt).toLocaleDateString('en-IN', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
      })
    : null;

  return (
    <Card
      className={cn(
        'w-full max-w-full overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-xs transition-shadow hover:shadow-sm space-y-0',
        className
      )}
    >
      {/* Top Banner Row */}
      <CardHeader className="p-4 sm:p-5 border-b border-slate-100 pb-3">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2.5">
          {/* Booking & Commodity Identification */}
          <div className="space-y-0.5 min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <Link
                href={`/buyer/orders/${dispute.bookingId}`}
                className="font-mono text-xs font-bold text-[#0284C7] hover:underline"
              >
                {dispute.bookingId}
              </Link>
              <span className="text-slate-300">•</span>
              {renderCategoryBadge(dispute.category)}
            </div>

            <h3 className="text-sm sm:text-base font-bold text-slate-900 truncate">
              {dispute.commodityName}
            </h3>
            {dispute.gradeName && (
              <span className="text-[11px] text-slate-500 block truncate">
                {dispute.gradeName}
              </span>
            )}
          </div>

          {/* Status Badge */}
          <div className="self-start sm:self-auto shrink-0">
            {renderDisputeStatusBadge(dispute.status)}
          </div>
        </div>
      </CardHeader>

      <CardContent className="p-4 sm:p-5 space-y-4">
        {/* Date & Initiation Tag */}
        <div className="flex items-center justify-between text-xs text-slate-500 border-b border-slate-100 pb-2.5">
          <div className="flex items-center gap-1.5">
            <Calendar className="w-3.5 h-3.5 text-slate-400" />
            <span>Raised: {formattedDate}</span>
          </div>

          <span className="inline-flex items-center gap-1 text-[10px] font-bold uppercase tracking-wider text-slate-600 bg-slate-100 px-2 py-0.5 rounded-md">
            Initiated by Buyer
          </span>
        </div>

        {/* Description Section */}
        <div className="space-y-1">
          <span className="text-[10px] font-bold uppercase tracking-wider text-slate-400 block">
            Discrepancy Details
          </span>
          <p className="text-xs sm:text-sm text-slate-700 leading-relaxed whitespace-pre-wrap">
            {dispute.description}
          </p>
        </div>

        {/* Evidence Attachments */}
        {dispute.evidenceUrls.length > 0 && (
          <div className="space-y-1.5 pt-1">
            <span className="text-[10px] font-bold uppercase tracking-wider text-slate-400 block">
              Supporting Evidence Files ({dispute.evidenceUrls.length})
            </span>
            <div className="flex flex-wrap gap-2">
              {dispute.evidenceUrls.map((url, idx) => (
                <a
                  key={idx}
                  href={url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1.5 min-h-[44px] px-3 py-1.5 rounded-xl border border-slate-200 bg-slate-50 hover:bg-slate-100 text-xs font-semibold text-slate-700 transition-colors shadow-2xs"
                >
                  <FileText className="w-3.5 h-3.5 text-[#0284C7]" />
                  <span>Evidence Document #{idx + 1}</span>
                  <ExternalLink className="w-3 h-3 text-slate-400" />
                </a>
              ))}
            </div>
          </div>
        )}

        {/* Resolution Milestone (if resolved) */}
        {dispute.status === 'Resolved' && (
          <div className="p-3 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-900 text-xs space-y-1">
            <div className="flex items-center gap-1.5 font-bold">
              <CheckCircle2 className="w-4 h-4 text-emerald-700 shrink-0" />
              <span>Resolution Finalized by Broker Desk</span>
            </div>
            <p className="text-[11px] text-emerald-800 leading-relaxed">
              This dispute was formally closed on {formattedResolvedDate}. Any applicable weight adjustments, rate deductions, or escrow balances have been reconciled in your contract payable ledger.
            </p>
          </div>
        )}

        {/* Read-Only Mediation Footnote & Navigation Deep-Link */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pt-2 border-t border-slate-100">
          <div className="flex items-center gap-2 text-[11px] text-slate-500">
            <ShieldCheck className="w-4 h-4 text-[#0284C7] shrink-0" />
            <span>Fiduciary Mediation — Direct seller messaging disabled</span>
          </div>

          <Link
            href={`/buyer/orders/${dispute.bookingId}`}
            className="inline-flex items-center justify-center min-h-[48px] px-3.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 text-slate-800 text-xs font-bold shadow-2xs transition-colors gap-1.5 w-full sm:w-auto"
          >
            <span>View Order & Financial Ledger</span>
            <ArrowRight className="w-3.5 h-3.5 text-slate-400" />
          </Link>
        </div>
      </CardContent>
    </Card>
  );
}

/**
 * Category Badge with distinctive colors
 */
function renderCategoryBadge(category: BuyerDisputeCategory) {
  switch (category) {
    case 'Quality':
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-rose-50 text-rose-700 border border-rose-200">
          <AlertTriangle className="w-3 h-3 text-rose-600" />
          Quality
        </span>
      );
    case 'Quantity':
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-orange-50 text-orange-700 border border-orange-200">
          <Scale className="w-3 h-3 text-orange-600" />
          Quantity
        </span>
      );
    case 'Delivery':
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-amber-50 text-amber-700 border border-amber-200">
          <Truck className="w-3 h-3 text-amber-600" />
          Delivery
        </span>
      );
    case 'Document':
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-sky-50 text-sky-700 border border-sky-200">
          <FileText className="w-3 h-3 text-sky-600" />
          Document
        </span>
      );
    case 'Payment':
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-purple-50 text-purple-700 border border-purple-200">
          <CreditCard className="w-3 h-3 text-purple-600" />
          Payment
        </span>
      );
    case 'Commercial':
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-indigo-50 text-indigo-700 border border-indigo-200">
          <Briefcase className="w-3 h-3 text-indigo-600" />
          Commercial
        </span>
      );
    case 'Other':
    default:
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-slate-100 text-slate-700 border border-slate-200">
          <HelpCircle className="w-3 h-3 text-slate-500" />
          Other
        </span>
      );
  }
}

/**
 * Dispute status badge
 */
function renderDisputeStatusBadge(status: BuyerDisputeStatus) {
  switch (status) {
    case 'Resolved':
      return (
        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-emerald-100 text-emerald-800 border border-emerald-300 shadow-2xs">
          <CheckCircle2 className="w-3.5 h-3.5 text-emerald-700" />
          Resolved
        </span>
      );
    case 'Under Broker Review':
      return (
        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-amber-100 text-amber-800 border border-amber-300 shadow-2xs">
          <Clock className="w-3.5 h-3.5 text-amber-700" />
          Under Broker Review
        </span>
      );
    case 'Open':
    default:
      return (
        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-sky-100 text-sky-800 border border-sky-300 shadow-2xs">
          <Clock className="w-3.5 h-3.5 text-sky-700" />
          Open
        </span>
      );
  }
}
