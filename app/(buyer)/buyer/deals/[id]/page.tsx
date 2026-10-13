import React from 'react';
import Link from 'next/link';
import { Metadata } from 'next';
import { ArrowLeft, Handshake, PackageX } from 'lucide-react';
import { getFinalDealReviewAction } from '@/src/server/actions/buyer-deal-actions';
import { FinalDealReview } from '@/src/components/buyer/deals/final-deal-review';
import { FinalConfirmationActions } from '@/src/components/buyer/deals/final-confirmation-actions';
import { BackButton } from '@/src/components/ui/back-button';
import { EmptyState } from '@/src/components/ui/empty-state';

export const dynamic = 'force-dynamic';

interface PageProps {
  params: Promise<{ id: string }>;
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const resolvedParams = await params;
  return {
    title: `Final Deal Review ${resolvedParams.id.slice(0, 8).toUpperCase()} | BrokerBridge Buyer`,
    description: 'Review final agreed commercial snapshot and visual diff comparison before official confirmation.',
  };
}

export default async function BuyerFinalDealReviewPage({ params }: PageProps) {
  const resolvedParams = await params;
  const dealId = resolvedParams.id;

  const res = await getFinalDealReviewAction(dealId);

  // If deal not found or access denied
  if (!res.success || !res.data) {
    return (
      <div className="w-full max-w-full overflow-x-hidden min-h-[70vh] flex flex-col items-center justify-center p-4 sm:p-6">
        <EmptyState
          title="Deal Not Found"
          description={
            res.error ||
            'This commercial deal snapshot does not exist, has expired, or is restricted under organization isolation rules.'
          }
          icon={PackageX}
          actionLabel="Back to Proposals"
          actionVariant="default"
          className="max-w-md w-full bg-white shadow-xs"
        >
          <Link
            href="/buyer/proposals"
            className="inline-flex items-center justify-center min-h-[48px] px-6 rounded-xl bg-[#0284C7] hover:bg-[#0369A1] text-white text-xs sm:text-sm font-bold shadow-xs transition-colors w-full"
          >
            <ArrowLeft className="w-4 h-4 mr-2" />
            <span>Return to Proposals Inbox</span>
          </Link>
        </EmptyState>
      </div>
    );
  }

  const reviewData = res.data;

  return (
    <div className="w-full max-w-full overflow-x-hidden min-h-screen bg-slate-50/50 pb-28 sm:pb-32">
      {/* 1. Sticky Navigation Bar */}
      <header className="sticky top-0 z-20 w-full bg-white/95 backdrop-blur-md border-b border-slate-200 shadow-2xs">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between gap-3">
          <div className="flex items-center gap-3 min-w-0">
            <BackButton
              fallbackUrl="/buyer/proposals"
              label="Proposals"
              className="min-h-[48px] h-12 px-3 py-2 rounded-xl border border-slate-200 text-slate-700 hover:text-slate-900 hover:bg-slate-100 text-xs font-semibold shrink-0"
            />

            <div className="hidden sm:block h-5 w-px bg-slate-200 shrink-0" />

            <div className="min-w-0 truncate">
              <span className="text-[11px] font-semibold text-slate-400 block uppercase tracking-wider">
                Final Deal Snapshot
              </span>
              <span className="text-xs sm:text-sm font-bold text-slate-900 truncate block">
                {reviewData.currentTerms.commodityName} — {reviewData.currentTerms.quantity} {reviewData.currentTerms.unitSymbol}
              </span>
            </div>
          </div>

          <div className="flex items-center gap-2 shrink-0">
            <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold bg-sky-50 text-[#0284C7] border border-sky-200">
              <Handshake className="w-3.5 h-3.5" />
              <span className="hidden xs:inline">Broker Mediated</span>
            </span>
          </div>
        </div>
      </header>

      {/* 2. Main Content Container: Stacked Cards Review with Visual Diff */}
      <main className="max-w-4xl mx-auto px-4 sm:px-6 pt-6">
        <FinalDealReview data={reviewData} />
      </main>

      {/* 3. Sticky Bottom Action Bar & Modal Gate (Micro-Sprint 37.2) */}
      <FinalConfirmationActions
        dealId={reviewData.dealId}
        versionNumber={reviewData.versionNumber}
        status={reviewData.status}
        confirmedAt={reviewData.updatedAt}
      />
    </div>
  );
}
