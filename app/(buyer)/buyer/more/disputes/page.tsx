import React from 'react';
import { Metadata } from 'next';
import Link from 'next/link';
import { ArrowLeft, ShieldAlert } from 'lucide-react';
import { getBuyerActiveDisputesAction } from '@/src/server/actions/buyer-dispute-actions';
import { BuyerDisputesFeed } from '@/src/components/buyer/disputes/buyer-disputes-feed';
import { BackButton } from '@/src/components/ui/back-button';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Dispute Ledger & Exceptions | BrokerBridge Buyer',
  description:
    'Track quality deviations, weight shortages, and transit exceptions submitted for neutral Broker mediation. Zero direct seller communication.',
};

/**
 * Task 3 (Micro-Sprint 39.4): Buyer Dispute Tracker Page.
 * 
 * Route: /buyer/more/disputes
 * Dedicated Dispute Ledger accessible from the "More" section.
 * Fetches getBuyerActiveDisputesAction() and renders a list of BuyerDisputeCard elements.
 * 
 * STRICT UX RULE:
 * This is a strictly read-only tracker. There is NO chat box.
 * The Buyer tracks official Broker mediation findings and resolution outcomes.
 */
export default async function BuyerDisputesPage() {
  const response = await getBuyerActiveDisputesAction();

  const fallbackSummary = {
    totalDisputes: 0,
    openCount: 0,
    underReviewCount: 0,
    resolvedCount: 0,
  };

  const disputes = response.success && response.data ? response.data.disputes : [];
  const summary = response.success && response.data ? response.data.summary : fallbackSummary;

  return (
    <div className="w-full max-w-full overflow-x-hidden min-h-full bg-slate-50/50 pb-20">
      {/* Sticky Header */}
      <header className="sticky top-0 z-20 w-full bg-white/95 backdrop-blur-md border-b border-slate-200 shadow-2xs">
        <div className="max-w-4xl mx-auto px-4 h-16 flex items-center justify-between gap-3">
          <div className="flex items-center gap-3 min-w-0">
            <BackButton
              fallbackUrl="/buyer/more"
              label="More Tools"
              className="min-h-[48px] h-12 px-3 py-2 rounded-xl border border-slate-200 text-slate-700 hover:text-slate-900 hover:bg-slate-100 text-xs font-semibold shrink-0"
            />

            <div className="h-5 w-px bg-slate-200 shrink-0 hidden sm:block" />

            <div className="min-w-0">
              <span className="text-[10px] sm:text-xs font-bold text-slate-400 uppercase tracking-wider block">
                Broker Mediation Desk
              </span>
              <h1 className="text-sm sm:text-base font-bold text-slate-900 truncate">
                Dispute Ledger & Exceptions
              </h1>
            </div>
          </div>

          <div className="flex items-center gap-2 shrink-0">
            <Link
              href="/buyer/orders"
              className="inline-flex items-center justify-center min-h-[48px] h-12 px-3.5 rounded-xl border border-slate-200 text-xs font-semibold text-slate-700 hover:text-slate-900 hover:bg-slate-50 transition-colors"
            >
              <span>My Orders</span>
            </Link>
          </div>
        </div>
      </header>

      {/* Main Container */}
      <main className="max-w-4xl mx-auto p-4 sm:p-6 lg:p-8">
        <BuyerDisputesFeed
          initialDisputes={disputes}
          initialSummary={summary}
        />
      </main>
    </div>
  );
}
