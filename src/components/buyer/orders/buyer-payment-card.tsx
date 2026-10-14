'use client';

import React, { useState, useEffect } from 'react';
import {
  CreditCard,
  IndianRupee,
  CheckCircle2,
  Clock,
  AlertTriangle,
  AlertCircle,
  ShieldCheck,
  Building2,
  Copy,
  Check,
  Loader2,
  ChevronDown,
  ChevronUp,
  Receipt,
  FileCheck2,
  RefreshCw,
} from 'lucide-react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import {
  BuyerPayableItem,
  BuyerPaymentStatus,
} from '@/src/types/buyer-payment-types';
import { getBuyerPayableLedgerAction } from '@/src/server/actions/buyer-payment-actions';

export interface BuyerPaymentCardProps {
  bookingId: string;
  initialData?: BuyerPayableItem | null;
  className?: string;
}

/**
 * Task 3 (Micro-Sprint 39.3): Order-Level Financial UI Component.
 * 
 * Displays the financial payable status of a specific booking with 3 prominent metric blocks:
 * 1. Total Payable
 * 2. Amount Paid (in Green/Emerald)
 * 3. Outstanding Balance (in Rose/Amber if balance pending)
 * 
 * Strict Guardrails:
 * - Server-side math: UI receives strictly pre-calculated numbers.
 * - Nodal escrow model: zero seller bank details; buyer pays the platform nodal account.
 * - Mobile-first: 3-column financial metrics wrap to flex-col on 360px screens.
 * - Touch targets: min-h-[48px] on all interactive elements.
 */
export function BuyerPaymentCard({
  bookingId,
  initialData,
  className,
}: BuyerPaymentCardProps) {
  const [item, setItem] = useState<BuyerPayableItem | null>(initialData || null);
  const [loading, setLoading] = useState<boolean>(!initialData);
  const [error, setError] = useState<string | null>(null);
  const [showHistory, setShowHistory] = useState<boolean>(false);
  const [copiedEscrow, setCopiedEscrow] = useState<boolean>(false);

  // Load ledger if not provided via initialData
  useEffect(() => {
    if (initialData) {
      setItem(initialData);
      setLoading(false);
      return;
    }

    let isMounted = true;
    async function loadData() {
      try {
        setLoading(true);
        setError(null);
        const res = await getBuyerPayableLedgerAction(bookingId);
        if (!isMounted) return;

        if (res.success && res.data) {
          const matched =
            res.data.singlePayable ||
            res.data.payables.find((p) => p.bookingId.toLowerCase() === bookingId.toLowerCase()) ||
            res.data.payables[0] ||
            null;
          setItem(matched);
        } else {
          setError(res.error || 'Failed to load payable ledger details.');
        }
      } catch (err: any) {
        if (!isMounted) return;
        setError(err.message || 'An unexpected error occurred while loading payment ledger.');
      } finally {
        if (isMounted) setLoading(false);
      }
    }

    loadData();

    return () => {
      isMounted = false;
    };
  }, [bookingId, initialData]);

  // Copy Escrow Virtual Account Code
  const handleCopyEscrow = () => {
    if (!item?.escrowReference) return;
    navigator.clipboard.writeText(item.escrowReference);
    setCopiedEscrow(true);
    setTimeout(() => setCopiedEscrow(false), 2000);
  };

  // 1. Loading State
  if (loading) {
    return (
      <Card className={cn('w-full max-w-full overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-xs p-6', className)}>
        <div className="flex flex-col items-center justify-center py-10 space-y-3 text-center">
          <Loader2 className="w-8 h-8 text-[#0284C7] animate-spin" />
          <p className="text-xs sm:text-sm font-semibold text-slate-600">
            Fetching verified commercial ledger and escrow balances...
          </p>
        </div>
      </Card>
    );
  }

  // 2. Error State
  if (error || !item) {
    return (
      <Card className={cn('w-full max-w-full overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-xs', className)}>
        <CardHeader className="p-4 sm:p-5 border-b border-slate-100 pb-3">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-amber-50 text-amber-600 flex items-center justify-center shrink-0">
              <CreditCard className="w-4 h-4" />
            </div>
            <div>
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                Commercial Ledger
              </span>
              <CardTitle className="text-sm sm:text-base font-bold text-slate-900 leading-tight">
                Payable Ledger & Escrow
              </CardTitle>
            </div>
          </div>
        </CardHeader>
        <CardContent className="p-6 text-center space-y-4">
          <div className="w-10 h-10 rounded-full bg-amber-50 text-amber-600 mx-auto flex items-center justify-center">
            <AlertCircle className="w-5 h-5" />
          </div>
          <div className="space-y-1 max-w-md mx-auto">
            <h4 className="text-xs sm:text-sm font-bold text-slate-800">Financial Records Unavailable</h4>
            <p className="text-xs text-slate-500 leading-relaxed">
              {error || 'Financial terms have not been finalized yet for this booking.'}
            </p>
          </div>
          <Button
            variant="outline"
            onClick={async () => {
              setLoading(true);
              setError(null);
              const res = await getBuyerPayableLedgerAction(bookingId);
              if (res.success && res.data) {
                setItem(res.data.singlePayable || res.data.payables[0] || null);
              } else {
                setError(res.error || 'Retry failed');
              }
              setLoading(false);
            }}
            className="min-h-[48px] px-4 rounded-xl text-xs font-semibold"
          >
            <RefreshCw className="w-3.5 h-3.5 mr-2" />
            Retry Fetching Ledger
          </Button>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card
      className={cn(
        'w-full max-w-full overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-xs',
        className
      )}
    >
      {/* Header */}
      <CardHeader className="p-4 sm:p-5 border-b border-slate-100 pb-3">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-emerald-50 text-emerald-700 flex items-center justify-center shrink-0 border border-emerald-100">
              <IndianRupee className="w-4 h-4" />
            </div>
            <div>
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                Commercial Ledger & Settlement
              </span>
              <CardTitle className="text-sm sm:text-base font-bold text-slate-900 leading-tight">
                Payable Ledger & Escrow Status
              </CardTitle>
            </div>
          </div>

          <div className="flex items-center gap-2 self-start sm:self-auto">
            {renderPaymentStatusBadge(item.paymentStatus, item.isOverdue)}
          </div>
        </div>
      </CardHeader>

      <CardContent className="p-4 sm:p-5 space-y-5">
        {/* THREE PROMINENT METRIC BLOCKS (Mobile-First: flex-col on 360px, 3-column on sm+) */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          {/* Block 1: Total Gross Payable */}
          <div className="rounded-xl border border-slate-200 bg-slate-50/70 p-3.5 space-y-1">
            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
              1. Total Gross Payable
            </span>
            <div className="text-base sm:text-lg font-black text-slate-900 font-mono tracking-tight">
              {item.formattedGrossPayable}
            </div>
            <p className="text-[11px] text-slate-500">
              Base lot value + 2.5% statutory charges
            </p>
          </div>

          {/* Block 2: Total Amount Paid (Emerald / Green) */}
          <div className="rounded-xl border border-emerald-200 bg-emerald-50/70 p-3.5 space-y-1">
            <div className="flex items-center justify-between">
              <span className="text-[10px] font-bold text-emerald-800 uppercase tracking-wider block">
                2. Total Amount Paid
              </span>
              <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" />
            </div>
            <div className="text-base sm:text-lg font-black text-emerald-900 font-mono tracking-tight">
              {item.formattedTotalPaid}
            </div>
            <p className="text-[11px] text-emerald-700">
              {item.totalPaid > 0 ? 'Confirmed in Nodal Escrow' : 'No payments confirmed yet'}
            </p>
          </div>

          {/* Block 3: Outstanding Balance (Rose/Amber if pending, Slate if paid) */}
          <div
            className={cn(
              'rounded-xl border p-3.5 space-y-1',
              item.outstandingBalance <= 0
                ? 'border-slate-200 bg-slate-50/70'
                : item.isOverdue
                ? 'border-rose-300 bg-rose-50/80 text-rose-950'
                : 'border-amber-200 bg-amber-50/70 text-amber-950'
            )}
          >
            <div className="flex items-center justify-between">
              <span
                className={cn(
                  'text-[10px] font-bold uppercase tracking-wider block',
                  item.outstandingBalance <= 0
                    ? 'text-slate-400'
                    : item.isOverdue
                    ? 'text-rose-800'
                    : 'text-amber-800'
                )}
              >
                3. Outstanding Balance
              </span>
              {item.outstandingBalance > 0 && <Clock className="w-3.5 h-3.5 text-amber-600" />}
            </div>
            <div
              className={cn(
                'text-base sm:text-lg font-black font-mono tracking-tight',
                item.outstandingBalance <= 0
                  ? 'text-slate-700'
                  : item.isOverdue
                  ? 'text-rose-900'
                  : 'text-amber-900'
              )}
            >
              {item.formattedOutstandingBalance}
            </div>
            <p
              className={cn(
                'text-[11px]',
                item.outstandingBalance <= 0
                  ? 'text-slate-500'
                  : item.isOverdue
                  ? 'text-rose-700'
                  : 'text-amber-700'
              )}
            >
              {item.outstandingBalance <= 0
                ? 'Settlement Fully Reconciled'
                : 'Payable prior to final vehicle release'}
            </p>
          </div>
        </div>

        {/* Commercial Math Breakdown Card */}
        <div className="rounded-xl bg-slate-50 border border-slate-200/80 p-3.5 space-y-2.5 text-xs">
          <div className="flex items-center justify-between font-bold text-slate-800">
            <span>Contract Commercial Formula</span>
            <span className="font-mono text-slate-500 text-[11px]">Server Verified</span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-[11px] text-slate-600 pt-1">
            <div className="flex justify-between items-center py-1 border-b sm:border-b-0 border-slate-200/60">
              <span className="text-slate-500">Locked Rate & Volume:</span>
              <span className="font-mono font-semibold text-slate-800">
                {item.finalQuantity} {item.unitSymbol} @ {item.formattedLockedBaseRate}
              </span>
            </div>
            <div className="flex justify-between items-center py-1 border-b sm:border-b-0 border-slate-200/60">
              <span className="text-slate-500">Base Contract Amount:</span>
              <span className="font-mono font-semibold text-slate-800">{item.formattedBaseAmount}</span>
            </div>
            <div className="flex justify-between items-center py-1">
              <span className="text-slate-500">Mandi Cess, Brokerage & Taxes:</span>
              <span className="font-mono font-semibold text-slate-800">{item.formattedChargesAndTaxes}</span>
            </div>
            <div className="flex justify-between items-center py-1 font-bold text-slate-900">
              <span>Gross Billable Payable:</span>
              <span className="font-mono text-[#0284C7]">{item.formattedGrossPayable}</span>
            </div>
          </div>
        </div>

        {/* Nodal Escrow Virtual Account Details */}
        <div className="rounded-xl border border-sky-200 bg-sky-50/50 p-3.5 space-y-2.5">
          <div className="flex items-start gap-2.5">
            <Building2 className="w-4 h-4 text-[#0284C7] shrink-0 mt-0.5" />
            <div className="space-y-0.5 flex-1 min-w-0">
              <span className="text-[10px] font-bold text-[#0284C7] uppercase tracking-wider block">
                Designated Nodal Escrow Account
              </span>
              <h4 className="text-xs font-bold text-slate-900 leading-tight">
                {item.nodalAccountName}
              </h4>
              <p className="text-[11px] text-slate-600 leading-relaxed">
                Remit payment directly via RTGS / NEFT using your unique booking virtual identifier:
              </p>
            </div>
          </div>

          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 p-2.5 rounded-lg bg-white border border-sky-200 shadow-2xs">
            <div className="min-w-0">
              <span className="text-[9px] uppercase font-bold text-slate-400 block">
                Escrow Virtual Account Code
              </span>
              <span className="font-mono font-bold text-xs sm:text-sm text-slate-900 truncate block">
                {item.escrowReference}
              </span>
            </div>

            <Button
              variant="outline"
              size="sm"
              onClick={handleCopyEscrow}
              className="min-h-[48px] sm:min-h-[36px] h-12 sm:h-9 px-3 rounded-lg border-sky-300 bg-sky-50/80 hover:bg-sky-100 text-[#0284C7] font-bold text-xs shrink-0 flex items-center justify-center gap-1.5 transition-colors"
            >
              {copiedEscrow ? (
                <>
                  <Check className="w-3.5 h-3.5 text-emerald-600" />
                  <span className="text-emerald-700">Copied Code</span>
                </>
              ) : (
                <>
                  <Copy className="w-3.5 h-3.5" />
                  <span>Copy Code</span>
                </>
              )}
            </Button>
          </div>
        </div>

        {/* Payment History Accordion */}
        {item.paymentRecords.length > 0 && (
          <div className="border-t border-slate-100 pt-2">
            <button
              onClick={() => setShowHistory(!showHistory)}
              className="w-full flex items-center justify-between py-2 text-xs font-bold text-slate-700 hover:text-slate-900 transition-colors min-h-[48px]"
            >
              <span className="flex items-center gap-1.5">
                <Receipt className="w-4 h-4 text-slate-500" />
                <span>Transaction & Payment Milestones ({item.paymentRecords.length})</span>
              </span>
              {showHistory ? (
                <ChevronUp className="w-4 h-4 text-slate-400" />
              ) : (
                <ChevronDown className="w-4 h-4 text-slate-400" />
              )}
            </button>

            {showHistory && (
              <div className="space-y-2 pt-2 animate-in fade-in">
                {item.paymentRecords.map((rec) => (
                  <div
                    key={rec.id}
                    className="p-3 rounded-xl border border-slate-200 bg-white flex flex-col sm:flex-row sm:items-center justify-between gap-2 shadow-2xs"
                  >
                    <div className="space-y-0.5 min-w-0">
                      <div className="flex items-center gap-1.5">
                        <span className="font-mono text-xs font-bold text-slate-900">
                          {rec.referenceNumber}
                        </span>
                        <span className="px-1.5 py-0.2 rounded text-[9px] font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">
                          {rec.status}
                        </span>
                      </div>
                      <p className="text-[11px] text-slate-500">
                        {rec.paymentMethod} •{' '}
                        {new Date(rec.paymentDate).toLocaleDateString('en-IN', {
                          day: '2-digit',
                          month: 'short',
                          year: 'numeric',
                        })}
                      </p>
                    </div>

                    <div className="font-mono font-bold text-sm text-slate-900 sm:text-right">
                      {rec.formattedAmount}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* Read-Only Disclaimer & Nodal Protection Seal */}
        <div className="p-3 rounded-xl bg-slate-50/70 border border-slate-200/60 flex items-start gap-2.5 text-[11px] text-slate-500">
          <ShieldCheck className="w-4 h-4 text-[#0284C7] shrink-0 mt-0.5" />
          <div className="space-y-0.5 leading-relaxed">
            <span className="font-bold text-slate-700 block">
              BrokerBridge Nodal Escrow Financial Safeguard
            </span>
            <p>
              {item.disclaimer} All settlements are locked to statutory weights and broker-audited fulfillment documents.
            </p>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

/**
 * Status badge renderer for payment status
 */
function renderPaymentStatusBadge(status: BuyerPaymentStatus, isOverdue: boolean) {
  if (isOverdue) {
    return (
      <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-rose-100 text-rose-800 border border-rose-300 shadow-2xs">
        <AlertTriangle className="w-3.5 h-3.5 text-rose-600" />
        Payment Overdue
      </span>
    );
  }

  switch (status) {
    case 'Paid':
      return (
        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-emerald-100 text-emerald-800 border border-emerald-300 shadow-2xs">
          <CheckCircle2 className="w-3.5 h-3.5 text-emerald-700" />
          Fully Settled
        </span>
      );
    case 'Part Paid':
      return (
        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-amber-100 text-amber-800 border border-amber-300 shadow-2xs">
          <Clock className="w-3.5 h-3.5 text-amber-700" />
          Part Paid (Balance Due)
        </span>
      );
    case 'Disputed':
      return (
        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-rose-100 text-rose-800 border border-rose-300">
          <AlertCircle className="w-3.5 h-3.5 text-rose-700" />
          Commercial Hold / Disputed
        </span>
      );
    case 'Pending':
    default:
      return (
        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-sky-100 text-sky-800 border border-sky-300">
          <Clock className="w-3.5 h-3.5 text-sky-700" />
          Payment Pending
        </span>
      );
  }
}
