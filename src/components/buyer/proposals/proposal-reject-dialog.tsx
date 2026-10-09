'use client';

import React, { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { 
  X, 
  AlertTriangle, 
  MessageSquare, 
  Loader2,
  CheckCircle2,
  HelpCircle
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
import { rejectBuyerProposalAction } from '@/src/server/actions/buyer-proposal-actions';
import { toast } from 'sonner';
import { cn } from '@/lib/utils';

interface ProposalRejectDialogProps {
  isOpen: boolean;
  onClose: () => void;
  proposalId: string;
  expectedVersionNumber: number;
  commodityName: string;
  onSuccess?: () => void;
}

const REJECT_REASONS = [
  'Price too high / Above target',
  'Quantity does not match demand',
  'Delivery window infeasible',
  'Quality terms / specifications unacceptable',
  'Other',
];

export function ProposalRejectDialog({
  isOpen,
  onClose,
  proposalId,
  expectedVersionNumber,
  commodityName,
  onSuccess,
}: ProposalRejectDialogProps) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  const [selectedReason, setSelectedReason] = useState<string>(REJECT_REASONS[0]);
  const [customNotes, setCustomNotes] = useState<string>('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    if (!selectedReason) {
      toast.error('Please select a reason for rejection.');
      return;
    }

    startTransition(async () => {
      try {
        const res = await rejectBuyerProposalAction({
          proposalId,
          expectedVersionNumber,
          reason: selectedReason,
          notes: customNotes.trim() || undefined,
        });

        if (res.success) {
          toast.success('Proposal rejected. Your broker has been notified.');
          onClose();
          if (onSuccess) onSuccess();
          router.refresh();
        } else if (res.error === 'STALE_VERSION_DETECTED') {
          toast.error('The Broker has updated this proposal. Please refresh to review the latest terms.', {
            action: {
              label: 'Refresh',
              onClick: () => router.refresh(),
            },
            duration: 8000,
          });
          onClose();
        } else {
          toast.error(res.error || 'Failed to reject proposal.');
        }
      } catch (err: any) {
        toast.error(err.message || 'An unexpected error occurred.');
      }
    });
  };

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="w-full max-w-lg max-h-[92vh] overflow-y-auto p-4 sm:p-6 rounded-2xl bg-white border border-slate-200 shadow-xl">
        <DialogHeader className="pb-3 border-b border-slate-100">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-rose-50 text-rose-600 flex items-center justify-center border border-rose-100 shrink-0">
              <X className="w-4 h-4" />
            </div>
            <div>
              <DialogTitle className="text-base sm:text-lg font-bold text-slate-900 leading-tight">
                Reject Proposal
              </DialogTitle>
              <DialogDescription className="text-xs text-slate-500">
                {commodityName} — State commercial reason for declining this broker offer
              </DialogDescription>
            </div>
          </div>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4 pt-2">
          {/* Warning Banner */}
          <div className="p-3 rounded-xl bg-amber-50/70 border border-amber-200/80 flex items-start gap-2.5 text-xs text-amber-900">
            <AlertTriangle className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
            <p className="leading-relaxed">
              Declining will close this commercial offer round. Your broker will be notified with your feedback so they can source alternative lots.
            </p>
          </div>

          {/* Structured Reason Selector */}
          <div className="space-y-2">
            <label className="text-xs font-semibold text-slate-700 block">
              Reason for Rejection *
            </label>
            <div className="space-y-1.5">
              {REJECT_REASONS.map((reason) => {
                const isSelected = selectedReason === reason;
                return (
                  <button
                    key={reason}
                    type="button"
                    disabled={isPending}
                    onClick={() => setSelectedReason(reason)}
                    className={cn(
                      'w-full flex items-center justify-between min-h-[48px] h-12 px-3.5 py-2.5 rounded-xl text-xs sm:text-sm text-left transition-all border cursor-pointer',
                      isSelected
                        ? 'bg-rose-50/60 border-rose-300 text-rose-950 font-semibold shadow-2xs'
                        : 'bg-white hover:bg-slate-50 border-slate-200 text-slate-700 font-medium'
                    )}
                  >
                    <span>{reason}</span>
                    <div
                      className={cn(
                        'w-4 h-4 rounded-full border flex items-center justify-center shrink-0 transition-colors',
                        isSelected
                          ? 'border-rose-600 bg-rose-600 text-white'
                          : 'border-slate-300 bg-white'
                      )}
                    >
                      {isSelected && <div className="w-1.5 h-1.5 rounded-full bg-white" />}
                    </div>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Remarks Textarea */}
          <div className="space-y-1.5">
            <label 
              htmlFor="customNotes" 
              className="text-xs font-semibold text-slate-700 flex items-center gap-1.5"
            >
              <MessageSquare className="w-3.5 h-3.5 text-slate-400" />
              <span>Additional Feedback for Broker (Optional)</span>
            </label>
            <Textarea
              id="customNotes"
              rows={3}
              disabled={isPending}
              value={customNotes}
              onChange={(e) => setCustomNotes(e.target.value)}
              placeholder="e.g. Can reconsider if price drops below ₹24,500/MT or moisture test is certified under 11.5%."
              className="min-h-[72px] text-xs sm:text-sm text-slate-800 rounded-xl border-slate-200 focus-visible:ring-rose-500 resize-none"
            />
          </div>

          {/* Footer Actions with min-h-[48px] */}
          <DialogFooter className="flex flex-col-reverse sm:flex-row items-stretch sm:items-center justify-end gap-2 pt-2 border-t border-slate-100">
            <Button
              type="button"
              variant="outline"
              disabled={isPending}
              onClick={onClose}
              className="min-h-[48px] h-12 px-5 rounded-xl border-slate-200 text-slate-700 hover:bg-slate-50 text-xs sm:text-sm font-semibold"
            >
              Cancel
            </Button>

            <Button
              type="submit"
              disabled={isPending}
              className="min-h-[48px] h-12 px-6 rounded-xl bg-rose-600 hover:bg-rose-700 active:bg-rose-800 text-white text-xs sm:text-sm font-bold shadow-xs hover:shadow transition-all"
            >
              {isPending ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  <span>Rejecting...</span>
                </>
              ) : (
                <>
                  <X className="w-4 h-4 mr-1.5" />
                  <span>Reject Proposal</span>
                </>
              )}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
