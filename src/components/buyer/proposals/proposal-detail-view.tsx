'use client';

import React, { useState } from 'react';
import { 
  FileText, 
  History, 
  Sparkles, 
  Layers, 
  Receipt,
  Scale
} from 'lucide-react';
import { BuyerProposalDetail, BuyerProposalVersionItem } from '@/src/types/buyer-proposal';
import { DetailHeaderCard } from '@/src/components/buyer/proposals/detail-header-card';
import { BrokerMessageCard } from '@/src/components/buyer/proposals/broker-message-card';
import { DetailCommercialBreakdown } from '@/src/components/buyer/proposals/detail-commercial-breakdown';
import { DetailTermsGrid } from '@/src/components/buyer/proposals/detail-terms-grid';
import { ProposalVersionTimeline } from '@/src/components/buyer/proposals/proposal-version-timeline';
import { cn } from '@/lib/utils';

interface ProposalDetailViewProps {
  proposal: BuyerProposalDetail;
  versions: BuyerProposalVersionItem[];
}

export function ProposalDetailView({ proposal, versions }: ProposalDetailViewProps) {
  const [activeTab, setActiveTab] = useState<'current' | 'history'>('current');
  const roundsCount = versions.length;

  return (
    <div className="w-full max-w-full overflow-x-hidden space-y-6">
      {/* 1. Header Card (Always Visible on Top) */}
      <DetailHeaderCard proposal={proposal} />

      {/* 2. Primary Navigation Tabs: Current Commercials vs. Version History */}
      <div className="flex items-center gap-2 border-b border-slate-200 pb-1">
        <button
          type="button"
          onClick={() => setActiveTab('current')}
          className={cn(
            'flex items-center gap-2 min-h-[48px] px-4 sm:px-6 rounded-xl text-xs sm:text-sm font-bold transition-all border cursor-pointer',
            activeTab === 'current'
              ? 'bg-[#0284C7] text-white border-[#0284C7] shadow-xs'
              : 'bg-white hover:bg-slate-50 text-slate-600 border-slate-200'
          )}
        >
          <Receipt className="w-4 h-4" />
          <span>Active Terms & Commercials</span>
          <span
            className={cn(
              'px-1.5 py-0.5 rounded text-[10px] font-bold',
              activeTab === 'current'
                ? 'bg-white/20 text-white'
                : 'bg-slate-100 text-slate-700'
            )}
          >
            v{proposal.versionNumber}
          </span>
        </button>

        <button
          type="button"
          onClick={() => setActiveTab('history')}
          className={cn(
            'flex items-center gap-2 min-h-[48px] px-4 sm:px-6 rounded-xl text-xs sm:text-sm font-bold transition-all border cursor-pointer',
            activeTab === 'history'
              ? 'bg-[#0284C7] text-white border-[#0284C7] shadow-xs'
              : 'bg-white hover:bg-slate-50 text-slate-600 border-slate-200'
          )}
        >
          <History className="w-4 h-4" />
          <span>Version History & Ledger</span>
          <span
            className={cn(
              'px-2 py-0.5 rounded-full text-[10px] font-bold',
              activeTab === 'history'
                ? 'bg-white/20 text-white'
                : 'bg-sky-100 text-[#0284C7]'
            )}
          >
            {roundsCount} {roundsCount === 1 ? 'Round' : 'Rounds'}
          </span>
        </button>
      </div>

      {/* 3. Tab Content View */}
      {activeTab === 'current' ? (
        <div className="space-y-6 animate-in fade-in-50 duration-150">
          {/* Broker Message Callout */}
          <BrokerMessageCard proposal={proposal} />

          {/* Commercial & Cost Breakdown */}
          <DetailCommercialBreakdown proposal={proposal} />

          {/* Stacked Terms Grid (Quality, Logistics, Payment) */}
          <DetailTermsGrid proposal={proposal} />
        </div>
      ) : (
        <div className="space-y-6 animate-in fade-in-50 duration-150">
          {/* Version Timeline & Historical Comparison Ledger */}
          <ProposalVersionTimeline versions={versions} />
        </div>
      )}
    </div>
  );
}
