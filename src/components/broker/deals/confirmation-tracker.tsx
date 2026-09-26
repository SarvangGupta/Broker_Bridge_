'use client';

import React, { useState, useEffect, useTransition } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import {
  CheckCircle2,
  Clock,
  Send,
  Lock,
  ShieldCheck,
  AlertCircle,
  FileCheck2,
  Loader2,
  Building2,
  Building,
  Sparkles,
  ArrowRight,
} from 'lucide-react';
import { toast } from 'sonner';
import {
  dispatchDealForConfirmationAction,
  getConfirmationStatusAction,
  type ConfirmationStatusData,
} from '@/src/server/actions/broker-confirmation-actions';
import { finalizeDealAction } from '@/src/server/actions/finalization-actions';
import { createIdempotentBookingAction } from '@/src/server/actions/booking-actions';

interface ConfirmationTrackerProps {
  requestId: string;
  initialData?: ConfirmationStatusData;
}

export function ConfirmationTracker({ requestId, initialData }: ConfirmationTrackerProps) {
  const [statusData, setStatusData] = useState<ConfirmationStatusData | null>(initialData || null);
  const [isLoading, setIsLoading] = useState<boolean>(!initialData);
  const [isDispatching, setIsDispatching] = useState<boolean>(false);
  const [isFinalizing, setIsFinalizing] = useState<boolean>(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  const fetchStatus = async () => {
    setIsLoading(true);
    const res = await getConfirmationStatusAction(requestId);
    if (res.success && res.data) {
      setStatusData(res.data);
    } else if (res.error) {
      setErrorMessage(res.error);
    }
    setIsLoading(false);
  };

  useEffect(() => {
    if (!initialData) {
      fetchStatus();
    }
  }, [requestId]);

  const handleDispatch = async () => {
    setIsDispatching(true);
    setErrorMessage(null);
    setSuccessMessage(null);

    const res = await dispatchDealForConfirmationAction(requestId);
    if (res.success) {
      setSuccessMessage(res.message || 'Deal snapshot dispatched to Buyer and Seller!');
      toast.success('Deal snapshot dispatched for signatures!');
      await fetchStatus();
    } else {
      setErrorMessage(res.error || 'Failed to dispatch deal.');
      toast.error(res.error || 'Failed to dispatch deal.');
    }
    setIsDispatching(false);
  };

  const handleFinalize = async () => {
    setIsFinalizing(true);
    setErrorMessage(null);
    setSuccessMessage(null);

    const versionNum = statusData?.latestVersionNumber || 1;

    try {
      // 1. Call finalizeDealAction with requestId and expectedVersion
      const finalizeRes = await finalizeDealAction(requestId, versionNum);

      if (!finalizeRes.success) {
        const errorMsg = finalizeRes.error || 'Pre-flight finalization gate blocked.';

        if (errorMsg.includes('STALE_VERSION_DETECTED')) {
          toast.error('STALE VERSION DETECTED: Deal terms were updated in another session. Refreshing...', { duration: 5000 });
        } else if (errorMsg.includes('MISSING_SELLER_CONFIRMATION')) {
          toast.error('MISSING SELLER CONFIRMATION: Seller must confirm terms before finalization.');
        } else {
          toast.error(errorMsg);
        }

        setErrorMessage(errorMsg);
        await fetchStatus();
        setIsFinalizing(false);
        return;
      }

      // 2. Call createIdempotentBookingAction
      const bookingRes = await createIdempotentBookingAction(requestId);

      if (bookingRes.success && bookingRes.bookingId) {
        toast.success(`🎉 Contract finalized! Booking ${bookingRes.bookingId} issued.`);
        setSuccessMessage(`Contract finalized and Booking ${bookingRes.bookingId} issued!`);
        await fetchStatus();
      } else {
        const errorMsg = bookingRes.error || 'Failed to issue booking reference.';
        toast.error(errorMsg);
        setErrorMessage(errorMsg);
      }
    } catch (err: any) {
      toast.error(`Finalization error: ${err.message || 'Execution failed.'}`);
      setErrorMessage(err.message || 'Execution failed.');
    } finally {
      setIsFinalizing(false);
    }
  };

  if (isLoading) {
    return (
      <Card className="border-slate-200 animate-pulse bg-white p-6 space-y-4">
        <div className="h-6 bg-slate-200 rounded-md w-1/3"></div>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div className="h-28 bg-slate-100 rounded-xl"></div>
          <div className="h-28 bg-slate-100 rounded-xl"></div>
        </div>
        <div className="h-12 bg-slate-200 rounded-xl"></div>
      </Card>
    );
  }

  const buyerConfirmed = statusData?.buyerConfirmed || false;
  const sellerConfirmed = statusData?.sellerConfirmed || false;
  const isFullyConfirmed = statusData?.isFullyConfirmed || (buyerConfirmed && sellerConfirmed);

  return (
    <Card className="border-slate-200/80 bg-white shadow-xs text-slate-900 w-full overflow-hidden">
      <CardHeader className="bg-slate-900 text-white pb-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
          <div>
            <CardTitle className="text-base sm:text-lg font-bold flex items-center gap-2">
              <ShieldCheck className="w-5 h-5 text-teal-400" />
              Dual Confirmation & Pre-Flight Gate Tracker (26.3 & 26.4)
            </CardTitle>
            <CardDescription className="text-xs text-slate-400 mt-0.5">
              Track separate Buyer & Seller digital signatures before issuing official booking.
            </CardDescription>
          </div>

          <Badge
            className={`self-start sm:self-auto text-xs font-mono font-bold px-3 py-1 ${
              isFullyConfirmed
                ? 'bg-emerald-500/20 text-emerald-300 border-emerald-400/40'
                : 'bg-amber-500/20 text-amber-300 border-amber-400/40'
            }`}
          >
            {isFullyConfirmed ? '2/2 Both Confirmed' : buyerConfirmed || sellerConfirmed ? '1/2 Partial Confirmation' : '0/2 Awaiting Signatures'}
          </Badge>
        </div>
      </CardHeader>

      <CardContent className="p-4 sm:p-6 space-y-6">
        {/* Alerts */}
        {errorMessage && (
          <div className="p-3.5 rounded-xl bg-red-50 border border-red-200 text-red-700 flex items-start gap-2.5 text-xs">
            <AlertCircle className="w-4 h-4 text-red-600 shrink-0 mt-0.5" />
            <div className="flex-1 font-medium">{errorMessage}</div>
          </div>
        )}

        {successMessage && (
          <div className="p-3.5 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 flex items-start gap-2.5 text-xs">
            <ShieldCheck className="w-4 h-4 text-emerald-600 shrink-0 mt-0.5" />
            <div className="flex-1 font-medium">{successMessage}</div>
          </div>
        )}

        {/* TASK 2: SIDE-BY-SIDE CONFIRMATION TRACKING CARDS */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {/* LEFT SIDE: BUYER CONFIRMATION */}
          <div
            className={`p-4 rounded-xl border transition-all ${
              buyerConfirmed
                ? 'bg-emerald-50/60 border-emerald-200 text-emerald-950'
                : 'bg-amber-50/60 border-amber-200 text-amber-950'
            }`}
          >
            <div className="flex items-center justify-between gap-2 mb-2">
              <span className="text-xs font-bold uppercase tracking-wider flex items-center gap-1.5 text-slate-700">
                <Building className="w-4 h-4 text-blue-600" />
                Buyer Confirmation
              </span>
              <Badge
                className={`text-[11px] font-bold ${
                  buyerConfirmed
                    ? 'bg-emerald-100 text-emerald-800 border-emerald-300'
                    : 'bg-amber-100 text-amber-800 border-amber-300'
                }`}
              >
                {buyerConfirmed ? (
                  <>
                    <CheckCircle2 className="w-3 h-3 mr-1 inline text-emerald-600" />
                    Confirmed
                  </>
                ) : (
                  <>
                    <Clock className="w-3 h-3 mr-1 inline text-amber-600" />
                    Pending Signature
                  </>
                )}
              </Badge>
            </div>

            <p className="text-xs text-slate-600">
              {buyerConfirmed
                ? 'Buyer has digitally signed and accepted contract terms.'
                : 'Awaiting Buyer digital signature on contract snapshot.'}
            </p>

            {statusData?.buyerConfirmedAt && (
              <p className="text-[10px] font-mono text-slate-500 mt-2">
                Confirmed: {new Date(statusData.buyerConfirmedAt).toLocaleString('en-IN')}
              </p>
            )}
          </div>

          {/* RIGHT SIDE: SELLER CONFIRMATION */}
          <div
            className={`p-4 rounded-xl border transition-all ${
              sellerConfirmed
                ? 'bg-emerald-50/60 border-emerald-200 text-emerald-950'
                : 'bg-amber-50/60 border-amber-200 text-amber-950'
            }`}
          >
            <div className="flex items-center justify-between gap-2 mb-2">
              <span className="text-xs font-bold uppercase tracking-wider flex items-center gap-1.5 text-slate-700">
                <Building2 className="w-4 h-4 text-teal-600" />
                Seller Confirmation
              </span>
              <Badge
                className={`text-[11px] font-bold ${
                  sellerConfirmed
                    ? 'bg-emerald-100 text-emerald-800 border-emerald-300'
                    : 'bg-amber-100 text-amber-800 border-amber-300'
                }`}
              >
                {sellerConfirmed ? (
                  <>
                    <CheckCircle2 className="w-3 h-3 mr-1 inline text-emerald-600" />
                    Confirmed
                  </>
                ) : (
                  <>
                    <Clock className="w-3 h-3 mr-1 inline text-amber-600" />
                    Pending Signature
                  </>
                )}
              </Badge>
            </div>

            <p className="text-xs text-slate-600">
              {sellerConfirmed
                ? 'Seller has digitally signed and accepted contract terms.'
                : 'Awaiting Seller digital signature on contract snapshot.'}
            </p>

            {statusData?.sellerConfirmedAt && (
              <p className="text-[10px] font-mono text-slate-500 mt-2">
                Confirmed: {new Date(statusData.sellerConfirmedAt).toLocaleString('en-IN')}
              </p>
            )}
          </div>
        </div>

        {/* PRIMARY DISPATCH BUTTON (IF NOT YET FULLY CONFIRMED) */}
        {!isFullyConfirmed && (
          <div className="pt-2">
            <Button
              onClick={handleDispatch}
              disabled={isDispatching}
              className="w-full h-12 min-h-[48px] bg-[#0D9488] hover:bg-[#0D9488]/90 text-white font-bold text-sm rounded-xl shadow-xs flex items-center justify-center gap-2 cursor-pointer"
            >
              {isDispatching ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  <span>Dispatching for Signatures...</span>
                </>
              ) : (
                <>
                  <Send className="w-4 h-4" />
                  <span>Dispatch for Signatures (Buyer & Seller Notifications)</span>
                </>
              )}
            </Button>
          </div>
        )}

        {/* TASK 3: THE PRE-FLIGHT FINALIZATION GATE BLOCK (26.4) */}
        <div className="border-t border-slate-200 pt-5 space-y-3">
          <div className="flex items-center justify-between">
            <h4 className="text-sm font-bold text-slate-900 flex items-center gap-2">
              <Lock className={`w-4 h-4 ${isFullyConfirmed ? 'text-teal-600' : 'text-slate-400'}`} />
              Pre-Flight Finalization Gate
            </h4>
            {statusData?.bookingReference && (
              <Badge className="bg-teal-100 text-teal-800 border-teal-300 font-mono text-xs">
                Booking: {statusData.bookingReference}
              </Badge>
            )}
          </div>

          <Button
            onClick={handleFinalize}
            disabled={!isFullyConfirmed || isFinalizing}
            className={`w-full h-12 min-h-[48px] font-bold text-sm rounded-xl transition-all flex items-center justify-center gap-2 ${
              isFullyConfirmed
                ? 'bg-[#0D9488] hover:bg-[#0D9488]/90 text-white shadow-md cursor-pointer'
                : 'bg-slate-100 text-slate-400 border border-slate-200 cursor-not-allowed'
            }`}
          >
            {isFinalizing ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" />
                <span>Finalizing & Issuing Booking...</span>
              </>
            ) : (
              <>
                <FileCheck2 className="w-4 h-4" />
                <span>Finalize & Generate Booking</span>
                <ArrowRight className="w-4 h-4 ml-1" />
              </>
            )}
          </Button>

          <p className="text-[11px] text-slate-500 text-center leading-relaxed">
            Requires explicit digital confirmation from both parties before booking can be issued.
          </p>
        </div>
      </CardContent>
    </Card>
  );
}
