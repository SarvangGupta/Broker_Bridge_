import React from 'react';
import { Truck } from 'lucide-react';
import { getBuyerOrdersListAction } from '@/src/server/actions/buyer-order-actions';
import { BuyerOrdersFeed } from '@/src/components/buyer/orders/buyer-orders-feed';

export const dynamic = 'force-dynamic';

/**
 * Task 3 (Micro-Sprint 38.2): Buyer "My Orders" Hub Route.
 * Displays live orders feed, filterable status tabs, and mobile-first order summary cards.
 */
export default async function BuyerOrdersPage() {
  const response = await getBuyerOrdersListAction();
  const orders = response.success && response.data ? response.data : [];

  return (
    <div className="w-full max-w-full overflow-x-hidden space-y-6 p-4 sm:p-6 lg:p-8">
      {/* 1. Page Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 pb-4 border-b border-slate-200">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-sky-50 text-[#0284C7] border border-sky-200">
              <Truck className="w-3.5 h-3.5" />
              <span>Logistics & Fulfillment</span>
            </span>
          </div>
          <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">
            My Orders
          </h1>
          <p className="text-xs sm:text-sm text-slate-500 mt-0.5">
            Track active procurement bookings, logistics dispatch lifecycles, and fulfillment status.
          </p>
        </div>
      </div>

      {/* 2. Main Orders Feed (Card-based grid + status filters + empty state) */}
      <BuyerOrdersFeed orders={orders} />
    </div>
  );
}
