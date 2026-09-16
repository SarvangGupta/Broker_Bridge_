import React from 'react';
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
} from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { RealtimeDealsListener } from '@/src/components/realtime-deals-listener';
import { getBrokerDashboardDataAction } from '@/src/server/actions/broker-dashboard-actions';
import { BrokerFollowUpTasks } from '@/src/components/dashboard/broker-follow-up-tasks';

export const dynamic = 'force-dynamic';

export default async function BrokerDashboardPage() {
  // Fetch real live broker data from server action (Strict Assignment Model)
  const res = await getBrokerDashboardDataAction();

  const kpis = res.data?.kpis ?? {
    activeDealsCount: 0,
    openRequirementsCount: 0,
    dispatchDueCount: 0,
    commissionThisMonth: '₹0',
  };

  const alerts = res.data?.alerts ?? [];
  const pipeline = res.data?.pipeline ?? [];
  const tasks = res.data?.tasks ?? [];

  const COMPACT_KPIS = [
    {
      id: 'active_deals',
      label: 'Active Deals',
      value: kpis.activeDealsCount,
      subtext: `${kpis.activeDealsCount} locked or in transit`,
      icon: Handshake,
    },
    {
      id: 'open_requirements',
      label: 'Open Requirements',
      value: kpis.openRequirementsCount,
      subtext: `${kpis.openRequirementsCount} matching opportunities`,
      icon: Layers,
    },
    {
      id: 'dispatch_due',
      label: 'Dispatch Due',
      value: kpis.dispatchDueCount,
      subtext: `${kpis.dispatchDueCount} pending logistics`,
      icon: Truck,
    },
    {
      id: 'monthly_commission',
      label: 'Commission This Month',
      value: kpis.commissionThisMonth,
      subtext: 'Brokerage volume rate',
      icon: IndianRupee,
    },
  ];

  return (
    <div className="w-full min-h-screen bg-[#F8FAFC]">
      <RealtimeDealsListener />

      {/* Main Page Container: w-full max-w-screen-xl mx-auto p-4 sm:p-6 lg:p-8 space-y-6 */}
      <div className="w-full max-w-screen-xl mx-auto p-4 sm:p-6 lg:p-8 space-y-6 overflow-x-hidden">
        
        {/* --- 1. PAGE HEADER --- */}
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
          <div>
            <div className="flex items-center gap-2.5">
              <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-slate-900">
                Broker Command Center
              </h1>
              <span className="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold uppercase tracking-wider bg-[#CCFBF1] text-[#0D9488] border border-teal-200/70 shrink-0">
                LIVE
              </span>
            </div>
            <p className="text-xs sm:text-sm text-slate-500 mt-1">
              Action-first operational summary • Jaipur Commodity Mandi
            </p>
          </div>
          <div className="flex items-center gap-2 text-xs font-medium text-slate-500 bg-white px-3 py-1.5 rounded-lg border border-slate-200/80 shadow-2xs w-fit">
            <Calendar className="w-3.5 h-3.5 text-[#0D9488]" />
            <span>Today&apos;s Trading Desk</span>
          </div>
        </div>

        {/* --- 2. COMPACT KPIS (THE TOP RIBBON) --- */}
        {/* Responsive grid: grid-cols-2 lg:grid-cols-4 gap-4 */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
          {COMPACT_KPIS.map((kpi) => {
            const Icon = kpi.icon;

            return (
              <Card
                key={kpi.id}
                className="bg-white border border-slate-200/80 shadow-2xs hover:border-[#0D9488]/40 hover:shadow-xs transition-all rounded-xl overflow-hidden p-3.5 sm:p-4"
              >
                <div className="flex items-center justify-between gap-2">
                  <span className="text-xs font-semibold text-slate-500 tracking-tight line-clamp-1">
                    {kpi.label}
                  </span>
                  {/* Electric Teal #0D9488 Accent Icon */}
                  <div className="w-8 h-8 sm:w-9 sm:h-9 rounded-lg bg-[#0D9488]/10 border border-[#0D9488]/20 flex items-center justify-center text-[#0D9488] shrink-0">
                    <Icon className="w-4 h-4 sm:w-4.5 sm:h-4.5" />
                  </div>
                </div>

                <div className="mt-2.5">
                  <div className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight leading-tight">
                    {kpi.value}
                  </div>
                  <div className="text-[11px] font-medium text-slate-500 mt-1 truncate">
                    {kpi.subtext}
                  </div>
                </div>
              </Card>
            );
          })}
        </div>

        {/* --- 3. ACTION REQUIRED SECTION (P0 PRIORITY) --- */}
        <div className="space-y-3">
          {/* Section Header */}
          <div className="flex items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <div className="w-2.5 h-2.5 rounded-full bg-rose-500 animate-pulse" />
              <h2 className="text-base sm:text-lg font-bold text-slate-900 tracking-tight">
                Action Required
              </h2>
              <span className="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold bg-rose-100 text-rose-700 border border-rose-200/80">
                P0 IMMEDIATE
              </span>
            </div>
            <span className="text-xs font-medium text-slate-500 hidden sm:inline-block">
              {alerts.length} items requiring broker decision
            </span>
          </div>

          {/* List of High-Priority Alert Cards */}
          {alerts.length === 0 ? (
            <div className="rounded-xl border border-dashed border-slate-200 bg-white p-6 text-center space-y-2">
              <div className="w-10 h-10 rounded-full bg-emerald-50 text-emerald-600 flex items-center justify-center mx-auto border border-emerald-100">
                <CheckCircle2 className="w-5 h-5" />
              </div>
              <h3 className="text-sm font-bold text-slate-800">All clear! No pending actions.</h3>
              <p className="text-xs text-slate-500 max-w-sm mx-auto">
                No urgent price counters, unbooked mandates, or delayed dispatches requiring broker intervention.
              </p>
            </div>
          ) : (
            <div className="space-y-3">
              {alerts.map((alert) => {
                const isDanger = alert.type === 'danger';
                const isWarning = alert.type === 'warning';

                return (
                  <div
                    key={alert.id}
                    className={`relative rounded-xl border bg-white shadow-2xs p-4 sm:p-5 transition-all hover:shadow-xs overflow-hidden ${
                      isDanger
                        ? 'border-l-4 border-l-rose-500 border-slate-200/80 bg-gradient-to-r from-rose-50/40 via-white to-white'
                        : isWarning
                        ? 'border-l-4 border-l-amber-500 border-slate-200/80 bg-gradient-to-r from-amber-50/40 via-white to-white'
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

        {/* --- 4. ACTIVE WORK & TODAY'S FOLLOW-UPS --- */}
        {/* Responsive two-column grid: grid-cols-1 lg:grid-cols-2 gap-6 */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 items-start">
          
          {/* LEFT COLUMN: ACTIVE PIPELINE */}
          <Card className="bg-white border border-slate-200/80 shadow-2xs rounded-2xl overflow-hidden">
            <CardHeader className="p-4 sm:p-5 border-b border-slate-100 bg-slate-50/50 flex flex-row items-center justify-between gap-3">
              <div>
                <div className="flex items-center gap-2">
                  <Sparkles className="w-4 h-4 text-[#0D9488]" />
                  <CardTitle className="text-sm sm:text-base font-bold text-slate-900">
                    Active Pipeline
                  </CardTitle>
                </div>
                <CardDescription className="text-xs text-slate-500 mt-0.5">
                  Negotiations & deals ready to lock
                </CardDescription>
              </div>
              <Link
                href="/broker/deals"
                className="inline-flex items-center gap-1 h-8 text-xs font-semibold text-[#0D9488] hover:text-[#0F766E] hover:bg-teal-50 px-2 rounded-md transition-colors"
              >
                <span>View All</span>
                <ChevronRight className="w-3.5 h-3.5" />
              </Link>
            </CardHeader>

            <CardContent className="p-3 sm:p-4 space-y-3">
              {pipeline.length === 0 ? (
                <div className="p-6 rounded-xl border border-dashed border-slate-200 bg-slate-50/50 text-center space-y-2">
                  <Sparkles className="w-6 h-6 text-slate-400 mx-auto" />
                  <h4 className="text-xs font-bold text-slate-700">No Active Negotiations</h4>
                  <p className="text-[11px] text-slate-500">
                    Assigned trade mandates and deal proposals will appear here as negotiations progress.
                  </p>
                </div>
              ) : (
                pipeline.map((deal) => {
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
                          {deal.status}
                        </Badge>
                      </div>

                      {/* Middle: Parties (Strictly Company Names - Zero Personal Contact PII) */}
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
                          <span>{isReady ? 'Lock Deal' : 'View'}</span>
                          <ArrowRight className="w-3 h-3" />
                        </Link>
                      </div>
                    </div>
                  );
                })
              )}
            </CardContent>
          </Card>

          {/* RIGHT COLUMN: TODAY'S FOLLOW-UPS (Interactive Client Component) */}
          <BrokerFollowUpTasks initialTasks={tasks} />
        </div>
      </div>
    </div>
  );
}
