'use client';

import React, { useState, useEffect, useTransition } from 'react';
import {
  FileCheck2,
  FileText,
  ShieldCheck,
  AlertTriangle,
  CheckCircle2,
  XCircle,
  ExternalLink,
  ChevronDown,
  ChevronUp,
  FlaskConical,
  Building2,
  Calendar,
  Layers,
  Sparkles,
  Loader2,
  HelpCircle,
  Clock,
  Info,
} from 'lucide-react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from '@/components/ui/dialog';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import {
  getBrokerQualityComparisonAction,
  type BrokerQualityComparisonData,
  type QualityDocumentState,
} from '@/src/server/actions/broker-quality-actions';
import { getSignedLabDocumentUrlAction } from '@/src/server/actions/quality-verification-actions';
import { QualityActionBar } from './quality-action-bar';
import { toast } from 'sonner';

interface QualityComparisonPanelProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  requirementId: string;
  availabilityId: string;
  onVerificationComplete?: () => void;
}

export function QualityComparisonPanel({
  open,
  onOpenChange,
  requirementId,
  availabilityId,
  onVerificationComplete,
}: QualityComparisonPanelProps) {
  const [isPending, startTransition] = useTransition();
  const [data, setData] = useState<BrokerQualityComparisonData | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isExpandedDetails, setIsExpandedDetails] = useState<boolean>(true);
  const [isFetchingSignedUrl, setIsFetchingSignedUrl] = useState<boolean>(false);

  const loadComparison = () => {
    if (!requirementId || !availabilityId) return;

    startTransition(async () => {
      setError(null);
      const res = await getBrokerQualityComparisonAction({
        requirementId,
        availabilityId,
      });

      if (res.success && res.data) {
        setData(res.data);
      } else {
        setError(res.error || 'Failed to load quality comparison data.');
      }
    });
  };

  useEffect(() => {
    if (open && requirementId && availabilityId) {
      loadComparison();
    }
  }, [open, requirementId, availabilityId]);

  const handleViewLabReport = async () => {
    if (!data?.labTest?.id) return;

    setIsFetchingSignedUrl(true);
    try {
      const res = await getSignedLabDocumentUrlAction(data.labTest.id);
      if (res.success && res.data?.signedUrl) {
        window.open(res.data.signedUrl, '_blank', 'noopener,noreferrer');
      } else {
        toast.error(res.error || 'Failed to generate secure document preview link.');
      }
    } catch (err: any) {
      toast.error(err.message || 'Error opening lab report.');
    } finally {
      setIsFetchingSignedUrl(false);
    }
  };

  const getDocumentStateBadge = (state: QualityDocumentState) => {
    switch (state) {
      case 'Verified':
        return (
          <span className="px-2.5 py-1 rounded-md text-xs font-bold bg-emerald-100 text-emerald-800 border border-emerald-300 flex items-center gap-1 shadow-2xs">
            <CheckCircle2 className="w-3.5 h-3.5 text-emerald-700 shrink-0" />
            <span>Verified COA</span>
          </span>
        );
      case 'Received':
        return (
          <span className="px-2.5 py-1 rounded-md text-xs font-bold bg-teal-100 text-teal-800 border border-teal-300 flex items-center gap-1 shadow-2xs">
            <FileText className="w-3.5 h-3.5 text-teal-700 shrink-0" />
            <span>Report Received (Pending Audit)</span>
          </span>
        );
      case 'Correction Required':
        return (
          <span className="px-2.5 py-1 rounded-md text-xs font-bold bg-amber-100 text-amber-800 border border-amber-300 flex items-center gap-1 shadow-2xs">
            <AlertTriangle className="w-3.5 h-3.5 text-amber-700 shrink-0" />
            <span>Correction Requested</span>
          </span>
        );
      case 'Rejected':
        return (
          <span className="px-2.5 py-1 rounded-md text-xs font-bold bg-rose-100 text-rose-800 border border-rose-300 flex items-center gap-1 shadow-2xs">
            <XCircle className="w-3.5 h-3.5 text-rose-700 shrink-0" />
            <span>Rejected</span>
          </span>
        );
      case 'Required':
        return (
          <span className="px-2.5 py-1 rounded-md text-xs font-bold bg-amber-50 text-amber-700 border border-amber-200 flex items-center gap-1">
            <Clock className="w-3.5 h-3.5 text-amber-600 shrink-0" />
            <span>COA Required</span>
          </span>
        );
      default:
        return (
          <span className="px-2.5 py-1 rounded-md text-xs font-bold bg-slate-100 text-slate-600 border border-slate-200 flex items-center gap-1">
            <Info className="w-3.5 h-3.5 text-slate-400 shrink-0" />
            <span>Missing Evidence</span>
          </span>
        );
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-2xl max-h-[92vh] flex flex-col p-0 gap-0 overflow-hidden bg-slate-50/50">
        {/* HEADER */}
        <div className="p-4 sm:p-5 bg-white border-b border-slate-200 space-y-2">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-lg bg-teal-50 border border-teal-200/80 flex items-center justify-center text-[#0D9488]">
                <FlaskConical className="w-4 h-4" />
              </div>
              <div>
                <DialogTitle className="text-base sm:text-lg font-bold text-slate-900 leading-tight">
                  Quality & Lab Verification
                </DialogTitle>
                <div className="text-xs text-slate-500 font-mono">
                  {data?.availability.lotNumber} • {data?.availability.sellerCompanyName}
                </div>
              </div>
            </div>

            {/* Document State Badge */}
            {data && getDocumentStateBadge(data.documentState)}
          </div>
        </div>

        {/* BODY */}
        <div className="flex-1 overflow-y-auto p-4 sm:p-5 space-y-4">
          {isPending ? (
            <div className="py-16 text-center space-y-3">
              <Loader2 className="w-8 h-8 animate-spin text-[#0D9488] mx-auto" />
              <p className="text-xs text-slate-500 font-medium">
                Evaluating quality tolerances & laboratory evidence...
              </p>
            </div>
          ) : error ? (
            <Card className="border-rose-200 bg-rose-50/70 p-4 text-center text-xs text-rose-700">
              {error}
            </Card>
          ) : data ? (
            <>
              {/* 1. HIGH-LEVEL COMPATIBILITY SUMMARY */}
              <Card className="bg-white border border-slate-200 shadow-2xs rounded-xl overflow-hidden">
                <div className="p-4 space-y-3">
                  <div className="flex items-center justify-between gap-2">
                    <div className="flex items-center gap-2">
                      {data.summary.varianceCount === 0 ? (
                        <div className="w-6 h-6 rounded-full bg-emerald-100 flex items-center justify-center text-emerald-700 shrink-0">
                          <CheckCircle2 className="w-4 h-4" />
                        </div>
                      ) : (
                        <div className="w-6 h-6 rounded-full bg-amber-100 flex items-center justify-center text-amber-700 shrink-0">
                          <AlertTriangle className="w-4 h-4" />
                        </div>
                      )}
                      <div>
                        <div className="text-xs font-bold text-slate-900">
                          {data.summary.overallStatus}
                        </div>
                        <div className="text-[11px] text-slate-500">
                          {data.summary.summaryText}
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Summary Metric Strip */}
                  <div className="grid grid-cols-3 gap-2 bg-slate-50 p-2.5 rounded-lg border border-slate-100 text-center">
                    <div>
                      <div className="text-[10px] text-slate-400 uppercase font-semibold">Total Params</div>
                      <div className="text-sm font-bold text-slate-800 mt-0.5">
                        {data.summary.totalParameters}
                      </div>
                    </div>
                    <div>
                      <div className="text-[10px] text-emerald-600 uppercase font-semibold">Compliant</div>
                      <div className="text-sm font-bold text-emerald-700 mt-0.5">
                        {data.summary.compliantParameters}
                      </div>
                    </div>
                    <div>
                      <div className="text-[10px] text-amber-600 uppercase font-semibold">Variances</div>
                      <div className="text-sm font-bold text-amber-700 mt-0.5">
                        {data.summary.varianceCount}
                      </div>
                    </div>
                  </div>
                </div>
              </Card>

              {/* 2. COA / LAB DOCUMENT ATTACHMENT CARD */}
              {data.labTest ? (
                <Card className="bg-gradient-to-r from-teal-900 to-slate-900 text-white rounded-xl shadow-xs border-0 p-4">
                  <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                    <div className="space-y-1">
                      <div className="flex items-center gap-1.5 text-xs text-teal-300 font-bold uppercase tracking-wider">
                        <FileText className="w-3.5 h-3.5" />
                        <span>Laboratory Evidence Document</span>
                      </div>
                      <div className="text-sm font-bold text-white">
                        {data.labTest.laboratoryName}
                        {data.labTest.laboratoryLocation && (
                          <span className="text-xs font-normal text-slate-300 ml-1">
                            ({data.labTest.laboratoryLocation})
                          </span>
                        )}
                      </div>
                      <div className="text-xs text-slate-300 font-mono">
                        Report #{data.labTest.reportNumber} • Tested: {data.labTest.testDateFormatted}
                      </div>
                    </div>

                    {/* View Lab Report Button */}
                    {data.labTest.hasPhysicalDocument && (
                      <Button
                        type="button"
                        onClick={handleViewLabReport}
                        disabled={isFetchingSignedUrl}
                        className="min-h-[44px] h-11 px-4 bg-white hover:bg-slate-100 text-slate-900 font-bold text-xs rounded-lg shadow-xs transition-all flex items-center justify-center gap-1.5 shrink-0"
                      >
                        {isFetchingSignedUrl ? (
                          <Loader2 className="w-3.5 h-3.5 animate-spin" />
                        ) : (
                          <ExternalLink className="w-3.5 h-3.5" />
                        )}
                        <span>View Lab Report (PDF)</span>
                      </Button>
                    )}
                  </div>
                </Card>
              ) : (
                <div className="p-3 bg-amber-50/80 border border-amber-200/80 rounded-xl text-xs text-amber-800 flex items-start gap-2">
                  <Info className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
                  <div>
                    <span className="font-semibold">No formal COA report uploaded:</span> Parameters below reflect the Seller's declared specifications.
                  </div>
                </div>
              )}

              {/* 3. DETAILED PARAMETER COMPARISON (Collapsible) */}
              <div className="space-y-2">
                <button
                  type="button"
                  onClick={() => setIsExpandedDetails(!isExpandedDetails)}
                  className="w-full flex items-center justify-between text-xs font-bold text-slate-700 bg-white p-3 rounded-lg border border-slate-200/80 hover:bg-slate-50 transition-colors"
                >
                  <div className="flex items-center gap-1.5">
                    <Sparkles className="w-3.5 h-3.5 text-[#0D9488]" />
                    <span>Side-by-Side Parameter Specifications ({data.parameters.length})</span>
                  </div>
                  {isExpandedDetails ? (
                    <ChevronUp className="w-4 h-4 text-slate-400" />
                  ) : (
                    <ChevronDown className="w-4 h-4 text-slate-400" />
                  )}
                </button>

                {isExpandedDetails && (
                  <div className="space-y-2">
                    {data.parameters.map((p) => {
                      const isOk = p.isCompliant;
                      return (
                        <div
                          key={p.parameterId}
                          className={`p-3 rounded-xl border transition-all ${
                            isOk
                              ? 'bg-white border-slate-200/80'
                              : 'bg-amber-50/50 border-amber-200'
                          }`}
                        >
                          {/* Parameter Name & Source Badge */}
                          <div className="flex items-center justify-between gap-2 pb-2 border-b border-slate-100">
                            <span className="font-bold text-xs sm:text-sm text-slate-900">
                              {p.name}
                            </span>
                            <div className="flex items-center gap-1.5">
                              {p.source === 'Laboratory Certified' ? (
                                <Badge className="bg-teal-50 text-teal-700 border-teal-200 text-[10px]">
                                  Lab Certified
                                </Badge>
                              ) : p.source === 'Seller Declared' ? (
                                <Badge className="bg-slate-100 text-slate-600 border-slate-200 text-[10px]">
                                  Seller Declared
                                </Badge>
                              ) : (
                                <Badge className="bg-rose-50 text-rose-700 border-rose-200 text-[10px]">
                                  Undeclared
                                </Badge>
                              )}

                              {isOk ? (
                                <span className="text-[11px] font-bold text-emerald-600 flex items-center gap-0.5">
                                  <CheckCircle2 className="w-3.5 h-3.5" />
                                  <span>Match</span>
                                </span>
                              ) : (
                                <span className="text-[11px] font-bold text-amber-600 flex items-center gap-0.5">
                                  <AlertTriangle className="w-3.5 h-3.5" />
                                  <span>Variance</span>
                                </span>
                              )}
                            </div>
                          </div>

                          {/* Stacked comparison on mobile (360px), side-by-side on md: */}
                          <div className="grid grid-cols-1 md:grid-cols-2 gap-2 pt-2 text-xs">
                            {/* Buyer Target Requirement */}
                            <div className="bg-slate-50 p-2 rounded-lg border border-slate-100">
                              <div className="text-[10px] uppercase font-semibold text-slate-400">
                                Buyer Target Specification
                              </div>
                              <div className="font-semibold text-slate-800 mt-0.5">
                                {p.buyerFormattedSpec}
                              </div>
                            </div>

                            {/* Seller Lot Value */}
                            <div
                              className={`p-2 rounded-lg border ${
                                isOk
                                  ? 'bg-slate-50 border-slate-100 text-slate-800'
                                  : 'bg-amber-100/60 border-amber-200 text-amber-900'
                              }`}
                            >
                              <div className="text-[10px] uppercase font-semibold text-slate-400">
                                Seller Measured Value
                              </div>
                              <div className="font-bold mt-0.5">
                                {p.sellerValue ? `${p.sellerValue} ${p.unit || ''}` : 'Not Provided'}
                              </div>
                              {p.discrepancyNote && (
                                <div className="text-[10px] font-medium text-amber-700 mt-0.5">
                                  {p.discrepancyNote}
                                </div>
                              )}
                            </div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            </>
          ) : null}
        </div>

        {/* STICKY QUALITY ACTION BAR */}
        {data && (
          <QualityActionBar
            labTestId={data.labTest?.id}
            availabilityId={data.availability.id}
            requirementId={data.requirement.id}
            lotNumber={data.availability.lotNumber}
            currentStatus={data.labTest?.status}
            onSuccess={() => {
              loadComparison();
              if (onVerificationComplete) onVerificationComplete();
            }}
          />
        )}
      </DialogContent>
    </Dialog>
  );
}
