'use client';

import React, { useState, useTransition } from 'react';
import {
  TrendingUp,
  Package,
  Truck,
  Wallet,
  Download,
  Calendar,
  AlertCircle,
  CheckCircle2,
  Clock,
  RefreshCw,
  Search,
  Filter,
  BarChart3,
  PieChart as PieIcon,
  ShieldCheck,
  ChevronRight,
  ArrowUpRight,
  IndianRupee,
  Layers,
} from 'lucide-react';
import {
  TimeRange,
  SellerAnalyticsData,
  RecentTransactionDTO,
  SalesTimeSeriesPointDTO,
} from '@/src/types/report-schema';
import { getSellerAnalyticsAction } from '@/src/server/actions/report-actions';
import { runSecurityDoubleCheckAction } from '@/src/server/actions/audit-runner-action';
import { SecurityAuditReport } from '@/src/server/utils/security-state-audit';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from '@/components/ui/dialog';
import { toast } from 'sonner';

interface SellerReportsViewProps {
  initialData: SellerAnalyticsData;
}

export function SellerReportsView({ initialData }: SellerReportsViewProps) {
  const [data, setData] = useState<SellerAnalyticsData>(initialData);
  const [selectedRange, setSelectedRange] = useState<TimeRange>(initialData.timeRange || '30d');
  const [chartMetric, setChartMetric] = useState<'volume' | 'revenue'>('volume');
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('ALL');
  const [isPending, startTransition] = useTransition();

  // Security Audit Runner State (Micro-Sprint 20.3)
  const [auditReport, setAuditReport] = useState<SecurityAuditReport | null>(null);
  const [isAuditRunning, setIsAuditRunning] = useState(false);
  const [auditModalOpen, setAuditModalOpen] = useState(false);

  const handleRunSecurityAudit = async () => {
    setIsAuditRunning(true);
    setAuditModalOpen(true);
    try {
      const res = await runSecurityDoubleCheckAction();
      if (res.success && res.data) {
        setAuditReport(res.data);
        toast.success(`Security Double-Check Complete: ${res.data.score}% Score (${res.data.passed}/${res.data.totalTests} Gates Passed)`);
      } else {
        toast.error(res.error || 'Failed to complete security double-check.');
      }
    } catch (err: any) {
      toast.error('Audit execution error: ' + (err.message || 'Unknown error'));
    } finally {
      setIsAuditRunning(false);
    }
  };

  // Switch Time Range
  const handleRangeChange = (newRange: TimeRange) => {
    setSelectedRange(newRange);
    startTransition(async () => {
      const res = await getSellerAnalyticsAction(newRange);
      if (res.success && res.data) {
        setData(res.data);
        toast.success(`Updated reports for ${getRangeLabel(newRange)}`);
      } else {
        toast.error(res.error || 'Failed to update reports data');
      }
    });
  };

  function getRangeLabel(range: TimeRange): string {
    switch (range) {
      case '7d':
        return 'Last 7 Days';
      case '30d':
        return 'Last 30 Days';
      case 'all':
        return 'All Time';
    }
  }

  // Format INR Currency
  const formatINR = (val: number): string => {
    if (val >= 10000000) {
      return `₹${(val / 10000000).toFixed(2)} Cr`;
    }
    if (val >= 100000) {
      return `₹${(val / 100000).toFixed(2)} L`;
    }
    return `₹${val.toLocaleString('en-IN')}`;
  };

  // CSV Export
  const handleExportCSV = () => {
    try {
      if (!data.recentTransactions || data.recentTransactions.length === 0) {
        toast.error('No transaction records available to export for this time range.');
        return;
      }

      const headers = [
        'Transaction Date',
        'Booking Reference',
        'Commodity',
        'Grade',
        'Lot Number',
        'Quantity',
        'Unit',
        'Locked Rate (INR)',
        'Gross Sale Value (INR)',
        'Broker Commission (INR)',
        'Net Receivable (INR)',
        'Paid Amount (INR)',
        'Outstanding Amount (INR)',
        'Settlement Status',
        'Deal Status',
      ];

      const rows = data.recentTransactions.map((tx) => [
        `"${tx.formattedDate}"`,
        `"${tx.bookingReference}"`,
        `"${tx.commodityName.replace(/"/g, '""')}"`,
        `"${tx.gradeName.replace(/"/g, '""')}"`,
        `"${tx.lotNumber}"`,
        tx.bookedQuantity,
        `"${tx.unitSymbol}"`,
        tx.lockedRate,
        tx.grossSaleValue,
        tx.brokerCommission,
        tx.netReceivable,
        tx.paidAmount,
        tx.outstandingAmount,
        `"${tx.settlementStatus}"`,
        `"${tx.dealStatus}"`,
      ]);

      const csvContent =
        'data:text/csv;charset=utf-8,' +
        [headers.join(','), ...rows.map((r) => r.join(','))].join('\n');

      const encodedUri = encodeURI(csvContent);
      const link = document.createElement('a');
      const dateStr = new Date().toISOString().split('T')[0];
      link.setAttribute('href', encodedUri);
      link.setAttribute('download', `seller-report-${selectedRange}-${dateStr}.csv`);
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);

      toast.success('Report successfully exported as CSV!');
    } catch (err: any) {
      console.error('CSV Export Error:', err);
      toast.error('Failed to export CSV: ' + (err.message || 'Unknown error'));
    }
  };

  // Filter transactions
  const filteredTransactions = (data.recentTransactions || []).filter((tx) => {
    const matchesSearch =
      tx.commodityName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      tx.gradeName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      tx.bookingReference.toLowerCase().includes(searchQuery.toLowerCase()) ||
      tx.lotNumber.toLowerCase().includes(searchQuery.toLowerCase());

    const matchesStatus =
      statusFilter === 'ALL' ||
      tx.settlementStatus.toUpperCase() === statusFilter ||
      tx.dealStatus.toUpperCase().includes(statusFilter);

    return matchesSearch && matchesStatus;
  });

  // Calculate maximum value for chart scaling
  const maxChartValue = Math.max(
    ...data.timeSeries.map((p) => (chartMetric === 'volume' ? p.volume : p.revenue)),
    10
  );

  return (
    <div className="w-full space-y-6">
      {/* HEADER CONTROLS BAR */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-white p-4 sm:p-5 rounded-2xl border border-slate-200/90 shadow-xs">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
              Reports & Visibility
            </h1>
            <Badge
              variant="outline"
              className="bg-emerald-50 text-emerald-800 border-emerald-200 text-[11px] font-bold px-2 py-0.5 inline-flex items-center gap-1"
            >
              <ShieldCheck className="w-3 h-3 text-emerald-600" />
              Zero-PII Secure Aggregation
            </Badge>
          </div>
          <p className="text-xs sm:text-sm text-slate-500 font-medium mt-0.5">
            Operational analytics, inventory turnover, net receivables, and verified sales ledger.
          </p>
        </div>

        {/* TIME RANGE SELECTOR & EXPORT BUTTON */}
        <div className="flex flex-wrap items-center gap-2 shrink-0">
          <div className="inline-flex p-1 bg-slate-100 rounded-xl border border-slate-200">
            {(['7d', '30d', 'all'] as TimeRange[]).map((range) => (
              <button
                key={range}
                onClick={() => handleRangeChange(range)}
                disabled={isPending}
                type="button"
                className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer min-h-[36px] ${
                  selectedRange === range
                    ? 'bg-white text-emerald-800 shadow-xs'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                {getRangeLabel(range)}
              </button>
            ))}
          </div>

          <Button
            onClick={handleRunSecurityAudit}
            disabled={isAuditRunning}
            variant="outline"
            className="border-emerald-300 text-emerald-800 bg-emerald-50/60 hover:bg-emerald-100 font-bold text-xs h-9 px-3.5 rounded-xl cursor-pointer inline-flex items-center gap-1.5"
          >
            <ShieldCheck className="w-3.5 h-3.5 text-emerald-700" />
            <span>{isAuditRunning ? "Auditing Gates..." : "Security Double-Check"}</span>
          </Button>

          <Button
            onClick={handleExportCSV}
            variant="outline"
            className="border-slate-300 text-slate-700 hover:bg-slate-50 font-bold text-xs h-9 px-3.5 rounded-xl cursor-pointer inline-flex items-center gap-1.5"
          >
            <Download className="w-3.5 h-3.5 text-slate-600" />
            <span>Export CSV</span>
          </Button>
        </div>
      </div>

      {/* TOP 4 KPI CARDS */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* CARD 1: NET RECEIVABLES */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs relative overflow-hidden flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
              Net Receivables
            </span>
            <div className="w-9 h-9 rounded-xl bg-emerald-50 text-emerald-700 flex items-center justify-center">
              <IndianRupee className="w-4 h-4 stroke-[2.5]" />
            </div>
          </div>
          <div className="mt-3">
            <div className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight">
              {formatINR(data.kpis.netReceivables)}
            </div>
            <div className="flex items-center gap-1.5 mt-1 text-[11px] text-slate-500 font-medium">
              <span>Gross: {formatINR(data.kpis.grossRevenue)}</span>
              <span>·</span>
              <span className="text-amber-700 font-semibold">
                Comm: {formatINR(data.kpis.totalCommission)}
              </span>
            </div>
          </div>
          <div className="mt-3 pt-3 border-t border-slate-100 flex items-center justify-between text-xs text-slate-600">
            <span>Collected</span>
            <span className="font-bold text-emerald-700">{formatINR(data.kpis.totalCollected)}</span>
          </div>
        </div>

        {/* CARD 2: OUTSTANDING & OVERDUE */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs relative overflow-hidden flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
              Outstanding Balance
            </span>
            <div
              className={`w-9 h-9 rounded-xl flex items-center justify-center ${
                data.kpis.totalOverdue > 0
                  ? 'bg-rose-50 text-rose-700'
                  : 'bg-amber-50 text-amber-700'
              }`}
            >
              <Wallet className="w-4 h-4 stroke-[2.5]" />
            </div>
          </div>
          <div className="mt-3">
            <div
              className={`text-2xl sm:text-3xl font-black tracking-tight ${
                data.kpis.totalOutstanding > 0 ? 'text-amber-700' : 'text-slate-900'
              }`}
            >
              {formatINR(data.kpis.totalOutstanding)}
            </div>
            <div className="flex items-center gap-1.5 mt-1 text-[11px] font-semibold">
              {data.kpis.totalOverdue > 0 ? (
                <span className="text-rose-600 flex items-center gap-1">
                  <AlertCircle className="w-3 h-3" />
                  {formatINR(data.kpis.totalOverdue)} Overdue
                </span>
              ) : (
                <span className="text-emerald-700 flex items-center gap-1">
                  <CheckCircle2 className="w-3 h-3" />
                  0 Overdue Invoices
                </span>
              )}
            </div>
          </div>
          <div className="mt-3 pt-3 border-t border-slate-100 flex items-center justify-between text-xs text-slate-600">
            <span>Payment Status</span>
            <span className="font-bold text-slate-800">
              {data.kpis.totalOutstanding === 0 ? 'Fully Settled' : 'Pending Clearance'}
            </span>
          </div>
        </div>

        {/* CARD 3: UNITS SOLD */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs relative overflow-hidden flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
              Volume Sold
            </span>
            <div className="w-9 h-9 rounded-xl bg-blue-50 text-blue-700 flex items-center justify-center">
              <Package className="w-4 h-4 stroke-[2.5]" />
            </div>
          </div>
          <div className="mt-3">
            <div className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight">
              {data.kpis.unitsSold.toLocaleString('en-IN')}{' '}
              <span className="text-base sm:text-lg font-bold text-slate-500">MT</span>
            </div>
            <div className="flex items-center gap-1.5 mt-1 text-[11px] text-slate-500 font-medium">
              <span>{data.kpis.totalOrdersCount} Completed Trade Orders</span>
            </div>
          </div>
          <div className="mt-3 pt-3 border-t border-slate-100 flex items-center justify-between text-xs text-slate-600">
            <span>Turnover Window</span>
            <span className="font-bold text-slate-800">{getRangeLabel(selectedRange)}</span>
          </div>
        </div>

        {/* CARD 4: ACTIVE DISPATCHES */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs relative overflow-hidden flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
              Active Dispatches
            </span>
            <div className="w-9 h-9 rounded-xl bg-purple-50 text-purple-700 flex items-center justify-center">
              <Truck className="w-4 h-4 stroke-[2.5]" />
            </div>
          </div>
          <div className="mt-3">
            <div className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight">
              {data.kpis.activeDispatchesCount}
            </div>
            <div className="flex items-center gap-1.5 mt-1 text-[11px] text-slate-500 font-medium">
              <span>{data.pipeline.inTransit} In Transit · {data.pipeline.dispatchPending} Pending</span>
            </div>
          </div>
          <div className="mt-3 pt-3 border-t border-slate-100 flex items-center justify-between text-xs text-slate-600">
            <span>Delivered & Closed</span>
            <span className="font-bold text-emerald-700">
              {data.pipeline.delivered + data.pipeline.closed} Total
            </span>
          </div>
        </div>
      </div>

      {/* MIDDLE SECTION: CHARTS GRID */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* CHART 1: SALES VOLUME & REVENUE TIME-SERIES (2 Cols) */}
        <div className="lg:col-span-2 bg-white p-5 sm:p-6 rounded-2xl border border-slate-200/90 shadow-xs flex flex-col justify-between">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-4 border-b border-slate-100">
            <div>
              <div className="flex items-center gap-2">
                <BarChart3 className="w-5 h-5 text-emerald-700" />
                <h2 className="text-base sm:text-lg font-bold text-slate-900">
                  Sales Trend ({getRangeLabel(selectedRange)})
                </h2>
              </div>
              <p className="text-xs text-slate-500 mt-0.5">
                Daily aggregated trade volume and net receivables.
              </p>
            </div>

            {/* Metric Toggle */}
            <div className="inline-flex p-0.5 bg-slate-100 rounded-lg border border-slate-200 shrink-0">
              <button
                onClick={() => setChartMetric('volume')}
                type="button"
                className={`px-3 py-1 rounded-md text-xs font-bold transition-all cursor-pointer ${
                  chartMetric === 'volume'
                    ? 'bg-white text-slate-900 shadow-2xs'
                    : 'text-slate-500 hover:text-slate-900'
                }`}
              >
                Volume (MT)
              </button>
              <button
                onClick={() => setChartMetric('revenue')}
                type="button"
                className={`px-3 py-1 rounded-md text-xs font-bold transition-all cursor-pointer ${
                  chartMetric === 'revenue'
                    ? 'bg-white text-slate-900 shadow-2xs'
                    : 'text-slate-500 hover:text-slate-900'
                }`}
              >
                Revenue (₹)
              </button>
            </div>
          </div>

          {/* TIME SERIES BAR CHART */}
          <div className="pt-6 pb-2">
            {data.timeSeries.length === 0 ? (
              <div className="h-64 flex flex-col items-center justify-center text-center p-6 bg-slate-50/60 rounded-xl border border-dashed border-slate-200">
                <BarChart3 className="w-8 h-8 text-slate-300 mb-2" />
                <p className="text-sm font-bold text-slate-700">No Sales in Selected Period</p>
                <p className="text-xs text-slate-400 mt-0.5">
                  Try selecting 'All Time' or 'Last 30 Days' to see historical trends.
                </p>
              </div>
            ) : (
              <div>
                {/* Visual SVG / HTML Bar Chart */}
                <div className="h-60 w-full flex items-end gap-1 sm:gap-2 px-1 pt-6 overflow-x-auto scrollbar-hide">
                  {data.timeSeries.map((point, idx) => {
                    const value = chartMetric === 'volume' ? point.volume : point.revenue;
                    const heightPercent =
                      maxChartValue > 0 ? Math.max(8, Math.round((value / maxChartValue) * 100)) : 8;

                    return (
                      <div
                        key={point.date || idx}
                        className="flex-1 min-w-[20px] max-w-[48px] flex flex-col items-center h-full justify-end group relative cursor-pointer"
                      >
                        {/* Tooltip on Hover */}
                        <div className="absolute -top-12 left-1/2 -translate-x-1/2 hidden group-hover:flex flex-col items-center bg-slate-900 text-white text-[10px] font-semibold py-1.5 px-2.5 rounded-lg shadow-lg z-20 pointer-events-none whitespace-nowrap">
                          <span>{point.displayDate}</span>
                          <span className="text-emerald-400 font-bold">
                            {chartMetric === 'volume'
                              ? `${point.volume.toLocaleString('en-IN')} MT`
                              : formatINR(point.revenue)}
                          </span>
                          <span className="text-[9px] text-slate-300">{point.dealsCount} deals</span>
                        </div>

                        {/* Bar */}
                        <div
                          style={{ height: `${heightPercent}%` }}
                          className={`w-full rounded-t-md transition-all duration-300 ${
                            value > 0
                              ? 'bg-gradient-to-t from-emerald-700 to-emerald-500 group-hover:from-emerald-800 group-hover:to-emerald-400'
                              : 'bg-slate-100 group-hover:bg-slate-200'
                          }`}
                        />

                        {/* Date Label */}
                        <span className="text-[9px] font-semibold text-slate-400 mt-2 truncate w-full text-center group-hover:text-slate-900">
                          {point.displayDate}
                        </span>
                      </div>
                    );
                  })}
                </div>

                <div className="flex items-center justify-between text-[11px] text-slate-400 font-semibold px-2 mt-3 pt-2 border-t border-slate-100">
                  <span>Start of Period</span>
                  <span className="text-slate-600 font-bold">
                    Total Period Volume:{' '}
                    {data.timeSeries
                      .reduce((acc, curr) => acc + curr.volume, 0)
                      .toLocaleString('en-IN')}{' '}
                    MT
                  </span>
                  <span>End of Period</span>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* CHART 2: INVENTORY DISTRIBUTION DONUT / BREAKDOWN (1 Col) */}
        <div className="bg-white p-5 sm:p-6 rounded-2xl border border-slate-200/90 shadow-xs flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between pb-4 border-b border-slate-100">
              <div className="flex items-center gap-2">
                <PieIcon className="w-5 h-5 text-emerald-700" />
                <h2 className="text-base sm:text-lg font-bold text-slate-900">
                  Inventory State
                </h2>
              </div>
              <Badge variant="secondary" className="text-[10px] font-bold">
                {data.inventory.totalQuantity.toLocaleString('en-IN')} MT Total
              </Badge>
            </div>

            {/* Segmented Donut / Arc Representation */}
            <div className="py-6 flex flex-col items-center">
              <div className="relative w-44 h-44 flex items-center justify-center">
                {/* SVG Donut */}
                <svg className="w-full h-full transform -rotate-90" viewBox="0 0 36 36">
                  {/* Background Circle */}
                  <path
                    className="text-slate-100"
                    strokeWidth="3.8"
                    stroke="currentColor"
                    fill="none"
                    d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                  />

                  {/* Available Quantity Arc */}
                  <path
                    className="text-emerald-500 transition-all duration-500"
                    strokeDasharray={`${data.inventory.availablePercent}, 100`}
                    strokeWidth="3.8"
                    strokeLinecap="round"
                    stroke="currentColor"
                    fill="none"
                    d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                  />

                  {/* Reserved Quantity Arc */}
                  <path
                    className="text-amber-500 transition-all duration-500"
                    strokeDasharray={`${data.inventory.reservedPercent}, 100`}
                    strokeDashoffset={`-${data.inventory.availablePercent}`}
                    strokeWidth="3.8"
                    strokeLinecap="round"
                    stroke="currentColor"
                    fill="none"
                    d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                  />

                  {/* Sold Quantity Arc */}
                  <path
                    className="text-blue-500 transition-all duration-500"
                    strokeDasharray={`${data.inventory.soldPercent}, 100`}
                    strokeDashoffset={`-${data.inventory.availablePercent + data.inventory.reservedPercent}`}
                    strokeWidth="3.8"
                    strokeLinecap="round"
                    stroke="currentColor"
                    fill="none"
                    d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                  />
                </svg>

                {/* Center Content */}
                <div className="absolute flex flex-col items-center justify-center text-center">
                  <span className="text-xs font-bold uppercase tracking-wider text-slate-400">
                    Stock
                  </span>
                  <span className="text-xl font-black text-slate-900 tracking-tight">
                    {data.inventory.availableQuantity.toLocaleString('en-IN')}
                  </span>
                  <span className="text-[10px] font-bold text-emerald-700">MT Available</span>
                </div>
              </div>
            </div>

            {/* Legend & Breakdown */}
            <div className="space-y-2.5 pt-2 border-t border-slate-100">
              <div className="flex items-center justify-between text-xs">
                <div className="flex items-center gap-2">
                  <span className="w-2.5 h-2.5 rounded-full bg-emerald-500" />
                  <span className="font-semibold text-slate-700">Available to Offer</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="font-bold text-slate-900">
                    {data.inventory.availableQuantity.toLocaleString('en-IN')} MT
                  </span>
                  <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-emerald-50 text-emerald-700">
                    {data.inventory.availablePercent}%
                  </span>
                </div>
              </div>

              <div className="flex items-center justify-between text-xs">
                <div className="flex items-center gap-2">
                  <span className="w-2.5 h-2.5 rounded-full bg-amber-500" />
                  <span className="font-semibold text-slate-700">Reserved in Deals</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="font-bold text-slate-900">
                    {data.inventory.reservedQuantity.toLocaleString('en-IN')} MT
                  </span>
                  <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-amber-50 text-amber-700">
                    {data.inventory.reservedPercent}%
                  </span>
                </div>
              </div>

              <div className="flex items-center justify-between text-xs">
                <div className="flex items-center gap-2">
                  <span className="w-2.5 h-2.5 rounded-full bg-blue-500" />
                  <span className="font-semibold text-slate-700">Sold & Dispatched</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="font-bold text-slate-900">
                    {data.inventory.soldQuantity.toLocaleString('en-IN')} MT
                  </span>
                  <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-blue-50 text-blue-700">
                    {data.inventory.soldPercent}%
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* PIPELINE LOGISTICS TRACKER BAR */}
      <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-xs">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2">
            <Truck className="w-4 h-4 text-emerald-700" />
            <h3 className="text-sm font-bold text-slate-900 uppercase tracking-wider">
              Logistics & Fulfillment Pipeline
            </h3>
          </div>
          <span className="text-xs text-slate-500 font-medium">Real-time order statuses</span>
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-100 flex flex-col">
            <span className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">
              Dispatch Pending
            </span>
            <span className="text-xl font-black text-slate-900 mt-1">
              {data.pipeline.dispatchPending}
            </span>
            <span className="text-[10px] text-amber-700 font-semibold mt-0.5">Awaiting Loading</span>
          </div>

          <div className="p-3.5 rounded-xl bg-purple-50/60 border border-purple-100 flex flex-col">
            <span className="text-[11px] font-bold text-purple-700 uppercase tracking-wider">
              In Transit
            </span>
            <span className="text-xl font-black text-purple-900 mt-1">
              {data.pipeline.inTransit}
            </span>
            <span className="text-[10px] text-purple-600 font-semibold mt-0.5">En Route</span>
          </div>

          <div className="p-3.5 rounded-xl bg-blue-50/60 border border-blue-100 flex flex-col">
            <span className="text-[11px] font-bold text-blue-700 uppercase tracking-wider">
              Delivered
            </span>
            <span className="text-xl font-black text-blue-900 mt-1">
              {data.pipeline.delivered}
            </span>
            <span className="text-[10px] text-blue-600 font-semibold mt-0.5">At Buyer Facility</span>
          </div>

          <div className="p-3.5 rounded-xl bg-emerald-50/60 border border-emerald-100 flex flex-col">
            <span className="text-[11px] font-bold text-emerald-700 uppercase tracking-wider">
              Settled / Closed
            </span>
            <span className="text-xl font-black text-emerald-900 mt-1">
              {data.pipeline.closed}
            </span>
            <span className="text-[10px] text-emerald-600 font-semibold mt-0.5">
              Payment Completed
            </span>
          </div>
        </div>
      </div>

      {/* BOTTOM SECTION: RECENT COMPLETED TRANSACTIONS TABLE */}
      <div className="bg-white rounded-2xl border border-slate-200/90 shadow-xs overflow-hidden">
        {/* Table Controls & Filter Bar */}
        <div className="p-5 border-b border-slate-100 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div>
            <h3 className="text-base font-bold text-slate-900">
              Recent Completed Transactions
            </h3>
            <p className="text-xs text-slate-500 font-medium mt-0.5">
              Audit-ready sales ledger with exact net receivable settlement figures.
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-2.5">
            {/* Search Input */}
            <div className="relative min-w-[200px]">
              <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search commodity, booking ref..."
                className="w-full pl-8 pr-3 py-1.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-emerald-600 focus:bg-white transition-all font-medium"
              />
            </div>

            {/* Status Filter */}
            <div className="inline-flex p-0.5 bg-slate-100 rounded-xl border border-slate-200 text-xs">
              {['ALL', 'PAID', 'PENDING', 'OVERDUE'].map((st) => (
                <button
                  key={st}
                  onClick={() => setStatusFilter(st)}
                  type="button"
                  className={`px-2.5 py-1 rounded-lg font-bold transition-all cursor-pointer ${
                    statusFilter === st
                      ? 'bg-white text-slate-900 shadow-2xs'
                      : 'text-slate-500 hover:text-slate-900'
                  }`}
                >
                  {st}
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Transactions Table (Desktop) / Cards (Mobile) */}
        {filteredTransactions.length === 0 ? (
          <div className="p-8 text-center bg-slate-50/50">
            <Layers className="w-8 h-8 text-slate-300 mx-auto mb-2" />
            <p className="text-sm font-bold text-slate-700">No transactions found</p>
            <p className="text-xs text-slate-400 mt-0.5">
              {searchQuery ? 'Try adjusting your search criteria' : 'No trade orders recorded yet.'}
            </p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse text-xs">
              <thead>
                <tr className="bg-slate-50/80 border-b border-slate-100 text-[11px] font-bold text-slate-500 uppercase tracking-wider">
                  <th className="py-3 px-4">Date & Ref</th>
                  <th className="py-3 px-4">Commodity & Grade</th>
                  <th className="py-3 px-4">Quantity</th>
                  <th className="py-3 px-4">Locked Rate</th>
                  <th className="py-3 px-4">Net Receivable</th>
                  <th className="py-3 px-4">Settlement Status</th>
                  <th className="py-3 px-4">Deal Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {filteredTransactions.map((tx) => (
                  <tr key={tx.id} className="hover:bg-slate-50/60 transition-colors">
                    {/* Date & Ref */}
                    <td className="py-3 px-4">
                      <div className="font-bold text-slate-900">{tx.formattedDate}</div>
                      <div className="text-[10px] text-slate-400 font-mono">
                        {tx.bookingReference}
                      </div>
                    </td>

                    {/* Commodity & Grade */}
                    <td className="py-3 px-4">
                      <div className="font-bold text-slate-900">{tx.commodityName}</div>
                      <div className="text-[11px] text-slate-500">{tx.gradeName}</div>
                    </td>

                    {/* Quantity */}
                    <td className="py-3 px-4 font-bold text-slate-800">
                      {tx.bookedQuantity.toLocaleString('en-IN')} {tx.unitSymbol}
                    </td>

                    {/* Locked Rate */}
                    <td className="py-3 px-4 font-medium text-slate-700">
                      ₹{tx.lockedRate.toLocaleString('en-IN')} / {tx.unitSymbol}
                    </td>

                    {/* Net Receivable */}
                    <td className="py-3 px-4">
                      <div className="font-black text-slate-900">
                        ₹{tx.netReceivable.toLocaleString('en-IN')}
                      </div>
                      <div className="text-[10px] text-slate-400">
                        Comm: ₹{tx.brokerCommission.toLocaleString('en-IN')}
                      </div>
                    </td>

                    {/* Settlement Status */}
                    <td className="py-3 px-4">
                      <Badge
                        variant="outline"
                        className={`text-[10px] font-bold px-2 py-0.5 ${
                          tx.settlementStatus === 'Paid'
                            ? 'bg-emerald-50 text-emerald-800 border-emerald-200'
                            : tx.settlementStatus === 'Overdue'
                            ? 'bg-rose-50 text-rose-800 border-rose-200'
                            : tx.settlementStatus === 'Part Paid'
                            ? 'bg-amber-50 text-amber-800 border-amber-200'
                            : 'bg-slate-100 text-slate-700 border-slate-200'
                        }`}
                      >
                        {tx.settlementStatus}
                      </Badge>
                    </td>

                    {/* Deal Status */}
                    <td className="py-3 px-4">
                      <span className="text-[11px] font-semibold text-slate-600">
                        {tx.dealStatus}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* SECURITY DOUBLE-CHECK AUDIT MODAL (Micro-Sprint 20.3) */}
      <Dialog open={auditModalOpen} onOpenChange={setAuditModalOpen}>
        <DialogContent className="sm:max-w-2xl max-h-[85vh] overflow-y-auto bg-white rounded-3xl p-6 border-slate-200">
          <DialogHeader className="border-b border-slate-100 pb-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-2xl bg-emerald-50 text-emerald-700 flex items-center justify-center shrink-0">
                <ShieldCheck className="w-5 h-5 stroke-[2.5]" />
              </div>
              <div>
                <DialogTitle className="text-lg font-black text-slate-900 tracking-tight">
                  Security & State-Transition Double Check
                </DialogTitle>
                <DialogDescription className="text-xs text-slate-500 font-medium mt-0.5">
                  Automated non-destructive assertions across DB gates, RBAC, and tenant boundaries.
                </DialogDescription>
              </div>
            </div>
          </DialogHeader>

          {isAuditRunning ? (
            <div className="py-12 flex flex-col items-center justify-center text-center space-y-3">
              <RefreshCw className="w-8 h-8 text-emerald-600 animate-spin" />
              <div className="text-sm font-bold text-slate-800">Executing 7-Gate Security Harness...</div>
              <div className="text-xs text-slate-400">Verifying state machines, RBAC, IDOR boundaries, and PII filters.</div>
            </div>
          ) : auditReport ? (
            <div className="space-y-5 pt-2">
              {/* AUDIT SCORE BANNER */}
              <div className="flex items-center justify-between p-4 rounded-2xl bg-emerald-50/80 border border-emerald-200">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-xl bg-emerald-600 text-white flex items-center justify-center font-black text-lg">
                    {auditReport.score}%
                  </div>
                  <div>
                    <div className="font-extrabold text-slate-900 text-sm">
                      {auditReport.passed === auditReport.totalTests ? "All Security Gates Passed" : "Audit Warnings Detected"}
                    </div>
                    <div className="text-xs text-emerald-800 font-medium">
                      {auditReport.passed} of {auditReport.totalTests} verification vectors satisfied
                    </div>
                  </div>
                </div>

                <Badge variant="outline" className="bg-white text-emerald-800 border-emerald-300 font-bold text-xs px-2.5 py-1">
                  100% Non-Destructive
                </Badge>
              </div>

              {/* DETAILED RESULTS LIST */}
              <div className="space-y-2.5">
                <div className="text-xs font-bold uppercase tracking-wider text-slate-400 px-1">
                  Verification Vectors
                </div>

                {auditReport.results.map((r, i) => (
                  <div
                    key={i}
                    className="p-3.5 rounded-xl border border-slate-100 bg-slate-50/70 hover:bg-slate-50 transition-colors"
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div className="space-y-1">
                        <div className="flex items-center gap-2">
                          {r.passed ? (
                            <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
                          ) : (
                            <AlertCircle className="w-4 h-4 text-rose-600 shrink-0" />
                          )}
                          <span className="font-bold text-xs text-slate-900">{r.testName}</span>
                        </div>
                        <p className="text-[11px] text-slate-600 pl-6 leading-relaxed">
                          {r.message}
                        </p>
                      </div>

                      <Badge
                        variant="outline"
                        className={`text-[10px] font-bold shrink-0 ${
                          r.passed
                            ? "bg-emerald-100/70 text-emerald-800 border-emerald-200"
                            : "bg-rose-100 text-rose-800 border-rose-200"
                        }`}
                      >
                        {r.passed ? "PASS" : "FAIL"}
                      </Badge>
                    </div>
                  </div>
                ))}
              </div>

              <div className="pt-3 border-t border-slate-100 flex items-center justify-between">
                <span className="text-[11px] text-slate-400">
                  Last verified: {new Date(auditReport.timestamp).toLocaleTimeString()}
                </span>
                <Button
                  onClick={handleRunSecurityAudit}
                  size="sm"
                  className="bg-slate-900 hover:bg-slate-800 text-white font-bold text-xs rounded-xl"
                >
                  <RefreshCw className="w-3.5 h-3.5 mr-1.5" />
                  Re-Run Audit
                </Button>
              </div>
            </div>
          ) : null}
        </DialogContent>
      </Dialog>
    </div>
  );
}
