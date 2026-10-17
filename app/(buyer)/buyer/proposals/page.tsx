import React from 'react';
import { getBuyerProposalsInboxAction } from '@/src/server/actions/buyer-proposal-actions';
import { ProposalsInboxView } from '@/src/components/buyer/proposals/proposals-inbox-view';
import { Handshake } from 'lucide-react';

export const dynamic = 'force-dynamic';

export default async function BuyerProposalsPage() {
  const response = await getBuyerProposalsInboxAction();
  const proposals = response.success && response.data ? response.data : [];

  return (
    <div className="w-full max-w-full overflow-x-hidden space-y-6 p-4 sm:p-6 lg:p-8">
      {/* Page Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 pb-4 border-b border-slate-200">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-sky-50 text-[#0284C7] border border-sky-200">
              <Handshake className="w-3.5 h-3.5" />
              <span>Broker Mediated</span>
            </span>
          </div>
          <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">
            Broker Proposals
          </h1>
          <p className="text-xs sm:text-sm text-slate-500 mt-0.5">
            Receive and respond to commercial offers mediated by your assigned brokers.
          </p>
        </div>
      </div>

      {/* Main Proposals View (Grid + Mobile-first cards + Empty state) */}
      <ProposalsInboxView proposals={proposals} />
    </div>
  );
}
