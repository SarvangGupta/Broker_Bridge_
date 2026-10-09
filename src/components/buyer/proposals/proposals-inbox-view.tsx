'use client';

import React, { useState, useMemo } from 'react';
import Link from 'next/link';
import { 
  Inbox, 
  Search, 
  Plus, 
  Filter, 
  Handshake, 
  Sparkles,
  ClipboardList
} from 'lucide-react';
import { ProposalCard } from '@/src/components/buyer/proposals/proposal-card';
import { BuyerProposalItem } from '@/src/types/buyer-proposal';
import { ProposalStatus } from '@/src/utils/proposal-mappers';
import { EmptyState } from '@/src/components/ui/empty-state';
import { Input } from '@/components/ui/input';

export interface ProposalsInboxViewProps {
  proposals: BuyerProposalItem[];
}

type FilterTab = 'ALL' | 'NEW' | 'COUNTERED' | 'PENDING' | 'ACCEPTED' | 'ARCHIVED';

export function ProposalsInboxView({ proposals }: ProposalsInboxViewProps) {
  const [selectedTab, setSelectedTab] = useState<FilterTab>('ALL');
  const [searchQuery, setSearchQuery] = useState('');

  // Counts for each filter tab
  const counts = useMemo(() => {
    let newCount = 0;
    let counteredCount = 0;
    let pendingCount = 0;
    let acceptedCount = 0;
    let archivedCount = 0;

    for (const p of proposals) {
      if (p.status === 'New') newCount++;
      else if (p.status === 'Countered') counteredCount++;
      else if (p.status === 'Pending Response') pendingCount++;
      else if (p.status === 'Accepted') acceptedCount++;
      else if (p.status === 'Rejected' || p.status === 'Expired') archivedCount++;
    }

    return {
      all: proposals.length,
      new: newCount,
      countered: counteredCount,
      pending: pendingCount,
      accepted: acceptedCount,
      archived: archivedCount,
    };
  }, [proposals]);

  // Filtered proposals based on active tab and search query
  const filteredProposals = useMemo(() => {
    return proposals.filter((p) => {
      // Tab filter
      let matchesTab = true;
      if (selectedTab === 'NEW') matchesTab = p.status === 'New';
      else if (selectedTab === 'COUNTERED') matchesTab = p.status === 'Countered';
      else if (selectedTab === 'PENDING') matchesTab = p.status === 'Pending Response';
      else if (selectedTab === 'ACCEPTED') matchesTab = p.status === 'Accepted';
      else if (selectedTab === 'ARCHIVED') matchesTab = p.status === 'Rejected' || p.status === 'Expired';

      if (!matchesTab) return false;

      // Search filter
      if (!searchQuery.trim()) return true;
      const q = searchQuery.toLowerCase().trim();
      return (
        p.commodityName.toLowerCase().includes(q) ||
        p.gradeName.toLowerCase().includes(q) ||
        p.requirementDisplayId.toLowerCase().includes(q) ||
        p.requirementId.toLowerCase().includes(q) ||
        p.brokerName.toLowerCase().includes(q)
      );
    });
  }, [proposals, selectedTab, searchQuery]);

  // 1. Initial Zero-State: If no proposals exist at all
  if (proposals.length === 0) {
    return (
      <div className="w-full max-w-full overflow-x-hidden py-4 sm:py-8">
        <EmptyState
          icon={Handshake}
          title="No active proposals from your Broker yet."
          description="Your broker will match qualified suppliers against your procurement requirements and dispatch formal commercial offers directly to this inbox."
          className="border-dashed border-sky-200/90 bg-sky-50/20"
        >
          <div className="flex items-center justify-center mt-2 w-full max-w-md mx-auto">
            <Link
              href="/buyer/requirements/new"
              className="w-full sm:w-auto inline-flex items-center justify-center min-h-[48px] px-6 rounded-xl bg-[#0284C7] hover:bg-[#0369A1] text-white text-xs font-bold shadow-xs transition-all"
            >
              <Plus className="w-4 h-4 mr-2" />
              Post Requirement
            </Link>
          </div>
        </EmptyState>
      </div>
    );
  }

  return (
    <div className="w-full max-w-full overflow-x-hidden space-y-6">
      {/* Search & Quick Filters Bar */}
      <div className="flex flex-col sm:flex-row gap-3 items-stretch sm:items-center justify-between">
        {/* Search Input */}
        <div className="relative flex-1 max-w-md">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
          <Input
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search by commodity, grade, ref ID..."
            className="pl-10 h-11 rounded-xl bg-white border-slate-200 text-sm focus-visible:ring-1 focus-visible:ring-[#0284C7]"
          />
        </div>

        {/* Action Link for Requirements */}
        <div className="flex items-center gap-2 shrink-0">
          <Link
            href="/buyer/requirements/new"
            className="inline-flex items-center justify-center min-h-[48px] h-12 px-4 rounded-xl bg-[#0284C7] hover:bg-[#0369A1] text-white text-xs font-semibold shadow-xs transition-colors shrink-0"
          >
            <Plus className="w-4 h-4 mr-1.5" />
            <span>Post Requirement</span>
          </Link>
        </div>
      </div>

      {/* Responsive Horizontal Filter Tabs */}
      <div className="w-full max-w-full overflow-x-auto pb-1 scrollbar-thin">
        <div className="flex items-center gap-2 min-w-max">
          <button
            type="button"
            onClick={() => setSelectedTab('ALL')}
            className={`inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer ${
              selectedTab === 'ALL'
                ? 'bg-[#0284C7] text-white shadow-xs'
                : 'bg-white text-slate-600 hover:bg-slate-50 border border-slate-200'
            }`}
          >
            <span>All Proposals</span>
            <span
              className={`px-1.5 py-0.5 rounded-full text-[10px] ${
                selectedTab === 'ALL' ? 'bg-white/20 text-white' : 'bg-slate-100 text-slate-600'
              }`}
            >
              {counts.all}
            </span>
          </button>

          <button
            type="button"
            onClick={() => setSelectedTab('NEW')}
            className={`inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer ${
              selectedTab === 'NEW'
                ? 'bg-sky-600 text-white shadow-xs'
                : 'bg-white text-slate-600 hover:bg-slate-50 border border-slate-200'
            }`}
          >
            <span>New Offers</span>
            <span
              className={`px-1.5 py-0.5 rounded-full text-[10px] ${
                selectedTab === 'NEW' ? 'bg-white/20 text-white' : 'bg-sky-50 text-[#0284C7] font-semibold'
              }`}
            >
              {counts.new}
            </span>
          </button>

          <button
            type="button"
            onClick={() => setSelectedTab('COUNTERED')}
            className={`inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer ${
              selectedTab === 'COUNTERED'
                ? 'bg-blue-600 text-white shadow-xs'
                : 'bg-white text-slate-600 hover:bg-slate-50 border border-slate-200'
            }`}
          >
            <span>Countered</span>
            <span
              className={`px-1.5 py-0.5 rounded-full text-[10px] ${
                selectedTab === 'COUNTERED' ? 'bg-white/20 text-white' : 'bg-slate-100 text-slate-600'
              }`}
            >
              {counts.countered}
            </span>
          </button>

          <button
            type="button"
            onClick={() => setSelectedTab('ACCEPTED')}
            className={`inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer ${
              selectedTab === 'ACCEPTED'
                ? 'bg-emerald-600 text-white shadow-xs'
                : 'bg-white text-slate-600 hover:bg-slate-50 border border-slate-200'
            }`}
          >
            <span>Accepted</span>
            <span
              className={`px-1.5 py-0.5 rounded-full text-[10px] ${
                selectedTab === 'ACCEPTED' ? 'bg-white/20 text-white' : 'bg-emerald-50 text-emerald-700 font-semibold'
              }`}
            >
              {counts.accepted}
            </span>
          </button>

          <button
            type="button"
            onClick={() => setSelectedTab('ARCHIVED')}
            className={`inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer ${
              selectedTab === 'ARCHIVED'
                ? 'bg-slate-700 text-white shadow-xs'
                : 'bg-white text-slate-600 hover:bg-slate-50 border border-slate-200'
            }`}
          >
            <span>Expired & Rejected</span>
            <span
              className={`px-1.5 py-0.5 rounded-full text-[10px] ${
                selectedTab === 'ARCHIVED' ? 'bg-white/20 text-white' : 'bg-slate-100 text-slate-600'
              }`}
            >
              {counts.archived}
            </span>
          </button>
        </div>
      </div>

      {/* Grid of Proposal Cards */}
      {filteredProposals.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {filteredProposals.map((proposal) => (
            <ProposalCard key={proposal.id} proposal={proposal} />
          ))}
        </div>
      ) : (
        <div className="p-8 text-center bg-white rounded-2xl border border-dashed border-slate-200">
          <p className="text-sm text-slate-500 mb-2">
            No proposals match the selected filter or search criteria.
          </p>
          <button
            type="button"
            onClick={() => {
              setSelectedTab('ALL');
              setSearchQuery('');
            }}
            className="text-xs font-bold text-[#0284C7] hover:underline"
          >
            Clear filters
          </button>
        </div>
      )}
    </div>
  );
}
