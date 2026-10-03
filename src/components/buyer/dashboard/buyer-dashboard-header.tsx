'use client';

import React from 'react';
import { Plus, ShieldCheck, Building2 } from 'lucide-react';
import { PostRequirementDialog } from '@/src/components/dialogs/post-requirement-dialog';

interface BuyerDashboardHeaderProps {
  companyName?: string;
  isVerified?: boolean;
}

export function BuyerDashboardHeader({
  companyName = 'Buyer Enterprise',
  isVerified = true,
}: BuyerDashboardHeaderProps) {
  return (
    <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-white border border-slate-200/80 p-4 sm:p-6 rounded-2xl shadow-2xs">
      {/* Title & Subtitle */}
      <div className="space-y-1 min-w-0">
        <div className="flex items-center gap-2 flex-wrap">
          <h1 className="text-xl sm:text-2xl font-bold tracking-tight text-slate-900">
            Procurement Command Center
          </h1>
          {isVerified && (
            <span className="inline-flex items-center gap-1 text-[11px] font-bold text-sky-800 bg-sky-100/80 border border-sky-200 px-2 py-0.5 rounded-full shrink-0">
              <ShieldCheck className="w-3.5 h-3.5 text-[#0284C7]" />
              <span>Verified Buyer</span>
            </span>
          )}
        </div>
        <div className="flex items-center gap-1.5 text-xs sm:text-sm text-slate-500 truncate">
          <Building2 className="w-4 h-4 text-slate-400 shrink-0 inline" />
          <span className="truncate font-medium">{companyName}</span>
          <span className="text-slate-300">•</span>
          <span className="text-slate-500">Active Demand Mandates</span>
        </div>
      </div>

      {/* Primary Action Button */}
      <div className="w-full sm:w-auto shrink-0">
        <PostRequirementDialog />
      </div>
    </div>
  );
}
