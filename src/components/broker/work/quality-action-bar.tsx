'use client';

import React, { useState, useTransition } from 'react';
import {
  CheckCircle2,
  XCircle,
  AlertTriangle,
  RotateCcw,
  Clock,
  Send,
  Loader2,
  FileCheck2,
  ChevronDown,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import {
  reviewLabTestAction,
  type VerificationDecision,
} from '@/src/server/actions/quality-verification-actions';
import { toast } from 'sonner';

interface QualityActionBarProps {
  labTestId?: string | null;
  availabilityId: string;
  requirementId: string;
  lotNumber?: string;
  currentStatus?: string;
  onSuccess?: () => void;
}

export function QualityActionBar({
  labTestId,
  availabilityId,
  requirementId,
  lotNumber,
  currentStatus,
  onSuccess,
}: QualityActionBarProps) {
  const [isPending, startTransition] = useTransition();

  // Modal prompt state for notes/justification
  const [promptOpen, setPromptOpen] = useState<boolean>(false);
  const [selectedDecision, setSelectedDecision] = useState<VerificationDecision | 'New COA' | 'Pending'>('Verified');
  const [promptTitle, setPromptTitle] = useState<string>('');
  const [promptDescription, setPromptDescription] = useState<string>('');
  const [notes, setNotes] = useState<string>('');

  const executeDecision = async (
    decision: VerificationDecision,
    reasonNotes?: string
  ) => {
    if (!labTestId) {
      toast.info('No formal lab record is linked to this lot. Quality status updated locally.');
      if (onSuccess) onSuccess();
      return;
    }

    startTransition(async () => {
      try {
        const res = await reviewLabTestAction({
          labTestId,
          decision,
          verificationNotes: reasonNotes,
        });

        if (res.success) {
          toast.success(
            decision === 'Verified'
              ? 'Quality verified & approved for trade matching!'
              : decision === 'Correction Required'
              ? 'Quality correction request dispatched to Seller.'
              : 'Quality specification rejected.'
          );
          setPromptOpen(false);
          setNotes('');
          if (onSuccess) onSuccess();
        } else {
          toast.error(res.error || 'Failed to record quality review decision.');
        }
      } catch (err: any) {
        toast.error(err.message || 'An error occurred during verification.');
      }
    });
  };

  const handleApprove = () => {
    executeDecision('Verified', 'Approved by Broker as commercially compliant.');
  };

  const openPrompt = (type: 'Correction' | 'New COA' | 'Reject' | 'Pending') => {
    if (type === 'Correction') {
      setSelectedDecision('Correction Required');
      setPromptTitle('Request Quality Correction');
      setPromptDescription(
        'Specify the parameter discrepancy or value correction needed from the seller laboratory.'
      );
      setNotes('Moisture / foreign matter specification exceeds buyer requirement limit.');
    } else if (type === 'New COA') {
      setSelectedDecision('Correction Required');
      setPromptTitle('Request New Lab Report / COA');
      setPromptDescription(
        'Request an updated NABL/approved laboratory certificate for this inventory lot.'
      );
      setNotes('Please provide a fresh Certificate of Analysis (COA) tested within the last 15 days.');
    } else if (type === 'Reject') {
      setSelectedDecision('Rejected');
      setPromptTitle('Reject Lot Quality');
      setPromptDescription(
        'Mark this lot as non-compliant with the required buyer specifications.'
      );
      setNotes('Critical quality variance: Lot fails moisture/protein requirements.');
    } else {
      setSelectedDecision('Pending');
      setPromptTitle('Mark Quality Pending');
      setPromptDescription(
        'Flag this lot as awaiting physical sample draw or independent laboratory confirmation.'
      );
      setNotes('Awaiting physical sample verification from warehouse terminal.');
    }
    setPromptOpen(true);
  };

  const handleConfirmPrompt = () => {
    if (!notes.trim()) {
      toast.error('Please provide justification notes before submitting.');
      return;
    }

    const decision: VerificationDecision =
      selectedDecision === 'Rejected'
        ? 'Rejected'
        : selectedDecision === 'Correction Required'
        ? 'Correction Required'
        : 'Verified';

    executeDecision(decision, notes.trim());
  };

  return (
    <>
      <div className="sticky bottom-0 left-0 right-0 bg-white/95 backdrop-blur-md border-t border-slate-200 p-3 sm:p-4 rounded-b-2xl shadow-lg z-10">
        <div className="flex flex-col sm:flex-row items-center justify-between gap-2.5 max-w-full">
          {/* Status Indicator */}
          <div className="text-xs text-slate-500 font-medium hidden sm:flex items-center gap-1.5">
            <FileCheck2 className="w-4 h-4 text-[#0D9488]" />
            <span>Broker Decision Gate:</span>
            <span className="font-semibold text-slate-800">
              {currentStatus === 'Verified'
                ? 'Verified & Approved'
                : currentStatus === 'Correction Required'
                ? 'Correction Pending'
                : currentStatus === 'Rejected'
                ? 'Rejected'
                : 'Awaiting Broker Action'}
            </span>
          </div>

          {/* Action Button Strip */}
          <div className="flex items-center gap-2 w-full sm:w-auto">
            {/* Primary Action: Approve */}
            <Button
              type="button"
              onClick={handleApprove}
              disabled={isPending}
              className="flex-1 sm:flex-none min-h-[48px] h-12 px-5 bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-sm shadow-xs rounded-lg transition-all flex items-center justify-center gap-2"
            >
              {isPending ? (
                <Loader2 className="w-4 h-4 animate-spin" />
              ) : (
                <CheckCircle2 className="w-4 h-4 shrink-0" />
              )}
              <span>Approve Quality</span>
            </Button>

            {/* Secondary Action: Request Correction (Direct) */}
            <Button
              type="button"
              variant="outline"
              onClick={() => openPrompt('Correction')}
              disabled={isPending}
              className="flex-1 sm:flex-none min-h-[48px] h-12 px-4 border-amber-300 hover:bg-amber-50 text-amber-800 font-semibold text-xs sm:text-sm rounded-lg transition-all flex items-center justify-center gap-1.5"
            >
              <AlertTriangle className="w-4 h-4 text-amber-600 shrink-0" />
              <span>Request Correction</span>
            </Button>

            {/* Additional Secondary Actions Dropdown */}
            <DropdownMenu>
              <DropdownMenuTrigger
                disabled={isPending}
                className="min-h-[48px] h-12 px-3 border border-slate-200 text-slate-700 font-semibold text-xs rounded-lg hover:bg-slate-100 flex items-center gap-1 shrink-0 bg-white cursor-pointer"
              >
                <span>More</span>
                <ChevronDown className="w-3.5 h-3.5 opacity-70" />
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-56 text-xs">
                <DropdownMenuItem
                  onClick={() => openPrompt('New COA')}
                  className="cursor-pointer flex items-center gap-2 text-slate-700 py-2.5"
                >
                  <RotateCcw className="w-3.5 h-3.5 text-teal-600" />
                  <span>Request Fresh COA / Lab Report</span>
                </DropdownMenuItem>
                <DropdownMenuItem
                  onClick={() => openPrompt('Pending')}
                  className="cursor-pointer flex items-center gap-2 text-slate-700 py-2.5"
                >
                  <Clock className="w-3.5 h-3.5 text-slate-500" />
                  <span>Mark Quality Pending</span>
                </DropdownMenuItem>
                <DropdownMenuSeparator />
                <DropdownMenuItem
                  onClick={() => openPrompt('Reject')}
                  className="cursor-pointer flex items-center gap-2 text-rose-600 py-2.5 focus:text-rose-700 focus:bg-rose-50"
                >
                  <XCircle className="w-3.5 h-3.5" />
                  <span>Reject Quality</span>
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </div>
      </div>

      {/* REASON PROMPT DIALOG */}
      <Dialog open={promptOpen} onOpenChange={setPromptOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle className="text-base font-bold text-slate-900 flex items-center gap-2">
              {selectedDecision === 'Rejected' ? (
                <XCircle className="w-5 h-5 text-rose-600" />
              ) : (
                <AlertTriangle className="w-5 h-5 text-amber-600" />
              )}
              <span>{promptTitle}</span>
            </DialogTitle>
            <DialogDescription className="text-xs text-slate-500">
              {promptDescription}
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-3 py-2">
            <div className="space-y-1.5">
              <Label className="text-xs font-semibold text-slate-700">
                Verification Feedback / Instructions for Seller *
              </Label>
              <Textarea
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                rows={4}
                placeholder="Detail the parameter deviation, required testing standard, or reason..."
                className="text-xs resize-none focus-visible:ring-[#0D9488]"
              />
            </div>
          </div>

          <DialogFooter className="flex flex-col sm:flex-row gap-2 pt-2">
            <Button
              type="button"
              variant="outline"
              onClick={() => setPromptOpen(false)}
              className="min-h-[44px] h-11"
              disabled={isPending}
            >
              Cancel
            </Button>
            <Button
              type="button"
              onClick={handleConfirmPrompt}
              disabled={isPending}
              className={`min-h-[44px] h-11 font-bold text-white ${
                selectedDecision === 'Rejected'
                  ? 'bg-rose-600 hover:bg-rose-700'
                  : 'bg-amber-600 hover:bg-amber-700'
              }`}
            >
              {isPending ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4 mr-1.5" />}
              <span>Submit Decision</span>
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
