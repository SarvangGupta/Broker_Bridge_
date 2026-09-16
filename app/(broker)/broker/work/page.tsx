import React from 'react';
import { Layers } from 'lucide-react';
import { getBrokerAssignedRequirementsAction } from '@/src/server/actions/broker-work-actions';
import { BrokerWorkWorkspace } from '@/src/components/broker/work/broker-work-workspace';

export const dynamic = 'force-dynamic';

export default async function BrokerWorkPage() {
  // Pre-fetch assigned requirements on the server with strict broker assignment filter
  const res = await getBrokerAssignedRequirementsAction();
  const requirements = res.data || [];
  const error = res.error;

  return (
    <div className="p-4 sm:p-6 lg:p-8 space-y-6 w-full max-w-7xl mx-auto overflow-x-hidden">
      {/* Page Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <div>
          <div className="flex items-center gap-2.5">
            <h1 className="text-2xl sm:text-3xl font-bold text-slate-900 tracking-tight">
              Active Work
            </h1>
            <span className="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold uppercase tracking-wider bg-[#CCFBF1] text-[#0D9488] border border-teal-200/70 shrink-0">
              DESK
            </span>
          </div>
          <p className="text-xs sm:text-sm text-slate-500 mt-1">
            Assigned buyer mandates, matching engine, quality parameters, and active negotiations.
          </p>
        </div>

        <div className="flex items-center gap-2 text-xs font-medium text-slate-600 bg-white px-3 py-1.5 rounded-lg border border-slate-200/80 shadow-2xs w-fit">
          <Layers className="w-3.5 h-3.5 text-[#0D9488]" />
          <span>
            {requirements.length} {requirements.length === 1 ? 'Requirement' : 'Requirements'} Assigned
          </span>
        </div>
      </div>

      {/* Tabs Sub-Routing Workspace with Live Requirements Inbox */}
      <BrokerWorkWorkspace initialRequirements={requirements} error={error} />
    </div>
  );
}
