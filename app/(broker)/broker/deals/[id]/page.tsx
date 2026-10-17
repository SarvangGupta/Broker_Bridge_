import React from 'react';
import Link from 'next/link';
import { ArrowLeft, Handshake, AlertCircle } from 'lucide-react';
import {
  getBrokerDealDetailAction,
  getBrokerDealContextAction,
} from '@/src/server/actions/broker-deal-actions';
import { DealNegotiationWorkspace } from '@/src/components/broker/deals/deal-negotiation-workspace';
import { DealBuilder } from '@/src/components/broker/work/deal-builder';
import { ConfirmationTracker } from '@/src/components/broker/deals/confirmation-tracker';
import { BookingGate } from '@/src/components/broker/deals/booking-gate';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';

interface BrokerDealDetailPageProps {
  params: Promise<{ id: string }> | { id: string };
}

export default async function BrokerDealDetailPage({ params }: BrokerDealDetailPageProps) {
  const resolvedParams = await params;
  const requestId = resolvedParams.id;

  // 1. Try fetching authoritative RB-10 deal detail
  const detailRes = await getBrokerDealDetailAction(requestId);

  if (detailRes.success && detailRes.data) {
    return (
      <div className="p-4 sm:p-6 lg:p-8 space-y-6 w-full max-w-7xl mx-auto overflow-x-hidden">
        {/* Navigation Breadcrumb */}
        <Link
          href="/broker/deals"
          className="inline-flex items-center gap-1.5 text-xs font-semibold text-teal-700 hover:text-teal-900 transition-colors"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to Deals & Negotiations
        </Link>

        {/* RB-10 Deal Negotiation & Confirmation Workspace */}
        <DealNegotiationWorkspace initialData={detailRes.data} />
      </div>
    );
  }

  // 2. Fallback to legacy deal context if accessing quotation directly
  const contextRes = await getBrokerDealContextAction(requestId);

  if (contextRes.success && contextRes.data) {
    return (
      <div className="p-4 sm:p-6 lg:p-8 space-y-6 w-full max-w-7xl mx-auto overflow-x-hidden">
        {/* Top Breadcrumb & Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div>
            <Link
              href="/broker/deals"
              className="inline-flex items-center gap-1.5 text-xs font-semibold text-teal-700 hover:text-teal-900 transition-colors mb-2"
            >
              <ArrowLeft className="w-4 h-4" />
              Back to Deals
            </Link>
            <h1 className="text-2xl sm:text-3xl font-bold text-slate-900 tracking-tight flex items-center gap-2.5">
              <Handshake className="w-7 h-7 text-[#0D9488]" />
              Broker Deal Builder & Snapshot Generator
            </h1>
            <p className="text-xs sm:text-sm text-slate-500 mt-1">
              Consolidate negotiated commercial terms, set commission spread, and freeze immutable contract snapshot.
            </p>
          </div>
        </div>

        <DealBuilder initialData={contextRes.data} />
        <ConfirmationTracker requestId={requestId} />
        <BookingGate
          requestId={requestId}
          expectedVersion={contextRes.data.expectedVersionNumber}
        />
      </div>
    );
  }

  // 3. Error state if neither found
  return (
    <div className="p-4 sm:p-6 lg:p-8 space-y-6 w-full max-w-7xl mx-auto overflow-x-hidden">
      <Link
        href="/broker/deals"
        className="inline-flex items-center gap-1.5 text-xs sm:text-sm font-semibold text-teal-700 hover:text-teal-900 transition-colors"
      >
        <ArrowLeft className="w-4 h-4" />
        Back to Deals
      </Link>

      <Card className="border-red-200 bg-red-50/50">
        <CardContent className="p-6 text-center space-y-4">
          <div className="mx-auto w-12 h-12 rounded-full bg-red-100 flex items-center justify-center text-red-600">
            <AlertCircle className="w-6 h-6" />
          </div>
          <div className="space-y-1 max-w-md mx-auto">
            <h3 className="font-bold text-slate-900 text-base">Unable to Load Deal Context</h3>
            <p className="text-xs sm:text-sm text-slate-600">
              {detailRes.error || contextRes.error || 'The requested deal record could not be found or has expired.'}
            </p>
          </div>
          <Link href="/broker/deals">
            <Button className="bg-slate-900 text-white hover:bg-slate-800 text-xs font-semibold h-10 px-4">
              Return to Deals List
            </Button>
          </Link>
        </CardContent>
      </Card>
    </div>
  );
}
