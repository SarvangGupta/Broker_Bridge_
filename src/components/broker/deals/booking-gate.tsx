'use client';

import React, { useState, useEffect, useTransition } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import {
  ShieldCheck,
  CheckCircle2,
  Clock,
  AlertCircle,
  Lock,
  FileCheck2,
  Loader2,
  PackageCheck,
  CalendarCheck,
  Building,
  Building2,
  ArrowRight,
  Copy,
  Check,
  Truck,
  Sparkles,
  RefreshCw,
} from 'lucide-react';
import { toast } from 'sonner';
import { useRouter } from 'next/navigation';
import { finalizeDealAction } from '@/src/server/actions/finalization-actions';
import {
  createIdempotentBookingAction,
  getBookingByDealIdAction,
} from '@/src/server/actions/booking-actions';
import {
  getConfirmationStatusAction,
  type ConfirmationStatusData,
} from '@/src/server/actions/broker-confirmation-actions';
import { getBrokerDealContextAction } from '@/src/server/actions/broker-deal-actions';

interface BookingGateProps {
  requestId: string;
  expectedVersion?: number;
  initialBookingId?: string | null;
  onBookingSuccess?: (bookingId: string) => void;
}

export interface PreFlightCheckItem {
  id: 'seller_confirm' | 'buyer_confirm' | 'inventory_check' | 'expiry_check';
  label: string;
  subtitle: string;
  isPassed: boolean;
  statusText: string;
  iconType: 'seller' | 'buyer' | 'inventory' | 'expiry';
}

export function BookingGate({
  requestId,
  expectedVersion,
  initialBookingId,
  onBookingSuccess,
}: BookingGateProps) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [statusData, setStatusData] = useState<ConfirmationStatusData | null>(null);
  const [dealContext, setDealContext] = useState<any>(null);
  const [bookingId, setBookingId] = useState<string | null>(initialBookingId || null);
  const [copied, setCopied] = useState<boolean>(false);
  const [generalError, setGeneralError] = useState<string | null>(null);

  // Fetch deal status, version number, inventory status, and existing booking
  const loadGateData = async () => {
    setIsLoading(true);
    setGeneralError(null);

    try {
      // 1. Fetch confirmation status
      const statusRes = await getConfirmationStatusAction(requestId);
      if (statusRes.success && statusRes.data) {
        setStatusData(statusRes.data);
        if (statusRes.data.bookingReference) {
          setBookingId(statusRes.data.bookingReference);
        }
      }

      // 2. Fetch deal context (for version & inventory details)
      const ctxRes = await getBrokerDealContextAction(requestId);
      if (ctxRes.success && ctxRes.data) {
        setDealContext(ctxRes.data);
      }

      // 3. Fetch existing booking if not already set
      if (!initialBookingId) {
        const bookingRes = await getBookingByDealIdAction(requestId);
        if (bookingRes.success && bookingRes.bookingId) {
          setBookingId(bookingRes.bookingId);
        }
      }
    } catch (err: any) {
      console.error('Error loading booking gate data:', err);
      setGeneralError('Failed to load pre-flight validation status. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadGateData();
  }, [requestId]);

  // Derive Checklist items
  const buyerConfirmed = statusData?.buyerConfirmed || false;
  const sellerConfirmed = statusData?.sellerConfirmed || false;

  // Inventory check: Lot linked, active, and quantity > 0
  const hasLotLinked = Boolean(dealContext?.sellerAvailabilityId || dealContext?.lotId || statusData?.snapshot?.lotId);
  const isQuantityValid = Number(dealContext?.quantity || statusData?.snapshot?.quantity || 0) > 0;
  const isInventoryPassed = hasLotLinked && isQuantityValid;

  // Expiry check: Status is not expired/canceled, delivery date valid
  const currentStatus = statusData?.currentStatus || dealContext?.currentStatus || 'Proposed';
  const isStatusCancelled = currentStatus.toLowerCase().includes('cancel') || currentStatus.toLowerCase().includes('expire') || currentStatus.toLowerCase().includes('supersed');
  
  const deliveryDateStr = dealContext?.deliveryDate || statusData?.snapshot?.deliveryDate;
  const isDateValid = deliveryDateStr ? new Date(deliveryDateStr).getTime() > (Date.now() - 86400000) : true;
  const isExpiryPassed = !isStatusCancelled && isDateValid;

  const versionNumber = expectedVersion || statusData?.latestVersionNumber || dealContext?.expectedVersionNumber || 1;

  // All 4 checklist conditions required to enable primary action
  const isAllChecksPassed = buyerConfirmed && sellerConfirmed && isInventoryPassed && isExpiryPassed;

  // Copy booking ID helper
  const handleCopyBookingId = () => {
    if (!bookingId) return;
    navigator.clipboard.writeText(bookingId);
    setCopied(true);
    toast.success(`Booking ID ${bookingId} copied to clipboard!`);
    setTimeout(() => setCopied(false), 2000);
  };

  // Task 2: Handle Finalize & Generate Booking Trigger
  const handleFinalizeAndCreateBooking = () => {
    if (!isAllChecksPassed && !bookingId) {
      toast.error('Pre-Flight Gate Blocked: All 4 verification requirements must pass before issuing booking.');
      return;
    }

    setGeneralError(null);

    startTransition(async () => {
      try {
        // Step A: Call Sprint 18 finalizeDealAction
        const finalizeRes = await finalizeDealAction(requestId, versionNumber);

        if (!finalizeRes.success) {
          const errorMsg = finalizeRes.error || 'Finalization failed.';
          
          if (errorMsg.includes('STALE_VERSION_DETECTED')) {
            toast.error('STALE VERSION DETECTED: Deal terms were modified in another session. Refreshing workspace...', {
              duration: 5000,
            });
            await loadGateData();
            return;
          }

          if (errorMsg.includes('MISSING_SELLER_CONFIRMATION') || errorMsg.includes('Pre-Flight Gate')) {
            toast.error(`FINALIZATION BLOCKED: ${errorMsg}`);
            return;
          }

          toast.error(`Finalization Gate Error: ${errorMsg}`);
          return;
        }

        // Step B: Call Sprint 18 createIdempotentBookingAction
        const bookingRes = await createIdempotentBookingAction(requestId);

        if (!bookingRes.success || !bookingRes.bookingId) {
          const errorMsg = bookingRes.error || 'Failed to issue booking ID.';
          toast.error(`Booking Generation Error: ${errorMsg}`);
          return;
        }

        const issuedBookingId = bookingRes.bookingId;
        setBookingId(issuedBookingId);
        toast.success(`🎉 Booking ${issuedBookingId} successfully created and locked!`);

        if (onBookingSuccess) {
          onBookingSuccess(issuedBookingId);
        }

        // Refresh client data
        await loadGateData();
      } catch (err: any) {
        console.error('Finalization trigger error:', err);
        toast.error(`Unexpected execution error: ${err.message || 'Action failed.'}`);
      }
    });
  };

  if (isLoading) {
    return (
      <Card className="border-slate-200/80 bg-white p-6 space-y-4 animate-pulse">
        <div className="h-6 bg-slate-200 rounded-md w-1/3"></div>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div className="h-24 bg-slate-100 rounded-xl"></div>
          <div className="h-24 bg-slate-100 rounded-xl"></div>
          <div className="h-24 bg-slate-100 rounded-xl"></div>
          <div className="h-24 bg-slate-100 rounded-xl"></div>
        </div>
        <div className="h-12 bg-slate-200 rounded-xl"></div>
      </Card>
    );
  }

  // Task 3: SUCCESS STATE & POST-BOOKING HANDOFF VIEW
  if (bookingId) {
    return (
      <Card className="border-teal-200 bg-linear-to-b from-teal-50/60 via-white to-white shadow-md text-slate-900 w-full overflow-hidden">
        {/* SUCCESS HEADER BADGE */}
        <CardHeader className="bg-slate-900 text-white pb-4 border-b border-slate-800">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div>
              <div className="flex items-center gap-2">
                <Badge className="bg-[#0D9488] text-white text-[10px] font-bold uppercase tracking-wider px-2.5 py-0.5">
                  <ShieldCheck className="w-3.5 h-3.5 mr-1" />
                  Deal Finalized & Locked
                </Badge>
                <span className="text-xs font-mono text-teal-400">v{versionNumber}</span>
              </div>
              <CardTitle className="text-lg sm:text-xl font-bold mt-1 text-white flex items-center gap-2">
                Booking Reference Issued
              </CardTitle>
              <CardDescription className="text-xs text-slate-400">
                Official booking reference issued. Transaction is locked for order fulfillment.
              </CardDescription>
            </div>

            <Badge className="bg-emerald-500/20 text-emerald-300 border-emerald-400/40 text-xs font-mono font-bold px-3 py-1 self-start sm:self-auto">
              LOCKED & CONFIRMED
            </Badge>
          </div>
        </CardHeader>

        <CardContent className="p-4 sm:p-6 space-y-6">
          {/* HIGHLY VISIBLE LOCKED BOOKING ID CARD */}
          <div className="p-4 sm:p-5 rounded-2xl bg-teal-900/10 border-2 border-[#0D9488]/40 flex flex-col sm:flex-row sm:items-center justify-between gap-4 shadow-xs">
            <div className="flex items-center gap-3.5">
              <div className="w-12 h-12 rounded-xl bg-[#0D9488] text-white flex items-center justify-center shrink-0 shadow-sm">
                <Lock className="w-6 h-6 text-teal-100" />
              </div>
              <div>
                <span className="text-[11px] font-bold uppercase tracking-wider text-teal-800">
                  Official Booking Reference
                </span>
                <div className="text-xl sm:text-2xl font-black font-mono tracking-tight text-slate-900 flex items-center gap-2 mt-0.5">
                  <span>{bookingId}</span>
                </div>
              </div>
            </div>

            <Button
              onClick={handleCopyBookingId}
              variant="outline"
              size="sm"
              className="h-12 px-4 border-teal-300 bg-white text-teal-800 hover:bg-teal-50 font-semibold text-xs rounded-xl flex items-center gap-2 cursor-pointer self-start sm:self-auto min-h-[48px]"
            >
              {copied ? (
                <>
                  <Check className="w-4 h-4 text-emerald-600" />
                  <span>Copied!</span>
                </>
              ) : (
                <>
                  <Copy className="w-4 h-4 text-[#0D9488]" />
                  <span>Copy Reference</span>
                </>
              )}
            </Button>
          </div>

          {/* VERIFIED CHECKLIST RECAP */}
          <div className="bg-slate-50 border border-slate-200/80 rounded-xl p-3.5 sm:p-4 space-y-2">
            <h4 className="text-xs font-bold uppercase tracking-wider text-slate-700 flex items-center gap-1.5 mb-2">
              <FileCheck2 className="w-4 h-4 text-[#0D9488]" />
              Pre-Flight Validation Record
            </h4>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs">
              <div className="flex items-center gap-2 text-emerald-800 font-medium">
                <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
                <span>Seller Digital Signature Verified</span>
              </div>
              <div className="flex items-center gap-2 text-emerald-800 font-medium">
                <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
                <span>Buyer Digital Signature Verified</span>
              </div>
              <div className="flex items-center gap-2 text-emerald-800 font-medium">
                <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
                <span>Lot Inventory Reserved & Locked</span>
              </div>
              <div className="flex items-center gap-2 text-emerald-800 font-medium">
                <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
                <span>Contract Validity Period Verified</span>
              </div>
            </div>
          </div>

          {/* POST-BOOKING CALL TO ACTION HANDOFF */}
          <div className="pt-2 flex flex-col sm:flex-row items-center gap-3">
            <Button
              onClick={() => router.push('/broker/orders')}
              className="w-full sm:flex-1 h-12 min-h-[48px] bg-[#0D9488] hover:bg-[#0D9488]/90 text-white font-bold text-sm rounded-xl shadow-md flex items-center justify-center gap-2 cursor-pointer transition-all"
            >
              <Truck className="w-4 h-4" />
              <span>Proceed to Order Operations</span>
              <ArrowRight className="w-4 h-4 ml-1" />
            </Button>

            <Button
              onClick={() => router.push('/broker/work')}
              variant="outline"
              className="w-full sm:w-auto h-12 min-h-[48px] border-slate-300 text-slate-700 hover:bg-slate-100 font-semibold text-xs sm:text-sm rounded-xl flex items-center justify-center px-5 cursor-pointer"
            >
              Back to Work Inbox
            </Button>
          </div>
        </CardContent>
      </Card>
    );
  }

  // TASK 1: THE BOOKING VALIDATION CHECKLIST & TRIGGER VIEW
  return (
    <Card className="border-slate-200/80 bg-white shadow-xs text-slate-900 w-full overflow-hidden">
      {/* HEADER */}
      <CardHeader className="bg-slate-900 text-white pb-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div>
            <CardTitle className="text-base sm:text-lg font-bold flex items-center gap-2">
              <ShieldCheck className="w-5 h-5 text-teal-400" />
              Broker Booking & Pre-Flight Finalization Gate
            </CardTitle>
            <CardDescription className="text-xs text-slate-400 mt-0.5">
              Verify counterparty signoffs, inventory reservation, and contract rules before issuing booking.
            </CardDescription>
          </div>

          <div className="flex items-center gap-2 self-start sm:self-auto">
            <Badge className="bg-slate-800 text-slate-300 border-slate-700 text-xs font-mono">
              Version {versionNumber}
            </Badge>
            <Badge
              className={`text-xs font-mono font-bold px-3 py-1 ${
                isAllChecksPassed
                  ? 'bg-emerald-500/20 text-emerald-300 border-emerald-400/40'
                  : 'bg-amber-500/20 text-amber-300 border-amber-400/40'
              }`}
            >
              {isAllChecksPassed ? '4/4 Ready to Finalize' : 'Action Required'}
            </Badge>
          </div>
        </div>
      </CardHeader>

      <CardContent className="p-4 sm:p-6 space-y-6">
        {/* AUTHORIZATION NOTICE */}
        <div className="p-3.5 rounded-xl bg-teal-50/80 border border-teal-200 text-teal-900 text-xs flex items-start gap-2.5">
          <ShieldCheck className="w-4 h-4 text-[#0D9488] shrink-0 mt-0.5" />
          <div className="leading-relaxed">
            <span className="font-bold">Broker Authorization Guardrail:</span> You are authorized to issue the official booking reference only when both Buyer and Seller have explicitly confirmed contract terms and inventory is locked.
          </div>
        </div>

        {/* ERROR DISPLAY */}
        {generalError && (
          <div className="p-3.5 rounded-xl bg-red-50 border border-red-200 text-red-700 flex items-start gap-2.5 text-xs">
            <AlertCircle className="w-4 h-4 text-red-600 shrink-0 mt-0.5" />
            <div className="flex-1 font-medium">{generalError}</div>
          </div>
        )}

        {/* TASK 1: STRICT VISUAL CHECKLIST CARDS */}
        <div>
          <h4 className="text-xs font-bold uppercase tracking-wider text-slate-700 mb-3 flex items-center justify-between">
            <span>Pre-Flight Validation Checklist</span>
            <button
              onClick={loadGateData}
              className="text-[11px] font-normal text-teal-700 hover:text-teal-900 flex items-center gap-1 cursor-pointer"
            >
              <RefreshCw className="w-3 h-3" />
              Refresh Status
            </button>
          </h4>

          {/* 360px MOBILE-RESPONSIVE STACKED / GRID LAYOUT */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 sm:gap-4">
            {/* 1. SELLER CONFIRMATION */}
            <div
              className={`p-4 rounded-xl border transition-all ${
                sellerConfirmed
                  ? 'bg-emerald-50/60 border-emerald-200 text-emerald-950'
                  : 'bg-amber-50/60 border-amber-200 text-amber-950'
              }`}
            >
              <div className="flex items-center justify-between gap-2 mb-1.5">
                <span className="text-xs font-bold uppercase tracking-wider flex items-center gap-1.5 text-slate-800">
                  <Building2 className="w-4 h-4 text-teal-600" />
                  1. Seller Confirmation
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
                      Pending
                    </>
                  )}
                </Badge>
              </div>
              <p className="text-xs text-slate-600 leading-relaxed">
                {sellerConfirmed
                  ? 'Seller has digitally signed & confirmed commercial terms.'
                  : 'Awaiting Seller digital signature on contract snapshot.'}
              </p>
            </div>

            {/* 2. BUYER CONFIRMATION */}
            <div
              className={`p-4 rounded-xl border transition-all ${
                buyerConfirmed
                  ? 'bg-emerald-50/60 border-emerald-200 text-emerald-950'
                  : 'bg-amber-50/60 border-amber-200 text-amber-950'
              }`}
            >
              <div className="flex items-center justify-between gap-2 mb-1.5">
                <span className="text-xs font-bold uppercase tracking-wider flex items-center gap-1.5 text-slate-800">
                  <Building className="w-4 h-4 text-blue-600" />
                  2. Buyer Confirmation
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
                      Pending
                    </>
                  )}
                </Badge>
              </div>
              <p className="text-xs text-slate-600 leading-relaxed">
                {buyerConfirmed
                  ? 'Buyer has digitally signed & confirmed landed rate terms.'
                  : 'Awaiting Buyer digital signature on contract snapshot.'}
              </p>
            </div>

            {/* 3. INVENTORY AVAILABILITY CHECK */}
            <div
              className={`p-4 rounded-xl border transition-all ${
                isInventoryPassed
                  ? 'bg-emerald-50/60 border-emerald-200 text-emerald-950'
                  : 'bg-amber-50/60 border-amber-200 text-amber-950'
              }`}
            >
              <div className="flex items-center justify-between gap-2 mb-1.5">
                <span className="text-xs font-bold uppercase tracking-wider flex items-center gap-1.5 text-slate-800">
                  <PackageCheck className="w-4 h-4 text-emerald-600" />
                  3. Inventory Check
                </span>
                <Badge
                  className={`text-[11px] font-bold ${
                    isInventoryPassed
                      ? 'bg-emerald-100 text-emerald-800 border-emerald-300'
                      : 'bg-amber-100 text-amber-800 border-amber-300'
                  }`}
                >
                  {isInventoryPassed ? (
                    <>
                      <CheckCircle2 className="w-3 h-3 mr-1 inline text-emerald-600" />
                      Verified
                    </>
                  ) : (
                    <>
                      <AlertCircle className="w-3 h-3 mr-1 inline text-amber-600" />
                      Check Lot
                    </>
                  )}
                </Badge>
              </div>
              <p className="text-xs text-slate-600 leading-relaxed">
                {isInventoryPassed
                  ? `Lot inventory confirmed (${dealContext?.quantity || statusData?.snapshot?.quantity || 'Requested'} MT available).`
                  : 'Verification required: Supply lot or quantity parameters incomplete.'}
              </p>
            </div>

            {/* 4. EXPIRY & CANCELLATION CONDITION CHECK */}
            <div
              className={`p-4 rounded-xl border transition-all ${
                isExpiryPassed
                  ? 'bg-emerald-50/60 border-emerald-200 text-emerald-950'
                  : 'bg-amber-50/60 border-amber-200 text-amber-950'
              }`}
            >
              <div className="flex items-center justify-between gap-2 mb-1.5">
                <span className="text-xs font-bold uppercase tracking-wider flex items-center gap-1.5 text-slate-800">
                  <CalendarCheck className="w-4 h-4 text-purple-600" />
                  4. Validity & Expiry
                </span>
                <Badge
                  className={`text-[11px] font-bold ${
                    isExpiryPassed
                      ? 'bg-emerald-100 text-emerald-800 border-emerald-300'
                      : 'bg-amber-100 text-amber-800 border-amber-300'
                  }`}
                >
                  {isExpiryPassed ? (
                    <>
                      <CheckCircle2 className="w-3 h-3 mr-1 inline text-emerald-600" />
                      Valid
                    </>
                  ) : (
                    <>
                      <AlertCircle className="w-3 h-3 mr-1 inline text-amber-600" />
                      Expired/Canceled
                    </>
                  )}
                </Badge>
              </div>
              <p className="text-xs text-slate-600 leading-relaxed">
                {isExpiryPassed
                  ? 'Deal version is active, un-canceled, and within validity date.'
                  : 'Deal version is expired, canceled, or superseded.'}
              </p>
            </div>
          </div>
        </div>

        {/* TASK 2: THE PRIMARY FINALIZATION TRIGGER BUTTON */}
        <div className="border-t border-slate-200 pt-5 space-y-3">
          <Button
            onClick={handleFinalizeAndCreateBooking}
            disabled={!isAllChecksPassed || isPending}
            className={`w-full h-12 min-h-[48px] font-bold text-sm rounded-xl transition-all flex items-center justify-center gap-2 ${
              isAllChecksPassed
                ? 'bg-[#0D9488] hover:bg-[#0D9488]/90 text-white shadow-md cursor-pointer'
                : 'bg-slate-100 text-slate-400 border border-slate-200 cursor-not-allowed'
            }`}
          >
            {isPending ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin text-white" />
                <span>Finalizing & Generating Booking...</span>
              </>
            ) : (
              <>
                <FileCheck2 className="w-4 h-4" />
                <span>Finalize & Generate Booking</span>
                <ArrowRight className="w-4 h-4 ml-1" />
              </>
            )}
          </Button>

          {!isAllChecksPassed && (
            <p className="text-[11px] text-amber-700 bg-amber-50 border border-amber-200/60 p-2.5 rounded-lg text-center leading-relaxed">
              <strong>Finalization Blocked:</strong> All 4 pre-flight checks above must be green before the booking can be generated.
            </p>
          )}

          {isAllChecksPassed && (
            <p className="text-[11px] text-slate-500 text-center leading-relaxed">
              Clicking <strong>"Finalize & Generate Booking"</strong> will issue an immutable Booking Reference and reserve lot inventory.
            </p>
          )}
        </div>
      </CardContent>
    </Card>
  );
}
