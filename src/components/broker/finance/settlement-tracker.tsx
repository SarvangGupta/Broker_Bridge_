'use client';

import React, { useState, useEffect, useTransition } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import {
  Wallet,
  Building,
  Building2,
  Zap,
  PlusCircle,
  RefreshCw,
  CheckCircle2,
  Clock,
  ArrowUpRight,
  ArrowDownLeft,
  FileSpreadsheet,
  AlertCircle,
  DollarSign,
} from 'lucide-react';
import {
  getBrokerFinancialLedgerAction,
  BrokerFinancialLedgerPayload,
  PaymentRecordItem,
} from '@/src/server/actions/broker-finance-actions';
import { LogPaymentModal } from './log-payment-modal';

interface SettlementTrackerProps {
  bookingIdOrReference: string;
  initialData?: BrokerFinancialLedgerPayload;
}

export function SettlementTracker({
  bookingIdOrReference,
  initialData,
}: SettlementTrackerProps) {
  const [ledger, setLedger] = useState<BrokerFinancialLedgerPayload | null>(
    initialData || null
  );
  const [isLoading, setIsLoading] = useState<boolean>(!initialData);
  const [error, setError] = useState<string | null>(null);
  const [isModalOpen, setIsModalOpen] = useState<boolean>(false);
  const [isPending, startTransition] = useTransition();

  const fetchLedger = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const res = await getBrokerFinancialLedgerAction(bookingIdOrReference);
      if (res.success && res.data) {
        setLedger(res.data);
      } else {
        setError(res.error || 'Failed to fetch financial ledger');
      }
    } catch (err: any) {
      setError(err.message || 'Error loading financial ledger');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    if (!initialData) {
      fetchLedger();
    }
  }, [bookingIdOrReference]);

  const handlePaymentLogged = () => {
    startTransition(() => {
      fetchLedger();
    });
  };

  if (isLoading) {
    return (
      <Card className="border-slate-200/80 bg-white shadow-xs p-6">
        <div className="flex items-center justify-center py-8 space-x-3 text-slate-500">
          <RefreshCw className="w-5 h-5 animate-spin text-[#0D9488]" />
          <span className="text-xs font-semibold">Calculating Financial Settlement Ledger...</span>
        </div>
      </Card>
    );
  }

  if (error || !ledger) {
    return (
      <Card className="border-red-200 bg-red-50/50 p-6">
        <div className="flex flex-col items-center justify-center text-center space-y-3">
          <AlertCircle className="w-8 h-8 text-red-500" />
          <div>
            <h4 className="font-bold text-slate-900 text-sm">Financial Ledger Error</h4>
            <p className="text-xs text-slate-600 max-w-md mt-0.5">{error || 'Ledger data unavailable.'}</p>
          </div>
          <Button
            onClick={fetchLedger}
            variant="outline"
            className="border-slate-300 text-xs font-semibold h-8 px-3"
          >
            <RefreshCw className="w-3.5 h-3.5 mr-1.5" />
            Retry
          </Button>
        </div>
      </Card>
    );
  }

  const {
    buyerPayable,
    buyerPaid,
    buyerOutstanding,
    sellerSettlement,
    sellerPaid,
    sellerOutstanding,
    brokerCommission,
    brokerSpreadPerMT,
    baseRate,
    buyerMarkup,
    sellerDeduction,
    unitSymbol,
    quantity,
    settlementStatus,
    buyerCompanyName,
    sellerCompanyName,
    payments,
    bookingId,
    dealId,
  } = ledger;

  return (
    <div className="space-y-6 w-full max-w-7xl mx-auto overflow-x-hidden">
      {/* SECTION HEADER & LOG BUTTON */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 bg-white p-4 rounded-xl border border-slate-200/80 shadow-xs">
        <div className="flex items-center gap-2.5">
          <div className="w-10 h-10 rounded-lg bg-[#0D9488]/10 flex items-center justify-center text-[#0D9488] shrink-0">
            <Wallet className="w-5 h-5" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h2 className="text-lg font-bold text-slate-900 tracking-tight">
                Settlement & Financial Ledger
              </h2>
              <Badge
                className={`text-[11px] font-bold px-2 py-0.5 ${
                  settlementStatus === 'Paid'
                    ? 'bg-emerald-100 text-emerald-800 border-emerald-300'
                    : settlementStatus === 'Part Paid'
                    ? 'bg-amber-100 text-amber-800 border-amber-300'
                    : 'bg-slate-100 text-slate-800 border-slate-300'
                }`}
              >
                {settlementStatus}
              </Badge>
            </div>
            <p className="text-xs text-slate-500">
              Immutable contract valuation, escrow balances, and transaction history ({quantity} {unitSymbol}).
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 self-start sm:self-auto">
          <Button
            onClick={fetchLedger}
            variant="outline"
            size="sm"
            disabled={isPending}
            className="border-slate-200 text-slate-600 hover:bg-slate-50 text-xs h-9 px-3"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${isPending ? 'animate-spin' : ''}`} />
          </Button>
          <Button
            onClick={() => setIsModalOpen(true)}
            className="bg-[#0D9488] hover:bg-teal-700 text-white font-semibold text-xs h-9 px-4 cursor-pointer shadow-xs"
          >
            <PlusCircle className="w-4 h-4 mr-1.5" />
            Log Payment
          </Button>
        </div>
      </div>

      {/* 3-COLUMN SUMMARY CARDS (STACKS VERTICALLY ON 360PX MOBILE) */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 lg:gap-6">
        {/* CARD 1: BUYER PAYABLE */}
        <Card className="border-slate-200/80 bg-white shadow-xs relative overflow-hidden flex flex-col justify-between">
          <div className="absolute top-0 left-0 w-1.5 h-full bg-blue-600" />
          <CardHeader className="pb-2 pt-4 px-4 sm:px-5">
            <div className="flex items-start justify-between gap-2">
              <span className="text-[10px] font-bold uppercase tracking-wider text-blue-700 flex items-center gap-1">
                <Building className="w-3.5 h-3.5" />
                Buyer Payable
              </span>
              <Badge variant="outline" className="text-[10px] border-blue-200 text-blue-800 bg-blue-50">
                Landed Rate: ₹{(baseRate + buyerMarkup).toLocaleString('en-IN')}/{unitSymbol}
              </Badge>
            </div>
            <CardTitle className="text-2xl font-bold text-slate-900 font-mono mt-1">
              ₹{buyerPayable.toLocaleString('en-IN')}
            </CardTitle>
            <CardDescription className="text-xs text-slate-500 truncate">
              {buyerCompanyName}
            </CardDescription>
          </CardHeader>
          <CardContent className="px-4 sm:px-5 pb-4 pt-0 text-xs border-t border-slate-100 mt-2">
            <div className="grid grid-cols-2 gap-2 pt-3">
              <div>
                <span className="text-slate-500 block text-[11px]">Collected / Paid</span>
                <span className="font-mono font-bold text-emerald-700 text-xs">
                  ₹{buyerPaid.toLocaleString('en-IN')}
                </span>
              </div>
              <div>
                <span className="text-slate-500 block text-[11px]">Outstanding Due</span>
                <span className={`font-mono font-bold text-xs ${buyerOutstanding > 0 ? 'text-amber-700' : 'text-slate-700'}`}>
                  ₹{buyerOutstanding.toLocaleString('en-IN')}
                </span>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* CARD 2: SELLER SETTLEMENT */}
        <Card className="border-slate-200/80 bg-white shadow-xs relative overflow-hidden flex flex-col justify-between">
          <div className="absolute top-0 left-0 w-1.5 h-full bg-teal-600" />
          <CardHeader className="pb-2 pt-4 px-4 sm:px-5">
            <div className="flex items-start justify-between gap-2">
              <span className="text-[10px] font-bold uppercase tracking-wider text-teal-700 flex items-center gap-1">
                <Building2 className="w-3.5 h-3.5" />
                Seller Settlement
              </span>
              <Badge variant="outline" className="text-[10px] border-teal-200 text-teal-800 bg-teal-50">
                Net Rate: ₹{Math.max(0, baseRate - sellerDeduction).toLocaleString('en-IN')}/{unitSymbol}
              </Badge>
            </div>
            <CardTitle className="text-2xl font-bold text-slate-900 font-mono mt-1">
              ₹{sellerSettlement.toLocaleString('en-IN')}
            </CardTitle>
            <CardDescription className="text-xs text-slate-500 truncate">
              {sellerCompanyName}
            </CardDescription>
          </CardHeader>
          <CardContent className="px-4 sm:px-5 pb-4 pt-0 text-xs border-t border-slate-100 mt-2">
            <div className="grid grid-cols-2 gap-2 pt-3">
              <div>
                <span className="text-slate-500 block text-[11px]">Transferred</span>
                <span className="font-mono font-bold text-emerald-700 text-xs">
                  ₹{sellerPaid.toLocaleString('en-IN')}
                </span>
              </div>
              <div>
                <span className="text-slate-500 block text-[11px]">Remaining Pay</span>
                <span className={`font-mono font-bold text-xs ${sellerOutstanding > 0 ? 'text-slate-700' : 'text-emerald-700'}`}>
                  ₹{sellerOutstanding.toLocaleString('en-IN')}
                </span>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* CARD 3: BROKER MARGIN (PROMINENTLY HIGHLIGHTED IN ELECTRIC TEAL) */}
        <Card className="border-2 border-teal-500/80 bg-gradient-to-br from-slate-950 via-teal-950 to-slate-900 text-white shadow-md relative overflow-hidden flex flex-col justify-between">
          <div className="absolute top-0 right-0 p-3 opacity-10 pointer-events-none">
            <Zap className="w-24 h-24 text-teal-300" />
          </div>
          <CardHeader className="pb-2 pt-4 px-4 sm:px-5 relative z-10">
            <div className="flex items-center justify-between gap-2">
              <span className="text-[10px] font-bold uppercase tracking-wider text-teal-300 flex items-center gap-1.5">
                <Zap className="w-3.5 h-3.5 text-teal-400 animate-pulse" />
                Broker Commission Spread
              </span>
              <Badge className="bg-teal-500 text-slate-950 font-mono text-[10px] font-extrabold px-2 py-0.5 border-none">
                LOCKED SPREAD
              </Badge>
            </div>
            <CardTitle className="text-3xl font-extrabold text-teal-300 font-mono mt-1 tracking-tight">
              ₹{brokerCommission.toLocaleString('en-IN')}
            </CardTitle>
            <CardDescription className="text-xs text-teal-100/70">
              Total margin earned across {quantity} {unitSymbol}
            </CardDescription>
          </CardHeader>
          <CardContent className="px-4 sm:px-5 pb-4 pt-0 text-xs border-t border-teal-500/30 mt-2 relative z-10">
            <div className="pt-3 space-y-1">
              <div className="flex justify-between items-center text-[11px]">
                <span className="text-slate-300">Spread per {unitSymbol}:</span>
                <span className="font-mono font-bold text-teal-200">
                  ₹{brokerSpreadPerMT.toLocaleString('en-IN')} / {unitSymbol}
                </span>
              </div>
              <div className="flex justify-between items-center text-[10px] text-slate-400">
                <span>Base Rate:</span>
                <span className="font-mono">₹{baseRate.toLocaleString('en-IN')} / {unitSymbol}</span>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* READ-ONLY TRANSACTIONS TABLE */}
      <Card className="border-slate-200/80 bg-white shadow-xs">
        <CardHeader className="pb-3 border-b border-slate-100 flex flex-row items-center justify-between">
          <div>
            <CardTitle className="text-base font-bold flex items-center gap-2 text-slate-900">
              <FileSpreadsheet className="w-4 h-4 text-[#0D9488]" />
              Recorded Payment Transactions
            </CardTitle>
            <CardDescription className="text-xs">
              Audit log of payments received from Buyer and settlements disbursed to Seller.
            </CardDescription>
          </div>

          <Badge variant="outline" className="font-mono text-xs text-slate-600 border-slate-200">
            {payments.length} Transaction{payments.length === 1 ? '' : 's'}
          </Badge>
        </CardHeader>
        <CardContent className="p-0">
          {payments.length === 0 ? (
            <div className="p-8 text-center space-y-3">
              <div className="mx-auto w-10 h-10 rounded-full bg-slate-100 flex items-center justify-center text-slate-400">
                <DollarSign className="w-5 h-5" />
              </div>
              <div className="space-y-1">
                <p className="text-xs font-bold text-slate-700">No Payment Transactions Recorded</p>
                <p className="text-[11px] text-slate-500 max-w-sm mx-auto">
                  Use the "Log Payment" button to record a bank transfer UTR or buyer payment entry.
                </p>
              </div>
              <Button
                onClick={() => setIsModalOpen(true)}
                size="sm"
                className="bg-[#0D9488] hover:bg-teal-700 text-white text-xs font-semibold h-8 px-3"
              >
                <PlusCircle className="w-3.5 h-3.5 mr-1" />
                Log First Payment
              </Button>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader className="bg-slate-50/80 text-[11px]">
                  <TableRow>
                    <TableHead className="font-bold text-slate-700">Date</TableHead>
                    <TableHead className="font-bold text-slate-700">Reference / UTR</TableHead>
                    <TableHead className="font-bold text-slate-700">Direction</TableHead>
                    <TableHead className="font-bold text-slate-700 text-right">Amount (₹)</TableHead>
                    <TableHead className="font-bold text-slate-700 text-center">Status</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody className="text-xs font-medium">
                  {payments.map((p) => {
                    const isSellerDisbursement = p.direction.toLowerCase().includes('seller');
                    return (
                      <TableRow key={p.id} className="hover:bg-slate-50/60">
                        <TableCell className="text-slate-600 whitespace-nowrap">
                          {new Date(p.createdAt).toLocaleDateString('en-IN', {
                            day: '2-digit',
                            month: 'short',
                            year: 'numeric',
                          })}
                        </TableCell>
                        <TableCell className="font-mono font-bold text-slate-900 whitespace-nowrap">
                          {p.referenceNumber}
                        </TableCell>
                        <TableCell>
                          <span
                            className={`inline-flex items-center gap-1 text-[11px] font-semibold px-2 py-0.5 rounded-md ${
                              isSellerDisbursement
                                ? 'bg-amber-50 text-amber-800 border border-amber-200/60'
                                : 'bg-emerald-50 text-emerald-800 border border-emerald-200/60'
                            }`}
                          >
                            {isSellerDisbursement ? (
                              <ArrowUpRight className="w-3 h-3 text-amber-600" />
                            ) : (
                              <ArrowDownLeft className="w-3 h-3 text-emerald-600" />
                            )}
                            {p.direction}
                          </span>
                        </TableCell>
                        <TableCell className="text-right font-mono font-bold text-slate-900 whitespace-nowrap">
                          ₹{p.amount.toLocaleString('en-IN')}
                        </TableCell>
                        <TableCell className="text-center">
                          <span className="inline-flex items-center gap-1 text-[11px] text-emerald-700 font-semibold bg-emerald-100/80 px-2 py-0.5 rounded-full">
                            <CheckCircle2 className="w-3 h-3" />
                            {p.status}
                          </span>
                        </TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>

      {/* MODAL DIALOG FOR LOGGING PAYMENTS */}
      <LogPaymentModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        bookingId={bookingId}
        dealId={dealId}
        onSuccess={handlePaymentLogged}
      />
    </div>
  );
}
