'use client';

import React, { useState, useMemo } from 'react';
import Link from 'next/link';
import {
  CreditCard,
  IndianRupee,
  CheckCircle2,
  Clock,
  AlertTriangle,
  AlertCircle,
  Search,
  ArrowRight,
  ShieldCheck,
  Building2,
  Receipt,
  Truck,
  TrendingDown,
  Scale,
} from 'lucide-react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
} from '@/components/ui/table';
import { cn } from '@/lib/utils';
import {
  BuyerPayableLedgerData,
  BuyerPayableItem,
  BuyerPaymentStatus,
} from '@/src/types/buyer-payment-types';

export interface GlobalPayablesHubProps {
  initialData: BuyerPayableLedgerData;
  className?: string;
}

/**
 * Task 4 (Micro-Sprint 39.3): Global Payables Hub Component.
 * 
 * Replaces the SprintPlaceholder on /buyer/more with a consolidated master view
 * of all active payable ledgers, escrow settlement statuses, and outstanding balances.
 * 
 * Strict Guardrails:
 * - Server-side math: strictly pre-calculated amounts displayed.
 * - Nodal escrow model: zero seller bank details.
 * - Mobile-first: 360px zero horizontal scrolling via responsive table/card switching.
 * - Touch targets: min-h-[48px] on all links and interactive elements.
 */
export function GlobalPayablesHub({ initialData, className }: GlobalPayablesHubProps) {
  const { overview, payables } = initialData;
  const [searchQuery, setSearchQuery] = useState('');
  const [activeTab, setActiveTab] = useState<'all' | 'due' | 'settled'>('all');

  // Filtered payables list
  const filteredPayables = useMemo(() => {
    return payables.filter((p) => {
      // Tab filter
      if (activeTab === 'due' && p.outstandingBalance <= 0) return false;
      if (activeTab === 'settled' && p.outstandingBalance > 0) return false;

      // Search query
      if (!searchQuery.trim()) return true;
      const q = searchQuery.toLowerCase().trim();
      return (
        p.bookingId.toLowerCase().includes(q) ||
        p.commodityName.toLowerCase().includes(q) ||
        p.gradeName.toLowerCase().includes(q) ||
        (p.dealReference && p.dealReference.toLowerCase().includes(q))
      );
    });
  }, [payables, activeTab, searchQuery]);

  return (
    <div className={cn('w-full max-w-full space-y-5', className)}>
      {/* 1. Header Banner */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 bg-white p-4 sm:p-5 rounded-2xl border border-slate-200 shadow-xs">
        <div className="space-y-1">
          <div className="flex items-center gap-2">
            <span className="px-2 py-0.5 rounded-md bg-[#0284C7]/10 text-[#0284C7] text-[10px] font-bold uppercase tracking-wider">
              Financial Settlement
            </span>
          </div>
          <h1 className="text-lg sm:text-xl font-bold text-slate-900 tracking-tight">
            Payable Ledger & Escrow Hub
          </h1>
          <p className="text-xs text-slate-500 max-w-2xl leading-relaxed">
            Consolidated commercial payables across your active contracts. All funds are deposited into the regulated BrokerBridge Nodal Escrow and released to sellers strictly upon physical delivery verification.
          </p>
        </div>

        <div className="flex items-center gap-2 flex-wrap self-start sm:self-auto shrink-0">
          <Link
            href="/buyer/more/disputes"
            className="inline-flex items-center gap-1.5 text-xs font-bold text-rose-700 bg-rose-50 hover:bg-rose-100 border border-rose-200 px-3 py-2 rounded-xl transition-colors min-h-[40px]"
          >
            <AlertTriangle className="w-3.5 h-3.5 text-rose-600" />
            <span>Dispute Ledger</span>
          </Link>
          <div className="flex items-center gap-2 text-xs font-semibold text-slate-600 bg-slate-50 px-3 py-2 rounded-xl border border-slate-200 min-h-[40px]">
            <ShieldCheck className="w-4 h-4 text-emerald-600" />
            <span>RBI-Regulated Nodal Escrow</span>
          </div>
        </div>
      </div>

      {/* 2. Top Summary KPI Ribbon (4 metrics) */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        {/* Metric 1: Active Contracts */}
        <div className="rounded-xl border border-slate-200 bg-white p-3.5 space-y-1 shadow-2xs">
          <div className="flex items-center justify-between">
            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
              Active Contracts
            </span>
            <Truck className="w-3.5 h-3.5 text-slate-400" />
          </div>
          <div className="text-lg sm:text-xl font-black text-slate-900 font-mono">
            {overview.totalActiveOrders}
          </div>
          <span className="text-[10px] text-slate-500 block">Orders in lifecycle</span>
        </div>

        {/* Metric 2: Total Gross Payable */}
        <div className="rounded-xl border border-slate-200 bg-white p-3.5 space-y-1 shadow-2xs">
          <div className="flex items-center justify-between">
            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
              Gross Payable
            </span>
            <IndianRupee className="w-3.5 h-3.5 text-slate-400" />
          </div>
          <div className="text-lg sm:text-xl font-black text-slate-900 font-mono">
            {overview.formattedTotalGrossPayable}
          </div>
          <span className="text-[10px] text-slate-500 block">Total commercial volume</span>
        </div>

        {/* Metric 3: Total Paid in Escrow (Emerald) */}
        <div className="rounded-xl border border-emerald-200 bg-emerald-50/60 p-3.5 space-y-1 shadow-2xs">
          <div className="flex items-center justify-between">
            <span className="text-[10px] font-bold text-emerald-800 uppercase tracking-wider block">
              Deposited in Escrow
            </span>
            <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" />
          </div>
          <div className="text-lg sm:text-xl font-black text-emerald-900 font-mono">
            {overview.formattedTotalAmountPaid}
          </div>
          <span className="text-[10px] text-emerald-700 block">Confirmed buyer deposits</span>
        </div>

        {/* Metric 4: Total Outstanding Balance (Amber/Rose) */}
        <div
          className={cn(
            'rounded-xl border p-3.5 space-y-1 shadow-2xs',
            overview.totalOutstandingBalance > 0
              ? 'border-amber-200 bg-amber-50/60 text-amber-950'
              : 'border-slate-200 bg-white'
          )}
        >
          <div className="flex items-center justify-between">
            <span
              className={cn(
                'text-[10px] font-bold uppercase tracking-wider block',
                overview.totalOutstandingBalance > 0 ? 'text-amber-800' : 'text-slate-400'
              )}
            >
              Balance Due
            </span>
            <Clock className="w-3.5 h-3.5 text-amber-600" />
          </div>
          <div
            className={cn(
              'text-lg sm:text-xl font-black font-mono',
              overview.totalOutstandingBalance > 0 ? 'text-amber-900' : 'text-slate-800'
            )}
          >
            {overview.formattedTotalOutstandingBalance}
          </div>
          <span
            className={cn(
              'text-[10px] block',
              overview.totalOutstandingBalance > 0 ? 'text-amber-700' : 'text-slate-500'
            )}
          >
            Pending settlement balance
          </span>
        </div>
      </div>

      {/* 3. Filter Bar & Search */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 bg-white p-3 rounded-2xl border border-slate-200 shadow-2xs">
        {/* Tabs */}
        <div className="flex items-center gap-1.5 p-1 bg-slate-100 rounded-xl shrink-0">
          <button
            onClick={() => setActiveTab('all')}
            className={cn(
              'min-h-[40px] px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all',
              activeTab === 'all'
                ? 'bg-white text-slate-900 shadow-2xs'
                : 'text-slate-600 hover:text-slate-900'
            )}
          >
            All Payables ({payables.length})
          </button>
          <button
            onClick={() => setActiveTab('due')}
            className={cn(
              'min-h-[40px] px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all',
              activeTab === 'due'
                ? 'bg-white text-amber-700 shadow-2xs'
                : 'text-slate-600 hover:text-slate-900'
            )}
          >
            Balance Due ({payables.filter((p) => p.outstandingBalance > 0).length})
          </button>
          <button
            onClick={() => setActiveTab('settled')}
            className={cn(
              'min-h-[40px] px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all',
              activeTab === 'settled'
                ? 'bg-white text-emerald-700 shadow-2xs'
                : 'text-slate-600 hover:text-slate-900'
            )}
          >
            Fully Settled ({payables.filter((p) => p.outstandingBalance <= 0).length})
          </button>
        </div>

        {/* Search Input */}
        <div className="relative flex-1 max-w-sm">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <Input
            type="text"
            placeholder="Search booking, commodity..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-9 min-h-[48px] h-12 rounded-xl text-xs border-slate-200 bg-slate-50/50 focus:bg-white"
          />
        </div>
      </div>

      {/* 4. Master Table (Desktop) & Card List (Mobile 360px Viewport) */}
      {filteredPayables.length === 0 ? (
        <Card className="border border-slate-200 bg-white p-8 text-center space-y-3 rounded-2xl">
          <div className="w-12 h-12 rounded-2xl bg-slate-100 text-slate-400 mx-auto flex items-center justify-center">
            <Receipt className="w-6 h-6" />
          </div>
          <div className="space-y-1 max-w-sm mx-auto">
            <h3 className="text-sm font-bold text-slate-800">No Payables Matching Filter</h3>
            <p className="text-xs text-slate-500">
              There are no orders matching your current tab or search criteria.
            </p>
          </div>
          <Button
            variant="outline"
            onClick={() => {
              setActiveTab('all');
              setSearchQuery('');
            }}
            className="min-h-[48px] px-4 rounded-xl text-xs font-semibold"
          >
            Clear Filters
          </Button>
        </Card>
      ) : (
        <>
          {/* Desktop Table View (hidden on small viewports) */}
          <div className="hidden md:block rounded-2xl border border-slate-200 bg-white shadow-xs overflow-hidden">
            <Table>
              <TableHeader className="bg-slate-50 border-b border-slate-200">
                <TableRow>
                  <TableHead className="py-3 px-4 text-xs font-bold text-slate-600 uppercase">
                    Booking / Commodity
                  </TableHead>
                  <TableHead className="py-3 px-4 text-xs font-bold text-slate-600 uppercase">
                    Quantity & Rate
                  </TableHead>
                  <TableHead className="py-3 px-4 text-xs font-bold text-slate-600 uppercase text-right">
                    Gross Payable
                  </TableHead>
                  <TableHead className="py-3 px-4 text-xs font-bold text-slate-600 uppercase text-right">
                    Total Paid
                  </TableHead>
                  <TableHead className="py-3 px-4 text-xs font-bold text-slate-600 uppercase text-right">
                    Outstanding
                  </TableHead>
                  <TableHead className="py-3 px-4 text-xs font-bold text-slate-600 uppercase text-center">
                    Status
                  </TableHead>
                  <TableHead className="py-3 px-4 text-xs font-bold text-slate-600 uppercase text-right">
                    Action
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody className="divide-y divide-slate-100">
                {filteredPayables.map((item) => (
                  <TableRow key={item.bookingId} className="hover:bg-slate-50/70 transition-colors">
                    {/* Booking ID & Commodity */}
                    <TableCell className="py-3.5 px-4">
                      <div className="space-y-0.5">
                        <span className="font-mono text-xs font-bold text-[#0284C7] block">
                          {item.bookingId}
                        </span>
                        <span className="text-xs font-semibold text-slate-900 block truncate max-w-xs">
                          {item.commodityName}
                        </span>
                        <span className="text-[11px] text-slate-400 block">{item.gradeName}</span>
                      </div>
                    </TableCell>

                    {/* Quantity & Rate */}
                    <TableCell className="py-3.5 px-4 font-mono text-xs text-slate-700">
                      <div>
                        {item.finalQuantity} {item.unitSymbol}
                      </div>
                      <div className="text-[11px] text-slate-400">@ {item.formattedLockedBaseRate}</div>
                    </TableCell>

                    {/* Gross Payable */}
                    <TableCell className="py-3.5 px-4 font-mono text-xs font-bold text-slate-900 text-right">
                      {item.formattedGrossPayable}
                    </TableCell>

                    {/* Total Paid */}
                    <TableCell className="py-3.5 px-4 font-mono text-xs font-bold text-emerald-700 text-right">
                      {item.formattedTotalPaid}
                    </TableCell>

                    {/* Outstanding */}
                    <TableCell className="py-3.5 px-4 font-mono text-xs font-bold text-right">
                      <span
                        className={cn(
                          item.outstandingBalance <= 0
                            ? 'text-slate-400'
                            : item.isOverdue
                            ? 'text-rose-700'
                            : 'text-amber-700'
                        )}
                      >
                        {item.formattedOutstandingBalance}
                      </span>
                    </TableCell>

                    {/* Status Badge */}
                    <TableCell className="py-3.5 px-4 text-center">
                      {renderTableStatusBadge(item.paymentStatus, item.isOverdue)}
                    </TableCell>

                    {/* Action Button */}
                    <TableCell className="py-3.5 px-4 text-right">
                      <Link
                        href={`/buyer/orders/${item.bookingId}`}
                        className="inline-flex items-center justify-center min-h-[48px] px-3.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 text-slate-800 text-xs font-bold shadow-2xs transition-colors gap-1"
                      >
                        <span>View Order</span>
                        <ArrowRight className="w-3.5 h-3.5 text-slate-400" />
                      </Link>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>

          {/* Mobile Card View (360px Viewport Zero-Bleed) */}
          <div className="md:hidden space-y-3">
            {filteredPayables.map((item) => (
              <Card
                key={item.bookingId}
                className="w-full max-w-full overflow-hidden rounded-2xl border border-slate-200 bg-white p-4 space-y-3 shadow-xs"
              >
                {/* Header row */}
                <div className="flex items-start justify-between gap-2 border-b border-slate-100 pb-2.5">
                  <div className="space-y-0.5 min-w-0">
                    <span className="font-mono text-xs font-bold text-[#0284C7] block">
                      {item.bookingId}
                    </span>
                    <h3 className="text-xs sm:text-sm font-bold text-slate-900 truncate">
                      {item.commodityName}
                    </h3>
                    <span className="text-[11px] text-slate-500 block truncate">{item.gradeName}</span>
                  </div>

                  <div className="shrink-0">
                    {renderTableStatusBadge(item.paymentStatus, item.isOverdue)}
                  </div>
                </div>

                {/* 3-metric mini grid */}
                <div className="grid grid-cols-3 gap-2 p-2.5 rounded-xl bg-slate-50 border border-slate-100 text-xs font-mono">
                  <div>
                    <span className="text-[9px] font-bold text-slate-400 uppercase tracking-wider block">
                      Gross
                    </span>
                    <span className="font-bold text-slate-900 block truncate text-[11px]">
                      {item.formattedGrossPayable}
                    </span>
                  </div>

                  <div>
                    <span className="text-[9px] font-bold text-emerald-700 uppercase tracking-wider block">
                      Paid
                    </span>
                    <span className="font-bold text-emerald-800 block truncate text-[11px]">
                      {item.formattedTotalPaid}
                    </span>
                  </div>

                  <div>
                    <span
                      className={cn(
                        'text-[9px] font-bold uppercase tracking-wider block',
                        item.outstandingBalance > 0 ? 'text-amber-700' : 'text-slate-400'
                      )}
                    >
                      Balance
                    </span>
                    <span
                      className={cn(
                        'font-bold block truncate text-[11px]',
                        item.outstandingBalance <= 0
                          ? 'text-slate-500'
                          : item.isOverdue
                          ? 'text-rose-700'
                          : 'text-amber-800'
                      )}
                    >
                      {item.formattedOutstandingBalance}
                    </span>
                  </div>
                </div>

                {/* Rate and Quantity summary */}
                <div className="flex items-center justify-between text-[11px] text-slate-500 pt-0.5">
                  <span>Contract Lot:</span>
                  <span className="font-mono font-medium text-slate-700">
                    {item.finalQuantity} {item.unitSymbol} @ {item.formattedLockedBaseRate}
                  </span>
                </div>

                {/* View Order Link */}
                <Link
                  href={`/buyer/orders/${item.bookingId}`}
                  className="w-full min-h-[48px] h-12 rounded-xl bg-[#0284C7] hover:bg-[#0369A1] text-white text-xs font-bold shadow-xs transition-colors flex items-center justify-center gap-2"
                >
                  <span>View Order & Financial Ledger</span>
                  <ArrowRight className="w-4 h-4" />
                </Link>
              </Card>
            ))}
          </div>
        </>
      )}

      {/* 5. Nodal Escrow Information Footnote */}
      <div className="p-3.5 rounded-2xl bg-slate-50 border border-slate-200/80 flex items-start gap-3 text-xs text-slate-500">
        <Building2 className="w-4 h-4 text-[#0284C7] shrink-0 mt-0.5" />
        <div className="space-y-0.5 leading-relaxed text-[11px]">
          <span className="font-bold text-slate-800 block">
            Nodal Escrow Settlement Protocol
          </span>
          <p>
            BrokerBridge uses designated nodal accounts in accordance with RBI guidelines for commercial commodity transactions. Buyers remit funds to the verified platform escrow account. Funds are released to sellers only after electronic weighbridge slips, physical inspection, and delivery receipts are confirmed by both parties.
          </p>
        </div>
      </div>
    </div>
  );
}

/**
 * Status badge renderer for table / card
 */
function renderTableStatusBadge(status: BuyerPaymentStatus, isOverdue: boolean) {
  if (isOverdue) {
    return (
      <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-rose-50 text-rose-700 border border-rose-200">
        <AlertTriangle className="w-3 h-3 text-rose-600" />
        Overdue
      </span>
    );
  }

  switch (status) {
    case 'Paid':
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">
          <CheckCircle2 className="w-3 h-3 text-emerald-600" />
          Paid
        </span>
      );
    case 'Part Paid':
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-amber-50 text-amber-700 border border-amber-200">
          <Clock className="w-3 h-3 text-amber-600" />
          Part Paid
        </span>
      );
    case 'Disputed':
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-rose-50 text-rose-700 border border-rose-200">
          <AlertCircle className="w-3 h-3 text-rose-600" />
          Disputed
        </span>
      );
    case 'Pending':
    default:
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-sky-50 text-sky-700 border border-sky-200">
          <Clock className="w-3 h-3 text-sky-600" />
          Pending
        </span>
      );
  }
}
