'use client';

import React from 'react';
import Link from 'next/link';
import { 
  ArrowRight, 
  Clock, 
  CheckCircle2, 
  XCircle, 
  RefreshCw, 
  FileText, 
  UserCheck, 
  Calendar,
  Sparkles,
  AlertCircle
} from 'lucide-react';
import { Card, CardHeader, CardContent, CardFooter } from '@/components/ui/card';
import { BuyerProposalItem } from '@/src/types/buyer-proposal';
import { getProposalStatusMeta, ProposalStatus } from '@/src/utils/proposal-mappers';
import { cn } from '@/lib/utils';

export interface ProposalCardProps {
  proposal: BuyerProposalItem;
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
    maximumFractionDigits: 2,
  }).format(amount);
}

function formatDate(dateStr: string | null): string {
  if (!dateStr) return '';
  const d = new Date(dateStr);
  return d.toLocaleDateString('en-IN', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
}

export function ProposalCard({ proposal, className }: ProposalCardProps) {
  const meta = getProposalStatusMeta(proposal.status);
  const statusIcon = getStatusIcon(proposal.status);

  return (
    <Card
      className={cn(
        "group w-full max-w-full overflow-hidden rounded-2xl bg-white border border-slate-200/90 shadow-2xs hover:shadow-md hover:border-sky-300 transition-all duration-200 flex flex-col justify-between break-words",
        proposal.status === 'New' && "border-sky-200 ring-1 ring-sky-100",
        className
      )}
    >
      {/* 1. Header: Commodity & Grade + State Badge */}
      <CardHeader className="p-4 sm:p-5 border-b border-slate-100/90 bg-slate-50/40">
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-2 flex-wrap mb-1">
              <h3 className="text-base sm:text-lg font-bold text-slate-900 tracking-tight truncate leading-snug">
                {proposal.commodityName}
              </h3>
              {proposal.versionNumber > 1 && (
                <span className="inline-flex items-center px-1.5 py-0.5 rounded-md text-[10px] font-semibold bg-sky-50 text-[#0284C7] border border-sky-200">
                  v{proposal.versionNumber}
                </span>
              )}
            </div>
            <p className="text-xs sm:text-sm text-slate-500 font-medium truncate">
              {proposal.gradeName}
            </p>
          </div>

          {/* State Badge & Auto-Clean Timer */}
          <div className="flex flex-col items-end gap-1.5 shrink-0">
            <div
              className={cn(
                "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold border shrink-0 transition-colors",
                meta.badgeClass
              )}
            >
              <span className={cn("w-1.5 h-1.5 rounded-full shrink-0", meta.dotClass)} />
              <span>{meta.label}</span>
            </div>

            {proposal.status === 'Rejected' && proposal.autoCleanRemainingHours !== undefined && (
              <span className="inline-flex items-center gap-1 text-[10px] font-semibold text-rose-700 bg-rose-50 px-2 py-0.5 rounded-md border border-rose-200">
                <Clock className="w-3 h-3 text-rose-500" />
                <span>Auto-cleans in {proposal.autoCleanRemainingHours}h</span>
              </span>
            )}
          </div>
        </div>
      </CardHeader>

      {/* 2. Body: Proposed Quantity, Proposed Price (Landed), and Requirement ID */}
      <CardContent className="p-4 sm:p-5 space-y-4 flex-1">
        {/* Core Commercial Numbers Grid */}
        <div className="grid grid-cols-2 gap-3 p-3 rounded-xl bg-slate-50/70 border border-slate-100">
          <div>
            <span className="text-[11px] font-medium text-slate-500 uppercase tracking-wider block mb-0.5">
              Proposed Qty
            </span>
            <span className="text-sm sm:text-base font-bold text-slate-900">
              {proposal.proposedQuantity.toLocaleString('en-IN')}{' '}
              <span className="text-xs font-semibold text-slate-600">{proposal.unitSymbol}</span>
            </span>
          </div>

          <div>
            <span className="text-[11px] font-medium text-slate-500 uppercase tracking-wider block mb-0.5">
              Landed Price
            </span>
            <span className="text-sm sm:text-base font-bold text-[#0284C7]">
              ₹{formatCurrency(proposal.proposedPrice)}{' '}
              <span className="text-xs font-semibold text-slate-600">/ {proposal.unitSymbol}</span>
            </span>
          </div>

          {proposal.totalEstimatedValue > 0 && (
            <div className="col-span-2 pt-2 border-t border-slate-200/60 flex items-center justify-between">
              <span className="text-xs font-medium text-slate-500">
                Total Landed Value
              </span>
              <span className="text-xs sm:text-sm font-bold text-slate-900">
                ₹{formatCurrency(proposal.totalEstimatedValue)}
              </span>
            </div>
          )}
        </div>

        {/* Association Metadata (Requirement ID + Broker) */}
        <div className="space-y-2 pt-1 text-xs text-slate-600">
          {/* Linked Requirement Ref */}
          <div className="flex items-center justify-between gap-2">
            <span className="text-slate-500 flex items-center gap-1.5 shrink-0">
              <FileText className="w-3.5 h-3.5 text-slate-400" />
              Requirement Ref
            </span>
            <Link
              href={`/buyer/requirements/${proposal.requirementId}`}
              className="font-mono font-semibold text-slate-800 hover:text-[#0284C7] bg-slate-100 hover:bg-sky-50 px-2 py-0.5 rounded border border-slate-200 hover:border-sky-200 transition-colors truncate max-w-[150px]"
              title={`View Requirement ${proposal.requirementDisplayId}`}
            >
              {proposal.requirementDisplayId}
            </Link>
          </div>

          {/* Broker Attribution */}
          <div className="flex items-center justify-between gap-2">
            <span className="text-slate-500 flex items-center gap-1.5 shrink-0">
              <UserCheck className="w-3.5 h-3.5 text-slate-400" />
              Mediated By
            </span>
            <span className="font-semibold text-slate-800 truncate max-w-[160px]">
              {proposal.brokerName}
            </span>
          </div>

          {/* Validity or Delivery Date if applicable */}
          {proposal.validUntil && (
            <div className="flex items-center justify-between gap-2">
              <span className="text-slate-500 flex items-center gap-1.5 shrink-0">
                <Calendar className="w-3.5 h-3.5 text-slate-400" />
                Valid Until
              </span>
              <span
                className={cn(
                  "font-medium",
                  proposal.isExpired ? "text-rose-600 font-semibold" : "text-slate-700"
                )}
              >
                {formatDate(proposal.validUntil)}
              </span>
            </div>
          )}
        </div>
      </CardContent>

      {/* 3. Footer: Clear Next Action banner + Touch-First View Proposal Button */}
      <CardFooter className="p-4 sm:p-5 pt-0 flex flex-col gap-3 border-t border-slate-100 bg-white">
        {/* Clear Next Action Callout Banner */}
        <div className="w-full flex items-center justify-between gap-2 px-3 py-2 rounded-xl bg-slate-50 border border-slate-200/80 text-xs">
          <div className="flex items-center gap-2 min-w-0">
            {statusIcon}
            <span className="text-slate-500 font-medium shrink-0">Next Action:</span>
            <span className="font-bold text-slate-900 truncate">
              {proposal.status === 'Rejected' && proposal.autoCleanRemainingHours !== undefined
                ? `Declined • Removed in ${proposal.autoCleanRemainingHours}h`
                : proposal.nextAction}
            </span>
          </div>
        </div>

        {/* View Proposal Button (Strict min-h-[48px] touch target for 360px usability) */}
        <Link
          href={`/buyer/proposals/${proposal.id}`}
          className="w-full flex items-center justify-center min-h-[48px] px-4 rounded-xl bg-[#0284C7] hover:bg-[#0369A1] active:bg-[#075985] text-white font-semibold text-sm shadow-xs hover:shadow transition-all duration-150 group-hover:bg-[#0284C7]"
        >
          <span>View Proposal</span>
          <ArrowRight className="w-4 h-4 ml-2 transition-transform duration-150 group-hover:translate-x-0.5" />
        </Link>
      </CardFooter>
    </Card>
  );
}
