"use client";

import React, { useState, useTransition } from "react";
import Link from "next/link";
import {
  Wallet,
  Search,
  CheckCircle2,
  Clock,
  AlertTriangle,
  AlertCircle,
  FileText,
  Lock,
  ArrowRight,
  ExternalLink,
  ChevronRight,
  RefreshCw,
  Info,
  Layers,
  IndianRupee,
  ShieldCheck,
  Calendar,
  Building2,
  FileCheck2,
  X,
} from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  TransactionSettlementRecord,
  SettlementStatus,
} from "@/src/types/settlement-schema";
import { format } from "date-fns";
import { cn } from "@/lib/utils";

interface SettlementLedgerTableProps {
  records: TransactionSettlementRecord[];
  onRefresh?: () => void;
  isLoading?: boolean;
}

const STATUS_TABS: Array<{ id: "All" | SettlementStatus; label: string }> = [
  { id: "All", label: "All Records" },
  { id: "Pending", label: "Pending" },
  { id: "Part Paid", label: "Part Paid" },
  { id: "Paid", label: "Paid" },
  { id: "Overdue", label: "Overdue" },
  { id: "Disputed", label: "Disputed" },
];

function formatRupee(amount: number): string {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 0,
  }).format(amount);
}

export function SettlementLedgerTable({
  records,
  onRefresh,
  isLoading = false,
}: SettlementLedgerTableProps) {
  const [activeTab, setActiveTab] = useState<"All" | SettlementStatus>("All");
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedRecord, setSelectedRecord] =
    useState<TransactionSettlementRecord | null>(null);
  const [isPending, startTransition] = useTransition();

  const handleRefresh = () => {
    startTransition(async () => {
      onRefresh?.();
    });
  };

  // Filter records by status tab & search term
  const filteredRecords = records.filter((rec) => {
    const matchesTab = activeTab === "All" || rec.status === activeTab;
    if (!matchesTab) return false;

    const term = searchTerm.toLowerCase().trim();
    if (!term) return true;

    return (
      rec.bookingReference.toLowerCase().includes(term) ||
      rec.commodityName.toLowerCase().includes(term) ||
      rec.gradeName.toLowerCase().includes(term) ||
      rec.lotNumber.toLowerCase().includes(term) ||
      rec.paymentsList.some((p) => p.referenceNumber.toLowerCase().includes(term))
    );
  });

  const getStatusBadge = (status: SettlementStatus) => {
    switch (status) {
      case "Paid":
        return (
          <Badge className="bg-emerald-50 text-emerald-700 border-emerald-200 font-bold text-xs gap-1 py-1 px-2.5">
            <CheckCircle2 className="w-3 h-3 text-[#047857]" />
            <span>Paid</span>
          </Badge>
        );
      case "Part Paid":
        return (
          <Badge className="bg-amber-50 text-amber-700 border-amber-200 font-bold text-xs gap-1 py-1 px-2.5">
            <Clock className="w-3 h-3 text-amber-600" />
            <span>Part Paid</span>
          </Badge>
        );
      case "Pending":
        return (
          <Badge className="bg-blue-50 text-blue-700 border-blue-200 font-bold text-xs gap-1 py-1 px-2.5">
            <Clock className="w-3 h-3 text-blue-600" />
            <span>Pending</span>
          </Badge>
        );
      case "Overdue":
        return (
          <Badge className="bg-rose-50 text-rose-700 border-rose-200 font-bold text-xs gap-1 py-1 px-2.5">
            <AlertTriangle className="w-3 h-3 text-rose-600" />
            <span>Overdue</span>
          </Badge>
        );
      case "Disputed":
        return (
          <Badge className="bg-purple-50 text-purple-700 border-purple-200 font-bold text-xs gap-1 py-1 px-2.5">
            <AlertCircle className="w-3 h-3 text-purple-600" />
            <span>Disputed</span>
          </Badge>
        );
    }
  };

  return (
    <div className="space-y-6">
      {/* 1. FILTER CONTROLS & SEARCH BAR */}
      <div className="bg-white rounded-2xl border border-slate-200/90 p-5 sm:p-6 shadow-xs space-y-4">
        <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
          {/* STATUS TABS */}
          <div className="flex items-center gap-1.5 overflow-x-auto pb-1 max-w-full no-scrollbar">
            {STATUS_TABS.map((tab) => {
              const count =
                tab.id === "All"
                  ? records.length
                  : records.filter((r) => r.status === tab.id).length;

              const isActive = activeTab === tab.id;

              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  className={cn(
                    "min-h-[48px] px-4 py-2 rounded-xl font-bold text-xs whitespace-nowrap transition-all flex items-center gap-2 cursor-pointer",
                    isActive
                      ? "bg-slate-900 text-white shadow-xs"
                      : "bg-slate-50 text-slate-600 hover:bg-slate-100 hover:text-slate-900 border border-slate-200/60"
                  )}
                >
                  <span>{tab.label}</span>
                  <span
                    className={cn(
                      "text-[10px] px-1.5 py-0.5 rounded-full font-mono",
                      isActive
                        ? "bg-slate-700 text-slate-200"
                        : "bg-slate-200 text-slate-700"
                    )}
                  >
                    {count}
                  </span>
                </button>
              );
            })}
          </div>

          <div className="flex items-center gap-2.5 shrink-0">
            <Button
              onClick={handleRefresh}
              variant="outline"
              size="sm"
              disabled={isPending || isLoading}
              className="h-10 border-slate-200 text-slate-700 hover:bg-slate-50 rounded-xl font-bold gap-1.5 cursor-pointer"
            >
              <RefreshCw
                className={cn("w-3.5 h-3.5", (isPending || isLoading) && "animate-spin")}
              />
              <span>Refresh Ledger</span>
            </Button>
          </div>
        </div>

        {/* SEARCH BAR */}
        <div className="relative">
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <Input
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Search by Booking ID, Commodity, Lot #, or Payment Ref..."
            className="pl-10 h-12 bg-white rounded-xl border-slate-200 focus-visible:ring-emerald-500 text-sm font-medium"
          />
        </div>
      </div>

      {/* 2. SETTLEMENT TABLE */}
      <div className="bg-white rounded-2xl border border-slate-200/90 shadow-xs overflow-hidden">
        {filteredRecords.length === 0 ? (
          <div className="py-16 px-6 text-center space-y-4">
            <div className="w-14 h-14 rounded-2xl bg-slate-100 flex items-center justify-center mx-auto text-slate-400">
              <Wallet className="w-7 h-7 stroke-[1.5]" />
            </div>
            <div className="space-y-1 max-w-md mx-auto">
              <h3 className="text-base font-bold text-slate-900">
                {searchTerm
                  ? "No matching settlement records found"
                  : `No ${activeTab !== "All" ? activeTab : "active"} payment records found.`}
              </h3>
              <p className="text-xs sm:text-sm text-slate-500 leading-relaxed">
                {searchTerm
                  ? "Try adjusting your search criteria or switch to All Records tab."
                  : "Settlement ledger entries are generated automatically from confirmed commercial bookings and dispatches."}
              </p>
            </div>
            {searchTerm && (
              <Button
                onClick={() => setSearchTerm("")}
                variant="outline"
                className="font-bold rounded-xl text-xs h-10 mt-2"
              >
                Clear Search Filter
              </Button>
            )}
          </div>
        ) : (
          <div className="overflow-x-auto">
            <Table>
              <TableHeader className="bg-slate-50/80">
                <TableRow className="hover:bg-transparent border-slate-200/80">
                  <TableHead className="font-bold text-xs text-slate-700 py-3.5 pl-6">
                    Booking Reference
                  </TableHead>
                  <TableHead className="font-bold text-xs text-slate-700">
                    Commodity & Lot
                  </TableHead>
                  <TableHead className="font-bold text-xs text-slate-700 text-right">
                    Net Receivable
                  </TableHead>
                  <TableHead className="font-bold text-xs text-slate-700 text-right">
                    Paid / Collected
                  </TableHead>
                  <TableHead className="font-bold text-xs text-slate-700 text-right">
                    Outstanding
                  </TableHead>
                  <TableHead className="font-bold text-xs text-slate-700">
                    Due Date
                  </TableHead>
                  <TableHead className="font-bold text-xs text-slate-700">
                    Status
                  </TableHead>
                  <TableHead className="text-right pr-6"></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredRecords.map((record) => {
                  const formattedDueDate = record.dueDate
                    ? format(new Date(record.dueDate), "dd MMM yyyy")
                    : "Per Contract";

                  return (
                    <TableRow
                      key={record.bookingId}
                      onClick={() => setSelectedRecord(record)}
                      className="cursor-pointer hover:bg-slate-50/80 transition-colors border-slate-100 group min-h-[56px]"
                    >
                      {/* Booking Reference */}
                      <TableCell className="py-4 pl-6 font-mono font-bold text-xs sm:text-sm text-slate-900">
                        <div className="flex items-center gap-1.5">
                          <Lock className="w-3.5 h-3.5 text-[#047857]" />
                          <span>{record.bookingReference}</span>
                        </div>
                      </TableCell>

                      {/* Commodity & Lot */}
                      <TableCell className="py-4">
                        <div className="space-y-0.5">
                          <div className="font-bold text-xs text-slate-900">
                            {record.commodityName}
                          </div>
                          <div className="text-[11px] text-slate-500">
                            {record.gradeName} • Lot #{record.lotNumber}
                          </div>
                        </div>
                      </TableCell>

                      {/* Net Receivable */}
                      <TableCell className="py-4 text-right font-black text-xs sm:text-sm text-slate-900">
                        {formatRupee(record.netReceivable)}
                      </TableCell>

                      {/* Paid / Collected */}
                      <TableCell className="py-4 text-right font-bold text-xs sm:text-sm text-[#047857]">
                        {formatRupee(record.paidAmount)}
                      </TableCell>

                      {/* Outstanding */}
                      <TableCell className="py-4 text-right font-black text-xs sm:text-sm">
                        <span
                          className={cn(
                            record.outstandingAmount > 0
                              ? record.status === "Overdue"
                                ? "text-rose-600"
                                : "text-amber-700"
                              : "text-slate-400 font-normal"
                          )}
                        >
                          {formatRupee(record.outstandingAmount)}
                        </span>
                      </TableCell>

                      {/* Due Date */}
                      <TableCell className="py-4 text-xs text-slate-600 whitespace-nowrap">
                        <div className="flex items-center gap-1.5">
                          <Calendar className="w-3.5 h-3.5 text-slate-400" />
                          <span>{formattedDueDate}</span>
                        </div>
                      </TableCell>

                      {/* Status */}
                      <TableCell className="py-4 whitespace-nowrap">
                        {getStatusBadge(record.status)}
                      </TableCell>

                      {/* Action Chevron */}
                      <TableCell className="py-4 text-right pr-6">
                        <div className="w-8 h-8 rounded-lg bg-slate-100 group-hover:bg-slate-900 group-hover:text-white flex items-center justify-center text-slate-400 transition-colors ml-auto">
                          <ChevronRight className="w-4 h-4" />
                        </div>
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          </div>
        )}
      </div>

      {/* 3. FINANCIAL BREAKDOWN SHEET DRAWER */}
      <Sheet open={!!selectedRecord} onOpenChange={(open) => !open && setSelectedRecord(null)}>
        <SheetContent className="w-full sm:max-w-xl p-0 overflow-y-auto bg-white">
          {selectedRecord && (
            <div className="p-6 sm:p-8 space-y-6">
              {/* SHEET HEADER */}
              <SheetHeader className="space-y-2 pb-4 border-b border-slate-100">
                <div className="flex items-center justify-between">
                  <Badge
                    variant="outline"
                    className="bg-emerald-50 text-[#047857] border-emerald-200 text-xs font-bold gap-1 px-2.5 py-1"
                  >
                    <Lock className="w-3 h-3" />
                    <span>Booking #{selectedRecord.bookingReference}</span>
                  </Badge>
                  {getStatusBadge(selectedRecord.status)}
                </div>

                <SheetTitle className="text-xl sm:text-2xl font-black text-slate-900 text-left">
                  Settlement & Financial Breakdown
                </SheetTitle>
                <SheetDescription className="text-xs text-slate-500 text-left">
                  Authoritative server-computed balance sheet for {selectedRecord.commodityName} (Lot #{selectedRecord.lotNumber}).
                </SheetDescription>
              </SheetHeader>

              {/* DISPUTE ALERT IF PRESENT */}
              {selectedRecord.dispute && (
                <div className="p-4 rounded-2xl bg-purple-50 border border-purple-200 text-left space-y-1.5">
                  <div className="flex items-center gap-2 text-purple-900 font-bold text-xs">
                    <AlertCircle className="w-4 h-4 text-purple-700" />
                    <span>Active Commercial Dispute Under Mediation</span>
                  </div>
                  <p className="text-xs text-purple-800 leading-relaxed">
                    <span className="font-semibold">Reason:</span> {selectedRecord.dispute.reason}
                  </p>
                  {selectedRecord.dispute.description && (
                    <p className="text-[11px] text-purple-700">
                      {selectedRecord.dispute.description}
                    </p>
                  )}
                </div>
              )}

              {/* MATHEMATICAL BREAKDOWN CARD */}
              <Card className="rounded-2xl border-slate-200/90 bg-slate-50/70 shadow-2xs overflow-hidden">
                <CardHeader className="p-5 pb-3">
                  <CardTitle className="text-xs font-bold uppercase tracking-wider text-slate-600 flex items-center gap-1.5">
                    <Layers className="w-4 h-4 text-emerald-600" />
                    <span>Commercial Math Calculation</span>
                  </CardTitle>
                </CardHeader>
                <CardContent className="p-5 pt-0 space-y-3 font-mono text-xs">
                  {/* Gross Sale Value */}
                  <div className="flex justify-between items-center py-2 border-b border-slate-200/60">
                    <span className="text-slate-600 font-sans">
                      Gross Sale Value ({selectedRecord.bookedQuantity} {selectedRecord.unitSymbol} × ₹{selectedRecord.lockedRate})
                    </span>
                    <span className="font-bold text-slate-900">
                      {formatRupee(selectedRecord.grossSaleValue)}
                    </span>
                  </div>

                  {/* Broker Commission */}
                  <div className="flex justify-between items-center py-2 border-b border-slate-200/60 text-amber-900">
                    <span className="font-sans flex items-center gap-1">
                      <span>(-) Broker Commission</span>
                      <span className="text-[10px] text-slate-400 font-mono">
                        (₹{selectedRecord.brokerCommissionRate}/{selectedRecord.unitSymbol})
                      </span>
                    </span>
                    <span className="font-bold">
                      - {formatRupee(selectedRecord.brokerCommission)}
                    </span>
                  </div>

                  {/* Other Charges */}
                  {selectedRecord.otherCharges > 0 && (
                    <div className="flex justify-between items-center py-2 border-b border-slate-200/60 text-slate-600">
                      <span className="font-sans">(-) Other Configured Deductions</span>
                      <span className="font-bold">
                        - {formatRupee(selectedRecord.otherCharges)}
                      </span>
                    </div>
                  )}

                  {/* Net Receivable */}
                  <div className="flex justify-between items-center py-3 bg-emerald-50/80 px-3 rounded-xl text-[#047857]">
                    <span className="font-sans font-black text-xs sm:text-sm">
                      (=) Net Payable to Seller
                    </span>
                    <span className="font-black text-sm sm:text-base">
                      {formatRupee(selectedRecord.netReceivable)}
                    </span>
                  </div>
                </CardContent>
              </Card>

              {/* SETTLEMENT PROGRESS BALANCE */}
              <div className="p-5 rounded-2xl bg-white border border-slate-200/90 shadow-2xs space-y-3">
                <div className="flex justify-between items-center text-xs">
                  <span className="font-bold text-slate-700">Settlement Progress</span>
                  <span className="font-bold text-[#047857]">
                    {formatRupee(selectedRecord.paidAmount)} / {formatRupee(selectedRecord.netReceivable)}
                  </span>
                </div>

                {/* Progress Bar */}
                <div className="w-full h-3 rounded-full bg-slate-100 overflow-hidden">
                  <div
                    className="h-full bg-[#059669] transition-all duration-300"
                    style={{
                      width: `${Math.min(
                        100,
                        selectedRecord.netReceivable > 0
                          ? (selectedRecord.paidAmount / selectedRecord.netReceivable) * 100
                          : 0
                      )}%`,
                    }}
                  />
                </div>

                <div className="flex justify-between items-center text-xs pt-1">
                  <span className="text-slate-500">
                    Remaining Outstanding:{" "}
                    <span className="font-bold text-slate-900">
                      {formatRupee(selectedRecord.outstandingAmount)}
                    </span>
                  </span>
                  <span className="text-slate-500">
                    Due: <span className="font-bold text-slate-700">{format(new Date(selectedRecord.dueDate), "dd MMM yyyy")}</span>
                  </span>
                </div>
              </div>

              {/* PAYMENT TRANSACTIONS LEDGER */}
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <h4 className="text-xs font-bold uppercase tracking-wider text-slate-700 flex items-center gap-1.5">
                    <FileCheck2 className="w-4 h-4 text-slate-600" />
                    <span>Disbursed Payments ({selectedRecord.paymentsList.length})</span>
                  </h4>
                </div>

                {selectedRecord.paymentsList.length === 0 ? (
                  <div className="p-5 rounded-2xl bg-slate-50 border border-dashed border-slate-200 text-center space-y-1">
                    <Clock className="w-5 h-5 text-slate-400 mx-auto" />
                    <p className="text-xs font-semibold text-slate-600">
                      No payment disbursements recorded yet.
                    </p>
                    <p className="text-[11px] text-slate-400">
                      Escrow advances and final settlement transfers will display here once verified.
                    </p>
                  </div>
                ) : (
                  <div className="space-y-2">
                    {selectedRecord.paymentsList.map((payment) => (
                      <div
                        key={payment.id}
                        className="p-3.5 bg-slate-50 rounded-xl border border-slate-200/80 flex items-center justify-between text-xs"
                      >
                        <div className="space-y-0.5">
                          <div className="font-mono font-bold text-slate-900">
                            Ref: {payment.referenceNumber}
                          </div>
                          <div className="text-[11px] text-slate-400">
                            {format(new Date(payment.confirmedAt), "dd MMM yyyy, hh:mm a")}
                          </div>
                        </div>

                        <div className="text-right space-y-0.5">
                          <div className="font-black text-sm text-[#047857]">
                            +{formatRupee(payment.amount)}
                          </div>
                          <Badge className="bg-emerald-100 text-emerald-900 text-[10px] font-bold">
                            {payment.status}
                          </Badge>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* QUICK LINKS */}
              <div className="pt-4 border-t border-slate-100 flex items-center justify-between gap-3">
                <Link
                  href={`/seller/dispatch/${selectedRecord.bookingReference}`}
                  className="w-full"
                >
                  <Button
                    variant="outline"
                    className="w-full min-h-[48px] font-bold text-xs rounded-xl border-slate-200 gap-1.5"
                  >
                    <span>View Dispatch Details</span>
                    <ArrowRight className="w-3.5 h-3.5" />
                  </Button>
                </Link>

                <Link
                  href={`/seller/deals/${selectedRecord.dealId}`}
                  className="w-full"
                >
                  <Button
                    variant="outline"
                    className="w-full min-h-[48px] font-bold text-xs rounded-xl border-slate-200 gap-1.5"
                  >
                    <span>View Deal Contract</span>
                    <FileCheck2 className="w-3.5 h-3.5" />
                  </Button>
                </Link>
              </div>
            </div>
          )}
        </SheetContent>
      </Sheet>
    </div>
  );
}
