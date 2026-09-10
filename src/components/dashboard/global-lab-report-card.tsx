"use client";

import React, { useState } from "react";
import { format } from "date-fns";
import {
  FileText,
  Building2,
  Calendar,
  ExternalLink,
  Loader2,
  Clock,
  ShieldCheck,
  Tag,
  FlaskConical,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { QualityStatusBadge } from "@/src/components/dashboard/quality-status-badge";
import {
  SellerGlobalLabReportItem,
  getSignedLabDocumentUrlAction,
} from "@/src/server/actions/lab-actions";
import { cn } from "@/lib/utils";

interface GlobalLabReportCardProps {
  report: SellerGlobalLabReportItem;
}

export function GlobalLabReportCard({ report }: GlobalLabReportCardProps) {
  const [openingDoc, setOpeningDoc] = useState(false);

  const handleOpenDocument = async () => {
    if (!report.fileUrl) {
      toast.info("No physical document attached to this report.");
      return;
    }

    setOpeningDoc(true);
    try {
      const res = await getSignedLabDocumentUrlAction(report.fileUrl);
      if (res.success && res.data?.signedUrl) {
        window.open(res.data.signedUrl, "_blank", "noopener,noreferrer");
      } else {
        toast.error(res.error || "Failed to generate secure link for this document.");
      }
    } catch (err: any) {
      toast.error(err.message || "Failed to open document.");
    } finally {
      setOpeningDoc(false);
    }
  };

  const isNotRequired = report.status === "Not Required";
  const formattedTestDate = report.testDate
    ? format(new Date(report.testDate), "dd MMM yyyy")
    : "—";
  const formattedReportDate = report.reportDate
    ? format(new Date(report.reportDate), "dd MMM yyyy")
    : "—";
  const formattedExpiryDate = report.validUntil
    ? format(new Date(report.validUntil), "dd MMM yyyy")
    : "No Expiry";

  return (
    <div className="bg-white rounded-2xl border border-slate-200/90 p-5 sm:p-6 shadow-xs hover:border-slate-300 hover:shadow-md transition-all duration-200 flex flex-col justify-between space-y-4">
      <div className="space-y-3.5">
        {/* Top Header: Commodity Name, Lot Number & Status Badge */}
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-1.5 flex-wrap">
              <span className="text-xs sm:text-sm font-extrabold uppercase tracking-wider text-slate-900 truncate">
                {report.commodityName || "Agricultural Commodity"}
              </span>
              {report.lotNumber && (
                <>
                  <span className="text-slate-300 font-bold">•</span>
                  <span className="text-xs font-mono font-bold text-[#047857] bg-emerald-50 px-2 py-0.5 rounded-md border border-emerald-200/70">
                    Lot: {report.lotNumber}
                  </span>
                </>
              )}
            </div>

            {report.sampleId && (
              <p className="text-xs text-slate-500 font-medium truncate mt-0.5">
                Sample / Batch: <span className="text-slate-700 font-mono font-semibold">{report.sampleId}</span>
              </p>
            )}
          </div>

          <div className="shrink-0">
            <QualityStatusBadge
              status={report.status}
              validUntil={report.validUntil}
              testDate={report.testDate}
            />
          </div>
        </div>

        {/* Laboratory & Report Info Block */}
        <div className="p-3.5 bg-slate-50/80 rounded-xl border border-slate-100 space-y-2 text-xs">
          <div className="flex items-center justify-between gap-2">
            <span className="text-slate-500 font-medium flex items-center gap-1.5">
              <Building2 className="w-3.5 h-3.5 text-slate-400 shrink-0" />
              <span>Laboratory:</span>
            </span>
            <span className="font-bold text-slate-900 truncate text-right max-w-[60%]">
              {report.laboratoryName}
            </span>
          </div>

          <div className="flex items-center justify-between gap-2">
            <span className="text-slate-500 font-medium flex items-center gap-1.5">
              <FileText className="w-3.5 h-3.5 text-slate-400 shrink-0" />
              <span>Report No:</span>
            </span>
            <span className="font-bold font-mono text-slate-900 truncate text-right max-w-[60%]">
              {report.reportNumber}
            </span>
          </div>
        </div>

        {/* Date Matrix: Test Date & Expiry Date */}
        <div className="grid grid-cols-2 gap-2 text-xs">
          <div className="p-2.5 rounded-xl bg-white border border-slate-200/80 space-y-0.5">
            <span className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider block">
              Test Date
            </span>
            <span className="font-bold text-slate-800 block text-xs sm:text-sm">
              {formattedTestDate}
            </span>
          </div>

          <div className="p-2.5 rounded-xl bg-white border border-slate-200/80 space-y-0.5">
            <span className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider block">
              Valid Until
            </span>
            <span
              className={cn(
                "font-bold block text-xs sm:text-sm",
                report.freshness === "Expired"
                  ? "text-rose-600"
                  : report.freshness === "Expiring Soon"
                  ? "text-amber-600"
                  : "text-slate-800"
              )}
            >
              {formattedExpiryDate}
            </span>
          </div>
        </div>
      </div>

      {/* Action Footer: View Document Button (Min 48px touch target) */}
      <div className="pt-2 border-t border-slate-100">
        {isNotRequired ? (
          <div className="min-h-[48px] flex items-center justify-center p-2 rounded-xl bg-slate-50 border border-slate-200 text-xs font-semibold text-slate-500 text-center">
            Self-declared quality parameters (No physical COA required)
          </div>
        ) : report.fileUrl ? (
          <Button
            type="button"
            variant="outline"
            onClick={handleOpenDocument}
            disabled={openingDoc}
            className="w-full min-h-[48px] h-12 rounded-xl font-bold border-slate-300 hover:border-slate-400 hover:bg-slate-50 text-slate-800 text-xs sm:text-sm flex items-center justify-center gap-2 cursor-pointer shadow-2xs transition-all"
          >
            {openingDoc ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin text-emerald-600" />
                <span>Loading Document...</span>
              </>
            ) : (
              <>
                <FileText className="w-4 h-4 text-emerald-700" />
                <span>View Lab Certificate</span>
                <ExternalLink className="w-3.5 h-3.5 text-slate-400 ml-auto" />
              </>
            )}
          </Button>
        ) : (
          <div className="min-h-[48px] flex items-center justify-center p-2 rounded-xl bg-slate-50 border border-dashed border-slate-200 text-xs font-semibold text-slate-400 text-center">
            No physical file attached
          </div>
        )}
      </div>
    </div>
  );
}
