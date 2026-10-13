'use client';

import React, { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import {
  Check,
  CheckCircle2,
  AlertTriangle,
  ShieldCheck,
  FileSignature,
  Loader2,
  RefreshCw,
  Lock,
  ArrowRight,
  Clock,
} from 'lucide-react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { toast } from 'sonner';
import { cn } from '@/lib/utils';
import { DealConfirmationStatus } from '@/src/types/buyer-deal-review';
import {
  confirmFinalDealAction,
  requestDealAmendmentAction,
} from '@/src/server/actions/buyer-deal-actions';

interface FinalConfirmationActionsProps {
  dealId: string;
  versionNumber: number;
  status: DealConfirmationStatus;
  confirmedAt?: string | null;
  className?: string;
}

function formatDate(dateStr?: string | null): string {
  if (!dateStr) return 'Recently';
  try {
    const d = new Date(dateStr);
    if (isNaN(d.getTime())) return String(dateStr);
    return d.toLocaleDateString('en-IN', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return String(dateStr);
  }
}

/**
 * Task 2 & Task 3: Buyer Final Confirmation Action Bar (Micro-Sprint 37.2)
 * 
 * Strict Guardrails:
 * 1. 48px Touch Targets: All buttons enforce min-h-[48px] for 360px mobile usability.
 * 2. Concurrency Guard: Prompts refresh toast on STALE_VERSION_DETECTED.
 * 3. Terminal State Guard: Hides action buttons in terminal states and renders semantic banners.
 * 4. Architecture Isolation: Clarifies that Buyer confirmation unlocks Broker final booking.
 */
export function FinalConfirmationActions({
  dealId,
  versionNumber,
  status,
  confirmedAt,
  className,
}: FinalConfirmationActionsProps) {
  const router = useRouter();

  // Transitions
  const [isConfirmPending, startConfirmTransition] = useTransition();
  const [isAmendmentPending, startAmendmentTransition] = useTransition();

  // Dialog States
  const [isConfirmDialogOpen, setIsConfirmDialogOpen] = useState(false);
  const [isAmendmentDialogOpen, setIsAmendmentDialogOpen] = useState(false);
  const [amendmentReason, setAmendmentReason] = useState('');

  // Terminal state check
  const isBuyerConfirmed = status === 'Buyer Confirmed';
  const isFullyConfirmed = status === 'Confirmed';
  const isAmendmentRequired = status === 'Amendment Required';
  const isTerminal = isBuyerConfirmed || isFullyConfirmed || isAmendmentRequired;

  // 1. Confirm Deal Handler
  const handleConfirmDeal = () => {
    startConfirmTransition(async () => {
      try {
        const res = await confirmFinalDealAction(dealId, versionNumber);

        if (res.success) {
          toast.success(
            res.message || 'Deal confirmed successfully! Broker finalization gate unlocked.'
          );
          setIsConfirmDialogOpen(false);
          router.refresh();
        } else if (res.error === 'STALE_VERSION_DETECTED') {
          toast.error(
            res.message || 'The Broker has updated this deal. Please refresh to view the latest terms.',
            {
              action: {
                label: 'Refresh Page',
                onClick: () => router.refresh(),
              },
              duration: 8000,
            }
          );
          setIsConfirmDialogOpen(false);
        } else {
          toast.error(res.error || 'Failed to confirm final deal.');
        }
      } catch (err: any) {
        toast.error(err.message || 'An unexpected error occurred while confirming deal.');
      }
    });
  };

  // 2. Request Amendment Handler
  const handleRequestAmendment = () => {
    if (amendmentReason.trim().length < 5) {
      toast.error('Please specify a detailed reason for the amendment request (min 5 characters).');
      return;
    }

    startAmendmentTransition(async () => {
      try {
        const res = await requestDealAmendmentAction(dealId, versionNumber, amendmentReason.trim());

        if (res.success) {
          toast.success(
            res.message || 'Amendment request submitted to the Broker desk.'
          );
          setIsAmendmentDialogOpen(false);
          setAmendmentReason('');
          router.refresh();
        } else if (res.error === 'STALE_VERSION_DETECTED') {
          toast.error(
            res.message || 'The Broker has updated this deal snapshot. Please refresh to review latest terms.',
            {
              action: {
                label: 'Refresh Page',
                onClick: () => router.refresh(),
              },
              duration: 8000,
            }
          );
          setIsAmendmentDialogOpen(false);
        } else {
          toast.error(res.error || 'Failed to submit amendment request.');
        }
      } catch (err: any) {
        toast.error(err.message || 'An unexpected error occurred while requesting amendment.');
      }
    });
  };

  return (
    <>
      {/* Sticky Bottom Action Bar */}
      <footer
        className={cn(
          'fixed bottom-0 left-0 right-0 z-40 bg-white/95 backdrop-blur-md border-t border-slate-200 shadow-xl p-3 sm:p-4',
          className
        )}
      >
        <div className="max-w-4xl mx-auto flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3">
          {/* TASK 3: TERMINAL STATE GUARDS */}
          {isTerminal ? (
            <div className="w-full flex flex-col xs:flex-row items-start xs:items-center justify-between gap-3">
              {isBuyerConfirmed ? (
                <div className="flex items-center gap-2.5 px-4 py-2.5 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-900 text-xs sm:text-sm font-semibold w-full">
                  <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0" />
                  <div className="min-w-0">
                    <span>
                      You confirmed Snapshot v{versionNumber} on <strong>{formatDate(confirmedAt)}</strong>.
                    </span>
                    <span className="block text-[11px] text-emerald-700 font-normal">
                      Awaiting Broker finalization to execute system Booking.
                    </span>
                  </div>
                </div>
              ) : isFullyConfirmed ? (
                <div className="flex items-center gap-2.5 px-4 py-2.5 rounded-xl bg-emerald-100/80 border border-emerald-300 text-emerald-950 text-xs sm:text-sm font-semibold w-full">
                  <ShieldCheck className="w-5 h-5 text-emerald-700 shrink-0" />
                  <div className="min-w-0">
                    <span>
                      Mutual Commercial Agreement <strong>Confirmed</strong>.
                    </span>
                    <span className="block text-[11px] text-emerald-800 font-normal">
                      Order has been locked and released for dispatch planning.
                    </span>
                  </div>
                </div>
              ) : (
                <div className="flex items-center gap-2.5 px-4 py-2.5 rounded-xl bg-amber-50 border border-amber-300 text-amber-900 text-xs sm:text-sm font-semibold w-full">
                  <AlertTriangle className="w-5 h-5 text-amber-600 shrink-0" />
                  <div className="min-w-0">
                    <span>
                      Amendment Requested for Snapshot v{versionNumber}.
                    </span>
                    <span className="block text-[11px] text-amber-700 font-normal">
                      The Broker desk has been notified to revise commercial parameters.
                    </span>
                  </div>
                </div>
              )}
            </div>
          ) : (
            /* NON-TERMINAL ACTION CONTROLS */
            <>
              {/* Left Context Label */}
              <div className="hidden sm:flex items-center gap-2 text-xs text-slate-500">
                <FileSignature className="w-4 h-4 text-[#0284C7]" />
                <span>
                  Snapshot <strong>v{versionNumber}</strong> ready for official confirmation
                </span>
              </div>

              {/* Right Action Buttons Triad */}
              <div className="flex flex-col xs:flex-row items-stretch xs:items-center gap-2.5 w-full sm:w-auto">
                {/* 1. Request Amendment Button */}
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setIsAmendmentDialogOpen(true)}
                  disabled={isConfirmPending || isAmendmentPending}
                  className="min-h-[48px] h-12 px-4 rounded-xl text-slate-700 hover:text-amber-800 hover:bg-amber-50 border-slate-200 text-xs sm:text-sm font-semibold transition-colors cursor-pointer w-full xs:w-auto"
                >
                  <AlertTriangle className="w-4 h-4 mr-1.5 text-amber-600" />
                  <span>Request Amendment</span>
                </Button>

                {/* 2. Confirm Final Deal Button (Ocean Blue #0284C7) */}
                <Button
                  type="button"
                  onClick={() => setIsConfirmDialogOpen(true)}
                  disabled={isConfirmPending || isAmendmentPending}
                  className="min-h-[48px] h-12 px-6 rounded-xl bg-[#0284C7] hover:bg-[#0369A1] active:bg-[#075985] text-white text-xs sm:text-sm font-bold shadow-xs hover:shadow transition-all cursor-pointer w-full xs:w-auto"
                >
                  {isConfirmPending ? (
                    <Loader2 className="w-4 h-4 mr-1.5 animate-spin" />
                  ) : (
                    <Check className="w-4 h-4 mr-1.5" />
                  )}
                  <span>Confirm Final Deal</span>
                </Button>
              </div>
            </>
          )}
        </div>
      </footer>

      {/* 1. Confirmation Modal Dialog */}
      <Dialog open={isConfirmDialogOpen} onOpenChange={setIsConfirmDialogOpen}>
        <DialogContent className="w-full max-w-md p-5 sm:p-6 rounded-2xl bg-white border border-slate-200 shadow-xl">
          <DialogHeader className="pb-3 border-b border-slate-100">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-lg bg-sky-50 text-[#0284C7] flex items-center justify-center border border-sky-100 shrink-0">
                <FileSignature className="w-4 h-4" />
              </div>
              <DialogTitle className="text-base sm:text-lg font-bold text-slate-900">
                Confirm Deal Snapshot v{versionNumber}
              </DialogTitle>
            </div>
            <DialogDescription className="text-xs text-slate-500 pt-1">
              You are officially recording commercial confirmation for these agreed terms.
            </DialogDescription>
          </DialogHeader>

          <div className="py-3 space-y-3 text-xs sm:text-sm text-slate-600">
            <p>
              By clicking <strong>Confirm Deal</strong>, your digital signature will be appended to the immutable audit log and the Broker finalization gate will be unlocked.
            </p>

            <div className="p-3 rounded-xl bg-amber-50/80 border border-amber-200/80 text-amber-900 text-xs space-y-1">
              <div className="flex items-center gap-1.5 font-bold">
                <Lock className="w-3.5 h-3.5 text-amber-600 shrink-0" />
                <span>Architecture Guardrail Notice</span>
              </div>
              <p className="text-[11px] text-amber-800 leading-relaxed">
                Buyer confirmation records mutual commercial agreement. System Booking is executed exclusively by the Broker desk upon two-party verification.
              </p>
            </div>
          </div>

          <DialogFooter className="mt-2 pt-3 border-t border-slate-100 flex flex-col-reverse sm:flex-row sm:justify-end gap-2.5 bg-transparent m-0 p-0">
            <Button
              type="button"
              variant="outline"
              onClick={() => setIsConfirmDialogOpen(false)}
              disabled={isConfirmPending}
              className="min-h-[48px] h-12 px-5 rounded-xl text-xs sm:text-sm font-semibold border-slate-200 text-slate-700 hover:bg-slate-100 w-full sm:w-auto cursor-pointer"
            >
              Cancel
            </Button>
            <Button
              type="button"
              onClick={handleConfirmDeal}
              disabled={isConfirmPending}
              className="min-h-[48px] h-12 px-6 rounded-xl bg-[#0284C7] hover:bg-[#0369A1] text-white text-xs sm:text-sm font-bold shadow-xs w-full sm:w-auto cursor-pointer"
            >
              {isConfirmPending ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  <span>Recording Confirmation...</span>
                </>
              ) : (
                <>
                  <Check className="w-4 h-4 mr-1.5" />
                  <span>Confirm Deal</span>
                </>
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* 2. Amendment Request Modal Dialog */}
      <Dialog open={isAmendmentDialogOpen} onOpenChange={setIsAmendmentDialogOpen}>
        <DialogContent className="w-full max-w-md p-5 sm:p-6 rounded-2xl bg-white border border-slate-200 shadow-xl">
          <DialogHeader className="pb-3 border-b border-slate-100">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-lg bg-amber-50 text-amber-600 flex items-center justify-center border border-amber-100 shrink-0">
                <AlertTriangle className="w-4 h-4" />
              </div>
              <DialogTitle className="text-base sm:text-lg font-bold text-slate-900">
                Request Commercial Amendment
              </DialogTitle>
            </div>
            <DialogDescription className="text-xs text-slate-500 pt-1">
              Specify the commercial parameters you require revised by the Broker desk.
            </DialogDescription>
          </DialogHeader>

          <div className="py-3 space-y-3">
            <div className="space-y-1.5">
              <label
                htmlFor="amendment-reason"
                className="text-xs font-bold text-slate-800 flex items-center justify-between"
              >
                <span>Amendment Feedback & Required Changes *</span>
                <span className="text-[11px] text-slate-400 font-normal">
                  {amendmentReason.length} / 500 chars
                </span>
              </label>

              <Textarea
                id="amendment-reason"
                placeholder="Specify required modifications (e.g., Target rate reduction to ₹24,000/MT, shift delivery window by 3 days, adjust moisture limit to 11.5%)..."
                value={amendmentReason}
                onChange={(e) => setAmendmentReason(e.target.value.slice(0, 500))}
                className="min-h-[110px] p-3 text-xs sm:text-sm rounded-xl border border-slate-200 focus-visible:border-[#0284C7] focus-visible:ring-1 focus-visible:ring-[#0284C7]"
                disabled={isAmendmentPending}
              />
              <span className="text-[10px] text-slate-400 block">
                Minimum 5 characters. This feedback is logged into the audit ledger and dispatched to your Broker desk.
              </span>
            </div>
          </div>

          <DialogFooter className="mt-2 pt-3 border-t border-slate-100 flex flex-col-reverse sm:flex-row sm:justify-end gap-2.5 bg-transparent m-0 p-0">
            <Button
              type="button"
              variant="outline"
              onClick={() => setIsAmendmentDialogOpen(false)}
              disabled={isAmendmentPending}
              className="min-h-[48px] h-12 px-5 rounded-xl text-xs sm:text-sm font-semibold border-slate-200 text-slate-700 hover:bg-slate-100 w-full sm:w-auto cursor-pointer"
            >
              Cancel
            </Button>
            <Button
              type="button"
              onClick={handleRequestAmendment}
              disabled={isAmendmentPending || amendmentReason.trim().length < 5}
              className="min-h-[48px] h-12 px-6 rounded-xl bg-amber-600 hover:bg-amber-700 text-white text-xs sm:text-sm font-bold shadow-xs w-full sm:w-auto cursor-pointer"
            >
              {isAmendmentPending ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  <span>Submitting Request...</span>
                </>
              ) : (
                <>
                  <AlertTriangle className="w-4 h-4 mr-1.5" />
                  <span>Submit Amendment</span>
                </>
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
