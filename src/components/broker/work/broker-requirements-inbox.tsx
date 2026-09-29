'use client';

import React, { useState, useMemo } from 'react';
import {
  FileText,
  Search,
  SlidersHorizontal,
  Sparkles,
  Inbox,
  AlertCircle,
  CheckCircle2,
  Layers,
  ArrowUpDown,
  RefreshCw,
} from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { RequirementCard } from './requirement-card';
import type {
  BrokerAssignedRequirement,
  BrokerOperationalStatus,
} from '@/src/server/actions/broker-work-actions';

interface BrokerRequirementsInboxProps {
  initialRequirements: BrokerAssignedRequirement[];
  error?: string;
}

type FilterTab = 'ALL' | 'ACTION_REQUIRED' | 'NEW_DEMAND' | 'SOURCING' | 'PARTIAL';

export function BrokerRequirementsInbox({
  initialRequirements = [],
  error,
}: BrokerRequirementsInboxProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [activeFilter, setActiveFilter] = useState<FilterTab>('ALL');
  const [sortBy, setSortBy] = useState<'NEWEST' | 'URGENT' | 'VOLUME'>('URGENT');

  // Compute status counts for filter badges
  const counts = useMemo(() => {
    return {
      all: initialRequirements.length,
      actionRequired: initialRequirements.filter((r) => r.operationalStatus === 'Action Required').length,
      newDemand: initialRequirements.filter((r) => r.operationalStatus === 'New Demand').length,
      sourcing: initialRequirements.filter((r) => r.operationalStatus === 'Sourcing').length,
      partial: initialRequirements.filter((r) => r.operationalStatus === 'Partially Fulfilled').length,
    };
  }, [initialRequirements]);

  // Filter & Sort requirements
  const filteredRequirements = useMemo(() => {
    let list = [...initialRequirements];

    // Filter by Tab
    if (activeFilter === 'ACTION_REQUIRED') {
      list = list.filter((r) => r.operationalStatus === 'Action Required');
    } else if (activeFilter === 'NEW_DEMAND') {
      list = list.filter((r) => r.operationalStatus === 'New Demand');
    } else if (activeFilter === 'SOURCING') {
      list = list.filter((r) => r.operationalStatus === 'Sourcing');
    } else if (activeFilter === 'PARTIAL') {
      list = list.filter((r) => r.operationalStatus === 'Partially Fulfilled');
    }

    // Filter by Search Query
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      list = list.filter((r) => {
        return (
          r.commodityName.toLowerCase().includes(q) ||
          r.gradeName.toLowerCase().includes(q) ||
          r.buyerCompanyName.toLowerCase().includes(q) ||
          r.requirementRef.toLowerCase().includes(q) ||
          (r.categoryName && r.categoryName.toLowerCase().includes(q)) ||
          (r.industryName && r.industryName.toLowerCase().includes(q))
        );
      });
    }

    // Sort
    list.sort((a, b) => {
      if (sortBy === 'URGENT') {
        // Urgent first, then by earliest target date
        if (a.isUrgent && !b.isUrgent) return -1;
        if (!a.isUrgent && b.isUrgent) return 1;
        return new Date(a.targetDateRaw).getTime() - new Date(b.targetDateRaw).getTime();
      }
      if (sortBy === 'VOLUME') {
        return b.quantity - a.quantity;
      }
      // NEWEST
      return new Date(b.targetDateRaw).getTime() - new Date(a.targetDateRaw).getTime();
    });

    return list;
  }, [initialRequirements, activeFilter, searchQuery, sortBy]);

  if (error) {
    return (
      <Card className="border-rose-200 bg-rose-50/50">
        <CardContent className="p-6 text-center space-y-3">
          <AlertCircle className="w-8 h-8 text-rose-600 mx-auto" />
          <div className="space-y-1">
            <h3 className="font-bold text-slate-800 text-base">Unable to Load Requirements</h3>
            <p className="text-xs text-slate-600">{error}</p>
          </div>
          <Button
            variant="outline"
            onClick={() => window.location.reload()}
            className="min-h-[48px] h-12 border-rose-200 text-rose-700 hover:bg-rose-100"
          >
            <RefreshCw className="w-4 h-4 mr-2" />
            <span>Retry Connection</span>
          </Button>
        </CardContent>
      </Card>
    );
  }

  return (
    <div className="space-y-4 sm:space-y-5">
      {/* Search & Operational Filter Bar */}
      <div className="flex flex-col gap-3">
        {/* Search Input Box */}
        <div className="relative w-full">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
          <Input
            type="text"
            placeholder="Search by commodity, grade, buyer, or REQ ID..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-10 min-h-[48px] h-12 bg-white border-slate-200/90 rounded-xl text-xs sm:text-sm focus-visible:ring-[#0D9488]"
          />
          {searchQuery && (
            <button
              type="button"
              onClick={() => setSearchQuery('')}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-slate-400 hover:text-slate-600 px-1.5 py-0.5"
            >
              Clear
            </button>
          )}
        </div>

        {/* Operational Filter Chips - Scrollable on mobile without page overflow */}
        <div className="w-full overflow-x-auto touch-pan-x pb-1 scrollbar-none">
          <div className="flex items-center gap-1.5 min-w-max">
            {/* All */}
            <button
              type="button"
              onClick={() => setActiveFilter('ALL')}
              className={`min-h-[38px] px-3.5 py-1.5 rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5 ${
                activeFilter === 'ALL'
                  ? 'bg-slate-900 text-white shadow-2xs'
                  : 'bg-white text-slate-600 hover:bg-slate-100 border border-slate-200/80'
              }`}
            >
              <span>All Assigned</span>
              <span
                className={`text-[10px] px-1.5 py-0.2 rounded-full font-mono ${
                  activeFilter === 'ALL'
                    ? 'bg-slate-800 text-slate-200'
                    : 'bg-slate-100 text-slate-500'
                }`}
              >
                {counts.all}
              </span>
            </button>

            {/* Action Required */}
            {counts.actionRequired > 0 && (
              <button
                type="button"
                onClick={() => setActiveFilter('ACTION_REQUIRED')}
                className={`min-h-[38px] px-3.5 py-1.5 rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5 ${
                  activeFilter === 'ACTION_REQUIRED'
                    ? 'bg-amber-600 text-white shadow-2xs'
                    : 'bg-amber-50 text-amber-800 hover:bg-amber-100 border border-amber-200/80'
                }`}
              >
                <span className="w-1.5 h-1.5 rounded-full bg-amber-400 animate-pulse" />
                <span>Action Required</span>
                <span
                  className={`text-[10px] px-1.5 py-0.2 rounded-full font-mono ${
                    activeFilter === 'ACTION_REQUIRED'
                      ? 'bg-amber-700 text-white'
                      : 'bg-amber-200/70 text-amber-900'
                  }`}
                >
                  {counts.actionRequired}
                </span>
              </button>
            )}

            {/* New Demand */}
            <button
              type="button"
              onClick={() => setActiveFilter('NEW_DEMAND')}
              className={`min-h-[38px] px-3.5 py-1.5 rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5 ${
                activeFilter === 'NEW_DEMAND'
                  ? 'bg-[#0D9488] text-white shadow-2xs'
                  : 'bg-white text-slate-600 hover:bg-slate-100 border border-slate-200/80'
              }`}
            >
              <Sparkles className="w-3.5 h-3.5 text-[#0D9488]" />
              <span>New Demand</span>
              <span
                className={`text-[10px] px-1.5 py-0.2 rounded-full font-mono ${
                  activeFilter === 'NEW_DEMAND'
                    ? 'bg-teal-800 text-teal-100'
                    : 'bg-slate-100 text-slate-500'
                }`}
              >
                {counts.newDemand}
              </span>
            </button>

            {/* Sourcing */}
            <button
              type="button"
              onClick={() => setActiveFilter('SOURCING')}
              className={`min-h-[38px] px-3.5 py-1.5 rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5 ${
                activeFilter === 'SOURCING'
                  ? 'bg-blue-600 text-white shadow-2xs'
                  : 'bg-white text-slate-600 hover:bg-slate-100 border border-slate-200/80'
              }`}
            >
              <Search className="w-3.5 h-3.5 text-blue-500" />
              <span>Sourcing</span>
              <span
                className={`text-[10px] px-1.5 py-0.2 rounded-full font-mono ${
                  activeFilter === 'SOURCING'
                    ? 'bg-blue-700 text-blue-100'
                    : 'bg-slate-100 text-slate-500'
                }`}
              >
                {counts.sourcing}
              </span>
            </button>

            {/* Partially Fulfilled */}
            {counts.partial > 0 && (
              <button
                type="button"
                onClick={() => setActiveFilter('PARTIAL')}
                className={`min-h-[38px] px-3.5 py-1.5 rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5 ${
                  activeFilter === 'PARTIAL'
                    ? 'bg-indigo-600 text-white shadow-2xs'
                    : 'bg-white text-slate-600 hover:bg-slate-100 border border-slate-200/80'
                }`}
              >
                <Layers className="w-3.5 h-3.5 text-indigo-500" />
                <span>Partial Supply</span>
                <span
                  className={`text-[10px] px-1.5 py-0.2 rounded-full font-mono ${
                    activeFilter === 'PARTIAL'
                      ? 'bg-indigo-700 text-indigo-100'
                      : 'bg-slate-100 text-slate-500'
                  }`}
                >
                  {counts.partial}
                </span>
              </button>
            )}
          </div>
        </div>
      </div>

      {/* Grid of Cards or Empty State */}
      {filteredRequirements.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 sm:gap-5">
          {filteredRequirements.map((req) => (
            <RequirementCard key={req.id} requirement={req} />
          ))}
        </div>
      ) : (
        /* Empty State */
        <Card className="border-dashed border-2 border-slate-200 bg-white/70">
          <CardContent className="p-8 sm:p-12 text-center space-y-4">
            <div className="mx-auto w-14 h-14 rounded-2xl bg-teal-50 border border-teal-200/80 flex items-center justify-center text-[#0D9488]">
              <Inbox className="w-7 h-7" />
            </div>
            <div className="space-y-1.5 max-w-sm mx-auto">
              <h3 className="font-bold text-slate-900 text-base sm:text-lg">
                No Active Requirements
              </h3>
              <p className="text-xs sm:text-sm text-slate-500 leading-relaxed">
                {searchQuery || activeFilter !== 'ALL'
                  ? 'No buyer requirements matched your filter or search criteria. Try resetting filters.'
                  : 'You currently have no requirements assigned to you from the Deal Desk.'}
              </p>
            </div>
            {(searchQuery || activeFilter !== 'ALL') && (
              <Button
                variant="outline"
                onClick={() => {
                  setSearchQuery('');
                  setActiveFilter('ALL');
                }}
                className="min-h-[48px] h-12 text-xs font-semibold"
              >
                Reset All Filters
              </Button>
            )}
          </CardContent>
        </Card>
      )}
    </div>
  );
}
