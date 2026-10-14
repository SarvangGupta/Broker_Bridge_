'use client';

import React, { useState, useEffect, useTransition } from 'react';
import {
  FileText,
  FileCheck,
  FolderCheck,
  CheckCircle2,
  Clock,
  AlertCircle,
  AlertTriangle,
  ExternalLink,
  Loader2,
  ShieldCheck,
  Scale,
  Truck,
  Receipt,
  FileSpreadsheet,
  RefreshCw,
} from 'lucide-react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import {
  BuyerDocumentComplianceItem,
  BuyerDocumentMatrixData,
  DocumentComplianceStatus,
} from '@/src/types/buyer-document-types';
import {
  getBuyerDocumentMatrixAction,
  getBuyerDocumentSignedUrlAction,
} from '@/src/server/actions/buyer-document-actions';

export interface TransactionDocumentVaultProps {
  bookingId: string;
  initialData?: BuyerDocumentMatrixData | null;
  className?: string;
}

/**
 * Task 2 (Micro-Sprint 39.2): Buyer Transaction Document Vault UI.
 * 
 * Renders the read-only document compliance matrix comparing the Buyer's
 * original checklist (`requirement_documents`) against the files the Seller uploaded (`dispatch_documents`).
 * 
 * Strict Guardrails:
 * - Strictly read-only compliance viewer: zero upload capability.
 * - Mobile-first: stacks cleanly using flex-col on 360px viewports without horizontal scrolling.
 * - Touch targets: min-h-[48px] on all action triggers.
 * - Tenant isolation: only accessible to authenticated buyer owning the booking.
 */
export function TransactionDocumentVault({
  bookingId,
  initialData,
  className,
}: TransactionDocumentVaultProps) {
  const [data, setData] = useState<BuyerDocumentMatrixData | null>(initialData || null);
  const [loading, setLoading] = useState<boolean>(!initialData);
  const [error, setError] = useState<string | null>(null);

  // Document preview state
  const [activeDocId, setActiveDocId] = useState<string | null>(null);
  const [previewError, setPreviewError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  // Load document matrix if not provided as initialData
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
        const res = await getBuyerDocumentMatrixAction(bookingId);
        if (!isMounted) return;

        if (res.success && res.data) {
          setData(res.data);
        } else {
          setError(res.error || 'Failed to load document compliance matrix.');
        }
      } catch (err: any) {
        if (!isMounted) return;
        setError(err.message || 'An unexpected error occurred while loading document vault.');
      } finally {
        if (isMounted) setLoading(false);
      }
    }

    loadData();

    return () => {
      isMounted = false;
    };
  }, [bookingId, initialData]);

  // Handle viewing a document securely
  const handleViewDocument = (doc: BuyerDocumentComplianceItem) => {
    setPreviewError(null);
    setActiveDocId(doc.id);

    startTransition(async () => {
      try {
        if (doc.signedUrl) {
          window.open(doc.signedUrl, '_blank', 'noopener,noreferrer');
          setActiveDocId(null);
          return;
        }

        if (doc.fileUrl) {
          const res = await getBuyerDocumentSignedUrlAction(bookingId, doc.fileUrl);
          if (res.success && res.data?.signedUrl) {
            window.open(res.data.signedUrl, '_blank', 'noopener,noreferrer');
          } else {
            setPreviewError(res.error || 'Unable to generate secure document preview link.');
          }
        } else {
          setPreviewError('This document has not been uploaded yet.');
        }
      } catch (err: any) {
        setPreviewError(err.message || 'Failed to open document preview.');
      } finally {
        setActiveDocId(null);
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
            Checking document compliance checklist and verification records...
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
              <FolderCheck className="w-4 h-4" />
            </div>
            <div>
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                Compliance Vault
              </span>
              <CardTitle className="text-sm sm:text-base font-bold text-slate-900 leading-tight">
                Fulfillment Documents & Compliance
              </CardTitle>
            </div>
          </div>
        </CardHeader>
        <CardContent className="p-6 text-center space-y-4">
          <div className="w-10 h-10 rounded-full bg-amber-50 text-amber-600 mx-auto flex items-center justify-center">
            <AlertCircle className="w-5 h-5" />
          </div>
          <div className="space-y-1 max-w-md mx-auto">
            <h4 className="text-xs sm:text-sm font-bold text-slate-800">Document Records Unavailable</h4>
            <p className="text-xs text-slate-500 leading-relaxed">
              {error || 'Unable to retrieve document compliance records for this booking.'}
            </p>
          </div>
          <Button
            variant="outline"
            onClick={async () => {
              setLoading(true);
              setError(null);
              const res = await getBuyerDocumentMatrixAction(bookingId);
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
            Retry Fetching Documents
          </Button>
        </CardContent>
      </Card>
    );
  }

  const { documents, totalRequired, totalVerified, totalUploaded, totalMissing, compliancePercentage } = data;

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
            <div className="w-8 h-8 rounded-xl bg-sky-50 text-[#0284C7] flex items-center justify-center shrink-0 border border-sky-100">
              <FolderCheck className="w-4 h-4" />
            </div>
            <div>
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                Fulfillment Compliance
              </span>
              <CardTitle className="text-sm sm:text-base font-bold text-slate-900 leading-tight">
                Fulfillment Documents & Compliance
              </CardTitle>
            </div>
          </div>

          <div className="flex items-center gap-2 self-start sm:self-auto">
            {totalMissing > 0 ? (
              <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-amber-50 text-amber-800 border border-amber-300">
                <AlertTriangle className="w-3.5 h-3.5 text-amber-600" />
                {totalMissing} Document{totalMissing > 1 ? 's' : ''} Missing
              </span>
            ) : compliancePercentage === 100 ? (
              <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-emerald-50 text-emerald-800 border border-emerald-300">
                <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" />
                100% Compliant
              </span>
            ) : (
              <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-sky-50 text-sky-800 border border-sky-300">
                <Clock className="w-3.5 h-3.5 text-sky-600" />
                {totalVerified} of {totalRequired} Verified
              </span>
            )}
          </div>
        </div>
      </CardHeader>

      <CardContent className="p-4 sm:p-5 space-y-5">
        {/* Preview Error Banner */}
        {previewError && (
          <div className="p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2 animate-in fade-in">
            <AlertCircle className="w-4 h-4 shrink-0" />
            <span className="flex-1 font-medium">{previewError}</span>
            <button
              onClick={() => setPreviewError(null)}
              className="text-rose-500 hover:text-rose-800 text-[11px] font-bold px-1"
            >
              Dismiss
            </button>
          </div>
        )}

        {/* Compliance Progress Bar & Metrics */}
        <div className="rounded-xl bg-slate-50 border border-slate-200/80 p-3.5 space-y-2.5">
          <div className="flex items-center justify-between text-xs font-bold text-slate-800">
            <span>Checklist Fulfillment Progress</span>
            <span className="font-mono text-[#0284C7]">{compliancePercentage}%</span>
          </div>

          {/* Visual Progress Bar */}
          <div className="w-full h-2 rounded-full bg-slate-200/80 overflow-hidden">
            <div
              className={cn(
                'h-full transition-all duration-500 rounded-full',
                compliancePercentage === 100 ? 'bg-emerald-500' : 'bg-[#0284C7]'
              )}
              style={{ width: `${Math.min(100, Math.max(5, compliancePercentage))}%` }}
            />
          </div>

          {/* Micro stat chips */}
          <div className="flex flex-wrap items-center gap-2 pt-1 text-[11px]">
            <span className="px-2 py-0.5 rounded-md bg-white border border-slate-200 text-slate-600 font-medium">
              Required: <strong className="text-slate-900">{totalRequired}</strong>
            </span>
            <span className="px-2 py-0.5 rounded-md bg-white border border-slate-200 text-emerald-700 font-medium">
              Verified: <strong className="text-emerald-800">{totalVerified}</strong>
            </span>
            {totalUploaded > totalVerified && (
              <span className="px-2 py-0.5 rounded-md bg-white border border-slate-200 text-sky-700 font-medium">
                Pending Audit: <strong className="text-sky-800">{totalUploaded - totalVerified}</strong>
              </span>
            )}
            {totalMissing > 0 && (
              <span className="px-2 py-0.5 rounded-md bg-white border border-slate-200 text-rose-700 font-medium">
                Missing: <strong className="text-rose-800">{totalMissing}</strong>
              </span>
            )}
          </div>
        </div>

        {/* Document Compliance Matrix List (Mobile-First: flex-col, break-words) */}
        <div className="space-y-2.5" role="list" aria-label="Fulfillment documents compliance checklist">
          {documents.map((doc) => {
            const hasFile = Boolean(doc.signedUrl || doc.fileUrl);
            const isRowLoading = isPending && activeDocId === doc.id;

            return (
              <div
                key={doc.id}
                role="listitem"
                className={cn(
                  'rounded-xl border p-3.5 transition-all flex flex-col sm:flex-row sm:items-center justify-between gap-3 shadow-2xs',
                  doc.status === 'Missing'
                    ? 'border-rose-200/80 bg-rose-50/20'
                    : doc.status === 'Verified'
                    ? 'border-slate-200 bg-white hover:border-slate-300'
                    : 'border-slate-200 bg-white'
                )}
              >
                {/* Left side: Icon, title, badges, and status description */}
                <div className="flex items-start gap-3 min-w-0 flex-1">
                  <div
                    className={cn(
                      'w-9 h-9 rounded-xl flex items-center justify-center shrink-0 mt-0.5 border',
                      getDocumentIconStyles(doc.status)
                    )}
                  >
                    {getDocumentCategoryIcon(doc.category, doc.documentType)}
                  </div>

                  <div className="space-y-1 min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-1.5">
                      <h4 className="text-xs sm:text-sm font-bold text-slate-900 break-words leading-snug">
                        {doc.displayName}
                      </h4>
                      {doc.isMandatory ? (
                        <span className="px-1.5 py-0.2 rounded text-[9px] font-bold bg-amber-50 text-amber-700 border border-amber-200 shrink-0">
                          Mandatory
                        </span>
                      ) : (
                        <span className="px-1.5 py-0.2 rounded text-[9px] font-medium bg-slate-100 text-slate-500 border border-slate-200 shrink-0">
                          Supplementary
                        </span>
                      )}
                    </div>

                    <p className="text-[11px] text-slate-500 leading-relaxed break-words">
                      {doc.statusDescription}
                    </p>

                    {/* Metadata chips (file name, upload time) */}
                    {doc.fileName && (
                      <div className="flex flex-wrap items-center gap-2 pt-0.5 text-[10px] text-slate-400 font-mono">
                        <span className="truncate max-w-[200px] sm:max-w-xs">{doc.fileName}</span>
                        {doc.uploadedAt && (
                          <span>
                            •{' '}
                            {new Date(doc.uploadedAt).toLocaleDateString('en-IN', {
                              day: '2-digit',
                              month: 'short',
                              year: 'numeric',
                            })}
                          </span>
                        )}
                      </div>
                    )}
                  </div>
                </div>

                {/* Right side: Status badge & Action Button */}
                <div className="flex items-center justify-between sm:justify-end gap-2 shrink-0 pt-2 sm:pt-0 border-t sm:border-t-0 border-slate-100">
                  <div className="shrink-0">{renderDocumentStatusBadge(doc.status)}</div>

                  {hasFile ? (
                    <Button
                      variant="ghost"
                      onClick={() => handleViewDocument(doc)}
                      disabled={isRowLoading}
                      className="min-h-[48px] h-12 px-3.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 text-slate-800 text-xs font-bold shadow-2xs transition-colors flex items-center justify-center gap-1.5 shrink-0"
                    >
                      {isRowLoading ? (
                        <>
                          <Loader2 className="w-4 h-4 text-[#0284C7] animate-spin" />
                          <span className="text-[11px]">Opening...</span>
                        </>
                      ) : (
                        <>
                          <FileText className="w-3.5 h-3.5 text-slate-500" />
                          <span className="text-[11px]">View Document</span>
                          <ExternalLink className="w-3 h-3 text-slate-400 ml-0.5" />
                        </>
                      )}
                    </Button>
                  ) : (
                    <div className="min-h-[48px] h-12 px-3 flex items-center justify-center text-[11px] font-medium text-slate-400 italic">
                      {doc.status === 'Missing' ? 'Upload Pending' : 'Awaiting Dispatch'}
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </div>

        {/* Read-Only Disclaimer & Audit Guarantee */}
        <div className="p-3 rounded-xl bg-slate-50/70 border border-slate-200/60 flex items-start gap-2.5 text-[11px] text-slate-500">
          <ShieldCheck className="w-4 h-4 text-[#0284C7] shrink-0 mt-0.5" />
          <div className="space-y-0.5 leading-relaxed">
            <span className="font-bold text-slate-700 block">
              Tamper-Sealed Document Vault & Compliance Guarantee
            </span>
            <p>
              {data.disclaimer} Document uploads are authenticated directly by the assigned Broker Desk before release into the Buyer vault. The Buyer workspace is strictly read-only.
            </p>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

/**
 * Returns high-contrast status badge corresponding to the calculated document state:
 * - Green for 'Verified'
 * - Blue for 'Received'
 * - Amber/Red for 'Missing'
 * - Gray for 'Required'
 */
function renderDocumentStatusBadge(status: DocumentComplianceStatus) {
  switch (status) {
    case 'Verified':
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold bg-emerald-50 text-emerald-700 border border-emerald-200 shadow-2xs">
          <CheckCircle2 className="w-3 h-3 text-emerald-600" />
          Verified
        </span>
      );
    case 'Received':
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold bg-sky-50 text-sky-700 border border-sky-200">
          <Clock className="w-3 h-3 text-sky-600" />
          Received
        </span>
      );
    case 'Missing':
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold bg-rose-50 text-rose-700 border border-rose-200">
          <AlertCircle className="w-3 h-3 text-rose-600" />
          Missing
        </span>
      );
    case 'Required':
    default:
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold bg-slate-100 text-slate-600 border border-slate-200">
          <Clock className="w-3 h-3 text-slate-500" />
          Required
        </span>
      );
  }
}

/**
 * Returns tailored icon depending on document category / type.
 */
function getDocumentCategoryIcon(category: string, type: string) {
  const norm = type.toLowerCase();
  if (norm.includes('lorry') || norm === 'lr') {
    return <Truck className="w-4 h-4" />;
  }
  if (norm.includes('weigh') || norm.includes('scale')) {
    return <Scale className="w-4 h-4" />;
  }
  if (norm.includes('invoice')) {
    return <Receipt className="w-4 h-4" />;
  }
  if (norm.includes('eway')) {
    return <FileSpreadsheet className="w-4 h-4" />;
  }
  if (norm.includes('analysis') || norm.includes('coa') || category === 'Quality') {
    return <FileCheck className="w-4 h-4" />;
  }
  return <FileText className="w-4 h-4" />;
}

/**
 * Dynamic container color styles for document icon.
 */
function getDocumentIconStyles(status: DocumentComplianceStatus): string {
  switch (status) {
    case 'Verified':
      return 'bg-emerald-50 text-emerald-600 border-emerald-100';
    case 'Received':
      return 'bg-sky-50 text-[#0284C7] border-sky-100';
    case 'Missing':
      return 'bg-rose-50 text-rose-600 border-rose-100';
    case 'Required':
    default:
      return 'bg-slate-100 text-slate-500 border-slate-200';
  }
}
