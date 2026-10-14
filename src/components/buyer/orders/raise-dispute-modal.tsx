'use client';

import React, { useState, useTransition, useRef } from 'react';
import { useRouter } from 'next/navigation';
import {
  AlertTriangle,
  UploadCloud,
  FileCheck2,
  Trash2,
  Loader2,
  ShieldAlert,
  CheckCircle2,
  X,
  FileText,
  Info,
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
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';
import {
  BUYER_DISPUTE_CATEGORIES,
  BuyerDisputeCategory,
} from '@/src/types/buyer-dispute-types';
import {
  createBuyerDisputeAction,
  uploadBuyerDisputeEvidenceAction,
} from '@/src/server/actions/buyer-dispute-actions';

export interface RaiseDisputeModalProps {
  bookingId: string;
  commodityName?: string;
  className?: string;
  onDisputeCreated?: (disputeId: string) => void;
}

interface UploadedEvidenceFile {
  name: string;
  url: string;
  size: number;
}

/**
 * Task 2 (Micro-Sprint 39.4): Raise Dispute Modal Component.
 * 
 * Allows the Buyer to raise a formal commercial or fulfillment exception against a booking.
 * 
 * Strict Guardrails:
 * 1. Fiduciary Mediation: All disputes are strictly routed to the Broker Desk.
 *    Zero direct Buyer-Seller communication channels.
 * 2. Strict Category Validation: 'Quality', 'Quantity', 'Delivery', 'Document', 'Payment', 'Commercial', 'Other'.
 * 3. Description Guard: Minimum 50 characters required to prevent frivolous disputes.
 * 4. useTransition: Prevents double-submissions and displays a responsive spinner.
 * 5. Mobile-First: Form cleanly stacks on a 360px mobile viewport with min-h-[48px] touch targets.
 */
export function RaiseDisputeModal({
  bookingId,
  commodityName,
  className,
  onDisputeCreated,
}: RaiseDisputeModalProps) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [isPending, startTransition] = useTransition();

  const [category, setCategory] = useState<BuyerDisputeCategory>('Quality');
  const [description, setDescription] = useState('');
  const [evidenceFiles, setEvidenceFiles] = useState<UploadedEvidenceFile[]>([]);
  const [isUploading, setIsUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successDisputeId, setSuccessDisputeId] = useState<string | null>(null);

  const fileInputRef = useRef<HTMLInputElement>(null);

  const charCount = description.trim().length;
  const isDescriptionValid = charCount >= 50;

  // Reset form state on dialog close/open
  const handleOpenChange = (newOpen: boolean) => {
    if (!newOpen) {
      setError(null);
      setSuccessDisputeId(null);
    }
    setOpen(newOpen);
  };

  // Handle Evidence File Upload
  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files || files.length === 0) return;

    const file = files[0];
    setError(null);
    setIsUploading(true);

    try {
      const formData = new FormData();
      formData.append('file', file);
      formData.append('bookingId', bookingId);

      const res = await uploadBuyerDisputeEvidenceAction(formData);

      if (res.success && res.fileUrl) {
        setEvidenceFiles((prev) => [
          ...prev,
          {
            name: file.name,
            url: res.fileUrl!,
            size: file.size,
          },
        ]);
      } else {
        setError(res.error || 'Failed to upload evidence file.');
      }
    } catch (err: any) {
      setError(err.message || 'Error occurred during file upload.');
    } finally {
      setIsUploading(false);
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    }
  };

  const handleRemoveEvidence = (index: number) => {
    setEvidenceFiles((prev) => prev.filter((_, i) => i !== index));
  };

  // Handle Form Submission with useTransition
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    if (!isDescriptionValid) {
      setError('Description must be at least 50 characters explaining the issue.');
      return;
    }

    setError(null);

    startTransition(async () => {
      try {
        const payload = {
          booking_id: bookingId,
          category,
          description: description.trim(),
          evidence_urls: evidenceFiles.map((f) => f.url),
        };

        const res = await createBuyerDisputeAction(payload);

        if (res.success) {
          setSuccessDisputeId(res.disputeId || 'NEW');
          if (onDisputeCreated && res.disputeId) {
            onDisputeCreated(res.disputeId);
          }
          // Refresh route cache
          router.refresh();
        } else {
          setError(res.error || 'Failed to submit dispute. Please try again.');
        }
      } catch (err: any) {
        setError(err.message || 'An unexpected error occurred while raising the dispute.');
      }
    });
  };

  return (
    <>
      {/* 1. Destructive/Red Outline Trigger Button */}
      <Button
        type="button"
        variant="outline"
        onClick={() => setOpen(true)}
        className={cn(
          'w-full sm:w-auto min-h-[48px] px-4 rounded-xl text-xs sm:text-sm font-bold shadow-2xs gap-2 transition-all',
          'border-rose-300 text-rose-700 bg-white hover:bg-rose-50 hover:text-rose-800 hover:border-rose-400',
          className
        )}
      >
        <AlertTriangle className="w-4 h-4 text-rose-600 shrink-0" />
        <span>Raise Issue / Dispute</span>
      </Button>

      {/* 2. Shadcn Dialog / Modal */}
      <Dialog open={open} onOpenChange={handleOpenChange}>
        <DialogContent
          className="w-full max-w-lg p-0 overflow-hidden rounded-2xl bg-white border border-slate-200 shadow-xl"
          showCloseButton={!isPending}
        >
          {successDisputeId ? (
            /* Success Feedback State */
            <div className="p-6 text-center space-y-4 animate-in fade-in">
              <div className="w-12 h-12 rounded-full bg-emerald-100 text-emerald-700 mx-auto flex items-center justify-center">
                <CheckCircle2 className="w-7 h-7" />
              </div>

              <div className="space-y-1">
                <h3 className="text-base sm:text-lg font-bold text-slate-900">
                  Dispute Submitted for Broker Mediation
                </h3>
                <p className="text-xs sm:text-sm text-slate-500 max-w-sm mx-auto leading-relaxed">
                  Your exception on booking <span className="font-mono font-bold text-slate-800">{bookingId}</span> has been logged under status <span className="font-bold text-sky-700">Open</span>. The neutral Broker desk will review the parameters and issue resolution instructions.
                </p>
              </div>

              <div className="p-3 rounded-xl bg-slate-50 border border-slate-200 text-left text-xs text-slate-600 space-y-1">
                <span className="font-bold text-slate-800 block">Mediation Protocol Notice:</span>
                <p className="text-[11px] leading-relaxed text-slate-500">
                  Direct communication with the seller is disabled to protect contract integrity. Track broker mediation progress in the dedicated Dispute Ledger.
                </p>
              </div>

              <div className="flex flex-col sm:flex-row gap-2 pt-2">
                <Button
                  variant="outline"
                  onClick={() => setOpen(false)}
                  className="min-h-[48px] flex-1 rounded-xl text-xs font-semibold"
                >
                  Close
                </Button>
                <Button
                  onClick={() => {
                    setOpen(false);
                    router.push('/buyer/more/disputes');
                  }}
                  className="min-h-[48px] flex-1 rounded-xl text-xs font-bold bg-[#0284C7] hover:bg-[#0369A1] text-white shadow-xs"
                >
                  View in Dispute Ledger
                </Button>
              </div>
            </div>
          ) : (
            /* Form State */
            <form onSubmit={handleSubmit} className="flex flex-col">
              {/* Header */}
              <DialogHeader className="p-5 border-b border-slate-100 bg-slate-50/50 space-y-1.5 text-left">
                <div className="flex items-center gap-2">
                  <span className="px-2 py-0.5 rounded-md bg-rose-100 text-rose-800 text-[10px] font-bold uppercase tracking-wider">
                    Exception Management
                  </span>
                  <span className="font-mono text-xs font-bold text-slate-500">
                    {bookingId}
                  </span>
                </div>
                <DialogTitle className="text-base sm:text-lg font-bold text-slate-900 tracking-tight">
                  Raise Order Issue / Dispute
                </DialogTitle>
                <DialogDescription className="text-xs text-slate-500 leading-relaxed">
                  File a formal exception for neutral Broker mediation. The broker acts as an impartial escrow fiduciary to verify quality, weighment, or transit deviations.
                </DialogDescription>
              </DialogHeader>

              {/* Body Form Fields */}
              <div className="p-5 space-y-4 max-h-[60vh] overflow-y-auto">
                {/* Error Banner */}
                {error && (
                  <div className="p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-800 text-xs flex items-start gap-2 animate-in fade-in">
                    <ShieldAlert className="w-4 h-4 text-rose-600 shrink-0 mt-0.5" />
                    <span>{error}</span>
                  </div>
                )}

                {/* 1. Category Field */}
                <div className="space-y-1.5">
                  <Label htmlFor="dispute-category" className="text-xs font-bold text-slate-700">
                    Dispute Category <span className="text-rose-500">*</span>
                  </Label>
                  <select
                    id="dispute-category"
                    value={category}
                    onChange={(e) => setCategory(e.target.value as BuyerDisputeCategory)}
                    className="w-full min-h-[48px] h-12 px-3 rounded-xl border border-slate-200 bg-white text-xs sm:text-sm font-medium text-slate-900 focus:outline-none focus:ring-2 focus:ring-[#0284C7]/20 focus:border-[#0284C7] transition-all"
                  >
                    <option value="Quality">Quality — Specification or COA deviation</option>
                    <option value="Quantity">Quantity — Weighment or lot shortage</option>
                    <option value="Delivery">Delivery — Transit delay or breakdown</option>
                    <option value="Document">Document — Missing LR, E-Way Bill, or invoice error</option>
                    <option value="Payment">Payment — Escrow settlement discrepancy</option>
                    <option value="Commercial">Commercial — Contract terms disagreement</option>
                    <option value="Other">Other — General operational exception</option>
                  </select>
                </div>

                {/* 2. Description Field (min 50 chars) */}
                <div className="space-y-1.5">
                  <div className="flex items-center justify-between">
                    <Label htmlFor="dispute-description" className="text-xs font-bold text-slate-700">
                      Description & Discrepancy Evidence <span className="text-rose-500">*</span>
                    </Label>
                    <span
                      className={cn(
                        'text-[10px] font-mono font-bold',
                        isDescriptionValid ? 'text-emerald-600' : 'text-slate-400'
                      )}
                    >
                      {charCount} / 50 min chars
                    </span>
                  </div>

                  <Textarea
                    id="dispute-description"
                    rows={4}
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                    placeholder="Provide detailed description of the observed discrepancy, batch numbers, laboratory findings, physical inspection observations, or delivery note differences..."
                    className="w-full p-3 rounded-xl border-slate-200 text-xs sm:text-sm text-slate-900 focus:ring-[#0284C7]/20 focus:border-[#0284C7] resize-none"
                  />
                  {!isDescriptionValid && charCount > 0 && (
                    <p className="text-[11px] text-amber-600 font-medium">
                      Please enter at least {50 - charCount} more character{50 - charCount === 1 ? '' : 's'}.
                    </p>
                  )}
                </div>

                {/* 3. Evidence Upload Dropzone */}
                <div className="space-y-1.5">
                  <Label className="text-xs font-bold text-slate-700">
                    Evidence Documents / Photos (Optional)
                  </Label>
                  <p className="text-[11px] text-slate-500 leading-tight">
                    Upload photos of damaged goods, weighbridge tickets, or independent lab slips (JPEG, PNG, WEBP, PDF up to 10MB).
                  </p>

                  <div
                    onClick={() => fileInputRef.current?.click()}
                    className={cn(
                      'border-2 border-dashed rounded-xl p-4 text-center cursor-pointer transition-colors',
                      isUploading
                        ? 'bg-slate-50 border-slate-300 pointer-events-none'
                        : 'border-slate-200 hover:border-[#0284C7] hover:bg-sky-50/30'
                    )}
                  >
                    <input
                      ref={fileInputRef}
                      type="file"
                      accept="image/jpeg,image/png,image/webp,application/pdf"
                      onChange={handleFileUpload}
                      className="hidden"
                    />

                    {isUploading ? (
                      <div className="flex flex-col items-center justify-center py-2 space-y-1">
                        <Loader2 className="w-5 h-5 text-[#0284C7] animate-spin" />
                        <span className="text-xs font-medium text-slate-600">
                          Uploading evidence to secure storage...
                        </span>
                      </div>
                    ) : (
                      <div className="flex flex-col items-center justify-center space-y-1">
                        <UploadCloud className="w-6 h-6 text-slate-400" />
                        <div className="text-xs font-bold text-slate-700">
                          Click to upload evidence file
                        </div>
                        <span className="text-[10px] text-slate-400">
                          Supports JPEG, PNG, PDF (Max 10MB)
                        </span>
                      </div>
                    )}
                  </div>

                  {/* Uploaded Files List */}
                  {evidenceFiles.length > 0 && (
                    <div className="space-y-1.5 pt-1">
                      {evidenceFiles.map((f, idx) => (
                        <div
                          key={idx}
                          className="flex items-center justify-between p-2 rounded-lg bg-slate-50 border border-slate-200 text-xs"
                        >
                          <div className="flex items-center gap-2 min-w-0">
                            <FileText className="w-4 h-4 text-[#0284C7] shrink-0" />
                            <span className="font-medium text-slate-800 truncate">
                              {f.name}
                            </span>
                          </div>

                          <button
                            type="button"
                            onClick={() => handleRemoveEvidence(idx)}
                            className="p-1 text-slate-400 hover:text-rose-600 transition-colors"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                {/* Neutral Broker Mediation Policy Notice */}
                <div className="p-3 rounded-xl bg-amber-50/70 border border-amber-200/80 flex items-start gap-2.5 text-[11px] text-amber-900">
                  <Info className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
                  <p className="leading-relaxed">
                    <span className="font-bold">Neutral Mediation Protocol:</span> Direct Buyer-Seller communication channels are prohibited. The Broker Desk mediates settlement adjustments and orders reinspection if required.
                  </p>
                </div>
              </div>

              {/* Footer Actions */}
              <DialogFooter className="p-4 border-t border-slate-100 bg-slate-50/50 flex flex-col-reverse sm:flex-row gap-2 justify-end">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setOpen(false)}
                  disabled={isPending}
                  className="min-h-[48px] rounded-xl text-xs font-semibold w-full sm:w-auto"
                >
                  Cancel
                </Button>

                <Button
                  type="submit"
                  disabled={!isDescriptionValid || isPending || isUploading}
                  className="min-h-[48px] rounded-xl text-xs font-bold bg-rose-600 hover:bg-rose-700 text-white shadow-xs gap-2 w-full sm:w-auto transition-all disabled:opacity-50"
                >
                  {isPending ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin" />
                      <span>Submitting for Broker Review...</span>
                    </>
                  ) : (
                    <>
                      <AlertTriangle className="w-4 h-4" />
                      <span>Submit for Broker Mediation</span>
                    </>
                  )}
                </Button>
              </DialogFooter>
            </form>
          )}
        </DialogContent>
      </Dialog>
    </>
  );
}
