import React, { Suspense } from "react";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ShieldCheck, FileCheck2, Loader2 } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { BackButton } from "@/src/components/ui/back-button";
import { getDealVersionSnapshotAction } from "@/src/server/actions/version-actions";
import { VisualDiffSnapshot } from "@/src/components/dashboard/visual-diff-snapshot";
import { FinalConfirmationActions } from "@/src/components/dashboard/final-confirmation-actions";

export const dynamic = "force-dynamic";

interface ConfirmDealPageProps {
  params: Promise<{ id: string }> | { id: string };
}

export default async function ConfirmDealPage({ params }: ConfirmDealPageProps) {
  const resolvedParams = await params;
  const dealId = resolvedParams.id;

  if (!dealId) {
    notFound();
  }

  // Pre-fetch initial snapshot and server-computed visual diff
  const snapshotRes = await getDealVersionSnapshotAction(dealId);
  const snapshotData = snapshotRes.success && snapshotRes.data ? snapshotRes.data : null;

  return (
    <div className="min-h-screen bg-[#F8FAFC] font-sans antialiased text-slate-900 pb-20">
      {/* TOP STICKY APP BAR */}
      <header className="sticky top-0 z-30 bg-white/95 backdrop-blur-md border-b border-slate-200/90 shadow-2xs">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <BackButton label="Back" fallbackUrl={`/seller/deals/${dealId}`} />

            <div className="hidden sm:flex items-center gap-2">
              <span className="text-slate-300">/</span>
              <span className="text-sm font-bold text-slate-900">Final Deal Confirmation</span>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <Badge
              variant="outline"
              className="bg-emerald-50 text-[#047857] border-emerald-200 font-bold text-xs gap-1.5 hidden sm:inline-flex"
            >
              <ShieldCheck className="h-3.5 w-3.5" />
              <span>Zero-Buyer Exposure Active</span>
            </Badge>
          </div>
        </div>
      </header>

      {/* HERO SECTION */}
      <div className="bg-white border-b border-slate-200/80">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-6 sm:py-8">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div className="space-y-1">
              <div className="flex items-center gap-2">
                <div className="w-7 h-7 rounded-lg bg-emerald-100 flex items-center justify-center text-[#047857]">
                  <FileCheck2 className="w-4 h-4" />
                </div>
                <h1 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
                  Final Deal Confirmation
                </h1>
              </div>
              <p className="text-xs sm:text-sm text-slate-500 leading-relaxed max-w-2xl">
                Review the exact, immutable commercial terms below with visual change highlights. Confirm to lock in terms for Broker Finalization.
              </p>
            </div>

            <div className="flex items-center gap-2">
              <Badge className="bg-slate-900 text-white font-bold text-xs px-3 py-1 rounded-lg">
                Visual Diff Mode Active
              </Badge>
            </div>
          </div>
        </div>
      </div>

      {/* MAIN CONTAINER */}
      <main className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 pt-6 sm:pt-8 space-y-8">
        <Suspense
          fallback={
            <div className="flex items-center justify-center py-16">
              <Loader2 className="h-7 w-7 animate-spin text-emerald-600" />
            </div>
          }
        >
          <VisualDiffSnapshot versionId={dealId} initialData={snapshotData} />
        </Suspense>

        {/* 2-BUTTON CONFIRMATION ACTION BAR */}
        {snapshotData && (
          <FinalConfirmationActions record={snapshotData} />
        )}
      </main>
    </div>
  );
}

