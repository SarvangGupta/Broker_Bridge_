'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import {
  Handshake,
  Search,
  Filter,
  ArrowRight,
  ShieldCheck,
  Building2,
  Calendar,
  MapPin,
  Clock,
  CheckCircle2,
  AlertCircle,
  FileCheck2,
  Scale,
  Sparkles,
  Lock,
} from 'lucide-react';
import { useLanguage } from '@/src/lib/i18n/language-context';
import type { BrokerDealSummary } from '@/src/server/actions/broker-deal-actions';

interface BrokerDealsClientProps {
  initialDeals: BrokerDealSummary[];
}

export function BrokerDealsClient({ initialDeals }: BrokerDealsClientProps) {
  const { t, language, formatNumber, formatCurrency } = useLanguage();
  const [deals, setDeals] = useState<BrokerDealSummary[]>(initialDeals);
  const [activeTab, setActiveTab] = useState<string>('All');
  const [searchQuery, setSearchQuery] = useState<string>('');

  // Status Filter Tabs
  const statusTabs = [
    { id: 'All', label: 'All Deals', count: deals.length },
    {
      id: 'Draft',
      label: 'Drafts',
      count: deals.filter((d) => d.status === 'Draft').length,
    },
    {
      id: 'Negotiation',
      label: 'In Negotiation',
      count: deals.filter((d) => d.status === 'Negotiation').length,
    },
    {
      id: 'Awaiting',
      label: 'Awaiting Confirmation',
      count: deals.filter((d) =>
        ['Awaiting Buyer Confirmation', 'Awaiting Seller Confirmation'].includes(d.status)
      ).length,
    },
    {
      id: 'Ready to Finalize',
      label: 'Ready to Finalize',
      count: deals.filter((d) => d.status === 'Ready to Finalize').length,
    },
    {
      id: 'Finalized',
      label: 'Finalized Contracts',
      count: deals.filter((d) => d.status === 'Finalized').length,
    },
    {
      id: 'Cancelled',
      label: 'Cancelled',
      count: deals.filter((d) => d.status === 'Cancelled').length,
    },
  ];

  // Filtered Deals
  const filteredDeals = deals.filter((deal) => {
    // Status tab filter
    if (activeTab === 'Draft' && deal.status !== 'Draft') return false;
    if (activeTab === 'Negotiation' && deal.status !== 'Negotiation') return false;
    if (
      activeTab === 'Awaiting' &&
      !['Awaiting Buyer Confirmation', 'Awaiting Seller Confirmation'].includes(deal.status)
    )
      return false;
    if (activeTab === 'Ready to Finalize' && deal.status !== 'Ready to Finalize') return false;
    if (activeTab === 'Finalized' && deal.status !== 'Finalized') return false;
    if (activeTab === 'Cancelled' && deal.status !== 'Cancelled') return false;

    // Search query filter
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      const matchCommodity = deal.commodityName.toLowerCase().includes(q);
      const matchBuyer = deal.buyerCompanyName.toLowerCase().includes(q);
      const matchSeller = deal.sellerCompanyName.toLowerCase().includes(q);
      const matchBooking = deal.bookingReference?.toLowerCase().includes(q);
      const matchAlloc = deal.allocationReference?.toLowerCase().includes(q);
      if (!matchCommodity && !matchBuyer && !matchSeller && !matchBooking && !matchAlloc) {
        return false;
      }
    }

    return true;
  });

  // KPI calculations
  const totalValuation = deals
    .filter((d) => d.status === 'Finalized')
    .reduce((acc, d) => acc + d.totalValuation, 0);

  const readyToFinalizeCount = deals.filter((d) => d.status === 'Ready to Finalize').length;
  const inNegotiationCount = deals.filter((d) =>
    ['Draft', 'Negotiation', 'Awaiting Buyer Confirmation', 'Awaiting Seller Confirmation'].includes(
      d.status
    )
  ).length;

  const getStatusBadgeVariant = (status: string) => {
    switch (status) {
      case 'Draft':
        return 'bg-slate-100 text-slate-800 border-slate-300 dark:bg-slate-800 dark:text-slate-300';
      case 'Negotiation':
        return 'bg-amber-50 text-amber-800 border-amber-300 dark:bg-amber-950/40 dark:text-amber-300';
      case 'Awaiting Buyer Confirmation':
      case 'Awaiting Seller Confirmation':
        return 'bg-blue-50 text-blue-800 border-blue-300 dark:bg-blue-950/40 dark:text-blue-300';
      case 'Ready to Finalize':
        return 'bg-emerald-50 text-emerald-800 border-emerald-400 dark:bg-emerald-950/40 dark:text-emerald-300 shadow-xs ring-1 ring-emerald-400 font-bold';
      case 'Finalized':
        return 'bg-teal-50 text-teal-800 border-teal-300 dark:bg-teal-950/40 dark:text-teal-300 font-bold';
      case 'Cancelled':
        return 'bg-red-50 text-red-800 border-red-300 dark:bg-red-950/40 dark:text-red-300';
      default:
        return 'bg-slate-100 text-slate-700';
    }
  };

  return (
    <div className="space-y-6">
      {/* Top Metrics Summary Cards */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 sm:gap-4">
        <Card className="border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 shadow-xs">
          <CardContent className="p-4 space-y-1">
            <span className="text-slate-500 text-xs font-medium block">Total Deals</span>
            <span className="text-xl sm:text-2xl font-bold font-mono text-slate-900 dark:text-white">
              {deals.length}
            </span>
          </CardContent>
        </Card>

        <Card className="border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 shadow-xs">
          <CardContent className="p-4 space-y-1">
            <span className="text-slate-500 text-xs font-medium block">In Negotiation</span>
            <span className="text-xl sm:text-2xl font-bold font-mono text-amber-600">
              {inNegotiationCount}
            </span>
          </CardContent>
        </Card>

        <Card className="border-emerald-200 dark:border-emerald-800 bg-emerald-50/50 dark:bg-emerald-950/20 shadow-xs">
          <CardContent className="p-4 space-y-1">
            <span className="text-emerald-700 dark:text-emerald-400 text-xs font-semibold block flex items-center gap-1">
              <ShieldCheck className="w-3.5 h-3.5" />
              Ready to Finalize
            </span>
            <span className="text-xl sm:text-2xl font-bold font-mono text-emerald-700 dark:text-emerald-300">
              {readyToFinalizeCount}
            </span>
          </CardContent>
        </Card>

        <Card className="border-teal-200 dark:border-teal-800 bg-teal-50/50 dark:bg-teal-950/20 shadow-xs">
          <CardContent className="p-4 space-y-1">
            <span className="text-teal-700 dark:text-teal-400 text-xs font-semibold block flex items-center gap-1">
              <CheckCircle2 className="w-3.5 h-3.5" />
              Finalized Contract Value
            </span>
            <span className="text-base sm:text-lg font-bold font-mono text-teal-800 dark:text-teal-300">
              {formatCurrency(totalValuation)}
            </span>
          </CardContent>
        </Card>
      </div>

      {/* Search and Tabs Toolbar */}
      <div className="space-y-3">
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3">
          {/* Search Box */}
          <div className="relative flex-1 max-w-md">
            <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <Input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search by commodity, buyer, seller, booking ref..."
              className="pl-9 text-xs h-9 bg-white dark:bg-slate-900 border-slate-200 dark:border-slate-800"
            />
          </div>

          <Link href="/broker/work" className="self-end sm:self-auto">
            <Button
              size="sm"
              variant="outline"
              className="h-9 text-xs font-semibold border-teal-300 text-teal-800 hover:bg-teal-50"
            >
              <Scale className="w-3.5 h-3.5 mr-1.5 text-[#0D9488]" />
              Match Center & Allocations
              <ArrowRight className="w-3 h-3 ml-1" />
            </Button>
          </Link>
        </div>

        {/* Tab Badges */}
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 text-xs">
          {statusTabs.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`px-3 py-1.5 rounded-xl font-medium whitespace-nowrap transition-colors flex items-center gap-1.5 ${
                activeTab === tab.id
                  ? 'bg-slate-900 text-white dark:bg-teal-600 dark:text-white shadow-xs'
                  : 'bg-slate-100 text-slate-600 hover:bg-slate-200/70 dark:bg-slate-800 dark:text-slate-300'
              }`}
            >
              <span>{tab.label}</span>
              <span
                className={`px-1.5 py-0.2 rounded-full text-[10px] font-mono ${
                  activeTab === tab.id
                    ? 'bg-white/20 text-white'
                    : 'bg-slate-200 text-slate-700 dark:bg-slate-700 dark:text-slate-200'
                }`}
              >
                {tab.count}
              </span>
            </button>
          ))}
        </div>
      </div>

      {/* Deals Cards Grid */}
      {filteredDeals.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-5">
          {filteredDeals.map((deal) => (
            <Card
              key={deal.id}
              className="border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 shadow-xs hover:shadow-md transition-shadow flex flex-col justify-between"
            >
              <CardContent className="p-4 sm:p-5 space-y-3.5">
                {/* Header: Status & Version */}
                <div className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-1.5 flex-wrap">
                    <Badge
                      variant="outline"
                      className={`text-[10px] uppercase font-bold px-2 py-0.5 ${getStatusBadgeVariant(
                        deal.status
                      )}`}
                    >
                      {deal.status}
                    </Badge>
                    <Badge variant="secondary" className="text-[10px] font-mono">
                      v{deal.latestVersionNumber}
                    </Badge>
                  </div>
                  {deal.bookingReference ? (
                    <span className="font-mono text-xs font-bold text-teal-700 dark:text-teal-400">
                      {deal.bookingReference}
                    </span>
                  ) : deal.allocationReference ? (
                    <span className="font-mono text-[11px] text-slate-400">
                      {deal.allocationReference}
                    </span>
                  ) : null}
                </div>

                {/* Commodity Title */}
                <div>
                  <h3 className="font-bold text-slate-900 dark:text-white text-base">
                    {deal.commodityName}
                  </h3>
                  {deal.gradeName && (
                    <p className="text-xs text-slate-500 font-medium">
                      Grade: {deal.gradeName}
                    </p>
                  )}
                </div>

                {/* Counterparties */}
                <div className="space-y-1 text-xs border-y border-slate-100 dark:border-slate-800/80 py-2">
                  <div className="flex items-center justify-between">
                    <span className="text-slate-400">Buyer:</span>
                    <span className="font-semibold text-slate-800 dark:text-slate-200 truncate max-w-[180px]">
                      {deal.buyerCompanyName}
                    </span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-slate-400">Seller:</span>
                    <span className="font-semibold text-slate-800 dark:text-slate-200 truncate max-w-[180px]">
                      {deal.sellerCompanyName}
                    </span>
                  </div>
                </div>

                {/* Key Numbers Grid */}
                <div className="grid grid-cols-2 gap-2 text-xs">
                  <div>
                    <span className="text-slate-400 block text-[11px]">{t('contractQuantity')}:</span>
                    <span className="font-mono font-bold text-slate-900 dark:text-white">
                      {formatNumber(deal.agreedQuantity)} {deal.unitSymbol}
                    </span>
                  </div>
                  <div>
                    <span className="text-slate-400 block text-[11px]">{t('agreedPrice')}:</span>
                    <span className="font-mono font-bold text-teal-700 dark:text-teal-400">
                      {formatCurrency(deal.agreedPrice)}/{deal.unitSymbol}
                    </span>
                  </div>
                </div>

                {/* Confirmation Status Bar */}
                <div className="flex items-center justify-between text-[11px] px-2.5 py-1.5 bg-slate-50 dark:bg-slate-950/40 rounded-lg border border-slate-100 dark:border-slate-800">
                  <div className="flex items-center gap-1">
                    <span className="text-slate-400">Buyer:</span>
                    {deal.buyerConfirmed ? (
                      <span className="text-emerald-700 dark:text-emerald-400 font-semibold flex items-center gap-0.5">
                        <CheckCircle2 className="w-3 h-3" /> Confirmed
                      </span>
                    ) : (
                      <span className="text-amber-600 font-medium flex items-center gap-0.5">
                        <Clock className="w-3 h-3" /> Pending
                      </span>
                    )}
                  </div>

                  <div className="flex items-center gap-1">
                    <span className="text-slate-400">Seller:</span>
                    {deal.sellerConfirmed ? (
                      <span className="text-emerald-700 dark:text-emerald-400 font-semibold flex items-center gap-0.5">
                        <CheckCircle2 className="w-3 h-3" /> Confirmed
                      </span>
                    ) : (
                      <span className="text-amber-600 font-medium flex items-center gap-0.5">
                        <Clock className="w-3 h-3" /> Pending
                      </span>
                    )}
                  </div>
                </div>
              </CardContent>

              {/* Bottom Action Footer */}
              <div className="p-3 bg-slate-50/50 dark:bg-slate-900/50 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between">
                <span className="font-mono text-xs font-semibold text-slate-700 dark:text-slate-300">
                  {formatCurrency(deal.totalValuation)}
                </span>

                <Link href={`/broker/deals/${deal.id}`}>
                  <Button
                    size="sm"
                    className="h-7 text-xs font-semibold bg-[#0D9488] hover:bg-[#0D9488]/90 text-white"
                  >
                    <span>Open Deal</span>
                    <ArrowRight className="w-3 h-3 ml-1" />
                  </Button>
                </Link>
              </div>
            </Card>
          ))}
        </div>
      ) : (
        /* Empty State */
        <Card className="border-dashed border-2 border-slate-200 dark:border-slate-800 bg-white/60 dark:bg-slate-900/40">
          <CardContent className="p-8 sm:p-12 text-center space-y-4">
            <div className="mx-auto w-12 h-12 rounded-full bg-teal-50 dark:bg-teal-950/40 border border-teal-200/80 flex items-center justify-center text-[#0D9488]">
              <Handshake className="w-6 h-6" />
            </div>
            <div className="space-y-1 max-w-sm mx-auto">
              <h3 className="font-bold text-slate-800 dark:text-slate-200 text-base">
                {t('emptyDealsTitle')}
              </h3>
              <p className="text-xs sm:text-sm text-slate-500">
                {t('emptyDealsDesc')}
              </p>
            </div>
            <Link href="/broker/work" className="inline-block">
              <Button size="sm" className="bg-[#0D9488] hover:bg-[#0D9488]/90 text-white text-xs font-semibold">
                Go to Match Center & Allocations
                <ArrowRight className="w-3.5 h-3.5 ml-1.5" />
              </Button>
            </Link>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
