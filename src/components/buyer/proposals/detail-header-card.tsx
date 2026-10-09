'use client';

import React from 'react';
import Link from 'next/link';
import { 
  Building2, 
  Calendar, 
  CheckCircle2, 
  Clock, 
  ExternalLink, 
  Layers, 
  Sparkles, 
  Tag, 
  XCircle, 
  AlertCircle, 
  RefreshCw 
} from 'lucide-react';
import { BuyerProposalDetail } from '@/src/types/buyer-proposal';
import { getProposalStatusMeta, ProposalStatus } from '@/src/utils/proposal-mappers';
import { cn } from '@/lib/utils';

interface DetailHeaderCardProps {
  proposal: BuyerProposalDetail;
  className?: string;
}

function getStatusIcon(status: ProposalStatus) {
  switch (status) {
    case 'Accepted':
      return <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" />;
    case 'New':
      return <Sparkles className="w-3.5 h-3.5 text-[#0284C7]" />;
    case 'Countered':
      return <RefreshCw className="w-3.5 h-3.5 text-[#0284C7]" />;
    case 'Pending Response':
      return <Clock className="w-3.5 h-3.5 text-amber-600" />;
    case 'Rejected':
      return <XCircle className="w-3.5 h-3.5 text-rose-600" />;
    case 'Expired':
      return <AlertCircle className="w-3.5 h-3.5 text-slate-500" />;
    default:
      return null;
  }
}

function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('en-IN', {
    maximumFractionDigits: 0,
  }).format(amount);
}

function formatDate(dateStr: string | null): string {
  if (!dateStr) return 'N/A';
  const d = new Date(dateStr);
  return d.toLocaleDateString('en-IN', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export function DetailHeaderCard({ proposal, className }: DetailHeaderCardProps) {
  const statusMeta = getProposalStatusMeta(proposal.status);
  const statusIcon = getStatusIcon(proposal.status);
  const displayId = `PROP-${proposal.id.slice(0, 8).toUpperCase()}`;

  return (
    <div
      className={cn(
        'w-full max-w-full overflow-x-hidden bg-white rounded-2xl border border-slate-200 shadow-xs p-4 sm:p-6 space-y-5',
        className
      )}
    >
      {/* 1. Top Badges & Meta Row */}
      <div className="flex flex-wrap items-center justify-between gap-2.5">
        <div className="flex flex-wrap items-center gap-2">
          {/* Proposal ID */}
          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-lg text-xs font-bold bg-slate-100 text-slate-800 border border-slate-200/80">
            <Tag className="w-3.5 h-3.5 text-slate-500" />
            <span>{displayId}</span>
          </span>

          {/* Version Badge */}
          <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-xs font-semibold bg-sky-50 text-[#0284C7] border border-sky-200">
            <Layers className="w-3 h-3" />
            <span>Version {proposal.versionNumber}</span>
          </span>

          {/* Linked Requirement */}
          <Link
            href={`/buyer/requirements/${proposal.requirementId}`}
            className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-xs font-medium text-slate-600 hover:text-[#0284C7] hover:bg-slate-50 border border-slate-200 transition-colors"
            title="View original requirement"
          >
            <span>{proposal.requirementDisplayId}</span>
            <ExternalLink className="w-3 h-3 text-slate-400" />
          </Link>
        </div>

        {/* Status Badge & Auto-Clean Timer */}
        <div className="flex items-center gap-2 flex-wrap">
          <span
            className={cn(
              'inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold border',
              statusMeta.badgeClass
            )}
          >
            {statusIcon}
            <span>{statusMeta.label}</span>
          </span>

          {proposal.status === 'Rejected' && (
            proposal.isArchived ? (
              <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-slate-100 text-slate-600 border border-slate-200">
                <Clock className="w-3.5 h-3.5 text-slate-400" />
                <span>Archived (Cleaned from Inbox)</span>
              </span>
            ) : proposal.autoCleanRemainingHours !== undefined ? (
              <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-rose-50 text-rose-700 border border-rose-200">
                <Clock className="w-3.5 h-3.5 text-rose-500" />
                <span>Auto-cleans in {proposal.autoCleanRemainingHours}h</span>
              </span>
            ) : null
          )}
        </div>
      </div>

      {/* 2. Commodity Title & Grade */}
      <div className="space-y-1">
        <div className="flex items-center gap-2 text-xs font-semibold text-[#0284C7] tracking-wider uppercase">
          <span>Broker Proposal</span>
          <span>•</span>
          <span>{proposal.brokerName}</span>
        </div>
        <h1 className="text-xl sm:text-2xl lg:text-3xl font-extrabold text-slate-900 tracking-tight break-words">
          {proposal.commodityName}
        </h1>
        <p className="text-sm sm:text-base font-medium text-slate-600 flex items-center gap-2">
          <span className="inline-block w-2 h-2 rounded-full bg-slate-300" />
          <span>{proposal.gradeName}</span>
        </p>
      </div>

      {/* 3. Primary Commercial Highlight Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 p-4 rounded-xl bg-slate-50/80 border border-slate-200/90">
        {/* Proposed Quantity */}
        <div className="space-y-1">
          <span className="text-xs font-medium text-slate-500 uppercase tracking-wider block">
            Offered Volume
          </span>
          <div className="flex items-baseline gap-1.5">
            <span className="text-xl sm:text-2xl font-bold text-slate-900">
              {formatCurrency(proposal.proposedQuantity)}
            </span>
            <span className="text-xs sm:text-sm font-semibold text-slate-600">
              {proposal.unitSymbol}
            </span>
          </div>
          <span className="text-[11px] text-slate-400 block">
            100% allocation reserved
          </span>
        </div>

        {/* Net Landed Price per Unit in Ocean Blue */}
        <div className="space-y-1 sm:border-x sm:border-slate-200 sm:px-4">
          <span className="text-xs font-semibold text-[#0284C7] uppercase tracking-wider block">
            Net Landed Price
          </span>
          <div className="flex items-baseline gap-1">
            <span className="text-xl sm:text-2xl font-black text-[#0284C7]">
              ₹{formatCurrency(proposal.netLandedPricePerUnit)}
            </span>
            <span className="text-xs sm:text-sm font-semibold text-slate-600">
              / {proposal.unitSymbol}
            </span>
          </div>
          <span className="text-[11px] text-slate-500 block">
            Includes all fees & cess
          </span>
        </div>

        {/* Total Estimated Value */}
        <div className="space-y-1 sm:pl-2">
          <span className="text-xs font-medium text-slate-500 uppercase tracking-wider block">
            Total Order Value
          </span>
          <div className="flex items-baseline gap-1">
            <span className="text-xl sm:text-2xl font-bold text-slate-900">
              ₹{formatCurrency(proposal.totalEstimatedValue)}
            </span>
          </div>
          <span className="text-[11px] text-slate-400 block">
            Estimated payable at escrow
          </span>
        </div>
      </div>

      {/* 4. Timeline & Action Callout */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2.5 pt-2 border-t border-slate-100 text-xs text-slate-500">
        <div className="flex items-center gap-2">
          <Calendar className="w-3.5 h-3.5 text-slate-400 shrink-0" />
          <span>Proposed on {formatDate(proposal.createdAt)}</span>
        </div>

        {proposal.validUntil && (
          <div className="flex items-center gap-2 font-medium">
            <Clock className="w-3.5 h-3.5 text-amber-500 shrink-0" />
            <span className={cn(proposal.isExpired ? 'text-rose-600 font-semibold' : 'text-slate-600')}>
              {proposal.isExpired ? 'Validity Expired' : `Valid until ${formatDate(proposal.validUntil)}`}
            </span>
          </div>
        )}
      </div>
    </div>
  );
}
