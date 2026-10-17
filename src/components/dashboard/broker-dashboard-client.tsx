'use client';

import React, { useState, useMemo } from 'react';
import Link from 'next/link';
import {
  Handshake,
  Layers,
  Truck,
  IndianRupee,
  Clock,
  ArrowRight,
  CheckCircle2,
  Building2,
  Sparkles,
  ChevronRight,
  Calendar,
  AlertTriangle,
  Package,
  Search,
  X,
  FileCheck2,
  Receipt,
  PieChart,
} from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { RealtimeDealsListener } from '@/src/components/realtime-deals-listener';
import { BrokerFollowUpTasks } from '@/src/components/dashboard/broker-follow-up-tasks';
import { BrokerQuickActions } from '@/src/components/dashboard/broker-quick-actions';
import { BrokerRecentActivity } from '@/src/components/dashboard/broker-recent-activity';
import {
  BrokerDashboardKpis,
  BrokerAlertItem,
  BrokerPendingActionItem,
  BrokerRecentActivityItem,
  BrokerPipelineDeal,
  BrokerFollowUpTask,
  PendingActionCategory,
} from '@/src/server/actions/broker-dashboard-actions';
import { useLanguage } from '@/src/lib/i18n/language-context';
import { LanguageSelector } from '@/src/components/ui/language-selector';

export interface BrokerDashboardClientProps {
  kpis: BrokerDashboardKpis;
  alerts?: BrokerAlertItem[];
  pendingActions?: BrokerPendingActionItem[];
  recentActivity?: BrokerRecentActivityItem[];
  pipeline: BrokerPipelineDeal[];
  tasks: BrokerFollowUpTask[];
}

export function BrokerDashboardClient({
  kpis,
  alerts,
  pendingActions: propPendingActions,
  recentActivity = [],
  pipeline,
  tasks,
}: BrokerDashboardClientProps) {
  const { t, formatNumber } = useLanguage();

  // Search & Filter State
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string>('all');

  const rawActions = propPendingActions ?? alerts ?? [];

  // Filtered Actions
  const filteredActions = useMemo(() => {
    return rawActions.filter((action) => {
      const matchesCategory =
        selectedCategory === 'all' || action.category === selectedCategory;

      const q = searchQuery.toLowerCase().trim();
      const matchesSearch =
        !q ||
        action.dealRef.toLowerCase().includes(q) ||
        action.commodity.toLowerCase().includes(q) ||
        action.title.toLowerCase().includes(q) ||
        action.description.toLowerCase().includes(q);

      return matchesCategory && matchesSearch;
    });
  }, [rawActions, selectedCategory, searchQuery]);

  // Filtered Pipeline Deals
  const filteredPipeline = useMemo(() => {
    if (!searchQuery.trim()) return pipeline;
    const q = searchQuery.toLowerCase().trim();
    return pipeline.filter(
      (deal) =>
        deal.dealRef.toLowerCase().includes(q) ||
        deal.commodity.toLowerCase().includes(q) ||
        deal.buyer.toLowerCase().includes(q) ||
        deal.seller.toLowerCase().includes(q)
    );
  }, [pipeline, searchQuery]);

  // 8 Authoritative Operational KPIs
  const SUMMARY_KPIS = [
    {
      id: 'active_deals',
      label: t('kpiActiveDeals'),
      value: formatNumber(kpis.activeDealsCount),
      subtext: `${kpis.activeDealsCount} ${t('kpiActiveDealsSub')}`,
      icon: Handshake,
      color: 'text-[#0D9488] bg-[#0D9488]/10 border-[#0D9488]/20',
      href: '/broker/deals',
    },
    {
      id: 'open_requirements',
      label: t('kpiOpenRequirements'),
      value: formatNumber(kpis.openRequirementsCount),
      subtext: `${kpis.openRequirementsCount} ${t('kpiOpenRequirementsSub')}`,
      icon: Layers,
      color: 'text-blue-600 bg-blue-50 border-blue-200/80',
      href: '/broker/work',
    },
    {
      id: 'partially_allocated',
      label: t('kpiPartiallyAllocated'),
      value: formatNumber(kpis.partiallyAllocatedCount ?? 0),
      subtext: `${kpis.partiallyAllocatedCount ?? 0} ${t('kpiPartiallyAllocatedSub')}`,
      icon: PieChart,
      color: 'text-sky-600 bg-sky-50 border-sky-200/80',
      href: '/broker/work',
    },
    {
      id: 'available_offers',
      label: t('kpiAvailableOffers'),
      value: formatNumber(kpis.availableOffersCount ?? 0),
      subtext: `${kpis.availableOffersCount ?? 0} ${t('kpiAvailableOffersSub')}`,
      icon: Package,
      color: 'text-indigo-600 bg-indigo-50 border-indigo-200/80',
      href: '/broker/work',
    },
    {
      id: 'awaiting_confirmation',
      label: t('kpiAwaitingConfirmation'),
      value: formatNumber(kpis.awaitingConfirmationCount ?? 0),
      subtext: `${kpis.awaitingConfirmationCount ?? 0} ${t('kpiAwaitingConfirmationSub')}`,
      icon: FileCheck2,
      color: 'text-teal-600 bg-teal-50 border-teal-200/80',
      href: '/broker/deals',
    },
    {
      id: 'dispatch_due',
      label: t('kpiDispatchDue'),
      value: formatNumber(kpis.dispatchDueCount),
      subtext: `${kpis.dispatchDueCount} ${t('kpiDispatchDueSub')}`,
      icon: Truck,
      color: 'text-amber-600 bg-amber-50 border-amber-200/80',
      href: '/broker/orders',
    },
    {
      id: 'monthly_commission',
      label: t('kpiMonthlyCommission'),
      value: kpis.commissionThisMonth,
      subtext: `${formatNumber(kpis.commissionPendingInvoicesCount ?? 0)} ${t('kpiPendingInvoicesSub')}`,
      icon: IndianRupee,
      color: 'text-emerald-600 bg-emerald-50 border-emerald-200/80',
      href: '/broker/more/commission',
    },
    {
      id: 'open_disputes',
      label: t('kpiOpenDisputes'),
      value: formatNumber(kpis.openDisputesCount ?? 0),
      subtext: `${kpis.openDisputesCount ?? 0} ${t('kpiOpenDisputesSub')}`,
      icon: AlertTriangle,
      color: 'text-rose-600 bg-rose-50 border-rose-200/80',
      href: '/broker/more/disputes',
    },
  ];

  const ACTION_CATEGORIES: Array<{ id: string; label: string }> = [
    { id: 'all', label: t('allStatusFilter') },
    { id: 'dispute_unresolved', label: t('actionCategoryDispute') },
    { id: 'delivery_review', label: t('actionCategoryLogistics') },
    { id: 'terms_confirmation', label: t('actionCategoryConfirmation') },
    { id: 'requirement_expiring', label: t('actionCategoryExpiring') },
    { id: 'partial_allocation', label: t('actionCategoryAllocation') },
    { id: 'invoice_followup', label: t('actionCategoryInvoice') },
  ];

  return (
    <div className="w-full min-h-screen bg-[#F8FAFC]">
      <RealtimeDealsListener />

      {/* Main Page Container */}
      <div className="w-full max-w-screen-xl mx-auto p-4 sm:p-6 lg:p-8 space-y-6 overflow-x-hidden">
        
        {/* --- 1. PAGE HEADER --- */}
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
          <div>
            <div className="flex items-center gap-2.5">
              <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-slate-900">
                {t('dashboardTitle')}
              </h1>
              <span className="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold uppercase tracking-wider bg-[#CCFBF1] text-[#0D9488] border border-teal-200/70 shrink-0">
                {t('liveStatus')}
              </span>
            </div>
            <p className="text-xs sm:text-sm text-slate-500 mt-1">
              {t('tradingDeskSummary')}
            </p>
          </div>
          
          <div className="flex items-center gap-2">
            <LanguageSelector variant="pill" />
            <div className="hidden sm:flex items-center gap-2 text-xs font-medium text-slate-600 bg-white px-3 py-1.5 rounded-lg border border-slate-200/80 shadow-2xs">
              <Calendar className="w-3.5 h-3.5 text-[#0D9488]" />
              <span>{t('todayTradingDesk')}</span>
            </div>
          </div>
        </div>

        {/* --- 2. SUMMARY KPIS RIBBON (8 AUTHORITATIVE METRICS) --- */}
        <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-8 gap-2.5 sm:gap-3">
          {SUMMARY_KPIS.map((kpi) => {
            const Icon = kpi.icon;

            return (
              <Link key={kpi.id} href={kpi.href} className="group focus:outline-none">
                <Card className="bg-white border border-slate-200/80 shadow-2xs hover:border-[#0D9488]/40 hover:shadow-xs transition-all rounded-xl overflow-hidden p-3 h-full flex flex-col justify-between">
                  <div className="flex items-start justify-between gap-1.5">
                    <span className="text-[11px] font-semibold text-slate-500 tracking-tight line-clamp-1 group-hover:text-slate-800 transition-colors">
                      {kpi.label}
                    </span>
                    <div className={`w-6 h-6 rounded-md border flex items-center justify-center shrink-0 ${kpi.color}`}>
                      <Icon className="w-3 h-3" />
                    </div>
                  </div>

                  <div className="mt-1.5">
                    <div className="text-base sm:text-lg font-black text-slate-900 tracking-tight leading-tight">
                      {kpi.value}
                    </div>
                    <div className="text-[9px] font-medium text-slate-400 mt-0.5 truncate">
                      {kpi.subtext}
                    </div>
                  </div>
                </Card>
              </Link>
            );
          })}
        </div>

        {/* --- 3. QUICK ACTIONS SHORTCUTS --- */}
        <BrokerQuickActions />

        {/* --- 4. OPERATIONAL SEARCH & CATEGORY FILTER BAR --- */}
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 bg-white p-3 rounded-xl border border-slate-200/80 shadow-2xs">
          {/* Search Box */}
          <div className="relative flex-1">
            <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder={t('searchFilterPlaceholder')}
              className="w-full pl-9 pr-8 py-1.5 text-xs text-slate-800 placeholder:text-slate-400 rounded-lg border border-slate-200 focus:outline-none focus:border-[#0D9488] focus:ring-1 focus:ring-[#0D9488]"
            />
            {searchQuery && (
              <button
                type="button"
                onClick={() => setSearchQuery('')}
                className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
              >
                <X className="w-3.5 h-3.5" />
              </button>
            )}
          </div>

          {/* Category Chips */}
          <div className="flex items-center gap-1.5 overflow-x-auto pb-1 sm:pb-0 scrollbar-none">
            {ACTION_CATEGORIES.map((cat) => {
              const isSelected = selectedCategory === cat.id;
              return (
                <button
                  key={cat.id}
                  type="button"
                  onClick={() => setSelectedCategory(cat.id)}
                  className={`text-[11px] font-semibold px-2.5 py-1 rounded-lg border whitespace-nowrap transition-all select-none ${
                    isSelected
                      ? 'bg-[#0D9488] text-white border-[#0D9488] shadow-2xs'
                      : 'bg-slate-50 text-slate-600 border-slate-200 hover:bg-slate-100 hover:text-slate-900'
                  }`}
                >
                  {cat.label}
                </button>
              );
            })}
          </div>
        </div>

        {/* --- 5. ACTION REQUIRED SECTION (P0 PRIORITY) --- */}
        <div className="space-y-3">
          <div className="flex items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <div className="w-2.5 h-2.5 rounded-full bg-rose-500 animate-pulse" />
              <h2 className="text-base sm:text-lg font-bold text-slate-900 tracking-tight">
                {t('actionRequiredTitle')}
              </h2>
              <span className="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold bg-rose-100 text-rose-700 border border-rose-200/80">
                {t('actionRequiredBadge')}
              </span>
            </div>
            <span className="text-xs font-medium text-slate-500 hidden sm:inline-block">
              {filteredActions.length} {t('actionRequiredCount')}
            </span>
          </div>

          {filteredActions.length === 0 ? (
            <div className="rounded-xl border border-dashed border-slate-200 bg-white p-6 text-center space-y-2">
              <div className="w-10 h-10 rounded-full bg-emerald-50 text-emerald-600 flex items-center justify-center mx-auto border border-emerald-100">
                <CheckCircle2 className="w-5 h-5" />
              </div>
              <h3 className="text-sm font-bold text-slate-800">{t('allClearTitle')}</h3>
              <p className="text-xs text-slate-500 max-w-sm mx-auto">
                {searchQuery || selectedCategory !== 'all'
                  ? t('noMatchingResults')
                  : t('allClearDesc')}
              </p>
              {(searchQuery || selectedCategory !== 'all') && (
                <button
                  type="button"
                  onClick={() => {
                    setSearchQuery('');
                    setSelectedCategory('all');
                  }}
                  className="text-xs font-semibold text-[#0D9488] hover:underline pt-1 inline-block"
                >
                  {t('clearFilters')}
                </button>
              )}
            </div>
          ) : (
            <div className="space-y-3">
              {filteredActions.map((alert) => {
                const isDanger = alert.type === 'danger';
                const isWarning = alert.type === 'warning';
                const isBlue = alert.type === 'blue';

                return (
                  <div
                    key={alert.id}
                    className={`relative rounded-xl border bg-white shadow-2xs p-4 sm:p-5 transition-all hover:shadow-xs overflow-hidden ${
                      isDanger
                        ? 'border-l-4 border-l-rose-500 border-slate-200/80 bg-gradient-to-r from-rose-50/40 via-white to-white'
                        : isWarning
                        ? 'border-l-4 border-l-amber-500 border-slate-200/80 bg-gradient-to-r from-amber-50/40 via-white to-white'
                        : isBlue
                        ? 'border-l-4 border-l-blue-500 border-slate-200/80 bg-gradient-to-r from-blue-50/40 via-white to-white'
                        : 'border-l-4 border-l-[#0D9488] border-slate-200/80 bg-gradient-to-r from-teal-50/40 via-white to-white'
                    }`}
                  >
                    <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
                      {/* Left: Content & Context */}
                      <div className="min-w-0 flex-1 space-y-1.5">
                        <div className="flex flex-wrap items-center gap-2">
                          <span
                            className={`text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-md border ${
                              isDanger
                                ? 'bg-rose-100 text-rose-700 border-rose-200'
                                : isWarning
                                ? 'bg-amber-100 text-amber-800 border-amber-200'
                                : isBlue
                                ? 'bg-blue-100 text-blue-800 border-blue-200'
                                : 'bg-teal-100 text-[#0D9488] border-teal-200'
                            }`}
                          >
                            {alert.badge}
                          </span>
                          <span className="text-xs font-mono font-bold text-slate-700">
                            {alert.dealRef}
                          </span>
                          <span className="text-xs text-slate-400">•</span>
                          <span className="text-xs font-semibold text-slate-800 truncate">
                            {alert.commodity}
                          </span>
                        </div>

                        <h3 className="text-sm sm:text-base font-bold text-slate-900 tracking-tight leading-snug">
                          {alert.title}
                        </h3>

                        <p className="text-xs sm:text-sm text-slate-600 leading-relaxed">
                          {alert.description}
                        </p>

                        <div className="flex items-center gap-1.5 text-[11px] font-medium text-slate-500 pt-0.5">
                          <Clock className="w-3 h-3 text-slate-400" />
                          <span>{alert.dueTime}</span>
                        </div>
                      </div>

                      {/* Right: Thumb-friendly deep link action button */}
                      <div className="shrink-0 w-full sm:w-auto pt-1 sm:pt-0">
                        <Link
                          href={alert.actionHref}
                          className={`w-full sm:w-auto min-h-[44px] sm:min-h-[42px] px-4 font-semibold text-xs sm:text-sm shadow-xs rounded-lg transition-all inline-flex items-center justify-center gap-2 select-none ${
                            isDanger
                              ? 'bg-rose-600 hover:bg-rose-700 text-white active:bg-rose-800'
                              : isWarning
                              ? 'bg-amber-600 hover:bg-amber-700 text-white active:bg-amber-800'
                              : isBlue
                              ? 'bg-blue-600 hover:bg-blue-700 text-white active:bg-blue-800'
                              : 'bg-[#0D9488] hover:bg-[#0F766E] text-white active:bg-teal-800'
                          }`}
                        >
                          <span>{alert.actionLabel}</span>
                          <ArrowRight className="w-4 h-4 shrink-0" />
                        </Link>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* --- 6. TWO-COLUMN OPERATIONAL WORK DESK --- */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 items-start">
          
          {/* LEFT COLUMN: ACTIVE PIPELINE DEALS */}
          <Card className="bg-white border border-slate-200/80 shadow-2xs rounded-2xl overflow-hidden">
            <CardHeader className="p-4 sm:p-5 border-b border-slate-100 bg-slate-50/50 flex flex-row items-center justify-between gap-3">
              <div>
                <div className="flex items-center gap-2">
                  <Sparkles className="w-4 h-4 text-[#0D9488]" />
                  <CardTitle className="text-sm sm:text-base font-bold text-slate-900">
                    {t('pipelineTitle')}
                  </CardTitle>
                </div>
                <CardDescription className="text-xs text-slate-500 mt-0.5">
                  {t('pipelineSub')}
                </CardDescription>
              </div>
              <Link
                href="/broker/deals"
                className="inline-flex items-center gap-1 h-8 text-xs font-semibold text-[#0D9488] hover:text-[#0F766E] hover:bg-teal-50 px-2 rounded-md transition-colors"
              >
                <span>{t('viewAll')}</span>
                <ChevronRight className="w-3.5 h-3.5" />
              </Link>
            </CardHeader>

            <CardContent className="p-3 sm:p-4 space-y-3">
              {filteredPipeline.length === 0 ? (
                <div className="p-6 rounded-xl border border-dashed border-slate-200 bg-slate-50/50 text-center space-y-2">
                  <Sparkles className="w-6 h-6 text-slate-400 mx-auto" />
                  <h4 className="text-xs font-bold text-slate-700">{t('noPipelineTitle')}</h4>
                  <p className="text-[11px] text-slate-500">
                    {searchQuery ? t('noMatchingResults') : t('noPipelineDesc')}
                  </p>
                </div>
              ) : (
                filteredPipeline.map((deal) => {
                  const isReady = deal.status === 'Ready to Book';

                  return (
                    <div
                      key={deal.id}
                      className="p-3.5 rounded-xl border border-slate-200/70 bg-white hover:border-[#0D9488]/40 hover:shadow-xs transition-all space-y-2.5"
                    >
                      {/* Top Row: Ref, Commodity, Status Badge */}
                      <div className="flex items-start justify-between gap-2">
                        <div className="min-w-0">
                          <div className="flex items-center gap-1.5">
                            <span className="text-[11px] font-mono font-bold text-slate-400">
                              {deal.dealRef}
                            </span>
                            <span className="text-xs font-bold text-slate-900 truncate">
                              {deal.commodity}
                            </span>
                          </div>
                          <div className="text-xs font-semibold text-slate-600 mt-0.5">
                            {deal.quantity} • <span className="text-slate-900 font-bold">{deal.targetPrice}</span>
                          </div>
                        </div>

                        <Badge
                          variant="outline"
                          className={`text-[10px] font-semibold tracking-wide shrink-0 ${
                            isReady
                              ? 'bg-emerald-50 text-emerald-700 border-emerald-200'
                              : 'bg-amber-50 text-amber-700 border-amber-200'
                          }`}
                        >
                          {isReady ? t('readyToBook') : t('negotiating')}
                        </Badge>
                      </div>

                      {/* Middle: Parties (Strictly Verified Company Names - Zero Contact PII) */}
                      <div className="flex items-center gap-1.5 text-[11px] text-slate-500">
                        <Building2 className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                        <span className="truncate">{deal.seller}</span>
                        <span className="text-slate-400">→</span>
                        <span className="truncate font-medium text-slate-700">{deal.buyer}</span>
                      </div>

                      {/* Bottom Row: Next action & Direct action link */}
                      <div className="pt-2 border-t border-slate-100 flex items-center justify-between gap-2">
                        <span className="text-[11px] font-medium text-[#0D9488] bg-[#0D9488]/5 px-2 py-0.5 rounded-md truncate">
                          {deal.nextAction}
                        </span>
                        <Link
                          href={deal.href}
                          className="inline-flex items-center gap-1 h-7 px-2.5 rounded-lg border border-slate-200 text-xs font-semibold text-slate-700 hover:text-[#0D9488] hover:border-[#0D9488] hover:bg-teal-50/50 transition-all shrink-0"
                        >
                          <span>{isReady ? t('lockDeal') : t('viewDetails')}</span>
                          <ArrowRight className="w-3 h-3" />
                        </Link>
                      </div>
                    </div>
                  );
                })
              )}
            </CardContent>
          </Card>

          {/* RIGHT COLUMN: TODAY'S CRM FOLLOW-UPS */}
          <BrokerFollowUpTasks initialTasks={tasks} />
        </div>

        {/* --- 7. RECENT ACTIVITY & EVENT STREAM TIMELINE --- */}
        <BrokerRecentActivity activities={recentActivity} />

      </div>
    </div>
  );
}
