'use client';

import React from 'react';
import { 
  MessageSquareQuote, 
  ShieldCheck, 
  Sparkles, 
  UserCheck2,
  Lock
} from 'lucide-react';
import { BuyerProposalDetail } from '@/src/types/buyer-proposal';
import { cn } from '@/lib/utils';

interface BrokerMessageCardProps {
  proposal: BuyerProposalDetail;
  className?: string;
}

export function BrokerMessageCard({ proposal, className }: BrokerMessageCardProps) {
  const note = proposal.brokerNotes || 'This commercial proposal has been validated by your assigned broker desk. Review terms and submit counter-terms or acceptance.';

  return (
    <div
      className={cn(
        'w-full max-w-full overflow-x-hidden bg-gradient-to-r from-sky-50/90 via-sky-50/50 to-white rounded-2xl border border-sky-200/90 shadow-2xs p-4 sm:p-5 space-y-3',
        className
      )}
    >
      {/* 1. Header with Broker Attribution */}
      <div className="flex flex-wrap items-center justify-between gap-2 pb-2.5 border-b border-sky-100">
        <div className="flex items-center gap-2.5">
          <div className="w-9 h-9 rounded-xl bg-[#0284C7] text-white flex items-center justify-center font-bold text-sm shadow-xs">
            {proposal.brokerName.slice(0, 1).toUpperCase()}
          </div>
          <div>
            <div className="flex items-center gap-2">
              <span className="text-sm font-bold text-slate-900 leading-tight">
                {proposal.brokerName}
              </span>
              <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-semibold bg-sky-100/80 text-[#0284C7]">
                <ShieldCheck className="w-3 h-3" />
                <span>{proposal.brokerAgency || 'Verified Broker Desk'}</span>
              </span>
            </div>
            <p className="text-[11px] text-slate-500">
              Commercial Intermediary & Transaction Mediator
            </p>
          </div>
        </div>

        <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-[#0284C7]">
          <MessageSquareQuote className="w-3.5 h-3.5" />
          <span>Broker Remarks</span>
        </span>
      </div>

      {/* 2. Message Quote Content */}
      <div className="relative pl-3.5 py-1 border-l-2 border-[#0284C7]">
        <p className="text-xs sm:text-sm text-slate-800 font-medium leading-relaxed italic break-words">
          "{note}"
        </p>
      </div>

      {/* 3. Mediation & Disintermediation Protection Note */}
      <div className="flex items-center gap-1.5 pt-1 text-[11px] text-slate-500">
        <Lock className="w-3.5 h-3.5 text-slate-400 shrink-0" />
        <span className="leading-tight">
          Broker-mediated channel: Seller credentials and private minimum floors remain shielded under platform rules.
        </span>
      </div>
    </div>
  );
}
