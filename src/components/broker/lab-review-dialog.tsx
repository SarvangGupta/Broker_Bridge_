"use client";

import { useState, useEffect } from "react";
import { format } from "date-fns";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import {
  Loader2,
  Building2,
  Calendar,
  FileCheck2,
  ExternalLink,
  ShieldCheck,
  AlertTriangle,
  CheckCircle2,
  XCircle,
  FileText,
  AlertCircle,
  FlaskConical,
} from "lucide-react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import { QualityStatusBadge } from "@/src/components/dashboard/quality-status-badge";
import {
  getLabTestReviewDetailsAction,
  reviewLabTestAction,
  getSignedLabDocumentUrlAction,
  VerificationDecision,
} from "@/src/server/actions/quality-verification-actions";

interface LabReviewDialogProps {
  labTestId?: string;
  availabilityId?: string;
  trigger?: React.ReactNode;
  open?: boolean;
  onOpenChange?: (open: boolean) => void;
  onSuccess?: () => void;
}

export function LabReviewDialog({
  labTestId,
  availabilityId,
  trigger,
  open: controlledOpen,
  onOpenChange: setControlledOpen,
  onSuccess,
}: LabReviewDialogProps) {
  const [internalOpen, setInternalOpen] = useState(false);
  const isControlled = controlledOpen !== undefined;
  const open = isControlled ? controlledOpen : internalOpen;
  const setOpen = isControlled ? setControlledOpen! : setInternalOpen;

  const [loading, setLoading] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isGeneratingUrl, setIsGeneratingUrl] = useState(false);
  const [notes, setNotes] = useState("");
  const [reviewData, setReviewData] = useState<any>(null);

  useEffect(() => {
    if (open && (labTestId || availabilityId)) {
      loadDetails();
    }
  }, [open, labTestId, availabilityId]);

  async function loadDetails() {
    setLoading(true);
    try {
      const res = await getLabTestReviewDetailsAction({ labTestId, availabilityId });
      if (res.success && res.data) {
        setReviewData(res.data);
        setNotes(res.data.labTest.verificationNotes || "");
      } else {
        toast.error(res.error || "Failed to load laboratory test details.");
      }
    } catch (err: any) {
      toast.error("An error occurred while loading lab review details.");
    } finally {
      setLoading(false);
    }
  }

  async function handleDecision(decision: VerificationDecision) {
    if (!reviewData?.labTest?.id) return;

    if (decision !== "Verified" && !notes.trim()) {
      toast.error(`Please provide verification feedback notes when ${decision === "Rejected" ? "rejecting" : "requesting corrections"}.`);
      return;
    }

    setIsSubmitting(true);
    try {
      const res = await reviewLabTestAction({
        labTestId: reviewData.labTest.id,
        decision,
        verificationNotes: notes,
      });

      if (res.success) {
        toast.success(`Lab evidence status updated to '${decision}'`);
        onSuccess?.();
        setOpen(false);
      } else {
        toast.error(res.error || "Failed to submit verification decision.");
      }
    } catch (err: any) {
      toast.error(err.message || "An unexpected error occurred.");
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleOpenDocument() {
    if (!reviewData?.labTest?.id) return;
    setIsGeneratingUrl(true);
    try {
      const res = await getSignedLabDocumentUrlAction(reviewData.labTest.id);
      if (res.success && res.data?.signedUrl) {
        window.open(res.data.signedUrl, "_blank", "noopener,noreferrer");
      } else {
        toast.error(res.error || "Unable to retrieve evidence document.");
      }
    } catch (err: any) {
      toast.error("Failed to generate temporary document link.");
    } finally {
      setIsGeneratingUrl(false);
    }
  }

  const labTest = reviewData?.labTest;
  const availability = reviewData?.availability;
  const parameters = reviewData?.parameters || [];

  const isPendingReview =
    labTest?.status === "Under Review" ||
    labTest?.status === "Report Uploaded" ||
    labTest?.status === "Sample Pending" ||
    labTest?.status === "Correction Required";

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      {trigger && <DialogTrigger>{trigger}</DialogTrigger>}
      <DialogContent className="max-w-3xl max-h-[90vh] overflow-y-auto p-6 sm:p-8">
        <DialogHeader className="pb-3 border-b">
          <div className="flex items-center justify-between gap-3 flex-wrap">
            <div>
              <DialogTitle className="text-xl font-bold text-slate-900 flex items-center gap-2">
                <ShieldCheck className="h-5 w-5 text-primary" />
                Laboratory Test & Quality Verification
              </DialogTitle>
              <DialogDescription className="text-xs sm:text-sm text-slate-500 mt-1">
                Broker Audit Center • Review analytical lab test certificate and confirm grade specifications.
              </DialogDescription>
            </div>
            {labTest && (
              <QualityStatusBadge
                status={labTest.effectiveStatus || labTest.status}
                validUntil={labTest.validUntil}
                testDate={labTest.testDate}
              />
            )}
          </div>
        </DialogHeader>

        {loading ? (
          <div className="flex flex-col items-center justify-center p-12 space-y-3">
            <Loader2 className="h-8 w-8 animate-spin text-primary" />
            <p className="text-sm font-medium text-slate-600">
              Retrieving laboratory audit package...
            </p>
          </div>
        ) : !reviewData ? (
          <div className="p-8 text-center text-sm text-muted-foreground">
            No laboratory test record found for this lot.
          </div>
        ) : (
          <div className="space-y-6 pt-2">
            {/* LOT & LAB METADATA GRID */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 p-4 rounded-xl bg-slate-50 border border-slate-200/80 text-xs">
              <div>
                <span className="text-slate-400 font-medium block uppercase tracking-wider text-[10px]">
                  Seller Company
                </span>
                <span className="font-semibold text-slate-800 text-sm truncate block mt-0.5">
                  {availability?.sellerCompanyName || "Seller"}
                </span>
              </div>
              <div>
                <span className="text-slate-400 font-medium block uppercase tracking-wider text-[10px]">
                  Commodity & Grade
                </span>
                <span className="font-semibold text-slate-800 text-sm truncate block mt-0.5">
                  {availability?.commodityName || "—"} ({availability?.gradeName || "Std"})
                </span>
              </div>
              <div>
                <span className="text-slate-400 font-medium block uppercase tracking-wider text-[10px]">
                  Laboratory Agency
                </span>
                <span className="font-semibold text-slate-800 text-sm truncate block mt-0.5">
                  {labTest?.laboratoryName || "—"}
                </span>
              </div>
              <div>
                <span className="text-slate-400 font-medium block uppercase tracking-wider text-[10px]">
                  Report #
                </span>
                <span className="font-mono font-semibold text-slate-800 text-sm truncate block mt-0.5">
                  {labTest?.reportNumber || "—"}
                </span>
              </div>
              <div>
                <span className="text-slate-400 font-medium block uppercase tracking-wider text-[10px]">
                  Analysis Date
                </span>
                <span className="font-medium text-slate-700 block mt-0.5">
                  {labTest?.testDate ? format(new Date(labTest.testDate), "MMM d, yyyy") : "—"}
                </span>
              </div>
              <div>
                <span className="text-slate-400 font-medium block uppercase tracking-wider text-[10px]">
                  Report Issuance Date
                </span>
                <span className="font-medium text-slate-700 block mt-0.5">
                  {labTest?.reportDate ? format(new Date(labTest.reportDate), "MMM d, yyyy") : "—"}
                </span>
              </div>
              <div>
                <span className="text-slate-400 font-medium block uppercase tracking-wider text-[10px]">
                  Validity Expiry
                </span>
                <span className="font-medium text-slate-700 block mt-0.5">
                  {labTest?.validUntil ? format(new Date(labTest.validUntil), "MMM d, yyyy") : "Standard (30 Days)"}
                </span>
              </div>
              <div>
                <span className="text-slate-400 font-medium block uppercase tracking-wider text-[10px]">
                  Sample Reference
                </span>
                <span className="font-mono font-medium text-slate-700 block mt-0.5">
                  {labTest?.sampleId || "Not Specified"}
                </span>
              </div>
            </div>

            {/* SECTION 1: STRUCTURED PARAMETER COMPARISON TABLE */}
            <div className="space-y-2.5">
              <div className="flex items-center justify-between">
                <h4 className="text-sm font-bold text-slate-900 flex items-center gap-1.5">
                  <FlaskConical className="h-4 w-4 text-primary" />
                  1. Laboratory Analytical Parameter Conformance
                </h4>
                <span className="text-xs text-muted-foreground">
                  {parameters.length} Parameter{parameters.length === 1 ? "" : "s"} Analyzed
                </span>
              </div>

              <div className="border rounded-xl overflow-hidden bg-white shadow-xs">
                <div className="overflow-x-auto">
                  <table className="w-full text-left text-xs border-collapse">
                    <thead>
                      <tr className="bg-slate-100/80 border-b text-slate-600 font-semibold">
                        <th className="py-2.5 px-3">Quality Parameter</th>
                        <th className="py-2.5 px-3">Measured Lab Value</th>
                        <th className="py-2.5 px-3">Standard Spec Range</th>
                        <th className="py-2.5 px-3 text-center">Conformance</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100">
                      {parameters.length === 0 ? (
                        <tr>
                          <td colSpan={4} className="py-6 text-center text-muted-foreground">
                            No structured test results recorded for this test.
                          </td>
                        </tr>
                      ) : (
                        parameters.map((p: any) => (
                          <tr key={p.parameterId} className="hover:bg-slate-50/50">
                            <td className="py-2.5 px-3 font-medium text-slate-900">
                              {p.parameterName}
                              {p.unit && <span className="text-slate-400 font-normal ml-1">({p.unit})</span>}
                            </td>
                            <td className="py-2.5 px-3 font-mono font-bold text-slate-800">
                              {p.measuredValue} {p.unit || ""}
                            </td>
                            <td className="py-2.5 px-3 text-slate-500 font-mono">
                              {p.minValue !== null || p.maxValue !== null ? (
                                <span>
                                  {p.minValue ?? "0"} – {p.maxValue ?? "∞"} {p.unit || ""}
                                </span>
                              ) : (
                                "Open Specification"
                              )}
                            </td>
                            <td className="py-2.5 px-3 text-center">
                              {p.isWithinBounds ? (
                                <Badge variant="outline" className="bg-emerald-50 text-emerald-700 border-emerald-200 text-[10px] font-medium">
                                  <CheckCircle2 className="w-3 h-3 mr-1" />
                                  In Spec
                                </Badge>
                              ) : (
                                <Badge variant="outline" className="bg-amber-50 text-amber-700 border-amber-200 text-[10px] font-medium">
                                  <AlertTriangle className="w-3 h-3 mr-1" />
                                  Out of Spec
                                </Badge>
                              )}
                            </td>
                          </tr>
                        ))
                      )}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>

            {/* SECTION 2: PHYSICAL CERTIFICATE DOCUMENT VAULT */}
            <div className="space-y-2.5">
              <h4 className="text-sm font-bold text-slate-900 flex items-center gap-1.5">
                <FileText className="h-4 w-4 text-primary" />
                2. Stamped Analytical Certificate Evidence
              </h4>

              {labTest?.fileUrl ? (
                <div className="flex flex-col sm:flex-row sm:items-center justify-between p-4 rounded-xl border border-emerald-200 bg-emerald-50/40 gap-3">
                  <div className="flex items-center space-x-3">
                    <div className="p-2 rounded-lg bg-emerald-100 text-emerald-800 shrink-0">
                      <FileCheck2 className="h-5 w-5" />
                    </div>
                    <div>
                      <p className="text-sm font-semibold text-slate-900">
                        Official Stamped Certificate of Analysis
                      </p>
                      <p className="text-xs text-muted-foreground">
                        Stored in BrokerBridge Encrypted Storage Vault
                      </p>
                    </div>
                  </div>

                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    onClick={handleOpenDocument}
                    disabled={isGeneratingUrl}
                    className="min-h-[48px] h-12 bg-white px-5 text-xs font-semibold shrink-0"
                  >
                    {isGeneratingUrl ? (
                      <Loader2 className="h-4 w-4 animate-spin mr-1.5" />
                    ) : (
                      <ExternalLink className="h-4 w-4 mr-1.5 text-slate-600" />
                    )}
                    View Physical Document
                  </Button>
                </div>
              ) : (
                <div className="p-4 rounded-xl border border-dashed text-center text-xs text-muted-foreground bg-slate-50">
                  No physical PDF / Certificate file has been uploaded by the seller.
                </div>
              )}
            </div>

            {/* SECTION 3: AUDIT TRAIL OR ACTION BAR */}
            <div className="space-y-3 pt-2">
              <label htmlFor="broker-notes" className="text-sm font-bold text-slate-900 block">
                Verification Notes & Auditor Feedback
              </label>
              <Textarea
                id="broker-notes"
                placeholder="Add audit comments, quality observations, or reasons if requesting corrections..."
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                disabled={isSubmitting || !isPendingReview}
                className="text-sm min-h-[80px]"
              />

              {labTest?.verifiedBy && (
                <div className="p-3 rounded-lg bg-slate-100 border text-xs text-slate-600">
                  <span className="font-semibold">Last Audited:</span>{" "}
                  {labTest.verifiedAt ? format(new Date(labTest.verifiedAt), "PPP 'at' p") : "—"}
                </div>
              )}
            </div>
          </div>
        )}

        <DialogFooter className="pt-4 border-t gap-2 sm:gap-3 flex-col sm:flex-row">
          <Button
            type="button"
            variant="outline"
            onClick={() => setOpen(false)}
            disabled={isSubmitting}
            className="min-h-[48px] h-12 px-5"
          >
            Close
          </Button>

          {isPendingReview && reviewData && (
            <>
              <Button
                type="button"
                variant="outline"
                onClick={() => handleDecision("Correction Required")}
                disabled={isSubmitting}
                className="min-h-[48px] h-12 px-4 text-orange-700 hover:bg-orange-50 hover:text-orange-800 border-orange-200 font-semibold"
              >
                {isSubmitting ? <Loader2 className="h-4 w-4 animate-spin mr-1" /> : <AlertTriangle className="h-4 w-4 mr-1.5" />}
                Request Correction
              </Button>

              <Button
                type="button"
                variant="destructive"
                onClick={() => handleDecision("Rejected")}
                disabled={isSubmitting}
                className="min-h-[48px] h-12 px-4 font-semibold"
              >
                {isSubmitting ? <Loader2 className="h-4 w-4 animate-spin mr-1" /> : <XCircle className="h-4 w-4 mr-1.5" />}
                Reject Evidence
              </Button>

              <Button
                type="button"
                onClick={() => handleDecision("Verified")}
                disabled={isSubmitting}
                className="min-h-[48px] h-12 px-6 bg-emerald-600 hover:bg-emerald-700 text-white font-semibold"
              >
                {isSubmitting ? <Loader2 className="h-4 w-4 animate-spin mr-1" /> : <CheckCircle2 className="h-4 w-4 mr-1.5" />}
                Approve & Mark Verified
              </Button>
            </>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
