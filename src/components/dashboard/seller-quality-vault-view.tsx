"use client";

import React, { useState, useMemo } from "react";
import Link from "next/link";
import {
  FlaskConical,
  FileX,
  Search,
  Package,
  ArrowRight,
} from "lucide-react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { SellerGlobalLabReportItem } from "@/src/server/actions/lab-actions";
import { GlobalLabReportCard } from "@/src/components/dashboard/global-lab-report-card";
import { cn } from "@/lib/utils";

interface SellerQualityVaultViewProps {
  initialReports: SellerGlobalLabReportItem[];
  onNavigateToInventory?: () => void;
}

export function SellerQualityVaultView({
  initialReports = [],
  onNavigateToInventory,
}: SellerQualityVaultViewProps) {
  const [searchTerm, setSearchTerm] = useState("");
  const [statusFilter, setStatusFilter] = useState<string>("ALL");

  // Filtered reports
  const filteredReports = useMemo(() => {
    return initialReports.filter((report) => {
      const matchesSearch =
        !searchTerm.trim() ||
        (report.commodityName || "").toLowerCase().includes(searchTerm.toLowerCase()) ||
        (report.laboratoryName || "").toLowerCase().includes(searchTerm.toLowerCase()) ||
        (report.reportNumber || "").toLowerCase().includes(searchTerm.toLowerCase()) ||
        (report.lotNumber || "").toLowerCase().includes(searchTerm.toLowerCase()) ||
        (report.sampleId || "").toLowerCase().includes(searchTerm.toLowerCase());

      if (!matchesSearch) return false;

      if (statusFilter === "ALL") return true;
      if (statusFilter === "VERIFIED") return report.effectiveStatus === "Verified";
      if (statusFilter === "UNDER_REVIEW")
        return report.effectiveStatus === "Under Review" || report.effectiveStatus === "Report Uploaded";
      if (statusFilter === "EXPIRED") return report.effectiveStatus === "Expired";
      if (statusFilter === "NOT_REQUIRED") return report.effectiveStatus === "Not Required";

      return true;
    });
  }, [initialReports, searchTerm, statusFilter]);

  return (
    <div className="space-y-6 animate-in fade-in-50 duration-200">
      {/* Header Banner */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-white p-5 sm:p-6 rounded-2xl border border-slate-200/90 shadow-xs">
        <div>
          <h1 className="text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight">
            Quality & Lab Reports
          </h1>
        </div>

        {onNavigateToInventory ? (
          <Button
            type="button"
            onClick={onNavigateToInventory}
            className="w-full sm:w-auto min-h-[48px] h-12 bg-[#047857] hover:bg-[#065f46] text-white font-bold rounded-xl shadow-xs gap-2 cursor-pointer text-sm"
          >
            <Package className="w-4 h-4" />
            <span>Manage Inventory Lots</span>
          </Button>
        ) : (
          <Link href="/seller?tab=inventory" className="w-full sm:w-auto">
            <Button
              type="button"
              className="w-full sm:w-auto min-h-[48px] h-12 bg-[#047857] hover:bg-[#065f46] text-white font-bold rounded-xl shadow-xs gap-2 cursor-pointer text-sm"
            >
              <Package className="w-4 h-4" />
              <span>Manage Inventory Lots</span>
            </Button>
          </Link>
        )}
      </div>

      {/* Main Content Area */}
      {initialReports.length === 0 ? (
        /* TASK 3: Clean, Tier-2 Friendly Empty State UI */
        <div className="bg-white rounded-3xl border border-slate-200/90 p-8 sm:p-14 text-center shadow-xs flex flex-col items-center justify-center space-y-4 max-w-2xl mx-auto my-6">
          <div className="w-16 h-16 sm:w-20 sm:h-20 rounded-2xl bg-slate-100 flex items-center justify-center text-slate-400">
            <FlaskConical className="w-8 h-8 sm:w-10 sm:h-10 stroke-[1.75]" />
          </div>

          <div className="space-y-1.5">
            <h2 className="text-lg sm:text-xl font-bold text-slate-900">
              No Lab Reports Uploaded
            </h2>
            <p className="text-xs sm:text-sm text-slate-500 max-w-md mx-auto leading-relaxed">
              Upload lab reports from your Inventory cards to see them tracked here.
            </p>
          </div>

          {onNavigateToInventory ? (
            <Button
              type="button"
              onClick={onNavigateToInventory}
              className="min-h-[48px] h-12 px-6 bg-slate-900 hover:bg-slate-800 text-white font-bold rounded-xl shadow-xs gap-2 cursor-pointer text-sm sm:text-base mt-2"
            >
              <span>Go to Inventory</span>
              <ArrowRight className="w-4 h-4" />
            </Button>
          ) : (
            <Link href="/seller?tab=inventory">
              <Button
                type="button"
                className="min-h-[48px] h-12 px-6 bg-slate-900 hover:bg-slate-800 text-white font-bold rounded-xl shadow-xs gap-2 cursor-pointer text-sm sm:text-base mt-2"
              >
                <span>Go to Inventory</span>
                <ArrowRight className="w-4 h-4" />
              </Button>
            </Link>
          )}
        </div>
      ) : (
        /* TASK 4: Populated State (Mobile-First Cards Grid) */
        <div className="space-y-6">
          {/* Search and Filters Bar */}
          <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
            <div className="relative flex-1">
              <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
              <Input
                type="text"
                placeholder="Search by commodity, lot #, lab name, report #..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="min-h-[48px] h-12 pl-10 bg-white border-slate-200 rounded-xl text-sm"
              />
            </div>

            {/* Quick Status Filter Buttons */}
            <div className="flex items-center gap-1.5 overflow-x-auto pb-1 sm:pb-0 scrollbar-hide">
              {[
                { id: "ALL", label: "All" },
                { id: "VERIFIED", label: "Verified" },
                { id: "UNDER_REVIEW", label: "Under Review" },
                { id: "EXPIRED", label: "Expired" },
              ].map((f) => (
                <button
                  key={f.id}
                  type="button"
                  onClick={() => setStatusFilter(f.id)}
                  className={cn(
                    "min-h-[48px] h-12 px-3.5 rounded-xl text-xs font-bold whitespace-nowrap transition-all cursor-pointer border",
                    statusFilter === f.id
                      ? "bg-slate-900 text-white border-slate-900 shadow-xs"
                      : "bg-white text-slate-600 border-slate-200 hover:bg-slate-50"
                  )}
                >
                  {f.label}
                </button>
              ))}
            </div>
          </div>

          {/* Cards Grid */}
          {filteredReports.length === 0 ? (
            <div className="bg-white rounded-2xl border border-slate-200/90 p-10 text-center space-y-2 mt-6">
              <FileX className="w-8 h-8 text-slate-400 mx-auto" />
              <p className="text-sm font-bold text-slate-800">No matching reports found</p>
              <p className="text-xs text-slate-500">Try adjusting your search query or filter.</p>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mt-6">
              {filteredReports.map((report) => (
                <GlobalLabReportCard key={report.id} report={report} />
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
