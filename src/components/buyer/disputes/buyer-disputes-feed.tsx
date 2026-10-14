'use client';

import React, { useState, useMemo } from 'react';
import Link from 'next/link';
import {
  ShieldAlert,
  Search,
  Filter,
  CheckCircle2,
  Clock,
  AlertTriangle,
  ArrowRight,
  ShieldCheck,
  Building2,
  HelpCircle,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card } from '@/components/ui/card';
import { cn } from '@/lib/utils';
import {
  BUYER_DISPUTE_CATEGORIES,
  BuyerDisputeCategory,
  BuyerDisputeItem,
  BuyerDisputeStatus,
  BuyerDisputeSummary,
} from '@/src/types/buyer-dispute-types';
import { BuyerDisputeCard } from './buyer-dispute-card';

export interface BuyerDisputesFeedProps {
  initialDisputes: BuyerDisputeItem[];
  initialSummary: BuyerDisputeSummary;
  className?: string;
}

/**
 * Task 3 (Micro-Sprint 39.4): Buyer Dispute Tracker Feed Component.
 * 
 * Provides an interactive filterable view of all active and resolved disputes
 * submitted by the Buyer organization.
 * 
 * STRICT UX RULE:
 * This is a strictly read-only tracker. There is NO chat box or messaging channel.
 * Disputes are mediated exclusively through the neutral Broker desk.
 */
export function BuyerDisputesFeed({
  initialDisputes,
  initialSummary,
  className,
}: BuyerDisputesFeedProps) {
  const [activeTab, setActiveTab] = useState<'all' | 'open' | 'under_review' | 'resolved'>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string>('all');

  // Filtered disputes
  const filteredDisputes = useMemo(() => {
    return initialDisputes.filter((d) => {
      // Tab filter
      if (activeTab === 'open' && d.status !== 'Open') return false;
      if (activeTab === 'under_review' && d.status !== 'Under Broker Review') return false;
      if (activeTab === 'resolved' && d.status !== 'Resolved') return false;

      // Category filter
      if (selectedCategory !== 'all' && d.category !== selectedCategory) return false;

      // Search query filter
      if (!searchQuery.trim()) return true;
      const q = searchQuery.toLowerCase().trim();
      return (
        d.bookingId.toLowerCase().includes(q) ||
        d.commodityName.toLowerCase().includes(q) ||
        d.description.toLowerCase().includes(q) ||
        d.category.toLowerCase().includes(q)
      );
    });
  }, [initialDisputes, activeTab, selectedCategory, searchQuery]);

  return (
    <div className={cn('w-full max-w-full space-y-5', className)}>
      {/* 1. Header Banner */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 bg-white p-4 sm:p-5 rounded-2xl border border-slate-200 shadow-xs">
        <div className="space-y-1">
          <div className="flex items-center gap-2">
            <span className="px-2 py-0.5 rounded-md bg-rose-100 text-rose-800 text-[10px] font-bold uppercase tracking-wider">
              Broker Mediation Desk
            </span>
          </div>
          <h1 className="text-lg sm:text-xl font-bold text-slate-900 tracking-tight">
            Dispute Ledger & Order Exceptions
          </h1>
          <p className="text-xs text-slate-500 max-w-2xl leading-relaxed">
            Track quality deviations, weight shortages, and delivery delays filed against your confirmed contracts. All disputes are mediated strictly through the neutral Broker Desk.
          </p>
        </div>

        <div className="flex items-center gap-2 text-xs font-semibold text-slate-600 bg-slate-50 px-3 py-2 rounded-xl border border-slate-200 self-start sm:self-auto shrink-0">
          <ShieldCheck className="w-4 h-4 text-[#0284C7]" />
          <span>Fiduciary Escrow Mediation</span>
        </div>
      </div>

      {/* 2. Top Summary KPI Ribbon */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        {/* Metric 1: Total Logged */}
        <div className="rounded-xl border border-slate-200 bg-white p-3.5 space-y-1 shadow-2xs">
          <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
            Total Exceptions
          </span>
          <div className="text-lg sm:text-xl font-black text-slate-900 font-mono">
            {initialSummary.totalDisputes}
          </div>
          <span className="text-[10px] text-slate-500 block">All-time order filings</span>
        </div>

        {/* Metric 2: Open Status */}
        <div className="rounded-xl border border-sky-200 bg-sky-50/60 p-3.5 space-y-1 shadow-2xs">
          <div className="flex items-center justify-between">
            <span className="text-[10px] font-bold text-sky-800 uppercase tracking-wider block">
              Pending Assessment
            </span>
            <Clock className="w-3.5 h-3.5 text-sky-600" />
          </div>
          <div className="text-lg sm:text-xl font-black text-sky-900 font-mono">
            {initialSummary.openCount}
          </div>
          <span className="text-[10px] text-sky-700 block">Awaiting broker review</span>
        </div>

        {/* Metric 3: Under Broker Review */}
        <div className="rounded-xl border border-amber-200 bg-amber-50/60 p-3.5 space-y-1 shadow-2xs">
          <div className="flex items-center justify-between">
            <span className="text-[10px] font-bold text-amber-800 uppercase tracking-wider block">
              Active Mediation
            </span>
            <AlertTriangle className="w-3.5 h-3.5 text-amber-600" />
          </div>
          <div className="text-lg sm:text-xl font-black text-amber-900 font-mono">
            {initialSummary.underReviewCount}
          </div>
          <span className="text-[10px] text-amber-700 block">Broker investigating terms</span>
        </div>

        {/* Metric 4: Resolved */}
        <div className="rounded-xl border border-emerald-200 bg-emerald-50/60 p-3.5 space-y-1 shadow-2xs">
          <div className="flex items-center justify-between">
            <span className="text-[10px] font-bold text-emerald-800 uppercase tracking-wider block">
              Resolved & Reconciled
            </span>
            <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" />
          </div>
          <div className="text-lg sm:text-xl font-black text-emerald-900 font-mono">
            {initialSummary.resolvedCount}
          </div>
          <span className="text-[10px] text-emerald-700 block">Settlement adjustments finalized</span>
        </div>
      </div>

      {/* 3. Filter Bar & Search */}
      <div className="flex flex-col md:flex-row items-stretch md:items-center justify-between gap-3 bg-white p-3 rounded-2xl border border-slate-200 shadow-2xs">
        {/* Status Tabs */}
        <div className="flex items-center gap-1.5 p-1 bg-slate-100 rounded-xl overflow-x-auto shrink-0">
          <button
            onClick={() => setActiveTab('all')}
            className={cn(
              'min-h-[40px] px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all whitespace-nowrap',
              activeTab === 'all'
                ? 'bg-white text-slate-900 shadow-2xs'
                : 'text-slate-600 hover:text-slate-900'
            )}
          >
            All ({initialDisputes.length})
          </button>
          <button
            onClick={() => setActiveTab('open')}
            className={cn(
              'min-h-[40px] px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all whitespace-nowrap',
              activeTab === 'open'
                ? 'bg-white text-sky-700 shadow-2xs'
                : 'text-slate-600 hover:text-slate-900'
            )}
          >
            Open ({initialSummary.openCount})
          </button>
          <button
            onClick={() => setActiveTab('under_review')}
            className={cn(
              'min-h-[40px] px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all whitespace-nowrap',
              activeTab === 'under_review'
                ? 'bg-white text-amber-700 shadow-2xs'
                : 'text-slate-600 hover:text-slate-900'
            )}
          >
            Under Review ({initialSummary.underReviewCount})
          </button>
          <button
            onClick={() => setActiveTab('resolved')}
            className={cn(
              'min-h-[40px] px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all whitespace-nowrap',
              activeTab === 'resolved'
                ? 'bg-white text-emerald-700 shadow-2xs'
                : 'text-slate-600 hover:text-slate-900'
            )}
          >
            Resolved ({initialSummary.resolvedCount})
          </button>
        </div>

        {/* Search & Category Filter */}
        <div className="flex items-center gap-2 flex-1 md:justify-end">
          {/* Category Dropdown */}
          <select
            value={selectedCategory}
            onChange={(e) => setSelectedCategory(e.target.value)}
            className="min-h-[48px] h-12 px-3 rounded-xl border border-slate-200 bg-slate-50/50 text-xs font-semibold text-slate-700 focus:bg-white focus:outline-none"
          >
            <option value="all">All Categories</option>
            {BUYER_DISPUTE_CATEGORIES.map((cat) => (
              <option key={cat} value={cat}>
                {cat}
              </option>
            ))}
          </select>

          {/* Search Input */}
          <div className="relative flex-1 max-w-xs">
            <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
            <Input
              type="text"
              placeholder="Search booking or description..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-9 min-h-[48px] h-12 rounded-xl text-xs border-slate-200 bg-slate-50/50 focus:bg-white"
            />
          </div>
        </div>
      </div>

      {/* 4. Disputes List */}
      {filteredDisputes.length === 0 ? (
        <Card className="border border-slate-200 bg-white p-8 text-center space-y-3 rounded-2xl">
          <div className="w-12 h-12 rounded-2xl bg-slate-100 text-slate-400 mx-auto flex items-center justify-center">
            <ShieldAlert className="w-6 h-6" />
          </div>
          <div className="space-y-1 max-w-sm mx-auto">
            <h3 className="text-sm font-bold text-slate-800">No Disputes Found</h3>
            <p className="text-xs text-slate-500">
              There are no dispute filings matching your selected filter or search term.
            </p>
          </div>
          <Button
            variant="outline"
            onClick={() => {
              setActiveTab('all');
              setSelectedCategory('all');
              setSearchQuery('');
            }}
            className="min-h-[48px] px-4 rounded-xl text-xs font-semibold"
          >
            Clear Filters
          </Button>
        </Card>
      ) : (
        <div className="space-y-4">
          {filteredDisputes.map((dispute) => (
            <BuyerDisputeCard key={dispute.id} dispute={dispute} />
          ))}
        </div>
      )}

      {/* 5. Policy Notice Footnote */}
      <div className="p-3.5 rounded-2xl bg-slate-50 border border-slate-200/80 flex items-start gap-3 text-xs text-slate-500">
        <Building2 className="w-4 h-4 text-[#0284C7] shrink-0 mt-0.5" />
        <div className="space-y-0.5 leading-relaxed text-[11px]">
          <span className="font-bold text-slate-800 block">
            BrokerBridge Dispute Mediation Policy
          </span>
          <p>
            Under platform commercial terms, buyers and sellers agree to submit all physical, quality, weighment, and transit claims to the Broker Desk. The Broker inspects evidentiary submissions, compares verified lab results and electronic weighbridge slips, and determines necessary adjustments or statutory rate discounts. Direct communication between counter-parties is strictly prohibited.
          </p>
        </div>
      </div>
    </div>
  );
}
