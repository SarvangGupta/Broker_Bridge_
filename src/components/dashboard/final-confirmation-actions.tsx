"use client";

import React, { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { useQueryClient } from "@tanstack/react-query";
import {
  Check,
  RotateCcw,
  AlertTriangle,
  CheckCircle2,
  ShieldCheck,
  Loader2,
  Send,
  X,
  FileCheck2,
  RefreshCw,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/textarea";
import { toast } from "sonner";
import {
  confirmFinalDealTermsAction,
  requestBrokerCorrectionAction,
} from "@/src/server/actions/confirmation-actions";
import { SnapshotDetailsWithDiff } from "@/src/components/dashboard/visual-diff-snapshot";

interface FinalConfirmationActionsProps {
  record: SnapshotDetailsWithDiff;
  onSuccess?: () => void;
  className?: string;
}

const CORRECTION_QUICK_CHIPS = [
  "Price revision required",
  "Adjust requested quantity",
  "Extend target delivery date",
  "Update packaging specification",
  "Clarify payment escrow terms",
];

export function FinalConfirmationActions({
  record,
  onSuccess,
  className = "",
}: FinalConfirmationActionsProps) {
  const router = useRouter();
  const queryClient = useQueryClient();
  const [modalType, setModalType] = useState<"confirm" | "correction" | null>(null);
  const [correctionRemarks, setCorrectionRemarks] = useState("");
  const [isPending, startTransition] = useTransition();

  const snap = record.snapshotPayload;
  const isAlreadyConfirmed =
    record.status === "Seller Confirmed" || record.status === "Broker Finalized";
  const isSuperseded = record.status === "Superseded";

  // Handle Confirm Final Terms Submission
  const handleConfirmTerms = () => {
    startTransition(async () => {
      try {
        const res = await confirmFinalDealTermsAction(
          record.requestId,
          record.versionNumber
        );

        if (res.success) {
          toast.success("Final terms confirmed. Awaiting Broker Finalization.", {
            description: `Deal Version ${record.versionNumber} terms are frozen for Booking creation.`,
          });
          setModalType(null);
          queryClient.invalidateQueries({ queryKey: ["seller-broker-requests"] });
          queryClient.invalidateQueries({ queryKey: ["in-app-notifications"] });
          if (onSuccess) onSuccess();
          router.refresh();
        } else {
          if (res.error?.includes("STALE_VERSION_DETECTED")) {
            toast.error("Stale terms detected.", {
              description: "The Broker has updated this deal proposal. Refreshing latest terms...",
              action: {
                label: "Refresh Now",
                onClick: () => {
                  queryClient.invalidateQueries({ queryKey: ["seller-broker-requests"] });
                  router.refresh();
                },
              },
            });
            setModalType(null);
            router.refresh();
          } else {
            toast.error(res.error || "Failed to confirm deal terms");
          }
        }
      } catch (err: any) {
        if (err.message?.includes("STALE_VERSION_DETECTED")) {
          toast.error("Stale terms detected.", {
            description: "The Broker has updated this deal proposal. Refreshing latest terms...",
          });
          setModalType(null);
          router.refresh();
        } else {
          toast.error(err.message || "An unexpected error occurred during confirmation.");
        }
      }
    });
  };

  // Handle Request Broker Correction Submission
  const handleRequestCorrection = () => {
    if (!correctionRemarks.trim() || correctionRemarks.trim().length < 5) {
      toast.error("Please provide at least 5 characters detailing the requested correction.");
      return;
    }

    startTransition(async () => {
      try {
        const res = await requestBrokerCorrectionAction(
          record.requestId,
          record.versionNumber,
          correctionRemarks.trim()
        );

        if (res.success) {
          toast.success("Correction requested. The Broker has been notified.", {
            description: "The Broker Desk will revise terms and generate a new Deal Version.",
          });
          setModalType(null);
          setCorrectionRemarks("");
          queryClient.invalidateQueries({ queryKey: ["seller-broker-requests"] });
          queryClient.invalidateQueries({ queryKey: ["in-app-notifications"] });
          if (onSuccess) onSuccess();
          router.refresh();
        } else {
          if (res.error?.includes("STALE_VERSION_DETECTED")) {
            toast.error("Stale terms detected.", {
              description: "The Broker updated the deal before your request. Refreshing latest version...",
            });
            setModalType(null);
            router.refresh();
          } else {
            toast.error(res.error || "Failed to submit correction request.");
          }
        }
      } catch (err: any) {
        toast.error(err.message || "An unexpected error occurred while requesting correction.");
      }
    });
  };

  if (isAlreadyConfirmed) {
    return (
      <div
        className={`p-4 sm:p-5 rounded-2xl bg-emerald-50/80 border border-emerald-200/90 shadow-2xs flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 ${className}`}
      >
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-full bg-emerald-100 flex items-center justify-center text-[#047857] shrink-0">
            <CheckCircle2 className="w-5 h-5 stroke-[2.25]" />
          </div>
          <div>
            <span className="text-sm font-bold text-[#047857] block">
              Deal Version {record.versionNumber} Confirmed by Seller
            </span>
            <span className="text-xs text-slate-600">
              Commercial terms are frozen and awaiting Broker Finalization to issue unique Booking ID.
            </span>
          </div>
        </div>
        <Button
          onClick={() => router.push("/seller/requests")}
          variant="outline"
          className="w-full sm:w-auto border-emerald-300 text-[#047857] font-bold text-xs rounded-xl h-10 px-4 shrink-0"
        >
          Return to Inbox
        </Button>
      </div>
    );
  }

  if (isSuperseded) {
    return (
      <div
        className={`p-4 sm:p-5 rounded-2xl bg-slate-100 border border-slate-200 shadow-2xs flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 ${className}`}
      >
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-full bg-slate-200 flex items-center justify-center text-slate-700 shrink-0">
            <RotateCcw className="w-5 h-5" />
          </div>
          <div>
            <span className="text-sm font-bold text-slate-800 block">
              Version {record.versionNumber} Has Been Superseded
            </span>
            <span className="text-xs text-slate-500">
              A newer deal version has been created. Historical versions cannot be confirmed.
            </span>
          </div>
        </div>
        <Button
          onClick={() => router.push("/seller/requests")}
          className="w-full sm:w-auto bg-slate-900 text-white font-bold text-xs rounded-xl h-10 px-4 shrink-0"
        >
          View Latest Version
        </Button>
      </div>
    );
  }

  return (
    <div className={`space-y-4 ${className}`}>
      {/* 2-BUTTON CONFIRMATION ACTION BAR */}
      <div className="p-4 sm:p-6 rounded-2xl bg-white border border-slate-200/90 shadow-xs space-y-4">
        <div className="flex items-center justify-between gap-3 flex-wrap">
          <div className="space-y-0.5">
            <h3 className="text-base font-bold text-slate-900">
              Confirm or Request Correction for Version {record.versionNumber}
            </h3>
            <p className="text-xs text-slate-500">
              Confirming locks in these exact terms. Broker Finalization requires this explicit confirmation.
            </p>
          </div>
          <div className="flex items-center gap-1.5 text-xs text-emerald-700 font-semibold bg-emerald-50 border border-emerald-200 px-3 py-1 rounded-lg">
            <ShieldCheck className="w-3.5 h-3.5 text-[#047857]" />
            <span>Audit-Logged Action</span>
          </div>
        </div>

        {/* Action Buttons: 48px Min Touch Target for Tier-2 Mobile */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2">
          {/* 1. CONFIRM FINAL TERMS (PRIMARY / FOREST JADE) */}
          <Button
            type="button"
            onClick={() => setModalType("confirm")}
            disabled={isPending}
            className="w-full min-h-[48px] h-12 bg-[#059669] hover:bg-[#047857] text-white font-bold text-sm sm:text-base rounded-xl transition-all shadow-xs cursor-pointer flex items-center justify-center gap-2"
          >
            <Check className="w-5 h-5 stroke-[2.5]" />
            <span>Confirm Final Terms</span>
          </Button>

          {/* 2. REQUEST BROKER CORRECTION (OUTLINE / DESTRUCTIVE) */}
          <Button
            type="button"
            variant="outline"
            onClick={() => setModalType("correction")}
            disabled={isPending}
            className="w-full min-h-[48px] h-12 border-slate-300 hover:border-slate-400 text-slate-800 hover:bg-slate-50 font-bold text-sm sm:text-base rounded-xl transition-all shadow-xs cursor-pointer flex items-center justify-center gap-2"
          >
            <RotateCcw className="w-4 h-4 text-amber-600" />
            <span>Request Broker Correction</span>
          </Button>
        </div>
      </div>

      {/* ========================================================================= */}
      {/* 1. CONFIRM FINAL TERMS MODAL DIALOG                                       */}
      {/* ========================================================================= */}
      <Dialog open={modalType === "confirm"} onOpenChange={(o) => !o && setModalType(null)}>
        <DialogContent className="sm:max-w-[520px] p-0 rounded-2xl border-slate-200">
          <DialogHeader className="p-6 pb-4 border-b border-slate-100 bg-slate-50/70">
            <div className="flex items-center gap-3">
              <div className="h-10 w-10 rounded-xl bg-emerald-100 text-[#047857] flex items-center justify-center shrink-0">
                <CheckCircle2 className="h-5 w-5 stroke-[2.2]" />
              </div>
              <div>
                <DialogTitle className="text-lg font-bold text-slate-900">
                  Confirm Final Deal Terms
                </DialogTitle>
                <DialogDescription className="text-xs text-slate-500 mt-0.5">
                  You are locking in Deal Version {record.versionNumber} for finalization.
                </DialogDescription>
              </div>
            </div>
          </DialogHeader>

          <div className="p-6 space-y-4 text-xs">
            {/* Commercial Summary Card */}
            <div className="p-4 rounded-xl bg-slate-50 border border-slate-200/80 space-y-2">
              <div className="flex justify-between items-center text-slate-600">
                <span>Commodity:</span>
                <span className="font-bold text-slate-900">{snap.commodityName}</span>
              </div>
              <div className="flex justify-between items-center text-slate-600">
                <span>Agreed Quantity:</span>
                <span className="font-bold text-slate-900">
                  {snap.quantity} {snap.unitSymbol || "MT"}
                </span>
              </div>
              <div className="flex justify-between items-center text-slate-600">
                <span>Final Rate:</span>
                <span className="font-bold text-[#047857]">
                  ₹{snap.rate}/{snap.unitSymbol || "MT"}
                </span>
              </div>
              <div className="flex justify-between items-center text-slate-600 pt-1 border-t border-slate-200/60">
                <span>Delivery Terms:</span>
                <span className="font-semibold text-slate-800">
                  {snap.deliveryTerms || "Ex-Warehouse"}
                </span>
              </div>
            </div>

            <div className="p-3.5 rounded-xl bg-amber-50/70 border border-amber-200/80 text-amber-900 flex items-start gap-2.5">
              <AlertTriangle className="w-4 h-4 text-amber-700 shrink-0 mt-0.5" />
              <p className="leading-relaxed text-[11px]">
                <strong>Immutable Binding:</strong> Once confirmed, this version is permanently recorded. The Broker will finalize and the system will create the unique Booking ID.
              </p>
            </div>
          </div>

          <DialogFooter className="p-6 pt-3 border-t border-slate-100 flex flex-col sm:flex-row gap-2 bg-slate-50/40">
            <Button
              type="button"
              variant="outline"
              onClick={() => setModalType(null)}
              disabled={isPending}
              className="w-full sm:w-auto font-semibold rounded-xl min-h-[48px] h-12"
            >
              Cancel
            </Button>
            <Button
              type="button"
              onClick={handleConfirmTerms}
              disabled={isPending}
              className="w-full sm:w-auto bg-[#059669] hover:bg-[#047857] text-white font-bold rounded-xl min-h-[48px] h-12 gap-2 cursor-pointer shadow-xs"
            >
              {isPending ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  <span>Locking Terms...</span>
                </>
              ) : (
                <>
                  <Check className="w-4 h-4 stroke-[3]" />
                  <span>Confirm Exact Terms</span>
                </>
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ========================================================================= */}
      {/* 2. REQUEST BROKER CORRECTION MODAL DIALOG                                 */}
      {/* ========================================================================= */}
      <Dialog open={modalType === "correction"} onOpenChange={(o) => !o && setModalType(null)}>
        <DialogContent className="sm:max-w-[540px] p-0 rounded-2xl border-slate-200">
          <DialogHeader className="p-6 pb-4 border-b border-slate-100 bg-slate-50/70">
            <div className="flex items-center gap-3">
              <div className="h-10 w-10 rounded-xl bg-amber-100 text-amber-800 flex items-center justify-center shrink-0">
                <RotateCcw className="h-5 w-5" />
              </div>
              <div>
                <DialogTitle className="text-lg font-bold text-slate-900">
                  Request Broker Correction
                </DialogTitle>
                <DialogDescription className="text-xs text-slate-500 mt-0.5">
                  Request changes to Version {record.versionNumber}. The Broker will generate a new Deal Version.
                </DialogDescription>
              </div>
            </div>
          </DialogHeader>

          <div className="p-6 space-y-4 text-xs">
            <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200/80 text-slate-600 leading-relaxed">
              <span>
                Please specify the exact parameters requiring adjustment. Your remarks will be transmitted directly to the Broker Desk.
              </span>
            </div>

            {/* Quick selection chips */}
            <div className="space-y-1.5">
              <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block">
                Quick Reason Select
              </span>
              <div className="flex flex-wrap gap-1.5">
                {CORRECTION_QUICK_CHIPS.map((chip) => (
                  <button
                    key={chip}
                    type="button"
                    onClick={() => {
                      if (!correctionRemarks.includes(chip)) {
                        setCorrectionRemarks((prev) =>
                          prev ? `${prev}, ${chip}` : chip
                        );
                      }
                    }}
                    className="px-2.5 py-1 rounded-lg text-xs bg-slate-100 hover:bg-amber-50 hover:text-amber-800 text-slate-700 transition-colors border border-slate-200 cursor-pointer"
                  >
                    + {chip}
                  </button>
                ))}
              </div>
            </div>

            {/* Custom remarks textarea */}
            <div className="space-y-1.5 pt-1">
              <label className="text-xs font-bold text-slate-700 block">
                Detailed Correction Notes <span className="text-rose-500">*</span>
              </label>
              <Textarea
                placeholder="E.g., We cannot fulfill at ₹4,100/MT due to rising transport costs. Please counter at ₹4,180/MT or adjust quantity to 100 MT."
                value={correctionRemarks}
                onChange={(e) => setCorrectionRemarks(e.target.value)}
                rows={4}
                className="w-full text-xs rounded-xl border-slate-200 focus:border-amber-500 focus:ring-amber-500"
              />
              <span className="text-[11px] text-slate-400">
                Minimum 5 characters required ({correctionRemarks.trim().length}/5).
              </span>
            </div>
          </div>

          <DialogFooter className="p-6 pt-3 border-t border-slate-100 flex flex-col sm:flex-row gap-2 bg-slate-50/40">
            <Button
              type="button"
              variant="outline"
              onClick={() => setModalType(null)}
              disabled={isPending}
              className="w-full sm:w-auto font-semibold rounded-xl min-h-[48px] h-12"
            >
              Cancel
            </Button>
            <Button
              type="button"
              onClick={handleRequestCorrection}
              disabled={isPending || correctionRemarks.trim().length < 5}
              className="w-full sm:w-auto bg-amber-600 hover:bg-amber-700 text-white font-bold rounded-xl min-h-[48px] h-12 gap-2 cursor-pointer shadow-xs"
            >
              {isPending ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  <span>Dispatching Request...</span>
                </>
              ) : (
                <>
                  <Send className="w-4 h-4" />
                  <span>Send Correction Request</span>
                </>
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
