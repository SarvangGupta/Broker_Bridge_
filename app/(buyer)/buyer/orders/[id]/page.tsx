import React from 'react';
import Link from 'next/link';
import { Metadata } from 'next';
import { ArrowLeft, PackageX } from 'lucide-react';
import { getBuyerBookingVisibilityAction } from '@/src/server/actions/buyer-order-actions';
import { getBuyerTransactionQualityAction } from '@/src/server/actions/buyer-quality-tracking-actions';
import { getBuyerDocumentMatrixAction } from '@/src/server/actions/buyer-document-actions';
import { getBuyerPayableLedgerAction } from '@/src/server/actions/buyer-payment-actions';
import { BookingVisibilityCard } from '@/src/components/buyer/orders/booking-visibility-card';
import { OrderFulfillmentCard } from '@/src/components/buyer/orders/order-fulfillment-card';
import { LogisticsTimeline } from '@/src/components/buyer/orders/logistics-timeline';
import { DeliveryDetailsCard } from '@/src/components/buyer/orders/delivery-details-card';
import { TransactionQualityCard } from '@/src/components/buyer/orders/transaction-quality-card';
import { TransactionDocumentVault } from '@/src/components/buyer/orders/transaction-document-vault';
import { BuyerPaymentCard } from '@/src/components/buyer/orders/buyer-payment-card';
import { RaiseDisputeModal } from '@/src/components/buyer/orders/raise-dispute-modal';
import { BackButton } from '@/src/components/ui/back-button';
import { EmptyState } from '@/src/components/ui/empty-state';

export const dynamic = 'force-dynamic';

interface PageProps {
  params: Promise<{ id: string }>;
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const resolvedParams = await params;
  return {
    title: `Order & Booking ${resolvedParams.id.toUpperCase()} | BrokerBridge Buyer`,
    description: 'Track locked Booking ID, partial fulfillment allocation, live vehicle details, and transit logistics.',
  };
}

/**
 * Tasks 3 & 4 (Micro-Sprint 38.4 & 38.5): Buyer Order Detail Page.
 * Renders BookingVisibilityCard, OrderFulfillmentCard, LogisticsTimeline, and DeliveryDetailsCard
 * in an app-like max-w-3xl reading layout.
 */
export default async function BuyerOrderDetailPage({ params }: PageProps) {
  const resolvedParams = await params;
  const bookingId = resolvedParams.id;

  const res = await getBuyerBookingVisibilityAction(bookingId);

  // If booking not found or unauthorized under tenant isolation rules
  if (!res.success || !res.data) {
    return (
      <div className="w-full max-w-full overflow-x-hidden min-h-[70vh] flex flex-col items-center justify-center p-4 sm:p-6">
        <EmptyState
          title="Booking Not Found"
          description={
            res.error ||
            'This booking record does not exist or is restricted under organization isolation rules.'
          }
          icon={PackageX}
          actionLabel="Back to Orders"
          actionVariant="default"
          className="max-w-md w-full bg-white shadow-xs"
        >
          <Link
            href="/buyer/orders"
            className="inline-flex items-center justify-center min-h-[48px] px-6 rounded-xl bg-[#0284C7] hover:bg-[#0369A1] text-white text-xs sm:text-sm font-bold shadow-xs transition-colors w-full"
          >
            <ArrowLeft className="w-4 h-4 mr-2" />
            <span>Return to Orders Inbox</span>
          </Link>
        </EmptyState>
      </div>
    );
  }

  const bookingData = res.data;

  // Fetch verified transaction quality & physical weighment data (Micro-Sprint 39.1)
  const qualityRes = await getBuyerTransactionQualityAction(bookingId);

  // Fetch fulfillment document compliance matrix (Micro-Sprint 39.2)
  const documentMatrixRes = await getBuyerDocumentMatrixAction(bookingId);

  // Fetch financial payable ledger and escrow status (Micro-Sprint 39.3)
  const paymentRes = await getBuyerPayableLedgerAction(bookingId);

  return (
    <div className="w-full max-w-full overflow-x-hidden min-h-full bg-slate-50/50 pb-20">
      {/* 1. Sticky Navigation Header */}
      <header className="sticky top-0 z-20 w-full bg-white/95 backdrop-blur-md border-b border-slate-200 shadow-2xs">
        <div className="max-w-3xl mx-auto px-4 h-16 flex items-center justify-between gap-3">
          <div className="flex items-center gap-3 min-w-0">
            <BackButton
              fallbackUrl="/buyer/orders"
              label="Orders"
              className="min-h-[48px] h-12 px-3 py-2 rounded-xl border border-slate-200 text-slate-700 hover:text-slate-900 hover:bg-slate-100 text-xs font-semibold shrink-0"
            />

            <div className="h-5 w-px bg-slate-200 shrink-0 hidden sm:block" />

            <div className="min-w-0">
              <span className="text-[10px] sm:text-xs font-bold text-slate-400 uppercase tracking-wider block">
                Order & Booking Overview
              </span>
              <h1 className="text-sm sm:text-base font-bold text-slate-900 truncate">
                {bookingData.bookingId || bookingData.dealReference}
              </h1>
            </div>
          </div>

          <div className="flex items-center gap-2 shrink-0">
            <Link
              href="/buyer/orders"
              className="inline-flex items-center justify-center min-h-[48px] h-12 px-4 rounded-xl text-xs sm:text-sm font-semibold text-slate-600 hover:text-slate-900 hover:bg-slate-100 transition-colors"
            >
              <span>Back to Orders</span>
            </Link>
          </div>
        </div>
      </header>

      {/* 2. Main Content Container (max-w-3xl mx-auto p-4 space-y-4) */}
      <main className="max-w-3xl mx-auto p-4 space-y-4">
        {/* Module 1: Booking Visibility Card (from 38.1) */}
        <section aria-labelledby="booking-card-heading">
          <h2 id="booking-card-heading" className="sr-only">
            Booking Details
          </h2>
          <BookingVisibilityCard data={bookingData} />
        </section>

        {/* Module 2: Partial Fulfillment Visualizer (from 38.3) */}
        <section aria-labelledby="fulfillment-card-heading">
          <h2 id="fulfillment-card-heading" className="sr-only">
            Partial Fulfillment Allocation
          </h2>
          <OrderFulfillmentCard
            math={bookingData.fulfillmentMath}
            originalQuantity={bookingData.originalQuantity}
            bookedQuantity={bookingData.bookedQuantity}
            remainingQuantity={bookingData.remainingQuantity}
            fulfillmentPercentage={bookingData.fulfillmentPercentage}
            unitSymbol={bookingData.unitSymbol}
          />
        </section>

        {/* Module 3: Live State Machine Logistics Timeline (Micro-Sprint 38.4) */}
        <section aria-labelledby="logistics-timeline-heading">
          <h2 id="logistics-timeline-heading" className="sr-only">
            Logistics Dispatch Timeline
          </h2>
          <LogisticsTimeline
            status={bookingData.bookingStatus}
            bookingId={bookingData.bookingId}
          />
        </section>

        {/* Module 4: Live Vehicle & Delivery Details Card (Micro-Sprint 38.5) */}
        <section aria-labelledby="delivery-details-heading">
          <h2 id="delivery-details-heading" className="sr-only">
            Live Vehicle & Delivery Details
          </h2>
          <DeliveryDetailsCard
            dealId={bookingData.dealId}
            bookingId={bookingData.bookingId}
            dispatchDetails={bookingData.dispatchDetails}
          />
        </section>

        {/* Module 5: Transaction Quality & Weighment Records (Micro-Sprint 39.1) */}
        <section aria-labelledby="transaction-quality-heading">
          <h2 id="transaction-quality-heading" className="sr-only">
            Transaction Quality & Weighment Records
          </h2>
          <TransactionQualityCard
            bookingId={bookingData.bookingId}
            initialData={qualityRes.success ? qualityRes.data : null}
          />
        </section>

        {/* Module 6: Fulfillment Documents & Compliance Vault (Micro-Sprint 39.2) */}
        <section aria-labelledby="document-vault-heading">
          <h2 id="document-vault-heading" className="sr-only">
            Fulfillment Documents & Compliance Vault
          </h2>
          <TransactionDocumentVault
            bookingId={bookingData.bookingId}
            initialData={documentMatrixRes.success ? documentMatrixRes.data : null}
          />
        </section>

        {/* Module 7: Buyer Payable Ledger & Escrow Settlement (Micro-Sprint 39.3) */}
        <section aria-labelledby="payment-card-heading">
          <h2 id="payment-card-heading" className="sr-only">
            Payable Ledger & Escrow Settlement
          </h2>
          <BuyerPaymentCard
            bookingId={bookingData.bookingId}
            initialData={
              paymentRes.success && paymentRes.data
                ? paymentRes.data.singlePayable || paymentRes.data.payables[0] || null
                : null
            }
          />
        </section>

        {/* Module 8: Dispute & Exception Management (Micro-Sprint 39.4) */}
        <section aria-labelledby="dispute-section-heading">
          <h2 id="dispute-section-heading" className="sr-only">
            Order Discrepancies & Dispute Mediation
          </h2>
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 p-4 sm:p-5 rounded-2xl bg-white border border-slate-200 shadow-xs">
            <div className="space-y-0.5">
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                Fulfillment Exceptions
              </span>
              <h3 className="text-xs sm:text-sm font-bold text-slate-900">
                Encountered a Quality, Weight, or Transit Discrepancy?
              </h3>
              <p className="text-xs text-slate-500 max-w-lg leading-relaxed">
                File a formal exception for neutral Broker mediation. Direct seller communications are restricted to preserve fiduciary escrow integrity.
              </p>
            </div>
            <RaiseDisputeModal
              bookingId={bookingData.bookingId}
              commodityName={bookingData.commodityName}
            />
          </div>
        </section>
      </main>
    </div>
  );
}
