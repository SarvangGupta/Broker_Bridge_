import React from 'react';
import Link from 'next/link';
import {
  ArrowLeft,
  AlertTriangle,
  CheckCircle2,
  Clock,
  ShieldAlert,
  AlertCircle,
  FileSpreadsheet,
  Filter,
} from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { getBrokerActiveDisputesAction } from '@/src/server/actions/broker-dispute-actions';
import { DisputeCard } from '@/src/components/broker/crm/dispute-card';

export const dynamic = 'force-dynamic';

export default async function BrokerDisputesPage() {
  const res = await getBrokerActiveDisputesAction();

  if (!res.success || !res.data) {
    return (
      <div className="p-4 sm:p-6 lg:p-8 space-y-6 w-full max-w-7xl mx-auto overflow-x-hidden">
        <Link
          href="/broker/more"
          className="inline-flex items-center gap-1.5 text-xs font-semibold text-teal-700 hover:text-teal-900 transition-colors mb-2"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to Additional Tools
        </Link>

        <Card className="border-red-200 bg-red-50/50">
          <CardContent className="p-6 text-center space-y-4">
            <div className="mx-auto w-12 h-12 rounded-full bg-red-100 flex items-center justify-center text-red-600">
              <AlertCircle className="w-6 h-6" />
            </div>
            <div className="space-y-1 max-w-md mx-auto">
              <h3 className="font-bold text-slate-900 text-base">Unable to Load Dispute Center</h3>
              <p className="text-xs sm:text-sm text-slate-600">
                {res.error || 'You do not have permission to view active trade disputes.'}
              </p>
            </div>
            <Link href="/broker/more">
              <Button className="bg-slate-900 text-white hover:bg-slate-800 text-xs font-semibold h-10 px-4">
                Return to Tools
              </Button>
            </Link>
          </CardContent>
        </Card>
      </div>
    );
  }

  const { summary, disputes } = res.data;

  return (
    <div className="p-4 sm:p-6 lg:p-8 space-y-6 w-full max-w-7xl mx-auto overflow-x-hidden">
      {/* Top Header & Navigation */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <Link
            href="/broker/more"
            className="inline-flex items-center gap-1.5 text-xs font-semibold text-teal-700 hover:text-teal-900 transition-colors mb-2"
          >
            <ArrowLeft className="w-4 h-4" />
            Back to Additional Tools
          </Link>
          <div className="flex items-center gap-2">
            <h1 className="text-2xl sm:text-3xl font-bold text-slate-900 tracking-tight flex items-center gap-2">
              <AlertTriangle className="w-7 h-7 text-amber-600" />
              Dispute Resolution Center
            </h1>
            <Badge className="bg-[#0D9488] text-white font-mono text-xs px-2.5 py-0.5">
              SPRINT 28.4
            </Badge>
          </div>
          <p className="text-xs sm:text-sm text-slate-500 mt-1">
            Operational exceptions, weighbridge variances, and quality mediation desk. No direct Buyer-Seller chat.
          </p>
        </div>
      </div>

      {/* TASK 2: KPI ROW SUMMARY CARDS */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 lg:gap-6">
        {/* CARD 1: OPEN DISPUTES (RED BADGE) */}
        <Card className="border-slate-200/80 bg-white shadow-xs relative overflow-hidden flex flex-col justify-between">
          <div className="absolute top-0 left-0 w-1.5 h-full bg-red-600" />
          <CardHeader className="pb-2 pt-4 px-4 sm:px-5">
            <div className="flex items-center justify-between">
              <span className="text-[10px] font-bold uppercase tracking-wider text-red-700 flex items-center gap-1">
                <AlertTriangle className="w-3.5 h-3.5 text-red-600" />
                Open Disputes
              </span>
              <Badge className="bg-red-100 text-red-800 border-red-300 font-bold text-[10px]">
                ACTION REQUIRED
              </Badge>
            </div>
            <CardTitle className="text-2xl sm:text-3xl font-bold text-slate-900 font-mono mt-1">
              {summary.openDisputesCount}
            </CardTitle>
            <CardDescription className="text-xs text-slate-500">
              Active exceptions requiring Broker mediation & findings
            </CardDescription>
          </CardHeader>
          <CardContent className="px-4 sm:px-5 pb-4 pt-0 text-xs border-t border-slate-100 mt-2">
            <div className="pt-2 text-[11px] text-slate-500 flex justify-between items-center">
              <span>Under Review:</span>
              <span className="font-bold text-amber-700">{summary.underReviewCount} Cases</span>
            </div>
          </CardContent>
        </Card>

        {/* CARD 2: RESOLVED DISPUTES (GREEN BADGE) */}
        <Card className="border-slate-200/80 bg-white shadow-xs relative overflow-hidden flex flex-col justify-between">
          <div className="absolute top-0 left-0 w-1.5 h-full bg-emerald-600" />
          <CardHeader className="pb-2 pt-4 px-4 sm:px-5">
            <div className="flex items-center justify-between">
              <span className="text-[10px] font-bold uppercase tracking-wider text-emerald-700 flex items-center gap-1">
                <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" />
                Resolved Disputes
              </span>
              <Badge className="bg-emerald-100 text-emerald-800 border-emerald-300 font-bold text-[10px]">
                SETTLED
              </Badge>
            </div>
            <CardTitle className="text-2xl sm:text-3xl font-bold text-slate-900 font-mono mt-1">
              {summary.resolvedDisputesCount}
            </CardTitle>
            <CardDescription className="text-xs text-slate-500">
              Successfully arbitrated trade variances & concessions
            </CardDescription>
          </CardHeader>
          <CardContent className="px-4 sm:px-5 pb-4 pt-0 text-xs border-t border-slate-100 mt-2">
            <div className="pt-2 text-[11px] text-slate-500 flex justify-between items-center">
              <span>Resolution Rate:</span>
              <span className="font-bold text-emerald-700">
                {summary.totalDisputes > 0
                  ? `${Math.round((summary.resolvedDisputesCount / summary.totalDisputes) * 100)}%`
                  : '100%'}
              </span>
            </div>
          </CardContent>
        </Card>

        {/* CARD 3: TOTAL DISPUTES */}
        <Card className="border-slate-200/80 bg-white shadow-xs relative overflow-hidden flex flex-col justify-between">
          <div className="absolute top-0 left-0 w-1.5 h-full bg-teal-600" />
          <CardHeader className="pb-2 pt-4 px-4 sm:px-5">
            <div className="flex items-center justify-between">
              <span className="text-[10px] font-bold uppercase tracking-wider text-teal-700 flex items-center gap-1">
                <ShieldAlert className="w-3.5 h-3.5 text-[#0D9488]" />
                Total Dispute History
              </span>
              <Badge variant="outline" className="text-[10px] border-slate-200 text-slate-700">
                AUDIT LOG
              </Badge>
            </div>
            <CardTitle className="text-2xl sm:text-3xl font-bold text-slate-900 font-mono mt-1">
              {summary.totalDisputes}
            </CardTitle>
            <CardDescription className="text-xs text-slate-500">
              Lifetime operational exceptions logged on active orders
            </CardDescription>
          </CardHeader>
          <CardContent className="px-4 sm:px-5 pb-4 pt-0 text-xs border-t border-slate-100 mt-2">
            <div className="pt-2 text-[11px] text-slate-500 flex justify-between items-center">
              <span>Communication Boundaries:</span>
              <span className="font-bold text-slate-700">100% Broker Mediated</span>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* TASK 2: DISPUTE CARDS FEED */}
      <Card className="border-slate-200/80 bg-white shadow-xs">
        <CardHeader className="pb-3 border-b border-slate-100 flex flex-row items-center justify-between">
          <div>
            <CardTitle className="text-base font-bold flex items-center gap-2 text-slate-900">
              <AlertTriangle className="w-4 h-4 text-amber-600" />
              Active & Logged Dispute Cases
            </CardTitle>
            <CardDescription className="text-xs">
              Quality, weight, delivery, document, and commercial exceptions needing mediation.
            </CardDescription>
          </div>

          <Badge variant="outline" className="font-mono text-xs text-slate-600 border-slate-200">
            {disputes.length} Case{disputes.length === 1 ? '' : 's'}
          </Badge>
        </CardHeader>
        <CardContent className="p-4 sm:p-6">
          {disputes.length === 0 ? (
            <div className="p-8 text-center space-y-3">
              <div className="mx-auto w-12 h-12 rounded-full bg-emerald-100 flex items-center justify-center text-emerald-600">
                <CheckCircle2 className="w-6 h-6" />
              </div>
              <div className="space-y-1 max-w-sm mx-auto">
                <p className="text-sm font-bold text-slate-900">Zero Active Disputes</p>
                <p className="text-xs text-slate-500">
                  All trade dispatches and order finalizations are running smoothly without open operational exceptions.
                </p>
              </div>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 lg:gap-6">
              {disputes.map((dispute) => (
                <DisputeCard key={dispute.id} dispute={dispute} />
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
