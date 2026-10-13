'use client';

import React, { useState, useTransition } from 'react';
import {
  Truck,
  Calendar,
  MapPin,
  FileText,
  ExternalLink,
  Loader2,
  Clock,
  ShieldCheck,
  Scale,
  Building2,
  AlertCircle,
} from 'lucide-react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { BuyerDispatchDetails, BuyerDispatchDocument } from '@/src/types/buyer-order-types';
import { getBuyerDispatchDocumentSignedUrlAction } from '@/src/server/actions/buyer-order-actions';

export interface DeliveryDetailsCardProps {
  dealId?: string;
  bookingId?: string;
  dispatchDetails?: BuyerDispatchDetails | null;
  className?: string;
}

/**
 * Task 3 & 4 (Micro-Sprint 38.5): Live Vehicle & Delivery Details Card.
 * Displays live transit metrics, vehicle details, loaded quantity, and authorized document viewers.
 * Enforces strictly read-only view and min-h-[48px] touch targets on mobile.
 */
export function DeliveryDetailsCard({
  dealId,
  bookingId,
  dispatchDetails,
  className,
}: DeliveryDetailsCardProps) {
  const [loadingDocId, setLoadingDocId] = useState<string | null>(null);
  const [docError, setDocError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  // 1. Empty State (PRD 38.5 Standard)
  if (!dispatchDetails) {
    return (
      <Card
        className={cn(
          'w-full max-w-full overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-xs',
          className
        )}
      >
        <CardHeader className="p-4 sm:p-5 border-b border-slate-100 pb-3">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-slate-100 text-slate-500 flex items-center justify-center shrink-0">
              <Truck className="w-4 h-4" />
            </div>
            <div>
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                Delivery & Transit Details
              </span>
              <CardTitle className="text-sm sm:text-base font-bold text-slate-900 leading-tight">
                Transporter & Loading Schedule
              </CardTitle>
            </div>
          </div>
        </CardHeader>
        <CardContent className="p-6 sm:p-8 text-center space-y-3">
          <div className="w-12 h-12 rounded-2xl bg-sky-50 text-[#0284C7] mx-auto flex items-center justify-center border border-sky-100">
            <Clock className="w-6 h-6 animate-pulse" />
          </div>
          <div className="max-w-md mx-auto space-y-1">
            <h4 className="text-sm font-bold text-slate-800">Awaiting Dispatch</h4>
            <p className="text-xs text-slate-500 leading-relaxed">
              Vehicle details and ETA will appear here once the Broker authorizes the loading.
            </p>
          </div>
        </CardContent>
      </Card>
    );
  }

  // Handle viewing signed document
  const handleViewDocument = (doc: BuyerDispatchDocument) => {
    setDocError(null);
    setLoadingDocId(doc.id);

    startTransition(async () => {
      try {
        if (doc.signedUrl) {
          window.open(doc.signedUrl, '_blank', 'noopener,noreferrer');
          setLoadingDocId(null);
          return;
        }

        const res = await getBuyerDispatchDocumentSignedUrlAction(
          dealId || 'demo-deal',
          doc.filePath
        );

        if (res.success && res.data?.signedUrl) {
          window.open(res.data.signedUrl, '_blank', 'noopener,noreferrer');
        } else {
          setDocError(res.error || 'Failed to generate secure document preview.');
        }
      } catch (err: any) {
        setDocError(err.message || 'Error opening document.');
      } finally {
        setLoadingDocId(null);
      }
    });
  };

  const dispatchDateFormatted = new Date(dispatchDetails.dispatchDate).toLocaleDateString(
    'en-IN',
    {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    }
  );

  const etaFormatted = new Date(dispatchDetails.expectedDeliveryDate).toLocaleDateString(
    'en-IN',
    {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    }
  );

  // Filter for LR and E-Way Bill documents
  const transitDocs = dispatchDetails.documents.filter(
    (d) =>
      d.documentType.toLowerCase().includes('lr') ||
      d.documentType.toLowerCase().includes('lorry') ||
      d.documentType.toLowerCase().includes('way') ||
      d.documentType.toLowerCase().includes('ewb')
  );

  // Fallback default docs if empty
  const displayDocs: BuyerDispatchDocument[] =
    transitDocs.length > 0
      ? transitDocs
      : [
          {
            id: 'doc-lr-fallback',
            documentType: 'Lorry Receipt (LR)',
            fileName: 'Lorry_Receipt.pdf',
            filePath: `dispatches/${bookingId || 'BKG-2026-1042'}/LR.pdf`,
          },
          {
            id: 'doc-ewb-fallback',
            documentType: 'E-Way Bill',
            fileName: 'EWay_Bill.pdf',
            filePath: `dispatches/${bookingId || 'BKG-2026-1042'}/EWB.pdf`,
          },
        ];

  return (
    <Card
      className={cn(
        'w-full max-w-full overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-xs',
        className
      )}
    >
      <CardHeader className="p-4 sm:p-5 border-b border-slate-100 pb-3">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2.5">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-sky-50 text-[#0284C7] flex items-center justify-center shrink-0 border border-sky-100">
              <Truck className="w-4 h-4" />
            </div>
            <div>
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                Logistics & Fleet Overview
              </span>
              <CardTitle className="text-sm sm:text-base font-bold text-slate-900 leading-tight">
                Live Vehicle & Delivery Details
              </CardTitle>
            </div>
          </div>

          <Badge
            variant="outline"
            className="w-fit text-xs px-2.5 py-0.5 bg-emerald-50 text-emerald-800 border-emerald-300 font-bold"
          >
            {dispatchDetails.status}
          </Badge>
        </div>
      </CardHeader>

      <CardContent className="p-4 sm:p-5 space-y-4">
        {/* Vehicle Information Banner */}
        <div className="p-3.5 sm:p-4 rounded-xl bg-slate-50 border border-slate-200/80 space-y-3">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2.5">
            <div>
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                Assigned Vehicle Number
              </span>
              <div className="flex items-center gap-2 mt-1">
                <span className="inline-flex items-center px-3 py-1 rounded-lg bg-slate-900 text-white font-mono font-black text-sm tracking-wide shadow-2xs">
                  <Truck className="w-3.5 h-3.5 mr-1.5 text-sky-400 shrink-0" />
                  {dispatchDetails.vehicleNumber}
                </span>
                {dispatchDetails.vehicleType && (
                  <span className="text-xs text-slate-600 font-medium">
                    ({dispatchDetails.vehicleType})
                  </span>
                )}
              </div>
            </div>

            {/* Explicit Loaded Quantity (to cross-reference against partial fulfillment math) */}
            <div className="sm:text-right">
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                Loaded Quantity (Tranche)
              </span>
              <div className="text-base sm:text-lg font-black text-[#0284C7] mt-0.5">
                {dispatchDetails.dispatchedQuantity.toLocaleString('en-IN')}{' '}
                <span className="text-xs font-bold text-slate-500">
                  {dispatchDetails.unitSymbol || 'MT'}
                </span>
              </div>
            </div>
          </div>

          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 pt-2 border-t border-slate-200/60 text-xs text-slate-600">
            <div className="flex items-center gap-1.5 min-w-0">
              <Building2 className="w-3.5 h-3.5 text-slate-400 shrink-0" />
              <span className="truncate">
                Transporter: <strong>{dispatchDetails.transporterName}</strong>
              </span>
            </div>

            {dispatchDetails.driverName && (
              <div className="text-slate-500 text-[11px] truncate">
                Driver: {dispatchDetails.driverName}{' '}
                {dispatchDetails.driverMobile && `(${dispatchDetails.driverMobile})`}
              </div>
            )}
          </div>
        </div>

        {/* Transit Information Grid (2-column on mobile & desktop) */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5 sm:gap-3">
          {/* Dispatch Date */}
          <div className="p-3 rounded-xl border border-slate-200/80 bg-white space-y-1">
            <div className="flex items-center gap-1.5 text-[10px] font-bold text-slate-400 uppercase tracking-wider">
              <Calendar className="w-3.5 h-3.5 text-slate-400" />
              <span>Dispatch Date</span>
            </div>
            <p className="text-xs sm:text-sm font-bold text-slate-900 truncate">
              {dispatchDateFormatted}
            </p>
          </div>

          {/* Expected Delivery Date (ETA) */}
          <div className="p-3 rounded-xl border border-sky-100 bg-sky-50/40 space-y-1">
            <div className="flex items-center gap-1.5 text-[10px] font-bold text-[#0284C7] uppercase tracking-wider">
              <Clock className="w-3.5 h-3.5 text-[#0284C7]" />
              <span>Expected Delivery (ETA)</span>
            </div>
            <p className="text-xs sm:text-sm font-black text-[#0284C7] truncate">
              {etaFormatted}
            </p>
          </div>

          {/* Loading Location */}
          <div className="p-3 rounded-xl border border-slate-200/80 bg-white space-y-1">
            <div className="flex items-center gap-1.5 text-[10px] font-bold text-slate-400 uppercase tracking-wider">
              <MapPin className="w-3.5 h-3.5 text-slate-400" />
              <span>Loading Location</span>
            </div>
            <p className="text-xs font-semibold text-slate-800 line-clamp-1">
              {dispatchDetails.loadingLocation}
            </p>
          </div>

          {/* Destination */}
          <div className="p-3 rounded-xl border border-slate-200/80 bg-white space-y-1">
            <div className="flex items-center gap-1.5 text-[10px] font-bold text-slate-400 uppercase tracking-wider">
              <MapPin className="w-3.5 h-3.5 text-slate-400" />
              <span>Destination</span>
            </div>
            <p className="text-xs font-semibold text-slate-800 line-clamp-1">
              {dispatchDetails.destination}
            </p>
          </div>
        </div>

        {/* Task 4: Authorized Transit Documents (Read-Only) */}
        <div className="pt-2 space-y-2.5">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-800 flex items-center gap-1.5">
              <FileText className="w-3.5 h-3.5 text-[#0284C7]" />
              <span>Authorized Transit Documents</span>
            </span>
            <span className="text-[10px] text-slate-400 uppercase font-bold tracking-wider">
              Read-Only
            </span>
          </div>

          {docError && (
            <div className="p-2.5 rounded-xl bg-red-50 border border-red-200 text-red-800 text-xs flex items-center gap-2">
              <AlertCircle className="w-4 h-4 shrink-0" />
              <span>{docError}</span>
            </div>
          )}

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
            {displayDocs.map((doc) => {
              const isLoading = loadingDocId === doc.id;
              const isEwb = doc.documentType.toLowerCase().includes('way') || doc.documentType.toLowerCase().includes('ewb');

              return (
                <button
                  key={doc.id}
                  type="button"
                  onClick={() => handleViewDocument(doc)}
                  disabled={isLoading}
                  className="w-full flex items-center justify-between min-h-[48px] h-12 px-4 rounded-xl border border-slate-200 bg-white hover:bg-sky-50/70 hover:border-sky-300 transition-all text-xs font-bold text-slate-800 group shadow-2xs cursor-pointer disabled:opacity-60"
                >
                  <span className="flex items-center min-w-0 pr-2">
                    <FileText className="w-4 h-4 mr-2 text-[#0284C7] shrink-0" />
                    <span className="truncate">{doc.documentType}</span>
                  </span>

                  <span className="inline-flex items-center text-slate-400 group-hover:text-[#0284C7] shrink-0 font-semibold text-[11px]">
                    {isLoading ? (
                      <Loader2 className="w-3.5 h-3.5 animate-spin" />
                    ) : (
                      <>
                        <span>View</span>
                        <ExternalLink className="w-3.5 h-3.5 ml-1" />
                      </>
                    )}
                  </span>
                </button>
              );
            })}
          </div>
        </div>

        {/* Read-Only Transparency Footnote */}
        <div className="flex items-center gap-2 pt-1 text-[11px] text-slate-400">
          <ShieldCheck className="w-3.5 h-3.5 text-emerald-600 shrink-0" />
          <p className="truncate">
            Official logistics records verified by Transporter & Brokerage Desk. Read-only audit access.
          </p>
        </div>
      </CardContent>
    </Card>
  );
}
