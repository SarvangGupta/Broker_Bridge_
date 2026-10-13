'use client';

import React, { useState, useTransition } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { 
  Check, 
  RefreshCw, 
  X, 
  CheckCircle2, 
  Clock, 
  AlertCircle, 
  ShieldCheck, 
  FileCheck2,
  Lock,
  Loader2,
  Info,
  ArrowRight
} from 'lucide-react';
import { BuyerProposalDetail } from '@/src/types/buyer-proposal';
import { ProposalCounterDrawer } from '@/src/components/buyer/proposals/proposal-counter-drawer';
import { ProposalRejectDialog } from '@/src/components/buyer/proposals/proposal-reject-dialog';
import { acceptBuyerProposalAction } from '@/src/server/actions/buyer-proposal-actions';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { toast } from 'sonner';
import { cn } from '@/lib/utils';

interface ProposalActionBarProps {
  proposal: BuyerProposalDetail;
  className?: string;
}

function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('en-IN', {
    maximumFractionDigits: 0,
  }).format(amount);
}

function formatDate(dateStr?: string | null): string {
  if (!dateStr) return 'Recent';
  const d = new Date(dateStr);
  return d.toLocaleDateString('en-IN', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
}

export function ProposalActionBar({ proposal, className }: ProposalActionBarProps) {
  const router = useRouter();
  const [isAcceptPending, startAcceptTransition] = useTransition();

  // Modals state
  const [isCounterOpen, setIsCounterOpen] = useState(false);
  const [isRejectOpen, setIsRejectOpen] = useState(false);
  const [isAcceptConfirmOpen, setIsAcceptConfirmOpen] = useState(false);

  const isTerminal = 
    proposal.status === 'Accepted' || 
    proposal.status === 'Rejected' || 
    proposal.status === 'Expired' || 
    proposal.isExpired;

  // Accept Proposal Handler
  const handleConfirmAccept = () => {
    startAcceptTransition(async () => {
      try {
        const res = await acceptBuyerProposalAction({
          proposalId: proposal.id,
          expectedVersionNumber: proposal.versionNumber,
        });

        if (res.success) {
          toast.success('Commercial proposal accepted successfully! Proceeding to contract generation.');
          setIsAcceptConfirmOpen(false);
          router.refresh();
        } else if (res.error === 'STALE_VERSION_DETECTED') {
          toast.error('The Broker has updated this proposal. Please refresh to review the latest terms.', {
            action: {
              label: 'Refresh',
              onClick: () => router.refresh(),
            },
            duration: 8000,
          });
          setIsAcceptConfirmOpen(false);
        } else {
          toast.error(res.error || 'Failed to accept proposal.');
        }
      } catch (err: any) {
        toast.error(err.message || 'An unexpected error occurred.');
      }
    });
  };

  return (
    <>
      {/* Action Bar Container: Fixed bottom on mobile, sticky clean bar on desktop */}
      <div
        className={cn(
          'fixed bottom-0 left-0 right-0 z-40 bg-white/95 backdrop-blur-md border-t border-slate-200 shadow-xl p-3 sm:p-4',
          className
        )}
      >
        <div className="max-w-7xl mx-auto flex flex-col md:flex-row items-center justify-between gap-3">
          {/* Left: Commercial Reminders or Terminal Status Banner */}
          {isTerminal ? (
            <div className="w-full md:w-auto flex items-center gap-3">
              {proposal.status === 'Accepted' ? (
                <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 w-full">
                  <div className="flex items-center gap-2.5 px-4 py-2.5 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-900 text-xs sm:text-sm font-semibold">
                    <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
                    <span>
                      This proposal was <strong>Accepted</strong> on {formatDate(proposal.updatedAt)}. Commercial snapshot locked.
                    </span>
                  </div>

                  <Link
                    href={`/buyer/deals/${proposal.dealId || proposal.id}/confirm`}
                    className="inline-flex items-center justify-center min-h-[48px] px-5 rounded-xl bg-[#0284C7] hover:bg-[#0369A1] active:bg-[#075985] text-white text-xs sm:text-sm font-bold shadow-xs transition-all shrink-0"
                  >
                    <FileCheck2 className="w-4 h-4 mr-2" />
                    <span>Proceed to Confirmation</span>
                    <ArrowRight className="w-3.5 h-3.5 ml-1.5" />
                  </Link>
                </div>
              ) : proposal.status === 'Rejected' ? (
                <div className="flex items-center gap-2.5 px-4 py-2.5 rounded-xl bg-rose-50/80 border border-rose-200 text-rose-900 text-xs sm:text-sm font-semibold">
                  <X className="w-4 h-4 text-rose-600 shrink-0" />
                  <span>
                    This commercial proposal was <strong>Declined</strong> on {formatDate(proposal.updatedAt)}.
                    {proposal.isArchived ? (
                      <span className="ml-1 text-rose-700/80 font-medium">
                        (Automatically archived from inbox to keep your workspace clean)
                      </span>
                    ) : proposal.autoCleanRemainingHours !== undefined ? (
                      <span className="ml-1 text-rose-700 font-medium">
                        • Auto-cleans from inbox in {proposal.autoCleanRemainingHours}h
                      </span>
                    ) : null}
                  </span>
                </div>
              ) : (
                <div className="flex items-center gap-2.5 px-4 py-2.5 rounded-xl bg-amber-50 border border-amber-200 text-amber-900 text-xs sm:text-sm font-semibold">
                  <Clock className="w-4 h-4 text-amber-600 shrink-0" />
                  <span>
                    This commercial proposal has <strong>Expired</strong>. Contact your Broker to request a refreshed quote.
                  </span>
                </div>
              )}
            </div>
          ) : (
            <div className="w-full md:w-auto flex items-center justify-between md:justify-start gap-4">
              <div>
                <span className="text-[11px] font-semibold text-slate-400 block uppercase tracking-wider">
                  Net Landed Rate
                </span>
                <div className="text-base sm:text-lg font-black text-[#0284C7] leading-tight">
                  ₹{formatCurrency(proposal.netLandedPricePerUnit)}
                  <span className="text-xs font-normal text-slate-500 ml-1">
                    / {proposal.unitSymbol}
                  </span>
                </div>
              </div>

              <div className="hidden sm:block h-8 w-px bg-slate-200" />

              <div className="hidden sm:block">
                <span className="text-[11px] font-semibold text-slate-400 block uppercase tracking-wider">
                  Total Valuation
                </span>
                <span className="text-sm sm:text-base font-bold text-slate-800 block">
                  ₹{formatCurrency(proposal.totalEstimatedValue)}
                </span>
              </div>
            </div>
          )}

          {/* Right: Action Buttons Triad (Disabled if terminal) */}
          {!isTerminal && (
            <div className="w-full md:w-auto flex flex-col xs:flex-row items-stretch sm:items-center gap-2">
              {/* 1. Reject Proposal Button */}
              <Button
                type="button"
                variant="outline"
                onClick={() => setIsRejectOpen(true)}
                className="min-h-[48px] h-12 px-4 rounded-xl text-slate-700 hover:text-rose-700 hover:bg-rose-50 border-slate-200 text-xs sm:text-sm font-semibold transition-colors cursor-pointer"
                title="Reject proposal with commercial feedback"
              >
                <X className="w-4 h-4 mr-1.5 text-rose-500" />
                <span>Reject</span>
              </Button>

              {/* 2. Counter-Offer Button */}
              <Button
                type="button"
                variant="outline"
                onClick={() => setIsCounterOpen(true)}
                className="min-h-[48px] h-12 px-4 rounded-xl text-[#0284C7] hover:text-[#0369A1] hover:bg-sky-50 border-sky-300 text-xs sm:text-sm font-semibold transition-colors cursor-pointer"
                title="Propose revised price, volume or delivery date"
              >
                <RefreshCw className="w-4 h-4 mr-1.5 text-[#0284C7]" />
                <span>Counter-Offer</span>
              </Button>

              {/* 3. Accept Proposal Button (Ocean Blue #0284C7) */}
              <Button
                type="button"
                onClick={() => setIsAcceptConfirmOpen(true)}
                className="min-h-[48px] h-12 px-6 rounded-xl bg-[#0284C7] hover:bg-[#0369A1] active:bg-[#075985] text-white text-xs sm:text-sm font-bold shadow-xs hover:shadow transition-all cursor-pointer"
                title="Accept active commercial terms"
              >
                <Check className="w-4 h-4 mr-1.5" />
                <span>Accept Proposal</span>
              </Button>
            </div>
          )}
        </div>
      </div>

      {/* Accept Confirmation Dialog */}
      <Dialog open={isAcceptConfirmOpen} onOpenChange={setIsAcceptConfirmOpen}>
        <DialogContent className="w-full max-w-md p-5 sm:p-6 rounded-2xl bg-white border border-slate-200 shadow-xl">
          <DialogHeader className="pb-3 border-b border-slate-100">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-lg bg-sky-50 text-[#0284C7] flex items-center justify-center border border-sky-100 shrink-0">
                <ShieldCheck className="w-4 h-4" />
              </div>
              <div>
                <DialogTitle className="text-base sm:text-lg font-bold text-slate-900 leading-tight">
                  Confirm Proposal Acceptance
                </DialogTitle>
                <DialogDescription className="text-xs text-slate-500">
                  Version {proposal.versionNumber} — {proposal.commodityName}
                </DialogDescription>
              </div>
            </div>
          </DialogHeader>

          <div className="space-y-3.5 py-2 text-xs">
            <p className="text-slate-600 leading-relaxed">
              You are about to accept the commercial terms mediated by your Broker. This will freeze the deal terms and generate the commercial agreement.
            </p>

            <div className="p-3.5 rounded-xl bg-sky-50/50 border border-sky-100 space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-slate-500">Agreed Net Rate:</span>
                <span className="font-bold text-slate-900 text-sm">
                  ₹{formatCurrency(proposal.netLandedPricePerUnit)} / {proposal.unitSymbol}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-slate-500">Total Volume:</span>
                <span className="font-semibold text-slate-800">
                  {formatCurrency(proposal.proposedQuantity)} {proposal.unitSymbol}
                </span>
              </div>
              <div className="flex items-center justify-between border-t border-sky-100 pt-1.5">
                <span className="text-slate-500">Total Contract Value:</span>
                <span className="font-black text-[#0284C7] text-sm">
                  ₹{formatCurrency(proposal.totalEstimatedValue)}
                </span>
              </div>
            </div>
          </div>

          <DialogFooter className="flex flex-col-reverse sm:flex-row items-stretch sm:items-center justify-end gap-2 pt-2 border-t border-slate-100">
            <Button
              type="button"
              variant="outline"
              disabled={isAcceptPending}
              onClick={() => setIsAcceptConfirmOpen(false)}
              className="min-h-[48px] h-12 px-5 rounded-xl border-slate-200 text-slate-700 text-xs sm:text-sm font-semibold"
            >
              Cancel
            </Button>

            <Button
              type="button"
              disabled={isAcceptPending}
              onClick={handleConfirmAccept}
              className="min-h-[48px] h-12 px-6 rounded-xl bg-[#0284C7] hover:bg-[#0369A1] active:bg-[#075985] text-white text-xs sm:text-sm font-bold shadow-xs transition-all"
            >
              {isAcceptPending ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  <span>Accepting...</span>
                </>
              ) : (
                <>
                  <Check className="w-4 h-4 mr-1.5" />
                  <span>Confirm Acceptance</span>
                </>
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Counter Drawer */}
      <ProposalCounterDrawer
        isOpen={isCounterOpen}
        onClose={() => setIsCounterOpen(false)}
        proposalId={proposal.id}
        expectedVersionNumber={proposal.versionNumber}
        currentPrice={proposal.netLandedPricePerUnit}
        currentQuantity={proposal.proposedQuantity}
        unitSymbol={proposal.unitSymbol}
        commodityName={proposal.commodityName}
        initialDeliveryDate={proposal.deliveryWindowStart}
      />

      {/* Reject Dialog */}
      <ProposalRejectDialog
        isOpen={isRejectOpen}
        onClose={() => setIsRejectOpen(false)}
        proposalId={proposal.id}
        expectedVersionNumber={proposal.versionNumber}
        commodityName={proposal.commodityName}
      />
    </>
  );
}
