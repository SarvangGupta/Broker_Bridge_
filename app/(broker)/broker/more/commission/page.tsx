import React from 'react';
import Link from 'next/link';
import {
  ArrowLeft,
  Zap,
  TrendingUp,
  Clock,
  CheckCircle2,
  AlertCircle,
  FileSpreadsheet,
  Building,
  Building2,
  ChevronRight,
  Sparkles,
  Coins,
} from 'lucide-react';
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
import { getBrokerCommissionLedgerAction } from '@/src/server/actions/broker-commission-actions';

export const dynamic = 'force-dynamic';

export default async function BrokerCommissionPage() {
  const res = await getBrokerCommissionLedgerAction();

  if (!res.success || !res.data) {
    return (
      <div className="p-4 sm:p-6 lg:p-8 space-y-6 w-full max-w-7xl mx-auto overflow-x-hidden">
        <Link
          href="/broker/more"
          className="inline-flex items-center gap-1.5 text-xs font-semibold text-teal-700 hover:text-teal-900 transition-colors"
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
              <h3 className="font-bold text-slate-900 text-base">Unable to Load Commission Ledger</h3>
              <p className="text-xs sm:text-sm text-slate-600">
                {res.error || 'You do not have permission to access the commission ledger.'}
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

  const { summary, records } = res.data;

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
              <Zap className="w-7 h-7 text-[#0D9488]" />
              Commission & Revenue Ledger
            </h1>
            <Badge className="bg-[#0D9488] text-white font-mono text-xs px-2.5 py-0.5">
              SPRINT 28.2
            </Badge>
          </div>
          <p className="text-xs sm:text-sm text-slate-500 mt-1">
            Read-only historical commission ledger locked during deal finalization.
          </p>
        </div>
      </div>

      {/* TASK 2: KPI SUMMARY GRID (3 CARDS) */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 lg:gap-6">
        {/* CARD 1: TOTAL EXPECTED COMMISSION */}
        <Card className="border-slate-200/80 bg-white shadow-xs relative overflow-hidden flex flex-col justify-between">
          <div className="absolute top-0 left-0 w-1.5 h-full bg-blue-600" />
          <CardHeader className="pb-2 pt-4 px-4 sm:px-5">
            <div className="flex items-center justify-between">
              <span className="text-[10px] font-bold uppercase tracking-wider text-blue-700 flex items-center gap-1">
                <TrendingUp className="w-3.5 h-3.5" />
                Total Expected Revenue
              </span>
              <Badge variant="outline" className="text-[10px] border-blue-200 text-blue-800 bg-blue-50">
                {summary.totalDealsCount} Deal{summary.totalDealsCount === 1 ? '' : 's'}
              </Badge>
            </div>
            <CardTitle className="text-2xl sm:text-3xl font-bold text-slate-900 font-mono mt-1">
              ₹{summary.totalExpectedCommission.toLocaleString('en-IN')}
            </CardTitle>
            <CardDescription className="text-xs text-slate-500">
              Total brokerage earned across all finalized contracts
            </CardDescription>
          </CardHeader>
          <CardContent className="px-4 sm:px-5 pb-4 pt-0 text-xs border-t border-slate-100 mt-2">
            <div className="pt-2 text-[11px] text-slate-500 flex justify-between items-center">
              <span>Historical Locked Rates:</span>
              <span className="font-semibold text-slate-700">100% Immutable</span>
            </div>
          </CardContent>
        </Card>

        {/* CARD 2: TOTAL COLLECTED REVENUE (PROMINENTLY HIGHLIGHTED IN ELECTRIC TEAL) */}
        <Card className="border-2 border-teal-500/80 bg-gradient-to-br from-slate-950 via-[#0D9488] to-teal-900 text-white shadow-md relative overflow-hidden flex flex-col justify-between">
          <div className="absolute top-0 right-0 p-3 opacity-10 pointer-events-none">
            <Coins className="w-24 h-24 text-teal-200" />
          </div>
          <CardHeader className="pb-2 pt-4 px-4 sm:px-5 relative z-10">
            <div className="flex items-center justify-between">
              <span className="text-[10px] font-bold uppercase tracking-wider text-teal-200 flex items-center gap-1.5">
                <CheckCircle2 className="w-3.5 h-3.5 text-teal-300" />
                Collected Revenue
              </span>
              <Badge className="bg-teal-300 text-slate-950 font-mono text-[10px] font-extrabold border-none px-2 py-0.5">
                DISBURSED
              </Badge>
            </div>
            <CardTitle className="text-2xl sm:text-3xl font-extrabold text-white font-mono mt-1 tracking-tight">
              ₹{summary.totalCollectedCommission.toLocaleString('en-IN')}
            </CardTitle>
            <CardDescription className="text-xs text-teal-100/80">
              Actual collected payouts & buyer escrow releases
            </CardDescription>
          </CardHeader>
          <CardContent className="px-4 sm:px-5 pb-4 pt-0 text-xs border-t border-teal-400/30 mt-2 relative z-10">
            <div className="pt-2 text-[11px] text-teal-100/90 flex justify-between items-center">
              <span>Fully Settled Deals:</span>
              <span className="font-bold text-white">{summary.settledDealsCount} of {summary.totalDealsCount}</span>
            </div>
          </CardContent>
        </Card>

        {/* CARD 3: PENDING COMMISSION */}
        <Card className="border-slate-200/80 bg-white shadow-xs relative overflow-hidden flex flex-col justify-between">
          <div className="absolute top-0 left-0 w-1.5 h-full bg-amber-500" />
          <CardHeader className="pb-2 pt-4 px-4 sm:px-5">
            <div className="flex items-center justify-between">
              <span className="text-[10px] font-bold uppercase tracking-wider text-amber-700 flex items-center gap-1">
                <Clock className="w-3.5 h-3.5" />
                Pending Revenue
              </span>
              <Badge variant="outline" className="text-[10px] border-amber-200 text-amber-800 bg-amber-50">
                Awaiting Payment
              </Badge>
            </div>
            <CardTitle className="text-2xl sm:text-3xl font-bold text-slate-900 font-mono mt-1">
              ₹{summary.totalPendingCommission.toLocaleString('en-IN')}
            </CardTitle>
            <CardDescription className="text-xs text-slate-500">
              Remaining margin balance to be collected
            </CardDescription>
          </CardHeader>
          <CardContent className="px-4 sm:px-5 pb-4 pt-0 text-xs border-t border-slate-100 mt-2">
            <div className="pt-2 text-[11px] text-slate-500 flex justify-between items-center">
              <span>Collection Status:</span>
              <span className={`font-semibold ${summary.totalPendingCommission > 0 ? 'text-amber-700' : 'text-emerald-700'}`}>
                {summary.totalPendingCommission > 0 ? 'Active Orders Open' : '100% Collected'}
              </span>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* TASK 2 & 3: DEAL BREAKDOWN SECTION */}
      <Card className="border-slate-200/80 bg-white shadow-xs">
        <CardHeader className="pb-3 border-b border-slate-100 flex flex-row items-center justify-between">
          <div>
            <CardTitle className="text-base font-bold flex items-center gap-2 text-slate-900">
              <FileSpreadsheet className="w-4 h-4 text-[#0D9488]" />
              Deal Commission Breakdown
            </CardTitle>
            <CardDescription className="text-xs">
              Locked buyer markups and seller deductions per finalized contract.
            </CardDescription>
          </div>

          <Badge variant="outline" className="font-mono text-xs text-slate-600 border-slate-200">
            {records.length} Contract{records.length === 1 ? '' : 's'}
          </Badge>
        </CardHeader>
        <CardContent className="p-0">
          {records.length === 0 ? (
            <div className="p-8 text-center space-y-3">
              <div className="mx-auto w-10 h-10 rounded-full bg-slate-100 flex items-center justify-center text-slate-400">
                <Coins className="w-5 h-5" />
              </div>
              <div className="space-y-1 max-w-sm mx-auto">
                <p className="text-xs font-bold text-slate-700">No Finalized Commission Records</p>
                <p className="text-[11px] text-slate-500">
                  When you finalize deals with buyers and sellers, locked commission spreads will automatically populate here.
                </p>
              </div>
            </div>
          ) : (
            <>
              {/* TASK 3: MOBILE VIEWPORT STACKED CARDS (SHOWS ON 360PX - 768PX) */}
              <div className="block md:hidden divide-y divide-slate-100">
                {records.map((r) => (
                  <div key={r.bookingId} className="p-4 space-y-3">
                    <div className="flex items-center justify-between gap-2">
                      <div className="flex items-center gap-2">
                        <Badge className="bg-[#0D9488] text-white font-mono text-[11px] px-2 py-0.5">
                          {r.bookingReference}
                        </Badge>
                        <span className="text-[11px] text-slate-400">
                          {new Date(r.createdAt).toLocaleDateString('en-IN', {
                            day: '2-digit',
                            month: 'short',
                          })}
                        </span>
                      </div>
                      <Badge
                        className={`text-[10px] font-bold ${
                          r.commissionStatus === 'Settled'
                            ? 'bg-emerald-100 text-emerald-800 border-emerald-300'
                            : r.commissionStatus === 'Partially Collected'
                            ? 'bg-amber-100 text-amber-800 border-amber-300'
                            : 'bg-slate-100 text-slate-800 border-slate-300'
                        }`}
                      >
                        {r.commissionStatus}
                      </Badge>
                    </div>

                    <div>
                      <h4 className="font-bold text-slate-900 text-sm">{r.commodityName}</h4>
                      <p className="text-xs text-slate-500">
                        {r.gradeName || 'Standard Grade'} • Lot #{r.lotNumber} ({r.bookedQuantity} {r.unitSymbol})
                      </p>
                    </div>

                    {/* Margin Breakdown Card */}
                    <div className="p-3 rounded-lg bg-slate-50 border border-slate-200/70 text-xs space-y-1">
                      <div className="flex justify-between items-center text-slate-600">
                        <span>Margin Spread Breakdown:</span>
                        <span className="font-mono font-bold text-slate-900">
                          ₹{r.totalMarginPerMT.toLocaleString('en-IN')} / {r.unitSymbol}
                        </span>
                      </div>
                      <div className="flex justify-between items-center text-[11px] text-slate-500">
                        <span>Buyer Markup / Seller Ded:</span>
                        <span>₹{r.buyerMarkup} Buyer + ₹{r.sellerDeduction} Seller</span>
                      </div>
                    </div>

                    {/* Math totals */}
                    <div className="grid grid-cols-2 gap-2 text-xs pt-1">
                      <div>
                        <span className="text-slate-500 block text-[11px]">Expected Total</span>
                        <span className="font-mono font-bold text-slate-900 text-sm">
                          ₹{r.expectedCommission.toLocaleString('en-IN')}
                        </span>
                      </div>
                      <div>
                        <span className="text-slate-500 block text-[11px]">Collected</span>
                        <span className="font-mono font-bold text-emerald-700 text-sm">
                          ₹{r.collectedCommission.toLocaleString('en-IN')}
                        </span>
                      </div>
                    </div>

                    <div className="pt-1">
                      <Link href={`/broker/orders/${r.bookingId}`}>
                        <Button
                          variant="outline"
                          size="sm"
                          className="w-full text-xs font-semibold h-8 border-slate-200 text-teal-800 hover:bg-teal-50"
                        >
                          View Order Settlement
                          <ChevronRight className="w-3.5 h-3.5 ml-1" />
                        </Button>
                      </Link>
                    </div>
                  </div>
                ))}
              </div>

              {/* TASK 3: DESKTOP SHADCN TABLE (MD+ BREAKPOINTS) */}
              <div className="hidden md:block overflow-x-auto">
                <Table>
                  <TableHeader className="bg-slate-50/80 text-[11px]">
                    <TableRow>
                      <TableHead className="font-bold text-slate-700">Booking & Date</TableHead>
                      <TableHead className="font-bold text-slate-700">Commodity & Quantity</TableHead>
                      <TableHead className="font-bold text-slate-700">Margin Breakdown</TableHead>
                      <TableHead className="font-bold text-slate-700 text-right">Expected (₹)</TableHead>
                      <TableHead className="font-bold text-slate-700 text-right">Collected (₹)</TableHead>
                      <TableHead className="font-bold text-slate-700 text-center">Status</TableHead>
                      <TableHead className="font-bold text-slate-700 text-right">Action</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody className="text-xs font-medium">
                    {records.map((r) => (
                      <TableRow key={r.bookingId} className="hover:bg-slate-50/60">
                        <TableCell>
                          <div className="space-y-0.5">
                            <span className="font-mono font-bold text-teal-800 block">
                              {r.bookingReference}
                            </span>
                            <span className="text-[11px] text-slate-500">
                              {new Date(r.createdAt).toLocaleDateString('en-IN', {
                                day: '2-digit',
                                month: 'short',
                                year: 'numeric',
                              })}
                            </span>
                          </div>
                        </TableCell>
                        <TableCell>
                          <div className="space-y-0.5">
                            <span className="font-bold text-slate-900 block">{r.commodityName}</span>
                            <span className="text-[11px] text-slate-500">
                              {r.bookedQuantity} {r.unitSymbol} • Lot #{r.lotNumber}
                            </span>
                          </div>
                        </TableCell>
                        <TableCell>
                          <div className="space-y-0.5">
                            <span className="font-mono font-bold text-slate-900 block">
                              ₹{r.totalMarginPerMT.toLocaleString('en-IN')} / {r.unitSymbol}
                            </span>
                            <span className="text-[10px] text-slate-500">
                              ₹{r.buyerMarkup} Buyer + ₹{r.sellerDeduction} Seller
                            </span>
                          </div>
                        </TableCell>
                        <TableCell className="text-right font-mono font-bold text-slate-900 whitespace-nowrap">
                          ₹{r.expectedCommission.toLocaleString('en-IN')}
                        </TableCell>
                        <TableCell className="text-right font-mono font-bold text-emerald-700 whitespace-nowrap">
                          ₹{r.collectedCommission.toLocaleString('en-IN')}
                        </TableCell>
                        <TableCell className="text-center">
                          <Badge
                            className={`text-[10px] font-bold ${
                              r.commissionStatus === 'Settled'
                                ? 'bg-emerald-100 text-emerald-800 border-emerald-300'
                                : r.commissionStatus === 'Partially Collected'
                                ? 'bg-amber-100 text-amber-800 border-amber-300'
                                : 'bg-slate-100 text-slate-800 border-slate-300'
                            }`}
                          >
                            {r.commissionStatus}
                          </Badge>
                        </TableCell>
                        <TableCell className="text-right">
                          <Link href={`/broker/orders/${r.bookingId}`}>
                            <Button
                              variant="ghost"
                              size="sm"
                              className="text-xs text-teal-700 hover:text-teal-900 hover:bg-teal-50 h-8 px-2 font-semibold"
                            >
                              Details
                              <ChevronRight className="w-3.5 h-3.5 ml-1" />
                            </Button>
                          </Link>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>
            </>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
