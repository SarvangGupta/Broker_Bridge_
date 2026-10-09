'use client';

import React from 'react';
import { 
  Receipt, 
  ShieldCheck, 
  Info, 
  Check, 
  HelpCircle,
  TrendingDown,
  ArrowRight
} from 'lucide-react';
import { BuyerProposalDetail } from '@/src/types/buyer-proposal';
import { cn } from '@/lib/utils';

interface DetailCommercialBreakdownProps {
  proposal: BuyerProposalDetail;
  className?: string;
}

function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('en-IN', {
    maximumFractionDigits: 0,
  }).format(amount);
}

export function DetailCommercialBreakdown({
  proposal,
  className,
}: DetailCommercialBreakdownProps) {
  const hasCharges = proposal.applicableCharges && proposal.applicableCharges.length > 0;

  return (
    <div
      className={cn(
        'w-full max-w-full overflow-x-hidden bg-white rounded-2xl border border-slate-200 shadow-xs p-4 sm:p-6 space-y-5',
        className
      )}
    >
      {/* 1. Header */}
      <div className="flex items-center justify-between gap-3 pb-3 border-b border-slate-100">
        <div className="flex items-center gap-2.5">
          <div className="w-9 h-9 rounded-xl bg-sky-50 text-[#0284C7] flex items-center justify-center border border-sky-100">
            <Receipt className="w-5 h-5" />
          </div>
          <div>
            <h2 className="text-base sm:text-lg font-bold text-slate-900 leading-tight">
              Commercial & Cost Breakdown
            </h2>
            <p className="text-xs text-slate-500">
              Transparent itemized pricing for {formatCurrency(proposal.proposedQuantity)} {proposal.unitSymbol}
            </p>
          </div>
        </div>

        <span className="hidden sm:inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
          <ShieldCheck className="w-3.5 h-3.5" />
          <span>Zero Hidden Fees</span>
        </span>
      </div>

      {/* 2. Itemized Breakdown Table / Cards */}
      <div className="space-y-3">
        {/* Base Commodity Price */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between p-3.5 rounded-xl bg-slate-50 border border-slate-200/80 gap-2">
          <div className="space-y-0.5">
            <div className="flex items-center gap-2">
              <span className="text-xs sm:text-sm font-bold text-slate-900">
                Base Commodity Rate
              </span>
              <span className="px-2 py-0.5 text-[10px] font-semibold rounded bg-slate-200/80 text-slate-700">
                Offered Floor
              </span>
            </div>
            <p className="text-xs text-slate-500">
              Direct physical commodity rate as negotiated with supplier
            </p>
          </div>

          <div className="text-left sm:text-right shrink-0">
            <div className="text-sm sm:text-base font-bold text-slate-900">
              ₹{formatCurrency(proposal.basePricePerUnit)}{' '}
              <span className="text-xs font-normal text-slate-500">
                / {proposal.unitSymbol}
              </span>
            </div>
            <div className="text-xs text-slate-400">
              Subtotal: ₹{formatCurrency(proposal.basePricePerUnit * proposal.proposedQuantity)}
            </div>
          </div>
        </div>

        {/* Itemized Buyer-Side Charges */}
        {hasCharges && (
          <div className="space-y-2 pt-1">
            <div className="flex items-center justify-between text-xs font-semibold text-slate-500 uppercase tracking-wider px-1">
              <span>Applicable Buyer-Side Charges</span>
              <span>Rate / Amount</span>
            </div>

            <div className="divide-y divide-slate-100 rounded-xl border border-slate-200/80 overflow-hidden bg-white">
              {proposal.applicableCharges.map((charge, idx) => (
                <div
                  key={idx}
                  className="flex flex-col sm:flex-row sm:items-center justify-between p-3 gap-2 hover:bg-slate-50/60 transition-colors"
                >
                  <div className="space-y-0.5 min-w-0 pr-2">
                    <div className="flex items-center gap-2">
                      <span className="text-xs sm:text-sm font-semibold text-slate-800 break-words">
                        {charge.name}
                      </span>
                      {charge.includedInLandedPrice && (
                        <span className="px-1.5 py-0.5 rounded text-[10px] font-medium bg-sky-50 text-[#0284C7] border border-sky-100">
                          Included
                        </span>
                      )}
                    </div>
                    {charge.description && (
                      <p className="text-[11px] text-slate-400 leading-normal">
                        {charge.description}
                      </p>
                    )}
                  </div>

                  <div className="text-left sm:text-right shrink-0">
                    <div className="text-xs sm:text-sm font-bold text-slate-700">
                      {charge.type === 'per_unit' && charge.rate
                        ? `+ ₹${formatCurrency(charge.rate)} / ${proposal.unitSymbol}`
                        : `₹${formatCurrency(charge.amount)}`}
                    </div>
                    <div className="text-[11px] text-slate-400">
                      ₹{formatCurrency(charge.amount)} total
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Total Charges Summary */}
        {hasCharges && (
          <div className="flex items-center justify-between px-3 py-2 text-xs rounded-lg bg-sky-50/50 border border-sky-100 text-[#0284C7] font-medium">
            <span>Total Buyer Charges & Statutory Facilitation:</span>
            <span className="font-bold">
              + ₹{formatCurrency(proposal.totalChargesPerUnit)} / {proposal.unitSymbol} (₹{formatCurrency(proposal.totalChargesPerUnit * proposal.proposedQuantity)})
            </span>
          </div>
        )}
      </div>

      {/* 3. Final Net Landed Summary Banner */}
      <div className="p-4 rounded-xl bg-gradient-to-br from-sky-50 via-sky-50/60 to-white border-2 border-sky-200 space-y-3">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div>
            <div className="text-xs font-bold uppercase tracking-wider text-[#0284C7]">
              Final Landed Commercial Terms
            </div>
            <div className="text-xs text-slate-600 mt-0.5">
              Net payable rate per {proposal.unitSymbol} at designated destination
            </div>
          </div>

          <div className="text-left sm:text-right">
            <div className="text-2xl sm:text-3xl font-black text-[#0284C7]">
              ₹{formatCurrency(proposal.netLandedPricePerUnit)}
              <span className="text-sm font-bold text-slate-600 ml-1">
                / {proposal.unitSymbol}
              </span>
            </div>
            <div className="text-xs font-semibold text-slate-700 mt-0.5">
              Net Total: ₹{formatCurrency(proposal.totalEstimatedValue)}
            </div>
          </div>
        </div>

        {/* Escrow Protection Note */}
        <div className="flex items-start gap-2 pt-2 border-t border-sky-200/80 text-[11px] text-slate-500">
          <Info className="w-4 h-4 text-[#0284C7] shrink-0 mt-0.5" />
          <p className="leading-relaxed">
            Funds will be held in regulated escrow until physical delivery weighment and quality COA approval are signed off. No charges are billed prior to order finalization.
          </p>
        </div>
      </div>
    </div>
  );
}
