'use client';

import React, { useState, useEffect, useTransition } from 'react';
import {
  FlaskConical,
  Scale,
  CheckCircle2,
  Clock,
  AlertTriangle,
  AlertCircle,
  FileCheck,
  FileText,
  ExternalLink,
  Loader2,
  ShieldCheck,
  Info,
  Calendar,
  MapPin,
  Truck,
  Building,
  RefreshCw,
} from 'lucide-react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import {
  BuyerTransactionQualityData,
  BuyerQualityParameterComparison,
  LabVerificationStatus,
  WeighmentStatus,
} from '@/src/types/buyer-quality-types';
import {
  getBuyerTransactionQualityAction,
  getBuyerLabReportSignedUrlAction,
  getBuyerWeighmentSlipSignedUrlAction,
} from '@/src/server/actions/buyer-quality-tracking-actions';

export interface TransactionQualityCardProps {
  bookingId: string;
  initialData?: BuyerTransactionQualityData | null;
  className?: string;
}

/**
 * Task 2 & 3 (Micro-Sprint 39.1): Buyer Transaction Quality & Weighment UI Component.
 * 
 * Renders verified post-deal transaction quality evidence:
 * 1. Scientific Quality (Lab Results): Compares Buyer Target vs. Actual Verified Result.
 * 2. Physical Weighment: Displays Gross, Tare, and Net Weight Loaded.
 * 3. Secure Document Preview: Short-lived signed URLs for COA and Weighment Slip.
 * 
 * Strict Guardrails:
 * - Read-only: No editing or dispute initiation here (disputes handled in Sprint 39.4).
 * - Mobile-first: flex-col stacking on 360px viewports without horizontal scrolling.
 * - Touch targets: min-h-[48px] on all action triggers.
 * - Privacy scrubber: Zero Seller contact details or internal pricing exposed.
 */
export function TransactionQualityCard({
  bookingId,
  initialData,
  className,
}: TransactionQualityCardProps) {
  const [data, setData] = useState<BuyerTransactionQualityData | null>(initialData || null);
  const [loading, setLoading] = useState<boolean>(!initialData);
  const [error, setError] = useState<string | null>(null);

  // Document download/preview states
  const [loadingDocType, setLoadingDocType] = useState<'coa' | 'weighment' | null>(null);
  const [docError, setDocError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  // Load transaction quality if not provided as initialData
  useEffect(() => {
    if (initialData) {
      setData(initialData);
      setLoading(false);
      return;
    }

    let isMounted = true;
    async function loadData() {
      try {
        setLoading(true);
        setError(null);
        const res = await getBuyerTransactionQualityAction(bookingId);
        if (!isMounted) return;

        if (res.success && res.data) {
          setData(res.data);
        } else {
          setError(res.error || 'Failed to load transaction quality evidence.');
        }
      } catch (err: any) {
        if (!isMounted) return;
        setError(err.message || 'An unexpected error occurred while loading quality data.');
      } finally {
        if (isMounted) setLoading(false);
      }
    }

    loadData();

    return () => {
      isMounted = false;
    };
  }, [bookingId, initialData]);

  // Handle viewing COA certificate
  const handleViewCOA = () => {
    setDocError(null);
    setLoadingDocType('coa');

    startTransition(async () => {
      try {
        if (data?.labReport?.signedUrl) {
          window.open(data.labReport.signedUrl, '_blank', 'noopener,noreferrer');
          setLoadingDocType(null);
          return;
        }

        const res = await getBuyerLabReportSignedUrlAction(bookingId);
        if (res.success && res.data?.signedUrl) {
          window.open(res.data.signedUrl, '_blank', 'noopener,noreferrer');
        } else {
          setDocError(res.error || 'Unable to generate secure link for the Certificate of Analysis.');
        }
      } catch (err: any) {
        setDocError(err.message || 'Failed to open Certificate of Analysis.');
      } finally {
        setLoadingDocType(null);
      }
    });
  };

  // Handle viewing Weighment Slip
  const handleViewWeighmentSlip = () => {
    setDocError(null);
    setLoadingDocType('weighment');

    startTransition(async () => {
      try {
        const res = await getBuyerWeighmentSlipSignedUrlAction(bookingId);
        if (res.success && res.data?.signedUrl) {
          window.open(res.data.signedUrl, '_blank', 'noopener,noreferrer');
        } else {
          setDocError(res.error || 'Unable to generate secure link for the Weighment Slip.');
        }
      } catch (err: any) {
        setDocError(err.message || 'Failed to open Weighment Slip.');
      } finally {
        setLoadingDocType(null);
      }
    });
  };

  // 1. Loading State
  if (loading) {
    return (
      <Card className={cn('w-full max-w-full overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-xs p-6', className)}>
        <div className="flex flex-col items-center justify-center py-10 space-y-3 text-center">
          <Loader2 className="w-8 h-8 text-[#0284C7] animate-spin" />
          <p className="text-xs sm:text-sm font-semibold text-slate-600">
            Fetching verified quality parameters and weighment data...
          </p>
        </div>
      </Card>
    );
  }

  // 2. Error State
  if (error || !data) {
    return (
      <Card className={cn('w-full max-w-full overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-xs', className)}>
        <CardHeader className="p-4 sm:p-5 border-b border-slate-100 pb-3">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-amber-50 text-amber-600 flex items-center justify-center shrink-0">
              <FlaskConical className="w-4 h-4" />
            </div>
            <div>
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                Quality & Weighment
              </span>
              <CardTitle className="text-sm sm:text-base font-bold text-slate-900 leading-tight">
                Transaction Quality Evidence
              </CardTitle>
            </div>
          </div>
        </CardHeader>
        <CardContent className="p-6 text-center space-y-4">
          <div className="w-10 h-10 rounded-full bg-amber-50 text-amber-600 mx-auto flex items-center justify-center">
            <AlertCircle className="w-5 h-5" />
          </div>
          <div className="space-y-1 max-w-md mx-auto">
            <h4 className="text-xs sm:text-sm font-bold text-slate-800">Quality Data Not Available</h4>
            <p className="text-xs text-slate-500 leading-relaxed">
              {error || 'Quality parameters have not been recorded yet for this booking.'}
            </p>
          </div>
          <Button
            variant="outline"
            onClick={async () => {
              setLoading(true);
              setError(null);
              const res = await getBuyerTransactionQualityAction(bookingId);
              if (res.success && res.data) {
                setData(res.data);
              } else {
                setError(res.error || 'Retry failed');
              }
              setLoading(false);
            }}
            className="min-h-[48px] px-4 rounded-xl text-xs font-semibold"
          >
            <RefreshCw className="w-3.5 h-3.5 mr-2" />
            Retry Fetching Evidence
          </Button>
        </CardContent>
      </Card>
    );
  }

  const { labReport, parameters, weighment } = data;

  return (
    <Card
      className={cn(
        'w-full max-w-full overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-xs',
        className
      )}
    >
      {/* Header with high-level badges */}
      <CardHeader className="p-4 sm:p-5 border-b border-slate-100 pb-3">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center shrink-0 border border-emerald-100">
              <FlaskConical className="w-4 h-4" />
            </div>
            <div>
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                Post-Deal Verification
              </span>
              <CardTitle className="text-sm sm:text-base font-bold text-slate-900 leading-tight">
                Transaction Quality & Weighment
              </CardTitle>
            </div>
          </div>

          <div className="flex items-center gap-2 self-start sm:self-auto">
            {renderOverallStatusBadge(data.overallQualityStatus)}
          </div>
        </div>
      </CardHeader>

      <CardContent className="p-4 sm:p-5 space-y-6">
        {/* Document Action Error Alert */}
        {docError && (
          <div className="p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2 animate-in fade-in">
            <AlertCircle className="w-4 h-4 shrink-0" />
            <span className="flex-1 font-medium">{docError}</span>
            <button
              onClick={() => setDocError(null)}
              className="text-rose-500 hover:text-rose-800 text-[11px] font-bold px-1"
            >
              Dismiss
            </button>
          </div>
        )}

        {/* SECTION 1: SCIENTIFIC QUALITY (LAB RESULTS) */}
        <section aria-labelledby="scientific-quality-heading" className="space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-slate-100 pb-2">
            <div className="flex items-center gap-2">
              <h3
                id="scientific-quality-heading"
                className="text-xs sm:text-sm font-bold text-slate-900 uppercase tracking-wider flex items-center gap-1.5"
              >
                <span>1. Scientific Quality (Lab Results)</span>
              </h3>
            </div>

            {labReport?.status && (
              <div className="flex items-center gap-1.5">
                {renderLabStatusBadge(labReport.status)}
              </div>
            )}
          </div>

          {labReport ? (
            <div className="space-y-4">
              {/* Lab Overview Metadata Card */}
              <div className="rounded-xl bg-slate-50/80 border border-slate-200/80 p-3.5 space-y-3">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                  <div className="space-y-1">
                    <div className="flex items-center gap-1.5">
                      <Building className="w-3.5 h-3.5 text-slate-500 shrink-0" />
                      <span className="text-xs font-bold text-slate-800">
                        {labReport.laboratoryName}
                      </span>
                    </div>
                    {labReport.laboratoryLocation && (
                      <div className="flex items-center gap-1 text-[11px] text-slate-500 pl-5">
                        <MapPin className="w-3 h-3 text-slate-400 shrink-0" />
                        <span className="truncate">{labReport.laboratoryLocation}</span>
                      </div>
                    )}
                  </div>

                  <div className="flex flex-wrap items-center gap-2 text-[11px] text-slate-600 sm:text-right">
                    <div className="px-2 py-0.5 rounded-md bg-white border border-slate-200 font-mono text-[11px] font-semibold text-slate-700">
                      Ref: {labReport.reportNumber}
                    </div>
                  </div>
                </div>

                {/* Additional lab details row */}
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-2 pt-2 border-t border-slate-200/60 text-[11px]">
                  {labReport.sampleId && (
                    <div>
                      <span className="text-slate-400 block text-[10px] uppercase font-bold">Sample ID</span>
                      <span className="font-medium text-slate-700 truncate block">{labReport.sampleId}</span>
                    </div>
                  )}
                  {labReport.reportDate && (
                    <div>
                      <span className="text-slate-400 block text-[10px] uppercase font-bold">Report Date</span>
                      <span className="font-medium text-slate-700">
                        {new Date(labReport.reportDate).toLocaleDateString('en-IN', {
                          day: '2-digit',
                          month: 'short',
                          year: 'numeric',
                        })}
                      </span>
                    </div>
                  )}
                  {labReport.verifiedAt && (
                    <div className="col-span-2 sm:col-span-1">
                      <span className="text-slate-400 block text-[10px] uppercase font-bold">Desk Verification</span>
                      <span className="font-medium text-emerald-700 flex items-center gap-1">
                        <ShieldCheck className="w-3 h-3" />
                        Verified
                      </span>
                    </div>
                  )}
                </div>

                {/* Secure Document Preview Button for COA */}
                {labReport.hasCertificate && (
                  <div className="pt-2">
                    <Button
                      variant="outline"
                      onClick={handleViewCOA}
                      disabled={isPending && loadingDocType === 'coa'}
                      className="w-full min-h-[48px] h-12 rounded-xl bg-white hover:bg-slate-50 border-slate-200 text-slate-800 text-xs sm:text-sm font-bold shadow-2xs transition-colors flex items-center justify-center gap-2"
                    >
                      {loadingDocType === 'coa' ? (
                        <>
                          <Loader2 className="w-4 h-4 text-[#0284C7] animate-spin" />
                          <span>Generating Secure Certificate Link...</span>
                        </>
                      ) : (
                        <>
                          <FileCheck className="w-4 h-4 text-emerald-600" />
                          <span>View Certificate of Analysis (COA)</span>
                          <ExternalLink className="w-3.5 h-3.5 text-slate-400 ml-1" />
                        </>
                      )}
                    </Button>
                  </div>
                )}
              </div>

              {/* Quality Comparison Table / Grid (Mobile-First: flex-col on 360px) */}
              <div className="space-y-2">
                <div className="flex items-center justify-between text-xs font-bold text-slate-700 px-1">
                  <span>Parameter Specification Matrix</span>
                  <span className="text-[11px] font-normal text-slate-400">
                    Buyer Target vs. Verified Lab Output
                  </span>
                </div>

                {/* Desktop View Table (hidden on small viewports) */}
                <div className="hidden md:block rounded-xl border border-slate-200 overflow-hidden bg-white">
                  <table className="w-full text-left text-xs">
                    <thead className="bg-slate-50 border-b border-slate-200 text-[11px] font-bold text-slate-600 uppercase">
                      <tr>
                        <th className="py-2.5 px-3">Quality Parameter</th>
                        <th className="py-2.5 px-3">Buyer Target Spec</th>
                        <th className="py-2.5 px-3">Actual Verified Result</th>
                        <th className="py-2.5 px-3 text-right">Variance / Status</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100">
                      {parameters.map((param) => (
                        <tr key={param.parameterId} className="hover:bg-slate-50/50 transition-colors">
                          <td className="py-2.5 px-3 font-semibold text-slate-900">
                            <div className="flex items-center gap-1.5">
                              <span>{param.parameterName}</span>
                              {param.isRequired && (
                                <span className="px-1.5 py-0.2 rounded text-[9px] font-bold bg-amber-50 text-amber-700 border border-amber-200">
                                  Required
                                </span>
                              )}
                            </div>
                          </td>
                          <td className="py-2.5 px-3 text-slate-600 font-mono text-xs">
                            {param.buyerTargetFormatted}
                          </td>
                          <td className="py-2.5 px-3 font-mono font-bold text-slate-900 text-xs">
                            {param.actualValueFormatted}
                          </td>
                          <td className="py-2.5 px-3 text-right">
                            <div className="flex items-center justify-end gap-1.5">
                              {param.varianceLabel && (
                                <span className="text-[10px] text-slate-500 font-mono">
                                  {param.varianceLabel}
                                </span>
                              )}
                              {param.isWithinBounds ? (
                                <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">
                                  <CheckCircle2 className="w-2.5 h-2.5 text-emerald-600" />
                                  Within Spec
                                </span>
                              ) : (
                                <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-rose-50 text-rose-700 border border-rose-200">
                                  <AlertTriangle className="w-2.5 h-2.5 text-rose-600" />
                                  Deviation
                                </span>
                              )}
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

                {/* Mobile-First Stacked Cards (Visible on mobile 360px viewport) */}
                <div className="md:hidden space-y-2">
                  {parameters.map((param) => (
                    <div
                      key={param.parameterId}
                      className="rounded-xl border border-slate-200 bg-white p-3 space-y-2.5 shadow-2xs"
                    >
                      <div className="flex items-start justify-between gap-2">
                        <div className="space-y-0.5 min-w-0">
                          <span className="text-xs font-bold text-slate-900 block truncate">
                            {param.parameterName}
                          </span>
                          {param.isRequired && (
                            <span className="inline-block px-1.5 py-0.2 rounded text-[9px] font-bold bg-amber-50 text-amber-700 border border-amber-200">
                              Contractual Spec
                            </span>
                          )}
                        </div>

                        {param.isWithinBounds ? (
                          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-50 text-emerald-700 border border-emerald-200 shrink-0">
                            <CheckCircle2 className="w-2.5 h-2.5 text-emerald-600" />
                            Within Spec
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-rose-50 text-rose-700 border border-rose-200 shrink-0">
                            <AlertTriangle className="w-2.5 h-2.5 text-rose-600" />
                            Deviation
                          </span>
                        )}
                      </div>

                      {/* 2-column key comparison */}
                      <div className="grid grid-cols-2 gap-2 p-2 rounded-lg bg-slate-50 border border-slate-100 text-xs">
                        <div>
                          <span className="text-[10px] uppercase font-bold text-slate-400 block">
                            Buyer Target
                          </span>
                          <span className="font-mono text-slate-700 font-semibold block text-[11px]">
                            {param.buyerTargetFormatted}
                          </span>
                        </div>
                        <div>
                          <span className="text-[10px] uppercase font-bold text-slate-400 block">
                            Verified Result
                          </span>
                          <span className="font-mono text-slate-900 font-bold block text-[11px]">
                            {param.actualValueFormatted}
                          </span>
                        </div>
                      </div>

                      {param.varianceLabel && (
                        <div className="text-[10px] text-slate-500 font-medium flex items-center justify-between">
                          <span>Lot Variance:</span>
                          <span className="font-mono font-semibold text-slate-700">
                            {param.varianceLabel}
                          </span>
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </div>
          ) : (
            <div className="p-4 rounded-xl bg-slate-50 border border-slate-200 text-center space-y-2">
              <div className="w-8 h-8 rounded-full bg-slate-100 text-slate-500 mx-auto flex items-center justify-center">
                <Clock className="w-4 h-4" />
              </div>
              <h4 className="text-xs font-bold text-slate-800">Scientific Testing In Progress</h4>
              <p className="text-[11px] text-slate-500 max-w-sm mx-auto">
                Lab testing sample is currently undergoing scientific analysis at the designated accredited facility. Full COA parameters will be verified and published here prior to dispatch.
              </p>
            </div>
          )}
        </section>

        {/* SECTION 2: PHYSICAL WEIGHMENT */}
        <section aria-labelledby="physical-weighment-heading" className="space-y-4 pt-2 border-t border-slate-100">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-slate-100 pb-2">
            <h3
              id="physical-weighment-heading"
              className="text-xs sm:text-sm font-bold text-slate-900 uppercase tracking-wider flex items-center gap-1.5"
            >
              <span>2. Physical Weighment (Dispatch Loading)</span>
            </h3>

            {weighment?.status && (
              <div className="flex items-center gap-1.5">
                {renderWeighmentStatusBadge(weighment.status)}
              </div>
            )}
          </div>

          {weighment ? (
            <div className="space-y-3">
              {/* Weighbridge and Vehicle Header */}
              <div className="rounded-xl bg-slate-50/80 border border-slate-200/80 p-3.5 space-y-3">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                  <div className="space-y-0.5">
                    <div className="flex items-center gap-1.5">
                      <Truck className="w-3.5 h-3.5 text-slate-500 shrink-0" />
                      <span className="text-xs font-bold text-slate-900 font-mono">
                        Vehicle: {weighment.vehicleNumber || 'Assigned Commercial Carrier'}
                      </span>
                    </div>
                    {weighment.weighbridgeLocation && (
                      <div className="flex items-center gap-1 text-[11px] text-slate-500 pl-5">
                        <MapPin className="w-3 h-3 text-slate-400 shrink-0" />
                        <span className="truncate">{weighment.weighbridgeLocation}</span>
                      </div>
                    )}
                  </div>

                  {weighment.weighmentDate && (
                    <div className="flex items-center gap-1 text-[11px] text-slate-600 sm:text-right">
                      <Calendar className="w-3 h-3 text-slate-400" />
                      <span>
                        {new Date(weighment.weighmentDate).toLocaleDateString('en-IN', {
                          day: '2-digit',
                          month: 'short',
                          year: 'numeric',
                        })}
                      </span>
                    </div>
                  )}
                </div>

                {/* 3-Column / Stacked Metric Cards (Gross, Tare, Net) */}
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5 pt-1">
                  {/* Gross Weight */}
                  <div className="p-3 rounded-xl bg-white border border-slate-200 space-y-1">
                    <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                      Gross Weight
                    </span>
                    <div className="text-sm sm:text-base font-extrabold text-slate-800 font-mono">
                      {weighment.grossWeight !== null ? `${weighment.grossWeight.toFixed(2)} ${weighment.unitSymbol}` : 'Pending'}
                    </div>
                    <span className="text-[10px] text-slate-400 block">Truck + Cargo</span>
                  </div>

                  {/* Tare Weight */}
                  <div className="p-3 rounded-xl bg-white border border-slate-200 space-y-1">
                    <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                      Tare Weight
                    </span>
                    <div className="text-sm sm:text-base font-extrabold text-slate-800 font-mono">
                      {weighment.tareWeight !== null ? `${weighment.tareWeight.toFixed(2)} ${weighment.unitSymbol}` : 'Pending'}
                    </div>
                    <span className="text-[10px] text-slate-400 block">Empty Vehicle</span>
                  </div>

                  {/* Net Weight Loaded (Prominent Highlight) */}
                  <div className="p-3 rounded-xl bg-emerald-50/70 border border-emerald-200 space-y-1 sm:col-span-1">
                    <div className="flex items-center justify-between">
                      <span className="text-[10px] font-bold text-emerald-800 uppercase tracking-wider block">
                        Net Weight Loaded
                      </span>
                      <Scale className="w-3.5 h-3.5 text-emerald-600" />
                    </div>
                    <div className="text-base sm:text-lg font-black text-emerald-900 font-mono">
                      {weighment.netWeight !== null ? `${weighment.netWeight.toFixed(2)} ${weighment.unitSymbol}` : 'Pending'}
                    </div>
                    <span className="text-[10px] font-medium text-emerald-700 block">Billable Dispatch Lot</span>
                  </div>
                </div>

                {/* Secure Document Preview Button for Weighment Slip */}
                {weighment.hasWeighbridgeSlip && (
                  <div className="pt-2">
                    <Button
                      variant="outline"
                      onClick={handleViewWeighmentSlip}
                      disabled={isPending && loadingDocType === 'weighment'}
                      className="w-full min-h-[48px] h-12 rounded-xl bg-white hover:bg-slate-50 border-slate-200 text-slate-800 text-xs sm:text-sm font-bold shadow-2xs transition-colors flex items-center justify-center gap-2"
                    >
                      {loadingDocType === 'weighment' ? (
                        <>
                          <Loader2 className="w-4 h-4 text-[#0284C7] animate-spin" />
                          <span>Generating Secure Weighment Slip Link...</span>
                        </>
                      ) : (
                        <>
                          <Scale className="w-4 h-4 text-emerald-600" />
                          <span>View Official Weighbridge Slip</span>
                          <ExternalLink className="w-3.5 h-3.5 text-slate-400 ml-1" />
                        </>
                      )}
                    </Button>
                  </div>
                )}
              </div>
            </div>
          ) : (
            <div className="p-4 rounded-xl bg-slate-50 border border-slate-200 text-center space-y-2">
              <div className="w-8 h-8 rounded-full bg-slate-100 text-slate-500 mx-auto flex items-center justify-center">
                <Scale className="w-4 h-4" />
              </div>
              <h4 className="text-xs font-bold text-slate-800">Weighment In Progress</h4>
              <p className="text-[11px] text-slate-500 max-w-sm mx-auto">
                Electronic weighbridge certificate and vehicle tare/gross tickets will be recorded at origin loading point prior to in-transit departure.
              </p>
            </div>
          )}
        </section>

        {/* Read-Only Disclaimer & Audit Seal */}
        <div className="p-3 rounded-xl bg-slate-50/70 border border-slate-200/60 flex items-start gap-2.5 text-[11px] text-slate-500">
          <ShieldCheck className="w-4 h-4 text-[#0284C7] shrink-0 mt-0.5" />
          <div className="space-y-0.5 leading-relaxed">
            <span className="font-bold text-slate-700 block">
              Tamper-Sealed Quality & Weighment Guarantee
            </span>
            <p>
              {data.disclaimer} All documents are cryptographically verified by the assigned Broker Desk. For physical discrepancies, please prepare delivery inspection documentation upon vehicle arrival.
            </p>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

/**
 * High-contrast badge for overall quality status
 */
function renderOverallStatusBadge(status: 'Verified' | 'Under Review' | 'Pending Review' | 'Missing') {
  switch (status) {
    case 'Verified':
      return (
        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-emerald-100 text-emerald-800 border border-emerald-300 shadow-2xs">
          <CheckCircle2 className="w-3.5 h-3.5 text-emerald-700" />
          Verified Quality & Weight
        </span>
      );
    case 'Under Review':
      return (
        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-sky-100 text-sky-800 border border-sky-300">
          <Clock className="w-3.5 h-3.5 text-sky-700" />
          Desk Audit Underway
        </span>
      );
    case 'Pending Review':
      return (
        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-amber-100 text-amber-800 border border-amber-300">
          <Clock className="w-3.5 h-3.5 text-amber-700" />
          Pending Broker Review
        </span>
      );
    case 'Missing':
    default:
      return (
        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-slate-100 text-slate-700 border border-slate-300">
          <AlertCircle className="w-3.5 h-3.5 text-slate-600" />
          Awaiting Records
        </span>
      );
  }
}

/**
 * High-contrast badge for scientific lab status
 */
function renderLabStatusBadge(status: LabVerificationStatus) {
  switch (status) {
    case 'Verified':
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">
          <CheckCircle2 className="w-3 h-3 text-emerald-600" />
          Lab Certified
        </span>
      );
    case 'Under Review':
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-sky-50 text-sky-700 border border-sky-200">
          <Clock className="w-3 h-3 text-sky-600" />
          Under Review
        </span>
      );
    case 'Pending Broker Review':
    case 'Sample Pending':
    case 'Testing In Progress':
    case 'Report Uploaded':
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-amber-50 text-amber-700 border border-amber-200">
          <Clock className="w-3 h-3 text-amber-600" />
          Pending Broker Review
        </span>
      );
    case 'Rejected':
    case 'Correction Required':
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-rose-50 text-rose-700 border border-rose-200">
          <AlertTriangle className="w-3 h-3 text-rose-600" />
          Correction Required
        </span>
      );
    case 'Expired':
    case 'Missing':
    default:
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-slate-100 text-slate-700 border border-slate-200">
          <AlertCircle className="w-3 h-3 text-slate-500" />
          Missing Lab Evidence
        </span>
      );
  }
}

/**
 * High-contrast badge for weighment status
 */
function renderWeighmentStatusBadge(status: WeighmentStatus) {
  switch (status) {
    case 'Verified':
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">
          <CheckCircle2 className="w-3 h-3 text-emerald-600" />
          Weighment Verified
        </span>
      );
    case 'Recorded':
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-sky-50 text-sky-700 border border-sky-200">
          <Scale className="w-3 h-3 text-sky-600" />
          Slip Recorded
        </span>
      );
    case 'Discrepancy Detected':
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-rose-50 text-rose-700 border border-rose-200">
          <AlertTriangle className="w-3 h-3 text-rose-600" />
          Discrepancy
        </span>
      );
    case 'Pending Weighment':
    case 'Missing':
    default:
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-slate-100 text-slate-700 border border-slate-200">
          <Clock className="w-3 h-3 text-slate-500" />
          Awaiting Scale
        </span>
      );
  }
}
