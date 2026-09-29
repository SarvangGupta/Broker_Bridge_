'use client';

import React, { useState, useTransition } from 'react';
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
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import {
  AlertTriangle,
  CheckCircle2,
  FileText,
  ExternalLink,
  Loader2,
  ShieldCheck,
  Building,
  Clock,
} from 'lucide-react';
import { toast } from 'sonner';
import {
  BrokerDisputeItem,
  resolveDisputeAction,
} from '@/src/server/actions/broker-dispute-actions';

interface DisputeResolutionModalProps {
  dispute: BrokerDisputeItem;
  isOpen: boolean;
  onClose: () => void;
  onResolved?: () => void;
}

export function DisputeResolutionModal({
  dispute,
  isOpen,
  onClose,
  onResolved,
}: DisputeResolutionModalProps) {
  const [isPending, startTransition] = useTransition();
  const [resolutionNotes, setResolutionNotes] = useState<string>(
    dispute.resolutionNotes || ''
  );
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const isAlreadyResolved = dispute.status === 'Resolved';

  const handleResolve = (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg(null);

    if (resolutionNotes.trim().length < 5) {
      setErrorMsg('Please enter detailed resolution notes (at least 5 characters).');
      return;
    }

    startTransition(async () => {
      try {
        const res = await resolveDisputeAction({
          disputeId: dispute.id,
          resolutionNotes: resolutionNotes.trim(),
        });

        if (res.success) {
          toast.success('Dispute Resolved Successfully', {
            description: `Logged resolution for ${dispute.bookingReference}`,
          });
          onClose();
          if (onResolved) onResolved();
        } else {
          setErrorMsg(res.error || 'Failed to resolve dispute.');
          toast.error('Resolution Error', {
            description: res.error || 'Unexpected error occurred.',
          });
        }
      } catch (err: any) {
        setErrorMsg(err.message || 'Error executing dispute resolution.');
        toast.error('Resolution Exception', {
          description: err.message || 'Network error occurred.',
        });
      }
    });
  };

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="sm:max-w-lg bg-white border-slate-200 shadow-xl rounded-2xl p-0 overflow-hidden">
        {/* Header */}
        <div className="bg-slate-900 text-white p-5 space-y-2">
          <div className="flex items-center justify-between gap-2">
            <Badge
              className={`text-xs font-bold px-2.5 py-0.5 ${
                dispute.category === 'Quality'
                  ? 'bg-red-500 text-white'
                  : dispute.category === 'Delivery'
                  ? 'bg-amber-500 text-slate-950 font-bold'
                  : dispute.category === 'Payment'
                  ? 'bg-purple-500 text-white'
                  : 'bg-teal-500 text-slate-950 font-bold'
              }`}
            >
              {dispute.category} Issue
            </Badge>
            <Badge variant="outline" className="text-xs text-slate-300 border-slate-700 font-mono">
              {dispute.bookingReference}
            </Badge>
          </div>
          <DialogTitle className="text-lg font-bold text-white tracking-tight">
            Dispute Resolution & Evidence Vault
          </DialogTitle>
          <DialogDescription className="text-xs text-slate-300">
            Broker operational mediation desk. Direct counterparty messaging is disabled.
          </DialogDescription>
        </div>

        {/* Body */}
        <form onSubmit={handleResolve} className="p-5 space-y-4 text-xs">
          {errorMsg && (
            <div className="p-3 rounded-lg bg-red-50 border border-red-200 text-red-700 text-xs font-medium">
              {errorMsg}
            </div>
          )}

          {/* FILED BY & REASON SUMMARY */}
          <div className="p-3 rounded-xl bg-slate-50 border border-slate-200/80 space-y-2">
            <div className="flex justify-between items-center text-[11px] text-slate-500">
              <span className="flex items-center gap-1 font-semibold text-slate-700">
                <Building className="w-3.5 h-3.5 text-slate-400" />
                Filed By: {dispute.filedByCompanyName} ({dispute.filedByName})
              </span>
              <span className="flex items-center gap-1">
                <Clock className="w-3 h-3 text-slate-400" />
                {dispute.daysOpen} Day{dispute.daysOpen === 1 ? '' : 's'} Open
              </span>
            </div>
            <div>
              <span className="font-bold text-slate-900 block text-xs">Issue Reason: {dispute.reason}</span>
              <p className="text-slate-600 text-xs mt-0.5 whitespace-pre-wrap">{dispute.description}</p>
            </div>
          </div>

          {/* READ-ONLY EVIDENCE DOCUMENTS */}
          <div className="space-y-1.5">
            <Label className="text-slate-700 font-semibold text-xs flex items-center gap-1.5">
              <FileText className="w-3.5 h-3.5 text-teal-600" />
              Attached Fulfillment Evidence & Records
            </Label>
            {dispute.evidenceDocuments.length === 0 ? (
              <p className="text-slate-400 italic text-[11px] p-3 rounded-lg bg-slate-50 border border-slate-100 text-center">
                No weighbridge, COA, or LR evidence files uploaded yet.
              </p>
            ) : (
              <div className="space-y-1.5 max-h-36 overflow-y-auto">
                {dispute.evidenceDocuments.map((doc) => (
                  <div
                    key={doc.id}
                    className="p-2.5 rounded-lg bg-teal-50/50 border border-teal-200/60 flex items-center justify-between gap-2"
                  >
                    <div className="flex items-center gap-2 min-w-0">
                      <FileText className="w-4 h-4 text-[#0D9488] shrink-0" />
                      <div className="min-w-0">
                        <span className="font-bold text-slate-900 text-xs block truncate">
                          {doc.documentType}
                        </span>
                        <span className="text-[10px] text-slate-400">
                          Uploaded {new Date(doc.createdAt).toLocaleDateString('en-IN')}
                        </span>
                      </div>
                    </div>
                    <a
                      href={doc.fileUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center gap-1 text-[11px] font-semibold text-[#0D9488] hover:text-teal-900 shrink-0"
                    >
                      <span>View File</span>
                      <ExternalLink className="w-3 h-3" />
                    </a>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* BROKER MEDIATION NOTES */}
          <div className="space-y-1.5">
            <Label className="text-slate-700 font-semibold text-xs flex items-center gap-1.5">
              <ShieldCheck className="w-3.5 h-3.5 text-teal-600" />
              Broker Internal Mediation Notes & Resolution Findings
            </Label>
            <Textarea
              placeholder="Record your offline mediation findings, agreed weight adjustments, quality concessions, or settlement terms..."
              value={resolutionNotes}
              onChange={(e) => setResolutionNotes(e.target.value)}
              disabled={isAlreadyResolved || isPending}
              className="min-h-[90px] border-slate-300 focus:border-teal-500 text-xs rounded-xl"
              required
            />
          </div>

          {/* FOOTER ACTIONS */}
          <DialogFooter className="pt-3 border-t border-slate-100 flex flex-col-reverse sm:flex-row sm:justify-end gap-2">
            <Button
              type="button"
              variant="outline"
              onClick={onClose}
              disabled={isPending}
              className="border-slate-300 text-slate-700 hover:bg-slate-100 text-xs h-10 font-semibold"
            >
              Close
            </Button>
            {!isAlreadyResolved && (
              <Button
                type="submit"
                disabled={isPending}
                className="bg-[#0D9488] hover:bg-teal-700 text-white text-xs h-10 font-semibold px-5 cursor-pointer"
              >
                {isPending ? (
                  <>
                    <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                    Resolving...
                  </>
                ) : (
                  <>
                    <CheckCircle2 className="w-4 h-4 mr-1.5" />
                    Mark as Resolved
                  </>
                )}
              </Button>
            )}
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
